#!/usr/bin/env python3
import time
import logging
import gc
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from config import load_config
from db import Database
from pinger import ping
from tracer import traceroute
from baseline import compute_baseline, check_anomaly, check_path_change
from alerter import send_alert, build_alert_message

LITE_MODE = False

def setup_logging(config, lite=False):
    level = getattr(logging, config.get("log", {}).get("level", "INFO"))
    handlers = [logging.StreamHandler()]
    if not lite:
        log_file = config.get("log", {}).get("file", "monitor.log")
        handlers.append(logging.FileHandler(log_file, encoding="utf-8"))
    logging.basicConfig(level=level, format="%(asctime)s [%(name)s] %(levelname)s: %(message)s", handlers=handlers)

def do_ping_cycle(db, config):
    logger = logging.getLogger("ping")
    targets = config["ping_targets"]
    count = config["monitoring"]["ping_count"]
    consecutive = {}
    for target in targets:
        host = target["host"]
        name = target["name"]
        result = ping(host, count=count)
        if result["success"]:
            latency = result["latency_ms"]
            loss = result["packet_loss_pct"]
            is_anomaly, reason = check_anomaly(db, config, host, latency, loss)
            db.save_ping(host, name, latency, loss, is_anomaly)
            status = "ANOMALY" if is_anomaly else "OK"
            logger.info(f"[{status}] {name}({host}): {latency:.1f}ms, loss:{loss:.1f}%")
            if is_anomaly:
                consecutive[host] = consecutive.get(host, 0) + 1
                threshold = config["alert"]["consecutive_failures"]
                if consecutive[host] >= threshold:
                    cooldown = config["alert"]["cooldown_sec"]
                    last = db.get_last_alert_time("ping_anomaly", host)
                    if time.time() - last > cooldown:
                        msg = build_alert_message("延迟/丢包异常", config["server_name"], {
                            "目标": f"{name} ({host})",
                            "延迟": f"{latency:.1f}ms",
                            "丢包": f"{loss:.1f}%",
                            "原因": reason,
                            "连续异常": f"{consecutive[host]}次"
                        })
                        send_alert(config, msg)
                        db.save_alert("ping_anomaly", f"{host} {reason}")
                        logger.warning(f"ALERT SENT: {name} {reason}")
            else:
                consecutive[host] = 0
        else:
            db.save_ping(host, name, None, 100.0, True)
            logger.warning(f"[FAIL] {name}({host}): ping failed")
            consecutive[host] = consecutive.get(host, 0) + 1
    if LITE_MODE:
        gc.collect()
    return True

def do_traceroute_cycle(db, config):
    logger = logging.getLogger("traceroute")
    targets = config["traceroute_targets"]
    for target in targets:
        host = target["host"]
        name = target["name"]
        result = traceroute(host)
        if result["success"]:
            hop_count = result["hop_count"]
            baseline = db.get_baseline(host)
            if baseline and baseline[3]:
                changed, detail = check_path_change(result["hops"], baseline[3])
            else:
                changed, detail = False, "first run, setting baseline"
            db.save_traceroute(host, name, result["hops"], hop_count, changed)
            if changed:
                cooldown = config["alert"]["cooldown_sec"]
                last = db.get_last_alert_time("path_change", host)
                if time.time() - last > cooldown:
                    msg = build_alert_message("路径变化", config["server_name"], {
                        "目标": f"{name} ({host})",
                        "跳数": str(hop_count),
                        "变化": detail,
                        "当前路径": " -> ".join(h["ip"] for h in result["hops"][:5])
                    })
                    send_alert(config, msg)
                    db.save_alert("path_change", f"{host} {detail}")
                    logger.warning(f"PATH CHANGED: {name} {detail}")
            logger.info(f"[{'CHANGED' if changed else 'OK'}] {name}: {hop_count} hops")
            del result
        else:
            logger.warning(f"[FAIL] {name}({host}): traceroute failed")
    if LITE_MODE:
        gc.collect()
    return True

def update_baselines(db, config):
    logger = logging.getLogger("baseline")
    all_targets = set()
    for t in config["ping_targets"]:
        all_targets.add(t["host"])
    for t in config["traceroute_targets"]:
        all_targets.add(t["host"])
    for host in all_targets:
        bl = compute_baseline(db, host)
        if bl:
            old = db.get_baseline(host)
            old_avg = old[0] if old else None
            db.save_baseline(host, bl["avg_ms"], bl["std_ms"], 0, "[]")
            if old_avg and abs(bl["avg_ms"] - old_avg) > old_avg * 0.3:
                logger.warning(f"Baseline shifted for {host}: {old_avg:.1f}ms -> {bl['avg_ms']:.1f}ms")
            else:
                logger.info(f"Baseline updated for {host}: {bl['avg_ms']:.1f}ms (std:{bl['std_ms']:.1f})")

def main():
    global LITE_MODE
    config = load_config()
    LITE_MODE = config.get("mode", "normal") == "lite"
    setup_logging(config, lite=LITE_MODE)
    logger = logging.getLogger("main")
    if LITE_MODE:
        logger.info("=== LITE MODE: reduced memory usage ===")
    db_path = config["database"]["path"]
    db = Database(db_path)
    logger.info(f"Starting monitor: {config['server_name']}")
    logger.info(f"Ping targets: {[t['name'] for t in config['ping_targets']]}")
    if not LITE_MODE:
        logger.info(f"Traceroute targets: {[t['name'] for t in config['traceroute_targets']]}")
    ping_interval = config["monitoring"]["ping_interval_sec"]
    tr_interval = config["monitoring"]["traceroute_interval_sec"]
    baseline_interval = 600
    last_tr = 0
    last_bl = 0
    cycle = 0
    sample_count = config["monitoring"]["baseline_sample_count"]
    logger.info(f"Warming up: collecting {sample_count} samples for baseline...")
    while True:
        try:
            now = time.time()
            do_ping_cycle(db, config)
            cycle += 1
            if not LITE_MODE and now - last_tr >= tr_interval:
                do_traceroute_cycle(db, config)
                last_tr = now
            if now - last_bl >= baseline_interval:
                update_baselines(db, config)
                last_bl = now
            if cycle == sample_count:
                logger.info("Warmup complete, computing initial baselines...")
                update_baselines(db, config)
                last_bl = now
            time.sleep(ping_interval)
        except KeyboardInterrupt:
            logger.info("Shutting down...")
            break
        except Exception as e:
            logger.error(f"Error in main loop: {e}", exc_info=True)
            time.sleep(5)

if __name__ == "__main__":
    main()
