#!/usr/bin/env python3

"""Validate and promote one complete Docker Stacks candidate build."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


IMAGES = (
    "base-r-notebook",
    "essentials-notebook",
    "r-notebook",
    "datascience-notebook",
    "datascience-core",
    "exercises-notebook",
)
WORKFLOW_PATH = ".github/workflows/publish.yml"
ALLOWED_EVENTS = {"push", "schedule", "workflow_dispatch"}
INDEX_MEDIA_TYPES = {
    "application/vnd.oci.image.index.v1+json",
    "application/vnd.docker.distribution.manifest.list.v2+json",
}
EXPECTED_PLATFORMS = {"linux/amd64", "linux/arm64"}


class PromotionError(RuntimeError):
    """The candidate cannot be promoted safely."""


def parse_time(value: str) -> datetime:
    return datetime.fromisoformat(value.replace("Z", "+00:00")).astimezone(timezone.utc)


@dataclass(frozen=True)
class CandidateRun:
    run_id: int
    html_url: str
    event: str
    head_sha: str
    created_at: datetime
    completed_at: datetime

    @property
    def release_date(self) -> str:
        return self.completed_at.date().isoformat()


class External:
    def _run(self, command: list[str], *, check: bool = True) -> subprocess.CompletedProcess[str]:
        result = subprocess.run(command, check=False, capture_output=True, text=True)
        if check and result.returncode != 0:
            detail = result.stderr.strip() or result.stdout.strip()
            raise PromotionError(f"Command failed: {' '.join(command)}\n{detail}")
        return result

    def github_run(self, repository: str, run_id: int) -> dict[str, Any]:
        result = self._run(["gh", "api", f"repos/{repository}/actions/runs/{run_id}"])
        return json.loads(result.stdout)

    def digest(self, reference: str, *, missing_ok: bool = False) -> str | None:
        result = self._run(["crane", "digest", reference], check=False)
        if result.returncode == 0:
            return result.stdout.strip()

        detail = f"{result.stdout}\n{result.stderr}".upper()
        missing_markers = ("MANIFEST_UNKNOWN", "NAME_UNKNOWN", "NOT_FOUND", "404")
        if missing_ok and any(marker in detail for marker in missing_markers):
            return None
        raise PromotionError(f"Could not resolve {reference}:\n{result.stderr.strip()}")

    def manifest(self, reference: str) -> dict[str, Any]:
        result = self._run(["crane", "manifest", reference])
        return json.loads(result.stdout)

    def copy(self, source: str, target: str) -> None:
        self._run(["crane", "copy", source, target])


def validate_run(raw: dict[str, Any], repository: str, requested_id: int) -> CandidateRun:
    checks = {
        "run ID": raw.get("id") == requested_id,
        "repository": raw.get("head_repository", {}).get("full_name") == repository,
        "workflow": raw.get("path") == WORKFLOW_PATH,
        "branch": raw.get("head_branch") == "main",
        "event": raw.get("event") in ALLOWED_EVENTS,
        "status": raw.get("status") == "completed",
        "conclusion": raw.get("conclusion") == "success",
        "commit": bool(re.fullmatch(r"[0-9a-f]{40}", raw.get("head_sha", ""))),
    }
    failed = [name for name, passed in checks.items() if not passed]
    if failed:
        raise PromotionError(f"Candidate run failed validation: {', '.join(failed)}")

    created_at = parse_time(raw["created_at"])
    completed_at = parse_time(raw["updated_at"])
    if completed_at < created_at:
        raise PromotionError("Candidate run completion precedes its start")

    return CandidateRun(
        run_id=requested_id,
        html_url=raw["html_url"],
        event=raw["event"],
        head_sha=raw["head_sha"],
        created_at=created_at,
        completed_at=completed_at,
    )


def validate_index(manifest: dict[str, Any], run: CandidateRun, image: str) -> dict[str, str]:
    if manifest.get("mediaType") not in INDEX_MEDIA_TYPES:
        raise PromotionError(f"{image} is not a multi-architecture image index")

    annotations = manifest.get("annotations", {})
    if annotations.get("org.opencontainers.image.revision") != run.head_sha:
        raise PromotionError(f"{image} does not identify candidate commit {run.head_sha}")

    created_value = annotations.get("org.opencontainers.image.created")
    if not created_value:
        raise PromotionError(f"{image} has no creation timestamp")
    created_at = parse_time(created_value)
    if not run.created_at <= created_at <= run.completed_at:
        raise PromotionError(f"{image} was created outside candidate run {run.run_id}")

    platforms: dict[str, str] = {}
    for item in manifest.get("manifests", []):
        platform = item.get("platform", {})
        name = f"{platform.get('os')}/{platform.get('architecture')}"
        if name in platforms:
            raise PromotionError(f"{image} contains duplicate platform {name}")
        platforms[name] = item.get("digest", "")

    valid_digests = all(
        re.fullmatch(r"sha256:[0-9a-f]{64}", digest) for digest in platforms.values()
    )
    if set(platforms) != EXPECTED_PLATFORMS or not valid_digests:
        found = ", ".join(sorted(platforms)) or "none"
        raise PromotionError(f"{image} platforms are {found}; expected linux/amd64 and linux/arm64")
    return platforms


def build_manifest(
    external: External,
    repository: str,
    owner: str,
    run_id: int,
    change_class: str,
) -> dict[str, Any]:
    run = validate_run(external.github_run(repository, run_id), repository, run_id)
    images: dict[str, Any] = {}

    for image in IMAGES:
        source_repository = f"ghcr.io/{owner}/next/{image}"
        stable_repository = f"ghcr.io/{owner}/{image}"
        source_tag = f"run-{run.run_id}"
        source_ref = f"{source_repository}:{source_tag}"
        source_digest = external.digest(source_ref)
        if not source_digest or not re.fullmatch(r"sha256:[0-9a-f]{64}", source_digest):
            raise PromotionError(f"{source_ref} did not resolve to a sha256 digest")

        source_at_digest = f"{source_repository}@{source_digest}"
        platforms = validate_index(external.manifest(source_at_digest), run, image)
        dated_ref = f"{stable_repository}:{run.release_date}"
        existing_dated_digest = external.digest(dated_ref, missing_ok=True)
        if existing_dated_digest not in (None, source_digest):
            raise PromotionError(
                f"Immutable tag collision: {dated_ref} is {existing_dated_digest}, "
                f"candidate is {source_digest}"
            )

        images[image] = {
            "source": {
                "repository": source_repository,
                "tag": source_tag,
                "digest": source_digest,
                "platforms": platforms,
            },
            "stable": {
                "repository": stable_repository,
                "dated_tag": run.release_date,
                "dated_digest_before": existing_dated_digest,
                "latest_digest_before": external.digest(
                    f"{stable_repository}:latest", missing_ok=True
                ),
            },
        }

    return {
        "schema_version": 1,
        "status": "validated",
        "change_class": change_class,
        "release": {
            "date": run.release_date,
            "tag": f"environment-{run.release_date}",
        },
        "candidate_run": {
            "id": run.run_id,
            "url": run.html_url,
            "event": run.event,
            "workflow": WORKFLOW_PATH,
            "head_sha": run.head_sha,
            "created_at": run.created_at.isoformat().replace("+00:00", "Z"),
            "completed_at": run.completed_at.isoformat().replace("+00:00", "Z"),
        },
        "images": images,
    }


def promote(external: External, manifest: dict[str, Any]) -> None:
    for image in IMAGES:
        record = manifest["images"][image]
        source = record["source"]
        stable = record["stable"]
        if stable["dated_digest_before"] is None:
            external.copy(
                f"{source['repository']}@{source['digest']}",
                f"{stable['repository']}:{stable['dated_tag']}",
            )

    for image in IMAGES:
        record = manifest["images"][image]
        stable = record["stable"]
        dated_ref = f"{stable['repository']}:{stable['dated_tag']}"
        if external.digest(dated_ref) != record["source"]["digest"]:
            raise PromotionError(f"Verification failed for {dated_ref}; latest tags were not changed")

    for image in IMAGES:
        record = manifest["images"][image]
        source = record["source"]
        stable = record["stable"]
        external.copy(
            f"{source['repository']}@{source['digest']}",
            f"{stable['repository']}:latest",
        )

    for image in IMAGES:
        record = manifest["images"][image]
        latest_ref = f"{record['stable']['repository']}:latest"
        if external.digest(latest_ref) != record["source"]["digest"]:
            raise PromotionError(f"Verification failed for {latest_ref}")
        record["stable"]["digest"] = record["source"]["digest"]
        record["stable"]["latest_digest"] = record["source"]["digest"]

    manifest["status"] = "promoted"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-id", type=int, required=True)
    parser.add_argument("--repository", required=True, help="GitHub owner/repository")
    parser.add_argument("--owner", required=True, help="GHCR organization")
    parser.add_argument(
        "--change-class", choices=("packages", "runtime", "os-only"), required=True
    )
    parser.add_argument("--mode", choices=("validate", "promote"), default="validate")
    parser.add_argument("--manifest", type=Path, default=Path("release-manifest.json"))
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    external = External()
    manifest = build_manifest(
        external,
        repository=args.repository,
        owner=args.owner,
        run_id=args.run_id,
        change_class=args.change_class,
    )
    if args.mode == "promote":
        promote(external, manifest)
    args.manifest.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    print(f"{manifest['status']}: {manifest['release']['tag']}")


if __name__ == "__main__":
    try:
        main()
    except PromotionError as error:
        print(f"error: {error}", file=sys.stderr)
        raise SystemExit(1) from None
