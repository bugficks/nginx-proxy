#!/bin/bash
set -o noglob

########################################################################################################################
#NGINX_MOD_ENABLE="ngx_http_geoip2_module x ngx_http_xslt_filter"
#NGINX_MOD_ENABLE=.*http.*

# allow either command line or env variable, command line has priority
NGINX_MOD_ENABLE=${*:-${NGINX_MOD_ENABLE}}

NGINX_MOD_DIR=${NGINX_MOD_DIR:-/usr/lib/nginx/modules}
NGINX_MOD_CONF=${NGINX_MOD_CONF:-/etc/nginx/modules.conf}

########################################################################################################################

_MODS_NOTFOUND=${NGINX_MOD_ENABLE}

########################################################################################################################

# no mod dir, no mods...
if [ ! -d ${NGINX_MOD_DIR} ]; then
    echo "NGINX_MOD_DIR does not exist: '${NGINX_MOD_DIR}'"
    exit 1
fi

for arg in "$@"; do
    case $arg in
        -l|--list)
            echo "Available modules:"
            find ${NGINX_MOD_DIR}/ -type f -name *module.so -exec basename {} \; | sed -e "s/^/- /g"
            exit 0
            ;;
        *)  ;;
    esac
done

# always create new config with enabled modules
cat /dev/null > ${NGINX_MOD_CONF}

[ "x${NGINX_MOD_ENABLE}" == "x" ] && exit 0

for M in $(find ${NGINX_MOD_DIR}/ -type f -name *module.so); do
    for E in ${NGINX_MOD_ENABLE}; do
        if [[ ${M} =~ (ngx_)?${E}(_module)?(.so)?$ ]]; then
            echo "load_module \"${M}\";" >> ${NGINX_MOD_CONF}

            _MODS_ENABLED="${_MODS_ENABLED} $(basename ${M})"
            _MODS_NOTFOUND=${_MODS_NOTFOUND//${E}/}
            break
        fi
    done
done

if [ "x${_MODS_ENABLED}" != "x" ]; then
    echo "Module(s) enabled:"
    for M in ${_MODS_ENABLED}; do
        echo "+ '$(basename ${M})'"
    done
fi

# trim spaces
_MODS_NOTFOUND=$(echo ${_MODS_NOTFOUND} | xargs)

if [ "x${_MODS_NOTFOUND}" != "x" ]; then
    echo "Module(s) not found:"
    for M in ${_MODS_NOTFOUND}; do
        echo "- '${M}'"
    done
fi
