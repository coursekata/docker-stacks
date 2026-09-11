#!/usr/bin/env python3
"""Report known advisories against the Python packages a build will install.

Every build runs `pixi update`, so conda and PyPI are already resolved fresh and
nothing here is about staleness. What this answers is the question nothing else
does: did the solver pick a version with a published advisory? That is the signal
to add a floor to pixi.toml, which is a ratchet against the solver backtracking
rather than a bump.

Reads the lock rather than a built image because the lock is the thing that
decides what ships, and it is text: no pull, no build. Conda packages that carry
a PyPI distribution declare it in `purls`; their version lives in the artifact
filename. Native conda libraries have no advisory feed in any tool and are
deliberately out of scope -- `pixi update` on every build is the control there.

DELETE THIS when a standard scanner can read pixi.lock. Nothing does today:
osv-scanner reads Pipfile/poetry/pdm/pylock/uv locks but not pixi, and Trivy has
no pixi analyzer. osv-scalibr, the engine behind osv-scanner, has open work for
exactly this ("Extractor for python/pixilock"). When it lands, replace this file
with that tool rather than maintaining a bespoke parser -- the only reason it
exists is that the ecosystem has not caught up with pixi yet.
"""

import argparse
import json
import re
import sys
import urllib.error
import urllib.request
from collections import defaultdict
from pathlib import Path

OSV_BATCH = "https://api.osv.dev/v1/querybatch"
OSV_VULN = "https://api.osv.dev/v1/vulns/"
BATCH = 400

# conda artifact filenames are <name>-<version>-<build>.<ext>
CONDA_FILE = re.compile(r"/(?P<name>.+)-(?P<version>[^-]+)-(?P<build>[^-]+)\.(?:conda|tar\.bz2)$")
PURL_NAME = re.compile(r"^pkg:pypi/(?P<name>[^@?#]+)")


def post(url, payload):
    request = urllib.request.Request(
        url,
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=60) as response:
        return json.load(response)


def get(url):
    with urllib.request.urlopen(url, timeout=60) as response:
        return json.load(response)


def packages(lock_path):
    """Yield (pypi_name, version, origin) for every Python distribution in the lock."""
    import yaml

    lock = yaml.safe_load(Path(lock_path).read_text())

    # `packages:` is a shared pool that can outlive the environments referencing
    # it, so an un-refreshed lock carries orphans. Reporting those is a false
    # positive about something no image installs.
    installed = set()
    for environment in (lock.get("environments") or {}).values():
        for entries in (environment.get("packages") or {}).values():
            for entry in entries:
                installed.update(entry.values())

    seen = {}

    for entry in lock.get("packages", []):
        if installed and not ({entry.get("conda"), entry.get("pypi")} & installed):
            continue
        if "pypi" in entry and entry.get("name") and entry.get("version"):
            seen[(entry["name"].lower(), entry["version"])] = "pypi"
            continue

        url = entry.get("conda")
        purls = entry.get("purls") or []
        if not url or not purls:
            continue
        match = CONDA_FILE.search(url)
        if not match:
            continue
        version = match.group("version")
        for purl in purls:
            name_match = PURL_NAME.match(purl)
            if name_match:
                seen[(name_match.group("name").lower(), version)] = "conda"

    return [(name, version, origin) for (name, version), origin in sorted(seen.items())]


def query(pairs):
    """Return {(name, version): [vuln_id, ...]} for everything OSV knows about."""
    hits = {}
    for start in range(0, len(pairs), BATCH):
        chunk = pairs[start : start + BATCH]
        payload = {
            "queries": [
                {"package": {"name": name, "ecosystem": "PyPI"}, "version": version}
                for name, version, _ in chunk
            ]
        }
        results = post(OSV_BATCH, payload).get("results", [])
        for (name, version, _), result in zip(chunk, results):
            ids = [vuln["id"] for vuln in result.get("vulns", [])]
            if ids:
                hits[(name, version)] = ids
    return hits


def fixed_versions(detail, name):
    """The versions that resolve this advisory - what a floor in pixi.toml would target."""
    out = []
    for affected in detail.get("affected", []):
        package = affected.get("package", {})
        if package.get("ecosystem") != "PyPI":
            continue
        if package.get("name", "").lower() != name.lower():
            continue
        for entry in affected.get("ranges", []):
            for event in entry.get("events", []):
                if "fixed" in event:
                    out.append(event["fixed"])
    return sorted(set(out))


def severity_of(detail):
    for item in detail.get("severity", []) or []:
        if item.get("score"):
            return item["score"]
    database = detail.get("database_specific") or {}
    return database.get("severity") or "unrated"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("lock", nargs="?", default="pixi.lock")
    parser.add_argument(
        "--fail-on-findings",
        action="store_true",
        help="exit non-zero when anything is found (default: report only)",
    )
    parser.add_argument("--json", dest="as_json", action="store_true")
    args = parser.parse_args()

    pairs = packages(args.lock)
    if not pairs:
        print(f"No Python distributions found in {args.lock}", file=sys.stderr)
        return 1

    try:
        hits = query(pairs)
    except (urllib.error.URLError, TimeoutError) as error:
        # A feed outage must not read as "clean".
        print(f"::error::OSV query failed: {error}", file=sys.stderr)
        return 2

    details = {}
    for ids in hits.values():
        for vuln_id in ids:
            if vuln_id not in details:
                try:
                    details[vuln_id] = get(OSV_VULN + vuln_id)
                except (urllib.error.URLError, TimeoutError):
                    details[vuln_id] = {}

    origin_of = {(name, version): origin for name, version, origin in pairs}
    report = []
    for (name, version), ids in sorted(hits.items()):
        advisories = []
        for vuln_id in ids:
            detail = details.get(vuln_id, {})
            advisories.append(
                {
                    "id": vuln_id,
                    "severity": severity_of(detail),
                    "summary": (detail.get("summary") or "").strip(),
                    "fixed": fixed_versions(detail, name),
                }
            )
        report.append(
            {
                "package": name,
                "version": version,
                "origin": origin_of[(name, version)],
                "advisories": advisories,
            }
        )

    if args.as_json:
        print(json.dumps({"scanned": len(pairs), "findings": report}, indent=2))
    else:
        print(f"Checked {len(pairs)} Python distributions from {args.lock}\n")
        if not report:
            print("No known advisories.")
        for finding in report:
            fixes = sorted({v for a in finding["advisories"] for v in a["fixed"]})
            print(
                f"{finding['package']} {finding['version']} "
                f"({finding['origin']}, {len(finding['advisories'])} advisories)"
                + (f" -> fixed in {', '.join(fixes)}" if fixes else " -> no fix published")
            )
            for advisory in finding["advisories"]:
                summary = advisory["summary"]
                print(
                    f"    {advisory['id']} [{advisory['severity']}] "
                    + (summary[:96] if summary else "")
                )
        counts = defaultdict(int)
        for finding in report:
            counts[finding["origin"]] += 1
        print(
            f"\n{len(report)} affected of {len(pairs)} "
            f"({', '.join(f'{n} via {o}' for o, n in sorted(counts.items()))})"
        )

    return 1 if (report and args.fail_on_findings) else 0


if __name__ == "__main__":
    sys.exit(main())
