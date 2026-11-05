#!/usr/bin/env python3
"""Guard the updater's distribution inputs without touching signing credentials."""
import base64
import pathlib
import plistlib
import tempfile
import unittest

from embed_sparkle import update_settings


class UpdateConfigurationTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.path = pathlib.Path(self.directory.name) / 'Updates.plist'
        self.config = {'SUFeedURL': 'https://updates.example.org/appcast.xml',
                       'SUPublicEDKey': base64.b64encode(bytes(range(32))).decode()}

    def read(self):
        self.path.write_bytes(plistlib.dumps(self.config))
        return update_settings(self.path, required=True)

    def test_valid_feed_checks_automatically_without_silent_install_or_profiling(self):
        self.config['UnrelatedBundleKey'] = 'must not enter app Info.plist'
        settings = self.read()
        self.assertTrue(settings['SUEnableAutomaticChecks'])
        self.assertFalse(settings['SUAutomaticallyUpdate'])
        self.assertFalse(settings['SUAllowsAutomaticUpdates'])
        self.assertFalse(settings['SUEnableSystemProfiling'])
        self.assertNotIn('UnrelatedBundleKey', settings)

    def test_missing_configuration_is_only_allowed_for_development(self):
        self.assertFalse(update_settings(self.path, required=False)['SUEnableAutomaticChecks'])
        with self.assertRaises(FileNotFoundError):
            update_settings(self.path, required=True)

    def test_unsafe_or_malformed_urls_are_rejected(self):
        for feed in ('http://updates.example.org/appcast.xml', 'https:///appcast.xml',
                     'https://user:secret@example.org/feed', 'https://example.org/feed#fragment',
                     'https://example.org:bad/feed', 'https://example.org/\nfeed'):
            with self.subTest(feed=feed), self.assertRaises(ValueError):
                self.config['SUFeedURL'] = feed
                self.read()

    def test_invalid_public_keys_are_rejected(self):
        for key in ('', '!not base64!', base64.b64encode(b'short').decode(), 123):
            with self.subTest(key=key), self.assertRaises(ValueError):
                self.config['SUPublicEDKey'] = key
                self.read()

    def test_string_boolean_is_rejected(self):
        self.config['SUEnableAutomaticChecks'] = 'false'
        with self.assertRaises(ValueError):
            self.read()

    def test_explicit_check_preference_is_preserved(self):
        self.config['SUEnableAutomaticChecks'] = False
        self.assertFalse(self.read()['SUEnableAutomaticChecks'])


if __name__ == '__main__':
    unittest.main()
