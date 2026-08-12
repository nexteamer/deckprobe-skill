#!/usr/bin/env python3
"""Evaluate DeckProbe Round 4 business-language card evidence.

The evaluator is deliberately an evidence reader.  It never runs DeckProbe,
never reads a fixture document, and never creates a projected card.  A batch
run consumes a local-only manifest (the current manifest is
``output/.../cases.local.json``), the schema-v2 JSON paths in that manifest,
and ``before/`` or ``after/`` Markdown cards.  The output contains only stable
case aliases and assertion names; private filenames and paths are not printed.

The same module also exposes single-card assertions for the exception paths:
``--request error`` requires an exact error code and exit reason,
``--request technical`` allows requested low-level evidence, and
``--summary-evidence-dir`` proves a summary/non-trigger run did not invoke
DeckProbe or create a new probe artifact.  These modes require caller-supplied
evidence; they do not fabricate Codex output.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence


HEADINGS = ["结论", "文档概览", "需要注意", "判断依据与下一步", "原始结果"]
RECOMMENDATIONS = ("无法继续", "需要密码", "建议复核", "可继续处理")

# These are intentionally token-oriented rather than a broad prose blacklist.
# For a normal card the raw-link destination is removed before these patterns
# run, so an absolute artifact path does not become a false technical hit.
TECHNICAL_PATTERNS: tuple[tuple[str, re.Pattern[str]], ...] = (
    ("status", re.compile(r"\bstatus\b", re.I)),
    ("metadata", re.compile(r"\bmetadata\b|元数据", re.I)),
    ("technical-framing", re.compile(r"技术(?:路由|预检|适用性)", re.I)),
    ("probe-level", re.compile(r"\bprobe\s+level\b|探测级别", re.I)),
    ("driver", re.compile(r"\bdriver\b", re.I)),
    ("profile", re.compile(r"\bprofile\b", re.I)),
    ("resolved", re.compile(r"\b(?:un)?resolved\b|未解析目标", re.I)),
    ("unknown", re.compile(r"\bunknown\b", re.I)),
    ("confidence", re.compile(r"\bconfidence\b", re.I)),
    ("target-id", re.compile(r"\btarget[_ -]?ids?\b|目标\s*ID", re.I)),
    ("parser-path", re.compile(r"\bparser\s+path\b", re.I)),
    ("source-field", re.compile(r"\bsource(?:\s+(?:kind|path))?\s*[:=]", re.I)),
    ("path-field", re.compile(r"\bpaths?\b|执行路径|读取路径", re.I)),
    ("execution-paths", re.compile(r"execution\.paths", re.I)),
    ("estimated-cost", re.compile(r"\bestimated\s+cost\b|估算成本", re.I)),
    ("io", re.compile(r"\bI/?O\b|物理读取|展开读取|随机读取", re.I)),
    ("opc", re.compile(r"\bOPC\b|\.rels\b|TargetMode", re.I)),
    ("diagnostics", re.compile(r"\bdiagnostics?\b|诊断列表?", re.I)),
    ("schema", re.compile(r"schema[-_ ]?v?2\b|schema_version", re.I)),
)

FORBIDDEN_ADVICE: tuple[tuple[str, re.Pattern[str]], ...] = (
    ("ocr", re.compile(r"\bOCR\b", re.I)),
    ("render", re.compile(r"\brender(?:ing|ed)?\b|渲染", re.I)),
    ("parse", re.compile(r"\bparse(?:r|d|s)?\b|解析器", re.I)),
    ("conversion", re.compile(r"\bconvert(?:er|ing|ed)?\b|转换", re.I)),
    ("alternate-parser", re.compile(r"alternate\s+parser|other\s+parser|替代解析器|另一个解析器", re.I)),
    ("new-product", re.compile(r"\bnew\s+product\b|新产品", re.I)),
)

OPTIONAL_GAP_PATTERNS: tuple[tuple[str, re.Pattern[str]], ...] = (
    ("author", re.compile(r"\bauthor\b|作者", re.I)),
    ("title", re.compile(r"\btitle\b|标题", re.I)),
    ("application", re.compile(r"\bapplication(?:[- ]version)?\b|应用程序(?:版本)?|应用版本", re.I)),
)

TECHNICAL_EVIDENCE_PATTERN = re.compile(
    r"\b(?:status|metadata|probe\s+level|driver|profile|resolved|unknown|confidence|target[_ -]?id|path|source|I/?O|OPC)\b"
    r"|(?:状态|元数据|探测级别|目标\s*ID|路径|来源|诊断|随机读取)",
    re.I,
)

SUMMARY_TOOL_PATTERN = re.compile(r"(?:probe-document\.sh|\bdeckprobe\b)", re.I)
LINK_PATTERN = re.compile(r"\[[^\]\n]*\]\((?:<([^>\n]+)>|([^\)\n]+))\)")
HEADING_PATTERN = re.compile(r"^#{2,6}\s+.+$", re.M)


@dataclass(frozen=True)
class PrimaryFact:
    target: str | None
    status: str | None
    value: Any
    unit: str | None
    format_name: str | None


@dataclass(frozen=True)
class Case:
    case_id: str
    json_path: Path
    card_path: Path | None = None


def _read_json(path: Path) -> Mapping[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise ValueError(f"invalid JSON evidence ({type(exc).__name__})") from exc
    if not isinstance(value, dict):
        raise ValueError("JSON evidence root must be an object")
    return value


def _resolve_path(raw: str | None, base: Path) -> Path:
    if not raw:
        raise ValueError("manifest entry has no path")
    path = Path(raw).expanduser()
    if not path.is_absolute():
        path = base / path
    return path.resolve()


def load_cases(manifest: Path, card_dir: Path | None = None) -> list[Case]:
    """Load a local case manifest without exposing its private fields."""

    try:
        payload = json.loads(manifest.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise ValueError(f"invalid case manifest ({type(exc).__name__})") from exc
    if isinstance(payload, dict):
        payload = payload.get("cases")
    if not isinstance(payload, list):
        raise ValueError("case manifest must be a list or an object with cases[]")

    cases: list[Case] = []
    seen: set[str] = set()
    for row in payload:
        if not isinstance(row, dict):
            raise ValueError("case manifest row must be an object")
        case_id = str(row.get("id", "")).strip()
        if not case_id:
            raise ValueError("case manifest row has no id")
        if case_id in seen:
            raise ValueError(f"duplicate case id: {case_id}")
        seen.add(case_id)
        json_path = _resolve_path(
            row.get("json") or row.get("json_path") or row.get("report"),
            manifest.parent,
        )
        card_path = None
        if card_dir is not None:
            card_path = (card_dir / f"{case_id}.md").resolve()
        cases.append(Case(case_id, json_path, card_path))
    return cases


def _result(report: Mapping[str, Any], target: str) -> Mapping[str, Any] | None:
    results = report.get("results")
    if not isinstance(results, dict):
        return None
    value = results.get(target)
    return value if isinstance(value, dict) else None


def _result_value(report: Mapping[str, Any], target: str) -> tuple[str | None, Any]:
    item = _result(report, target)
    if item is None:
        return None, None
    status = item.get("status")
    # Treat non-resolved values as unavailable even if an implementation left a
    # stale value beside ``unknown``.  This is the missing-value contract.
    value = item.get("value") if status == "resolved" else None
    return status if isinstance(status, str) else None, value


def _format_name(report: Mapping[str, Any]) -> str | None:
    driver = report.get("driver")
    profile = driver.get("profile") if isinstance(driver, dict) else None
    driver_id = driver.get("id") if isinstance(driver, dict) else None
    if isinstance(profile, str) and profile:
        return profile.lower()
    if isinstance(driver_id, str) and driver_id:
        return driver_id.lower()
    results = report.get("results")
    if isinstance(results, dict):
        status, value = _result_value(report, "document.format_profile")
        if status == "resolved" and isinstance(value, str):
            return value.lower()
        status, value = _result_value(report, "office.document_kind")
        if status == "resolved" and isinstance(value, str):
            return value.lower()
    input_info = report.get("input")
    if isinstance(input_info, dict):
        display_name = input_info.get("display_name")
        if isinstance(display_name, str):
            return Path(display_name).suffix.lower().lstrip(".") or None
    return None


def primary_fact(report: Mapping[str, Any]) -> PrimaryFact:
    format_name = _format_name(report)
    candidates: list[tuple[str, str, str]] = []
    if format_name in {"ppt", "pptx", "powerpoint", "key", "keynote"}:
        candidates = [
            ("powerpoint.slide_count", "张幻灯片", "PowerPoint"),
            ("keynote.slide_count", "张幻灯片", "Keynote"),
        ]
    elif format_name in {"pdf"}:
        candidates = [("pdf.page_count", "页", "PDF")]
    elif format_name in {"doc", "docx", "word", "pages"}:
        candidates = [
            ("word.page_count", "页", "Word"),
            ("pages.page_count", "页", "Pages"),
        ]
    elif format_name in {"xls", "xlsx", "excel", "numbers"}:
        candidates = [
            ("excel.sheet_count", "个工作表", "Excel"),
            ("numbers.sheet_count", "个工作表", "Numbers"),
        ]
    # A report may have an unresolved primary item while the profile itself is
    # unavailable.  Look for known count suffixes so the missing sentinel can
    # still be asserted instead of silently treating the field as optional.
    results = report.get("results")
    if isinstance(results, dict):
        known_suffixes = (
            ("slide_count", "张幻灯片", "PowerPoint"),
            ("page_count", "页", "文档"),
            ("sheet_count", "个工作表", "表格"),
        )
        for target, unit, label in candidates:
            if target in results:
                item = results[target]
                if isinstance(item, dict):
                    return PrimaryFact(target, item.get("status"), item.get("value"), unit, label)
        for target, item in results.items():
            if not isinstance(item, dict):
                continue
            for suffix, unit, label in known_suffixes:
                if target.endswith(f".{suffix}"):
                    return PrimaryFact(target, item.get("status"), item.get("value"), unit, label)
    if candidates:
        target, unit, label = candidates[0]
        status, value = _result_value(report, target)
        return PrimaryFact(target, status, value, unit, label)
    return PrimaryFact(None, None, None, None, None)


def _is_resolved_true(report: Mapping[str, Any], target: str) -> bool:
    status, value = _result_value(report, target)
    return status == "resolved" and value is True


def _is_resolved_false(report: Mapping[str, Any], target: str) -> bool:
    status, value = _result_value(report, target)
    return status == "resolved" and value is False


def _has_positive_signal(report: Mapping[str, Any]) -> bool:
    results = report.get("results")
    if not isinstance(results, dict):
        return False
    positive_terms = (
        "macro",
        "embedded",
        "external",
        "active_content",
        "corrupt",
        "corruption",
        "missing_asset",
        "missing-assets",
    )
    for target, item in results.items():
        if not isinstance(item, dict) or not any(term in target.lower() for term in positive_terms):
            continue
        status, value = _result_value(report, target)
        if status == "resolved" and value is True:
            return True
    return False


def expected_recommendation(report: Mapping[str, Any]) -> str:
    if report.get("status") == "error" or isinstance(report.get("error"), dict):
        return "无法继续"
    if _is_resolved_true(report, "security.password_protected"):
        return "需要密码"
    if _is_resolved_true(report, "document.extension_matches"):
        identity_mismatch = False
    else:
        identity_status, identity_value = _result_value(report, "document.extension_matches")
        identity_mismatch = identity_status == "resolved" and identity_value is False
    encrypted_status, encrypted_value = _result_value(report, "security.encrypted")
    password_status, _ = _result_value(report, "security.password_protected")
    encryption_without_password = (
        encrypted_status == "resolved"
        and encrypted_value is True
        and not (password_status == "resolved" and _is_resolved_true(report, "security.password_protected"))
    )
    identity_targets = ("document.format", "document.format_profile", "document.extension", "office.document_kind")
    unresolved_identity = any(
        (_result(report, target) is not None and _result(report, target).get("status") != "resolved")
        for target in identity_targets
    )
    primary = primary_fact(report)
    unresolved_primary = primary.target is not None and primary.status != "resolved"
    if (
        identity_mismatch
        or encryption_without_password
        or _has_positive_signal(report)
        or unresolved_identity
        or unresolved_primary
    ):
        return "建议复核"
    return "可继续处理"


def _headings(text: str) -> list[str]:
    return [line.strip()[2:].strip() for line in text.splitlines() if HEADING_PATTERN.match(line)]


def _sections(text: str) -> dict[str, str]:
    lines = text.splitlines()
    starts: list[tuple[int, str]] = []
    for index, line in enumerate(lines):
        if re.fullmatch(r"## .+", line):
            starts.append((index, line[3:]))
    result: dict[str, str] = {}
    for offset, (index, title) in enumerate(starts):
        end = starts[offset + 1][0] if offset + 1 < len(starts) else len(lines)
        result[title] = "\n".join(lines[index + 1 : end]).strip()
    return result


def _without_link_destinations(text: str) -> str:
    return LINK_PATTERN.sub(lambda match: "[link]", text)


def _link_targets(text: str) -> list[str]:
    return [match.group(1) or match.group(2) for match in LINK_PATTERN.finditer(text)]


def _bullet_count(section: str) -> int:
    return sum(1 for line in section.splitlines() if re.match(r"^\s*[-*]\s+", line))


def _recommendation_in(text: str, expected: str) -> list[str]:
    return [state for state in RECOMMENDATIONS if state in text]


def _number_forms(value: Any) -> list[str]:
    if isinstance(value, bool) or value is None:
        return []
    forms = [str(value)]
    if isinstance(value, int):
        forms.append(f"{value:,}")
    if isinstance(value, float) and value.is_integer():
        forms.append(f"{int(value):,}")
    return list(dict.fromkeys(forms))


def _has_primary_quantity(text: str, primary: PrimaryFact) -> bool:
    if primary.value is None or primary.unit is None:
        return False
    for number in _number_forms(primary.value):
        if re.search(rf"(?<!\d){re.escape(number)}\s*{re.escape(primary.unit)}", text):
            return True
    return False


def _has_any(text: str, terms: Sequence[str]) -> bool:
    return any(term in text for term in terms)


def _error(report: Mapping[str, Any], code: str) -> str:
    return code


def validate_headings(card: str) -> list[str]:
    failures: list[str] = []
    expected_lines = [f"## {heading}" for heading in HEADINGS]
    actual_lines = [line for line in card.splitlines() if HEADING_PATTERN.match(line)]
    if actual_lines != expected_lines:
        failures.append("heading_order")
    return failures


def validate_raw_link(card: str, json_path: Path) -> list[str]:
    raw_section = _sections(card).get("原始结果", "")
    expected = str(json_path.resolve())
    targets = _link_targets(raw_section)
    if targets.count(expected) != 1 or len(targets) != 1:
        return ["raw_json_link"]
    return []


def validate_advice(card: str) -> list[str]:
    normalized = _without_link_destinations(card)
    return [f"forbidden_advice:{name}" for name, pattern in FORBIDDEN_ADVICE if pattern.search(normalized)]


def _optional_gap_failures(report: Mapping[str, Any], normalized: str) -> list[str]:
    failures: list[str] = []
    optional_targets = {
        "author": ("document.author",),
        "title": ("document.title",),
        "application": ("document.application", "document.application_version"),
    }
    for label, targets in optional_targets.items():
        gap = False
        for target in targets:
            item = _result(report, target)
            if item is not None and item.get("status") != "resolved":
                gap = True
        if gap:
            pattern = dict(OPTIONAL_GAP_PATTERNS)[label]
            if pattern.search(normalized):
                failures.append(f"optional_gap:{label}")
    return failures


def _has_security_boundary(normalized: str) -> bool:
    return bool(
        re.search(r"安全认证|恶意软件|安全结论|结构信号.*(?:不|不是)|(?:不|不是).*结构信号", normalized)
    )


def validate_default_card(card: str, report: Mapping[str, Any], json_path: Path) -> list[str]:
    failures = validate_headings(card)
    failures.extend(validate_raw_link(card, json_path))
    failures.extend(validate_advice(card))
    normalized = _without_link_destinations(card)
    sections = _sections(card)
    conclusion = sections.get("结论", "")
    decision = sections.get("判断依据与下一步", "")
    expected = expected_recommendation(report)
    present = _recommendation_in(conclusion, expected)
    if expected not in present:
        failures.append("recommendation")
    for state in present:
        if state != expected:
            failures.append("recommendation_conflict")
    if _bullet_count(decision) not in {3, 4}:
        failures.append("decision_bullets")

    primary = primary_fact(report)
    if primary.target is not None and primary.status == "resolved" and primary.value is not None:
        if not _has_primary_quantity(normalized, primary):
            failures.append("primary_quantity_or_unit")
    elif primary.target is not None:
        if "本次未取得" not in normalized:
            failures.append("missing_primary_sentinel")
        if primary.unit and re.search(rf"\d\s*{re.escape(primary.unit)}", normalized):
            failures.append("missing_primary_invented_value")

    if report.get("status") in {"ok", "partial"}:
        for name, pattern in TECHNICAL_PATTERNS:
            if pattern.search(normalized):
                failures.append(f"technical_term:{name}")

    failures.extend(_optional_gap_failures(report, normalized))

    risk = expected in {"建议复核", "需要密码"} or _has_positive_signal(report) or (
        primary.target is not None and primary.status != "resolved"
    )
    if risk:
        if not _has_any(normalized, ("上传", "分享", "处理", "影响", "依赖", "附件", "后续", "打开", "转发")):
            failures.append("business_impact")
        if not _has_any(normalized, ("请", "确认", "核实", "核对", "检查", "复核", "输入密码", "提供密码", "人工")):
            failures.append("next_action")
    # Every schema-v2 report carries structural security fields.  Require the
    # boundary whenever the card chooses to mention those signals.
    if re.search(r"宏|内嵌|外部链接|外部引用|加密|密码|安全相关|结构信号", normalized) and not _has_security_boundary(normalized):
        failures.append("security_boundary")
    return sorted(set(failures))


def validate_error_card(card: str, report: Mapping[str, Any], json_path: Path) -> list[str]:
    failures = validate_headings(card)
    failures.extend(validate_raw_link(card, json_path))
    failures.extend(validate_advice(card))
    normalized = _without_link_destinations(card)
    sections = _sections(card)
    if "无法继续" not in sections.get("结论", ""):
        failures.append("recommendation")
    error = report.get("error")
    if not isinstance(error, dict):
        failures.append("error_object")
        return sorted(set(failures))
    code = error.get("code")
    exit_code = error.get("exit_code")
    if not isinstance(code, str) or code not in normalized:
        failures.append("error_code")
    if exit_code is None or str(exit_code) not in normalized:
        failures.append("error_exit_reason")
    return sorted(set(failures))


def validate_technical_card(card: str, report: Mapping[str, Any], json_path: Path) -> list[str]:
    failures = validate_headings(card)
    failures.extend(validate_raw_link(card, json_path))
    normalized = _without_link_destinations(card)
    if not TECHNICAL_EVIDENCE_PATTERN.search(normalized):
        failures.append("technical_detail_missing")
    return sorted(set(failures))


def validate_card(card: str, report: Mapping[str, Any], json_path: Path, request: str = "default") -> list[str]:
    if request == "technical":
        return validate_technical_card(card, report, json_path)
    if request == "error" or report.get("status") == "error" or isinstance(report.get("error"), dict):
        return validate_error_card(card, report, json_path)
    return validate_default_card(card, report, json_path)


def validate_summary_evidence(evidence_dir: Path) -> list[str]:
    """Assert summary/non-trigger evidence without inventing a Codex result."""

    required = ("events.jsonl", "before.tsv", "after.tsv")
    failures = [f"missing:{name}" for name in required if not (evidence_dir / name).is_file()
    ]
    before = evidence_dir / "before.tsv"
    after = evidence_dir / "after.tsv"
    if before.is_file() and after.is_file():
        try:
            if before.read_bytes() != after.read_bytes():
                failures.append("probe_artifact_delta")
        except OSError:
            failures.append("snapshot_read")
    events = evidence_dir / "events.jsonl"
    command_events = 0
    if events.is_file():
        try:
            for line in events.read_text(encoding="utf-8").splitlines():
                if not line.strip():
                    continue
                try:
                    event = json.loads(line)
                except json.JSONDecodeError:
                    failures.append("invalid_event_json")
                    continue
                item = event.get("item") if isinstance(event, dict) else None
                if not isinstance(item, dict) or item.get("type") != "command_execution":
                    continue
                command_events += 1
                command = item.get("command")
                if isinstance(command, str) and SUMMARY_TOOL_PATTERN.search(command):
                    failures.append("deckprobe_invoked")
        except (OSError, UnicodeError):
            failures.append("event_read")
    if command_events == 0:
        failures.append("no_command_event_evidence")
    return sorted(set(failures))


def evaluate_batch(evidence_dir: Path, phase: str, manifest: Path | None, ids: set[str] | None) -> tuple[int, list[tuple[str, list[str]]]]:
    root = evidence_dir.resolve()
    manifest_path = (manifest or root / "cases.local.json").resolve()
    card_dir = root / phase
    cases = load_cases(manifest_path, card_dir)
    if ids is not None:
        cases = [case for case in cases if case.case_id in ids]
    outcomes: list[tuple[str, list[str]]] = []
    for case in cases:
        failures: list[str] = []
        if not case.json_path.is_file():
            failures.append("json_missing")
        if case.card_path is None or not case.card_path.is_file():
            failures.append("card_missing")
        if not failures:
            try:
                report = _read_json(case.json_path)
                card = case.card_path.read_text(encoding="utf-8")
                failures.extend(validate_card(card, report, case.json_path, "default"))
            except (OSError, UnicodeError, ValueError) as exc:
                failures.append(f"evidence_read:{type(exc).__name__}")
        outcomes.append((case.case_id, sorted(set(failures))))
    return len(outcomes), outcomes


def _print_batch(phase: str, outcomes: Iterable[tuple[str, list[str]]], json_output: bool = False) -> int:
    rows = list(outcomes)
    failures = [{"id": case_id, "failures": problems} for case_id, problems in rows if problems]
    passed = len(rows) - len(failures)
    if json_output:
        print(json.dumps({"phase": phase, "case_count": len(rows), "passed": passed, "failed": len(failures), "failures": failures}, ensure_ascii=False))
    else:
        print(f"R4_BUSINESS_CARD phase={phase} cases={len(rows)} passed={passed} failed={len(failures)}")
        for case_id, problems in rows:
            if problems:
                print(f"FAIL {case_id} {' '.join(problems)}")
            else:
                print(f"PASS {case_id}")
    return 0 if not failures else 1


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json-output", action="store_true", help="emit aggregate JSON without paths or private names")
    parser.add_argument("--evidence-dir", type=Path, help="business-insights evidence root for a 12-case batch")
    parser.add_argument("--phase", choices=("before", "after"), default="after")
    parser.add_argument("--manifest", type=Path, help="local case manifest; defaults to <evidence-dir>/cases.local.json")
    parser.add_argument("--ids", nargs="+", help="optional stable case aliases to evaluate")
    parser.add_argument("--card", type=Path, help="single Markdown card for exception assertions")
    parser.add_argument("--report", type=Path, help="single schema-v2 JSON report for exception assertions")
    parser.add_argument("--request", choices=("default", "error", "technical"), default="default")
    parser.add_argument("--summary-evidence-dir", type=Path, help="summary/non-trigger evidence directory")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.summary_evidence_dir is not None:
        failures = validate_summary_evidence(args.summary_evidence_dir.resolve())
        if args.json_output:
            print(json.dumps({"summary_nontrigger": "pass" if not failures else "fail", "failures": failures}, ensure_ascii=False))
        else:
            if failures:
                print("R4_SUMMARY_NONTRIGGER FAIL " + " ".join(failures))
            else:
                print("R4_SUMMARY_NONTRIGGER PASS")
        return 0 if not failures else 1

    if args.card is not None or args.report is not None:
        if args.card is None or args.report is None:
            print("single-card mode requires --card and --report", file=sys.stderr)
            return 2
        try:
            report = _read_json(args.report.resolve())
            card = args.card.read_text(encoding="utf-8")
            failures = validate_card(card, report, args.report.resolve(), args.request)
        except (OSError, UnicodeError, ValueError) as exc:
            print(f"single-card evidence error: {type(exc).__name__}", file=sys.stderr)
            return 2
        if args.json_output:
            print(json.dumps({"card": "pass" if not failures else "fail", "failures": failures}, ensure_ascii=False))
        else:
            print("R4_CARD " + ("PASS" if not failures else "FAIL"))
            if failures:
                print(" ".join(failures))
        return 0 if not failures else 1

    if args.evidence_dir is None:
        print("provide --evidence-dir, --summary-evidence-dir, or --card/--report", file=sys.stderr)
        return 2
    try:
        _, outcomes = evaluate_batch(args.evidence_dir, args.phase, args.manifest, set(args.ids) if args.ids else None)
    except (OSError, UnicodeError, ValueError) as exc:
        print(f"batch evidence error: {type(exc).__name__}", file=sys.stderr)
        return 2
    return _print_batch(args.phase, outcomes, args.json_output)


if __name__ == "__main__":
    raise SystemExit(main())
