########################################################################################################################
#
FROM golang:buster as builder
LABEL stage=nginx-proxy-intermediate

RUN apt install -y -q --no-install-recommends \
    git \
    make \
    gcc \
    libc-dev \
    curl

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
#
FROM nginx:mainline
LABEL maintainer="github.com/bugficks/nginx-proxy"

# Install runtime dependencies
RUN apt-get update \
   && apt-get install -y -q --no-install-recommends \
      ca-certificates curl bash openssl \
   && apt-get clean \
   && rm -r /var/lib/apt/lists/*

# Configure Nginx
RUN sed -i '1idaemon off;' /etc/nginx/nginx.conf \
    && sed -i 's/worker_processes  1/worker_processes  auto/' /etc/nginx/nginx.conf

COPY network_internal.conf /etc/nginx/

# Create storage for auto created htpasswd files
VOLUME /etc/nginx/htpasswd

COPY . /app/
COPY --from=builder /build/docker-gen/docker-gen /usr/local/bin/
COPY --from=builder /build/forego/forego /usr/local/bin/
WORKDIR /app/

ENV DOCKER_HOST unix:///tmp/docker.sock

VOLUME ["/etc/nginx/certs", "/etc/nginx/dhparam"]

ENTRYPOINT ["/app/docker-entrypoint.sh"]
CMD ["forego", "start", "-r"]
