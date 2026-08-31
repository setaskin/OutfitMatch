# OutfitMatch

An iOS app idea: take a photo of an outfit or a single clothing item, and get
an exact match plus cheaper alternatives you can buy online.

This repo is currently a **prototype** — the UI flow and the on-device
clothing detection are real, but the product search results are mocked
(hardcoded sample data), since a real visual-search backend hasn't been
built yet.

## What works right now

1. **Home screen** — pick a photo from your library (`ContentView.swift`).
2. **Clothing detection** — the photo is analyzed on-device with Apple's
   Vision framework (`ClothingDetector.swift`) to check whether it actually
   contains clothing, and to guess what *kind* (footwear, outerwear, dress,
   top, bottom). A photo with multiple items (e.g. a jacket and sneakers)
   can surface more than one detected category.
3. **No outfit found** — if no clothing is detected, the app tells you
   instead of pretending to search.
4. **Results screen** — for each detected item, shows an "Exact Match" and
   a few "Cheaper Alternatives" (`ResultsView.swift`). This data is fake —
   see [`Models.swift`](OutfitMatch/Models.swift)'s `MockSearch`.

## Known limitation: Simulator vs. real device

Vision's on-device classifier (`VNClassifyImageRequest`) does not run in the
iOS Simulator — it fails on every call regardless of the photo. Because of
this, `ClothingDetector` skips the real check when running in the Simulator
and always reports a generic "Clothing" match instead. **The real
detection — telling clothing types apart, and correctly rejecting photos
with no clothing — only works on a physical iPhone.**

## Project structure

```
OutfitMatch/
├── OutfitMatchApp.swift     App entry point
├── ContentView.swift        Home screen: photo picker, kicks off detection
├── ClothingDetector.swift   On-device Vision-based clothing detection
├── Models.swift             Data models + MockSearch (fake product data)
└── ResultsView.swift        Results screen, grouped by detected item
```

## Running it

**Simulator:**
Open `OutfitMatch.xcodeproj` in Xcode, pick a simulator from the run
destination dropdown, and hit Run (▶).

**Real device** (needed to test clothing detection properly):
1. Connect your iPhone via USB and trust the computer.
2. Enable Developer Mode on the phone if prompted (Settings → Privacy &
   Security → Developer Mode) — this option only appears after Xcode's
   first attempt to install a build on the device.
3. Select your iPhone from Xcode's run destination dropdown and hit Run.

## Next steps

- Wire up a real visual-search backend (e.g. Google Cloud Vision Product
  Search, ViSenze, or SerpApi) to replace `MockSearch`.
- Connect a real shopping/product API for live pricing instead of the
  hardcoded sample data.
- Camera capture (currently photo-library only).
