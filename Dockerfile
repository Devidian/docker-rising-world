FROM cm2network/steamcmd:root

LABEL maintainer=docker-rw@devidian.de

RUN apt update && apt upgrade -y

COPY entrypoint.sh /root/
RUN chmod +x /root/entrypoint.sh

HEALTHCHECK --interval=30s --timeout=10s --retries=3 CMD curl -f http://localhost:4254/info || exit 1

ENTRYPOINT ["/root/entrypoint.sh"]