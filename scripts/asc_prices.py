#!/usr/bin/env python3
"""Inspect or change Informed's subscription prices in App Store Connect.

  scripts/asc_prices.py list
  scripts/asc_prices.py set --monthly 8.99 --annual 89.99 --start YYYY-MM-DD [--apply]

`set` without --apply is a dry run. With --apply it schedules the USA price and
then the equalized price in every other territory for the same start date,
preserving existing subscribers' current price (no consent flow).

See docs/RELEASE.md for the rules (approved subscriptions need a future
startDate; USA prices don't auto-equalize).
"""
import argparse
import datetime
import json
import sys

from asc_common import PRODUCTS, api, paged


def subscriptions():
    apps = api("GET", f"/apps?filter[bundleId]=com.jacob.informed")["data"]
    if not apps:
        sys.exit("app not found")
    subs = {}
    for g in api("GET", f"/apps/{apps[0]['id']}/subscriptionGroups")["data"]:
        for s in api("GET", f"/subscriptionGroups/{g['id']}/subscriptions?limit=50")["data"]:
            subs[s["attributes"]["productId"]] = s
    return subs


def prices(sub_id, territory="USA"):
    d = api("GET", f"/subscriptions/{sub_id}/prices?include=subscriptionPricePoint&limit=200&filter[territory]={territory}")
    pp = {i["id"]: i for i in d.get("included", []) if i["type"] == "subscriptionPricePoints"}
    rows = []
    for p in d["data"]:
        point = pp[p["relationships"]["subscriptionPricePoint"]["data"]["id"]]
        rows.append((p["attributes"].get("startDate") or "now", point["attributes"]["customerPrice"],
                     "kept-for-existing" if p["attributes"].get("preserved") else ""))
    return sorted(rows)


def usa_price_point(sub_id, usd):
    for pp in paged(f"/subscriptions/{sub_id}/pricePoints?filter[territory]=USA&limit=200"):
        if pp["attributes"]["customerPrice"] == f"{usd:.2f}":
            return pp["id"]
    sys.exit(f"no USA price point for ${usd:.2f}")


def schedule(sub_id, point_id, start):
    body = {"data": {"type": "subscriptionPrices",
                     "attributes": {"preserveCurrentPrice": True, "startDate": start},
                     "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sub_id}},
                                       "subscriptionPricePoint": {"data": {"type": "subscriptionPricePoints", "id": point_id}}}}}
    return api("POST", "/subscriptionPrices", data=json.dumps(body))


def main():
    ap = argparse.ArgumentParser()
    sp = ap.add_subparsers(dest="cmd", required=True)
    sp.add_parser("list")
    st = sp.add_parser("set")
    st.add_argument("--monthly", type=float)
    st.add_argument("--annual", type=float)
    st.add_argument("--start", help="YYYY-MM-DD; Apple requires at least its next day")
    st.add_argument("--apply", action="store_true")
    a = ap.parse_args()

    subs = subscriptions()
    for name, pid in PRODUCTS.items():
        s = subs.get(pid)
        if not s:
            print(f"{name}: {pid} NOT FOUND")
            continue
        print(f"{name} ({pid}, id {s['id']}, {s['attributes'].get('state')}) USA: {prices(s['id'])}")
        if a.cmd != "set":
            continue
        usd = a.monthly if name == "monthly" else a.annual
        if usd is None:
            continue
        start = a.start or (datetime.date.today() + datetime.timedelta(days=1)).isoformat()
        usa = usa_price_point(s["id"], usd)
        print(f"  -> ${usd:.2f} USA from {start} (price point {usa}), then equalized in all other territories")
        if not a.apply:
            continue
        schedule(s["id"], usa, start)
        done = 0
        failed = []
        for pp in paged(f"/subscriptionPricePoints/{usa}/equalizations?include=territory&limit=200"):
            terr = pp["relationships"]["territory"]["data"]["id"]
            if terr == "USA":
                continue
            try:
                schedule(s["id"], pp["id"], start)
                done += 1
            except SystemExit as e:  # api() exits on error; keep going for other territories
                failed.append((terr, str(e)[:80]))
        print(f"  applied: USA + {done} territories; failed: {failed[:5]}{' …' if len(failed) > 5 else ''}")


if __name__ == "__main__":
    main()
