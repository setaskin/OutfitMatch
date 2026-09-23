"""
Backend proxy for OutfitMatch's product search.

The iOS app never talks to SerpApi directly (the API key would be
extractable from the app binary). Instead it uploads the photo here,
and this server does the SerpApi calls and returns simplified results.
"""

import base64
import io
import json
import logging
import os
import re

import anthropic
import requests
from dotenv import load_dotenv
from flask import Flask, jsonify, request
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from PIL import Image

load_dotenv()


def read_secret(name):
    """Read an env var that's destined for an HTTP header.

    Secrets pasted into a hosting dashboard routinely pick up a trailing
    newline, or the *next* line of the .env file they were copied from. Both
    make any header built from the value illegal, and the failure surfaces
    far away from the cause: the Anthropic SDK reports it as a bare
    "Connection error", which looks like a network problem rather than a
    config one. Take the first non-empty line and warn if we had to trim,
    so a stray newline degrades to a log line instead of an outage.
    """
    raw = os.environ.get(name)
    if not raw:
        return None

    cleaned = raw.strip().splitlines()[0].strip() if raw.strip() else ""
    if cleaned != raw:
        logging.warning(
            "%s contained extra whitespace or lines; using the first line only. "
            "Check for a stray newline or a second variable pasted into this field.",
            name,
        )
    return cleaned or None


SERPAPI_KEY = read_secret("SERPAPI_KEY")
SERPAPI_MAX_BYTES = 500 * 1024  # SerpApi's image upload limit

app = Flask(__name__)

# Every request here costs real money (SerpApi/Anthropic calls), and there's
# no per-user auth to scope abuse to one account — so it's scoped to the
# caller's IP instead. In-memory storage is fine for a single-process dev
# server; a real multi-instance deployment would want a shared backend
# (e.g. Redis) so limits are enforced across all instances, not per-process.
limiter = Limiter(
    key_func=get_remote_address,
    app=app,
    default_limits=["200 per day", "50 per hour"],
    storage_uri="memory://",
)

ANTHROPIC_API_KEY = read_secret("ANTHROPIC_API_KEY")
ANTHROPIC_WORKSPACE_ID = read_secret("ANTHROPIC_WORKSPACE_ID")
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


def split_exact_and_alternatives(priced_items, get_price, exact_index=0, keep_alternative=None):
    """Shared ranking rule: one item leads as the closest match, and anything
    genuinely cheaper becomes an alternative, cheapest first.

    `exact_index` lets the caller choose which item leads. The Lens path keeps
    index 0 because Lens already ranks by visual similarity. The Shopping path
    picks by how well the title matches what the user asked for, because
    Google Shopping orders commercially rather than by attribute match.
    `keep_alternative` optionally narrows alternatives to relevant ones.
    """
    if not priced_items:
        return []

    exact = priced_items[exact_index]
    exact_price = get_price(exact)
    cheaper = [
        item
        for index, item in enumerate(priced_items)
        if index != exact_index and get_price(item) < exact_price
    ]

    if keep_alternative:
        relevant = [item for item in cheaper if keep_alternative(item)]
        # Only narrow if something survives — a strict filter shouldn't empty
        # the grid when the alternative is showing nothing at all.
        if relevant:
            cheaper = relevant

    return [exact] + sorted(cheaper, key=get_price)[:5]


# Words that carry no signal when matching a query against a product title.
MATCH_STOPWORDS = {
    "and", "for", "the", "with", "that", "this", "some", "any", "please",
    "size", "sizes", "under", "below", "over", "about", "around", "approx",
    "cheap", "cheaper", "cheapest", "budget", "affordable", "inexpensive",
    "want", "wants", "need", "needs", "looking", "look", "like", "similar",
    "style", "styled", "new", "buy", "shop", "shopping", "something",
}


def match_terms(query):
    """The meaningful lowercase words in a query, for scoring product titles."""
    if not query:
        return []
    words = re.findall(r"[a-z0-9]+", query.lower())
    return [w for w in words if len(w) > 2 and w not in MATCH_STOPWORDS]


def relevance_score(title, terms):
    """How many of the query's meaningful terms appear in this title."""
    if not terms:
        return 0
    lowered = (title or "").lower()
    return sum(1 for term in terms if term in lowered)


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


def to_shopping_matches(shopping_results, query=None):
    """Turn Google Shopping results into the app's match shape.

    Shopping orders results by commercial relevance, so its first result is
    routinely the wrong colour or material for what the user described — a
    search for "black fur duster" would lead with a light grey cardigan while
    better matches sat further down. So the leading "closest match" is chosen
    by scoring titles against the query's terms instead of trusting position.
    """
    priced = [r for r in shopping_results if r.get("extracted_price") is not None]
    if not priced:
        return []

    terms = match_terms(query)
    if terms:
        # Best-scoring title leads; ties keep Google's original order.
        best_index = max(
            range(len(priced)),
            key=lambda i: (relevance_score(priced[i].get("title", ""), terms), -i),
        )
        keep_alternative = lambda item: relevance_score(item.get("title", ""), terms) > 0  # noqa: E731
    else:
        best_index = 0
        keep_alternative = None

    ranked = split_exact_and_alternatives(
        priced,
        lambda r: r["extracted_price"],
        exact_index=best_index,
        keep_alternative=keep_alternative,
    )

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
@limiter.limit("20 per hour")
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
@limiter.limit("30 per hour")
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
            matches = to_shopping_matches(shopping_results, decision["query"])
        except requests.RequestException as e:
            return jsonify({"error": f"SerpApi request failed: {e}"}), 502
        return jsonify({"action": "search", "message": decision["message"], "matches": matches})

    return jsonify({"action": "ask", "message": decision.get("message", "")})


@app.route("/style-advice", methods=["POST"])
@limiter.limit("20 per hour")
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
                matches = to_shopping_matches(shopping_results, query)
            except requests.RequestException:
                matches = []
        recommendations.append({"label": label, "matches": matches})

    return jsonify({"advice": decision.get("advice", ""), "recommendations": recommendations})


@app.route("/health", methods=["GET"])
@limiter.exempt
def health():
    return jsonify({"status": "ok"})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5050, debug=True)
