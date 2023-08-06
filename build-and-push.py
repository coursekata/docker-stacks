#!/usr/bin/env python

import subprocess
from datetime import datetime
from pathlib import Path

import asyncclick as click
from pydantic import BaseModel


class Image(BaseModel):
    name: str
    description: str
    deps: list[str]
    build_args: dict[str, str] = {}
    build_contexts: dict[str, str] = {}


class BuildContext(BaseModel):
    org: str
    repo: str
    python_version: str
    r_version: str
    platforms: list[str]
    has_built: set[str] = set()
    push: bool = False


images = [
    Image(
        name="base-r-notebook",
        description="Jupyter Lab, Python, and R, and that's it.",
        deps=[],
        build_contexts={"scripts": "scripts"},
        build_args={
            "PYTHON_VERSION": "{context.python_version}",
            "R_VERSION": "{context.r_version}",
        },
    ),
    Image(
        name="essentials-builder",
        description="Base for the essentials- and r-notebook images.",
        deps=["base-r-notebook"],
        build_contexts={"scripts": "scripts"},
        build_args={"BASE_TAG": "r-{context.r_version}"},
    ),
    Image(
        name="essentials-notebook",
        description="CourseKata essentials: everything used in the books.",
        deps=["essentials-builder"],
        build_contexts={"scripts": "scripts"},
        build_args={"BASE_TAG": "r-{context.r_version}"},
    ),
    Image(
        name="r-notebook",
        description="CourseKata essentials and other R packages for teaching and learning data science.",
        deps=["essentials-builder"],
        build_contexts={"scripts": "scripts"},
        build_args={"BASE_TAG": "r-{context.r_version}"},
    ),
    Image(
        name="datascience-notebook",
        description="R and Python packages for teaching and learning data science.",
        deps=["r-notebook"],
        build_contexts={"scripts": "scripts"},
        build_args={"BASE_TAG": "python-{context.python_version}"},
    ),
]


@click.command()
@click.option("--org", default="coursekata", help="GitHub organization")
@click.option("--repo", default="docker-images", help="GitHub repository")
@click.option("--python-version", default="3.11", help="Python version to use")
@click.option("--r-version", default="4.3", help="R version to use")
@click.option(
    "--platforms", default="linux/amd64,linux/arm64/v8", help="Platforms to build for"
)
@click.option("--push", is_flag=True, help="Push to DockerHub/GHCR")
async def build(
    org: str,
    repo: str,
    python_version: str,
    r_version: str,
    platforms: str,
    push: bool,
):
    """Build (and push) Docker images"""
    context = BuildContext(
        org=org,
        repo=repo,
        python_version=python_version,
        r_version=r_version,
        platforms=platforms.split(","),
        push=push,
    )
    for image in images:
        for arg in image.build_args:
            image.build_args[arg] = image.build_args[arg].format(context=context)
        await build_image(image, context)


async def build_image(image: Image, context: BuildContext):
    """Build a Docker image"""
    if image.name in context.has_built:
        return
    for dep in image.deps:
        dep_image = next(i for i in images if i.name == dep)
        await build_image(dep_image, context)

    click.echo(f"\nBuilding {image.name}")
    click.secho(" ".join(make_cmd(image, context)), fg="green")
    subprocess.run(" ".join(make_cmd(image, context)), shell=True)
    context.has_built.add(image.name)


def make_cmd(image: Image, context: BuildContext) -> list[str]:
    """Make the Docker build command for a Docker image"""
    cmd: list[str] = ["docker", "buildx", "build"]
    cmd.extend(build_args(image, context))
    cmd.extend(labels(image, context))
    cmd.extend(tags(image, context))
    cmd.append(f"{Path(__file__).parent}/{image.name}")
    return cmd


def build_args(image: Image, context: BuildContext) -> list[str]:
    """Get the build args for a Docker image"""
    args: list[str] = []
    for key, value in image.build_args.items():
        args.append(f"--build-arg={key}={value}")
    for key, value in image.build_contexts.items():
        args.append(f"--build-context={key}={value}")
    args.append(f"--platform={','.join(context.platforms)}")
    if context.push:
        args.append("--push")
    return args


def labels(image: Image, context: BuildContext) -> list[str]:
    """Get the metadata args for a Docker image"""
    github_url = f"https://github.com/{context.org}/{context.repo}"
    args: list[str] = []
    label_prefix = "--label=org.opencontainers.image"
    args.append(f'"{label_prefix}.title={image.name}"')
    args.append(f'"{label_prefix}.description={image.description}"')
    args.append(f'"{label_prefix}.source={github_url}"')
    args.append(f'"{label_prefix}.url={github_url}/pkgs/container/{ image.name }"')
    args.append(f'"{label_prefix}.version=latest"')
    args.append(f'"{label_prefix}.revision={git_sha(True)}"')
    args.append(f'"{label_prefix}.created={datetime.now().isoformat()}"')
    args.append(f'"{label_prefix}.licenses=AGPL-3.0"')
    return args


def tags(image: Image, context: BuildContext) -> list[str]:
    return [f"--tag={tag}" for tag in tag_names(image, context)]


def tag_names(image: Image, context: BuildContext) -> list[str]:
    args: list[str] = []
    for repo in ["ghcr.io/", ""]:
        args.append(f"{repo}{context.org}/{image.name}:latest")
        args.append(f"{repo}{context.org}/{image.name}:sha-{git_sha()}")
        args.append(f"{repo}{context.org}/{image.name}:r-{context.r_version}")
        args.append(f"{repo}{context.org}/{image.name}:python-{context.python_version}")
    return args


def git_sha(full: bool = False) -> str:
    """Get the git SHA"""
    cmd = ["git", "rev-parse"] + (["--short"] if not full else []) + ["HEAD"]
    return subprocess.check_output(cmd).decode("utf-8").strip()


if __name__ == "__main__":
    build(_anyio_backend="asyncio")
