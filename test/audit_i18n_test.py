import pathlib
import tempfile
import unittest

import yaml

from script.audit_i18n import (
    DuplicateKeyError,
    StrictLoader,
    audit_definitions,
    audit_references,
    translation_references,
)


class AuditI18nTest(unittest.TestCase):
    def test_absent_in_every_locale_is_detected(self):
        catalogs = {locale: {} for locale in ("en", "es", "ko")}
        issues = audit_references(catalogs, {"admin.languages.updated": "controller.rb:1"})
        self.assertEqual(len(issues), 3)
        self.assertTrue(all("MISSING_REFERENCE admin.languages.updated" in issue for issue in issues))

    def test_literal_and_relative_view_references(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            view = root / "views/admin/languages/_form.html.erb"
            view.parent.mkdir(parents=True)
            view.write_text("<%= t('.title') %> <%= t('admin.languages.updated') %>", encoding="utf-8")
            self.assertEqual(set(translation_references(root)), {
                "admin.languages.form.title", "admin.languages.updated"
            })

    def test_unquoted_boolean_key_is_rejected(self):
        with self.assertRaises(DuplicateKeyError):
            yaml.load('en: {yes: "Yes"}', Loader=StrictLoader)
        self.assertEqual(yaml.load('en: {"yes": "Yes"}', Loader=StrictLoader), {"en": {"yes": "Yes"}})

    def test_blank_and_conflicting_definitions_are_detected(self):
        parsed = {
            "a.yml": ("en", {"en": {"key": None}}),
            "b.yml": ("en", {"en": {"key": "Value"}}),
        }
        issues = audit_definitions(parsed)
        self.assertEqual(len(issues), 2)
        self.assertTrue(any("EMPTY" in issue for issue in issues))
        self.assertTrue(any("CONFLICT" in issue for issue in issues))


if __name__ == "__main__":
    unittest.main()
