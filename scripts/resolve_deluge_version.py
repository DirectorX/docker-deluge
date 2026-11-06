#!/usr/bin/env python3
"""Select stable Deluge releases and sync the Dockerfile pin after publishing."""

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import urllib.request


STABLE_VERSION = re.compile(r"[0-9]+\.[0-9]+\.[0-9]+")


def resolve_version(dockerfile, latest_version, requested_version="", scheduled=False):
    if not STABLE_VERSION.fullmatch(latest_version):
        raise ValueError(f"Invalid upstream stable version: {latest_version!r}")
    match = re.search(r"^ARG DELUGE_BRANCH=deluge-(\S+)$", dockerfile, re.MULTILINE)
    if match is None:
        raise ValueError("Dockerfile must pin ARG DELUGE_BRANCH to a Deluge release")
    version = requested_version or (latest_version if scheduled else match[1])
    if not STABLE_VERSION.fullmatch(version):
        raise ValueError(f"Expected a stable Deluge version (e.g. 2.2.0): {version!r}")
    return version


def pin_version(dockerfile, version):
    if not STABLE_VERSION.fullmatch(version):
        raise ValueError(f"Invalid stable version: {version!r}")
    updated, count = re.subn(
        r"^ARG DELUGE_BRANCH=deluge-[0-9]+\.[0-9]+\.[0-9]+$",
        f"ARG DELUGE_BRANCH=deluge-{version}",
        dockerfile,
        flags=re.MULTILINE,
    )
    if count != 1:
        raise ValueError("Expected exactly one pinned DELUGE_BRANCH in Dockerfile")
    return updated


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pin", metavar="VERSION", help="Update Dockerfile without querying upstream")
    args = parser.parse_args()
    if args.pin is not None:
        path = Path("Dockerfile")
        path.write_text(pin_version(path.read_text(), args.pin))
        return

    request = urllib.request.Request(
        "https://pypi.org/pypi/deluge/json",
        headers={"User-Agent": "docker-deluge-release-build"},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        latest = json.load(response)["info"]["version"]
    version = resolve_version(
        Path("Dockerfile").read_text(),
        latest,
        requested_version=os.environ.get("DELUGE_VERSION", ""),
        scheduled=os.environ.get("GITHUB_EVENT_NAME") == "schedule",
    )
    # Fail before building if PyPI and the upstream source tags disagree.
    subprocess.run(
        [
            "git", "ls-remote", "--exit-code", "--tags",
            "https://github.com/deluge-torrent/deluge.git",
            f"refs/tags/deluge-{version}",
        ],
        check=True,
        timeout=60,
    )
    with open(os.environ["GITHUB_OUTPUT"], "a") as output:
        output.write(f"version={version}\n")
        output.write(f"is_latest={str(version == latest).lower()}\n")
    print(f"Building Deluge {version}; upstream latest stable: {latest}")


if __name__ == "__main__":
    main()
