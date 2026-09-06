import http.server
import socketserver
import datetime
import sys

LOG = r"c:/Users/xbdki/code/chat/app_err.log"


class Handler(http.server.BaseHTTPRequestHandler):
    def _cors(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")

    def do_OPTIONS(self):
        self.send_response(204)
        self._cors()
        self.end_headers()

    def do_POST(self):
        try:
            length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(length) if length else b""
        except Exception:
            body = b""
        ts = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        with open(LOG, "ab") as f:
            f.write(("==== %s ====\n" % ts).encode("utf-8"))
            f.write(body)
            f.write(b"\n\n")
        self.send_response(200)
        self._cors()
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        self.wfile.write(b"ok")

    def do_GET(self):
        self.send_response(200)
        self._cors()
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        try:
            with open(LOG, "rb") as f:
                self.wfile.write(f.read())
        except Exception:
            self.wfile.write(b"")

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    with socketserver.TCPServer(("0.0.0.0", 5300), Handler) as httpd:
        print("log recv on http://0.0.0.0:5300", flush=True)
        httpd.serve_forever()
