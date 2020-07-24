import docker
import pytest


docker_client = docker.from_env()


def test_web1_http_load_module(docker_compose):
    sut_container = docker_client.containers.get("nginxproxy")
    docker_logs = sut_container.logs(stdout=True, stderr=True, stream=False, follow=False)

    assert b"+ 'ngx_http_geoip_module.so'\n" in docker_logs
    assert b"+ 'ngx_http_js_module.so'\n" in docker_logs
    assert b"+ 'ngx_http_xslt_filter_module.so'\n" in docker_logs
    assert b"+ 'ngx_http_image_filter_module.so'\n" in docker_logs
