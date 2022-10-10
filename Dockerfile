FROM ubuntu

LABEL maintainer="kasen@kasen.win" repository="https://github.com/yaule/postfix-server"

ARG DEBIAN_FRONTEND="noninteractive"

RUN apt update && apt upgrade -yqq && apt install --no-install-recommends -yqq rsyslog sendemail postfix opendkim opendkim-tools openssl curl && apt autoremove -yqq && apt clean all && rm -rf /var/log/*

VOLUME [ "/etc/dkimkeys/" ]

ENV DOMAIN_NAME SELECTOR_NAME DKIMDOMAIN

ADD start.sh /start.sh

EXPOSE 25

CMD [ "sh", "/start.sh" ]