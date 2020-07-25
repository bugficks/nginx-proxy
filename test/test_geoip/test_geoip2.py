import docker
import pytest


docker_client = docker.from_env()


def test_web1_http_geoip2_conf(docker_compose, nginxproxy):
    assert b'$geoip2_country_code' in nginxproxy.get_conf()

def test_web1_http_geoip2_module(docker_compose, nginxproxy):
    sut_container = docker_client.containers.get("nginxproxy")
    docker_logs = sut_container.logs(stdout=True, stderr=True, stream=False, follow=False)

    assert b"+ 'ngx_http_geoip2_module.so'\n" in docker_logs

def test_web1_http_geoip2_country_code(docker_compose, nginxproxy):
    headers={
        'X-Forwarded-For': '8.8.8.8',
    }
    r = nginxproxy.get("http://web1.nginx-proxy.tld/headers", headers=headers)

    assert 'X-GeoIP-Country-Code:' in r.text
    # requires `set_real_ip_from local networks`
    assert 'X-GeoIP-Country-Code: US' in r.text
    assert r.status_code == 200


def test_web1_http_geoip2_country(docker_compose, nginxproxy):
    headers={
        'X-Forwarded-For': '8.8.8.8',
    }
    r = nginxproxy.get("http://web1.nginx-proxy.tld/headers", headers=headers)

    assert 'X-GeoIP-Country:' in r.text
    # requires `set_real_ip_from local networks`
    assert 'X-GeoIP-Country: United States' in r.text
    assert r.status_code == 200

def test_web1_http_geoip2_city(docker_compose, nginxproxy):
    headers={
        'X-Forwarded-For': '8.8.8.8',
    }
    r = nginxproxy.get("http://web1.nginx-proxy.tld/headers", headers=headers)

    print(r.text)
    assert 'X-GeoIP-City:' in r.text
    # requires `set_real_ip_from local networks`
    assert 'X-GeoIP-City: Lake Saint Louis' in r.text
    assert r.status_code == 200

def test_web1_http_geoip2_region(docker_compose, nginxproxy):
    headers={
        'X-Forwarded-For': '8.8.8.8',
    }
    r = nginxproxy.get("http://web1.nginx-proxy.tld/headers", headers=headers)

    assert 'X-GeoIP-Region:' in r.text
    # requires `set_real_ip_from local networks`
    assert 'X-GeoIP-Region: Missouri' in r.text
    assert r.status_code == 200

def test_web1_http_geoip2_cf(docker_compose, nginxproxy):
    headers={
        'X-Forwarded-For': '8.8.8.8',
        'CF-IPCountry': 'ZZ'
    }
    r = nginxproxy.get("http://web1.nginx-proxy.tld/headers", headers=headers)

    assert 'X-GeoIP-Country-Code: ZZ' in r.text
    assert r.status_code == 200
