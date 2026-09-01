# OutfitMatch

An iOS app: take a photo of an outfit or a single clothing item — or just
describe it in chat — and get the closest match plus genuinely cheaper
alternatives you can buy online.

The UI flow, on-device clothing detection, and product search are all real
now — search is backed by SerpApi's Google Lens (photo) and Google Shopping
(chat) APIs, and chat is powered by Claude. Both are called through a small
local backend so the API keys never ship inside the app.

## What works right now

1. **Home screen** — pick a photo from your library, or describe what you
   want in chat instead (`ContentView.swift`).
2. **Clothing detection (photo path)** — the photo is analyzed on-device
   with Apple's Vision framework (`ClothingDetector.swift`) to check whether
   it actually contains clothing, and to guess what *kind* (footwear,
   outerwear, dress, top, bottom). A photo with multiple items (e.g. a
   jacket and sneakers) can surface more than one detected category.
3. **No outfit found** — if no clothing is detected in a photo, the app
   tells you instead of pretending to search.
4. **Real product search (photo path)** — the photo and detected category
   are sent to the local backend, which uploads it to SerpApi's Google Lens
   API and filters results down to ones matching that category.
5. **Chat search ("Describe It")** — `ChatView.swift` has a short back-and-
   forth with Claude (via the backend's `/chat` endpoint), which asks a
   couple of clarifying questions (color, style, budget) and then runs a
   real SerpApi Google Shopping search once it has enough detail. A mic
   button lets you speak your description instead of typing it —
   `SpeechRecognizer.swift` uses Apple's on-device Speech framework (no
   network call) to stream a live transcript into the text field.
6. **Style Advisor** — `StyleAdvisorView.swift` lets you upload a photo of
   yourself or an outfit and ask a styling question (e.g. "what shoes go
   with these jeans, casual Gen Z style?"). Claude actually looks at the
   photo (vision) and returns a short styling explanation plus 2-3 concrete
   recommendations, each backed by its own real SerpApi Google Shopping
   search — via the backend's `/style-advice` endpoint.
7. **Results** — all three paths land on a closest match plus any results
   that are genuinely cheaper, shown as a photo grid (hero card + 2-column
   grid) with real thumbnails/prices, tappable to open the retailer's
   product page (`MatchesListView.swift`, shared by all three flows).

## Known limitation: Simulator vs. real device

Vision's on-device classifier (`VNClassifyImageRequest`) does not run in the
iOS Simulator — it fails on every call regardless of the photo. Because of
this, `ClothingDetector` skips the real check when running in the Simulator
and always reports a generic "Clothing" category instead. That still lets
you test the real backend/search end-to-end in the Simulator (it hits the
real API), but **without the category hint, results are noisier** — the
backend can't filter out irrelevant matches as well. Telling clothing types
apart, correctly rejecting photos with no clothing, and getting well-filtered
search results all need a physical iPhone to test properly. (The chat path
doesn't have this limitation — it doesn't depend on Vision at all.)

## Project structure

```
OutfitMatch/
├── OutfitMatchApp.swift       App entry point
├── ContentView.swift          Home screen: photo, "Describe It", "Style Advisor" entries
├── ClothingDetector.swift     On-device Vision-based clothing detection
├── Models.swift               Data models (MatchResult, ChatMessage, StyleAdvice, etc.)
├── BackendConfig.swift        Backend base URL
├── SearchService.swift        Photo search: talks to backend's /search
├── ChatService.swift          Chat search: talks to backend's /chat
├── StyleAdviceService.swift   Style advisor: talks to backend's /style-advice
├── ResultsView.swift          Results screen for the photo path
├── ChatView.swift             Chat conversation screen
├── ChatResultsView.swift      Results screen for the chat path
├── StyleAdvisorView.swift     Style advisor input screen (photo + question)
├── StyleAdviceResultsView.swift  Style advice + per-recommendation results
└── MatchesListView.swift      Shared photo-grid results rendering (all three flows)

backend/
├── app.py                   Flask proxy: /search (Lens), /chat, /style-advice (Claude + Shopping)
├── requirements.txt
└── .env                     Holds API keys (gitignored, not committed)
```

## Running it

**1. Start the backend** (needed before running the app — search and chat
calls will fail without it):
```bash
cd backend
source .venv/bin/activate   # first time: python3 -m venv .venv
python3 app.py
```
Runs on `http://127.0.0.1:5050`. Needs a `backend/.env` file with:
```
SERPAPI_KEY=your_key_here
ANTHROPIC_API_KEY=your_key_here
ANTHROPIC_WORKSPACE_ID=wrkspc_your_id_here   # only if your key is identity-linked (SSO)
```
- SerpApi: free plan, 250 searches/month — [serpapi.com](https://serpapi.com/manage-api-key)
- Anthropic: no free tier, pay-per-use (a few cents covers a lot of testing) — [console.anthropic.com](https://console.anthropic.com/settings/keys)

**2. Run the app — Simulator:**
Open `OutfitMatch.xcodeproj` in Xcode, pick a simulator from the run
destination dropdown, and hit Run (▶). `BackendConfig.swift` points at
`127.0.0.1`, which reaches the Mac's backend automatically from the
Simulator.

**2. Run the app — real device** (needed to test clothing detection
properly):
1. Connect your iPhone via USB and trust the computer.
2. Enable Developer Mode on the phone if prompted (Settings → Privacy &
   Security → Developer Mode) — this option only appears after Xcode's
   first attempt to install a build on the device.
3. Select your iPhone from Xcode's run destination dropdown and hit Run.
4. Update `BackendConfig.baseURL` to the Mac's LAN IP (e.g.
   `http://192.168.x.x:5050`) instead of `127.0.0.1` — a real device can't
   reach the Mac via loopback. You'll also need an App Transport Security /
   local network exception in Info.plist, not yet set up.

## Next steps

- Local-network ATS exception + `NSLocalNetworkUsageDescription` for
  real-device search testing.
- Camera capture (currently photo-library only).
- Deploy the backend somewhere reachable outside your own Wi-Fi (currently
  `localhost`-only, fine for development).
