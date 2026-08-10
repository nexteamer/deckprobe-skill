#!/usr/bin/env python3
"""Build a safe, deterministic manifest for the Round 3 local corpus.

The tracked manifest deliberately omits private fixture names, paths, sizes,
and hashes.  Private files are represented only by stable aliases.  Full
per-input identity belongs in the ignored run directory emitted by
run-corpus.sh.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import sys
from pathlib import Path


EXPECTED_PRIVATE_COUNT = 12
EXPECTED_PUBLIC_GENERATED_COUNT = 34
EXPECTED_TOTAL_COUNT = 46


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_public_sources(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as stream:
        rows = list(csv.DictReader(stream, delimiter="\t"))
    required = {"local_path", "repository", "commit", "license", "source_url"}
    if rows and set(rows[0]) != required:
        raise SystemExit(f"unexpected PUBLIC_SOURCES.tsv columns: {sorted(rows[0])}")
    return sorted(rows, key=lambda row: row["local_path"])


def build_rows(repo_root: Path, allow_missing_private: bool) -> list[dict[str, str]]:
    qa_root = repo_root / "qa"
    public_root = qa_root / "fixtures" / "public"
    generated_root = qa_root / "fixtures" / "generated"
    user_root = qa_root / "fixtures" / "user"

    source_rows = read_public_sources(qa_root / "PUBLIC_SOURCES.tsv")
    rows: list[dict[str, str]] = []
    for index, source in enumerate(source_rows, start=1):
        relative = source["local_path"]
        file_path = qa_root / relative
        if not file_path.is_file():
            raise SystemExit(f"public fixture is missing: {relative}")
        suffix = file_path.suffix.lower().lstrip(".") or "unknown"
        role = "security-password" if relative.endswith("password-sample-128bit.pdf") else "public"
        role = "security-macros" if relative.endswith("with-macros.ppt") else role
        rows.append(
            {
                "case_id": f"public-{index:03d}",
                "source_class": "public",
                "input_ref": relative,
                "format": suffix,
                "role": role,
                "source_ref": f"{source['repository']}@{source['commit']}",
                "expected_sha256": sha256(file_path),
            }
        )

    generated = sorted(
        path for path in generated_root.rglob("*") if path.is_file()
    )
    for index, file_path in enumerate(generated, start=1):
        relative = file_path.relative_to(qa_root).as_posix()
        suffix = file_path.suffix.lower().lstrip(".") or "unknown"
        rows.append(
            {
                "case_id": f"generated-{index:03d}",
                "source_class": "generated",
                "input_ref": relative,
                "format": suffix,
                "role": "boundary",
                "source_ref": "qa/generate-boundary-fixtures.mjs",
                "expected_sha256": sha256(file_path),
            }
        )

    private_files = sorted(
        path
        for path in user_root.rglob("*")
        if path.is_file() and path.name != "README.md"
    )
    if len(private_files) != EXPECTED_PRIVATE_COUNT and not allow_missing_private:
        raise SystemExit(
            "expected exactly "
            f"{EXPECTED_PRIVATE_COUNT} private fixtures, found {len(private_files)}; "
            "use --allow-missing-private only for a public/generated release checkout"
        )
    for index, _file_path in enumerate(private_files, start=1):
        # Do not derive or persist anything from the private filename.  The
        # local runner resolves this alias against the same sorted file list.
        rows.append(
            {
                "case_id": f"private-{index:03d}",
                "source_class": "private",
                "input_ref": f"private-{index:03d}",
                "format": "local",
                "role": "user-local",
                "source_ref": "local-only",
                "expected_sha256": "not-published",
            }
        )

    rows.sort(key=lambda row: (row["source_class"], row["case_id"]))
    public_generated_count = sum(
        row["source_class"] in {"public", "generated"} for row in rows
    )
    private_count = sum(row["source_class"] == "private" for row in rows)
    if public_generated_count != EXPECTED_PUBLIC_GENERATED_COUNT:
        raise SystemExit(
            f"expected {EXPECTED_PUBLIC_GENERATED_COUNT} public/generated fixtures, "
            f"found {public_generated_count}"
        )
    if not allow_missing_private and len(rows) != EXPECTED_TOTAL_COUNT:
        raise SystemExit(f"expected {EXPECTED_TOTAL_COUNT} total fixtures, found {len(rows)}")
    if private_count not in {0, EXPECTED_PRIVATE_COUNT}:
        raise SystemExit(f"unexpected private fixture count: {private_count}")
    return rows


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--repo-root",
        type=Path,
        default=Path(__file__).resolve().parents[2],
        help="DeckProbe Skill release repository root",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=None,
        help="safe manifest path (default: qa/CORPUS_MANIFEST.tsv)",
    )
    parser.add_argument(
        "--allow-missing-private",
        action="store_true",
        help="build a 34-case public/generated manifest in a clean checkout",
    )
    args = parser.parse_args()
    repo_root = args.repo_root.resolve()
    output = (args.output or repo_root / "qa" / "CORPUS_MANIFEST.tsv").resolve()

    rows = build_rows(repo_root, args.allow_missing_private)
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_name(f".{output.name}.tmp")
    fieldnames = [
        "case_id",
        "source_class",
        "input_ref",
        "format",
        "role",
        "source_ref",
        "expected_sha256",
    ]
    with temporary.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=fieldnames, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    temporary.replace(output)
    print(f"MANIFEST_OK\t{output}\t{len(rows)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
