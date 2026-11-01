#!/usr/bin/env python3
"""Inventory short or ambiguous UX messages and hard-coded feedback in Delta POS.

This is an advisory audit, not an automatic judge of translation quality.
Run alongside script/audit_i18n.py. Review findings in context before rewriting.
"""

from __future__ import annotations

import pathlib
import re
import sys

import yaml

LOCALES = ("es", "en", "ko")
LOCALE_DIR = pathlib.Path("config/locales")
FEEDBACK_KEYS = re.compile(
    r"(?:^|_)(?:error|failed|failure|success|saved|created|updated|deleted|"
    r"restored|empty|no_results|no_data|not_found|unavailable|processing|"
    r"load_error|save_error|invalid)$"
)
SHORT_LIMIT = {"es": 43, "en": 40, "ko": 19}
SOURCE_DIRS = ("app/controllers", "app/views", "app/javascript", "app/helpers", "app/services")
SOURCE_EXTS = {".rb", ".erb", ".js", ".ts"}
HARDCODED_FEEDBACK = (
    re.compile(r"\b(?:alert|confirm|prompt|Swal\.fire)\s*\(\s*['\x22\x60]"),
    re.compile(r"\bflash\s*\[\s*:[a-z_]+\s*\]\s*=\s*['\x22]"),
    re.compile(r"\b(?:notice|alert|swal_message):\s*['\x22]"),
)


def leaves(data, path=()):
    if isinstance(data, dict):
        for key, value in data.items():
            yield from leaves(value, path + (str(key),))
    elif isinstance(data, str):
        yield ".".join(path), data


def locale_messages():
    totals = {locale: 0 for locale in LOCALES}
    candidates = []
    file_count = 0
    for file in sorted(LOCALE_DIR.rglob("*")):
        if file.suffix not in (".yml", ".yaml"):
            continue
        file_count += 1
        data = yaml.safe_load(file.read_text(encoding="utf-8")) or {}
        if not isinstance(data, dict):
            continue
        for locale in LOCALES:
            root = data.get(locale)
            if not isinstance(root, dict):
                continue
            for path, value in leaves(root):
                tail = path.rsplit(".", 1)[-1]
                if not FEEDBACK_KEYS.search(tail):
                    continue
                totals[locale] += 1
                if not value.strip() or len(value.strip()) < SHORT_LIMIT[locale]:
                    candidates.append((locale, str(file), path, value.strip()))
    return file_count, totals, candidates


def hardcoded_feedback():
    findings = []
    for directory in SOURCE_DIRS:
        root = pathlib.Path(directory)
        if not root.exists():
            continue
        for file in root.rglob("*"):
            if not file.is_file() or file.suffix not in SOURCE_EXTS:
                continue
            for number, line in enumerate(file.read_text(encoding="utf-8").splitlines(), 1):
                if any(pattern.search(line) for pattern in HARDCODED_FEEDBACK):
                    findings.append((str(file), number, line.strip()[:160]))
    return findings


def main():
    count, totals, generic = locale_messages()
    literal = hardcoded_feedback()
    print(f"UX MESSAGE AUDIT: {count} locale files; feedback keys by locale: {totals}")
    print(f"Review candidates: {len(generic)} short/empty messages, "
          f"{len(literal)} possible hardcoded feedback statements")
    for locale, file, path, value in generic[:120]:
        print(f"  REVIEW [{locale}] {file} {path}: {value!r}")
    if len(generic) > 120:
        print(f"  ... {len(generic) - 120} more short-message candidates")
    for file, number, line in literal[:80]:
        print(f"  HARDCODED {file}:{number}: {line}")
    if len(literal) > 80:
        print(f"  ... {len(literal) - 80} more literal candidates")
    print("Findings are advisory: short status labels may be correct. "
          "Review text in its screen and operation context.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
