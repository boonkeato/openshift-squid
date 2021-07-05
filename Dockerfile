FROM ubuntu:bionic-20190612
LABEL maintainer="boonkeat@gmail.com"

ENV SQUID_VERSION=3.5.27 \
    SQUID_CACHE_DIR=/var/spool/squid \
    SQUID_LOG_DIR=/var/log/squid

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y squid=${SQUID_VERSION}* \
 && rm -rf /var/lib/apt/lists/*

RUN mkdir -p ${SQUID_CACHE_DIR} \
 && mkdir -p ${SQUID_LOG_DIR} \
 && mkdir -p /var/run/squid

RUN chgrp -R 0 /etc/squid \
 && chmod -R g+rwX /etc/squid \
 && chgrp -R 0 ${SQUID_CACHE_DIR} \
 && chmod -R g+rwX ${SQUID_CACHE_DIR} \
 && chgrp -R 0 ${SQUID_LOG_DIR} \
 && chmod -R g+rwX ${SQUID_LOG_DIR} \
 && chgrp -R 0 /var/run/squid \
 && chmod -R g+rwX /var/run/squid

COPY entrypoint.sh /sbin/entrypoint.sh
RUN chmod 775 /sbin/entrypoint.sh

USER 10000

EXPOSE 3128/tcp
ENTRYPOINT ["/sbin/entrypoint.sh"]
