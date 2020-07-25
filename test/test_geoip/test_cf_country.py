import docker
import pytest


docker_client = docker.from_env()


def test_web1_http_cf_no_geoip2_conf(docker_compose, nginxproxy):
    assert b'$geoip2_country_code' not in nginxproxy.get_conf()

def test_web1_http_cf_no_geoip2_module(docker_compose, nginxproxy):
    sut_container = docker_client.containers.get("nginxproxy")
    docker_logs = sut_container.logs(stdout=True, stderr=True, stream=False, follow=False)

    assert b"+ 'ngx_http_geoip2_module.so'\n" not in docker_logs

def test_web1_http_cf_country_code_default(docker_compose, nginxproxy):
    headers={
        'X-Forwarded-For': '8.8.8.8',
    }
    r = nginxproxy.get("http://web1.nginx-proxy.tld/headers", headers=headers)

    assert 'X-GeoIP-Country-Code: XX' in r.text
    assert r.status_code == 200

def test_web1_http_cf_country_code(docker_compose, nginxproxy):
    headers={
        'X-Forwarded-For': '8.8.8.8',
        'CF-IPCountry': 'ZZ'
    }
    r = nginxproxy.get("http://web1.nginx-proxy.tld/headers", headers=headers)

    assert 'X-GeoIP-Country-Code: ZZ' in r.text
    assert r.status_code == 200
