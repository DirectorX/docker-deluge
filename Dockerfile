ARG UNRAR_VERSION=7.2.7
# SHA-256 of the versioned source archive fetched from rarlab.com over HTTPS.
ARG UNRAR_SHA256=01d903a7dcf413cb2925696d7796e48e38d471f79bfe7ef3ad2aebf6c12dbefd
ARG DELUGE_BRANCH=deluge-2.2.0

FROM alpine:3.24@sha256:3f4d6b32e26703c6082839234f43769d5046b3ac7c910033911d1e71d8cd630a AS unrar-builder

ARG UNRAR_VERSION
ARG UNRAR_SHA256

WORKDIR /tmp

RUN apk update && \
    apk add --no-cache \
        curl \
        tar \
        gzip \
        make \
        g++ && \
    mkdir -p /tmp/unrar && \
    curl --fail --silent --show-error -o \
    /tmp/unrar.tar.gz -L \
    "https://www.rarlab.com/rar/unrarsrc-${UNRAR_VERSION}.tar.gz" && \
    echo "${UNRAR_SHA256}  /tmp/unrar.tar.gz" | sha256sum -c - && \
    tar xf \
        /tmp/unrar.tar.gz -C \
        /tmp/unrar --strip-components=1 && \
    cd /tmp/unrar && \
    make


FROM emmercm/libtorrent:2.0.15-alpine@sha256:68c6e62adbd8237ed70daf4004f4400ad840cac174f9d17f3e38eabfb54d2083

LABEL name="docker-deluge" \
    maintainer="DirectorX" \
    description="Deluge is a lightweight, Free Software, cross-platform BitTorrent client." \
    url="https://deluge-torrent.org/" \
    org.label-schema.vcs-url="https://github.com/DirectorX/docker-deluge" \
    org.opencontainers.image.source="https://github.com/DirectorX/docker-deluge"

COPY rootfs /
COPY --from=unrar-builder /tmp/unrar/unrar /tmp/unrar

ARG DELUGE_BRANCH
ENV PYTHON_EGG_CACHE=/config/.cache \
    XDG_CONFIG_HOME=/config \
    LOGLEVEL=info

RUN apk update && \
    apk upgrade && \
    apk add --no-cache --virtual=base --upgrade \
        bash \
        p7zip \
        unzip \
        git \
        tzdata \
        ca-certificates \
        curl \
        python3 && \
    apk add --no-cache --virtual=build-dependencies --upgrade \
        build-base \
        libffi-dev \
        zlib-dev \
        openssl-dev \
        libjpeg-turbo-dev \
        linux-headers \
        musl-dev \
        cargo \
        py3-pip \
        py3-rjsmin \
        python3-dev && \
    apk add --no-cache --virtual=deluge-dependencies --upgrade \
        py3-chardet \
        py3-distro \
        py3-idna \
        py3-mako \
        py3-openssl \
        py3-pillow \
        py3-rencode \
        py3-service_identity \
        py3-setproctitle \
        py3-setuptools \
        py3-twisted \
        py3-wheel \
        py3-xdg \
        py3-six \
        py3-zope-interface && \
    # Deluge 2.2.0 plugins still require pkg_resources, removed in setuptools 81.
    python3 -m pip install --no-cache-dir --break-system-packages --ignore-installed 'setuptools==80.9.0' && \
    install -v -m755 /tmp/unrar /usr/local/bin && \
    git clone -b "${DELUGE_BRANCH}" https://github.com/deluge-torrent/deluge.git /tmp/deluge && \
    cd /tmp/deluge && \
    python3 setup.py clean -a && \
    python3 setup.py build && \
    test -s deluge/ui/web/js/deluge-all.js && \
    test -s deluge/ui/web/js/extjs/ext-extensions.js && \
    python3 setup.py install && \
    apk del --purge build-dependencies && \
    rm -rf /tmp/*

WORKDIR /config

VOLUME ["/config"]

HEALTHCHECK --interval=5m --timeout=10s --start-period=30s \
    CMD /usr/local/bin/healthcheck.sh 58846 8112

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
