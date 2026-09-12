import unittest
from pathlib import Path


SCRIPT = Path(__file__).parents[2] / "Scripts" / "install-macos-im.sh"


class InstallMacOSIMTests(unittest.TestCase):
    def setUp(self):
        self.script = SCRIPT.read_text(encoding="utf-8")

    def test_uses_signed_application_for_input_source_operations(self):
        self.assertNotIn("/usr/bin/swift -e", self.script)
        self.assertIn("--input-source-status", self.script)
        self.assertIn("--select-fallback-input-source", self.script)
        self.assertIn("--select-input-source", self.script)

    def test_verifies_staged_application_before_replacing_installed_copy(self):
        stage = self.script.index('ditto "$app_source" "$staged_destination"')
        verify = self.script.index(
            'codesign --verify --deep --strict "$staged_destination"'
        )
        replace = self.script.index('/usr/bin/rsync -aE --delete', verify)
        self.assertLess(stage, verify)
        self.assertLess(verify, replace)

    def test_preserves_bundle_root_and_previous_application(self):
        self.assertNotIn('mv "$app_destination" "$previous_destination"', self.script)
        self.assertNotIn('rm -rf "$app_destination"', self.script)
        self.assertIn('ditto "$app_destination" "$previous_destination"', self.script)
        self.assertIn('/usr/bin/rsync -aE --delete', self.script)

    def test_refreshes_registration_and_enablement_after_every_update(self):
        self.assertIn('"$installed_executable" --register-input-source', self.script)
        self.assertIn('"$installed_executable" --enable-input-source', self.script)
        self.assertIn('wait_for_status "$installed_executable" enabled 1', self.script)

    def test_waits_for_the_new_server_before_reporting_success(self):
        verify_binary = self.script.index(
            'cmp -s "$source_executable" "$installed_executable"'
        )
        select_source = self.script.index(
            '"$installed_executable" --select-input-source'
        )
        wait_for_server = self.script.index(
            'wait_for_running_server "$installed_executable"'
        )
        success = self.script.index(
            'echo "インストールしました: $app_destination"'
        )
        self.assertLess(verify_binary, select_source)
        self.assertLess(select_source, wait_for_server)
        self.assertLess(wait_for_server, success)

    def test_stops_every_bundled_process_before_replacing_the_app(self):
        self.assertIn("stop_process myim", self.script)
        self.assertIn("stop_process myim-external-browser", self.script)
        self.assertIn("stop_process myim-extension-host", self.script)


if __name__ == "__main__":
    unittest.main()
