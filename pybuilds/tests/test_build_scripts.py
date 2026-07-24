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


if __name__ == "__main__":
    unittest.main()
