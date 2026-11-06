#!/bin/sh

exec python3 - "${1:-58846}" "${2:-8112}" <<'PY'
import socket
import sys
import urllib.error
import urllib.request

try:
    with socket.create_connection(("127.0.0.1", int(sys.argv[1])), timeout=2):
        pass
    # Ignore proxy environment variables for container-local checks.
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    with opener.open(f"http://127.0.0.1:{int(sys.argv[2])}/", timeout=2) as response:
        if response.status != 200:
            raise ValueError(f"Unexpected web status: {response.status}")
except (OSError, ValueError, urllib.error.URLError) as error:
    print(f"Deluge healthcheck failed: {error}", file=sys.stderr)
    sys.exit(1)
print("Deluge daemon and web UI: OK")
PY
