FROM cm2network/steamcmd:steam-trixie

ARG VERSION=dev
ARG VCS_REF=unknown

LABEL org.opencontainers.image.title="Rising World Dedicated Server" \
      org.opencontainers.image.description="Docker image for the Rising World dedicated server" \
      org.opencontainers.image.source="https://github.com/Devidian/docker-rising-world" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.authors="docker-rw@devidian.de"

USER root

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends unzip borgbackup sqlite3 \
    && rm -rf /var/lib/apt/lists/* \
    && install -d -o steam -g steam /appdata/rising-world/dedicated-server

COPY --chown=steam:steam --chmod=0755 entrypoint.sh /usr/local/bin/entrypoint.sh
COPY --chown=steam:steam --chmod=0755 backup.sh /usr/local/bin/backup.sh
COPY --chown=steam:steam --chmod=0755 compact-plugin-dbs.sh /usr/local/bin/compact-plugin-dbs.sh
COPY --chown=steam:steam --chmod=0755 healthcheck.sh /usr/local/bin/healthcheck.sh

USER steam
WORKDIR /appdata/rising-world/dedicated-server

ENV RW_UPDATE_ON_START=true \
    RW_VALIDATE=false \
    RW_BETA="" \
    RW_INSTALL_OZ_TOOLS=false \
    RW_BACKUP_ON_START=true \
    RW_BACKUP_KEEP=7 \
    RW_COMPACT_PLUGIN_DBS_ON_START=false \
    RW_COMPACT_PLUGIN_DBS_MIN_MIB=512

EXPOSE 4254-4259/tcp 4254-4259/udp

HEALTHCHECK --interval=30s --timeout=5s --start-period=10m --retries=3 \
    CMD ["/usr/local/bin/healthcheck.sh"]

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
