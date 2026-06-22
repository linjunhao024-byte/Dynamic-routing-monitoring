import requests
import time
import hmac
import hashlib
import base64
import urllib.parse
import logging

logger = logging.getLogger("alerter")

def send_telegram(bot_token, chat_id, message):
    url = f"https://api.telegram.org/bot{bot_token}/sendMessage"
    payload = {"chat_id": chat_id, "text": message, "parse_mode": "Markdown"}
    try:
        r = requests.post(url, json=payload, timeout=10)
        return r.status_code == 200
    except Exception as e:
        logger.error(f"Telegram send failed: {e}")
        return False

def send_dingtalk(webhook_url, secret, message):
    url = webhook_url
    if secret:
        timestamp = str(round(time.time() * 1000))
        string_to_sign = f"{timestamp}\n{secret}"
        hmac_code = hmac.new(secret.encode(), string_to_sign.encode(), hashlib.sha256).digest()
        sign = urllib.parse.quote_plus(base64.b64encode(hmac_code))
        url = f"{webhook_url}&timestamp={timestamp}&sign={sign}"
    payload = {"msgtype": "text", "text": {"content": message}}
    try:
        r = requests.post(url, json=payload, timeout=10)
        return r.status_code == 200
    except Exception as e:
        logger.error(f"DingTalk send failed: {e}")
        return False

def send_alert(config, message):
    ok = True
    tg = config.get("telegram", {})
    if tg.get("enabled"):
        if not send_telegram(tg["bot_token"], tg["chat_id"], message):
            ok = False
    dt = config.get("dingtalk", {})
    if dt.get("enabled"):
        if not send_dingtalk(dt["webhook_url"], dt.get("secret", ""), message):
            ok = False
    return ok

def build_alert_message(alert_type, server_name, details):
    timestamp = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime())
    lines = [f"🔴 *路由监测告警*", ""]
    lines.append(f"服务器: `{server_name}`")
    lines.append(f"时间: `{timestamp}`")
    lines.append(f"类型: {alert_type}")
    lines.append("")
    for k, v in details.items():
        lines.append(f"{k}: `{v}`")
    return "\n".join(lines)
