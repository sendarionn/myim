import hashlib
import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).parents[2] / "Scripts" / "collect-research.py"
SPEC = importlib.util.spec_from_file_location("collect_research", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
sys.modules["collect_research"] = MODULE
SPEC.loader.exec_module(MODULE)

FAKE_KEY = "sk-" + "a1B2c3D4e5F6g7H8i9J0k1L2m3N4"


def write_jsonl(path: Path, rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("".join(json.dumps(row, ensure_ascii=False) + "\n" for row in rows))


def codex_session(cwd: str, text: str, extra: list[dict] | None = None) -> list[dict]:
    return [
        {"type": "session_meta", "timestamp": "2026-10-01T00:00:00Z",
         "payload": {"id": "thread", "session_id": "thread", "cwd": cwd, "git": {}}},
        {"type": "response_item", "timestamp": "2026-10-01T00:00:01Z",
         "payload": {"type": "message", "role": "user",
                     "content": [{"type": "input_text", "text": text}]}},
        {"type": "response_item", "timestamp": "2026-10-01T00:00:02Z",
         "payload": {"type": "reasoning", "summary": [],
                     "encrypted_content": "gAAAA" + FAKE_KEY + "=="}},
    ] + (extra or [])


class CollectResearchTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        root = Path(self.temporary.name)
        self.repo = root / "myim"
        self.repo.mkdir()
        subprocess.run(["git", "init", "-q", str(self.repo)], check=True)
        (self.repo / "README.md").write_text("myim\n")
        subprocess.run(["git", "-C", str(self.repo), "add", "."], check=True)
        subprocess.run(
            ["git", "-C", str(self.repo), "-c", "user.name=t", "-c", "user.email=t@t",
             "commit", "-q", "-m", "init"],
            check=True,
        )
        self.head = subprocess.run(
            ["git", "-C", str(self.repo), "rev-parse", "HEAD"],
            check=True, capture_output=True, text=True,
        ).stdout.strip()
        self.other = root / "other-project"
        self.other.mkdir()
        self.codex = root / "codex"
        self.claude = root / "claude"
        self.output = root / "out"
        sessions = self.codex / "sessions" / "2026" / "10" / "01"
        write_jsonl(sessions / "rollout-a.jsonl", codex_session(
            str(self.repo),
            f"myimを直す\nOPENAI_API_KEY={FAKE_KEY}\ncommit {self.head[:7]}",
        ))
        write_jsonl(sessions / "rollout-b.jsonl", codex_session(
            str(root / "renamed-ime"), "myim " * 25,
        ))
        write_jsonl(sessions / "rollout-c.jsonl", codex_session(
            str(root / "renamed-ime"), "最初の試行",
        ))
        write_jsonl(sessions / "rollout-d.jsonl", codex_session(
            str(self.other), "[myim]を例に使う " * 25,
        ))
        write_jsonl(sessions / "rollout-e.jsonl", codex_session(
            str(self.other), "関係のない作業",
        ))
        write_jsonl(self.claude / "projects" / "-myim" / "session.jsonl", [
            {"type": "user", "sessionId": "claude-1", "cwd": str(self.repo),
             "timestamp": "2026-10-01T00:00:00Z",
             "message": {"role": "user", "content": "辞書登録を直して"}},
            {"type": "assistant", "sessionId": "claude-1", "cwd": str(self.repo),
             "timestamp": "2026-10-01T00:00:01Z",
             "message": {"role": "assistant", "content": [
                 {"type": "tool_use", "id": "t1", "name": "Bash",
                  "input": {"command": "git log"}},
             ]}},
        ])
        self.source_hashes = self.hashes()

    def tearDown(self):
        self.temporary.cleanup()

    def hashes(self):
        return {
            path: hashlib.sha256(path.read_bytes()).hexdigest()
            for base in (self.codex, self.claude)
            for path in base.rglob("*.jsonl")
        }

    def run_collector(self, *extra):
        arguments = MODULE.parse_arguments([
            "--repo", str(self.repo), "--output", str(self.output),
            "--codex-home", str(self.codex), "--claude-home", str(self.claude),
            "--chatgpt-export", str(Path(self.temporary.name) / "downloads"),
            *extra,
        ])
        return MODULE.Collector(arguments).run()

    def statuses(self, manifest):
        codex = manifest["sources"]["codex"]
        result = {entry["session_id"]: entry["status"] for entry in codex["sessions"]}
        result.update({entry["session_id"]: entry["status"] for entry in codex["not_selected"]})
        return result

    def test_classifies_repository_predecessor_and_other_projects(self):
        statuses = self.statuses(self.run_collector())

        self.assertEqual(statuses["a"], "selected")
        self.assertEqual(statuses["b"], "selected")
        self.assertEqual(statuses["c"], "selected")
        self.assertEqual(statuses["d"], "unclassified")
        self.assertEqual(statuses["e"], "excluded")

    def test_redacts_secrets_but_keeps_opaque_blobs(self):
        manifest = self.run_collector()
        entry = next(item for item in manifest["sources"]["codex"]["sessions"]
                     if item["session_id"] == "a")
        raw = (self.output / entry["raw_file"]).read_text()
        normalized = (self.output / entry["normalized_file"]).read_text()

        self.assertEqual(entry["redactions"], 1)
        self.assertNotIn("OPENAI_API_KEY=" + FAKE_KEY, raw)
        self.assertIn("gAAAA" + FAKE_KEY, raw)
        self.assertNotIn(FAKE_KEY, normalized)
        self.assertIn(MODULE.REDACTED, normalized)

    def test_normalizes_messages_tools_and_commits(self):
        manifest = self.run_collector()
        codex = next(item for item in manifest["sources"]["codex"]["sessions"]
                     if item["session_id"] == "a")
        rows = [json.loads(line) for line in
                (self.output / codex["normalized_file"]).read_text().splitlines()]
        message = next(row for row in rows if row["kind"] == "message")
        claude = manifest["sources"]["claude"]["sessions"][0]
        claude_rows = [json.loads(line) for line in
                       (self.output / claude["normalized_file"]).read_text().splitlines()]

        self.assertEqual(message["commit_shas"], [self.head[:7]])
        self.assertEqual(message["cwd"], str(self.repo))
        self.assertEqual(message["source_raw_file"], codex["raw_file"])
        self.assertEqual([row["kind"] for row in claude_rows], ["message", "tool_call"])

    def test_reruns_without_recopying_and_keeps_sources_unchanged(self):
        self.run_collector()
        second = self.run_collector()

        self.assertTrue(all(
            not entry["raw_updated"] for entry in second["sources"]["codex"]["sessions"]
        ))
        self.assertEqual(self.hashes(), self.source_hashes)
        self.assertIn("ChatGPT export: missing", second["warnings"])
        self.assertFalse(second["sources"]["chatgpt"]["export_found"])

    def test_dry_run_writes_nothing(self):
        self.run_collector("--dry-run")

        self.assertFalse(self.output.exists())


if __name__ == "__main__":
    unittest.main()
