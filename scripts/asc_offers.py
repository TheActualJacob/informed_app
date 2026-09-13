#!/usr/bin/env python3
"""Inspect or create the free-trial introductory offer on Informed's subscriptions.

  scripts/asc_offers.py list
  scripts/asc_offers.py create [--duration ONE_WEEK] [--periods 1] [--only monthly|annual] [--apply]
  scripts/asc_offers.py delete --id OFFER_ID [--apply]

`create` without --apply is a dry run. With --apply it creates a FREE_TRIAL
introductory offer (default: one week) on each Pro subscription, in every
territory that doesn't have one yet. It is idempotent: territories that already
carry an offer are skipped, so re-running after a partial failure only fills
the gaps.

Apple applies introductory offers automatically at purchase (once per Apple ID
per subscription group); RevenueCat needs no configuration — the app reads
`StoreProduct.introductoryDiscount` to show "7 days free, then $X".
See docs/RELEASE.md.
"""
import argparse
import json
import sys

from asc_common import PRODUCTS, api, paged

DURATIONS = ("THREE_DAYS", "ONE_WEEK", "TWO_WEEKS", "ONE_MONTH", "TWO_MONTHS",
             "THREE_MONTHS", "SIX_MONTHS", "ONE_YEAR")


def subscriptions():
    apps = api("GET", "/apps?filter[bundleId]=com.jacob.informed")["data"]
    if not apps:
        sys.exit("app not found")
    subs = {}
    for g in api("GET", f"/apps/{apps[0]['id']}/subscriptionGroups")["data"]:
        for s in api("GET", f"/subscriptionGroups/{g['id']}/subscriptions?limit=50")["data"]:
            subs[s["attributes"]["productId"]] = s
    return subs


def offers(sub_id):
    """{territory_id: offer} for every introductory offer on a subscription."""
    out = {}
    for o in paged(f"/subscriptions/{sub_id}/introductoryOffers?include=territory&limit=200"):
        terr = ((o.get("relationships") or {}).get("territory") or {}).get("data") or {}
        out[terr.get("id") or "?"] = o
    return out


def territories():
    return [t["id"] for t in paged("/territories?limit=200")]


def create(sub_id, territory, duration, periods):
    body = {"data": {"type": "subscriptionIntroductoryOffers",
                     "attributes": {"duration": duration, "offerMode": "FREE_TRIAL",
                                    "numberOfPeriods": periods},
                     "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sub_id}},
                                       "territory": {"data": {"type": "territories", "id": territory}}}}}
    return api("POST", "/subscriptionIntroductoryOffers", data=json.dumps(body))


def describe(o):
    a = o["attributes"]
    return f"{a.get('offerMode')} {a.get('numberOfPeriods')}×{a.get('duration')}" \
           f"{' from ' + a['startDate'] if a.get('startDate') else ''}" \
           f"{' until ' + a['endDate'] if a.get('endDate') else ''}"


def main():
    ap = argparse.ArgumentParser()
    sp = ap.add_subparsers(dest="cmd", required=True)
    sp.add_parser("list")
    cr = sp.add_parser("create")
    cr.add_argument("--duration", default="ONE_WEEK", choices=DURATIONS)
    cr.add_argument("--periods", type=int, default=1)
    cr.add_argument("--only", choices=list(PRODUCTS))
    cr.add_argument("--apply", action="store_true")
    de = sp.add_parser("delete")
    de.add_argument("--id", required=True)
    de.add_argument("--apply", action="store_true")
    a = ap.parse_args()

    if a.cmd == "delete":
        print(f"DELETE /subscriptionIntroductoryOffers/{a.id}")
        if a.apply:
            api("DELETE", f"/subscriptionIntroductoryOffers/{a.id}")
            print("deleted")
        return

    subs = subscriptions()
    all_terr = territories() if a.cmd == "create" else None
    for name, pid in PRODUCTS.items():
        s = subs.get(pid)
        if not s:
            print(f"{name}: {pid} NOT FOUND")
            continue
        existing = offers(s["id"])
        kinds = {}
        for terr, o in existing.items():
            kinds.setdefault(describe(o), []).append(terr)
        summary = "; ".join(f"{k} in {len(v)} territories" for k, v in kinds.items()) or "no introductory offers"
        print(f"{name} ({pid}, id {s['id']}, {s['attributes'].get('state')}): {summary}")
        if a.cmd != "create" or (a.only and a.only != name):
            continue
        missing = [t for t in all_terr if t not in existing]
        print(f"  -> FREE_TRIAL {a.periods}×{a.duration} in {len(missing)} territories without an offer"
              f" ({len(all_terr) - len(missing)} already have one)")
        if not a.apply or not missing:
            continue
        done, failed = 0, []
        for terr in missing:
            try:
                create(s["id"], terr, a.duration, a.periods)
                done += 1
            except SystemExit as e:  # api() exits on error; keep going for other territories
                failed.append((terr, str(e)[:120]))
        print(f"  created: {done}; failed: {failed[:5]}{' …' if len(failed) > 5 else ''}")


if __name__ == "__main__":
    main()
