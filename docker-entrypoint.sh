#!/bin/bash
set -e

# Warn if the DOCKER_HOST socket does not exist
if [[ $DOCKER_HOST = unix://* ]]; then
	socket_file=${DOCKER_HOST#unix://}
	if ! [ -S $socket_file ]; then
		cat >&2 <<-EOT
			ERROR: you need to share your Docker host socket with a volume at $socket_file
			Typically you should run your jwilder/nginx-proxy with: \`-v /var/run/docker.sock:$socket_file:ro\`
			See the documentation at http://git.io/vZaGJ
		EOT
		socketMissing=1
	fi
fi

# Generate dhparam file if required
# Note: if $DHPARAM_BITS is not defined, generate-dhparam.sh will use 4096 as a default
# Note2: if $DHPARAM_GENERATION is set to false in environment variable, dh param generator will skip completely
/app/generate-dhparam.sh ${DHPARAM_BITS:-4096} ${GENERATE_DHPARAM:-true}


# Compute the DNS resolvers for use in the templates - if the IP contains ":", it's IPv6 and must be enclosed in []
export RESOLVERS=$(awk '$1 == "nameserver" {print ($2 ~ ":")? "["$2"]": $2}' ORS=' ' /etc/resolv.conf | sed 's/ *$//g')
if [ "x$RESOLVERS" = "x" ]; then
    echo "Warning: unable to determine DNS resolvers for nginx" >&2
    unset RESOLVERS
fi

# If the user has run the default command and the socket doesn't exist, fail
if [ "$socketMissing" = 1 -a "$1" = forego -a "$2" = start -a "$3" = '-r' ]; then
	exit 1
fi

[ "x${NGINX_MOD_ENABLE}" != "x" ] && /app/bin/mod_enable.sh || cat /dev/null > /etc/nginx/modules.conf
[ "x${CF_REAL_IP_ENABLE}" != "x" ] && /app/bin/cloudflare-real-ip.sh || rm -f /etc/nginx/conf.d/*real-ip-auto.conf


if [ "x${GEOIP2_ENABLE}" != "x" ]; then
	GEOIPUPDATE_CONF=${GEOIPUPDATE_CONF:-/usr/local/etc/GeoIP.conf}
	GEOIPUPDATE_DATADIR=${GEOIPUPDATE_DATADIR:-/usr/local/share/GeoIP}
	GEOIPUPDATE_EDITION_IDS=${GEOIPUPDATE_EDITION_IDS:-GeoLite2-City GeoLite2-Country}

	if [ "x${GEOIPUPDATE_ACCOUNT_ID}" != "x" ] && [ "x${GEOIPUPDATE_LICENSE_KEY}" != "x" ]; then
		mkdir -p ${GEOIPUPDATE_DATADIR} &> /dev/null
		(
			echo "AccountID ${GEOIPUPDATE_ACCOUNT_ID}"
			echo "LicenseKey ${GEOIPUPDATE_LICENSE_KEY}"
			echo "EditionIDs ${GEOIPUPDATE_EDITION_IDS}"
			echo "DatabaseDirectory ${GEOIPUPDATE_DATADIR}"
		) > ${GEOIPUPDATE_CONF}

		[ "x${GEOIPUPDATE_NO_UPDATE}" == "x" ] && geoipupdate -f ${GEOIPUPDATE_CONF} -v
	else
		echo "geoipupdate disabled. Missing environment variables GEOIPUPDATE_ACCOUNT_ID and/or GEOIPUPDATE_LICENSE_KEY!"
	fi
fi
[ "x${CF_GEOIP2_PROXY_ENABLE}" != "x" ] && /app/bin/cloudflare-geoip2.sh || rm -f /etc/nginx/conf.d/*geoip2-auto.conf

exec "$@"
