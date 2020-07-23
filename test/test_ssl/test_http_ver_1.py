import pytest

import docker
docker_client = docker.from_env()

def test_web1_http_ver_1(docker_compose, nginxproxy):
    sut_container = docker_client.containers.get("nginxproxy")

    exit_code, http_version = sut_container.exec_run("curl -sIk -H 'Host: web1.nginx-proxy.tld/port' https://localhost -o/dev/null -w '%{http_version}'\n")

    assert float(http_version) in [ 1.0, 1.1 ]


