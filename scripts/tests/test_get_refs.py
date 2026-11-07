import importlib.util
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


ROOT = Path(__file__).parents[2]
SCRIPT = ROOT / "scripts/get-refs.py"
SPEC = importlib.util.spec_from_file_location("get_refs", SCRIPT)
get_refs = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(get_refs)


class FeaturePackageTests(unittest.TestCase):
    def test_feature_specs_preserve_order_and_strip_comments(self):
        with tempfile.TemporaryDirectory() as directory:
            specs = Path(directory)
            (specs / "notebook.txt").write_text("# export\ninkscape # SVG\n\npandoc\n")
            (specs / "custom.txt").write_text("extra-package\n")
            with patch.object(get_refs, "features_for", return_value=["notebook", "missing", "custom"]):
                self.assertEqual(
                    get_refs.feature_refs(Path("pixi.toml"), "arbitrary-name", specs),
                    ["inkscape", "pandoc", "extra-package"],
                )

    def apt_refs(self, environment):
        result = subprocess.run(
            [sys.executable, str(SCRIPT), environment, "--lang", "apt"],
            cwd=ROOT, text=True, capture_output=True, check=True,
        )
        return result.stdout.splitlines()

    def test_notebook_environments_receive_export_tools(self):
        for environment in ("base-r-notebook", "essentials-notebook", "r-notebook",
                            "datascience-notebook", "exercises-notebook"):
            with self.subTest(environment=environment):
                packages = self.apt_refs(environment)
                self.assertIn("inkscape", packages)
                self.assertIn("pandoc", packages)
                self.assertIn("texlive-xetex", packages)

    def test_core_has_no_notebook_export_packages(self):
        self.assertEqual(self.apt_refs("datascience-core"), [])

    def test_unknown_environment_fails_instead_of_omitting_packages(self):
        result = subprocess.run(
            [sys.executable, str(SCRIPT), "not-an-environment", "--lang", "apt"],
            cwd=ROOT, text=True, capture_output=True,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unknown environment", result.stderr)


if __name__ == "__main__":
    unittest.main()
