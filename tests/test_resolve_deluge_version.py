import unittest

from scripts.resolve_deluge_version import pin_version, resolve_version


class ResolveVersionTests(unittest.TestCase):
    dockerfile = "ARG UNRAR_VERSION=7.2.7\nARG DELUGE_BRANCH=deluge-2.2.0\n"

    def test_push_uses_dockerfile_pin(self):
        self.assertEqual(resolve_version(self.dockerfile, "2.3.0"), "2.2.0")

    def test_schedule_uses_latest_stable(self):
        self.assertEqual(
            resolve_version(self.dockerfile, "2.3.0", scheduled=True), "2.3.0"
        )

    def test_manual_version_overrides_default(self):
        self.assertEqual(
            resolve_version(self.dockerfile, "2.3.0", "2.1.1"), "2.1.1"
        )

    def test_manual_override_takes_precedence_over_schedule(self):
        self.assertEqual(
            resolve_version(self.dockerfile, "2.3.0", "2.2.0", scheduled=True),
            "2.2.0",
        )

    def test_rejects_invalid_or_development_versions(self):
        for version in ("master", "2.3.0rc1", "2.2.0\nlatest", "2.2", "-bad"):
            with self.subTest(version=version), self.assertRaises(ValueError):
                resolve_version(self.dockerfile, "2.3.0", version)

    def test_rejects_unstable_upstream_version(self):
        with self.assertRaises(ValueError):
            resolve_version(self.dockerfile, "2.3.0rc1", scheduled=True)

    def test_requires_pinned_dockerfile(self):
        with self.assertRaises(ValueError):
            resolve_version("ARG DELUGE_BRANCH=master\n", "2.3.0")


class PinVersionTests(unittest.TestCase):
    dockerfile = "ARG UNRAR_VERSION=7.2.7\nARG DELUGE_BRANCH=deluge-2.2.0\n"

    def test_updates_only_deluge_pin(self):
        self.assertEqual(
            pin_version(self.dockerfile, "2.3.0"),
            "ARG UNRAR_VERSION=7.2.7\nARG DELUGE_BRANCH=deluge-2.3.0\n",
        )

    def test_unchanged_version_is_noop(self):
        self.assertEqual(pin_version(self.dockerfile, "2.2.0"), self.dockerfile)

    def test_rejects_invalid_versions(self):
        for version in ("master", "2.3.0rc1", "2.3.0\nRUN bad"):
            with self.subTest(version=version), self.assertRaises(ValueError):
                pin_version(self.dockerfile, version)

    def test_rejects_missing_or_duplicate_pin(self):
        for dockerfile in ("FROM alpine:3.24\n", self.dockerfile * 2):
            with self.subTest(dockerfile=dockerfile), self.assertRaises(ValueError):
                pin_version(dockerfile, "2.3.0")


if __name__ == "__main__":
    unittest.main()
