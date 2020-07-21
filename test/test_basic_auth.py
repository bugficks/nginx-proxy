import pytest
from requests import ConnectionError



def test_basic_auth_to_web1(docker_compose, nginxproxy):
    r = nginxproxy.get("http://web1.nginx-proxy.tld/port", auth=('user', 'password'))
    assert r.status_code == 200
    assert r.text == "answer from port 81\n"

def test_basic_auth_fail_to_web1(docker_compose, nginxproxy):
    r = nginxproxy.get("http://web1.nginx-proxy.tld/port")
    assert r.status_code == 401

