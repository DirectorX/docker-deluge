import http.server
from pathlib import Path
import socket
import subprocess
import threading
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "rootfs/usr/local/bin/healthcheck.sh"


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(self.server.response_status)
        self.end_headers()

    def log_message(self, *args):
        pass


class HealthcheckTests(unittest.TestCase):
    def setUp(self):
        self.daemon = socket.socket()
        self.daemon.bind(("127.0.0.1", 0))
        self.daemon.listen()
        self.daemon_port = self.daemon.getsockname()[1]
        self.web = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        self.web.response_status = 200
        self.web_port = self.web.server_port
        self.thread = threading.Thread(target=self.web.serve_forever, daemon=True)
        self.thread.start()

    def tearDown(self):
        self.daemon.close()
        self.web.shutdown()
        self.web.server_close()
        self.thread.join()

    def check_health(self):
        return subprocess.run(
            ["sh", str(SCRIPT), str(self.daemon_port), str(self.web_port)],
            capture_output=True,
            text=True,
            timeout=10,
        )

    def test_healthy_services(self):
        result = self.check_health()
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_missing_daemon_fails(self):
        self.daemon.close()
        self.assertNotEqual(self.check_health().returncode, 0)

    def test_missing_web_fails(self):
        self.web.shutdown()
        self.web.server_close()
        self.assertNotEqual(self.check_health().returncode, 0)

    def test_web_error_fails(self):
        self.web.response_status = 500
        self.assertNotEqual(self.check_health().returncode, 0)
