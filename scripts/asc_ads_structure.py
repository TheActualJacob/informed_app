#!/usr/bin/env python3
"""Keyword structure for the Informed Apple Ads campaign — the source of truth for
what we bid on. Idempotent: re-running only adds what is missing.

  scripts/asc_ads_structure.py            # dry run: print what would change
  scripts/asc_ads_structure.py --apply    # create missing ad groups / keywords / negatives

Design (Apple's Maximize Conversions rules, see docs/RELEASE.md):
  * One campaign. Max Conversions requires exactly one automated Search Match ad
    group per campaign, so intent is split by AD GROUP, not by campaign.
  * "Automated" (Apple-created): Search Match discovery. Every exact keyword we bid on
    elsewhere is an EXACT negative here, so known queries route to the exact groups
    and its search-terms report only shows new discoveries.
  * "Exact - Category" / "Exact - Competitor" / "Exact - Brand": exact-match intent.
  * "Broad - Core": broad match on the core terms to catch phrasings the exact list
    misses; same exact negatives as Automated so it never competes with them.
  * Campaign-level BROAD negatives cut the wrong-intent apps that rank for our terms
    (fake-news *makers*, parody/prank apps, true-or-false quizzes).
  Bids are managed by Apple (target CPA on the campaign); keywords carry no bid.
"""
import argparse
import datetime as dt
import json
import sys

import asc_ads

CAMPAIGN_ID = 2144655036          # "informed fact checker" (org 24089240)

EXACT_CATEGORY = [
    "fact check", "fact checker", "fact checking", "fact check app", "fact checker app", "factcheck", "fact checks",
    "ai fact check", "ai fact checker", "fact check ai",
    "misinformation", "misinformation checker", "disinformation",
    "fake news detector", "fake news checker", "fake news check", "fake news app",
    "news fact check", "fact check news", "verify news", "news verification", "news checker", "news credibility",
    "is it true", "is this true", "true or false", "real or fake",
    "truth checker", "truth check", "truth app",
    "claim checker", "verify claims", "check facts",
    "debunk", "debunker",
    "fact check tiktok", "tiktok fact check", "fact check instagram", "instagram fact check",
    "fact check reels", "reel fact check", "fact check video", "video fact checker", "fact check youtube",
    "media bias", "news bias", "media bias checker", "source checker", "verify sources", "credibility checker",
    "deepfake detector", "ai video detector", "ai content detector", "ai generated detector", "ai image detector",
]
EXACT_COMPETITOR = [
    "snopes", "ground news", "allsides", "newsguard", "politifact", "factcheck org",
    "verifi", "verifi fact checker", "the fact check", "dbunk", "straight arrow news", "oigetit",
    "media bias fact check", "logically", "factiverse", "verdict fact check", "verifact",
]
EXACT_BRAND = [
    "informed", "informed app", "informed ai", "informed ai fact checker", "informed fact checker",
    "informed fact check", "get informed",
]
BROAD_CORE = [
    "fact check", "fact checker", "misinformation", "fake news detector", "news verification",
    "deepfake detector", "ai fact checker",
]
CAMPAIGN_NEGATIVES_BROAD = [
    "parody", "prank", "maker", "generator", "meme", "template", "quiz", "trivia", "game", "games", "faker",
]

GROUPS = {  # name -> (matchType, keywords)
    "Exact - Category":   ("EXACT", EXACT_CATEGORY),
    "Exact - Competitor": ("EXACT", EXACT_COMPETITOR),
    "Exact - Brand":      ("EXACT", EXACT_BRAND),
    "Broad - Core":       ("BROAD", BROAD_CORE),
}
ALL_EXACT = sorted(set(EXACT_CATEGORY + EXACT_COMPETITOR + EXACT_BRAND))
ROUTING_NEGATIVES_FOR = ["Automated", "Broad - Core"]   # groups that get ALL_EXACT as exact negatives


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--org")
    a = ap.parse_args()
    org = asc_ads.resolve_org(a.org)
    cid = CAMPAIGN_ID
    changes = 0

    camp = asc_ads.api("GET", f"/campaigns/{cid}", org)["data"]
    print(f"campaign {cid} '{camp['name']}' bidding={camp['biddingStrategy']} targetCpa={camp.get('targetCpa')} "
          f"daily={camp['dailyBudgetAmount']} status={camp['status']}/{camp['servingStatus']}")

    groups = {g["name"]: g for g in asc_ads.paged(f"/campaigns/{cid}/adgroups", org)}
    auto = [g for g in groups.values() if g.get("automatedKeywordsRequired")]
    if not auto:
        sys.exit("no automated ad group in the campaign — Max Conversions cannot run; create it in the UI first")
    auto_name = auto[0]["name"]
    if auto_name != "Automated":
        ROUTING_NEGATIVES_FOR[ROUTING_NEGATIVES_FOR.index("Automated")] = auto_name

    # 1. ad groups
    for name in GROUPS:
        if name in groups:
            print(f"ad group exists: {name} ({groups[name]['id']})")
            continue
        print(f"+ ad group: {name}")
        changes += 1
        if a.apply:
            # startTime is required and must be in the future (UTC, no zone suffix)
            start = (dt.datetime.now(dt.timezone.utc) + dt.timedelta(minutes=2)).strftime("%Y-%m-%dT%H:%M:%S.000")
            body = {"name": name, "automatedKeywordsOptIn": False, "pricingModel": "CPC", "status": "ENABLED",
                    "startTime": start,
                    "targetingDimensions": {"deviceClass": {"included": ["IPHONE", "IPAD"]}}}
            groups[name] = asc_ads.api("POST", f"/campaigns/{cid}/adgroups", org, data=json.dumps(body))["data"]
            print(f"  created {groups[name]['id']}")

    # 2. targeting keywords
    for name, (match, words) in GROUPS.items():
        g = groups.get(name)
        if not g:
            print(f"  (dry run) would add {len(words)} {match} keywords to {name}")
            continue
        have = {(k["text"].lower(), k["matchType"].upper()) for k in asc_ads.paged(f"/campaigns/{cid}/adgroups/{g['id']}/targetingkeywords", org)}
        missing = [w for w in words if (w.lower(), match) not in have]
        print(f"{name}: {len(have)} keywords present, {len(missing)} to add")
        if missing:
            changes += len(missing)
            if a.apply:
                asc_ads.api("POST", f"/campaigns/{cid}/adgroups/{g['id']}/targetingkeywords/bulk", org,
                            data=json.dumps([{"text": w, "matchType": match} for w in missing]))
                print(f"  added: {', '.join(missing)}")

    # 3. routing negatives on Automated + Broad
    for name in ROUTING_NEGATIVES_FOR:
        g = groups.get(name)
        if not g:
            print(f"  (dry run) would add {len(ALL_EXACT)} EXACT negatives to {name}")
            continue
        have = {(k["text"].lower(), k["matchType"].upper()) for k in asc_ads.paged(f"/campaigns/{cid}/adgroups/{g['id']}/negativekeywords", org)}
        missing = [w for w in ALL_EXACT if (w.lower(), "EXACT") not in have]
        print(f"{name} negatives: {len(have)} present, {len(missing)} to add")
        if missing:
            changes += len(missing)
            if a.apply:
                asc_ads.api("POST", f"/campaigns/{cid}/adgroups/{g['id']}/negativekeywords/bulk", org,
                            data=json.dumps([{"text": w, "matchType": "EXACT"} for w in missing]))
                print(f"  added {len(missing)} exact negatives")

    # 4. campaign-level wrong-intent negatives
    have = {(k["text"].lower(), k["matchType"].upper()) for k in asc_ads.paged(f"/campaigns/{cid}/negativekeywords", org)}
    missing = [w for w in CAMPAIGN_NEGATIVES_BROAD if (w.lower(), "BROAD") not in have]
    print(f"campaign negatives: {len(have)} present, {len(missing)} to add")
    if missing:
        changes += len(missing)
        if a.apply:
            asc_ads.api("POST", f"/campaigns/{cid}/negativekeywords/bulk", org,
                        data=json.dumps([{"text": w, "matchType": "BROAD"} for w in missing]))
            print(f"  added: {', '.join(missing)}")

    print(f"\n{'APPLIED' if a.apply else 'DRY RUN'}: {changes} change(s)")


if __name__ == "__main__":
    main()
