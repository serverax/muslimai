import requests
import pytest
import uuid
import os

API_ROOT = "http://localhost:8080"
BASE_URL = f"{API_ROOT}/v1"
API_TOKEN = os.getenv("SAKINA_API_TOKEN", "local-dev-token")


@pytest.fixture
def client():
    session = requests.Session()
    session.headers.update(
        {
            "Authorization": f"Bearer {API_TOKEN}",
            "x-sakina-user-id": "550e8400-e29b-41d4-a716-446655440000",
        }
    )
    return session


def test_health_check(client):
    response = client.get(f"{BASE_URL}/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"


def test_metrics_endpoint(client):
    response = client.get(f"{API_ROOT}/metrics")
    assert response.status_code == 200
    assert "sakina_verified_chunks_total" in response.text


def test_rag_query(client):
    payload = {
        "query": "Is music permissible in Islam?",
        "user_id": "550e8400-e29b-41d4-a716-446655440000",
        "madhhab_filter": "hanafi"
    }
    response = client.post(f"{BASE_URL}/rag/query", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert "answer" in data
    assert "sources" in data
    assert "guardrail_triggered" in data


def test_classify_intent(client):
    payload = {"text": "Is music permissible in Islam?"}
    response = client.post(f"{BASE_URL}/classify", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert "intent" in data
    assert "confidence" in data


def test_user_and_backup_contract(client):
    client.headers["x-sakina-user-id"] = "550e8400-e29b-41d4-a716-446655440000"
    user_response = client.post(
        f"{BASE_URL}/users",
        json={
            "pub_key": f"pytest-{uuid.uuid4()}",
            "madhhab_preference": "hanafi",
        },
    )
    assert user_response.status_code == 201
    user = user_response.json()
    assert user["id"]
    client.headers["x-sakina-user-id"] = user["id"]

    backup_response = client.post(
        f"{BASE_URL}/sync/backup/{user['id']}",
        json={"data": "encrypted-test-backup"},
    )
    assert backup_response.status_code == 200
    assert backup_response.json()["backup_hash"]

    restore_response = client.get(f"{BASE_URL}/sync/backup/{user['id']}")
    assert restore_response.status_code == 200
    assert restore_response.json()["data"] == "encrypted-test-backup"


def test_dashboard_guardrails_contract(client):
    client.headers["x-sakina-user-id"] = "550e8400-e29b-41d4-a716-446655440000"
    response = client.get(f"{BASE_URL}/dashboard/guardrails")
    assert response.status_code == 200
    assert isinstance(response.json(), list)
