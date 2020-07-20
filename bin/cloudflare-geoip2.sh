#!/bin/bash

# https://support.cloudflare.com/hc/en-us/articles/200170786

########################################################################################################################

CFG=${CFG:-/etc/nginx/conf.d/10-cloudflare-geoip2-auto.conf}
URL4=https://www.cloudflare.com/ips-v4
URL6=https://www.cloudflare.com/ips-v6

# allow either command line or env variable, command line has priority
CF_GEOIP2_PROXY_RECURSIVE=${1:-${CF_GEOIP2_PROXY_RECURSIVE:-off}}

LOG_PREFIX="cf-geoip2-proxy:"

########################################################################################################################

echo "${LOG_PREFIX} Fetching Cloudflare IPs"
IPs=$(curl -sfL ${URL4} ${URL6})

if [ "x${IPs}" != "x" ]; then
(
    echo "# This file is automatically generated."

    for ip in ${IPs}; do
        echo "geoip2_proxy ${ip};";
    done;
    echo "geoip2_proxy_recursive ${CF_GEOIP2_PROXY_RECURSIVE};"
) > /tmp/cloudflare-geoip2.conf

    if ! $(diff -q /tmp/cloudflare-geoip2.conf ${CFG} > /dev/null 2>&1); then
        echo "${LOG_PREFIX} Updating '${CFG}'"
        cp /tmp/cloudflare-geoip2.conf ${CFG}
        pidof -s nginx && nginx -s reload &> /dev/null
    else
        echo "${LOG_PREFIX} '${CFG}' did not change"
    fi
fi

exit 0
