import subprocess
import re
import platform

def ping(host, count=5):
    result = {
        "host": host,
        "latency_ms": None,
        "packet_loss_pct": 100.0,
        "success": False,
        "raw": ""
    }

    system = platform.system().lower()
    if system == "windows":
        cmd = ["ping", "-n", str(count), "-w", "3000", host]
    else:
        cmd = ["ping", "-c", str(count), "-W", "3", host]

    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        output = proc.stdout + proc.stderr
        result["raw"] = output

        loss_match = re.search(r"(\d+(?:\.\d+)?)\s*%", output)
        if loss_match:
            result["packet_loss_pct"] = float(loss_match.group(1))

        latency_matches = re.findall(r"time[=<](\d+(?:\.\d+)?)\s*ms", output)
        if latency_matches:
            latencies = [float(x) for x in latency_matches]
            result["latency_ms"] = sum(latencies) / len(latencies)
            result["success"] = True

    except subprocess.TimeoutExpired:
        result["raw"] = "timeout"
    except Exception as e:
        result["raw"] = str(e)

    return result
