import sqlite3
import time
import os

class Database:
    def __init__(self, db_path):
        self.db_path = db_path
        self._init_db()

    def _get_conn(self):
        return sqlite3.connect(self.db_path)

    def _init_db(self):
        conn = self._get_conn()
        c = conn.cursor()
        c.execute("""
            CREATE TABLE IF NOT EXISTS ping_results (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp REAL,
                target_host TEXT,
                target_name TEXT,
                latency_ms REAL,
                packet_loss_pct REAL,
                is_anomaly INTEGER DEFAULT 0
            )
        """)
        c.execute("""
            CREATE TABLE IF NOT EXISTS traceroute_results (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp REAL,
                target_host TEXT,
                target_name TEXT,
                hops_json TEXT,
                hop_count INTEGER,
                changed INTEGER DEFAULT 0
            )
        """)
        c.execute("""
            CREATE TABLE IF NOT EXISTS baselines (
                target_host TEXT PRIMARY KEY,
                avg_latency_ms REAL,
                std_latency_ms REAL,
                hop_count INTEGER,
                hops_json TEXT,
                updated_at REAL
            )
        """)
        c.execute("""
            CREATE TABLE IF NOT EXISTS alerts (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp REAL,
                alert_type TEXT,
                message TEXT,
                sent INTEGER DEFAULT 0
            )
        """)
        conn.commit()
        conn.close()

    def save_ping(self, target_host, target_name, latency_ms, packet_loss_pct, is_anomaly=False):
        conn = self._get_conn()
        conn.execute(
            "INSERT INTO ping_results (timestamp, target_host, target_name, latency_ms, packet_loss_pct, is_anomaly) VALUES (?,?,?,?,?,?)",
            (time.time(), target_host, target_name, latency_ms, packet_loss_pct, int(is_anomaly))
        )
        conn.commit()
        conn.close()

    def save_traceroute(self, target_host, target_name, hops, hop_count, changed=False):
        import json
        conn = self._get_conn()
        conn.execute(
            "INSERT INTO traceroute_results (timestamp, target_host, target_name, hops_json, hop_count, changed) VALUES (?,?,?,?,?,?)",
            (time.time(), target_host, target_name, json.dumps(hops), hop_count, int(changed))
        )
        conn.commit()
        conn.close()

    def get_recent_pings(self, target_host, count=50):
        conn = self._get_conn()
        rows = conn.execute(
            "SELECT latency_ms, packet_loss_pct FROM ping_results WHERE target_host=? ORDER BY id DESC LIMIT ?",
            (target_host, count)
        ).fetchall()
        conn.close()
        return rows

    def get_baseline(self, target_host):
        conn = self._get_conn()
        row = conn.execute(
            "SELECT avg_latency_ms, std_latency_ms, hop_count, hops_json FROM baselines WHERE target_host=?",
            (target_host,)
        ).fetchone()
        conn.close()
        return row

    def save_baseline(self, target_host, avg_latency, std_latency, hop_count, hops_json):
        conn = self._get_conn()
        conn.execute(
            "INSERT OR REPLACE INTO baselines (target_host, avg_latency_ms, std_latency_ms, hop_count, hops_json, updated_at) VALUES (?,?,?,?,?,?)",
            (target_host, avg_latency, std_latency, hop_count, hops_json, time.time())
        )
        conn.commit()
        conn.close()

    def save_alert(self, alert_type, message):
        conn = self._get_conn()
        conn.execute(
            "INSERT INTO alerts (timestamp, alert_type, message) VALUES (?,?,?)",
            (time.time(), alert_type, message)
        )
        conn.commit()
        conn.close()

    def get_last_alert_time(self, alert_type, target_host=None):
        conn = self._get_conn()
        if target_host:
            row = conn.execute(
                "SELECT timestamp FROM alerts WHERE alert_type=? AND message LIKE ? ORDER BY id DESC LIMIT 1",
                (alert_type, f"%{target_host}%")
            ).fetchone()
        else:
            row = conn.execute(
                "SELECT timestamp FROM alerts WHERE alert_type=? ORDER BY id DESC LIMIT 1",
                (alert_type,)
            ).fetchone()
        conn.close()
        return row[0] if row else 0
