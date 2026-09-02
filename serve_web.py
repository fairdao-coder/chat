import http.server
import socketserver
import threading
import functools
import os

# 同时托管用户端(8080)与管理端(8081)两个已构建的 Web 产物。
DIRS = {
    8080: r"c:/Users/xbdki/code/chat/client/flutter_chat/build/web",
    8081: r"c:/Users/xbdki/code/chat/client/flutter_admin/build/web",
}


class Handler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass  # 静默


def serve(port, directory):
    os.makedirs(directory, exist_ok=True)
    handler = functools.partial(Handler, directory=directory)
    with socketserver.TCPServer(("127.0.0.1", port), handler) as httpd:
        print(f"Serving {directory} on http://127.0.0.1:{port}", flush=True)
        httpd.serve_forever()


threads = []
for port, directory in DIRS.items():
    t = threading.Thread(target=serve, args=(port, directory), daemon=False)
    t.start()
    threads.append(t)

for t in threads:
    t.join()
