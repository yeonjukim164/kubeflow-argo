"""Alertmanager 웹훅을 받아 알림마다 한 줄씩 표준 출력에 남긴다. 메일이나 Slack 없이 라우팅을 확인하려고 만든 수신자."""
import json, sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

class H(BaseHTTPRequestHandler):
    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))) or b"{}")
        for a in body.get("alerts", []):
            print(json.dumps({"receiver": self.path.strip("/"), "status": a.get("status"), "alertname": a["labels"].get("alertname"),
                              "severity": a["labels"].get("severity"), "job": a["labels"].get("job"),
                              "summary": a.get("annotations", {}).get("summary"), "startsAt": a.get("startsAt")}, ensure_ascii=False), flush=True)
        self.send_response(200); self.end_headers()
    def do_GET(self):                       # readinessProbe 용. kubelet 이 응답을 다 읽기 전에 끊어도 오류를 남기지 않는다
        try:
            self.send_response(200); self.end_headers(); self.wfile.write(b"ok")
        except BrokenPipeError:
            pass
    def log_message(self, *a): pass

print("alert-logger listening on 8080", flush=True)
ThreadingHTTPServer(("", 8080), H).serve_forever()
