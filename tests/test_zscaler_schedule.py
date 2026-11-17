from pathlib import Path
import os
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).parents[1]
SCHEDULE = str(ROOT / "macos/zscaler-schedule/zscaler-schedule")
HOLD = str(ROOT / "bin/zscaler-hold")
TUESDAY = "2026-11-17"
SATURDAY = "2026-11-21"


class ZscalerScheduleTests(unittest.TestCase):
    """The root job reads times and holds from a data file in ~/.config; zscaler-hold writes it without sudo."""

    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.state = tempfile.TemporaryDirectory()
        self.config = Path(self.dir.name) / "config"
        self.env = {
            **os.environ,
            "ZSCALER_SCHEDULE_DRY": "1",
            "ZSCALER_SCHEDULE_TODAY": TUESDAY,
            "ZSCALER_SCHEDULE_CONFIG": self.dir.name,
            "ZSCALER_SCHEDULE_STATE": self.state.name,
        }

    def tearDown(self):
        self.dir.cleanup()
        self.state.cleanup()

    def schedule(self, action="tick", now=f"{TUESDAY} 18:00"):
        return subprocess.run(
            ["/bin/bash", SCHEDULE, action, self.dir.name, "501"],
            env={**self.env, "ZSCALER_SCHEDULE_NOW": now}, text=True, capture_output=True, timeout=10,
        )

    def hold(self, *args):
        return subprocess.run([HOLD, *args], env=self.env, text=True, capture_output=True, timeout=10)

    def outcome(self, result):
        self.assertEqual(result.returncode, 0, result.stderr)
        if "bootout system/com.zscaler.tunnel" in result.stdout:
            return "off"
        if "bootstrap system /Library/LaunchDaemons/com.zscaler.tunnel.plist" in result.stdout:
            return "on"
        return "skipped" if "skipped" in result.stdout else "nothing"

    def test_tick_runs_the_slot_that_is_due(self):
        cases = [
            ("default off slot", None, f"{TUESDAY} 18:00", "off"),
            ("before any slot", None, f"{TUESDAY} 07:55", "nothing"),
            ("default on slot on a weekday", None, f"{TUESDAY} 08:00", "on"),
            ("no on slot at the weekend", None, f"{SATURDAY} 08:00", "nothing"),
            ("custom off time", "OFF_AT=17:30\n", f"{TUESDAY} 17:35", "off"),
            ("custom on days include saturday", "ON_DAYS=6\n", f"{SATURDAY} 08:05", "on"),
            ("held tonight", "HOLD_UNTIL=2026-11-17\n", f"{TUESDAY} 18:00", "skipped"),
            ("held until a later day", "HOLD_UNTIL=2026-11-20\n", f"{TUESDAY} 19:00", "skipped"),
            ("expired hold", "HOLD_UNTIL=2026-11-16\n", f"{TUESDAY} 18:00", "off"),
            ("disabled", "OFF_ENABLED=false\n", f"{TUESDAY} 18:00", "skipped"),
            ("malformed times fall back to defaults", "OFF_AT=6pm\n", f"{TUESDAY} 18:00", "off"),
            ("injection ignored", "OFF_AT=$(touch /tmp/zs-pwned)\nHOLD_UNTIL=`id`\n", f"{TUESDAY} 18:00", "off"),
        ]
        for name, content, now, expected in cases:
            with self.subTest(name):
                self.config.unlink(missing_ok=True)
                for f in Path(self.state.name).iterdir():
                    f.unlink()
                if content:
                    self.config.write_text(content)
                self.assertEqual(self.outcome(self.schedule(now=now)), expected)
        self.assertFalse(Path("/tmp/zs-pwned").exists())

    def test_a_slot_runs_once_and_the_next_slot_runs_again(self):
        self.assertEqual(self.outcome(self.schedule(now=f"{TUESDAY} 18:00")), "off")
        self.assertEqual(self.outcome(self.schedule(now=f"{TUESDAY} 18:05")), "nothing")
        self.assertEqual(self.outcome(self.schedule(now=f"{TUESDAY} 19:00")), "off")

    def test_a_missed_slot_runs_once_on_wake(self):
        self.assertEqual(self.outcome(self.schedule(now=f"{TUESDAY} 08:40")), "on")
        self.assertEqual(self.outcome(self.schedule(now=f"{TUESDAY} 08:45")), "nothing")

    def test_manual_actions(self):
        self.config.write_text("OFF_ENABLED=false\n")
        self.assertEqual(self.outcome(self.schedule("off")), "skipped")
        self.assertEqual(self.outcome(self.schedule("on")), "on")

    def test_bad_arguments_are_refused(self):
        for args in (["sideways", self.dir.name, "501"], ["tick", "", "501"], ["tick", self.dir.name, "root"]):
            with self.subTest(args):
                result = subprocess.run(["/bin/bash", SCHEDULE, *args], env=self.env, capture_output=True, timeout=10)
                self.assertEqual(result.returncode, 64)

    def test_hold_commands_drive_the_job(self):
        cases = [
            (["tonight"], "held until 2026-11-17", "skipped"),
            (["2026-11-20"], "held until 2026-11-20", "skipped"),
            (["--release"], "runs tonight", "off"),
            (["--never"], "disabled", "skipped"),
            (["--resume"], "runs tonight", "off"),
        ]
        for args, status, expected in cases:
            with self.subTest(args):
                result = self.hold(*args)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn(status, result.stdout)
                for f in Path(self.state.name).iterdir():
                    f.unlink()
                self.assertEqual(self.outcome(self.schedule()), expected)

    def test_hold_sets_times_without_dropping_other_keys(self):
        self.hold("2026-11-20")
        result = self.hold("--off-at", "17:30,21:00")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.hold("--on-at", "07:45")
        self.hold("--on-days", "1,2,3,4")
        self.assertEqual(
            self.config.read_text().splitlines(),
            ["OFF_AT=17:30,21:00", "ON_AT=07:45", "ON_DAYS=1,2,3,4", "HOLD_UNTIL=2026-11-20"],
        )
        self.assertIn("off at  17:30,21:00", self.hold("--status").stdout)

    def test_hold_rejects_bad_input(self):
        for args in (["next-friday"], ["--off-at", "6pm"], ["--on-at", "25:00"], ["--on-days", "0,8"], ["--off-at"]):
            with self.subTest(args):
                self.assertEqual(self.hold(*args).returncode, 64)
        self.assertFalse(self.config.exists())


if __name__ == "__main__":
    unittest.main()
