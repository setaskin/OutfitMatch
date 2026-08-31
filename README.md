# OutfitMatch

An iOS app: take a photo of an outfit or a single clothing item, and get the
closest match plus genuinely cheaper alternatives you can buy online.

The UI flow, on-device clothing detection, and product search are all real
now — search is backed by SerpApi's Google Lens API, called through a small
local backend so the API key never ships inside the app.

## What works right now

1. **Home screen** — pick a photo from your library (`ContentView.swift`).
2. **Clothing detection** — the photo is analyzed on-device with Apple's
   Vision framework (`ClothingDetector.swift`) to check whether it actually
   contains clothing, and to guess what *kind* (footwear, outerwear, dress,
   top, bottom). A photo with multiple items (e.g. a jacket and sneakers)
   can surface more than one detected category.
3. **No outfit found** — if no clothing is detected, the app tells you
   instead of pretending to search.
4. **Real product search** — the photo and detected category are sent to
   the local backend (`backend/app.py`), which uploads it to SerpApi's
   Google Lens API, filters results down to ones matching that category,
   and returns a closest match plus any results that are genuinely
   cheaper. Rows show the real thumbnail/price and are tappable — they
   open the retailer's product page.

## Known limitation: Simulator vs. real device

Vision's on-device classifier (`VNClassifyImageRequest`) does not run in the
iOS Simulator — it fails on every call regardless of the photo. Because of
this, `ClothingDetector` skips the real check when running in the Simulator
and always reports a generic "Clothing" category instead. That still lets
you test the real backend/search end-to-end in the Simulator (it hits the
real API), but **without the category hint, results are noisier** — the
backend can't filter out irrelevant matches as well. Telling clothing types
apart, correctly rejecting photos with no clothing, and getting well-filtered
search results all need a physical iPhone to test properly.

## Project structure

```
OutfitMatch/
├── OutfitMatchApp.swift     App entry point
├── ContentView.swift        Home screen: photo picker, kicks off detection
├── ClothingDetector.swift   On-device Vision-based clothing detection
├── Models.swift             Data models (MatchResult, ClothingCategory)
├── SearchService.swift      Talks to the backend over HTTP
└── ResultsView.swift        Results screen: closest match + alternatives

backend/
├── app.py                   Flask proxy: photo → SerpApi Google Lens → JSON
├── requirements.txt
└── .env                     Holds SERPAPI_KEY (gitignored, not committed)
```

## Running it

**1. Start the backend** (needed before running the app — search calls will
fail without it):
```bash
cd backend
source .venv/bin/activate   # first time: python3 -m venv .venv
python3 app.py
```
Runs on `http://127.0.0.1:5050`. Needs a `backend/.env` file with
`SERPAPI_KEY=your_key_here` — get a free key (250 searches/month) at
[serpapi.com](https://serpapi.com/manage-api-key).

**2. Run the app — Simulator:**
Open `OutfitMatch.xcodeproj` in Xcode, pick a simulator from the run
destination dropdown, and hit Run (▶). `SearchService.swift` points at
`127.0.0.1`, which reaches the Mac's backend automatically from the
Simulator.

**2. Run the app — real device** (needed to test clothing detection
properly):
1. Connect your iPhone via USB and trust the computer.
2. Enable Developer Mode on the phone if prompted (Settings → Privacy &
   Security → Developer Mode) — this option only appears after Xcode's
   first attempt to install a build on the device.
3. Select your iPhone from Xcode's run destination dropdown and hit Run.
4. Update `SearchService.baseURL` to the Mac's LAN IP (e.g.
   `http://192.168.x.x:5050`) instead of `127.0.0.1` — a real device can't
   reach the Mac via loopback. You'll also need an App Transport Security /
   local network exception in Info.plist, not yet set up.

## Next steps

- Local-network ATS exception + `NSLocalNetworkUsageDescription` for
  real-device search testing.
- Camera capture (currently photo-library only).
- Deploy the backend somewhere reachable outside your own Wi-Fi (currently
  `localhost`-only, fine for development).
