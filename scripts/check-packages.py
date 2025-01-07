#!/usr/bin/env python3

import argparse
import concurrent.futures
import importlib.metadata
import subprocess
import textwrap
from collections.abc import Mapping
from importlib.util import find_spec
from pathlib import Path
from typing import Annotated, Any, Literal, Self, TypeVar, cast

import ruyaml as yaml
from pydantic import BaseModel, ConfigDict, Field, model_validator


# -----------------------------------------------------------------------------
# Model definitions
# -----------------------------------------------------------------------------
class Package(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    ref: str
    name: str = ""
    force: bool = False
    skip_install: Annotated[bool, Field(alias="skip-install")] = False
    skip_test: Annotated[bool, Field(alias="skip-test")] = False
    pre_install: Annotated[str | None, Field(alias="pre-install")] = None
    post_install: Annotated[str | None, Field(alias="post-install")] = None

    def __repr__(self) -> str:
        repr_str = self.ref
        repr_str += "*" if self.pre_install else ""
        repr_str += "+" if self.post_install else ""
        repr_str += " (force)" if self.force else ""
        return repr_str

    @model_validator(mode="after")
    def check_name_and_ref(self) -> Self:
        self.name = self.name or self.ref
        return self

    @model_validator(mode="after")
    def fix_github_type(self) -> Self:
        if "/" in self.ref:
            self.type = "github"
        return self


class RPackage(Package):
    type: Literal["cran", "github"] = "cran"
    repos: Annotated[list[str], Field(default_factory=list)]

    def __repr__(self) -> str:
        repr_str = super().__repr__()
        if self.repos:
            repr_str += f" (repos: {', '.join(self.repos)})"
        return repr_str


class PythonPackage(Package):
    type: Literal["pypi", "github"] = "pypi"


class Binary(BaseModel):
    name: str
    cmd: str


PackageType = TypeVar("PackageType", bound=Package)


class Environment(BaseModel):
    name: str
    hidden: bool = False
    aliases: Annotated[list[str], Field(default_factory=list)]
    depends: Annotated[list[str], Field(default_factory=list)]
    binaries: Annotated[list[Binary], Field(default_factory=list)]
    r: Annotated[list[RPackage], Field(default_factory=list)]
    python: Annotated[list[PythonPackage], Field(default_factory=list)]

    def __repr__(self) -> str:
        def labelled_list(label: str, items: list[Any]) -> str:
            return textwrap.fill(
                f"{label}: {', '.join(repr(item) for item in items)}",
                initial_indent="\n  ",
                subsequent_indent="    ",
                width=100,
            )

        repr_str = self.name
        repr_str += f" (aliases: {', '.join(self.aliases)})" if self.aliases else ""
        repr_str += labelled_list("Depends", self.depends) if self.depends else ""
        repr_str += labelled_list("R packages", self.r) if self.r else ""
        repr_str += labelled_list("Python packages", self.python) if self.python else ""
        return repr_str

    @model_validator(mode="before")
    @classmethod
    def convert_strings_to_packages(cls, data: Any) -> Any:
        if isinstance(data, dict):
            if "r" in data:
                data["r"] = cls.normalize_packages(data["r"], RPackage)
            if "python" in data:
                data["python"] = cls.normalize_packages(data["python"], PythonPackage)
        return cast(Any, data)

    @staticmethod
    def normalize_packages(
        pkgs: Any,
        PackageClass: type[PackageType],
    ) -> list[PackageType]:
        """Normalize package definitions."""
        normalized: list[PackageClass] = []
        for pkg in pkgs:
            if isinstance(pkg, str):
                normalized.append(PackageClass(name=pkg, ref=pkg))
            elif isinstance(pkg, Mapping):
                pkg = cast(Mapping[str, Any], pkg)
                normalized.append(PackageClass(**pkg))
            else:
                raise ValueError(f"Invalid package definition: {pkg!r}")
        return normalized


class Environments(BaseModel):
    environments: dict[str, Environment]


# -----------------------------------------------------------------------------
# Environment parsing and loading
# -----------------------------------------------------------------------------
def parse_envs(yaml_file: Path) -> Environments:
    """Parse an environments file."""
    with yaml_file.open() as f:
        return Environments.model_validate(yaml.safe_load(f))


def find_env(envs: Environments, name: str) -> Environment:
    """Load an environment by name or alias."""
    if name in envs.environments:
        return envs.environments[name]
    for env in envs.environments.values():
        if name in env.aliases:
            return env
    raise ValueError(f"Environment '{name}' not found.")


def find_deps(envs: Environments, name: str) -> list[Environment]:
    """Recusively find all dependencies of an environment."""
    env = find_env(envs, name)
    deps = [env]
    for dep_name in env.depends:
        deps.extend(find_deps(envs, dep_name))
    return deps


# -----------------------------------------------------------------------------
# CLI helper functions
# -----------------------------------------------------------------------------
class Terminal:
    magenta = "\033[95m"
    blue = "\033[94m"
    cyan = "\033[96m"
    green = "\033[92m"
    yellow = "\033[93m"
    red = "\033[91m"
    grey = "\033[90m"
    bold = "\033[1m"
    underline = "\033[4m"
    clear = "\033[0m"

    def __init__(self, prefix: str = "") -> None:
        self.prefix = prefix

    def print(self, text: str) -> None:
        print(text, flush=True)

    def header(self, text: str) -> None:
        self.print(f"{self.underline}{self.yellow}{self.prefix}{text}{self.clear}")

    def inform(self, text: str) -> None:
        self.print(f"{self.blue}{self.prefix}{text}{self.clear}")

    def log(self, text: str) -> None:
        self.print(f"{self.grey}{self.prefix}{text}{self.clear}")

    def success(self, text: str) -> None:
        self.print(f"{self.green}{self.prefix}{text}{self.clear}")

    def error(self, text: str) -> None:
        self.print(f"{self.red}{self.prefix}{text}{self.clear}")


# -----------------------------------------------------------------------------
# Package checking functions
# -----------------------------------------------------------------------------
def check_r_packages(pkgs: list[RPackage]) -> None:
    def check_r_package(pkg: RPackage) -> None:
        script = f"options(warn = 2); library({pkg.name})"
        subprocess.run(
            ["Rscript", "-e", script],
            shell=False,
            check=True,
            capture_output=True,
            text=True,
        )

    with concurrent.futures.ThreadPoolExecutor() as executor:
        futures = [
            executor.submit(check_r_package, pkg) for pkg in pkgs if not pkg.skip_test
        ]
        for future in concurrent.futures.as_completed(futures):
            future.result()


def check_python_packages(pkgs: list[PythonPackage]) -> None:
    for pkg in pkgs:
        if not find_spec(pkg.name) and not pkg.skip_test:
            raise Exception(f"Python package '{pkg.name}' not found.")


# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
def main():
    term = Terminal()
    args = get_args()
    envs = parse_envs(Path(args.file))
    deps = find_deps(envs, args.env)

    try:
        term.header(f"Loaded features for environment `{args.env}`")
        term.log("\n".join(repr(env) for env in deps))
        for env in reversed(deps):
            if args.install:
                term.header(f"Installing feature `{env.name}`")
                installer = Installer(Terminal(prefix=f"[{env.name}] "))
                installer.install_r(*env.r)
            else:
                term.header(f"Testing feature `{env.name}`")
                tester = Tester(Terminal(prefix=f"[{env.name}] "))
                tester.test_env(env)
    except Exception as e:
        term.error(f"\n{e}")
        exit(1)


class Config(BaseModel):
    env: str
    install: bool = False
    file: Path = Path("packages.yaml")


def get_args() -> Config:
    parser = argparse.ArgumentParser(
        "Package manager for CourseKata Docker stacks.",
        description="Check (or install) packages for a given environment.",
    )
    parser.add_argument(
        "env",
        help="Environment name (required).",
    )
    parser.add_argument(
        "-i",
        "--install",
        action="store_true",
        help="Install packages (instead of checking) for the given environment.",
    )
    parser.add_argument(
        "-f",
        "--file",
        default="packages.yaml",
        help="Packages file to load [default: packages.yaml].",
    )
    args = parser.parse_args()
    return Config(env=args.env, install=args.install, file=Path(args.file))


class RExecutor:
    def exec_r(self, *scripts: str) -> None:
        cmd = ["Rscript", "-e", "options(warn = 2)"]
        for script in scripts:
            cmd.extend(["-e", script])
        subprocess.run(cmd, check=True, text=True)


class Tester(RExecutor):
    def __init__(self, term: Terminal) -> None:
        self.term = term

    def test_env(self, env: Environment) -> None:
        self.test_bin(*env.binaries)
        self.test_r(*env.r)
        self.test_python(*env.python)

    def test_bin(self, *bins: Binary) -> None:
        if not bins:
            return

        self.term.inform("Testing binaries")
        for bin in bins:
            subprocess.run(bin.cmd, shell=True, check=True)

    def test_python(self, *pkgs: PythonPackage) -> None:
        testable_pkgs = [pkg for pkg in pkgs if not pkg.skip_test]
        if not testable_pkgs:
            return

        pkg_str = ", ".join(repr(pkg) for pkg in testable_pkgs)
        self.term.inform("Testing Python packages: " + pkg_str)

        for pkg in testable_pkgs:
            importlib.metadata.version(pkg.ref if pkg.type == "pypi" else pkg.name)

    def test_r(self, *pkgs: RPackage) -> None:
        testable_pkgs = [pkg for pkg in pkgs if not pkg.skip_test]
        if not testable_pkgs:
            return

        pkg_str = ", ".join(repr(pkg) for pkg in testable_pkgs)
        self.term.inform("Testing R packages: " + pkg_str)

        quoted_pkgs = [f'"{pkg.name}"' for pkg in testable_pkgs]
        pkgs_arg = f'c({", ".join(quoted_pkgs)})'
        self.exec_r(f"""
load_all <- function(x) invisible(lapply(x, function(x) tryCatch(
    suppressPackageStartupMessages(library(x, character.only = TRUE)),
    error = function(e) stop(paste('Error: Failed to load package', x))
)))
load_all({pkgs_arg})
""")


class Installer(RExecutor):
    def __init__(self, term: Terminal) -> None:
        self.term = term

    def exec_install_cran(
        self,
        *pkgs: str,
        upgrade: bool = False,
        repos: list[str] | None = None,
        type: Literal["cran", "github"] = "cran",
    ) -> None:
        quoted_pkgs = [f'"{pkg}"' for pkg in pkgs]
        pkgs_arg = f'c({", ".join(quoted_pkgs)})'

        upgrade_arg = "TRUE" if upgrade else "FALSE"

        quoted_repos = [f'"{repo}"' for repo in repos] if repos else []
        quoted_repos += ['getOption("repos")']
        repos_arg = f'c({", ".join(quoted_repos)})'

        method = f'remotes::{"install_cran" if type == "cran" else "install_github"}'

        cmd = f"{method}({pkgs_arg}, upgrade = {upgrade_arg}, repos = {repos_arg})"
        self.exec_r(cmd)

    def install_r(self, *pkgs: RPackage) -> None:
        for pkg in pkgs:
            if pkg.pre_install:
                self.term.inform(f"Running pre-install scripts for '{pkg.name}'")
                self.exec_r(pkg.pre_install.strip())

        organized = self.organize_pkgs(*pkgs)

        if organized["force"]:
            self.term.inform("Installing CRAN packages that should always be updated")
            pkg_refs = [pkg.name for pkg in organized["force"]]
            self.exec_install_cran(*pkg_refs, upgrade=True)

        if organized["custom_repos"]:
            self.term.inform("Installing CRAN packages from custom repositories")
            for pkg in organized["custom_repos"]:
                self.exec_install_cran(pkg.name, repos=pkg.repos, upgrade=True)

        if organized["cran"]:
            self.term.inform("Installing CRAN packages")
            pkg_refs = [pkg.name for pkg in organized["cran"]]
            self.exec_install_cran(*pkg_refs)

        if organized["github"]:
            self.term.inform("Installing GitHub packages")
            pkg_refs = [pkg.ref for pkg in organized["github"]]
            self.exec_install_cran(*pkg_refs, type="github")

        for pkg in pkgs:
            if pkg.post_install:
                self.term.inform("Running post-install scripts for '{pkg.name}'")
                self.exec_r(pkg.post_install.strip())

    def organize_pkgs(self, *pkgs: RPackage) -> dict[str, list[RPackage]]:
        organized: dict[str, list[RPackage]] = {
            "force": [],
            "custom_repos": [],
            "cran": [],
            "github": [],
        }
        for pkg in pkgs:
            if pkg.type == "cran" and pkg.repos and not pkg.skip_install:
                organized["force"].append(pkg)
            elif pkg.type == "cran" and pkg.force:
                organized["custom_repos"].append(pkg)
            elif pkg.type == "cran" and not pkg.skip_install:
                organized["cran"].append(pkg)
            elif pkg.type == "github" and not pkg.skip_install:
                organized["github"].append(pkg)
        return organized


if __name__ == "__main__":
    main()
