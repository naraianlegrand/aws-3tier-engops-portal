from engops.storage import new_storage_key, safe_filename


def test_upload_and_download(client, new_request):
    rid = new_request["id"]
    resp = client.post(
        f"/api/requests/{rid}/attachments",
        files={"file": ("crash log.txt", b"Revit.exe stopped working", "text/plain")},
    )
    assert resp.status_code == 201
    att = resp.json()
    assert att["filename"] == "crash_log.txt"
    assert att["size_bytes"] == len(b"Revit.exe stopped working")

    detail = client.get(f"/api/requests/{rid}").json()
    assert len(detail["attachments"]) == 1

    download = client.get(f"/api/requests/{rid}/attachments/{att['id']}")
    assert download.status_code == 200
    assert download.content == b"Revit.exe stopped working"
    # Always served as a download, never rendered.
    assert download.headers["content-type"] == "application/octet-stream"
    assert download.headers["content-disposition"].startswith("attachment;")


def test_upload_too_large_is_rejected(client, new_request):
    too_big = b"x" * (1024 * 1024 + 1)  # test settings allow 1 MB
    resp = client.post(
        f"/api/requests/{new_request['id']}/attachments",
        files={"file": ("big.bin", too_big, "application/octet-stream")},
    )
    assert resp.status_code == 413


def test_attachment_from_other_request_is_404(client, new_request):
    rid = new_request["id"]
    att = client.post(
        f"/api/requests/{rid}/attachments", files={"file": ("a.txt", b"hello", "text/plain")}
    ).json()
    other = client.post(
        "/api/requests", json={"title": "Other request", "category": "other", "requester": "Sam"}
    ).json()
    assert client.get(f"/api/requests/{other['id']}/attachments/{att['id']}").status_code == 404


def test_safe_filename_strips_paths_and_odd_characters():
    assert safe_filename("../../etc/passwd") == "passwd"
    assert safe_filename("C:\\Users\\me\\model v2.rvt") == "model_v2.rvt"
    assert safe_filename("") == "file"
    assert safe_filename(None) == "file"


def test_storage_keys_stay_under_uploads_prefix():
    # The EC2 IAM policy only allows uploads/* and reports/*.
    assert new_storage_key(7, "a.txt").startswith("uploads/7/")
