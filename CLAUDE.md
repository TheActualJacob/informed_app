# Informed iOS — notes for agents

- **Shipping / App Store Connect / TestFlight / prices:** read `docs/RELEASE.md` first.
  It has the app, team, subscription and API-key identifiers, where the `.p8`
  lives on Jacob's Mac, and the exact commands. `scripts/release.sh` archives,
  uploads (API-key auth, no Xcode sign-in needed) and sets TestFlight notes;
  `scripts/asc_prices.py`, `scripts/asc_offers.py` (free-trial introductory
  offer) and `scripts/asc_testflight.py` talk to the ASC API.
- Tiers: free = no fact checks, trial = 7 for the 7-day free trial, pro = 15/day.
  The backend (`subscription_tiers.py`) is the source of truth; the app mirrors
  the numbers in `UsageStatus` only for copy shown before the first response.
- Never commit `*.p8` (gitignored). The key id and issuer id in the docs are
  fine to keep; they are useless without the private key.
- Versioning: app and both extensions share one version/build string in the
  pbxproj; bump all occurrences together (see `docs/RELEASE.md`).
- Live Activity / notification protocol (single alert per fact-check, shared
  with the backend): `informedBackend/LIVE_ACTIVITY_NOTIFICATIONS.md` in the
  backend repo, and the header comments in `informed/Models/ReelProcessingActivity.swift`.
- UI direction: plain, native-feeling Apple UI — one accent colour, flat tinted
  icons, system type and materials, segmented stage bars (`SegmentedStageBar`).
  No gradients, glow rings or dot-and-line timelines.
- Backend (`TheActualJacob/informed`) auto-deploys to Railway from GitHub `main`.
