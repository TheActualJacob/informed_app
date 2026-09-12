"""Shared App Store Connect API auth + helpers for the scripts in this folder.

Credentials come from the environment, falling back to the values documented in
docs/RELEASE.md (Jacob's Mac). The private key itself is never in the repo.

  ASC_KEY_ID      App Store Connect API key id        (default 32P8X6989C)
  ASC_ISSUER_ID   App Store Connect API issuer id     (default 9a14060e-f8f2-4beb-9b5e-951ad8dda6e2)
  ASC_KEY_PATH    path to the AuthKey_<id>.p8 file    (default ~/Documents/Personal/AuthKey_32P8X6989C.p8)

Requires: pyjwt, cryptography, requests.
"""
import os
import sys
import time

try:
    import jwt
    import requests
except ImportError:  # pragma: no cover
    sys.exit("pip install pyjwt cryptography requests")

KEY_ID = os.getenv("ASC_KEY_ID", "32P8X6989C")
ISSUER_ID = os.getenv("ASC_ISSUER_ID", "9a14060e-f8f2-4beb-9b5e-951ad8dda6e2")
KEY_PATH = os.path.expanduser(os.getenv("ASC_KEY_PATH", f"~/Documents/Personal/AuthKey_{KEY_ID}.p8"))

BASE = "https://api.appstoreconnect.apple.com/v1"
BUNDLE_ID = "com.jacob.informed"
APP_ID = "6759923252"
PRODUCTS = {"monthly": "informed_pro_monthly", "annual": "informed_pro_annual"}


def token() -> str:
    if not os.path.exists(KEY_PATH):
        sys.exit(f"ASC private key not found at {KEY_PATH} (set ASC_KEY_PATH)")
    now = int(time.time())
    return jwt.encode(
        {"iss": ISSUER_ID, "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"},
        open(KEY_PATH).read(),
        algorithm="ES256",
        headers={"kid": KEY_ID, "typ": "JWT"},
    )


def headers() -> dict:
    return {"Authorization": f"Bearer {token()}", "Content-Type": "application/json"}


def api(method: str, path: str, **kw):
    """Call the API; exits with the error body on 4xx/5xx."""
    url = path if path.startswith("http") else BASE + path
    r = requests.request(method, url, headers=headers(), timeout=30, **kw)
    if r.status_code >= 400:
        sys.exit(f"{method} {path} -> {r.status_code}: {r.text[:800]}")
    return r.json() if r.text else {}


def paged(path: str):
    """Yield every item of a paginated collection."""
    url = path
    while url:
        d = api("GET", url)
        yield from d.get("data", [])
        url = d.get("links", {}).get("next")
