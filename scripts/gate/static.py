#!/usr/bin/env python3
"""The static release gate.

Everything here is provable from committed text, in seconds, before any image
exists: pixi.lock containment across the ladder, the solve-group split that
keeps exercises-notebook's asttokens ceiling off the ladder, cross-arch
version equality over the packages we actually name, the CRAN repository
configuration, the R refs in r/, the feature ladder pixi.toml defines for
both languages, the test layer staying out of published images, and CI Action
pinning.

python3 + PyYAML rather than bash/yq because pixi.lock is 632KB of YAML and
the repo carries no other YAML tooling; both are present on ubuntu-24.04
runners and locally.
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
import time
import tomllib
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent.parent

# One-line edits, on purpose: deleting "default" from channels or dropping a
# platform later is a change here, not a hunt through the checks below.
ALLOWED_CHANNELS = {"conda-forge", "default"}
ALLOWED_PLATFORMS = {"linux-64", "linux-aarch64"}

# The named numeric core: transitively pulled math/runtime libraries whose
# cross-arch drift is exactly the failure mode this gate exists to catch,
# even though none of them is a literal pixi.toml dependency key.
GATED_CORE = {
    "libblas", "libcblas", "liblapack", "libopenblas", "libgfortran",
    "libgfortran5", "libgcc", "libstdcxx", "libgomp", "python", "r-base",
    "numpy", "scipy", "pandas", "tbb",
}

PPM_LATEST = "https://packagemanager.posit.co/cran/__linux__/noble/latest"
SHA_RE = re.compile(r"^[0-9a-f]{40}$")

# A bare name resolves from CRAN; a name-overridden or plain GitHub ref must
# carry a 40-char commit SHA, never a movable tag or branch.
CRAN_REF_RE = re.compile(r"^[A-Za-z][A-Za-z0-9._]*$")
GITHUB_REF_RE = re.compile(
    r"^([A-Za-z][A-Za-z0-9._]*=)?[A-Za-z0-9._-]+/[A-Za-z0-9._-]+@[0-9a-f]{40}(\?reinstall)?$"
)

# Four notebook tiers, the nesting pixi.toml's `features` lists must express
# for both languages now that R composition rides the same manifest.
# datascience-core and exercises-notebook are checked separately (env-name
# parity, not nesting).
LADDER = ["base-r-notebook", "essentials-notebook", "r-notebook", "datascience-notebook"]


def load_toml(path: Path) -> dict:
    return tomllib.loads(path.read_text())


def parse_conda_filename(url: str) -> tuple[str, str, str]:
    filename = url.rsplit("/", 1)[-1]
    for ext in (".conda", ".tar.bz2"):
        if filename.endswith(ext):
            stem = filename[: -len(ext)]
            break
    else:
        raise ValueError(f"unrecognized conda package filename: {url}")
    name, version, build = stem.rsplit("-", 2)
    return name, version, build


def build_package_index(lock: dict) -> dict[str, tuple[str, str]]:
    """url -> (name, version), for both conda (parsed from the filename) and
    pypi (name/version are already fields) entries in the lock's package pool."""
    index: dict[str, tuple[str, str]] = {}
    for pkg in lock["packages"]:
        if "conda" in pkg:
            name, version, _build = parse_conda_filename(pkg["conda"])
            index[pkg["conda"]] = (name, version)
        elif "pypi" in pkg:
            index[pkg["pypi"]] = (pkg["name"], pkg["version"])
    return index


def env_packages(lock: dict, index: dict, env: str, platform: str) -> dict[str, str]:
    entries = lock["environments"][env]["packages"].get(platform, [])
    out: dict[str, str] = {}
    for e in entries:
        url = e.get("conda") or e.get("pypi")
        name, version = index[url]
        out[name] = version
    return out


def pixi_dependency_names(pixi: dict) -> set[str]:
    names = set(pixi.get("dependencies", {}))
    for feat in pixi.get("feature", {}).values():
        names |= set(feat.get("dependencies", {}))
    return names


def solve_group_main(pixi: dict) -> dict[str, dict]:
    return {n: e for n, e in pixi["environments"].items() if e.get("solve-group") == "main"}


# --------------------------------------------------------------------------
# Checks. Each appends "check: coordinate" strings to `failures`.
# --------------------------------------------------------------------------

def check_lock_fresh(failures: list[str], committed: bytes) -> None:
    # On pixi 0.63.2, `pixi lock --check` against a stale lock REWRITES
    # pixi.lock on disk (then exits 1) instead of just reporting staleness —
    # not read-only despite the name. `committed` is the lock content this
    # process read before invoking pixi; every other check must keep using
    # that, and if pixi rewrote the file this check restores it, because the
    # gate must never itself be a pixi.lock writer.
    lock_path = ROOT / "pixi.lock"
    try:
        subprocess.run(
            ["pixi", "lock", "--check"], cwd=ROOT, check=True,
            capture_output=True, text=True, timeout=60,
        )
    except FileNotFoundError:
        failures.append("pixi-lock-check: pixi is not on PATH")
    except subprocess.CalledProcessError as e:
        detail = (e.stdout + e.stderr).strip()
        failures.append(f"pixi-lock-check: pixi.lock does not match pixi.toml\n{detail}")
    finally:
        if lock_path.read_bytes() != committed:
            lock_path.write_bytes(committed)
            failures.append(
                "pixi-lock-check: `pixi lock --check` rewrote pixi.lock on disk; "
                "restored the committed bytes — this gate must never be a lock-writer"
            )


def check_channels_platforms(failures: list[str], pixi: dict) -> None:
    channels = set(pixi["workspace"]["channels"])
    extra = channels - ALLOWED_CHANNELS
    if extra:
        failures.append(f"channels: {sorted(extra)} not in the allowlist {sorted(ALLOWED_CHANNELS)}")

    platforms = set(pixi["workspace"]["platforms"])
    if platforms != ALLOWED_PLATFORMS:
        failures.append(f"platforms: {sorted(platforms)} != {sorted(ALLOWED_PLATFORMS)}")


def check_solve_group(failures: list[str], pixi: dict) -> None:
    # Splitting the group silently breaks same-version-across-tiers without
    # touching a single feature list, so this gets its own assertion rather
    # than riding on the containment check.
    for name, env in pixi["environments"].items():
        group = env.get("solve-group")
        if name == "exercises-notebook":
            if group is not None:
                failures.append(
                    f"solve-group: exercises-notebook must declare none (its own group "
                    f"keeps pythonwhat's asttokens ceiling off the ladder); found {group!r}"
                )
        elif group != "main":
            failures.append(f"solve-group: {name} must declare solve-group = \"main\"; found {group!r}")


def check_containment(failures: list[str], pixi: dict, lock: dict, index: dict) -> None:
    # Pairs are derived from the feature lattice, not a hardcoded chain, so
    # adding an environment stays correct without touching this check.
    group = solve_group_main(pixi)
    for a in group:
        fa = set(group[a]["features"])
        for b in group:
            if a == b:
                continue
            fb = set(group[b]["features"])
            if not fa < fb:  # strict subset only; equal feature sets aren't a rung
                continue
            for platform in sorted(ALLOWED_PLATFORMS):
                pa = env_packages(lock, index, a, platform)
                pb = env_packages(lock, index, b, platform)
                for name in sorted(set(pa) - set(pb)):
                    failures.append(f"containment: {a} carries {name} {pa[name]}, absent from {b} ({platform})")
                for name in sorted(set(pa) & set(pb)):
                    if pa[name] != pb[name]:
                        failures.append(
                            f"containment: {a}.{name}={pa[name]} != {b}.{name}={pb[name]} ({platform})"
                        )


def check_cross_arch_gated(failures: list[str], pixi: dict, lock: dict, index: dict) -> set[str]:
    gated = GATED_CORE | pixi_dependency_names(pixi)
    for env in pixi["environments"]:
        pa = env_packages(lock, index, env, "linux-64")
        pb = env_packages(lock, index, env, "linux-aarch64")
        for name in sorted(gated):
            va, vb = pa.get(name), pb.get(name)
            if va is None and vb is None:
                continue
            if va != vb:
                failures.append(f"cross-arch: {env}.{name} linux-64={va!r} linux-aarch64={vb!r}")
    return gated


def report_cross_arch_rest(pixi: dict, lock: dict, index: dict, gated: set[str]) -> None:
    """Never gates — printed so the ungated majority stays visible. Compared
    over a name-normalized namespace: some conda builds put the platform in
    the package name itself (e.g. gcc_linux-64), which isn't a real mismatch."""

    def normalize(name: str) -> str:
        for suffix in ("_linux-64", "_linux-aarch64"):
            if name.endswith(suffix):
                return name[: -len(suffix)]
        return name

    mismatches = 0
    for env in pixi["environments"]:
        pa = {normalize(n): v for n, v in env_packages(lock, index, env, "linux-64").items()}
        pb = {normalize(n): v for n, v in env_packages(lock, index, env, "linux-aarch64").items()}
        for name in sorted(set(pa) & set(pb)):
            if name in gated or pa[name] == pb[name]:
                continue
            mismatches += 1
            print(f"report cross-arch (ungated): {env}.{name} linux-64={pa[name]} linux-aarch64={pb[name]}")
    print(f"report cross-arch (ungated): {mismatches} version mismatch(es) outside the gated zone")


def check_rprofile(failures: list[str]) -> None:
    text = (ROOT / "Rprofile.site").read_text()
    code = "\n".join(line.split("#", 1)[0] for line in text.splitlines())

    # Counted as a bare "options(repos =" occurrence, not via the paren-balanced
    # call regex below: a second call can smuggle extra repos through a nested
    # paren (e.g. c(getOption("repos"), CRAN2 = ...)) that the call regex's
    # single-level `[^)]*` can't see past, so this count is what actually
    # enforces "exactly one repos-setting call" against that shape.
    repo_calls = re.findall(r"options\(\s*repos\s*=", code)
    if len(repo_calls) != 1:
        failures.append(f"Rprofile.site: found {len(repo_calls)} options(repos = ...) calls, expected exactly one")

    m = re.search(r"options\(repos\s*=\s*c\(([^)]*)\)\)", code)
    if not m:
        failures.append("Rprofile.site: no options(repos = c(...)) call found")
    else:
        entries = [e.strip() for e in m.group(1).split(",") if e.strip()]
        if len(entries) != 1:
            failures.append(f"Rprofile.site: repos must configure exactly one repository, found {entries}")
        elif entries[0].split("=", 1)[0].strip() != "CRAN":
            # pkgcache injects its own rolling cran.rstudio.com unless an entry
            # is literally named CRAN, so the name is what makes the pin hold.
            failures.append(f"Rprofile.site: the one repository must be named CRAN, found {entries[0]!r}")

    if "pkg.use_bioconductor = FALSE" not in text:
        failures.append("Rprofile.site: pak adds five rolling Bioconductor repos unless pkg.use_bioconductor = FALSE")

    if "HTTPUserAgent" not in text:
        failures.append("Rprofile.site: HTTPUserAgent is unset — PPM serves source instead of binaries without it (measured 5.5s vs 1m49s)")

    m = re.search(r'Sys\.getenv\(\s*"PPM"\s*,\s*unset\s*=\s*"([^"]+)"\s*\)', text)
    if not m:
        failures.append("Rprofile.site: no PPM default found (Sys.getenv(\"PPM\", unset = ...))")
    elif m.group(1) != PPM_LATEST:
        failures.append(f"Rprofile.site: PPM default {m.group(1)!r} != {PPM_LATEST!r} — no frozen date belongs anywhere in this file")


def check_r_specs(failures: list[str], pixi: dict) -> None:
    valid_features = set(pixi.get("feature", {})) | {"default"}
    owner: dict[str, str] = {}

    for spec_file in sorted((ROOT / "r").glob("*.txt")):
        if spec_file.stem not in valid_features:
            failures.append(f"r specs: r/{spec_file.name} has no matching feature in pixi.toml")

        for lineno, raw in enumerate(spec_file.read_text().splitlines(), start=1):
            ref = raw.split("#", 1)[0].strip()
            if not ref:
                continue

            if "::" in ref:
                failures.append(
                    f"r specs: r/{spec_file.name}:{lineno}: {ref!r} uses a custom-repo escape hatch — "
                    "custom R repos are banned (R0)"
                )
                continue

            if not (CRAN_REF_RE.fullmatch(ref) or GITHUB_REF_RE.fullmatch(ref)):
                failures.append(
                    f"r specs: r/{spec_file.name}:{lineno}: {ref!r} is not a bare CRAN name or a "
                    "SHA-pinned GitHub ref — a movable tag or bare branch means the same ref resolves "
                    "to different code tomorrow, and two of these are dataset packages where a column "
                    "rename silently invalidates every worked example in a chapter"
                )
                continue

            name = ref.split("=", 1)[0].split("@", 1)[0].split("?", 1)[0]
            if name in owner and owner[name] != spec_file.name:
                failures.append(f"r specs: package {name!r} appears in both r/{owner[name]} and r/{spec_file.name}")
            else:
                owner[name] = spec_file.name


def check_ladder(failures: list[str], pixi: dict) -> None:
    envs = pixi["environments"]
    feats = {name: set(envs[name]["features"]) for name in LADDER if name in envs}
    for lo, hi in zip(LADDER, LADDER[1:]):
        if lo not in feats or hi not in feats:
            continue
        if not feats[lo] < feats[hi]:  # strict: each rung must add something
            failures.append(f"ladder: {lo} features {sorted(feats[lo])} not a strict subset of {hi} features {sorted(feats[hi])}")


def check_environment_features(failures: list[str], pixi: dict) -> None:
    # scripts/get-refs.py reads tier composition by parsing pixi.toml directly
    # (declared features + ["default"]) rather than shelling out to pixi; this
    # is the one assumption that makes that valid.
    try:
        result = subprocess.run(
            ["pixi", "info", "--json"], cwd=ROOT, check=True,
            capture_output=True, text=True, timeout=30,
        )
    except FileNotFoundError:
        failures.append("environment features: pixi is not on PATH")
        return
    except subprocess.CalledProcessError as e:
        failures.append(f"environment features: pixi info --json failed:\n{(e.stdout + e.stderr).strip()}")
        return

    reported = {e["name"]: e["features"] for e in json.loads(result.stdout)["environments_info"]}
    for name, env in pixi["environments"].items():
        expected = list(env["features"]) + ["default"]
        actual = reported.get(name)
        if actual != expected:
            failures.append(
                f"environment features: {name}: pixi info reports {actual}, expected declared "
                f"features + ['default'] = {expected}"
            )


def check_test_layer_unpublished(failures: list[str]) -> None:
    # `test` is the Dockerfile's last stage, so a publish job that omits
    # `target` builds it by default and ships bats into a product image. The
    # explicit target is the only thing preventing that, which makes it worth
    # asserting rather than trusting.
    text = (ROOT / "Dockerfile").read_text()
    parents: dict[str, str] = {}
    installs_bats: set[str] = set()
    stage = None
    for line in text.splitlines():
        m = re.match(r"\s*FROM\s+(\S+)(?:\s+AS\s+(\S+))?", line, re.IGNORECASE)
        if m:
            base, name = m.group(1), m.group(2)
            stage = name or base
            parents[stage] = base
            continue
        if line.lstrip().startswith("#"):
            continue  # a comment mentioning bats installs nothing
        if stage and "bats" in line.lower():
            installs_bats.add(stage)

    # Without this the check passes vacuously the moment bats moves or is
    # renamed, which is exactly when it would be needed.
    if "test" not in installs_bats:
        failures.append("test layer: no stage named `test` installs bats — this check can no longer see what it guards")

    def ancestry(target: str) -> list[str]:
        chain: list[str] = []
        while target in parents and target not in chain:
            chain.append(target)
            target = parents[target]
        return chain

    workflow = yaml.safe_load((ROOT / ".github" / "workflows" / "publish.yml").read_text())
    for job_name, job in workflow.get("jobs", {}).items():
        if "build-test-push" not in job.get("uses", ""):
            continue
        target = (job.get("with") or {}).get("target")
        if not target:
            failures.append(
                f"test layer: publish.yml job {job_name!r} sets no `target`; the Dockerfile's "
                "last stage is `test`, so an unset target publishes bats"
            )
            continue
        leaked = sorted(set(ancestry(target)) & installs_bats)
        if leaked:
            failures.append(
                f"test layer: publish.yml job {job_name!r} publishes {target!r}, which installs bats in {leaked}"
            )


def check_workflow_pins(failures: list[str]) -> None:
    # Composite-action steps conventionally lead with "- uses: ..." (no
    # separate "- name:" line first, unlike this repo's workflow style), so
    # the leading list dash has to be optional or scanning action.yml is a
    # no-op in practice.
    uses_re = re.compile(r"^\s*(?:-\s*)?uses:\s*(\S+)", re.MULTILINE)

    # .yaml is a valid GitHub Actions extension too, and a composite action
    # under .github/actions/**/action.yml is just as capable of a `uses:` as
    # a workflow file: both are part of the surface this check exists for.
    workflows = sorted(
        p for ext in ("*.yml", "*.yaml") for p in (ROOT / ".github" / "workflows").glob(ext)
    )
    composite_actions = sorted((ROOT / ".github" / "actions").rglob("action.y*ml"))

    for wf in workflows + composite_actions:
        rel = wf.relative_to(ROOT)
        text = wf.read_text()
        for m in uses_re.finditer(text):
            ref = m.group(1)
            if ref.startswith("./"):
                continue  # a local reusable workflow, not a third-party action
            if "@" not in ref:
                failures.append(f"workflow pins: {rel}: {ref!r} has no @ref")
                continue
            repo, sha = ref.rsplit("@", 1)
            if not SHA_RE.fullmatch(sha):
                failures.append(f"workflow pins: {rel}: {ref!r} is not pinned to a 40-char SHA")


# --------------------------------------------------------------------------

def main() -> int:
    start = time.time()
    failures: list[str] = []

    pixi = load_toml(ROOT / "pixi.toml")

    # Read before pixi ever runs: every check downstream of check_lock_fresh
    # must reason about these committed bytes, not whatever pixi leaves on
    # disk after `--check` (see check_lock_fresh).
    lock_bytes = (ROOT / "pixi.lock").read_bytes()
    check_lock_fresh(failures, lock_bytes)
    lock = yaml.safe_load(lock_bytes)
    index = build_package_index(lock)

    check_channels_platforms(failures, pixi)
    check_solve_group(failures, pixi)
    check_containment(failures, pixi, lock, index)
    gated = check_cross_arch_gated(failures, pixi, lock, index)
    report_cross_arch_rest(pixi, lock, index, gated)
    check_rprofile(failures)
    check_r_specs(failures, pixi)
    check_ladder(failures, pixi)
    check_environment_features(failures, pixi)
    check_test_layer_unpublished(failures)
    check_workflow_pins(failures)

    elapsed = time.time() - start
    if failures:
        for f in failures:
            print(f"FAIL {f}")
        print(f"gate static: FAIL ({len(failures)} violation(s), {elapsed:.1f}s)")
        return 1

    print(f"gate static: PASS ({elapsed:.1f}s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
