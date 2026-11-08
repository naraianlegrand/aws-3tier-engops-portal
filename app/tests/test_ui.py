def test_index_renders(client, new_request):
    resp = client.get("/")
    assert resp.status_code == 200
    assert "EngOps Portal" in resp.text
    assert new_request["title"] in resp.text


def test_create_via_form_redirects_to_detail(client):
    resp = client.post(
        "/requests",
        data={"title": "AutoCAD license error", "category": "autocad", "requester": "Lee"},
        follow_redirects=False,
    )
    assert resp.status_code == 303
    detail = client.get(resp.headers["location"])
    assert "AutoCAD license error" in detail.text


def test_form_validation_errors_are_shown(client):
    resp = client.post("/requests", data={"title": "x", "category": "revit", "requester": "Lee"})
    assert resp.status_code == 422
    assert "title" in resp.text


def test_html_is_escaped(client):
    client.post(
        "/api/requests",
        json={"title": "<script>alert(1)</script>", "category": "other", "requester": "Eve"},
    )
    resp = client.get("/")
    assert "<script>alert(1)</script>" not in resp.text
    assert "&lt;script&gt;" in resp.text
