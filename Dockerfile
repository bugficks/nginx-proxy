########################################################################################################################
#
FROM golang:buster as go-builder
LABEL stage=nginx-proxy-intermediate

RUN apt install -y -q --no-install-recommends \
    git \
    make \
    gcc \
    libc-dev \
    curl \
    && git config --global advice.detachedHead false

########################################################################################################################

RUN \
    DOCKER_GEN_TAG=${DOCKER_GEN_TAG:-$(curl -fsSLI -o /dev/null -w %{url_effective} https://github.com/bugficks/docker-gen/releases/latest | awk -F / '{print $NF}')} \
    && git clone https://github.com/bugficks/docker-gen --single-branch --branch ${DOCKER_GEN_TAG} --depth 1 /build/docker-gen

WORKDIR /build/docker-gen
RUN make check-gofmt all

########################################################################################################################

RUN \
    FOREGO_TAG=${FOREGO_TAG:-$(curl -fsSLI -o /dev/null -w %{url_effective} https://github.com/bugficks/forego/releases/latest | awk -F / '{print $NF}')} \
    && git clone https://github.com/bugficks/forego --single-branch --branch ${FOREGO_TAG} --depth 1 /build/forego

WORKDIR /build/forego
RUN make lint build

########################################################################################################################

RUN \
    GEOIPUPDATE_TAG=${GEOIPUPDATE_TAG:-$(curl -fsSLI -o /dev/null -w %{url_effective} https://github.com/maxmind/geoipupdate/releases/latest | awk -F / '{print $NF}')} \
    && git clone https://github.com/maxmind/geoipupdate --single-branch --branch ${GEOIPUPDATE_TAG} --depth 1 /build/geoipupdate

WORKDIR /build/geoipupdate
RUN \
  echo "#!/bin/sh" > /usr/local/bin/perl && \
  chmod +x /usr/local/bin/perl && \
  make VERSION=$(git describe --tags) \
  && rm -f /usr/local/bin/perl

########################################################################################################################
#
FROM nginx:mainline as nginx-builder
LABEL stage=nginx-proxy-intermediate

RUN sed 's:^deb:deb-src:g' /etc/apt/sources.list > /etc/apt/sources.list.d/deb-src.list \
    && apt-get update \
    && apt-get install --no-install-recommends --no-install-suggests -y  \
        bash git vim make curl \
        libmaxminddb0 libmaxminddb-dev mmdb-bin \
    && apt-get build-dep -y --no-install-recommends nginx \
    && git config --global advice.detachedHead false

WORKDIR /build
RUN curl -sL https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz | tar xzv -C /build

RUN \
    MOD_GEOIP2_VER=${MOD_GEOIP2_VER:-$(curl -fsSLI -o /dev/null -w %{url_effective} https://github.com/leev/ngx_http_geoip2_module/releases/latest | awk -F / '{print $NF}')} \
    && git clone https://github.com/leev/ngx_http_geoip2_module --single-branch --branch ${MOD_GEOIP2_VER} --depth 1 /build/ngx_http_geoip2_module

WORKDIR /build/nginx-${NGINX_VERSION}/
RUN \
  echo "#!/bin/sh" > build.sh && \
  nginx -V 2>&1 | grep "configure arguments:.*"  | sed 's/^configure arguments: /.\/configure /g' >> build.sh && \
  truncate -s -1 build.sh && \
  printf " --add-dynamic-module=/build/ngx_http_geoip2_module" >> build.sh && \
  chmod +x build.sh && \
  ./build.sh && \
  make modules

# modules are in /build/nginx-1.19.1/objs/
# - ngx_http_geoip2_module.so
# - ngx_stream_geoip2_module.so
# + apt install libmaxminddb0 mmdb-bin

########################################################################################################################
#
FROM nginx:mainline
LABEL maintainer="github.com/bugficks/nginx-proxy"

# Install runtime dependencies
RUN apt-get update \
   && apt-get install -y -q --no-install-recommends \
      ca-certificates curl bash openssl \
      libmaxminddb0 mmdb-bin \
   && update-ca-certificates \
   && apt-get clean \
   && rm -r /var/lib/apt/lists/*

# Configure Nginx
RUN sed -i '1idaemon off;' /etc/nginx/nginx.conf \
    && sed -i '2iinclude /etc/nginx/modules.conf;' /etc/nginx/nginx.conf \
    && sed -i 's/worker_processes  1/worker_processes  auto/' /etc/nginx/nginx.conf

COPY network_internal.conf /etc/nginx/

COPY . /app/
COPY --from=go-builder /build/docker-gen/docker-gen /usr/local/bin/
COPY --from=go-builder /build/forego/forego /usr/local/bin/
COPY --from=go-builder /build/geoipupdate/build/geoipupdate /usr/local/bin/
COPY --from=go-builder /build/geoipupdate/build/GeoIP.conf /usr/local/etc/
COPY --from=nginx-builder /build/nginx-${NGINX_VERSION}/objs/ngx_*_geoip2_module.so /etc/nginx/modules/
WORKDIR /app/

ENV DOCKER_HOST unix:///tmp/docker.sock

VOLUME ["/etc/nginx/certs", "/etc/nginx/dhparam", "/etc/nginx/htpasswd", "/usr/local/share/GeoIP" ]

ENTRYPOINT ["/app/docker-entrypoint.sh"]
CMD ["forego", "start", "-r"]
