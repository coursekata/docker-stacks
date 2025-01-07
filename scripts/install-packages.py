#!/usr/bin/env python3

import argparse
import concurrent.futures
import subprocess
import textwrap
from importlib.util import find_spec
from pathlib import Path
from re import L
from typing import Annotated, Any, Literal, Self, TypeVar, cast

import ruyaml as yaml
from pydantic import BaseModel, ConfigDict, Field, model_validator


# -----------------------------------------------------------------------------
# CLI helper functions
# -----------------------------------------------------------------------------
def header(text: str) -> None:
    """Print a header in yellow text."""
    print(f"\033[33m\n{text}\033[0m", flush=True)


def info(text: str) -> None:
    """Print an info message in blue text."""
    print(text, flush=True)


def success(text: str) -> None:
    """Print a success message in green text."""
    print(f"\033[32m{text}\033[0m", flush=True)


def error(text: str) -> None:
    """Print an error message in red text."""
    print(f"\033[31m{text}\033[0m", flush=True)


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
        repr_str = self.ref
        if self.pre_install:
            repr_str += "*"
        if self.post_install:
            repr_str += "+"
        if self.repos:
            repr_str += f" (repos: {', '.join(self.repos)})"
        if self.force:
            repr_str += " (force)"
        return repr_str


class PythonPackage(Package):
    type: Literal["pypi", "github"] = "pypi"

    def __repr__(self) -> str:
        return self.ref


PackageType = TypeVar("PackageType", RPackage, PythonPackage)


class Binary(BaseModel):
    name: str
    cmd: str


class EnvironmentBase(BaseModel):
    name: str
    aliases: Annotated[list[str], Field(default_factory=list)]
    depends: Annotated[list[str], Field(default_factory=list)]
    binaries: Annotated[list[Binary], Field(default_factory=list)]
    hidden: bool = False


class EnvironmentConfig(EnvironmentBase):
    r: Annotated[list[str | RPackage], Field(default_factory=list)]
    python: Annotated[list[str | PythonPackage], Field(default_factory=list)]


class EnvironmentsConfig(BaseModel):
    environments: dict[str, EnvironmentConfig]


class Environment(EnvironmentBase):
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
        if self.aliases:
            repr_str += f" (aliases: {', '.join(self.aliases)})"
        if self.depends:
            repr_str += labelled_list("Depends", self.depends)
        if self.r:
            repr_str += labelled_list("R packages", self.r)
        if self.python:
            repr_str += labelled_list("Python packages", self.python)
        return repr_str


class Environments(BaseModel):
    environments: dict[str, Environment]


# -----------------------------------------------------------------------------
# Environment parsing and loading
# -----------------------------------------------------------------------------
def parse_envs(yaml_file: Path) -> Environments:
    """Parse an environments file."""
    with yaml_file.open() as f:
        data = yaml.safe_load(f)

    config = EnvironmentsConfig(**data)
    for env in config.environments.values():
        env.r = normalize_packages(env.r, RPackage)  # type: ignore
        env.python = normalize_packages(env.python, PythonPackage)  # type: ignore

    return Environments(**config.model_dump())


def normalize_packages(
    pkgs: list[str | RPackage] | list[str | PythonPackage], pkg_class: type[Package]
) -> list[Package]:
    """Normalize package definitions."""
    return [
        pkg_class(name=pkg, ref=pkg)
        if isinstance(pkg, str)
        else pkg_class(**pkg.model_dump())
        for pkg in pkgs
    ]


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
    parser = argparse.ArgumentParser(
        description="Check if packages are installed for a given environment."
    )
    parser.add_argument("env", help="Environment name (required).")
    parser.add_argument(
        "-f",
        "--file",
        default="packages.yaml",
        help="YAML file with package definitions.",
    )
    args = parser.parse_args()

    # load the environment
    target_env_name = args.env
    envs = parse_envs(Path(args.file))
    deps = find_deps(envs, target_env_name)

    header(f"Loaded environment `{target_env_name}` and its dependencies:")
    for env in deps:
        info(repr(env))

    try:
        for env in reversed(deps):
            header(f"Installing environment `{env.name}`")
            install_env(env)
    except subprocess.CalledProcessError as e:
        error(f"\n{e}")
        exit(1)


def run_rscript(*scripts: str) -> None:
    cmd = ["Rscript", "-e", "options(warn = 2)"]
    for script in scripts:
        cmd.extend(["-e", script])
    subprocess.run(cmd, check=True, text=True)


def install_env(env: Environment) -> None:
    for pkg in env.r:
        if pkg.pre_install:
            header(f"[{env.name}] Running pre-install scripts for '{pkg.name}'")
            run_rscript(pkg.pre_install.strip())

    cran_force: list[RPackage] = []
    cran_custom_repos: list[RPackage] = []
    cran: list[RPackage] = []
    github: list[RPackage] = []
    for pkg in env.r:
        if pkg.type == "cran" and pkg.repos and not pkg.skip_install:
            cran_custom_repos.append(pkg)
        elif pkg.type == "cran" and pkg.force:
            cran_force.append(pkg)
        elif pkg.type == "cran" and not pkg.skip_install:
            cran.append(pkg)
        elif pkg.type == "github" and not pkg.skip_install:
            github.append(pkg)

    if cran_force:
        header(f"[{env.name}] Installing CRAN packages that should always be updated")
        pkg_string = ", ".join(f"'{pkg.ref}'" for pkg in cran_force)
        run_rscript(f"remotes::install_cran(c({pkg_string}), upgrade = TRUE)")

    if cran_custom_repos:
        header(f"[{env.name}] Installing CRAN packages from custom repositories")
        for pkg in cran_custom_repos:
            added_repos = ", ".join(f"'{repo}'" for repo in pkg.repos)
            repos = f"c({added_repos}, getOption('repos'))"
            upgrade = "TRUE" if pkg.force else "FALSE"
            run_rscript(
                f"remotes::install_cran('{pkg.name}', repos = {repos}, upgrade = {upgrade})"
            )

    if cran:
        header(f"[{env.name}] Installing CRAN packages")
        pkg_string = ", ".join(f"'{pkg.ref}'" for pkg in cran)
        run_rscript(f"remotes::install_cran(c({pkg_string}))")

    if github:
        header(f"[{env.name}] Installing GitHub packages")
        pkg_string = ", ".join(f"'{pkg.ref}'" for pkg in github)
        run_rscript(f"remotes::install_github(c({pkg_string}))")

    for pkg in env.r:
        if pkg.post_install:
            header(f"[{env.name}] Running post-install scripts for '{pkg.name}'")
            run_rscript(pkg.post_install.strip())


if __name__ == "__main__":
    main()
