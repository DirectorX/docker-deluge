#!/bin/bash
# Exercise the built image without requiring host-side Deluge dependencies.
set -euo pipefail

image="${1:?Usage: bash scripts/smoke_test.sh IMAGE}"
config="$(mktemp -d)"
name="deluge-smoke-${RANDOM}-$$"
cleanup() {
    docker logs "$name" 2>/dev/null || true
    docker rm -f "$name" >/dev/null 2>&1 || true
    # Container files belong to UID 1000, not necessarily the CI user.
    docker run --rm --user 0 --entrypoint /bin/sh \
        --volume "$config:/config" "$image" -c 'rm -rf /config/* /config/.[!.]* /config/..?*' || true
    rm -rf "$config"
}
trap cleanup EXIT
chmod 777 "$config"

docker run --detach --name "$name" --user 1000:1000 \
    --stop-timeout 30 --health-interval 2s --health-start-period 30s \
    --env UMASK_SET=022 --volume "$config:/config" \
    --publish 127.0.0.1::8112 "$image" >/dev/null

wait_healthy() {
    for ((attempt=0; attempt<60; attempt++)); do
        state="$(docker inspect --format '{{.State.Status}}' "$name")"
        if [[ "$state" != running ]]; then
            echo "Container stopped unexpectedly: $state" >&2
            return 1
        fi
        if [[ "$(docker inspect --format '{{.State.Health.Status}}' "$name")" == healthy ]]; then
            return 0
        fi
        sleep 2
    done
    docker inspect --format '{{json .State.Health}}' "$name" >&2
    return 1
}

wait_healthy
port="$(docker port "$name" 8112/tcp)"
curl --fail --silent --show-error --max-time 10 "http://$port/" >/dev/null
# Confirm arbitrary non-root operation and a writable persistent mount.
test "$(docker exec "$name" id -u)" = 1000
docker exec "$name" sh -c 'echo persisted > /config/smoke-marker'
docker stop "$name" >/dev/null
test "$(docker inspect --format '{{.State.ExitCode}}' "$name")" = 0
test -s "$config/core.conf"
docker start "$name" >/dev/null
wait_healthy
test "$(docker exec "$name" cat /config/smoke-marker)" = persisted
docker stop "$name" >/dev/null
test "$(docker inspect --format '{{.State.ExitCode}}' "$name")" = 0
echo 'Smoke tests passed: non-root startup, HTTP, healthcheck, shutdown, persistence, restart.'
