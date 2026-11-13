from pathlib import Path
import os
import re
import shutil
import subprocess
import tempfile
import unittest

PATCH = Path(__file__).parents[1] / "patches/peon-ping-headphones.patch"
UPSTREAM = Path(os.environ.get("PEON_SH", "/opt/homebrew/opt/peon-ping/libexec/peon.sh"))


def device(name, transport, *flags):
    lines = [f"        {name}:", ""]
    lines += [f"          {flag}: Yes" for flag in flags]
    lines += ["          Output Channels: 2", f"          Transport: {transport}", ""]
    return "\n".join(lines)


def profile(*devices):
    return "Audio:\n\n    Devices:\n\n" + "\n".join(devices)


MIC = device("MacBook Pro Microphone", "Built-in", "Default Input Device")
OUT, SYS = "Default Output Device", "Default System Output Device"

CASES = [
    ("built-in speakers", profile(MIC, device("MacBook Pro Speakers", "Built-in", OUT, SYS)), True, False),
    ("airpods", profile(MIC, device("Niels AirPods Pro", "Bluetooth", OUT, SYS)), True, True),
    ("bluetooth speaker without a headphone name", profile(device("JBL Flip 6", "Bluetooth", OUT, SYS)), True, True),
    ("usb headset", profile(device("Jabra Evolve2 65", "USB", OUT, SYS)), True, True),
    ("wired headphones on the jack", profile(device("External Headphones", "Built-in", OUT, SYS)), True, True),
    ("display speakers", profile(device("LG HDR 4K", "DisplayPort", OUT, SYS)), True, False),
    ("blackhole as output", profile(device("BlackHole 2ch", "Virtual", OUT, SYS)), True, False),
    (
        "multi-output default, sound effects on speakers",
        profile(
            MIC,
            device("MacBook Pro Speakers", "Built-in", SYS),
            device("Microsoft Teams Audio", "Virtual"),
            device("Call Capture", "Unknown"),
            device("Call Output", "Unknown", OUT),
        ),
        True,
        False,
    ),
    (
        "afplay mode follows the default output",
        profile(device("MacBook Pro Speakers", "Built-in", SYS), device("Niels AirPods Pro", "Bluetooth", OUT)),
        False,
        True,
    ),
    (
        "headphone neighbour does not leak into a speaker section",
        profile(device("External Headphones", "Built-in"), device("MacBook Pro Speakers", "Built-in", OUT, SYS)),
        True,
        False,
    ),
]


@unittest.skipUnless(UPSTREAM.exists() and shutil.which("patch"), "peon-ping not installed")
class DetectHeadphonesTests(unittest.TestCase):
    """detect_headphones inspects the device peon-ping actually plays on, and only counts real headphones."""

    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        patched = Path(cls.tmp.name) / "peon.sh"
        shutil.copy(UPSTREAM, patched)
        subprocess.run(["patch", "-s", str(patched), str(PATCH)], check=True)
        source = patched.read_text()
        cls.func = re.search(r"^detect_headphones\(\) \{\n.*?^\}\n", source, re.S | re.M).group(0)

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def detect(self, fixture, sound_effects_device):
        bindir = Path(self.tmp.name) / "bin"
        bindir.mkdir(exist_ok=True)
        (bindir / "fixture.txt").write_text(fixture)
        stub = bindir / "system_profiler"
        stub.write_text(f"#!/bin/sh\ncat '{bindir / 'fixture.txt'}'\n")
        stub.chmod(0o755)
        env = {
            **os.environ,
            "PATH": f"{bindir}:{os.environ['PATH']}",
            "PEON_PLATFORM": "mac",
            "USE_SOUND_EFFECTS_DEVICE": str(sound_effects_device).lower(),
        }
        result = subprocess.run(["bash", "-c", self.func + "detect_headphones"], env=env)
        return result.returncode == 0

    def test_cases(self):
        for name, fixture, sound_effects_device, expected in CASES:
            with self.subTest(name):
                self.assertEqual(self.detect(fixture, sound_effects_device), expected)


if __name__ == "__main__":
    unittest.main()
