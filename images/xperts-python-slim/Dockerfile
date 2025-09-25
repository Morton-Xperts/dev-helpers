ARG PY_VER=3.11
FROM python:${PY_VER}-slim

# 1) Minimal runtime packages
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        netbase \
        tzdata; \
    rm -rf /var/lib/apt/lists/*

# 2) Create no-suffix symlinks (idle/pydoc/python/python-config)
RUN set -eux; \
    for src in idle3 pydoc3 python3 python3-config; do \
        dst="$(echo "$src" | tr -d 3)"; \
        [ -s "/usr/local/bin/$src" ] || continue; \
        [ -e "/usr/local/bin/$dst" ] || ln -sT "/usr/local/bin/$src" "/usr/local/bin/$dst"; \
    done

# 3) Build deps & headers
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        curl \
        gcc \
        gnupg \
        dirmngr \
        dpkg-dev \
        libbluetooth-dev \
        libbz2-dev \
        libc6-dev \
        libexpat1-dev \
        libffi-dev \
        libgdbm-dev \
        liblzma-dev \
        libncursesw5-dev \
        libreadline-dev \
        libsqlite3-dev \
        libssl-dev \
        make \
        tk-dev \
        uuid-dev \
        wget \
        xz-utils \
        zlib1g-dev \
        libpq-dev \
        python3-dev; \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    apt-get clean -y; \
    rm -rf /var/lib/apt/lists/*

# 4) pip upgrade, then pipenv
RUN /bin/sh -c "pip3 install -U pip && pip3 install --no-cache-dir -q pipenv"
