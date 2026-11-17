from pathlib import Path
import os
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).parents[1]
SCHEDULE = str(ROOT / "macos/zscaler-schedule/zscaler-schedule")
HOLD = str(ROOT / "bin/zscaler-hold")
DOTFILE = (ROOT / ".config/zscaler-schedule/schedule").read_text()
MONDAY = "2026-11-16"
TUESDAY = "2026-11-17"
SATURDAY = "2026-11-21"


class ZscalerScheduleTests(unittest.TestCase):
    """The root job reads the schedule dotfile and hold as data; zscaler-hold writes holds without sudo."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        base = Path(self.tmp.name)
        self.dir = base / "config"
        self.state = base / "state"
        self.dir.mkdir()
        self.state.mkdir()
        self.schedule_file = self.dir / "schedule"
        self.hold_file = self.dir / "hold"
        self.watermark = self.state / "last-tick"
        self.env = {
            **os.environ,
            "ZSCALER_SCHEDULE_DRY": "1",
            "ZSCALER_SCHEDULE_TODAY": TUESDAY,
            "ZSCALER_SCHEDULE_CONFIG": str(self.dir),
            "ZSCALER_SCHEDULE_STATE": str(self.state),
            "ZSCALER_SCHEDULE_BIN": str(base / "not-installed"),
        }

    def tearDown(self):
        self.tmp.cleanup()

    def files(self, schedule=DOTFILE, hold=None, last=None):
        for path, content in ((self.schedule_file, schedule), (self.hold_file, hold), (self.watermark, last)):
            path.unlink(missing_ok=True)
            if content is not None:
                path.parent.mkdir(exist_ok=True)
                path.write_text(content if path != self.watermark else content + "\n")

    def run_schedule(self, action, now):
        return subprocess.run(
            ["/bin/bash", SCHEDULE, action, str(self.dir), "501"],
            env={**self.env, "ZSCALER_SCHEDULE_NOW": now}, text=True, capture_output=True, timeout=10,
        )

    def tick(self, now):
        result = self.run_schedule("tick", now)
        self.assertEqual(result.returncode, 0, result.stderr)
        if "bootout system/com.zscaler.tunnel" in result.stdout:
            return "off"
        if "bootstrap system /Library/LaunchDaemons/com.zscaler.tunnel.plist" in result.stdout:
            return "on"
        return "skipped" if "skipped" in result.stdout else "nothing"

    def hold(self, *args):
        return subprocess.run([HOLD, *args], env=self.env, text=True, capture_output=True, timeout=10)

    def test_tick_decides_from_the_slots_since_the_last_tick(self):
        cases = [
            ("off slot reached", DOTFILE, None, f"{TUESDAY} 17:55", f"{TUESDAY} 18:00", "off"),
            ("between slots", DOTFILE, None, f"{TUESDAY} 18:00", f"{TUESDAY} 18:05", "nothing"),
            ("next off slot", DOTFILE, None, f"{TUESDAY} 18:55", f"{TUESDAY} 19:00", "off"),
            ("on slot on a weekday", DOTFILE, None, f"{TUESDAY} 07:55", f"{TUESDAY} 08:00", "on"),
            ("no on slot at the weekend", DOTFILE, None, f"{SATURDAY} 07:55", f"{SATURDAY} 08:00", "nothing"),
            ("first tick of a new day", DOTFILE, None, f"{MONDAY} 23:55", f"{TUESDAY} 08:05", "on"),
            ("missed slot runs on wake", DOTFILE, None, f"{TUESDAY} 07:30", f"{TUESDAY} 08:40", "on"),
            ("two slots missed, the latest runs", DOTFILE, None, f"{TUESDAY} 17:30", f"{TUESDAY} 19:10", "off"),
            ("custom off time", "OFF_AT=17:30\n", None, f"{TUESDAY} 17:25", f"{TUESDAY} 17:35", "off"),
            ("day codes", "ON_DAYS=Sat,sun\n", None, f"{SATURDAY} 07:55", f"{SATURDAY} 08:05", "on"),
            ("codes exclude a weekday", "ON_DAYS=mon,wed\n", None, f"{TUESDAY} 07:55", f"{TUESDAY} 08:05", "nothing"),
            ("codes and numbers mixed", "ON_DAYS=1,TUE\n", None, f"{TUESDAY} 07:55", f"{TUESDAY} 08:05", "on"),
            ("unknown days fall back to weekdays", "ON_DAYS=xyz\n", None, f"{SATURDAY} 07:55", f"{SATURDAY} 08:05", "nothing"),
            ("malformed times fall back", "OFF_AT=6pm\n", None, f"{TUESDAY} 17:55", f"{TUESDAY} 18:00", "off"),
            ("held tonight", DOTFILE, "HOLD_UNTIL=2026-11-17\n", f"{TUESDAY} 17:55", f"{TUESDAY} 18:00", "skipped"),
            ("expired hold", DOTFILE, "HOLD_UNTIL=2026-11-16\n", f"{TUESDAY} 17:55", f"{TUESDAY} 18:00", "off"),
            ("hold in the schedule ignored", "HOLD_UNTIL=2026-11-20\n", None, f"{TUESDAY} 17:55", f"{TUESDAY} 18:00", "off"),
            ("disabled", "OFF_ENABLED=false\n", None, f"{TUESDAY} 17:55", f"{TUESDAY} 18:00", "skipped"),
            ("CRLF line", "OFF_ENABLED=false\r\n", None, f"{TUESDAY} 17:55", f"{TUESDAY} 18:00", "skipped"),
            ("trailing space and comment", "OFF_ENABLED=false   # tonight\n", None, f"{TUESDAY} 17:55", f"{TUESDAY} 18:00", "skipped"),
            ("spaces in a list", "OFF_AT=17:30, 18:30\n", None, f"{TUESDAY} 18:25", f"{TUESDAY} 18:30", "off"),
        ]
        for name, schedule, hold, last, now, expected in cases:
            with self.subTest(name):
                self.files(schedule, hold, last)
                self.assertEqual(self.tick(now), expected)
                self.assertEqual(self.watermark.read_text(), f"{now}\n")

    def test_a_fresh_install_does_not_fire_a_past_slot(self):
        self.files(last=None)
        self.assertEqual(self.tick(f"{TUESDAY} 18:43"), "nothing")
        self.assertEqual(self.tick(f"{TUESDAY} 18:48"), "nothing")
        self.assertEqual(self.tick(f"{TUESDAY} 19:00"), "off")

    def test_moving_a_slot_into_the_past_does_not_fire_it(self):
        self.files(last=f"{TUESDAY} 19:25")
        self.schedule_file.write_text("OFF_AT=18:00,21:00\n")
        self.assertEqual(self.tick(f"{TUESDAY} 19:30"), "nothing")

    def test_a_watermark_from_the_future_resets_to_now(self):
        self.files(last="2027-01-01 12:00")
        self.assertEqual(self.tick(f"{TUESDAY} 18:43"), "nothing")
        self.assertEqual(self.watermark.read_text(), f"{TUESDAY} 18:43\n")

    def test_manual_actions(self):
        self.files("OFF_ENABLED=false\n")
        self.assertIn("skipped", self.run_schedule("off", f"{TUESDAY} 12:00").stdout)
        self.assertIn("switching on", self.run_schedule("on", f"{TUESDAY} 12:00").stdout)

    def test_injected_content_is_never_run(self):
        marker = Path(self.tmp.name) / "pwned"
        self.files(f"OFF_AT=$(touch {marker})\nON_DAYS=`touch {marker}`\n", f"HOLD_UNTIL=;touch {marker}\n", f"{TUESDAY} 17:55")
        self.assertEqual(self.tick(f"{TUESDAY} 18:00"), "off")
        self.run_schedule("status", f"{TUESDAY} 18:00")
        self.assertFalse(marker.exists())

    def test_bad_arguments_are_refused(self):
        for args in (["sideways", str(self.dir), "501"], ["tick", "", "501"], ["tick", str(self.dir), "root"]):
            with self.subTest(args):
                result = subprocess.run(["/bin/bash", SCHEDULE, *args], env=self.env, capture_output=True, timeout=10)
                self.assertEqual(result.returncode, 64)

    def test_holds_drive_the_job(self):
        self.files()
        for args, expected in ((["tonight"], "skipped"), (["2026-11-20"], "skipped"), (["--release"], "off")):
            with self.subTest(args):
                self.assertEqual(self.hold(*args).returncode, 0)
                self.watermark.write_text(f"{TUESDAY} 17:55\n")
                self.assertEqual(self.tick(f"{TUESDAY} 18:00"), expected)

    def test_hold_rejects_bad_dates_and_options(self):
        self.files()
        for args in (["2026-21-11"], ["2026-02-30"], ["2062-11-20"], ["2026-11-16"], ["next-friday"], ["--never"]):
            with self.subTest(args):
                self.assertEqual(self.hold(*args).returncode, 64)
        self.assertFalse(self.hold_file.exists())

    def test_status_reports_what_root_will_use(self):
        self.files("OFF_AT=6pm\nON_DAYS=mon, tue\nOFF_ENABLED=true\n", None)
        status = self.hold("--status").stdout
        self.assertIn("off at  18:00,19:00,20:00,21:00", status)
        self.assertIn("on days 1,2", status)
        self.assertIn("repo copy", status)
        (self.dir / "config").write_text("OFF_ENABLED=false\n")
        self.assertIn("older version and is ignored", self.hold("--status").stdout)

    def test_hold_never_touches_the_schedule_dotfile(self):
        self.files("OFF_AT=17:30\n")
        self.hold("2026-11-20")
        self.assertEqual(self.schedule_file.read_text(), "OFF_AT=17:30\n")
        self.assertEqual(self.hold_file.read_text(), "HOLD_UNTIL=2026-11-20\n")
        self.hold("--release")
        self.assertFalse(self.hold_file.exists())


if __name__ == "__main__":
    unittest.main()
