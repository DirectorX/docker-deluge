# docker-deluge

![GitHub Workflow Status (branch)](https://img.shields.io/github/actions/workflow/status/DirectorX/docker-deluge/deploy.yaml?branch=main&style=flat-square)
[![GHCR](https://img.shields.io/badge/ghcr.io-directorx%2Fdeluge-24292e?logo=github&style=flat-square)](https://github.com/DirectorX/docker-deluge/pkgs/container/deluge)

A docker image for the torrent client [Deluge](https://deluge-torrent.org/) ![deluge's logo](https://user-images.githubusercontent.com/10530469/79228210-5ae36180-7e61-11ea-8f72-276e6197f011.png) based on @emmercm [libtorrent image](https://github.com/emmercm/docker-libtorrent.git). 

Use `ghcr.io/directorx/deluge:latest` or pin a Deluge version, e.g.
`ghcr.io/directorx/deluge:2.2.0`. New releases are checked daily.

## What is Deluge?

From [deluge-torrent.org](https://deluge-torrent.org/):

>  Deluge is a fully-featured cross-platform ​BitTorrent client. It is ​Free Software, licensed under the ​GNU GPLv3+ and adheres to ​freedesktop standards enabling it to work across many desktop environments.


## How to use these images

Quick start (configuration and downloads are not persisted in this example):

```bash
docker run \
    --detach \
    --interactive \
    --name deluge \
    --user "$(id -u):$(id -g)" \
    --env UMASK_SET=022 \
    --env TZ=Europe/Paris \
    --publish 127.0.0.1:8112:8112 \
    --publish 127.0.0.1:58846:58846 \
    ghcr.io/directorx/deluge:latest
```    

Access the web UI at [http://localhost:8112](http://localhost:8112) with default password `deluge` (no username). Change it immediately in Preferences → Interface.

Examples bind management ports to localhost. For remote access, use an authenticated VPN or a TLS reverse proxy; do not expose default credentials publicly. `localclient` is a daemon authentication user, not a web UI username.

Optional settings: mount `/etc/localtime:/etc/localtime:ro` to share host time settings, or set `LOGLEVEL=debug` for troubleshooting.

You can also access through the [Gtk client](https://dev.deluge-torrent.org/wiki/UserGuide/ThinClient) on `localhost` port `58846` for this you will need to set `allow_remote` to `true` in the `config/core.conf` file and [add a new user](https://dev.deluge-torrent.org/wiki/UserGuide/Authentication) `myuser:mypassword:10` in the `config/auth` file.

**Always stop the container before modify your config files otherwise they will not be saved**

### Volume mounts

Due to the ephemeral nature of Docker containers these images provide a number of optional volume mounts to persist data outside of the container:

- `/config`: the Deluge config directory containing `core.conf`
- `/torrents`: an optional download directory; configure Deluge's download path as `/torrents` in Preferences → Downloads. This image does not override Deluge's download defaults.

If using separate completed, incomplete, or watch directories, create them under `/torrents` and configure the corresponding Deluge preferences/plugins.

```bash
mkdir -p "${HOME}/deluge/config" "${HOME}/deluge/torrents"
docker run \
    --detach \
    --interactive \
    --name deluge \
    --user "$(id -u):$(id -g)" \
    --volume "${HOME}/deluge/torrents:/torrents" \
    --volume "${HOME}/deluge/config:/config" \
    --volume /etc/localtime:/etc/localtime:ro \
    --env UMASK_SET=022 \
    --env TZ=Europe/Paris \
    --publish 127.0.0.1:8112:8112 \
    --publish 127.0.0.1:58846:58846 \
    ghcr.io/directorx/deluge:latest
```

You should create directory before run the container otherwise directories are created by the docker deamon and owned by the root user

### Environment variables

- `UMASK_SET`: File creation mask (default: `002`; examples use `022`).
- `LOGLEVEL`: Set the log level: none, info, warning, error, debug (default: info)
- `TZ`: To change the timezone of the container. The full list of available options can be found on [Wikipedia](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones).

### Docker Compose

[`docker-compose`](https://docs.docker.com/compose/) can help with defining the `docker run` config in a repeatable way rather than ensuring you always pass the same CLI arguments.

Here's an example `docker-compose.yml` config:

```yaml
services:
  deluge:
    image: ghcr.io/directorx/deluge:latest
    container_name: deluge
    restart: unless-stopped
    user: 1000:1000
    environment:
      - UMASK_SET=022
      - TZ=Europe/Paris
      #- LOGLEVEL=info
    ports:
      - "127.0.0.1:8112:8112"
      - "127.0.0.1:58846:58846"
    volumes:
      - ./config:/config
      - ./torrents:/torrents
      - /etc/localtime:/etc/localtime:ro
```

Before starting Compose, create `config` and `torrents` and ensure UID/GID `1000:1000` can write to both (or change `user` to match your host user). Set the download path to `/torrents` after first login. Torrent peer traffic may require additional TCP/UDP port mappings matching your Deluge incoming-port settings.

## Tests

```bash
python3 -m unittest discover -s tests -v
docker build -t deluge:smoke .
bash scripts/smoke_test.sh deluge:smoke
bash scripts/scan_image.sh deluge:smoke
```

PR builds run smoke tests on amd64 and arm64. Publishing requires an amd64 smoke test covering non-root startup, HTTP, healthcheck, graceful shutdown, persistence, and restart.

## Build security

Base images and the Trivy scanner use multi-platform digest pins; GitHub Actions use commit SHA pins. Renovate maintains base-image and action pins. Update the Trivy version and digest together in `scripts/scan_image.sh`.

UnRAR source is checked against `UNRAR_SHA256` before extraction. When changing `UNRAR_VERSION`, fetch the matching archive from the official HTTPS URL, verify its provenance, and update the checksum too. The current checksum was computed from that archive; it is not an upstream signature verification.

CI blocks on HIGH/CRITICAL vulnerabilities with available fixes, plus scanner/database errors. Unfixed vulnerabilities are excluded from this gate, not considered safe. PRs scan both architectures; publishing scans amd64 before the multi-architecture push.

These controls do not make builds fully reproducible: Alpine packages, PyPI dependencies, and Deluge source tags remain external moving inputs.

## Contributing :

You are welcome to contribute to this project, but read this before please.

### Issues

Found any issue or bug in the codebase? Have a great idea you want to propose ? 
You can help by submitting an issue to the Github repository. 

**Before opening a new issue, please check if the issue has not been already made by searching 
the issues**

### Questions

For questions, open an [issue](https://github.com/DirectorX/docker-deluge/issues).

### Pull requests

Before submitting a pull request, ensure that you go through the following:
- Ensure that there is no open or closed Pull Request corresponding to your submission to avoid duplication of effort.
- Create a new branch on your forked repo based on the **main branch** (be sure that your fork is up to date with the upstream) and make the changes in it. Example:
```
    git clone https://your_fork
    git checkout -B patch-N main
```
- Submit the pull request, provide informations (why/where/how) in the comments section

## License

This project is under the [GNU Generic Public License v3](https://github.com/DirectorX/docker-deluge/blob/main/LICENSE) to allow free use while ensuring it stays open.

## Credit

This image is largely inspired by [Christian Emmer](https://emmer.dev)'s great work :

- https://github.com/emmercm/docker-libtorrent
