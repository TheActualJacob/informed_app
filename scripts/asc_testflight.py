#!/usr/bin/env python3
"""TestFlight helper for Informed.

  scripts/asc_testflight.py status                      # recent builds + beta groups
  scripts/asc_testflight.py wait --version 1.1.6 [--notes "What to test…"] [--timeout 1500]

`wait` polls until the build for that version is processed (VALID), then sets
the en-US "What to Test" text. The internal "Marketing" group has automatic
distribution, so a VALID build is already in beta testing — no assignment step
(the API refuses manual assignment to auto-distribution groups).
"""
import argparse
import json
import sys
import time

from asc_common import APP_ID, api


def builds(version=None, limit=10):
    q = f"/builds?filter[app]={APP_ID}&sort=-uploadedDate&limit={limit}&include=preReleaseVersion,buildBetaDetail"
    if version:
        q += f"&filter[preReleaseVersion.version]={version}"
    d = api("GET", q)
    inc = {(i["type"], i["id"]): i for i in d.get("included", [])}
    out = []
    for b in d["data"]:
        a = b["attributes"]
        prv = b["relationships"].get("preReleaseVersion", {}).get("data")
        bbd = b["relationships"].get("buildBetaDetail", {}).get("data")
        beta = inc.get(("buildBetaDetails", bbd["id"]))["attributes"] if bbd else {}
        out.append({"id": b["id"],
                    "version": inc.get(("preReleaseVersions", prv["id"]))["attributes"]["version"] if prv else "?",
                    "build": a["version"], "processingState": a["processingState"],
                    "uploaded": a["uploadedDate"], "expired": a["expired"],
                    "internal": beta.get("internalBuildState"), "external": beta.get("externalBuildState")})
    return out


def groups():
    return [{"id": g["id"], "name": g["attributes"]["name"], "internal": g["attributes"]["isInternalGroup"],
             "autoDistribute": g["attributes"].get("hasAccessToAllBuilds")}
            for g in api("GET", f"/apps/{APP_ID}/betaGroups?limit=50")["data"]]


def set_notes(build_id, notes):
    loc = api("GET", f"/builds/{build_id}/betaBuildLocalizations")["data"]
    en = next((l for l in loc if l["attributes"]["locale"] == "en-US"), None)
    if en:
        api("PATCH", f"/betaBuildLocalizations/{en['id']}",
            data=json.dumps({"data": {"type": "betaBuildLocalizations", "id": en["id"], "attributes": {"whatsNew": notes}}}))
    else:
        api("POST", "/betaBuildLocalizations",
            data=json.dumps({"data": {"type": "betaBuildLocalizations", "attributes": {"locale": "en-US", "whatsNew": notes},
                                      "relationships": {"build": {"data": {"type": "builds", "id": build_id}}}}}))


def main():
    ap = argparse.ArgumentParser()
    sp = ap.add_subparsers(dest="cmd", required=True)
    sp.add_parser("status")
    w = sp.add_parser("wait")
    w.add_argument("--version", required=True)
    w.add_argument("--notes")
    w.add_argument("--timeout", type=int, default=1500, help="seconds to wait for processing")
    a = ap.parse_args()

    if a.cmd == "status":
        for b in builds():
            print("build:", json.dumps(b))
        for g in groups():
            print("group:", json.dumps(g))
        return

    deadline = time.time() + a.timeout
    while True:
        live = [b for b in builds(a.version, limit=5) if not b["expired"]]
        if live:
            b = live[0]
            print(f"[{time.strftime('%H:%M:%S')}] {a.version} processing={b['processingState']} internal={b['internal']}", flush=True)
            if b["processingState"] == "VALID":
                break
            if b["processingState"] in ("FAILED", "INVALID"):
                sys.exit("processing failed — check App Store Connect for the reason")
        else:
            print(f"[{time.strftime('%H:%M:%S')}] {a.version} not visible yet", flush=True)
        if time.time() > deadline:
            sys.exit("timed out waiting for processing")
        time.sleep(20)
    if a.notes:
        set_notes(b["id"], a.notes)
        print("test notes set")


if __name__ == "__main__":
    main()
