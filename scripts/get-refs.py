#!/usr/bin/env python3
"""List the packages a pixi environment declares, for one language.

The declared set, not the resolved closure: what these feed is the assertion
that every package an image advertises loads, not that its whole dependency
tree is intact.

Composition comes from pixi itself rather than a hand parse of pixi.toml.
pixi already resolves feature ordering, the implicit `default` feature,
`no-default-feature`, and per-target tables — so a package declared only for
one architecture is reported for that architecture and not the other. A parser
here would answer those cases silently and wrongly. pixi needs no network and
no writable cache for either query; the Dockerfile bind-mounts the binary from
the pinned pixi stage for exactly this.
"""

import argparse
import functools
import json
import subprocess
import sys
from pathlib import Path

# Declared in pixi.toml but not importable Python packages: the interpreter and
# installer themselves, and system libraries pulled in for other packages to
# link against. R packages are excluded by the r- prefix instead.
NOT_IMPORTABLE = {
    "python", "pip",
    "cmdstan", "ocl-icd-system", "pkg-config", "unixodbc", "xorg-xorgproto",
}

# conda names that differ from the importable name.
RENAMES = {"jupyterhub-singleuser": "jupyterhub", "matplotlib-base": "matplotlib"}


def pixi(manifest, *args):
    command = ["pixi", *args, "--manifest-path", str(manifest)]
    try:
        result = subprocess.run(command, check=True, capture_output=True, text=True)
    except FileNotFoundError:
        sys.exit("pixi is not on PATH")
    except subprocess.CalledProcessError as e:
        sys.exit(f"{' '.join(command)} failed:\n{(e.stdout + e.stderr).strip()}")
    return json.loads(result.stdout)


@functools.lru_cache(maxsize=None)
def info(manifest):
    return pixi(manifest, "info", "--json")


def environment_names(manifest):
    return [e["name"] for e in info(manifest)["environments_info"] if e["name"] != "default"]


def environment(manifest, env):
    for entry in info(manifest)["environments_info"]:
        if entry["name"] == env:
            return entry
    known = ", ".join(sorted(environment_names(manifest)))
    sys.exit(f"unknown environment '{env}'; known environments: {known}")


def features_for(manifest, env):
    return environment(manifest, env)["features"]


def resolve_platform(manifest, env, requested):
    """Inside the image the platform pixi reports is the one being built. On a
    macOS host it is not one the manifest targets: that has to be an error, not
    an empty list that makes every downstream assertion vacuously true."""
    supported = environment(manifest, env)["platforms"]
    platform = requested or info(manifest)["platform"]
    if platform not in supported:
        sys.exit(
            f"platform '{platform}' is not one of {env}'s platforms "
            f"({', '.join(sorted(supported))}); pass --platform"
        )
    return platform


def r_refs(manifest, env, specs_dir):
    """pak refs, in feature order, from r/<feature>.txt."""
    refs = []
    for feature in features_for(manifest, env):
        spec_file = specs_dir / f"{feature}.txt"
        if not spec_file.exists():
            continue
        for line in spec_file.read_text().splitlines():
            ref = line.split("#", 1)[0].strip()
            if ref:
                refs.append(ref)
    return refs


def python_refs(manifest, env, platform):
    """Importable package names, sorted. `requested_spec` is what separates the
    packages this environment asks for from the closure pulled in beneath them."""
    # --locked, not a bare list: pixi re-solves and REWRITES pixi.lock when the
    # manifest has moved ahead of it, so without this a read turns into a write.
    # --no-install keeps it from materializing the environment to answer.
    listing = pixi(
        manifest, "list", "-e", env, "--platform", platform,
        "--json", "--locked", "--no-install",
    )
    names = set()
    for entry in listing:
        name = entry["name"]
        if entry.get("requested_spec") is None:
            continue
        if name.startswith("r-") or name in NOT_IMPORTABLE:
            continue
        names.add(RENAMES.get(name, name))
    return sorted(names)


def ref_name(ref):
    return ref.split("=")[0].split("@")[0].split("?")[0]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("env", nargs="?", help="pixi environment name")
    parser.add_argument("--lang", choices=("r", "python"), default="r", help="which language's packages to list")
    parser.add_argument("--names", action="store_true", help="print package names only, without ref syntax")
    parser.add_argument("--list", action="store_true", help="list known environment names")
    parser.add_argument("--manifest", default="pixi.toml", help="path to pixi.toml")
    parser.add_argument("--specs", default="r", help="path to the r/ spec directory")
    parser.add_argument("--platform", help="pixi platform to resolve for (default: the platform pixi reports)")
    args = parser.parse_args()

    manifest = Path(args.manifest)

    if args.list:
        for name in sorted(environment_names(manifest)):
            print(name)
        return

    if not args.env:
        parser.error("an environment name is required unless --list is given")

    if args.lang == "python":
        refs = python_refs(manifest, args.env, resolve_platform(manifest, args.env, args.platform))
    else:
        refs = r_refs(manifest, args.env, Path(args.specs))

    if not refs:
        parser.error(f"no {args.lang} packages declared for environment '{args.env}'")

    for ref in refs:
        print(ref_name(ref) if args.names else ref)


if __name__ == "__main__":
    main()
