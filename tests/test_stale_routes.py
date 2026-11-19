from pathlib import Path
import os
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).parents[1]
SCRIPT = str(ROOT / "macos/stale-routes/stale-routes")

HEADER = """Routing tables

Internet:
Destination        Gateway            Flags               Netif Expire
"""


class StaleRoutesTests(unittest.TestCase):
    """Static host routes via a gateway that is no longer on-link get deleted; everything else stays."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.base = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def run_script(self, table, on_link, has_default=True):
        (self.base / "table").write_text(HEADER + table)
        (self.base / "on-link").write_text("".join(f"{entry}\n" for entry in on_link))
        env = {
            **os.environ,
            "STALE_ROUTES_DRY": "1",
            "STALE_ROUTES_TABLE": str(self.base / "table"),
            "STALE_ROUTES_ONLINK": str(self.base / "on-link"),
            "STALE_ROUTES_NOW": "2026-11-19 11:30",
            "STALE_ROUTES_DEFAULT": "1" if has_default else "0",
        }
        result = subprocess.run(["/bin/bash", SCRIPT], env=env, text=True, capture_output=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        return [line for line in result.stdout.splitlines() if line.startswith("would run:")]

    def test_which_routes_are_deleted(self):
        cases = [
            ("host route via a gateway from an old network", "1.1.1.1            172.20.10.1        UGHS                  en0\n",
             ["10.31.0.1 en0"], ["would run: route -n delete -host 1.1.1.1 172.20.10.1"]),
            ("host route via the current gateway", "16.15.183.16       10.31.0.1          UGHS                  en0\n",
             ["10.31.0.1 en0"], []),
            ("gateway on-link, but on another interface", "3.68.124.168       10.31.0.1          UGHS                  en1\n",
             ["10.31.0.1 en0"], ["would run: route -n delete -host 3.68.124.168 10.31.0.1"]),
            ("dynamic host route", "3.68.124.168       172.20.10.1        UGH                   en0\n",
             ["10.31.0.1 en0"], []),
            ("static network route", "100.64/10          172.20.10.1        UGSc                  en0\n",
             ["10.31.0.1 en0"], []),
            ("default route", "default            172.20.10.1        UGScg                 en0\n",
             ["10.31.0.1 en0"], []),
            ("interface route without a gateway address", "10.52.5.71         link#14            UHS                 utun4\n",
             ["10.31.0.1 en0"], []),
        ]
        for name, table, on_link, expected in cases:
            with self.subTest(name):
                self.assertEqual(self.run_script(table, on_link), expected)

    def test_deletes_every_route_via_a_stale_gateway_once(self):
        table = (
            "1.1.1.1            172.20.10.1        UGHS                  en0\n"
            "2.18.244.4         172.20.10.1        UGHS                  en0\n"
            "16.15.183.16       10.31.0.1          UGHS                  en0\n"
        )
        self.assertEqual(
            self.run_script(table, ["10.31.0.1 en0"]),
            [
                "would run: route -n delete -host 1.1.1.1 172.20.10.1",
                "would run: route -n delete -host 2.18.244.4 172.20.10.1",
            ],
        )

    def test_leaves_everything_alone_without_a_default_route(self):
        table = "1.1.1.1            172.20.10.1        UGHS                  en0\n"
        self.assertEqual(self.run_script(table, [], has_default=False), [])


if __name__ == "__main__":
    unittest.main()
