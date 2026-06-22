import requests
import logging

logger = logging.getLogger("geoip")

_cache = {}

_PRIVATE_PREFIXES = (
    "10.", "127.", "192.168.",
    "172.16.", "172.17.", "172.18.", "172.19.",
    "172.20.", "172.21.", "172.22.", "172.23.",
    "172.24.", "172.25.", "172.26.", "172.27.",
    "172.28.", "172.29.", "172.30.", "172.31.",
)

def lookup(ip):
    if ip in _cache:
        return _cache[ip]
    if ip.startswith(_PRIVATE_PREFIXES):
        result = {"ip": ip, "country": "私有", "city": "本地", "org": "内网"}
        _cache[ip] = result
        return result
    try:
        r = requests.get(f"https://ip-api.com/json/{ip}?fields=status,country,city,org,isp,as", timeout=5)
        data = r.json()
        if data.get("status") == "success":
            result = {
                "ip": ip,
                "country": data.get("country", ""),
                "city": data.get("city", ""),
                "org": data.get("org", ""),
                "isp": data.get("isp", ""),
                "as": data.get("as", "")
            }
        else:
            result = {"ip": ip, "country": "未知", "city": "", "org": ""}
        _cache[ip] = result
        return result
    except Exception as e:
        logger.error(f"GeoIP lookup failed for {ip}: {e}")
        result = {"ip": ip, "country": "查询失败", "city": "", "org": ""}
        _cache[ip] = result
        return result

def format_hop(index, hop):
    ip = hop.get("ip", "*")
    rtt = hop.get("rtt_ms")
    geo = lookup(ip)
    location = f"{geo['country']}"
    if geo.get("city"):
        location += f" {geo['city']}"
    org = geo.get("org", "")
    rtt_str = f"{rtt:.1f}ms" if rtt else "*"
    line = f"  {index+1:>2}. {ip:<16} {rtt_str:<10} {location}"
    if org:
        line += f" ({org})"
    return line

def format_traceroute_result(target_name, hops):
    lines = [f"🗺 *路由追踪: {target_name}*", ""]
    lines.append("跳 IP               延迟       位置")
    lines.append("─" * 60)
    for i, hop in enumerate(hops[:15]):
        lines.append(format_hop(i, hop))
    return "\n".join(lines)

def get_path_countries(hops):
    countries = []
    for hop in hops:
        geo = lookup(hop.get("ip", "*"))
        country = geo.get("country", "")
        if country and country not in ("未知", "查询失败", "私有", "本地") and country not in countries:
            countries.append(country)
    return countries
