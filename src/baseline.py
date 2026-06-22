import json
import logging

logger = logging.getLogger("baseline")

def compute_baseline(db, target_host):
    rows = db.get_recent_pings(target_host, count=50)
    if len(rows) < 10:
        logger.info(f"Not enough data for baseline on {target_host} ({len(rows)} samples)")
        return None
    latencies = [r[0] for r in rows if r[0] is not None]
    if len(latencies) < 10:
        return None
    avg = sum(latencies) / len(latencies)
    variance = sum((x - avg) ** 2 for x in latencies) / len(latencies)
    std = variance ** 0.5
    return {"avg_ms": round(avg, 2), "std_ms": round(std, 2)}

def check_anomaly(db, config, target_host, current_latency, current_loss):
    alert_cfg = config["alert"]
    baseline = db.get_baseline(target_host)
    if baseline is None:
        return False, "no baseline"
    avg_ms, std_ms, hop_count, hops_json = baseline
    reasons = []
    if current_latency is not None and avg_ms > 0:
        if current_latency > avg_ms * alert_cfg["latency_multiplier"]:
            reasons.append(f"latency {current_latency:.1f}ms > baseline {avg_ms:.1f}ms x{alert_cfg['latency_multiplier']}")
        if current_latency > alert_cfg["latency_abs_threshold_ms"]:
            reasons.append(f"latency {current_latency:.1f}ms > abs threshold {alert_cfg['latency_abs_threshold_ms']}ms")
    if current_loss > alert_cfg["packet_loss_threshold_pct"]:
        reasons.append(f"loss {current_loss:.1f}% > threshold {alert_cfg['packet_loss_threshold_pct']}%")
    return len(reasons) > 0, "; ".join(reasons)

def check_path_change(current_hops, baseline_hops_json):
    if not baseline_hops_json:
        return False, "no baseline"
    baseline_hops = json.loads(baseline_hops_json)
    if len(current_hops) != len(baseline_hops):
        return True, f"hop count changed {len(baseline_hops)} -> {len(current_hops)}"
    changes = []
    for i, (cur, base) in enumerate(zip(current_hops, baseline_hops)):
        if cur["ip"] != base["ip"]:
            changes.append(f"hop{i+1}: {base['ip']} -> {cur['ip']}")
    if changes:
        return True, "; ".join(changes)
    return False, "no change"
