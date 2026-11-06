#!/bin/bash
set -u

umask "${UMASK_SET:-002}"

daemon_pid=
web_pid=

shutdown() {
    trap '' TERM INT
    for pid in "$daemon_pid" "$web_pid"; do
        if [[ -n "$pid" ]]; then
            kill -TERM "$pid" 2>/dev/null || true
        fi
    done
    for pid in "$daemon_pid" "$web_pid"; do
        if [[ -n "$pid" ]]; then
            wait "$pid" 2>/dev/null || true
        fi
    done
}

trap 'shutdown; exit 0' TERM INT

deluged -d -L "${LOGLEVEL:-info}" --config /config &
daemon_pid=$!
deluge-web -d -L "${LOGLEVEL:-info}" --config /config &
web_pid=$!

status=0
wait -n "$daemon_pid" "$web_pid" || status=$?
shutdown
exit "$status"
