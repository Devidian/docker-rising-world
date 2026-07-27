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

RUN install -d -o steam -g steam /appdata/rising-world/dedicated-server

COPY --chown=steam:steam --chmod=0755 entrypoint.sh /usr/local/bin/entrypoint.sh

USER steam
WORKDIR /appdata/rising-world/dedicated-server

ENV RW_UPDATE_ON_START=true \
    RW_VALIDATE=false

EXPOSE 4254-4259/tcp 4254-4259/udp

HEALTHCHECK --interval=30s --timeout=5s --start-period=10m --retries=3 \
    CMD ["curl", "--fail", "--silent", "--show-error", "--max-time", "5", "http://127.0.0.1:4254/info"]

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
