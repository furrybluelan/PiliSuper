import importlib
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


PYBUILDS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PYBUILDS))

build_common = importlib.import_module("build_common")
packaging = importlib.import_module("packaging")
patch_script = importlib.import_module("patch")
prebuild = importlib.import_module("prebuild")


class BuildCommonTests(unittest.TestCase):
    def test_output_path(self):
        with tempfile.TemporaryDirectory() as temp:
            path = build_common.output_path(
                temp, "PiliSuper", "android", "2.1.0+10", "arm64-v8a", suffix=".apk"
            )
            self.assertEqual(path.name, "PiliSuper_android_2.1.0+10_arm64-v8a.apk")
            self.assertTrue(path.parent.is_dir())

    def test_flutter_build_dry_run_command(self):
        with patch.object(build_common, "require_command"), patch.object(
            build_common, "run_command"
        ) as run:
            build_common.flutter_build(
                "apk", "missing-release.json", ["--split-per-abi"]
            )

        run.assert_called_once_with(
            ["flutter", "build", "apk", "--release", "--no-pub", "--split-per-abi"]
        )


class PackagingTests(unittest.TestCase):
    def test_find_bundle_binary(self):
        with tempfile.TemporaryDirectory() as temp:
            bundle = Path(temp)
            binary = bundle / "PiliSuper"
            binary.write_bytes(b"binary")
            binary.chmod(0o755)
            (bundle / "lib.so").write_bytes(b"library")
            self.assertEqual(packaging.find_bundle_binary(bundle), "PiliSuper")

    def test_create_install_tree_dry_run(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp) / "root"
            bundle = Path(temp) / "bundle"
            bundle.mkdir()
            binary = bundle / "PiliSuper"
            binary.write_bytes(b"binary")
            binary.chmod(0o755)
            (bundle / "libPiliSuper.so").write_bytes(b"library")

            # The function only prepares files; no external package tool runs.
            packaging.create_install_tree(bundle, root, "PiliSuper")

            launcher = root / "usr" / "bin" / "pilisuper"
            self.assertTrue(launcher.is_file())
            self.assertIn('exec "$APP_DIR/PiliSuper"', launcher.read_text())


class PrebuildTests(unittest.TestCase):
    def test_android_display_version_includes_commit(self):
        self.assertEqual(
            prebuild.display_version_for("android", "2.1.0", "abcdef123456"),
            "2.1.0-abcdef123",
        )

    def test_non_android_display_version_is_unchanged(self):
        self.assertEqual(
            prebuild.display_version_for("linux", "2.1.0", "abcdef123456"),
            "2.1.0",
        )


class PatchTests(unittest.TestCase):
    def test_already_applied_project_patch_is_accepted(self):
        completed = type("Completed", (), {"returncode": 0})()
        with patch.object(patch_script, "run_command", side_effect=[
            type("Completed", (), {"returncode": 1})(),
            completed,
        ]) as run:
            patch_script.apply_project_patch(Path("patch.diff"), Path("."))

        self.assertEqual(run.call_count, 2)


if __name__ == "__main__":
    unittest.main()
