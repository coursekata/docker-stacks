#!/usr/bin/env python3
"""The static release gate.

Everything here is provable from committed text, in seconds, before any image
exists: pixi.lock containment across the ladder, the solve-group split that
keeps exercises-notebook's asttokens ceiling off the ladder, cross-arch
version equality over the packages we actually name, the CRAN repository
configuration, the R
GitHub refs, generator/lockfile sync, and CI Action pinning.

python3 + PyYAML rather than bash/yq because pixi.lock is 632KB of YAML and
the repo carries no other YAML tooling; both are present on ubuntu-24.04
runners and locally.
"""

from __future__ import annotations

import re
import shutil
import subprocess
import sys
import tempfile
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

# The R ladder as rpixi.toml expresses it — four notebook tiers. datascience-core
# and exercises-notebook are checked separately (env-name parity, not nesting).
R_LADDER = ["base-r-notebook", "essentials-notebook", "r-notebook", "datascience-notebook"]


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

    if "cloud.r-project.org" in text:
        failures.append("Rprofile.site: a second repository makes resolution nondeterministic; pak takes the newest across all of them")

    m = re.search(r"options\(repos\s*=\s*c\(([^)]*)\)\)", text)
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

    m = re.search(r'Sys\.getenv\(\s*"PPM"\s*,\s*unset\s*=\s*"([^"]+)"\s*\)', text)
    if not m:
        failures.append("Rprofile.site: no PPM default found (Sys.getenv(\"PPM\", unset = ...))")
    elif m.group(1) != PPM_LATEST:
        failures.append(f"Rprofile.site: PPM default {m.group(1)!r} != {PPM_LATEST!r} — no frozen date belongs anywhere in this file")


def check_pak_scripts_repos(failures: list[str]) -> None:
    # pak-scripts/*.R are what actually runs inside the image, so the single
    # repository is only as real as what's committed there, not just what
    # Rprofile.site says.
    for script in sorted((ROOT / "pak-scripts").glob("*.R")):
        text = script.read_text()
        for banned in ("cloud.r-project.org",):
            if banned in text:
                failures.append(
                    f"pak-scripts repos: {script.name}: forbidden string {banned!r} present — "
                    "a fallback repo in a shipped installer reintroduces exactly the ambiguity Rprofile.site removes"
                )
        for lineno, line in enumerate(text.splitlines(), start=1):
            if "options(repos" in line:
                failures.append(
                    f"pak-scripts repos: {script.name}:{lineno}: {line.strip()!r} configures a repository "
                    "beyond the one Rprofile.site already sets"
                )


def check_rpixi(failures: list[str], pixi: dict, rpixi: dict) -> None:
    tables = [("(dependencies)", rpixi.get("dependencies", {}))]
    tables += [(f"feature.{n}", f.get("dependencies", {})) for n, f in rpixi.get("feature", {}).items()]

    for table, deps in tables:
        for name, spec in deps.items():
            if not isinstance(spec, dict):
                continue
            if "repos" in spec:
                failures.append(
                    f"rpixi refs: {table}.{name} sets a custom \"repos\" ({spec['repos']!r}) — "
                    "custom R repos are banned (R0); off-CRAN packages must be GitHub refs pinned to a SHA"
                )
            if "github" not in spec:
                continue
            if "tag" in spec:
                failures.append(f"rpixi refs: {table}.{name} pins a movable \"tag\" — pin \"commit\" instead")
            commit = spec.get("commit")
            if not commit or not SHA_RE.fullmatch(commit):
                failures.append(f"rpixi refs: {table}.{name} commit {commit!r} is not a 40-char lowercase-hex SHA")

    feats = {e: set(rpixi["environments"][e]["features"]) for e in R_LADDER if e in rpixi["environments"]}
    for lo, hi in zip(R_LADDER, R_LADDER[1:]):
        if lo not in feats or hi not in feats:
            continue
        if not feats[lo] <= feats[hi]:
            failures.append(f"rpixi ladder: {lo} features {sorted(feats[lo])} not <= {hi} features {sorted(feats[hi])}")

    pixi_envs = set(pixi["environments"])
    rpixi_envs = set(rpixi["environments"])
    if pixi_envs != rpixi_envs:
        failures.append(
            f"rpixi/pixi env parity: only in pixi.toml={sorted(pixi_envs - rpixi_envs)}, "
            f"only in rpixi.toml={sorted(rpixi_envs - pixi_envs)}"
        )


def check_generator_sync(failures: list[str]) -> None:
    # Only rpixi.toml and the generator itself are inputs to `pakgen`; a full
    # tree copy would also drag along the multi-GB local .pixi cache for no
    # reason, which is not a tradeoff worth making for a 10-second gate.
    if shutil.which("Rscript") is None:
        # Reported, never fatal: the gate must not die on a runner without R,
        # and the prek hook already regenerates these on every rpixi.toml edit.
        print("report generator sync: Rscript not available, pak-scripts freshness unchecked")
        return

    with tempfile.TemporaryDirectory() as tmp:
        tmp_path = Path(tmp)
        shutil.copy(ROOT / "rpixi.toml", tmp_path / "rpixi.toml")
        (tmp_path / "scripts").mkdir()
        shutil.copy(ROOT / "scripts" / "rpak.R", tmp_path / "scripts" / "rpak.R")

        result = subprocess.run(
            ["Rscript", "scripts/rpak.R", "pakgen"], cwd=tmp_path,
            capture_output=True, text=True,
        )
        if result.returncode != 0:
            failures.append(f"generator sync: scripts/rpak.R pakgen failed:\n{result.stdout}{result.stderr}")
            return

        diff = subprocess.run(
            ["diff", "-rq", str(tmp_path / "pak-scripts"), str(ROOT / "pak-scripts")],
            capture_output=True, text=True,
        )
        if diff.returncode != 0:
            failures.append(
                "generator sync: pak-scripts/ is out of date with rpixi.toml; "
                f"run scripts/update-pak-scripts.sh\n{diff.stdout}{diff.stderr}"
            )


def check_workflow_pins(failures: list[str]) -> None:
    # Composite-action steps conventionally lead with "- uses: ..." (no
    # separate "- name:" line first, unlike this repo's workflow style), so
    # the leading list dash has to be optional or scanning action.yml is a
    # no-op in practice.
    uses_re = re.compile(r"^\s*(?:-\s*)?uses:\s*(\S+)", re.MULTILINE)

    # .yaml is a valid GitHub Actions extension too, and a composite action
    # under .github/actions/**/action.yml is just as capable of a `uses:` as
    # a workflow file — both are part of the surface this check exists for.
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
    rpixi = load_toml(ROOT / "rpixi.toml")

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
    check_pak_scripts_repos(failures)
    check_rpixi(failures, pixi, rpixi)
    check_generator_sync(failures)
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
