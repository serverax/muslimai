import requests
import pytest

BASE_URL = "http://localhost:8080/v1"


@pytest.fixture
def client():
    return requests.Session()


def test_health_check(client):
    response = client.get(f"{BASE_URL}/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"


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


def test_classify_intent(client):
    payload = {"text": "Is music permissible in Islam?"}
    response = client.post(f"{BASE_URL}/classify", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert "intent" in data
    assert "confidence" in data
