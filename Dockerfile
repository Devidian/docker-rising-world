FROM cm2network/steamcmd:root

LABEL maintainer=docker-rw@devidian.de

RUN apt update && apt upgrade -y

COPY entrypoint.sh /root/
RUN chmod +x /root/entrypoint.sh

ENTRYPOINT ["/root/entrypoint.sh"]