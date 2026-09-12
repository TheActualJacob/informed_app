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
| Subscriptions | `informed_pro_monthly` (ASC id `6759974633`), `informed_pro_annual` (ASC id `6759974821`); RevenueCat entitlement `Informed Pro` |
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
