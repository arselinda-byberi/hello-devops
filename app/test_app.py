import pytest

from app import app


@pytest.fixture
def client():
    app.config["TESTING"] = True
    with app.test_client() as c:
        yield c


def test_index_returns_message(client):
    resp = client.get("/")
    assert resp.status_code == 200
    body = resp.get_json()
    assert "message" in body
    assert "hostname" in body


def test_healthz(client):
    resp = client.get("/healthz")
    assert resp.status_code == 200
    assert resp.get_json()["status"] == "ok"


def test_readyz(client):
    resp = client.get("/readyz")
    assert resp.status_code == 200
    assert resp.get_json()["status"] == "ready"


def test_version(client):
    resp = client.get("/version")
    assert resp.status_code == 200
    assert "version" in resp.get_json()
