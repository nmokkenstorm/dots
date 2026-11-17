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
        self.schedule_file = Path(self.dir.name) / "schedule"
        self.hold_file = Path(self.dir.name) / "hold"
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
        dotfile = (ROOT / ".config/zscaler-schedule/schedule").read_text()
        cases = [
            ("no files: defaults", None, None, f"{TUESDAY} 18:00", "off"),
            ("the shipped dotfile", dotfile, None, f"{TUESDAY} 18:00", "off"),
            ("before any slot", dotfile, None, f"{TUESDAY} 07:55", "nothing"),
            ("on slot on a weekday", dotfile, None, f"{TUESDAY} 08:00", "on"),
            ("no on slot at the weekend", dotfile, None, f"{SATURDAY} 08:00", "nothing"),
            ("custom off time", "OFF_AT=17:30\n", None, f"{TUESDAY} 17:35", "off"),
            ("custom on days include saturday", "ON_DAYS=6\n", None, f"{SATURDAY} 08:05", "on"),
            ("held tonight", dotfile, "HOLD_UNTIL=2026-11-17\n", f"{TUESDAY} 18:00", "skipped"),
            ("held until a later day", dotfile, "HOLD_UNTIL=2026-11-20\n", f"{TUESDAY} 19:00", "skipped"),
            ("expired hold", dotfile, "HOLD_UNTIL=2026-11-16\n", f"{TUESDAY} 18:00", "off"),
            ("a hold in the schedule file is ignored", "HOLD_UNTIL=2026-11-20\n", None, f"{TUESDAY} 18:00", "off"),
            ("disabled", "OFF_ENABLED=false\n", None, f"{TUESDAY} 18:00", "skipped"),
            ("malformed times fall back to defaults", "OFF_AT=6pm\n", None, f"{TUESDAY} 18:00", "off"),
            ("injection ignored", "OFF_AT=$(touch /tmp/zs-pwned)\n", "HOLD_UNTIL=`id`\n", f"{TUESDAY} 18:00", "off"),
        ]
        for name, schedule, hold, now, expected in cases:
            with self.subTest(name):
                for path, content in ((self.schedule_file, schedule), (self.hold_file, hold)):
                    path.unlink(missing_ok=True)
                    if content:
                        path.write_text(content)
                for f in Path(self.state.name).iterdir():
                    f.unlink()
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
        self.schedule_file.write_text("OFF_ENABLED=false\n")
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
        ]
        for args, status, expected in cases:
            with self.subTest(args):
                result = self.hold(*args)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn(status, result.stdout)
                for f in Path(self.state.name).iterdir():
                    f.unlink()
                self.assertEqual(self.outcome(self.schedule()), expected)

    def test_hold_never_touches_the_schedule_dotfile(self):
        self.schedule_file.write_text("OFF_AT=17:30\n")
        self.hold("2026-11-20")
        self.assertEqual(self.schedule_file.read_text(), "OFF_AT=17:30\n")
        self.assertEqual(self.hold_file.read_text(), "HOLD_UNTIL=2026-11-20\n")
        status = self.hold("--status").stdout
        self.assertIn("off at  17:30", status)
        self.assertIn("held until 2026-11-20", status)
        self.hold("--release")
        self.assertFalse(self.hold_file.exists())

    def test_hold_rejects_bad_input(self):
        for args in (["next-friday"], ["--never"], ["--off-at", "18:00"]):
            with self.subTest(args):
                self.assertEqual(self.hold(*args).returncode, 64)
        self.assertFalse(self.hold_file.exists())


if __name__ == "__main__":
    unittest.main()
