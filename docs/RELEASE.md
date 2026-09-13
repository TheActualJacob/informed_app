# Release, TestFlight, and App Store Connect (for humans and agents)

Everything needed to ship a build and manage the app in App Store Connect
(ASC) from the command line, without opening Xcode's GUI.

## Identifiers

| What | Value |
|---|---|
| App Store Connect app | **Informed: AI Fact Checker**, app id `6759923252` |
| Bundle ids | `com.jacob.informed` (app), `com.jacob.informed.share`, `com.jacob.informed.widget` |
| Team | `JQTCAT85GP` (Robert Ryan) |
| ASC API key id | `32P8X6989C` |
| ASC API issuer id | `9a14060e-f8f2-4beb-9b5e-951ad8dda6e2` |
| Private key (`.p8`) | `~/Documents/Personal/AuthKey_32P8X6989C.p8` on Jacob's Mac (also in iCloud Drive → Documents/Personal). **Never commit it** — `*.p8` is gitignored. Apple only lets you download it once; if lost, create a new key in ASC → Users and Access → Integrations → App Store Connect API. |
| Subscriptions | `informed_pro_monthly` (ASC id `6759974633`), `informed_pro_annual` (ASC id `6759974821`); RevenueCat entitlement `Informed Pro`; both have a 7-day free-trial introductory offer (see below) |
| TestFlight | internal group **Marketing** has *automatic distribution*: every processed build is in beta immediately. The API refuses to assign builds to it manually — that's expected. No external group exists. |

The key id / issuer id are not secrets by themselves (they're useless without
the `.p8`), which is why they can live in this public repo.

## Versioning

`CURRENT_PROJECT_VERSION` and `MARKETING_VERSION` are the **same string**
(e.g. `1.1.5`) for the app **and both extensions** in `informed.xcodeproj/project.pbxproj`
(ASC rejects builds whose extensions carry a different `CFBundleVersion`).
Bump all occurrences together:

```bash
sed -i '' -e 's/CURRENT_PROJECT_VERSION = 1\.1\.5;/CURRENT_PROJECT_VERSION = 1.1.6;/g' \
          -e 's/MARKETING_VERSION = 1\.1\.5;/MARKETING_VERSION = 1.1.6;/g' informed.xcodeproj/project.pbxproj
```

`ITSAppUsesNonExemptEncryption = NO` is set via `INFOPLIST_KEY_…`, so ASC never
blocks a build on the export-compliance question.

## Ship a TestFlight build

```bash
scripts/release.sh            # archive → upload → wait for processing → set test notes
scripts/release.sh --notes "What to test…"
```

What it does (see the script for the exact commands):

1. `xcodebuild archive` for `generic/platform=iOS`, Release, automatic signing
   (`-allowProvisioningUpdates`).
2. `xcodebuild -exportArchive` with `scripts/exportOptions.plist`
   (method `app-store-connect`, destination `upload`) **authenticated with the
   API key** (`-authenticationKeyPath/-authenticationKeyID/-authenticationKeyIssuerID`).
   This works even when Xcode's Apple ID session has lapsed ("Failed to Use Accounts").
3. `scripts/asc_testflight.py wait --version X --notes "…"` polls until the
   build is `VALID` and sets the "What to Test" text.

Requirements on the Mac: Xcode with the **iOS platform component installed**
(`xcodebuild -downloadPlatform iOS` — ~8 GB, prints nothing for a long time but
is working), the `.p8` at the path above, and Python 3 with `pyjwt`,
`cryptography`, `requests` (`python3 -m venv .venv && .venv/bin/pip install pyjwt cryptography requests`).

Run one build step at a time: archive + upload + a simulator running together
have pushed this Mac into memory pressure and got the upload killed mid-way.

## Type-check without a simulator

If no simulator runtime is installed, every target can still be type-checked
against the SDK (this is how the 1.1.x work was verified):

```bash
SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
FLAGS="-sdk $SDK -target arm64-apple-ios26.1-simulator -parse-as-library -swift-version 5 \
  -default-isolation MainActor -enable-upcoming-feature NonisolatedNonsendingByDefault \
  -enable-upcoming-feature InferIsolatedConformances"
# widget target
xcrun swiftc -typecheck $FLAGS -application-extension -module-name InformedWidgetExtension \
  InformedWidget/InformedWidgetBundle.swift informed/Views/ReelProcessingLiveActivity.swift \
  informed/Models/ReelProcessingActivity.swift informed/Extensions/ColorPalette.swift informed/Utilities/HapticManager.swift
# share target: InformedShare/ShareViewController.swift + the same three shared files
# app target: all informed/**/*.swift except Views/ReelProcessingLiveActivity.swift, plus a stub
#             RevenueCat module (only Purchases/Offerings/Offering/Package/StoreProduct/CustomerInfo are used)
```

## Subscription prices

Prices live in ASC (the app reads them from StoreKit; nothing is hard-coded).

```bash
scripts/asc_prices.py list
scripts/asc_prices.py set --monthly 8.99 --annual 89.99 --start 2026-09-13 --apply
```

Rules learned the hard way:

* An **approved** subscription can't take an "initial price"; you must schedule
  a change with `startDate` ≥ Apple's next day (the error tells you the earliest date).
* `preserveCurrentPrice: true` keeps existing subscribers at their old price and
  avoids the price-increase consent flow.
* Creating a USA price does **not** equalize other territories. The script
  follows up with `GET /subscriptionPricePoints/{usa}/equalizations` and posts a
  price for every other territory (174 of them) on the same start date.
* History: $4.99 / $49.99 originally; $8.99 / $89.99 scheduled from 2026-09-13.

## Free trial (introductory offer)

Both Pro subscriptions carry a **7-day free trial** (`FREE_TRIAL`, `1 × ONE_WEEK`)
in every territory, created 2026-09-13 with `scripts/asc_offers.py`. Apple
applies it automatically at purchase, once per Apple ID per subscription group;
RevenueCat needs no configuration. The app reads
`StoreProduct.introductoryDiscount` (+ `checkTrialOrIntroDiscountEligibility`)
to show "7 days free, then $X", and the backend gives a `trial` account 7 fact
checks for the whole week (`informedBackend/subscription_tiers.py`), after
which the subscription auto-renews as Pro (15/day). A free account has no
allowance at all — the trial is the only way in.

```bash
scripts/asc_offers.py list                              # offers per subscription + territory count
scripts/asc_offers.py create --duration ONE_WEEK        # dry run: which territories still lack one
scripts/asc_offers.py create --duration ONE_WEEK --apply
scripts/asc_offers.py delete --id OFFER_ID --apply      # remove one territory's offer
```

`create` is idempotent (skips territories that already have an offer). The API
creates offers per territory (`POST /subscriptionIntroductoryOffers` with a
`territory` relationship); there are 175 territories, so a full run is ~350
requests. Introductory offers need no review and go live immediately.

## Apple Ads (Search Ads) campaigns

Apple Ads is a separate product with its own API and credentials; the App Store
Connect key does **not** work for it. The Apple Ads account is
`jacobrryan1@gmail.com` (org "jacobs account", org id `24089240`, USD,
America/New_York).

| What | Value |
|---|---|
| Client ID / Team ID | `SEARCHADS.fea65518-9e3c-416c-b38e-26ce191ba620` |
| Key ID | `5fad5c0b-ccbf-46d4-9bac-3be549c62e43` |
| Private key | `~/Documents/Personal/apple-ads/private-key.pem` (EC P-256; its public half is uploaded in Apple Ads → Account Settings → API). **Never commit it.** |
| Credentials file | `~/Documents/Personal/apple-ads/credentials.json` (the three ids + key path; read by `scripts/asc_ads.py`) |

```bash
scripts/asc_ads.py orgs                          # sanity check: auth + org id
scripts/asc_ads.py campaigns                     # status, budget, countries
scripts/asc_ads.py adgroups --campaign ID
scripts/asc_ads.py keywords --campaign ID
scripts/asc_ads.py report --days 30              # spend / impressions / taps / installs per campaign
scripts/asc_ads.py report --days 7 --granularity DAILY
scripts/asc_ads.py raw GET /campaigns/ID         # any endpoint (adds X-AP-Context: orgId=…)
```

### Campaign structure (set up 2026-09-12)

One campaign, `informed fact checker` (id `2144655036`, Maximize Conversions,
target CPA $5, $30/day, US/CA/GB). Max Conversions requires exactly one automated
Search Match ad group per campaign, so intent is split by ad group:

| Ad group | Match | Purpose |
|---|---|---|
| `Automated` (Apple-created) | Search Match | discovery; carries every exact keyword below as an EXACT negative so known queries route to the exact groups |
| `Exact - Category` | exact | fact-check / misinformation / verification / AI-detection terms |
| `Exact - Competitor` | exact | Snopes, Ground News, AllSides, NewsGuard, Verifi, … |
| `Exact - Brand` | exact | informed, informed app, informed fact checker, … |
| `Broad - Core` | broad | core terms for phrasings the exact list misses; same exact negatives as Automated |

Campaign-level BROAD negatives cut wrong-intent traffic (parody, prank, maker,
generator, meme, template, quiz, trivia, game, faker). Bids are Apple-managed
(keywords carry no bid under Max Conversions).

`scripts/asc_ads_structure.py` holds the keyword lists and is idempotent: edit the
lists, run it for a dry run, add `--apply` to push only what is missing. Weekly
review: `asc_ads.py searchterms --campaign 2144655036 --days 7` — promote converting
Search Match / broad queries into `EXACT_CATEGORY`, add junk as negatives.

Auth is OAuth 2 client-credentials: the script signs an ES256 JWT (`sub` = client
id, `iss` = team id, `kid` = key id, `aud` = `https://appleid.apple.com`, up to
180 days) and swaps it for a 1-hour bearer token at
`https://appleid.apple.com/auth/oauth2/token` (`scope=searchadsorg`), cached in
`~/Documents/Personal/apple-ads/.access-token.json`. API base
`https://api.searchads.apple.com/api/v5`. Report requests omit `granularity` for
per-row totals; daily rows with no metrics come back as `{"date": …}` only.

## Other ASC operations via the API

`scripts/asc_testflight.py status` lists recent builds (processing state,
internal/external beta state) and beta groups. The scripts are small; extend
them rather than clicking through the site when something new is needed.
Base URL `https://api.appstoreconnect.apple.com/v1`, auth = ES256 JWT
(`iss` = issuer id, `kid` = key id, `aud` = `appstoreconnect-v1`, 20-minute expiry).

## Backend deploys (for completeness)

The Flask/Celery backend (`TheActualJacob/informed`) auto-deploys on Railway
from GitHub `main` (project `enthusiastic-gratitude`, services `informed` and
`skillful-wisdom`). Merging a PR into `main` is the deploy. Details:
`informedBackend/LIVE_ACTIVITY_NOTIFICATIONS.md` and the backend
`.github/copilot-instructions.md`.
