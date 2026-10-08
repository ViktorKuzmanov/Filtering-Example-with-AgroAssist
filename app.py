#!/usr/bin/env python3
"""AgroAssist — тест веб апликација за recommendation shemata.

Старт:  python3 app.py
Потоа отвори:  http://localhost:8000
"""
import json
import os
import sqlite3
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

BASE = os.path.dirname(os.path.abspath(__file__))
DB = os.path.join(BASE, "agroassist.db")
PORT = int(os.environ.get("PORT", 8000))


def rows(sql, params=()):
    con = sqlite3.connect(DB)
    con.row_factory = sqlite3.Row
    try:
        return [dict(r) for r in con.execute(sql, params)]
    finally:
        con.close()


class Handler(BaseHTTPRequestHandler):
    def _send(self, code, content_type, body):
        self.send_response(code)
        self.send_header("Content-Type", content_type + "; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path
        qs = {k: v[0] for k, v in parse_qs(parsed.query).items()}

        if path == "/":
            with open(os.path.join(BASE, "index.html"), "rb") as f:
                self._send(200, "text/html", f.read())
            return

        if path == "/api/options":
            payload = {
                "crops": rows("SELECT id, name FROM crop WHERE is_active=1 ORDER BY name"),
                "diseases": rows("SELECT id, name FROM disease WHERE is_active=1 ORDER BY name"),
                "phases": rows("SELECT id, name FROM growth_phase WHERE is_active=1 ORDER BY sort_order"),
            }
            self._send(200, "application/json", json.dumps(payload, ensure_ascii=False).encode("utf-8"))
            return

        if path == "/api/search":
            crop = int(qs.get("crop", 0) or 0)
            disease = int(qs.get("disease", 0) or 0)
            phase = int(qs.get("phase", 0) or 0)
            if not (crop and disease and phase):
                self._send(400, "application/json", b'{"error":"crop, disease and phase are required"}')
                return

            # Точно совпаѓање на сите три филтри
            exact = rows(
                """SELECT p.name, p.category, p.active_substance, p.price, p.unit,
                          p.stock, r.dosage, r.notes, r.sort_order
                   FROM recommendation r
                   JOIN product p ON p.id = r.product_id
                   WHERE r.crop_id = ? AND r.disease_id = ? AND r.phase_id = ?
                     AND r.is_active = 1 AND p.is_active = 1
                   ORDER BY r.sort_order, p.name""",
                (crop, disease, phase),
            )

            # Пад-бек: исти култура + болест во други фази (ако нема точно совпаѓање)
            others = rows(
                """SELECT p.name, p.category, p.active_substance, p.price, p.unit,
                          p.stock, r.dosage, r.notes, ph.name AS phase_name
                   FROM recommendation r
                   JOIN product p ON p.id = r.product_id
                   JOIN growth_phase ph ON ph.id = r.phase_id
                   WHERE r.crop_id = ? AND r.disease_id = ? AND r.phase_id != ?
                     AND r.is_active = 1 AND p.is_active = 1
                   ORDER BY ph.sort_order, r.sort_order, p.name""",
                (crop, disease, phase),
            )

            self._send(200, "application/json", json.dumps({"exact": exact, "others": others}, ensure_ascii=False).encode("utf-8"))
            return

        self._send(404, "text/plain", b"Not found")

    def log_message(self, *args):  # потивок лог
        pass


if __name__ == "__main__":
    print(f"AgroAssist работи на http://localhost:{PORT}")
    ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()