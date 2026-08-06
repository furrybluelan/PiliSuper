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
        completed = type("Completed", (), {"returncode": 0})()
        with patch.object(
            patch_script,
            "run_command",
            side_effect=[type("Completed", (), {"returncode": 1})(), completed],
        ) as run:
            patch_script.apply_project_patch(Path("patch.diff"), Path("."))

        self.assertEqual(run.call_count, 2)


if __name__ == "__main__":
    unittest.main()
