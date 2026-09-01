"""
Backend proxy for OutfitMatch's product search.

The iOS app never talks to SerpApi directly (the API key would be
extractable from the app binary). Instead it uploads the photo here,
and this server does the SerpApi calls and returns simplified results.
"""

import base64
import io
import json
import os

import anthropic
import requests
from dotenv import load_dotenv
from flask import Flask, jsonify, request
from PIL import Image

load_dotenv()

SERPAPI_KEY = os.environ.get("SERPAPI_KEY")
SERPAPI_MAX_BYTES = 500 * 1024  # SerpApi's image upload limit

app = Flask(__name__)

ANTHROPIC_API_KEY = os.environ.get("ANTHROPIC_API_KEY")
ANTHROPIC_WORKSPACE_ID = os.environ.get("ANTHROPIC_WORKSPACE_ID")
# Constructed lazily so a missing key doesn't crash the whole server at
# startup — /search should keep working even before this key is set.
anthropic_client = (
    anthropic.Anthropic(
        api_key=ANTHROPIC_API_KEY,
        # Identity-linked keys (e.g. from Google/SSO sign-in) require this
        # header on every request; plain keys ignore it.
        default_headers=(
            {"anthropic-workspace-id": ANTHROPIC_WORKSPACE_ID} if ANTHROPIC_WORKSPACE_ID else None
        ),
    )
    if ANTHROPIC_API_KEY
    else None
)


def compress_for_upload(image_bytes):
    """Resize/recompress the photo so it's under SerpApi's 500KB upload limit."""
    image = Image.open(io.BytesIO(image_bytes)).convert("RGB")

    max_dimension = 1600
    quality = 85

    while True:
        resized = image.copy()
        resized.thumbnail((max_dimension, max_dimension))
        buffer = io.BytesIO()
        resized.save(buffer, format="JPEG", quality=quality)
        data = buffer.getvalue()

        if len(data) <= SERPAPI_MAX_BYTES or (max_dimension <= 400 and quality <= 40):
            return data

        if quality > 40:
            quality -= 15
        else:
            max_dimension = int(max_dimension * 0.75)


def upload_to_serpapi(image_bytes):
    response = requests.post(
        "https://serpapi.com/image",
        params={"api_key": SERPAPI_KEY},
        files={"image": ("photo.jpg", image_bytes, "image/jpeg")},
        timeout=30,
    )
    response.raise_for_status()
    data = response.json()
    if "image_id" not in data:
        raise RuntimeError(data.get("message", "SerpApi image upload failed"))
    return data["image_id"]


def search_google_lens(image_id):
    response = requests.get(
        "https://serpapi.com/search",
        params={
            "engine": "google_lens",
            "image_id": image_id,
            "type": "products",
            "api_key": SERPAPI_KEY,
        },
        timeout=30,
    )
    response.raise_for_status()
    return response.json().get("visual_matches", [])


CATEGORY_KEYWORDS = {
    "footwear": ["shoe", "sneaker", "boot", "sandal", "heel", "trainer", "footwear"],
    "outerwear": ["jacket", "coat", "blazer"],
    "dress": ["dress", "gown"],
    "top": ["shirt", "blouse", "sweater", "hoodie", "cardigan", "tee", "top"],
    "bottom": ["pant", "trouser", "jean", "skirt", "short"],
}


def is_relevant(item, category):
    keywords = CATEGORY_KEYWORDS.get(category)
    if not keywords:
        return True
    title = item.get("title", "").lower()
    return any(keyword in title for keyword in keywords)


def split_exact_and_alternatives(priced_items, get_price):
    """Shared ranking rule: the first (highest-ranked) priced item is the
    closest match; anything genuinely cheaper than it becomes an
    alternative, cheapest first."""
    if not priced_items:
        return []

    exact = priced_items[0]
    exact_price = get_price(exact)
    alternatives = sorted(
        (item for item in priced_items[1:] if get_price(item) < exact_price),
        key=get_price,
    )
    return [exact] + alternatives[:5]


def to_matches(visual_matches, category):
    """Keep only results with real price data whose title actually matches
    the detected clothing category (Lens mixes in unrelated visual matches
    like stickers or gift cards that happen to have price data)."""
    relevant = [m for m in visual_matches if is_relevant(m, category)]
    priced = [m for m in relevant if m.get("price", {}).get("extracted_value") is not None]

    if not priced:
        # Category filter may have been too strict, or Lens just didn't
        # find priced matches for this category — fall back to any priced
        # result rather than showing nothing.
        priced = [m for m in visual_matches if m.get("price", {}).get("extracted_value") is not None]

    ranked = split_exact_and_alternatives(priced, lambda m: m["price"]["extracted_value"])

    return [
        {
            "title": item.get("title", "Unknown item"),
            "retailer": item.get("source", "Unknown"),
            "price": item["price"]["extracted_value"],
            "link": item.get("link"),
            "thumbnail": item.get("thumbnail"),
            "matchType": "exact" if index == 0 else "alternative",
        }
        for index, item in enumerate(ranked)
    ]


def search_google_shopping(query):
    response = requests.get(
        "https://serpapi.com/search",
        params={"engine": "google_shopping", "q": query, "api_key": SERPAPI_KEY},
        timeout=30,
    )
    response.raise_for_status()
    return response.json().get("shopping_results", [])


def to_shopping_matches(shopping_results):
    priced = [r for r in shopping_results if r.get("extracted_price") is not None]
    ranked = split_exact_and_alternatives(priced, lambda r: r["extracted_price"])

    return [
        {
            "title": item.get("title", "Unknown item"),
            "retailer": item.get("source", "Unknown"),
            "price": item["extracted_price"],
            "link": item.get("product_link"),
            "thumbnail": item.get("thumbnail"),
            "matchType": "exact" if index == 0 else "alternative",
        }
        for index, item in enumerate(ranked)
    ]


CHAT_SYSTEM_PROMPT = """You are a friendly shopping assistant inside the OutfitMatch app. \
The user will describe a clothing or footwear item they want to buy. Your job is to figure \
out enough detail to run a good product search — typically the item type, color, and style, \
and budget if they mention one. Ask at most 2-3 short, conversational follow-up questions, \
one at a time. Once you have enough detail, stop asking and produce a concise search query \
(item + color + style keywords, suitable for a Google Shopping search).

Respond with JSON matching this shape:
{"action": "ask" or "search", "message": "your reply to show the user", "query": "search query, only when action is search"}"""

CHAT_OUTPUT_SCHEMA = {
    "type": "json_schema",
    "schema": {
        "type": "object",
        "properties": {
            "action": {"type": "string", "enum": ["ask", "search"]},
            "message": {"type": "string"},
            "query": {"type": ["string", "null"]},
        },
        "required": ["action", "message", "query"],
        "additionalProperties": False,
    },
}


def get_chat_decision(history):
    response = anthropic_client.messages.create(
        model="claude-opus-5",
        max_tokens=1024,
        system=CHAT_SYSTEM_PROMPT,
        messages=history,
        output_config={"format": CHAT_OUTPUT_SCHEMA},
    )
    text = next(block.text for block in response.content if block.type == "text")
    return json.loads(text)


STYLE_ADVICE_SYSTEM_PROMPT = """You are a fashion stylist inside the OutfitMatch app. The \
user will show you a photo — of themselves, an outfit, or a single item — and ask a styling \
question, e.g. what shoes to pair with the jeans they're wearing, or what would go with a \
piece shown in the photo. Actually look at what's in the photo (colors, fit, style) and \
answer their specific question, honoring any style/vibe they mention (e.g. "casual Gen Z").

Give a short (2-3 sentence) styling explanation, then 2-3 concrete, specific product \
recommendations that fit — specific enough to shop for (e.g. "white chunky dad sneakers", \
not just "sneakers"). Each needs a short display label and a search-engine-friendly query \
string suitable for a Google Shopping search.

Respond with JSON matching this shape:
{"advice": "your styling explanation", "recommendations": [{"label": "short display name", "query": "shopping search query"}]}"""

STYLE_ADVICE_OUTPUT_SCHEMA = {
    "type": "json_schema",
    "schema": {
        "type": "object",
        "properties": {
            "advice": {"type": "string"},
            "recommendations": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "label": {"type": "string"},
                        "query": {"type": "string"},
                    },
                    "required": ["label", "query"],
                    "additionalProperties": False,
                },
            },
        },
        "required": ["advice", "recommendations"],
        "additionalProperties": False,
    },
}


def get_style_advice(image_bytes, question):
    image_b64 = base64.standard_b64encode(image_bytes).decode("utf-8")
    response = anthropic_client.messages.create(
        model="claude-opus-5",
        max_tokens=1024,
        system=STYLE_ADVICE_SYSTEM_PROMPT,
        messages=[{
            "role": "user",
            "content": [
                {
                    "type": "image",
                    "source": {"type": "base64", "media_type": "image/jpeg", "data": image_b64},
                },
                {"type": "text", "text": question},
            ],
        }],
        output_config={"format": STYLE_ADVICE_OUTPUT_SCHEMA},
    )
    text = next(block.text for block in response.content if block.type == "text")
    return json.loads(text)


@app.route("/search", methods=["POST"])
def search():
    if not SERPAPI_KEY:
        return jsonify({"error": "Server is missing SERPAPI_KEY"}), 500

    if "image" not in request.files:
        return jsonify({"error": "No image uploaded"}), 400

    image_bytes = request.files["image"].read()
    if not image_bytes:
        return jsonify({"error": "Empty image"}), 400

    category = request.form.get("category", "general")

    try:
        compressed = compress_for_upload(image_bytes)
        image_id = upload_to_serpapi(compressed)
        visual_matches = search_google_lens(image_id)
        matches = to_matches(visual_matches, category)
    except requests.RequestException as e:
        return jsonify({"error": f"SerpApi request failed: {e}"}), 502
    except Exception as e:
        return jsonify({"error": str(e)}), 500

    return jsonify({"matches": matches})


@app.route("/chat", methods=["POST"])
def chat():
    if not anthropic_client:
        return jsonify({"error": "Server is missing ANTHROPIC_API_KEY"}), 500
    if not SERPAPI_KEY:
        return jsonify({"error": "Server is missing SERPAPI_KEY"}), 500

    data = request.get_json(silent=True) or {}
    history = data.get("messages")
    if not history:
        return jsonify({"error": "No messages provided"}), 400

    try:
        decision = get_chat_decision(history)
    except anthropic.APIError as e:
        return jsonify({"error": f"Claude request failed: {e}"}), 502
    except Exception as e:
        return jsonify({"error": str(e)}), 500

    if decision.get("action") == "search" and decision.get("query"):
        try:
            shopping_results = search_google_shopping(decision["query"])
            matches = to_shopping_matches(shopping_results)
        except requests.RequestException as e:
            return jsonify({"error": f"SerpApi request failed: {e}"}), 502
        return jsonify({"action": "search", "message": decision["message"], "matches": matches})

    return jsonify({"action": "ask", "message": decision.get("message", "")})


@app.route("/style-advice", methods=["POST"])
def style_advice():
    if not anthropic_client:
        return jsonify({"error": "Server is missing ANTHROPIC_API_KEY"}), 500
    if not SERPAPI_KEY:
        return jsonify({"error": "Server is missing SERPAPI_KEY"}), 500

    if "image" not in request.files:
        return jsonify({"error": "No image uploaded"}), 400

    image_bytes = request.files["image"].read()
    if not image_bytes:
        return jsonify({"error": "Empty image"}), 400

    question = request.form.get("question", "").strip()
    if not question:
        return jsonify({"error": "No question provided"}), 400

    try:
        compressed = compress_for_upload(image_bytes)
        decision = get_style_advice(compressed, question)
    except anthropic.APIError as e:
        return jsonify({"error": f"Claude request failed: {e}"}), 502
    except Exception as e:
        return jsonify({"error": str(e)}), 500

    recommendations = []
    for rec in decision.get("recommendations", [])[:3]:
        query = rec.get("query")
        label = rec.get("label") or query or "Recommendation"
        matches = []
        if query:
            try:
                shopping_results = search_google_shopping(query)
                matches = to_shopping_matches(shopping_results)
            except requests.RequestException:
                matches = []
        recommendations.append({"label": label, "matches": matches})

    return jsonify({"advice": decision.get("advice", ""), "recommendations": recommendations})


@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok"})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5050, debug=True)
