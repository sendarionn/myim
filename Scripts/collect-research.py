#!/usr/bin/env python3
"""myim開発史監査用のResearch Bundleを収集する

Codex・Claude Code・ChatGPT Data Exportから、myimに関係する会話だけを
.research/ へsnapshotし、共通形式のJSONLへ正規化する。
元ログは読み取り専用で開き、変更しない。
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Iterable, Iterator

NORMALIZATION_VERSION = 1
# 秘密情報の置換規則を変えたら上げる。raw・normalizedを作り直す
REDACTION_VERSION = 2
MAX_TOOL_TEXT = 4000
REDACTED = "[REDACTED_SECRET]"

# 秘密情報の形式。encrypted_contentなど不透明なblobは走査対象から外す
SECRET_PATTERNS = [
    re.compile(r"\bsk-(?:proj-|ant-)?[A-Za-z0-9_-]{20,}"),
    re.compile(r"\bgh[pousr]_[A-Za-z0-9]{30,}"),
    re.compile(r"\bgithub_pat_[A-Za-z0-9_]{30,}"),
    re.compile(r"\bxox[abprs]-[A-Za-z0-9-]{10,}"),
    re.compile(r"\bAKIA[0-9A-Z]{16}\b"),
    re.compile(r"\bAIza[0-9A-Za-z_-]{35}\b"),
    re.compile(r"\bGOCSPX-[A-Za-z0-9_-]{16,}"),
    re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?-----END [A-Z ]*PRIVATE KEY-----"),
    re.compile(r"\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}"),
    re.compile(r"(?i)\b(authorization|cookie|set-cookie)\s*:\s*[^\s\"\\]{12,}"),
    re.compile(
        r"(?i)\b(api[_-]?key|access[_-]?token|refresh[_-]?token|client[_-]?secret|password|passwd)"
        r"(\"?\s*[:=]\s*\"?)(?!\[REDACTED_SECRET\])([^\s\"'\\,]{8,})"
    ),
]
OPAQUE_KEYS = {"encrypted_content", "signature"}

# 内容判定に使うmyim固有の手掛かり
STRONG_MARKERS = ["sendarionn/myim", "/Users/sendarionn/myim", "myim"]
PROJECT_MARKERS = [
    "InputController", "InputMethodKit", "CandidateSession", "CandidatePipeline",
    "MyIMECore", "MyIMEMacOS", "ユーザー辞書", "次入力", "動詞活用", "選択文字列",
    "Selection Service", "候補パネル", "辞書パネル", "JavaScript拡張", "意味検索",
]
CONTENT_SELECT_THRESHOLD = 20


def log(message: str, *, verbose: bool, force: bool = False) -> None:
    if verbose or force:
        print(message, file=sys.stderr)


def sha256_of(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def strip_opaque(value: Any) -> Any:
    if isinstance(value, dict):
        return {
            key: strip_opaque(item)
            for key, item in value.items()
            if key not in OPAQUE_KEYS
        }
    if isinstance(value, list):
        return [strip_opaque(item) for item in value]
    return value


def redact_text(text: str) -> tuple[str, int]:
    count = 0

    def replace(match: re.Match[str]) -> str:
        nonlocal count
        count += 1
        if match.re.groups >= 3:
            return match.group(1) + match.group(2) + REDACTED
        return REDACTED

    for pattern in SECRET_PATTERNS:
        text = pattern.sub(replace, text)
    return text, count


def redact_value(value: Any) -> tuple[Any, int]:
    if isinstance(value, str):
        return redact_text(value)
    if isinstance(value, dict):
        total = 0
        result = {}
        for key, item in value.items():
            if key in OPAQUE_KEYS:
                result[key] = item
                continue
            result[key], count = redact_value(item)
            total += count
        return result, total
    if isinstance(value, list):
        total = 0
        result = []
        for item in value:
            redacted, count = redact_value(item)
            result.append(redacted)
            total += count
        return result, total
    return value, 0


def iter_json_lines(path: Path) -> Iterator[tuple[int, Any]]:
    with path.open(encoding="utf-8", errors="replace") as stream:
        for number, line in enumerate(stream, 1):
            line = line.strip()
            if not line:
                continue
            try:
                yield number, json.loads(line)
            except json.JSONDecodeError:
                yield number, None


@dataclass
class SessionRecord:
    source: str
    source_path: Path
    session_id: str
    reason: str
    status: str  # selected / excluded / unclassified
    cwd: str | None = None
    repository: str | None = None
    kind: str = "conversation"
    details: dict[str, Any] = field(default_factory=dict)


class Collector:
    def __init__(self, arguments: argparse.Namespace) -> None:
        self.arguments = arguments
        self.repo = arguments.repo.resolve()
        self.output = arguments.output.resolve()
        self.dry_run = arguments.dry_run
        self.verbose = arguments.verbose
        self.warnings: list[str] = []
        self.previous = self._load_previous_manifest()
        self.repo_commits = self._repository_commits()
        self.repo_aliases = {str(self.repo)} | set(arguments.alias_cwd or [])
        self.forced_sessions = set(arguments.include_session or [])

    # MARK: - environment

    def _load_previous_manifest(self) -> dict[str, Any]:
        path = self.output / "manifest.json"
        if path.exists():
            try:
                return json.loads(path.read_text(encoding="utf-8"))
            except json.JSONDecodeError:
                self.warnings.append("既存manifest.jsonを読めないため作り直した")
        return {}

    def _git(self, *arguments: str) -> str:
        return subprocess.run(
            ["git", "-C", str(self.repo), *arguments],
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()

    def _repository_commits(self) -> set[str]:
        try:
            return set(self._git("rev-list", "--all").split())
        except (subprocess.CalledProcessError, FileNotFoundError):
            self.warnings.append("gitのcommit一覧を取得できない")
            return set()

    def _repository_url(self) -> str | None:
        try:
            return self._git("remote", "get-url", "origin") or None
        except subprocess.CalledProcessError:
            return None

    # MARK: - classification

    def _is_repo_path(self, value: str | None) -> bool:
        if not value:
            return False
        candidates = {value, os.path.realpath(value)}
        aliases = {alias for alias in self.repo_aliases} | {
            os.path.realpath(alias) for alias in self.repo_aliases
        }
        return any(
            candidate == alias or candidate.startswith(alias.rstrip("/") + "/")
            for candidate in candidates
            for alias in aliases
        )

    def _content_score(self, path: Path) -> tuple[int, int]:
        strong = 0
        project = 0
        with path.open(encoding="utf-8", errors="replace") as stream:
            for line in stream:
                strong += sum(line.count(marker) for marker in STRONG_MARKERS[:2])
                strong += len(re.findall(r"\bmyim\b", line))
                project += sum(line.count(marker) for marker in PROJECT_MARKERS)
        return strong, project

    def _classify_by_content(
        self, path: Path, cwd: str | None = None
    ) -> tuple[str, str]:
        strong, project = self._content_score(path)
        if strong >= CONTENT_SELECT_THRESHOLD and cwd and Path(cwd).exists():
            return "unclassified", (
                f"content: myim言及{strong}件, ただし別プロジェクトのcwd"
            )
        if strong >= CONTENT_SELECT_THRESHOLD:
            return "selected", (
                f"content: myim言及{strong}件"
                + (", cwdは現存しない" if cwd else "")
            )
        if strong > 0 or project >= CONTENT_SELECT_THRESHOLD:
            return "unclassified", f"content: myim言及{strong}件, 関連語{project}件"
        return "excluded", "myimへの言及なし"

    # MARK: - Codex

    def codex_sessions(self) -> tuple[list[str], list[SessionRecord]]:
        home = Path(os.environ.get("CODEX_HOME", Path.home() / ".codex"))
        if self.arguments.codex_home:
            home = self.arguments.codex_home
        roots = [home / "sessions", home / "archived_sessions"]
        locations = [str(root) for root in roots if root.is_dir()]
        records: list[SessionRecord] = []
        for root in roots:
            if not root.is_dir():
                continue
            for path in sorted(root.rglob("*.jsonl")):
                records.append(self._classify_codex(path))
        return locations, self._include_predecessor_sessions(records)

    @staticmethod
    def _include_predecessor_sessions(
        records: list[SessionRecord],
    ) -> list[SessionRecord]:
        """内容からmyimと判定した改名前のcwdを、同じcwdの他sessionにも適用する"""
        predecessors = {
            record.cwd for record in records
            if record.status == "selected"
            and record.reason.startswith("content")
            and record.cwd and not Path(record.cwd).exists()
        }
        for record in records:
            if record.status != "selected" and record.cwd in predecessors:
                record.status = "selected"
                record.reason = f"改名前のmyimと判定したcwd ({record.cwd})"
        return records

    def _classify_codex(self, path: Path) -> SessionRecord:
        meta: dict[str, Any] = {}
        for _, value in iter_json_lines(path):
            if isinstance(value, dict) and value.get("type") == "session_meta":
                meta = value.get("payload") or {}
            break
        cwd = meta.get("cwd")
        git = meta.get("git") or {}
        repository = git.get("repository_url") if isinstance(git, dict) else None
        source = meta.get("source")
        kind = "guardian-review" if isinstance(source, dict) and "subagent" in source else "conversation"
        session_id = path.stem.removeprefix("rollout-")
        details = {
            "thread_id": meta.get("session_id") or meta.get("id"),
            "started_at": meta.get("timestamp"),
            "originator": meta.get("originator"),
        }
        if self._is_repo_path(cwd):
            status, reason = "selected", "cwd"
        elif repository and "sendarionn/myim" in repository:
            status, reason = "selected", "git repository_url"
        else:
            status, reason = self._classify_by_content(path, cwd)
        if status != "selected" and session_id in self.forced_sessions:
            status, reason = "selected", "--include-session"
        return SessionRecord(
            "codex", path, session_id, reason, status,
            cwd=cwd, repository=repository, kind=kind, details=details,
        )

    # MARK: - Claude Code

    def claude_sessions(self) -> tuple[list[str], list[SessionRecord]]:
        home = Path(os.environ.get("CLAUDE_CONFIG_DIR", Path.home() / ".claude"))
        if self.arguments.claude_home:
            home = self.arguments.claude_home
        projects = home / "projects"
        records: list[SessionRecord] = []
        if not projects.is_dir():
            return [], records
        for path in sorted(projects.rglob("*.jsonl")):
            if "memory" in path.relative_to(projects).parts:
                continue
            records.append(self._classify_claude(path, projects))
        return [str(projects)], records

    def _classify_claude(self, path: Path, projects: Path) -> SessionRecord:
        cwds: set[str] = set()
        session_id = path.stem
        for _, value in iter_json_lines(path):
            if isinstance(value, dict):
                if value.get("cwd"):
                    cwds.add(value["cwd"])
                session_id = value.get("sessionId", session_id)
        relative = path.relative_to(projects)
        kind = "subagent" if "subagents" in relative.parts else "conversation"
        cwd = sorted(cwds)[0] if cwds else None
        if any(self._is_repo_path(value) for value in cwds):
            status, reason = "selected", "cwd"
        else:
            status, reason = self._classify_by_content(path, cwd)
        if status != "selected" and session_id in self.forced_sessions:
            status, reason = "selected", "--include-session"
        return SessionRecord(
            "claude", path, f"{session_id}" if kind == "conversation" else f"{session_id}-{path.stem}",
            reason, status, cwd=cwd, kind=kind,
            details={"project_directory": relative.parts[0], "cwds": sorted(cwds)},
        )

    # MARK: - ChatGPT

    def chatgpt_exports(self) -> list[Path]:
        candidates: list[Path] = []
        search = self.arguments.chatgpt_export or [Path.home() / "Downloads"]
        for location in search:
            location = location.expanduser()
            if location.is_file() and location.suffix == ".zip":
                candidates.append(location)
            elif location.is_dir():
                if list(location.glob("conversations*.json")):
                    candidates.append(location)
                for child in sorted(location.iterdir()):
                    if child.suffix == ".zip" and self._zip_has_conversations(child):
                        candidates.append(child)
                    elif child.is_dir() and list(child.glob("conversations*.json")):
                        candidates.append(child)
        return sorted(set(candidates), key=lambda path: path.stat().st_mtime)

    @staticmethod
    def _zip_has_conversations(path: Path) -> bool:
        try:
            with zipfile.ZipFile(path) as archive:
                return any(
                    re.search(r"(^|/)conversations(-\d+)?\.json$", name)
                    for name in archive.namelist()
                )
        except (zipfile.BadZipFile, OSError):
            return False

    def chatgpt_conversations(self, export: Path) -> list[dict[str, Any]]:
        conversations: list[dict[str, Any]] = []
        if export.is_dir():
            for file in sorted(export.glob("conversations*.json")):
                conversations.extend(json.loads(file.read_text(encoding="utf-8")))
            return conversations
        with zipfile.ZipFile(export) as archive:
            for name in sorted(archive.namelist()):
                if re.search(r"(^|/)conversations(-\d+)?\.json$", name):
                    conversations.extend(json.loads(archive.read(name)))
        return conversations

    @staticmethod
    def chatgpt_messages(conversation: dict[str, Any]) -> list[dict[str, Any]]:
        mapping = conversation.get("mapping") or {}
        node_id = conversation.get("current_node")
        chain = []
        while node_id and node_id in mapping:
            chain.append(mapping[node_id])
            node_id = mapping[node_id].get("parent")
        messages = []
        for node in reversed(chain):
            message = node.get("message")
            if not message:
                continue
            parts = (message.get("content") or {}).get("parts") or []
            text = "\n".join(part for part in parts if isinstance(part, str))
            if text.strip():
                messages.append(message | {"text": text})
        return messages

    def classify_chatgpt(self, conversation: dict[str, Any]) -> tuple[str, str]:
        text = (conversation.get("title") or "") + "\n" + "\n".join(
            message["text"] for message in self.chatgpt_messages(conversation)
        )
        strong = len(re.findall(r"\bmyim\b", text)) + text.count("sendarionn/myim")
        project = sum(text.count(marker) for marker in PROJECT_MARKERS)
        if strong >= 1 and project >= 1 or strong >= 3:
            return "selected", f"content: myim言及{strong}件, 関連語{project}件"
        if project >= 3:
            return "unclassified", f"content: 関連語{project}件, myim言及なし"
        return "excluded", "myimへの言及なし"

    # MARK: - snapshot

    def snapshot(self, record: SessionRecord, relative: Path) -> dict[str, Any]:
        destination = self.output / "raw" / record.source / relative
        source_hash = sha256_of(record.source_path)
        previous = self._previous_entry(record.source, record.session_id)
        unchanged = (
            previous is not None
            and previous.get("source_sha256") == source_hash
            and previous.get("redaction_version") == REDACTION_VERSION
            and destination.exists()
        )
        entry = {
            "redaction_version": REDACTION_VERSION,
            "raw_file": str(destination.relative_to(self.output)),
            "source_sha256": source_hash,
            "source_size": record.source_path.stat().st_size,
        }
        if unchanged:
            entry["redactions"] = previous.get("redactions", 0)
            entry["raw_updated"] = False
            return entry
        redactions = self._secret_count(record.source_path)
        entry["redactions"] = redactions
        entry["raw_updated"] = True
        if self.dry_run:
            return entry
        destination.parent.mkdir(parents=True, exist_ok=True)
        if redactions == 0:
            shutil.copy2(record.source_path, destination)
        else:
            self._write_redacted_copy(record.source_path, destination)
        return entry

    def _secret_count(self, path: Path) -> int:
        total = 0
        for _, value in iter_json_lines(path):
            if value is None:
                continue
            _, count = redact_value(strip_opaque(value))
            total += count
        return total

    @staticmethod
    def _write_redacted_copy(source: Path, destination: Path) -> None:
        with tempfile.NamedTemporaryFile(
            "w", encoding="utf-8", dir=destination.parent, delete=False
        ) as stream:
            for _, value in iter_json_lines(source):
                if value is None:
                    continue
                redacted, _ = redact_value(value)
                stream.write(json.dumps(redacted, ensure_ascii=False) + "\n")
        os.replace(stream.name, destination)

    def _previous_entry(self, source: str, session_id: str) -> dict[str, Any] | None:
        for entry in self.previous.get("sources", {}).get(source, {}).get("sessions", []):
            if entry.get("session_id") == session_id:
                return entry
        return None

    # MARK: - normalization

    def commit_shas(self, text: str) -> list[str]:
        if not self.repo_commits:
            return []
        found = []
        for token in set(re.findall(r"\b[0-9a-f]{7,40}\b", text)):
            if any(commit.startswith(token) for commit in self.repo_commits):
                found.append(token)
        return sorted(found)

    def write_normalized(
        self,
        source: str,
        session_id: str,
        rows: Iterable[dict[str, Any]],
    ) -> tuple[str, int, int]:
        destination = self.output / "normalized" / source / f"{session_id}.jsonl"
        count = 0
        redactions = 0
        lines = []
        for row in rows:
            row["text"], redacted = redact_text(row.get("text") or "")
            redactions += redacted
            if row.get("tool"):
                row["tool"], redacted = redact_value(row["tool"])
                redactions += redacted
            row["commit_shas"] = sorted(
                set(row.get("commit_shas", [])) | set(self.commit_shas(row["text"]))
            )
            lines.append(json.dumps(row, ensure_ascii=False))
            count += 1
        if not self.dry_run:
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_text("\n".join(lines) + ("\n" if lines else ""), encoding="utf-8")
        return str(destination.relative_to(self.output)), count, redactions

    @staticmethod
    def _truncate(text: str) -> tuple[str, bool]:
        if len(text) <= MAX_TOOL_TEXT:
            return text, False
        head = text[: MAX_TOOL_TEXT - 800]
        tail = text[-600:]
        return f"{head}\n…[truncated {len(text) - len(head) - len(tail)} chars]…\n{tail}", True

    def codex_rows(self, record: SessionRecord, raw_file: str) -> Iterator[dict[str, Any]]:
        cwd = record.cwd
        base = {
            "source": "codex",
            "session_id": record.session_id,
            "thread_id": record.details.get("thread_id"),
            "repository": record.repository,
            "source_raw_file": raw_file,
        }
        for number, value in iter_json_lines(record.source_path):
            if not isinstance(value, dict):
                continue
            payload = value.get("payload") if isinstance(value.get("payload"), dict) else {}
            kind = value.get("type")
            timestamp = value.get("timestamp")
            if kind == "turn_context" and payload.get("cwd"):
                cwd = payload["cwd"]
                continue
            row = base | {"timestamp": timestamp, "cwd": cwd, "source_line": number}
            if kind == "session_meta":
                git = payload.get("git") or {}
                commit = git.get("commit_hash") if isinstance(git, dict) else None
                yield row | {
                    "role": "system", "kind": "session_start",
                    "text": f"cwd={payload.get('cwd')} branch={git.get('branch') if isinstance(git, dict) else None}",
                    "commit_shas": [commit[:12]] if commit else [],
                }
            elif kind == "response_item":
                yield from self._codex_response_item(payload, row)
            elif kind == "event_msg" and payload.get("type") in {
                "task_complete", "turn_aborted", "error", "stream_error"
            }:
                error = payload.get("error") or {}
                text = (
                    error.get("message") if isinstance(error, dict) else str(error)
                ) or payload.get("reason") or ""
                yield row | {"role": "system", "kind": payload["type"], "text": text}
            elif kind == "compacted":
                yield row | {"role": "system", "kind": "context_compacted", "text": ""}

    def _codex_response_item(
        self, payload: dict[str, Any], row: dict[str, Any]
    ) -> Iterator[dict[str, Any]]:
        item_type = payload.get("type")
        if item_type == "message":
            text = "\n".join(
                part.get("text", "")
                for part in payload.get("content") or []
                if isinstance(part, dict)
            )
            role = payload.get("role")
            kind = "context" if role in {"user", "developer"} and text.lstrip().startswith(
                ("<", "# AGENTS.md instructions")
            ) else "message"
            yield row | {"role": role, "kind": kind, "text": text}
        elif item_type == "reasoning":
            summary = "\n".join(
                part.get("text", "") for part in payload.get("summary") or []
                if isinstance(part, dict)
            )
            if summary:
                yield row | {"role": "assistant", "kind": "reasoning_summary", "text": summary}
        elif item_type in {"function_call", "custom_tool_call", "local_shell_call"}:
            raw = payload.get("arguments") or payload.get("input") or payload.get("action") or ""
            command = raw if isinstance(raw, str) else json.dumps(raw, ensure_ascii=False)
            command, truncated = self._truncate(command)
            yield row | {
                "role": "assistant", "kind": "tool_call", "text": command,
                "tool": {"name": payload.get("name"), "call_id": payload.get("call_id"), "truncated": truncated},
            }
        elif item_type in {"function_call_output", "custom_tool_call_output"}:
            output = payload.get("output")
            if isinstance(output, list):
                output = "\n".join(
                    part.get("text", "") for part in output if isinstance(part, dict)
                )
            elif isinstance(output, dict):
                output = output.get("content") or json.dumps(output, ensure_ascii=False)
            text, truncated = self._truncate(str(output or ""))
            yield row | {
                "role": "tool", "kind": "tool_result", "text": text,
                "tool": {"call_id": payload.get("call_id"), "truncated": truncated},
            }

    def claude_rows(self, record: SessionRecord, raw_file: str) -> Iterator[dict[str, Any]]:
        for number, value in iter_json_lines(record.source_path):
            if not isinstance(value, dict) or value.get("type") not in {"user", "assistant"}:
                continue
            message = value.get("message") or {}
            row = {
                "source": "claude",
                "session_id": record.session_id,
                "timestamp": value.get("timestamp"),
                "cwd": value.get("cwd"),
                "repository": None,
                "source_raw_file": raw_file,
                "source_line": number,
            }
            content = message.get("content")
            role = message.get("role") or value["type"]
            if isinstance(content, str):
                yield row | {"role": role, "kind": "message", "text": content}
                continue
            for block in content or []:
                if not isinstance(block, dict):
                    continue
                block_type = block.get("type")
                if block_type == "text":
                    kind = "context" if block.get("text", "").lstrip().startswith("<") and role == "user" else "message"
                    yield row | {"role": role, "kind": kind, "text": block.get("text", "")}
                elif block_type == "thinking" and block.get("thinking"):
                    yield row | {"role": role, "kind": "reasoning", "text": block["thinking"]}
                elif block_type == "tool_use":
                    command, truncated = self._truncate(json.dumps(block.get("input"), ensure_ascii=False))
                    yield row | {
                        "role": role, "kind": "tool_call", "text": command,
                        "tool": {"name": block.get("name"), "call_id": block.get("id"), "truncated": truncated},
                    }
                elif block_type == "tool_result":
                    result = block.get("content")
                    if isinstance(result, list):
                        result = "\n".join(
                            part.get("text", "") for part in result if isinstance(part, dict)
                        )
                    text, truncated = self._truncate(str(result or ""))
                    yield row | {
                        "role": "tool", "kind": "tool_result", "text": text,
                        "tool": {"call_id": block.get("tool_use_id"), "truncated": truncated},
                    }

    # MARK: - run

    def run(self) -> dict[str, Any]:
        manifest: dict[str, Any] = {
            "generated_at": dt.datetime.now(dt.timezone.utc).isoformat(),
            "repository_root": str(self.repo),
            "repository_url": self._repository_url(),
            "git_head": self._safe_git("rev-parse", "HEAD"),
            "normalization_version": NORMALIZATION_VERSION,
            "redaction_version": REDACTION_VERSION,
            "sources": {},
            "excluded_sources": [],
            "warnings": self.warnings,
        }
        manifest["sources"]["codex"] = self._collect_jsonl_source("codex", *self.codex_sessions())
        manifest["sources"]["claude"] = self._collect_jsonl_source("claude", *self.claude_sessions())
        manifest["sources"]["chatgpt"] = self._collect_chatgpt()
        manifest["excluded_sources"] = [
            {"path": "~/.codex/auth.json, ~/.codex/*.sqlite", "reason": "認証情報と内部DBは収集しない"},
            {"path": "~/.claude/sessions, ~/.claude/file-history, ~/.claude/projects/*/memory",
             "reason": "セッション鍵・編集前ファイルのバックアップ・memoryは会話記録ではない"},
        ]
        if not self.dry_run:
            self._write_layout()
            (self.output / "manifest.json").write_text(
                json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
            )
        return manifest

    def _safe_git(self, *arguments: str) -> str | None:
        try:
            return self._git(*arguments)
        except (subprocess.CalledProcessError, FileNotFoundError):
            return None

    def _collect_jsonl_source(
        self, source: str, locations: list[str], records: list[SessionRecord]
    ) -> dict[str, Any]:
        sessions = []
        others = []
        for record in records:
            summary = {
                "session_id": record.session_id,
                "status": record.status,
                "reason": record.reason,
                "kind": record.kind,
                "cwd": record.cwd,
                "repository": record.repository,
                "source_path": str(record.source_path),
            } | record.details
            if record.status != "selected":
                others.append(summary)
                continue
            relative = record.source_path.relative_to(Path(locations[0]).parent) \
                if source == "codex" else record.source_path.relative_to(Path(locations[0]))
            entry = summary | self.snapshot(record, relative)
            previous = self._previous_entry(source, record.session_id)
            if entry["raw_updated"] or previous is None or \
                    previous.get("normalization_version") != NORMALIZATION_VERSION:
                rows = self.codex_rows(record, entry["raw_file"]) if source == "codex" \
                    else self.claude_rows(record, entry["raw_file"])
                path, count, redactions = self.write_normalized(source, record.session_id, rows)
                entry |= {"normalized_file": path, "normalized_rows": count,
                          "normalized_redactions": redactions}
            else:
                entry |= {key: previous[key] for key in
                          ("normalized_file", "normalized_rows", "normalized_redactions")
                          if key in previous}
            entry["normalization_version"] = NORMALIZATION_VERSION
            sessions.append(entry)
            log(f"[{source}] {record.session_id} {record.reason} "
                f"{'updated' if entry['raw_updated'] else 'unchanged'}", verbose=self.verbose)
            if record.source == "claude" and record.source_path.stat().st_mtime > \
                    dt.datetime.now().timestamp() - 600:
                self.warnings.append(
                    f"claude {record.session_id} は収集中も更新されているため途中までのsnapshot"
                )
        return {
            "detected": bool(locations),
            "source_locations": locations,
            "sessions_found": len(records),
            "sessions_selected": len(sessions),
            "sessions": sessions,
            "not_selected": others,
        }

    def _collect_chatgpt(self) -> dict[str, Any]:
        exports = self.chatgpt_exports()
        if not exports:
            self.warnings.append("ChatGPT export: missing")
            return {"export_found": False, "export_date": None,
                    "conversations_found": 0, "conversations_selected": 0,
                    "searched_locations": [str(path) for path in
                                           (self.arguments.chatgpt_export or [Path.home() / "Downloads"])]}
        export = exports[-1]
        conversations = self.chatgpt_conversations(export)
        selected = []
        others = []
        for conversation in conversations:
            status, reason = self.classify_chatgpt(conversation)
            identifier = conversation.get("conversation_id") or conversation.get("id") or "unknown"
            summary = {"conversation_id": identifier, "title": conversation.get("title"),
                       "status": status, "reason": reason}
            if status != "selected":
                others.append(summary)
                continue
            raw_path = self.output / "raw" / "chatgpt" / f"{identifier}.json"
            redacted, redactions = redact_value(conversation)
            rows = [
                {
                    "source": "chatgpt", "session_id": identifier,
                    "timestamp": dt.datetime.fromtimestamp(message["create_time"], dt.timezone.utc).isoformat()
                    if message.get("create_time") else None,
                    "cwd": None, "repository": None,
                    "role": (message.get("author") or {}).get("role"),
                    "kind": "message", "text": message["text"],
                    "source_raw_file": str(raw_path.relative_to(self.output)),
                }
                for message in self.chatgpt_messages(conversation)
            ]
            if not self.dry_run:
                raw_path.parent.mkdir(parents=True, exist_ok=True)
                raw_path.write_text(json.dumps(redacted, ensure_ascii=False, indent=1), encoding="utf-8")
            path, count, normalized_redactions = self.write_normalized("chatgpt", identifier, rows)
            selected.append(summary | {"raw_file": str(raw_path.relative_to(self.output)),
                                       "redactions": redactions, "normalized_file": path,
                                       "normalized_rows": count,
                                       "normalized_redactions": normalized_redactions})
        return {
            "export_found": True,
            "export_path": str(export),
            "export_date": dt.datetime.fromtimestamp(export.stat().st_mtime, dt.timezone.utc).isoformat(),
            "conversations_found": len(conversations),
            "conversations_selected": len(selected),
            "conversations": selected,
            "not_selected": others,
        }

    def _write_layout(self) -> None:
        for directory in [
            "raw/chatgpt", "raw/codex", "raw/claude",
            "normalized/chatgpt", "normalized/codex", "normalized/claude",
            "audit/codex", "audit/claude", "audit/chatgpt", "tools",
        ]:
            (self.output / directory).mkdir(parents=True, exist_ok=True)
        readme = self.output / "README.md"
        readme.write_text(README, encoding="utf-8")


README = """# myim Research Bundle

`Scripts/collect-research.py`が生成する開発史監査用の資料
元ログのコピーと正規化データだけを置き、分析結果は`audit/`へ置く

## 構成

- `raw/codex/` Codexのsession JSONLのsnapshot（`~/.codex/sessions`と同じ日付階層）
- `raw/claude/` Claude Codeのsession JSONLのsnapshot（`~/.claude/projects`と同じ階層）
- `raw/chatgpt/` ChatGPT Data Exportから抽出したmyim関連会話
- `normalized/<source>/<session>.jsonl` 1 sessionにつき1ファイルの共通形式
- `audit/<source>/` 後続の分析結果の置き場所
- `manifest.json` 収集元、判定理由、件数、hash、警告

## normalizedの形式

1行1イベントのJSON

- `source` `session_id` `thread_id`（Codexのみ） `timestamp` `cwd` `repository`
- `role` `kind`（message / context / tool_call / tool_result / reasoning_summary / reasoning / session_start / task_complete など）
- `text` 本文（tool出力は先頭と末尾だけ残し、`tool.truncated`で示す）
- `commit_shas` 本文中に現れたmyimのcommit（リポジトリに存在するものだけ）
- `source_raw_file` `source_line` 一次資料の位置

秘密情報の形式に一致した値は`[REDACTED_SECRET]`へ置換している

## 再実行

```sh
python3 Scripts/collect-research.py            # 収集と更新
python3 Scripts/collect-research.py --dry-run  # 書き込まずに判定だけ確認
python3 Scripts/collect-research.py --verbose  # sessionごとの処理を表示
```

元ログが変わっていないsessionはコピーし直さない
新しいsessionや更新されたsessionだけ追加・更新する

## ChatGPT

ChatGPTの設定 → データコントロール → データをエクスポート で届いたZIPを`~/Downloads`へ保存し、collectorを再実行すると追加される
別の場所にある場合は`--chatgpt-export <ZIPまたは展開したフォルダ>`で指定する
"""


def parse_arguments(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    repository = Path(__file__).resolve().parents[1]
    parser.add_argument("--repo", type=Path, default=repository)
    parser.add_argument("--output", type=Path, default=repository / ".research")
    parser.add_argument("--codex-home", type=Path)
    parser.add_argument("--claude-home", type=Path)
    parser.add_argument("--chatgpt-export", type=Path, action="append",
                        help="ChatGPT export ZIPまたはその探索フォルダ（既定は~/Downloads）")
    parser.add_argument("--alias-cwd", action="append",
                        help="myimとして扱う旧作業ディレクトリ（例: 改名前のパス）")
    parser.add_argument("--include-session", action="append",
                        help="未分類と判定されたsessionを収集対象に加える（manifestのsession_id）")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--verbose", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    arguments = parse_arguments(argv)
    manifest = Collector(arguments).run()
    for source, info in manifest["sources"].items():
        if source == "chatgpt":
            print(f"chatgpt: export_found={info['export_found']} "
                  f"selected={info['conversations_selected']}/{info['conversations_found']}")
        else:
            unclassified = sum(1 for item in info["not_selected"] if item["status"] == "unclassified")
            print(f"{source}: selected={info['sessions_selected']}/{info['sessions_found']} "
                  f"unclassified={unclassified}")
    for warning in manifest["warnings"]:
        print(f"warning: {warning}")
    if arguments.dry_run:
        print("dry-run: 書き込みなし")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
