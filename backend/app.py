"""
Backend proxy for OutfitMatch's product search.

The iOS app never talks to SerpApi directly (the API key would be
extractable from the app binary). Instead it uploads the photo here,
and this server does the SerpApi calls and returns simplified results.
"""

import io
import os

import requests
from dotenv import load_dotenv
from flask import Flask, jsonify, request
from PIL import Image

load_dotenv()

SERPAPI_KEY = os.environ.get("SERPAPI_KEY")
SERPAPI_MAX_BYTES = 500 * 1024  # SerpApi's image upload limit

app = Flask(__name__)


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


def to_matches(visual_matches, category):
    """Keep only results with real price data whose title actually matches
    the detected clothing category (Lens mixes in unrelated visual matches
    like stickers or gift cards that happen to have price data). The first
    remaining result (Lens's top-ranked relevant, priced result) is the
    closest match; anything genuinely cheaper than it becomes an
    alternative."""
    relevant = [m for m in visual_matches if is_relevant(m, category)]
    priced = [m for m in relevant if m.get("price", {}).get("extracted_value") is not None]

    if not priced:
        # Category filter may have been too strict, or Lens just didn't
        # find priced matches for this category — fall back to any priced
        # result rather than showing nothing.
        priced = [m for m in visual_matches if m.get("price", {}).get("extracted_value") is not None]

    if not priced:
        return []

    exact = priced[0]
    exact_price = exact["price"]["extracted_value"]
    alternatives = sorted(
        (m for m in priced[1:] if m["price"]["extracted_value"] < exact_price),
        key=lambda m: m["price"]["extracted_value"],
    )

    def to_match(item, match_type):
        return {
            "title": item.get("title", "Unknown item"),
            "retailer": item.get("source", "Unknown"),
            "price": item["price"]["extracted_value"],
            "link": item.get("link"),
            "thumbnail": item.get("thumbnail"),
            "matchType": match_type,
        }

    return [to_match(exact, "exact")] + [to_match(m, "alternative") for m in alternatives[:5]]


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


@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok"})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5050, debug=True)
