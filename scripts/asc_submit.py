#!/usr/bin/env python3
"""Prepare and submit an App Store version from the command line.

  scripts/asc_submit.py status                       # versions, their builds, open review submissions
  scripts/asc_submit.py attach --version 1.1.7       # attach the processed build 1.1.7 to App Store version 1.1.7
  scripts/asc_submit.py submit --version 1.1.7       # attach (if needed) and submit for App Review
  scripts/asc_submit.py cancel                       # cancel the open review submission

The App Store version itself is created with
  POST /appStoreVersions {platform: IOS, versionString, releaseType: AFTER_APPROVAL}
(see docs/RELEASE.md); its localizations are copied from the previous version,
so only `whatsNew` normally needs a PATCH on the en-US appStoreVersionLocalization.
Review submissions are the ASC "Add for review → Submit" flow:
reviewSubmission (per app/platform) + reviewSubmissionItem (the version) + submitted=true.
"""
import argparse
import json
import sys

from asc_common import APP_ID, api

OPEN_STATES = ("READY_FOR_REVIEW", "WAITING_FOR_REVIEW", "IN_REVIEW", "UNRESOLVED_ISSUES")


def versions():
    d = api("GET", f"/apps/{APP_ID}/appStoreVersions?limit=5&include=build"
                   "&fields[appStoreVersions]=versionString,appStoreState,appVersionState,build"
                   "&fields[builds]=version,processingState")
    builds = {b["id"]: b["attributes"] for b in d.get("included", []) if b["type"] == "builds"}
    out = []
    for v in d["data"]:
        b = ((v.get("relationships") or {}).get("build") or {}).get("data")
        out.append((v["id"], v["attributes"], builds.get(b["id"]) if b else None, b["id"] if b else None))
    return out


def version_by_string(s):
    for vid, attrs, build, build_id in versions():
        if attrs["versionString"] == s:
            return vid, attrs, build, build_id
    sys.exit(f"App Store version {s} not found — create it first (see docs/RELEASE.md)")


def build_for(version_string):
    d = api("GET", f"/builds?filter[app]={APP_ID}&filter[version]={version_string}&sort=-uploadedDate&limit=1"
                   "&fields[builds]=version,processingState,uploadedDate")
    if not d["data"]:
        sys.exit(f"no build {version_string} uploaded yet")
    b = d["data"][0]
    if b["attributes"]["processingState"] != "VALID":
        sys.exit(f"build {version_string} is {b['attributes']['processingState']} — wait for processing")
    return b["id"]


def submissions():
    d = api("GET", f"/apps/{APP_ID}/reviewSubmissions?filter[platform]=IOS&limit=5"
                   "&fields[reviewSubmissions]=state,submittedDate,platform")
    return d["data"]


def attach(version_string):
    vid, attrs, build, build_id = version_by_string(version_string)
    bid = build_for(version_string)
    if build_id == bid:
        print(f"build {version_string} already attached to version {version_string}")
        return vid
    api("PATCH", f"/appStoreVersions/{vid}/relationships/build",
        data=json.dumps({"data": {"type": "builds", "id": bid}}))
    print(f"attached build {version_string} ({bid}) to version {version_string} ({vid})")
    return vid


def submit(version_string):
    vid = attach(version_string)
    open_subs = [s for s in submissions() if s["attributes"]["state"] in OPEN_STATES]
    if open_subs:
        rs = open_subs[0]
        print(f"reusing open review submission {rs['id']} ({rs['attributes']['state']})")
    else:
        rs = api("POST", "/reviewSubmissions", data=json.dumps(
            {"data": {"type": "reviewSubmissions", "attributes": {"platform": "IOS"},
                      "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}}}}))["data"]
        print(f"created review submission {rs['id']}")
    items = api("GET", f"/reviewSubmissions/{rs['id']}/items?fields[reviewSubmissionItems]=state,appStoreVersion")["data"]
    if not any(((i.get("relationships") or {}).get("appStoreVersion") or {}).get("data", {}).get("id") == vid for i in items):
        api("POST", "/reviewSubmissionItems", data=json.dumps(
            {"data": {"type": "reviewSubmissionItems",
                      "relationships": {"reviewSubmission": {"data": {"type": "reviewSubmissions", "id": rs["id"]}},
                                        "appStoreVersion": {"data": {"type": "appStoreVersions", "id": vid}}}}}))
        print(f"added version {version_string} to the submission")
    if rs["attributes"]["state"] == "READY_FOR_REVIEW":
        api("PATCH", f"/reviewSubmissions/{rs['id']}", data=json.dumps(
            {"data": {"type": "reviewSubmissions", "id": rs["id"], "attributes": {"submitted": True}}}))
        print("submitted for App Review")
    else:
        print(f"submission state is {rs['attributes']['state']}; nothing more to do")


def cancel():
    open_subs = [s for s in submissions() if s["attributes"]["state"] in OPEN_STATES]
    if not open_subs:
        print("no open review submission")
        return
    rs = open_subs[0]
    api("PATCH", f"/reviewSubmissions/{rs['id']}", data=json.dumps(
        {"data": {"type": "reviewSubmissions", "id": rs["id"], "attributes": {"canceled": True}}}))
    print(f"cancelled review submission {rs['id']}")


def main():
    ap = argparse.ArgumentParser()
    sp = ap.add_subparsers(dest="cmd", required=True)
    sp.add_parser("status")
    for name in ("attach", "submit"):
        p = sp.add_parser(name)
        p.add_argument("--version", required=True)
    sp.add_parser("cancel")
    a = ap.parse_args()
    if a.cmd == "status":
        for vid, attrs, build, _ in versions():
            print(f"{attrs['versionString']}: {attrs.get('appStoreState')} / {attrs.get('appVersionState')}"
                  f" — build {build['version'] + ' ' + build['processingState'] if build else 'none'} ({vid})")
        for s in submissions():
            print(f"review submission {s['id']}: {s['attributes']['state']} submitted {s['attributes'].get('submittedDate')}")
    elif a.cmd == "attach":
        attach(a.version)
    elif a.cmd == "submit":
        submit(a.version)
    elif a.cmd == "cancel":
        cancel()


if __name__ == "__main__":
    main()
