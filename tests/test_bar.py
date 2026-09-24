"""bar format: the status-format[1] string built from a modules file."""

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

BAR = Path(__file__).resolve().parents[1] / "bin" / "bar"
SEP = "#[fg=#908caa] │ #[default]"


def fmt(text=None):
    with tempfile.TemporaryDirectory() as tmp:
        modules = Path(tmp) / "modules"
        if text is not None:
            modules.write_text(text)
        env = {**os.environ, "BAR_MODULES": str(modules)}
        return subprocess.run([str(BAR), "format"], capture_output=True, text=True, env=env)


class BarFormat(unittest.TestCase):
    def test_missing_file_falls_back_to_sys_on_the_right(self):
        out = fmt().stdout
        self.assertTrue(out.startswith("#[align=left default]"))
        self.assertIn("#[align=right default]#{?@bar_sys,#{@bar_sys},}", out)

    def test_groups_join_with_a_separator_after_the_first(self):
        cases = {
            "left pr\n": "#[align=left default]#{?@bar_pr,#{@bar_pr},}",
            "right sys\nright reeds\n": f"#{{?@bar_sys,#{{@bar_sys}},}}#{{?@bar_reeds,{SEP}#{{@bar_reeds}},}}",
            "# a comment\n\ncentre train\n": "#[align=centre default]#{?@bar_train,#{@bar_train},}",
        }
        for text, expected in cases.items():
            with self.subTest(text=text):
                self.assertIn(expected, fmt(text).stdout)

    def test_every_group_is_present_even_when_empty(self):
        self.assertEqual(fmt("left pr\n").stdout.count("#[align="), 3)

    def test_bad_lines_fail_loudly(self):
        for text in ("middle pr\n", "left Pr\n", "left\n"):
            with self.subTest(text=text):
                result = fmt(text)
                self.assertEqual(result.returncode, 2)
                self.assertIn("modules", result.stderr)


if __name__ == "__main__":
    unittest.main()
