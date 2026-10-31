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



def deep_merge(target, source):
    """Mirror Rails locale merging without discarding unrelated scopes."""
    for key, value in source.items():
        if isinstance(value, dict) and isinstance(target.get(key), dict):
            deep_merge(target[key], value)
        else:
            target[key] = value


def leaf_map(value, prefix=()):
    """Keep arrays as values: empty lists must not silently count as translated topics."""
    if isinstance(value, dict):
        result = {}
        for key, child in value.items():
            result.update(leaf_map(child, prefix + (str(key),)))
        return result
    return {".".join(prefix): value}


def audit_full_locale_parity(parsed):
    """Report full file-catalog coverage; opt-in strict mode gates outstanding debt."""
    import os

    merged = {locale: {} for locale in REQUIRED_LOCALES}
    for locale, data in parsed.values():
        if locale in merged:
            deep_merge(merged[locale], data[locale])

    leaves = {locale: leaf_map(tree) for locale, tree in merged.items()}
    reference = leaves["es"]
    issues = []
    for locale in ("en", "ko"):
        current = leaves[locale]
        for key, value in sorted(reference.items()):
            if key not in current:
                issues.append(f"{locale}: MISSING {key}")
                continue
            translated = current[key]
            if isinstance(value, str) and isinstance(translated, str):
                base_vars = sorted(INTERPOLATION_RE.findall(value))
                target_vars = sorted(INTERPOLATION_RE.findall(translated))
                if base_vars != target_vars:
                    issues.append(f"{locale}: INTERPOLATION {key}: {base_vars} != {target_vars}")
            if isinstance(translated, str) and not translated.strip() and str(value).strip():
                issues.append(f"{locale}: EMPTY {key}")
            if isinstance(value, list) and isinstance(translated, list):
                if len(translated) < len(value):
                    issues.append(f"{locale}: SHORT_LIST {key}: {len(translated)}/{len(value)}")
        for key in sorted(set(current) - set(reference)):
            issues.append(f"{locale}: EXTRA {key}")

    for locale in REQUIRED_LOCALES:
        sections = merged[locale].get("admin", {}).get("user_manual", {}).get("sections", {})
        if isinstance(sections, dict):
            for section, content in sections.items():
                if isinstance(content, dict) and not content.get("topics"):
                    issues.append(f"{locale}: EMPTY_MANUAL {section}")

    print("FULL_LOCALE_PARITY")
    for locale in REQUIRED_LOCALES:
        print(f"  {locale}: {len(leaves[locale])} leaf paths")
    print(f"  findings: {len(issues)}")
    for issue in issues[:200]:
        print(f"  - {issue}")
    if len(issues) > 200:
        print(f"  ... {len(issues) - 200} additional findings omitted")
    if issues and os.environ.get("I18N_STRICT_PARITY") == "1":
        return 1
    if issues:
        print("WARN: translation coverage is incomplete; use I18N_STRICT_PARITY=1 to fail CI.")
    return 0

def main() -> int:
    paths = sorted(LOCALES_DIR.rglob("*.yml")) + sorted(LOCALES_DIR.rglob("*.yaml"))
    if not paths:
        print("No locale files found.")
        return 1

    parsed = {}
    errors = []
    for path in paths:
        try:
            locale, data = load_locale(path)
        except SystemExit as exc:
            errors.append(str(exc))
            continue
        parsed[path] = (locale, data)
        print(f"OK YAML: {path} ({locale})")
    if errors:
        print("YAML AUDIT ERRORS:")
        for error in errors:
            print(f"  - {error}")
        return 1

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

    # Main locale files intentionally contain some different Devise scopes because
    # additional Devise locale files also exist in config/locales/. Report those
    # differences without treating them as YAML errors.
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

    # The registration wizard is application-owned and must remain structurally
    # identical across the three supported UI locales.
    registration_paths = {}
    registration_interpolations = {}
    for locale in REQUIRED_LOCALES:
        node = main_files[locale].get("devise", {}).get("registrations", {}).get("new")
        if not isinstance(node, dict):
            raise SystemExit(f"Missing devise.registrations.new in {locale}.yml")
        registration_paths[locale] = set(flatten(node))
        registration_interpolations[locale] = interpolation_map(node)

    for locale in REQUIRED_LOCALES[1:]:
        missing = sorted(registration_paths["en"] - registration_paths[locale])
        extra = sorted(registration_paths[locale] - registration_paths["en"])
        if missing or extra:
            raise SystemExit(
                f"Registration structure mismatch for {locale}: "
                f"missing={len(missing)} extra={len(extra)}"
            )

    for path, variables in registration_interpolations["en"].items():
        for locale in REQUIRED_LOCALES[1:]:
            if registration_interpolations[locale].get(path) != variables:
                raise SystemExit(
                    f"Registration interpolation mismatch at {path}: "
                    f"en={variables}, {locale}={registration_interpolations[locale].get(path)}"
                )

    parity_result = audit_full_locale_parity(parsed)
    print(f"PASS: audited {len(paths)} locale files with strict duplicate-key detection.")
    return parity_result


if __name__ == "__main__":
    sys.exit(main())
# End of strict i18n audit script.
