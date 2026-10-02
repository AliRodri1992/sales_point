#!/usr/bin/env python3
"""Strict YAML/I18n audit for Rails locale files.

Checks every config/locales/**/*.yml and *.yaml file for:
- YAML syntax errors.
- Duplicate mapping keys at any nesting level.
- YAML aliases/anchors.
- Non-mapping locale roots.
- Missing/extra top-level locale keys.
- Interpolation variable drift across en/es/ko for shared translation paths.
"""

from __future__ import annotations

import pathlib
import re
import sys

import yaml
from yaml.events import AliasEvent, MappingEndEvent, MappingStartEvent, ScalarEvent


LOCALES_DIR = pathlib.Path("config/locales")
REQUIRED_LOCALES = ("en", "es", "ko")
INTERPOLATION_RE = re.compile(r"%{([A-Za-z0-9_]+)}")


class DuplicateKeyError(ValueError):
    pass


class StrictLoader(yaml.SafeLoader):
    pass


def construct_mapping_no_duplicates(loader: StrictLoader, node: yaml.MappingNode, deep: bool = False):
    mapping = {}
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node, deep=deep)
        if key in mapping:
            raise DuplicateKeyError(
                f"duplicate key {key!r} at line {key_node.start_mark.line + 1}, "
                f"column {key_node.start_mark.column + 1}"
            )
        mapping[key] = loader.construct_object(value_node, deep=deep)
    return mapping


StrictLoader.add_constructor(
    yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG,
    construct_mapping_no_duplicates,
)


def reject_aliases_and_anchors(path: pathlib.Path, text: str) -> None:
    for event in yaml.parse(text):
        if isinstance(event, AliasEvent):
            raise ValueError(
                f"YAML alias is not allowed at line {event.start_mark.line + 1}"
            )
        if isinstance(event, ScalarEvent) and event.anchor:
            raise ValueError(
                f"YAML anchor is not allowed at line {event.start_mark.line + 1}"
            )


def flatten(value, prefix=()):
    if isinstance(value, dict):
        for key, child in value.items():
            yield from flatten(child, prefix + (str(key),))
    else:
        yield prefix


def interpolation_map(value, prefix=()):
    result = {}
    if isinstance(value, dict):
        for key, child in value.items():
            result.update(interpolation_map(child, prefix + (str(key),)))
    elif isinstance(value, str):
        result[".".join(prefix)] = tuple(sorted(INTERPOLATION_RE.findall(value)))
    return result


def load_locale(path: pathlib.Path):
    text = path.read_text(encoding="utf-8")
    reject_aliases_and_anchors(path, text)
    try:
        parsed = yaml.load(text, Loader=StrictLoader)
    except (yaml.YAMLError, DuplicateKeyError, ValueError) as exc:
        raise SystemExit(f"{path}: {exc}") from exc

    if not isinstance(parsed, dict) or len(parsed) != 1:
        raise SystemExit(f"{path}: expected exactly one locale root mapping")

    locale, payload = next(iter(parsed.items()))
    if not isinstance(locale, str) or not isinstance(payload, dict):
        raise SystemExit(f"{path}: root locale {locale!r} must contain a mapping")

    return locale, parsed


def main() -> int:
    paths = sorted(LOCALES_DIR.rglob("*.yml")) + sorted(LOCALES_DIR.rglob("*.yaml"))
    if not paths:
        print("No locale files found.")
        return 1

    parsed = {}
    for path in paths:
        locale, data = load_locale(path)
        parsed[path] = (locale, data)
        print(f"OK YAML: {path} ({locale})")

    roots = {}
    for path, (locale, _) in parsed.items():
        roots.setdefault(locale, []).append(path)

    for locale in REQUIRED_LOCALES:
        if locale not in roots:
            raise SystemExit(f"Missing required locale root: {locale}")

    for locale, locale_paths in roots.items():
        if len(locale_paths) > 1:
            print(f"INFO: locale {locale!r} is split across: {', '.join(map(str, locale_paths))}")

    main_files = {}
    for path, (locale, data) in parsed.items():
        if path.name in {"en.yml", "es.yml", "ko.yml"}:
            main_files[locale] = data[locale]

    missing_main = set(REQUIRED_LOCALES) - set(main_files)
    if missing_main:
        raise SystemExit(f"Missing main locale files: {', '.join(sorted(missing_main))}")

    reference = main_files["en"]
    reference_paths = set(flatten(reference))
    for locale in REQUIRED_LOCALES[1:]:
        current_paths = set(flatten(main_files[locale]))
        missing = sorted(reference_paths - current_paths)
        extra = sorted(current_paths - reference_paths)
        print(f"STRUCTURE {locale}: missing={len(missing)} extra={len(extra)}")
        if missing:
            print("  Missing examples:", " | ".join(".".join(p) for p in missing[:20]))
        if extra:
            print("  Extra examples:", " | ".join(".".join(p) for p in extra[:20]))

    interpolation = {
        locale: interpolation_map(main_files[locale]) for locale in REQUIRED_LOCALES
    }
    for path, variables in interpolation["en"].items():
        for locale in REQUIRED_LOCALES[1:]:
            if path not in interpolation[locale]:
                continue
            if variables != interpolation[locale][path]:
                raise SystemExit(
                    f"Interpolation mismatch at {path}: "
                    f"en={variables}, {locale}={interpolation[locale][path]}"
                )

    print(f"PASS: audited {len(paths)} locale files with strict duplicate-key detection.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
