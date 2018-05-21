FROM omisegoimages/base:stretch

ADD ewallet.tar.gz /app
WORKDIR /app

RUN set -xe && \
    groupadd -r ewallet && \
    useradd -r -g ewallet ewallet && \
    chown -R ewallet /app

ENV PORT 4000

EXPOSE 4000
EXPOSE 4369
EXPOSE 6900 6901 6902 6903 6904 6905 6906 6907 6908 6909

RUN set -xe && \
    SERVICE_DIR=/etc/services.d/ewallet/ && \
    mkdir -p "$SERVICE_DIR" && \
    echo '#!/bin/execlineb -P' > $SERVICE_DIR/run && \
    echo 'with-contenv' >> $SERVICE_DIR/run && \
    echo 'cd /app' >> $SERVICE_DIR/run && \
    echo 's6-setuidgid ewallet' >> $SERVICE_DIR/run && \
    echo 'backtick -n default_host { s6-hostname }' >> $SERVICE_DIR/run && \
    echo 'importas -iu default_host default_host' >> $SERVICE_DIR/run && \
    echo 'importas -D $default_host NODE_HOST NODE_HOST' >> $SERVICE_DIR/run && \
    echo 's6-env NODE_HOST=$NODE_HOST' >> $SERVICE_DIR/run && \
    echo 'backtick -n default_cookie { openssl rand -hex 8 }' >> $SERVICE_DIR/run && \
    echo 'importas -iu default_cookie default_cookie' >> $SERVICE_DIR/run && \
    echo 'importas -D $default_cookie ERLANG_COOKIE ERLANG_COOKIE' >> $SERVICE_DIR/run && \
    echo 's6-env ERLANG_COOKIE=$ERLANG_COOKIE' >> $SERVICE_DIR/run && \
    echo 'importas -D ewallet NODE_NAME NODE_NAME' >> $SERVICE_DIR/run && \
    echo 's6-env NODE_NAME=$NODE_NAME' >> $SERVICE_DIR/run && \
    echo 'importas -D localhost NODE_DNS NODE_DNS' >> $SERVICE_DIR/run && \
    echo 's6-env NODE_DNS=$NODE_DNS' >> $SERVICE_DIR/run && \
    echo 's6-env HOME=/app' >> $SERVICE_DIR/run && \
    echo 's6-env REPLACE_OS_VARS=yes' >> $SERVICE_DIR/run && \
    echo '/app/bin/ewallet foreground' >> $SERVICE_DIR/run && \
    echo '#!/bin/execlineb -S1' > $SERVICE_DIR/finish && \
    echo 'if { s6-test ${1} -ne 0 }' >> $SERVICE_DIR/finish && \
    echo 'if { s6-test ${1} -ne 256 }' >> $SERVICE_DIR/finish && \
    echo 's6-svscanctl -t /var/run/s6/services' >> $SERVICE_DIR/finish

ENTRYPOINT ["/init"]