import copy
import importlib.util
import sys
import tomllib
import unittest
from pathlib import Path


SCRIPT = Path(__file__).parents[1] / "promote_images.py"
SPEC = importlib.util.spec_from_file_location("promote_images", SCRIPT)
promote_images = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
sys.modules[SPEC.name] = promote_images
SPEC.loader.exec_module(promote_images)


RUN_ID = 12345
OWNER = "coursekata"
REPOSITORY = "coursekata/docker-stacks"
HEAD_SHA = "a" * 40
SOURCE_DIGESTS = {
    image: f"sha256:{index:064x}"
    for index, image in enumerate(promote_images.IMAGES, start=1)
}


def candidate_run():
    return {
        "id": RUN_ID,
        "html_url": f"https://github.com/{REPOSITORY}/actions/runs/{RUN_ID}",
        "head_repository": {"full_name": REPOSITORY},
        "path": promote_images.WORKFLOW_PATH,
        "head_branch": "main",
        "event": "push",
        "status": "completed",
        "conclusion": "success",
        "head_sha": HEAD_SHA,
        "created_at": "2026-09-22T00:59:00Z",
        "run_started_at": "2026-09-22T01:00:00Z",
        "updated_at": "2026-09-22T02:00:00Z",
    }


def image_index():
    return {
        "mediaType": "application/vnd.oci.image.index.v1+json",
        "annotations": {
            "org.opencontainers.image.revision": HEAD_SHA,
            "org.opencontainers.image.created": "2026-09-22T01:30:00Z",
        },
        "manifests": [
            {
                "digest": "sha256:" + "b" * 64,
                "platform": {"os": "linux", "architecture": "amd64"},
            },
            {
                "digest": "sha256:" + "c" * 64,
                "platform": {"os": "linux", "architecture": "arm64"},
            },
        ],
    }


class FakeExternal:
    def __init__(self):
        self.run = candidate_run()
        self.refs = {}
        self.manifests = {}
        self.copies = []
        self.fail_target = None
        for image, digest in SOURCE_DIGESTS.items():
            repository = f"ghcr.io/{OWNER}/next/{image}"
            self.refs[f"{repository}:run-{RUN_ID}"] = digest
            self.manifests[f"{repository}@{digest}"] = image_index()

    def github_run(self, repository, run_id):
        return copy.deepcopy(self.run)

    def digest(self, reference, *, missing_ok=False):
        if reference in self.refs:
            return self.refs[reference]
        if missing_ok:
            return None
        raise promote_images.PromotionError(f"missing {reference}")

    def manifest(self, reference):
        return copy.deepcopy(self.manifests[reference])

    def copy(self, source, target):
        if target == self.fail_target:
            raise promote_images.PromotionError(f"copy failed for {target}")
        digest = source.rsplit("@", 1)[1]
        self.refs[target] = digest
        self.copies.append((source, target))


class PromotionTests(unittest.TestCase):
    def build_manifest(self, external):
        return promote_images.build_manifest(
            external,
            repository=REPOSITORY,
            owner=OWNER,
            run_id=RUN_ID,
            change_class="packages",
        )

    def test_validate_records_every_image_without_copying(self):
        external = FakeExternal()
        manifest = self.build_manifest(external)

        self.assertEqual(manifest["status"], "validated")
        self.assertEqual(set(manifest["images"]), set(promote_images.IMAGES))
        self.assertEqual(external.copies, [])

    def test_product_list_matches_the_built_environments(self):
        pixi = tomllib.loads((SCRIPT.parents[1] / "pixi.toml").read_text())

        self.assertEqual(set(promote_images.IMAGES), set(pixi["environments"]))

    def test_promote_writes_and_verifies_all_dated_tags_before_latest(self):
        external = FakeExternal()
        manifest = self.build_manifest(external)
        promote_images.promote(external, manifest)

        targets = [target for _, target in external.copies]
        split = len(promote_images.IMAGES)
        self.assertTrue(all(target.endswith(":2026-09-22") for target in targets[:split]))
        self.assertTrue(all(target.endswith(":latest") for target in targets[split:]))
        self.assertEqual(manifest["status"], "promoted")

    def test_dated_tag_collision_stops_before_any_copy(self):
        external = FakeExternal()
        image = promote_images.IMAGES[0]
        external.refs[f"ghcr.io/{OWNER}/{image}:2026-09-22"] = "sha256:" + "f" * 64

        with self.assertRaisesRegex(promote_images.PromotionError, "Immutable tag collision"):
            self.build_manifest(external)
        self.assertEqual(external.copies, [])

    def test_failed_dated_copy_never_reaches_latest(self):
        external = FakeExternal()
        failed_image = promote_images.IMAGES[2]
        external.fail_target = f"ghcr.io/{OWNER}/{failed_image}:2026-09-22"
        manifest = self.build_manifest(external)

        with self.assertRaisesRegex(promote_images.PromotionError, "copy failed"):
            promote_images.promote(external, manifest)
        self.assertFalse(any(target.endswith(":latest") for _, target in external.copies))

    def test_matching_dated_tags_make_a_retry_idempotent(self):
        external = FakeExternal()
        for image, digest in SOURCE_DIGESTS.items():
            external.refs[f"ghcr.io/{OWNER}/{image}:2026-09-22"] = digest
        manifest = self.build_manifest(external)

        promote_images.promote(external, manifest)

        self.assertEqual(len(external.copies), len(promote_images.IMAGES))
        self.assertTrue(all(target.endswith(":latest") for _, target in external.copies))

    def test_candidate_must_match_the_run_commit(self):
        external = FakeExternal()
        first_manifest = next(iter(external.manifests.values()))
        first_manifest["annotations"]["org.opencontainers.image.revision"] = "d" * 40

        with self.assertRaisesRegex(promote_images.PromotionError, "does not identify"):
            self.build_manifest(external)

    def test_candidate_must_contain_exactly_two_supported_platforms(self):
        external = FakeExternal()
        first_manifest = next(iter(external.manifests.values()))
        first_manifest["manifests"].pop()

        with self.assertRaisesRegex(promote_images.PromotionError, "platforms are"):
            self.build_manifest(external)

    def test_only_a_successful_main_publish_run_is_accepted(self):
        external = FakeExternal()
        external.run["head_branch"] = "feature"
        external.run["conclusion"] = "failure"

        with self.assertRaisesRegex(promote_images.PromotionError, "branch, conclusion"):
            self.build_manifest(external)


if __name__ == "__main__":
    unittest.main()
