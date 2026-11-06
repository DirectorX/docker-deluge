#!/bin/bash
# Scan an exported image; never expose the host Docker socket to the scanner.
set -euo pipefail

image="${1:?Usage: bash scripts/scan_image.sh IMAGE}"
scanner='aquasec/trivy:0.76.2@sha256:8f6bb947dbc528902e11f2f5be52f7b519f6a39d5d148f41166f2040499768fb'
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

docker image save --output "$work/image.tar" "$image"
docker run --rm --user "$(id -u):$(id -g)" \
    --volume "$work:/scan:ro" \
    "$scanner" image --input /scan/image.tar \
    --cache-dir /tmp/trivy --scanners vuln --severity HIGH,CRITICAL \
    --ignore-unfixed --exit-code 1 --timeout 10m
