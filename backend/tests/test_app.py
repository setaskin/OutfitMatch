"""Tests for backend/app.py.

Covers the pure ranking/filtering logic directly, and the Flask routes via
the test client with the SerpApi/Anthropic calls monkeypatched out — no
real network calls, no API costs, no real keys required.
"""
import io

import pytest
from PIL import Image

import app as app_module
from app import (
    SERPAPI_MAX_BYTES,
    app as flask_app,
    compress_for_upload,
    is_relevant,
    split_exact_and_alternatives,
    to_matches,
    to_shopping_matches,
)


# ---------------------------------------------------------------------------
# split_exact_and_alternatives
# ---------------------------------------------------------------------------

def test_split_empty_list_returns_empty():
    assert split_exact_and_alternatives([], lambda x: x) == []


def test_split_single_item_is_exact_only():
    result = split_exact_and_alternatives([{"price": 50}], lambda x: x["price"])
    assert result == [{"price": 50}]


def test_split_no_cheaper_items_returns_exact_only():
    items = [{"price": 50}, {"price": 60}, {"price": 70}]
    result = split_exact_and_alternatives(items, lambda x: x["price"])
    assert result == [{"price": 50}]


def test_split_cheaper_items_are_sorted_cheapest_first():
    items = [{"price": 50}, {"price": 40}, {"price": 10}, {"price": 30}]
    result = split_exact_and_alternatives(items, lambda x: x["price"])
    assert [i["price"] for i in result] == [50, 10, 30, 40]


def test_split_alternatives_capped_at_five():
    items = [{"price": 100}] + [{"price": p} for p in range(1, 8)]  # 7 cheaper items
    result = split_exact_and_alternatives(items, lambda x: x["price"])
    assert len(result) == 1 + 5
    assert [i["price"] for i in result[1:]] == [1, 2, 3, 4, 5]


# ---------------------------------------------------------------------------
# is_relevant
# ---------------------------------------------------------------------------

def test_is_relevant_matches_keyword_case_insensitively():
    assert is_relevant({"title": "Nike Running SNEAKER"}, "footwear") is True


def test_is_relevant_rejects_unrelated_title():
    assert is_relevant({"title": "Gift Card"}, "footwear") is False


def test_is_relevant_unknown_category_always_true():
    assert is_relevant({"title": "Anything at all"}, "general") is True


def test_is_relevant_missing_title_is_falsy_for_known_category():
    assert is_relevant({}, "footwear") is False


# ---------------------------------------------------------------------------
# to_matches (Google Lens -> app's match shape)
# ---------------------------------------------------------------------------

def test_to_matches_filters_by_category_and_ranks():
    visual_matches = [
        {"title": "Running sneaker", "source": "Nike", "price": {"extracted_value": 80}, "link": "a", "thumbnail": "ta"},
        {"title": "Gift card", "source": "Amazon", "price": {"extracted_value": 10}, "link": "b", "thumbnail": "tb"},
        {"title": "Cheap sneaker", "source": "eBay", "price": {"extracted_value": 40}, "link": "c", "thumbnail": "tc"},
        {"title": "No price sneaker", "source": "eBay", "link": "d"},
    ]
    result = to_matches(visual_matches, "footwear")

    assert [m["title"] for m in result] == ["Running sneaker", "Cheap sneaker"]
    assert result[0]["matchType"] == "exact"
    assert result[1]["matchType"] == "alternative"


def test_to_matches_falls_back_when_category_filter_yields_nothing():
    visual_matches = [
        {"title": "Gift card", "source": "Amazon", "price": {"extracted_value": 10}, "link": "b"},
    ]
    result = to_matches(visual_matches, "footwear")
    assert len(result) == 1
    assert result[0]["title"] == "Gift card"


def test_to_matches_handles_no_priced_results():
    assert to_matches([], "footwear") == []


# ---------------------------------------------------------------------------
# to_shopping_matches (Google Shopping -> app's match shape)
# ---------------------------------------------------------------------------

def test_to_shopping_matches_ranks_by_extracted_price():
    shopping_results = [
        {"title": "Item A", "source": "Store", "extracted_price": 90, "product_link": "a"},
        {"title": "Item B", "source": "Store", "extracted_price": 60, "product_link": "b"},
        {"title": "Item C", "source": "Store"},  # no price -> excluded
    ]
    result = to_shopping_matches(shopping_results)
    assert [m["title"] for m in result] == ["Item A", "Item B"]
    assert result[0]["matchType"] == "exact"
    assert result[1]["matchType"] == "alternative"


# ---------------------------------------------------------------------------
# compress_for_upload
# ---------------------------------------------------------------------------

def test_compress_for_upload_returns_valid_jpeg_under_the_limit():
    small = Image.new("RGB", (200, 200), color=(100, 150, 200))
    buf = io.BytesIO()
    small.save(buf, format="PNG")

    result = compress_for_upload(buf.getvalue())

    assert len(result) <= SERPAPI_MAX_BYTES
    out = Image.open(io.BytesIO(result))
    assert out.format == "JPEG"


def test_compress_for_upload_shrinks_a_large_noisy_image_under_the_limit():
    noisy = Image.effect_noise((2400, 2400), 60).convert("RGB")
    buf = io.BytesIO()
    noisy.save(buf, format="PNG")

    result = compress_for_upload(buf.getvalue())

    assert len(result) <= SERPAPI_MAX_BYTES


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

@pytest.fixture
def client():
    flask_app.config.update(TESTING=True)
    return flask_app.test_client()


def test_health(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.get_json() == {"status": "ok"}


def test_search_requires_serpapi_key(client, monkeypatch):
    monkeypatch.setattr(app_module, "SERPAPI_KEY", None)
    response = client.post("/search", data={})
    assert response.status_code == 500


def test_search_requires_image(client, monkeypatch):
    monkeypatch.setattr(app_module, "SERPAPI_KEY", "test-key")
    response = client.post("/search", data={"category": "footwear"})
    assert response.status_code == 400
    assert "image" in response.get_json()["error"].lower()


def test_search_rejects_empty_image(client, monkeypatch):
    monkeypatch.setattr(app_module, "SERPAPI_KEY", "test-key")
    response = client.post(
        "/search",
        data={"image": (io.BytesIO(b""), "photo.jpg")},
        content_type="multipart/form-data",
    )
    assert response.status_code == 400


def test_search_success_path(client, monkeypatch):
    monkeypatch.setattr(app_module, "SERPAPI_KEY", "test-key")
    monkeypatch.setattr(app_module, "upload_to_serpapi", lambda image_bytes: "fake-image-id")
    monkeypatch.setattr(
        app_module,
        "search_google_lens",
        lambda image_id: [
            {"title": "Running sneaker", "source": "Nike", "price": {"extracted_value": 80}, "link": "a"},
        ],
    )

    photo = Image.new("RGB", (50, 50), color="red")
    buf = io.BytesIO()
    photo.save(buf, format="JPEG")
    buf.seek(0)

    response = client.post(
        "/search",
        data={"category": "footwear", "image": (buf, "photo.jpg")},
        content_type="multipart/form-data",
    )

    assert response.status_code == 200
    matches = response.get_json()["matches"]
    assert len(matches) == 1
    assert matches[0]["matchType"] == "exact"


def test_chat_requires_anthropic_client(client, monkeypatch):
    monkeypatch.setattr(app_module, "anthropic_client", None)
    monkeypatch.setattr(app_module, "SERPAPI_KEY", "test-key")
    response = client.post("/chat", json={"messages": [{"role": "user", "content": "hi"}]})
    assert response.status_code == 500


def test_chat_requires_messages(client, monkeypatch):
    monkeypatch.setattr(app_module, "anthropic_client", object())
    monkeypatch.setattr(app_module, "SERPAPI_KEY", "test-key")
    response = client.post("/chat", json={})
    assert response.status_code == 400


def test_chat_ask_action_skips_search(client, monkeypatch):
    monkeypatch.setattr(app_module, "anthropic_client", object())
    monkeypatch.setattr(app_module, "SERPAPI_KEY", "test-key")
    monkeypatch.setattr(
        app_module, "get_chat_decision", lambda history: {"action": "ask", "message": "What color?"}
    )

    response = client.post("/chat", json={"messages": [{"role": "user", "content": "I want shoes"}]})

    assert response.status_code == 200
    body = response.get_json()
    assert body["action"] == "ask"
    assert "matches" not in body


def test_chat_search_action_returns_ranked_matches(client, monkeypatch):
    monkeypatch.setattr(app_module, "anthropic_client", object())
    monkeypatch.setattr(app_module, "SERPAPI_KEY", "test-key")
    monkeypatch.setattr(
        app_module,
        "get_chat_decision",
        lambda history: {"action": "search", "message": "Here you go", "query": "pink sneakers"},
    )
    monkeypatch.setattr(
        app_module,
        "search_google_shopping",
        lambda query: [{"title": "Pink sneaker", "source": "Nike", "extracted_price": 70, "product_link": "a"}],
    )

    response = client.post("/chat", json={"messages": [{"role": "user", "content": "pink sneakers"}]})

    assert response.status_code == 200
    body = response.get_json()
    assert body["action"] == "search"
    assert len(body["matches"]) == 1


def test_style_advice_requires_image(client, monkeypatch):
    monkeypatch.setattr(app_module, "anthropic_client", object())
    monkeypatch.setattr(app_module, "SERPAPI_KEY", "test-key")
    response = client.post("/style-advice", data={"question": "what shoes?"})
    assert response.status_code == 400


def test_style_advice_requires_question(client, monkeypatch):
    monkeypatch.setattr(app_module, "anthropic_client", object())
    monkeypatch.setattr(app_module, "SERPAPI_KEY", "test-key")
    photo = Image.new("RGB", (50, 50), color="blue")
    buf = io.BytesIO()
    photo.save(buf, format="JPEG")
    buf.seek(0)

    response = client.post(
        "/style-advice",
        data={"image": (buf, "photo.jpg")},
        content_type="multipart/form-data",
    )
    assert response.status_code == 400


def test_style_advice_success_path(client, monkeypatch):
    monkeypatch.setattr(app_module, "anthropic_client", object())
    monkeypatch.setattr(app_module, "SERPAPI_KEY", "test-key")
    monkeypatch.setattr(
        app_module,
        "get_style_advice",
        lambda image_bytes, question: {
            "advice": "Try white sneakers.",
            "recommendations": [{"label": "White sneakers", "query": "white sneakers"}],
        },
    )
    monkeypatch.setattr(
        app_module,
        "search_google_shopping",
        lambda query: [{"title": "White sneaker", "source": "Nike", "extracted_price": 55, "product_link": "a"}],
    )

    photo = Image.new("RGB", (50, 50), color="green")
    buf = io.BytesIO()
    photo.save(buf, format="JPEG")
    buf.seek(0)

    response = client.post(
        "/style-advice",
        data={"question": "what shoes go with this?", "image": (buf, "photo.jpg")},
        content_type="multipart/form-data",
    )

    assert response.status_code == 200
    body = response.get_json()
    assert body["advice"] == "Try white sneakers."
    assert len(body["recommendations"]) == 1
    assert len(body["recommendations"][0]["matches"]) == 1
