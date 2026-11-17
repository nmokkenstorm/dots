from pathlib import Path
import os
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).parents[1]
SCHEDULE = str(ROOT / "macos/zscaler-schedule/zscaler-schedule")
HOLD = str(ROOT / "bin/zscaler-hold")
TODAY = "2026-11-17"


class ZscalerScheduleTests(unittest.TestCase):
    """The root job decides from a data file in ~/.config; zscaler-hold writes it without sudo."""

    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.config = Path(self.dir.name) / "config"
        self.env = {
            **os.environ,
            "ZSCALER_SCHEDULE_DRY": "1",
            "ZSCALER_SCHEDULE_TODAY": TODAY,
            "ZSCALER_SCHEDULE_CONFIG": self.dir.name,
        }

    def tearDown(self):
        self.dir.cleanup()

    def schedule(self, action="off", *extra):
        return subprocess.run(
            ["/bin/bash", SCHEDULE, action, self.dir.name, "501", *extra],
            env=self.env, text=True, capture_output=True, timeout=10,
        )

    def hold(self, *args):
        return subprocess.run([HOLD, *args], env=self.env, text=True, capture_output=True, timeout=10)

    def switched_off(self, result):
        return "bootout system/com.zscaler.tunnel" in result.stdout

    def test_switch_off_decision(self):
        cases = [
            ("no config", None, True),
            ("held tonight", "OFF_ENABLED=true\nHOLD_UNTIL=2026-11-17\n", False),
            ("held until a later day", "HOLD_UNTIL=2026-11-20\n", False),
            ("expired hold", "HOLD_UNTIL=2026-11-16\n", True),
            ("disabled", "OFF_ENABLED=false\n", False),
            ("malformed date ignored", "HOLD_UNTIL=tomorrow\n", True),
            ("injection ignored", "HOLD_UNTIL=$(touch /tmp/pwned)\nOFF_ENABLED=false;id\n", True),
        ]
        for name, content, expect_off in cases:
            with self.subTest(name):
                if content is None:
                    self.config.unlink(missing_ok=True)
                else:
                    self.config.write_text(content)
                result = self.schedule()
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(self.switched_off(result), expect_off, result.stdout)

    def test_switch_on_ignores_the_hold(self):
        self.config.write_text("OFF_ENABLED=false\nHOLD_UNTIL=2099-01-01\n")
        result = self.schedule("on")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("bootstrap system /Library/LaunchDaemons/com.zscaler.tunnel.plist", result.stdout)
        self.assertIn("bootstrap gui/501", result.stdout)

    def test_bad_arguments_are_refused(self):
        for args in (["sideways", self.dir.name, "501"], ["off", "", "501"], ["off", self.dir.name, "root"]):
            with self.subTest(args):
                result = subprocess.run(["/bin/bash", SCHEDULE, *args], env=self.env, capture_output=True, timeout=10)
                self.assertEqual(result.returncode, 64)

    def test_hold_commands_drive_the_job(self):
        cases = [
            (["tonight"], "held until 2026-11-17", False),
            (["2026-11-20"], "held until 2026-11-20", False),
            (["--release"], "runs tonight", True),
            (["--never"], "disabled", False),
            (["--resume"], "runs tonight", True),
        ]
        for args, status, expect_off in cases:
            with self.subTest(args):
                result = self.hold(*args)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn(status, result.stdout)
                self.assertEqual(self.switched_off(self.schedule()), expect_off)

    def test_hold_rejects_a_bad_date(self):
        result = self.hold("next-friday")
        self.assertEqual(result.returncode, 64)
        self.assertFalse(self.config.exists())


if __name__ == "__main__":
    unittest.main()
