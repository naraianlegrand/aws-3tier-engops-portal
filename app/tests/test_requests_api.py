def test_create_and_get_request(client, new_request):
    assert new_request["status"] == "open"
    assert new_request["category"] == "revit"

    resp = client.get(f"/api/requests/{new_request['id']}")
    assert resp.status_code == 200
    assert resp.json()["title"] == new_request["title"]


def test_list_and_filter_by_status(client, new_request):
    client.post(
        "/api/requests",
        json={"title": "Need a new MEP template", "category": "template", "requester": "Sam"},
    )
    client.patch(f"/api/requests/{new_request['id']}/status", json={"status": "resolved"})

    all_items = client.get("/api/requests").json()
    assert len(all_items) == 2

    resolved = client.get("/api/requests", params={"status": "resolved"}).json()
    assert [r["id"] for r in resolved] == [new_request["id"]]


def test_update_status(client, new_request):
    resp = client.patch(f"/api/requests/{new_request['id']}/status", json={"status": "in_progress"})
    assert resp.status_code == 200
    assert resp.json()["status"] == "in_progress"


def test_invalid_input_is_rejected(client):
    bad_category = client.post(
        "/api/requests", json={"title": "Something", "category": "pizza", "requester": "Sam"}
    )
    assert bad_category.status_code == 422

    short_title = client.post(
        "/api/requests", json={"title": "x", "category": "revit", "requester": "Sam"}
    )
    assert short_title.status_code == 422


def test_invalid_status_is_rejected(client, new_request):
    resp = client.patch(f"/api/requests/{new_request['id']}/status", json={"status": "done"})
    assert resp.status_code == 422


def test_missing_request_returns_404(client):
    assert client.get("/api/requests/999").status_code == 404
    assert client.patch("/api/requests/999/status", json={"status": "resolved"}).status_code == 404
