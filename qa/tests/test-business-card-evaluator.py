#!/usr/bin/env python3
"""Focused unit checks for the Round 4 card evaluator.

These tests use redacted, synthetic schema-v2 objects only.  Real U01-U12
evidence is exercised by the evaluator commands documented in qa/scripts/README.md.
"""

from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "qa" / "scripts" / "evaluate-business-card.py"
SPEC = importlib.util.spec_from_file_location("r4_evaluator", SCRIPT)
assert SPEC and SPEC.loader
evaluator = importlib.util.module_from_spec(SPEC)
sys.modules["r4_evaluator"] = evaluator
SPEC.loader.exec_module(evaluator)


def report(*, status: str = "partial", primary_status: str = "resolved", primary_value: object = 2, **overrides: object) -> dict:
    values = {
        "document.extension": {"status": "resolved", "value": "pptx"},
        "document.extension_matches": {"status": "resolved", "value": True},
        "document.format": {"status": "resolved", "value": "office-open-xml"},
        "document.format_profile": {"status": "resolved", "value": "pptx"},
        "office.document_kind": {"status": "resolved", "value": "powerpoint"},
        "powerpoint.slide_count": {"status": primary_status, "value": primary_value},
        "document.author": {"status": "unknown"},
        "document.title": {"status": "unknown"},
        "document.application": {"status": "unknown"},
        "security.encrypted": {"status": "resolved", "value": False},
        "security.password_protected": {"status": "resolved", "value": False},
        "security.has_macros": {"status": "resolved", "value": False},
        "security.has_embedded_files": {"status": "resolved", "value": False},
        "security.has_external_relationships": {"status": "resolved", "value": False},
    }
    values.update(overrides)
    return {
        "schema_version": 2,
        "status": status,
        "driver": {"id": "powerpoint", "profile": "pptx"},
        "input": {"display_name": "sample.pptx"},
        "results": values,
    }


def card(path: Path, conclusion: str, overview: str, attention: str, bullets: list[str], raw: str | None = None) -> str:
    raw = raw or str(path)
    return "\n".join(
        [
            "## 结论",
            conclusion,
            "## 文档概览",
            overview,
            "## 需要注意",
            attention,
            "## 判断依据与下一步",
            *[f"- {line}" for line in bullets],
            "## 原始结果",
            f"[查看原始 JSON 报告]({raw})",
            "",
        ]
    )


class EvaluatorTests(unittest.TestCase):
    def test_four_recommendations_are_distinct_and_supported(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            path = root / "report.json"
            common = [
                "格式和关键数量已取得，未发现需要复核的结构信号。",
                "当前结果不会阻止上传、分享或后续处理。",
                "请按既有流程继续处理。",
            ]
            cases = [
                (report(), "可继续处理", card(path, "可继续处理。", "PowerPoint，共 2 张幻灯片。", "结构信号正常；不是安全认证或恶意软件结论。", common)),
                (report(**{"security.has_external_relationships": {"status": "resolved", "value": True}}), "建议复核", card(path, "建议复核。", "PowerPoint，共 2 张幻灯片。", "存在外部链接，可能影响分享；不是安全认证或恶意软件结论。", ["检测到外部链接。", "可能影响上传或分享。", "请核对目标后再处理。"])),
                (report(**{"security.password_protected": {"status": "resolved", "value": True}}), "需要密码", card(path, "需要密码。", "PowerPoint，共 2 张幻灯片。", "文件受密码保护；不是安全认证或恶意软件结论。", ["需要密码才能继续。", "上传和处理会被阻止。", "请提供密码后再处理。"])),
            ]
            for current, expected, text in cases:
                self.assertEqual(evaluator.expected_recommendation(current), expected)
                self.assertEqual(evaluator.validate_card(text, current, path), [])

            error = report(status="error")
            error["error"] = {"code": "MALFORMED_INPUT", "exit_code": 4, "message": "malformed input"}
            error_text = card(path, "无法继续。", "本次未取得。", "检查失败，请查看错误信息。", ["无法完成检查。", "后续处理暂不能继续。", "请修复输入后重试。"])
            error_text = error_text.replace("请查看错误信息。", "错误代码 MALFORMED_INPUT，退出原因 4。")
            self.assertEqual(evaluator.expected_recommendation(error), "无法继续")
            self.assertEqual(evaluator.validate_card(error_text, error, path), [])

    def test_missing_primary_requires_sentinel_and_business_action(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "report.json"
            missing = report(primary_status="unknown", primary_value=None)
            text = card(
                path,
                "建议复核。页数本次未取得。",
                "PowerPoint；幻灯片数量本次未取得。",
                "文件可识别，但关键数量本次未取得；不是安全认证或恶意软件结论。",
                ["关键数量本次未取得，因此建议复核。", "可能影响上传后的拆分或计量。", "请通过既有流程或人工方式确认后再处理。"],
            )
            self.assertEqual(evaluator.validate_card(text, missing, path), [])

    def test_technical_and_summary_exception_interfaces(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            path = root / "report.json"
            technical = card(
                path,
                "可继续处理。",
                "status=partial; driver/profile=pptx。",
                "resolved target evidence and execution.paths are available.",
                ["status=partial。", "target_id powerpoint.slide_count resolved。", "I/O path available."],
            )
            self.assertEqual(evaluator.validate_card(technical, report(), path, "technical"), [])
            (root / "events.jsonl").write_text(
                json.dumps({"item": {"type": "command_execution", "command": "printf summary"}}) + "\n",
                encoding="utf-8",
            )
            (root / "before.tsv").write_text("stable\n", encoding="utf-8")
            (root / "after.tsv").write_text("stable\n", encoding="utf-8")
            self.assertEqual(evaluator.validate_summary_evidence(root), [])


if __name__ == "__main__":
    unittest.main()
