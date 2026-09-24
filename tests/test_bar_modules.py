"""bar-pr and bar-reeds: the summarise step, fed fixture JSON on stdin."""

import json
import subprocess
import unittest
from pathlib import Path

BIN = Path(__file__).resolve().parents[1] / "bin"


def run(tool, args, payload):
    return subprocess.run([str(BIN / tool), "summarise", *args], input=json.dumps(payload),
                          capture_output=True, text=True).stdout.strip()


def pr(author, decision="REVIEW_REQUIRED", requested=(), draft=False):
    return {"author": {"login": author}, "reviewDecision": decision, "isDraft": draft,
            "reviewRequests": [{"login": r} for r in requested]}


class BarPr(unittest.TestCase):
    def test_counts_open_approved_and_requested_from_me(self):
        prs = [pr("me", "APPROVED"), pr("other", requested=("me",)), pr("other"), pr("me", draft=True)]
        out = run("bar-pr", ["ai-gateway", "me"], prs)
        self.assertIn("ai-gateway 3 open", out)
        self.assertIn("1 approved", out)
        self.assertIn("1 to review", out)

    def test_zero_to_review_is_not_highlighted(self):
        out = run("bar-pr", ["ai-gateway", "me"], [pr("me")])
        self.assertIn("0 to review", out)
        self.assertNotIn("#[fg=#f6c177]", out)

    def test_my_own_pr_requesting_me_does_not_count(self):
        out = run("bar-pr", ["ai-gateway", "me"], [pr("me", requested=("me",))])
        self.assertIn("0 to review", out)

    def test_empty_repo_renders_nothing(self):
        self.assertEqual(run("bar-pr", ["ai-gateway", "me"], []), "")


class BarReeds(unittest.TestCase):
    def test_counts_needs_user_entries(self):
        state = {"entries": [{"kind": "needs-user"}, {"kind": "status"}, {"kind": "needs-user"}]}
        self.assertIn("reeds 2 need you", run("bar-reeds", [], state))

    def test_nothing_pending_renders_nothing(self):
        self.assertEqual(run("bar-reeds", [], {"entries": [{"kind": "done"}]}), "")


if __name__ == "__main__":
    unittest.main()
