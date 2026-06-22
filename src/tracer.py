import subprocess
import re
import platform

def traceroute(host, max_hops=20):
    result = {
        "host": host,
        "hops": [],
        "hop_count": 0,
        "success": False,
        "raw": ""
    }

    system = platform.system().lower()
    if system == "windows":
        cmd = ["tracert", "-d", "-h", str(max_hops), "-w", "3000", host]
    else:
        cmd = ["traceroute", "-n", "-m", str(max_hops), "-w", "3", host]

    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
        output = proc.stdout + proc.stderr
        result["raw"] = output

        ip_pattern = r"(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})"
        lines = output.strip().split("\n")

        for line in lines:
            ips = re.findall(ip_pattern, line)
            if ips:
                hop_ip = ips[0]
                times = re.findall(r"(\d+(?:\.\d+)?)\s*ms", line)
                avg_time = sum(float(t) for t in times) / len(times) if times else None
                result["hops"].append({"ip": hop_ip, "rtt_ms": avg_time})

        result["hop_count"] = len(result["hops"])
        result["success"] = result["hop_count"] > 0

    except subprocess.TimeoutExpired:
        result["raw"] = "timeout"
    except Exception as e:
        result["raw"] = str(e)

    return result
