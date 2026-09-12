#!/usr/bin/env python3
"""Apple Ads (Search Ads) Campaign Management API helper for Informed.

  scripts/asc_ads.py orgs                              # organisations this API client can see
  scripts/asc_ads.py campaigns [--org ID]              # campaigns with status + budget
  scripts/asc_ads.py adgroups --campaign ID            # ad groups in a campaign
  scripts/asc_ads.py keywords --campaign ID [--adgroup ID]
  scripts/asc_ads.py report [--days 30] [--granularity DAILY|TOTAL] [--campaign ID]
                                                      # spend / impressions / taps / installs
  scripts/asc_ads.py keywordreport --campaign ID [--days 30]   # per-keyword performance
  scripts/asc_ads.py searchterms --campaign ID [--days 30]     # what people actually searched (Search Match + broad)
  scripts/asc_ads.py raw GET /campaigns?limit=5        # any endpoint, prints JSON

Auth is OAuth 2 client-credentials: a JWT signed with the private key whose
public half was uploaded in Apple Ads → Account Settings → API. Credentials are
read from ~/Documents/Personal/apple-ads/credentials.json (see docs/RELEASE.md):

  { "clientId": "SEARCHADS.…", "teamId": "SEARCHADS.…", "keyId": "…",
    "privateKeyPath": "~/Documents/Personal/apple-ads/private-key.pem" }

Env overrides: ADS_CLIENT_ID, ADS_TEAM_ID, ADS_KEY_ID, ADS_KEY_PATH, ADS_ORG_ID.
Requires: pyjwt, cryptography, requests (same .venv as the other scripts).
"""
import argparse
import datetime as dt
import json
import os
import sys
import time

try:
    import jwt
    import requests
except ImportError:  # pragma: no cover
    sys.exit("pip install pyjwt cryptography requests")

CRED_PATH = os.path.expanduser(os.getenv("ADS_CREDENTIALS", "~/Documents/Personal/apple-ads/credentials.json"))
TOKEN_URL = "https://appleid.apple.com/auth/oauth2/token"
BASE = "https://api.searchads.apple.com/api/v5"
_TOKEN_CACHE = os.path.expanduser("~/Documents/Personal/apple-ads/.access-token.json")


def _creds():
    c = {}
    if os.path.exists(CRED_PATH):
        c = json.load(open(CRED_PATH))
    out = {
        "clientId": os.getenv("ADS_CLIENT_ID", c.get("clientId")),
        "teamId": os.getenv("ADS_TEAM_ID", c.get("teamId")),
        "keyId": os.getenv("ADS_KEY_ID", c.get("keyId")),
        "keyPath": os.path.expanduser(os.getenv("ADS_KEY_PATH", c.get("privateKeyPath", ""))),
    }
    missing = [k for k, v in out.items() if not v]
    if missing:
        sys.exit(f"missing Apple Ads credentials {missing} — fill {CRED_PATH}")
    if not os.path.exists(out["keyPath"]):
        sys.exit(f"private key not found at {out['keyPath']}")
    return out


def client_secret(c) -> str:
    """ES256 JWT that Apple accepts as the OAuth client secret (max 180 days)."""
    now = int(time.time())
    return jwt.encode(
        {"sub": c["clientId"], "aud": "https://appleid.apple.com", "iat": now,
         "exp": now + 86400 * 180, "iss": c["teamId"]},
        open(c["keyPath"]).read(),
        algorithm="ES256",
        headers={"kid": c["keyId"], "alg": "ES256"},
    )


def access_token() -> str:
    """Cached bearer token (Apple issues them for 1 hour)."""
    try:
        cached = json.load(open(_TOKEN_CACHE))
        if cached.get("expires_at", 0) - 120 > time.time():
            return cached["access_token"]
    except (OSError, ValueError):
        pass
    c = _creds()
    r = requests.post(
        TOKEN_URL,
        params={"grant_type": "client_credentials", "client_id": c["clientId"],
                "client_secret": client_secret(c), "scope": "searchadsorg"},
        headers={"Host": "appleid.apple.com", "Content-Type": "application/x-www-form-urlencoded"},
        timeout=30,
    )
    if r.status_code >= 400:
        sys.exit(f"token request failed {r.status_code}: {r.text[:500]}")
    d = r.json()
    d["expires_at"] = time.time() + int(d.get("expires_in", 3600))
    try:
        with open(_TOKEN_CACHE, "w") as f:
            json.dump(d, f)
        os.chmod(_TOKEN_CACHE, 0o600)
    except OSError:
        pass
    return d["access_token"]


def api(method: str, path: str, org_id=None, **kw):
    """Call the Apple Ads API. Most endpoints need X-AP-Context: orgId=…; /acls does not."""
    headers = {"Authorization": f"Bearer {access_token()}", "Content-Type": "application/json"}
    if org_id:
        headers["X-AP-Context"] = f"orgId={org_id}"
    url = path if path.startswith("http") else BASE + path
    r = requests.request(method, url, headers=headers, timeout=60, **kw)
    if r.status_code >= 400:
        sys.exit(f"{method} {path} -> {r.status_code}: {r.text[:800]}")
    return r.json() if r.text else {}


def orgs():
    return [{"orgId": a["orgId"], "orgName": a["orgName"], "roles": a.get("roleNames"),
             "currency": a.get("currency"), "timeZone": a.get("timeZone")}
            for a in api("GET", "/acls")["data"]]


def resolve_org(explicit=None) -> int:
    if explicit:
        return int(explicit)
    if os.getenv("ADS_ORG_ID"):
        return int(os.environ["ADS_ORG_ID"])
    o = orgs()
    if len(o) == 1:
        return o[0]["orgId"]
    sys.exit("several orgs visible — pass --org ID:\n" + "\n".join(json.dumps(x) for x in o))


def paged(path, org_id, limit=200):
    offset = 0
    while True:
        d = api("GET", f"{path}{'&' if '?' in path else '?'}limit={limit}&offset={offset}", org_id)
        data = d.get("data") or []
        yield from data
        total = (d.get("pagination") or {}).get("totalResults", 0)
        offset += limit
        if offset >= total or not data:
            break


def report(org_id, days, granularity, campaign=None):
    end = dt.date.today()
    start = end - dt.timedelta(days=days - 1)
    body = {
        "startTime": start.isoformat(), "endTime": end.isoformat(), "timeZone": "ORTZ",
        "selector": {"orderBy": [{"field": "localSpend", "sortOrder": "DESCENDING"}],
                     "pagination": {"offset": 0, "limit": 1000}},
        "returnRowTotals": True, "returnGrandTotals": True, "returnRecordsWithNoMetrics": True,
    }
    if granularity != "TOTAL":          # omit the field entirely for per-row totals
        body["granularity"] = granularity
    path = f"/reports/campaigns/{campaign}/adgroups" if campaign else "/reports/campaigns"
    return api("POST", path, org_id, data=json.dumps(body))["data"]["reportingDataResponse"]


def keyword_level_report(org_id, campaign, days, kind="keywords"):
    """kind = 'keywords' (targeting keywords) or 'searchterms' (actual queries)."""
    end = dt.date.today()
    start = end - dt.timedelta(days=days - 1)
    body = {
        "startTime": start.isoformat(), "endTime": end.isoformat(), "timeZone": "ORTZ",
        "selector": {"orderBy": [{"field": "impressions", "sortOrder": "DESCENDING"}],
                     "pagination": {"offset": 0, "limit": 1000}},
        "returnRowTotals": True, "returnGrandTotals": True, "returnRecordsWithNoMetrics": kind == "keywords",
    }
    return api("POST", f"/reports/campaigns/{campaign}/{kind}", org_id, data=json.dumps(body))["data"]["reportingDataResponse"]


def fmt_totals(t):
    """One-line summary of a metrics object (row total, grand total or one day)."""
    if not t or "impressions" not in t:
        return "no data"
    money = lambda k: (t.get(k) or {}).get("amount")
    return (f"spend={money('localSpend')} {(t.get('localSpend') or {}).get('currency', '')} "
            f"impressions={t.get('impressions')} taps={t.get('taps')} ttr={t.get('ttr')} "
            f"installs={t.get('totalInstalls')} (tap={t.get('tapInstalls')} view={t.get('viewInstalls')}) "
            f"new={t.get('totalNewDownloads')} redownloads={t.get('totalRedownloads')} "
            f"cpt={money('avgCPT')} cpi={money('tapInstallCPI')}")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sp = ap.add_subparsers(dest="cmd", required=True)
    sp.add_parser("orgs")
    p = sp.add_parser("campaigns"); p.add_argument("--org")
    p = sp.add_parser("adgroups"); p.add_argument("--org"); p.add_argument("--campaign", required=True)
    p = sp.add_parser("keywords"); p.add_argument("--org"); p.add_argument("--campaign", required=True); p.add_argument("--adgroup")
    p = sp.add_parser("report"); p.add_argument("--org"); p.add_argument("--days", type=int, default=30)
    p.add_argument("--granularity", default="TOTAL", choices=["TOTAL", "DAILY", "WEEKLY", "MONTHLY"]); p.add_argument("--campaign")
    for name in ("keywordreport", "searchterms"):
        p = sp.add_parser(name); p.add_argument("--org"); p.add_argument("--campaign", required=True); p.add_argument("--days", type=int, default=30)
    p = sp.add_parser("raw"); p.add_argument("--org"); p.add_argument("method"); p.add_argument("path"); p.add_argument("--body")
    a = ap.parse_args()

    if a.cmd == "orgs":
        for o in orgs():
            print(json.dumps(o))
        return
    org = resolve_org(getattr(a, "org", None))

    if a.cmd == "campaigns":
        for c in paged("/campaigns", org):
            print(json.dumps({"id": c["id"], "name": c["name"], "status": c["status"], "serving": c.get("servingStatus"),
                              "display": c.get("displayStatus"), "dailyBudget": c.get("dailyBudgetAmount"),
                              "budget": c.get("budgetAmount"), "countries": c.get("countriesOrRegions"),
                              "bidding": c.get("biddingStrategy"), "targetCpa": c.get("targetCpa"),
                              "adamId": c.get("adamId"), "type": c.get("adChannelType")}))
    elif a.cmd == "adgroups":
        for g in paged(f"/campaigns/{a.campaign}/adgroups", org):
            print(json.dumps({"id": g["id"], "name": g["name"], "status": g["status"], "serving": g.get("servingStatus"),
                              "bidding": g.get("biddingStrategy"),
                              # defaultBid only applies to manual bidding; it reads 0 under MAX_CONVERSIONS
                              "defaultBid": g.get("defaultBidAmount"), "cpaGoal": g.get("cpaGoal"),
                              "automatedKeywords": g.get("automatedKeywordsOptIn")}))
    elif a.cmd == "keywords":
        groups = [a.adgroup] if a.adgroup else [g["id"] for g in paged(f"/campaigns/{a.campaign}/adgroups", org)]
        for gid in groups:
            for k in paged(f"/campaigns/{a.campaign}/adgroups/{gid}/targetingkeywords", org):
                print(json.dumps({"adGroup": gid, "id": k["id"], "text": k["text"], "matchType": k["matchType"],
                                  "status": k["status"], "bid": k.get("bidAmount")}))
    elif a.cmd == "report":
        r = report(org, a.days, a.granularity, a.campaign)
        print(f"# last {a.days} days, granularity {a.granularity}")
        for row in r.get("row", []):
            meta = row["metadata"]
            label = meta.get("campaignName") or meta.get("adGroupName") or meta.get("campaignId")
            if a.granularity == "TOTAL":
                print(f"{label}: {fmt_totals(row.get('total'))}  [{meta.get('campaignStatus') or meta.get('adGroupStatus')}]")
            else:
                print(f"{label}:")
                for g in row.get("granularity", []):
                    print(f"  {g['date']}: {fmt_totals(g)}")
        print("GRAND TOTAL:", fmt_totals(r.get("grandTotals", {}).get("total")))
    elif a.cmd in ("keywordreport", "searchterms"):
        kind = "keywords" if a.cmd == "keywordreport" else "searchterms"
        r = keyword_level_report(org, a.campaign, a.days, kind)
        rows = r.get("row", [])
        print(f"# {a.cmd} for campaign {a.campaign}, last {a.days} days — {len(rows)} rows")
        for row in rows:
            m = row["metadata"]; t = row.get("total") or {}
            term = m.get("searchTermText") or m.get("keyword")
            print(f"{term!r:40} [{m.get('adGroupName')}/{m.get('matchType') or m.get('searchTermSource')}] "
                  f"impr={t.get('impressions')} taps={t.get('taps')} installs={t.get('totalInstalls')} "
                  f"spend={(t.get('localSpend') or {}).get('amount')} cpt={(t.get('avgCPT') or {}).get('amount')}")
        print("GRAND TOTAL:", fmt_totals((r.get("grandTotals") or {}).get("total")))
    elif a.cmd == "raw":
        print(json.dumps(api(a.method.upper(), a.path, org, data=a.body), indent=2))


if __name__ == "__main__":
    main()
