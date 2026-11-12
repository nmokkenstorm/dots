from pathlib import Path
import os
import subprocess
import tempfile
import unittest

TRAIN = str(Path(__file__).parents[1] / "bin/train")


class ParallelRunTests(unittest.TestCase):
    """--parallel watches independent steps at once, so a slow step never hides a finished one."""

    def setUp(self):
        self.root = tempfile.TemporaryDirectory()
        self.env = {**os.environ, "TRAIN_ROOT": self.root.name, "TRAIN_NO_REEDS": "1"}
        self.flag = Path(self.root.name) / "flag"

    def tearDown(self):
        self.root.cleanup()

    def train(self, *args, stdin="", timeout=10):
        return subprocess.run(
            [TRAIN, *args], input=stdin, env=self.env, text=True,
            capture_output=True, timeout=timeout,
        )

    def state(self, id):
        rows = (Path(self.root.name) / id / "state").read_text().splitlines()
        return {key: status for key, status, _ in (r.split("|", 2) for r in rows)}

    def test_a_step_waiting_on_a_later_one_finishes(self):
        plan = (
            f"slow|waits for fast|for i in $(seq 50); do [ -f {self.flag} ] && exit 0; sleep 0.1; done; exit 1\n"
            f"fast|writes the flag|touch {self.flag}\n"
        )
        self.train("new", "t", stdin=plan)
        result = self.train("run", "--parallel", "t")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.state("t"), {"slow": "done", "fast": "done"})

    def test_one_failing_step_leaves_the_others_running_and_fails_the_run(self):
        plan = (
            "bad|fails|exit 3\n"
            f"good|finishes after bad|sleep 0.5; touch {self.flag}\n"
        )
        self.train("new", "t", stdin=plan)
        result = self.train("run", "--parallel", "t")
        self.assertEqual(result.returncode, 3)
        self.assertEqual(self.state("t"), {"bad": "fail", "good": "done"})

    def test_needs_user_wins_over_success(self):
        self.train("new", "t", stdin="human|needs a human|exit 75\nok|fine|true\n")
        result = self.train("run", "--parallel", "t")
        self.assertEqual(result.returncode, 75)
        self.assertEqual(self.state("t"), {"human": "needs-user", "ok": "done"})

    def test_done_steps_are_skipped(self):
        self.train("new", "t", stdin="a|first|exit 9\nb|second|true\n")
        self.train("mark", "t", "a", "done")
        result = self.train("run", "--parallel", "t")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.state("t"), {"a": "done", "b": "done"})


if __name__ == "__main__":
    unittest.main()
