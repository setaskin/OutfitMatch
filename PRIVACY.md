# Privacy Policy

**Last updated:** September 1, 2026

This policy describes how OutfitMatch ("the app") handles your
information. OutfitMatch is a single-developer project; there is no
company, no ad network, and no data broker involved.

## What the app does with your photos and questions

- **Photo search:** when you take or choose a photo to find matches for,
  that photo is sent to OutfitMatch's backend server, which forwards it to
  SerpApi (a third-party search API) to run a Google Lens visual search.
  The photo is not stored by OutfitMatch's backend beyond the time needed
  to process the request.
- **Chat search ("Describe It"):** what you type or dictate is sent to
  OutfitMatch's backend, which forwards it to Anthropic's Claude API to
  interpret your request and to SerpApi to run the resulting product
  search.
- **Style Advisor:** the photo and question you submit are sent to
  OutfitMatch's backend, forwarded to Anthropic's Claude API (which
  analyzes the image) and then to SerpApi for the resulting product
  searches.
- **Voice input:** when you use the microphone button, your speech is
  transcribed **on your device** using Apple's Speech framework. Audio is
  not uploaded anywhere for this — only the resulting text is sent, and
  only once you send the message.
- **Clothing detection:** the on-device check for "is this a photo of
  clothing, and what kind" runs entirely on your device using Apple's
  Vision framework. The photo is not uploaded for this step.

In short: photos and text you deliberately submit for a search are sent
to the third-party services above to produce your results. Nothing is
uploaded in the background or without an action you took.

## Third parties involved

- **[Anthropic](https://www.anthropic.com/legal/privacy)** — processes
  chat messages and photos you submit to Chat Search or Style Advisor.
- **[SerpApi](https://serpapi.com/legal)** — processes photos and search
  queries to return shopping results (via Google Lens and Google
  Shopping).
- **Retailers** — tapping a result opens that retailer's own website,
  outside the app, subject to their own privacy practices.
- **Apple** — subscriptions are handled entirely through Apple's App
  Store / StoreKit. OutfitMatch never sees or stores your payment
  details.

Each of these third parties handles data under their own privacy policy,
linked above — please review them if you want the full picture.

## What OutfitMatch does *not* do

- No account or sign-up, so no name, email, or profile is collected by
  the app itself.
- No advertising SDKs, no analytics/tracking SDKs, no data resale.
- No storage of your photos beyond what's needed to process a single
  search request.

## What's stored on your device

- Whether you have free Style Advisor uses remaining, so the app knows
  when to show the subscription paywall. This is stored locally on your
  device and is not transmitted anywhere.

## Camera, Photo Library, and Microphone permissions

The app only accesses your camera, photo library, or microphone when you
explicitly tap a button to use them (Scan, Library, or the mic). iOS asks
your permission the first time; you can review or revoke it anytime in
Settings → Privacy.

## Children's privacy

OutfitMatch is not directed at children under 13 and does not knowingly
collect information from them.

## Changes to this policy

If this policy changes in a way that matters, the "Last updated" date
above will change and, for material changes, this will be noted in the
app's release notes.

## Contact

Questions about this policy: **selengt@gmail.com**
