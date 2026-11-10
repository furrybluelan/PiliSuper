import json
import subprocess
import tempfile
from contextlib import chdir
import importlib
import sys
import unittest
from pathlib import Path
from unittest.mock import patch


BUILD_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BUILD_ROOT))

patch_script = importlib.import_module("patch")


class PatchTests(unittest.TestCase):
    def test_patch_sets_match_upstream_powershell_order(self):
        # Given
        expected_common = [
            "modal_barrier.patch",
            "text_selection.patch",
            "mouse_cursor.patch",
            "image_anim.patch",
            "layout_builder.patch",
            "navigation_drawer.patch",
            "popup_menu.patch",
            "fab.patch",
            "null_safety_for_selectable_region.patch",
            "selectable_region.patch",
            "editable_text.patch",
            "text_field.patch",
            "scroll_position.patch",
            "scrollable.patch",
            "scrollable_gesture.patch",
            "draggable_scrollable_sheet.patch",
            "scaffold.patch",
            "text.patch",
            "text_painter.patch",
            "sliver.patch",
            "refresh_indicator.patch",
            "double_tap_gesture.patch",
        ]

        # When
        patch_sets = (
            patch_script.COMMON_PATCHES,
            patch_script.ANDROID_PATCHES,
            patch_script.IOS_FLUTTER_PATCHES,
            patch_script.IOS_PROJECT_PATCHES,
        )

        # Then
        self.assertEqual(patch_sets[0], expected_common)
        self.assertEqual(
            patch_sets[1],
            ["bottom_sheet_android.patch", "scroll_view.patch", "navigator.patch"],
        )
        self.assertEqual(
            patch_sets[2],
            ["scroll_view.patch", "bottom_sheet_ios_flutter.patch", "navigator.patch"],
        )
        self.assertEqual(
            patch_sets[3],
            ["bottom_sheet_ios_piliplus.patch", "geetest_ios.patch"],
        )

    def test_all_selected_patch_payloads_exist(self):
        # Given
        patch_dir = BUILD_ROOT.parent / "patches"
        patch_names = {
            *patch_script.COMMON_PATCHES,
            *patch_script.ANDROID_PATCHES,
            *patch_script.IOS_FLUTTER_PATCHES,
            *patch_script.IOS_PROJECT_PATCHES,
        }

        # When
        missing = sorted(name for name in patch_names if not (patch_dir / name).is_file())

        # Then
        self.assertEqual(missing, [])

    def test_already_applied_project_patch_is_accepted(self):
        with tempfile.TemporaryDirectory() as temp:
            payload = Path(temp) / "patch.diff"
            payload.touch()
            with patch.object(patch_script, "run_command", side_effect=[
                subprocess.CalledProcessError(1, "git apply"), None,
            ]) as run:
                patch_script.apply_project_patch(payload, Path(temp))
        self.assertEqual(run.call_count, 2)
        self.assertIn("--reverse", run.call_args.args[0])

    def test_failed_patch_is_fatal(self):
        with tempfile.TemporaryDirectory() as temp:
            payload = Path(temp) / "broken.patch"
            payload.touch()
            with patch.object(patch_script, "run_command", side_effect=
                              subprocess.CalledProcessError(1, "git apply", stderr="hunk failed")):
                with self.assertRaisesRegex(SystemExit, "not already applied.*"):
                    patch_script.apply_patch(payload, Path(temp))

    def test_missing_patch_is_fatal_without_git(self):
        with patch.object(patch_script, "run_command") as run:
            with self.assertRaisesRegex(SystemExit, "Required patch not found"):
                patch_script.apply_patch(Path("nonexistent.patch"), Path("."))
        run.assert_not_called()

    def test_apply_success_checks_then_applies(self):
        with tempfile.TemporaryDirectory() as temp:
            payload = Path(temp) / "patch.diff"
            payload.touch()
            with patch.object(patch_script, "run_command") as run:
                patch_script.apply_patch(payload, Path(temp))
        self.assertEqual(run.call_count, 2)
        self.assertIn("--check", run.call_args_list[0].args[0])
        self.assertNotIn("--check", run.call_args_list[1].args[0])

    def test_resolved_package_uri_and_relative_root(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            config_dir = root / ".dart_tool"
            config_dir.mkdir()
            selected = root / "cache/locked package"
            selected.mkdir(parents=True)
            (root / "cache/material_ui-999").mkdir()
            for uri in (selected.as_uri(), "../cache/locked%20package"):
                (config_dir / "package_config.json").write_text(json.dumps({"packages": [
                    {"name": "material_ui", "rootUri": uri},
                ]}))
                self.assertEqual(patch_script.package_root(root, "material_ui"), selected)
            with self.assertRaisesRegex(SystemExit, "cupertino_ui.*pub get first"):
                patch_script.package_root(root, "cupertino_ui")

    def test_platform_package_plans_and_deduplication(self):
        sdk, project, material, cupertino = patch_script.patch_plan("all")
        self.assertEqual(len(sdk), len(set(sdk)))
        self.assertEqual(project, patch_script.IOS_PROJECT_PATCHES)
        self.assertIn("material/bottom_sheet_android.patch", material)
        self.assertIn("material/bottom_sheet_ios_flutter_material.patch", material)
        self.assertEqual(cupertino, ["cupertino/bottom_sheet_ios_flutter.patch"])
        for name in [*sdk, *project, *material, *cupertino]:
            payload = BUILD_ROOT.parent / "patches" / name
            self.assertTrue(payload.is_file(), name)
            self.assertNotIn(b"\r\n", payload.read_bytes(), name)

    def test_main_resolves_before_reset_and_never_fetches_or_picks(self):
        with tempfile.TemporaryDirectory() as temp, chdir(temp):
            sdk = Path(temp) / "sdk"
            (sdk / "bin").mkdir(parents=True)
            (sdk / "bin/flutter").touch()
            patch_dir = Path(temp) / "tool/patches"
            patch_dir.mkdir(parents=True)
            for names in patch_script.patch_plan("all"):
                for name in names:
                    file = patch_dir / name
                    file.parent.mkdir(parents=True, exist_ok=True)
                    file.touch()
            with patch.object(sys, "argv", ["patch.py", "all", "--flutter-root", str(sdk)]), \
                 patch.object(patch_script, "require_project_root"), \
                 patch.object(patch_script, "package_root", return_value=Path(temp)), \
                 patch.object(patch_script, "apply_patch") as apply, \
                 patch.object(patch_script, "run_command") as run:
                patch_script.main()
            run.assert_called_once_with(["git", "reset", "--hard", "HEAD"], cwd=sdk)
            self.assertEqual(apply.call_count, sum(map(len, patch_script.patch_plan("all"))))


if __name__ == "__main__":
    unittest.main()
