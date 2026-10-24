import subprocess
import tempfile
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
        replace = self.script.index(
            '/usr/bin/rsync -aE --checksum --delete',
            verify,
        )
        self.assertLess(stage, verify)
        self.assertLess(verify, replace)

    def test_preserves_bundle_root_and_previous_application(self):
        self.assertNotIn('mv "$app_destination" "$previous_destination"', self.script)
        self.assertIn('ditto "$app_destination" "$previous_destination"', self.script)
        self.assertIn(
            '/usr/bin/rsync -aE --checksum --delete',
            self.script,
        )

    def test_refreshes_registration_and_enablement_after_every_update(self):
        self.assertIn('"$installed_executable" --register-input-source', self.script)
        self.assertIn('"$installed_executable" --enable-input-source', self.script)
        self.assertIn('wait_for_status "$installed_executable" enabled 1', self.script)

    def test_installs_default_extensions_before_starting_input_source(self):
        install_extensions = self.script.index(
            '"$installed_executable" --install-default-extensions'
        )
        register = self.script.index(
            '"$installed_executable" --register-input-source'
        )
        self.assertLess(install_extensions, register)

    def test_bundles_third_party_notices(self):
        build_script = (
            SCRIPT.parents[1] / "Scripts" / "build-macos-ime.sh"
        ).read_text(encoding="utf-8")
        self.assertIn('"THIRD_PARTY_NOTICES.md"', build_script)
        self.assertIn(
            '"$resources_directory/THIRD_PARTY_NOTICES.md"',
            build_script,
        )

    def test_increments_bundle_version_for_every_installation(self):
        self.assertIn('next_build_number=', self.script)
        self.assertIn('MYIM_BUILD_NUMBER="$next_build_number"', self.script)
        self.assertIn(
            'if [[ "$installed_build_number" != "$next_build_number" ]]',
            self.script,
        )

    def test_waits_for_the_new_server_before_reporting_success(self):
        verify_application = self.script.index(
            'diff -qr "$app_source" "$app_destination"'
        )
        select_source = self.script.index(
            '"$installed_executable" --select-input-source'
        )
        wait_for_server = self.script.index(
            "if ! wait_for_running_server \\\n"
        )
        success = self.script.index(
            'echo "インストールしました: $app_destination"'
        )
        self.assertLess(verify_application, select_source)
        self.assertLess(select_source, wait_for_server)
        self.assertLess(wait_for_server, success)

    def test_checks_every_running_server_instead_of_only_the_first_pid(self):
        self.assertNotIn("pgrep -x myim 2>/dev/null | head -n 1", self.script)
        self.assertIn("for process_id in", self.script)
        self.assertIn("別の場所にあるmyimプロセス", self.script)

    def test_verifies_the_complete_application_before_success(self):
        self.assertIn(
            'diff -qr "$app_source" "$app_destination"',
            self.script,
        )
        verify = self.script.index(
            'diff -qr "$app_source" "$app_destination"'
        )
        delete_backup = self.script.index(
            'rm -rf "$previous_destination"',
            verify,
        )
        self.assertLess(verify, delete_backup)

    def test_reports_an_unverified_launch_as_a_distinct_failure(self):
        self.assertIn("RESULT=installed-launch-unverified", self.script)
        self.assertIn("exit 2", self.script)

    def test_reports_install_process_and_session_stages_separately(self):
        self.assertIn('echo "INSTALL_STAGE=verified"', self.script)
        self.assertIn('echo "PROCESS_STAGE=$process_stage"', self.script)
        self.assertIn('echo "SESSION_STAGE=$session_stage"', self.script)
        self.assertIn("RESULT=installed-verified", self.script)
        self.assertIn("RESULT=installed-session-unverified", self.script)

    def test_session_unverified_result_is_not_an_installation_failure(self):
        result = self.script.index("RESULT=installed-session-unverified")
        selected_branch_end = self.script.index(
            'else\n    echo "RESULT=installed-not-selected"',
            result,
        )
        self.assertNotIn("exit 2", self.script[result:selected_branch_end])
        self.assertIn("入力ソースを一度切り替えて", self.script)
        self.assertIn("入力欄へフォーカスし直して", self.script)
        self.assertIn("入力先アプリを再起動", self.script)

    def test_clears_old_session_records_before_starting_new_server(self):
        clear = self.script.index('name \'*.json\'')
        enable = self.script.index(
            '"$installed_executable" --enable-input-source'
        )
        select = self.script.index(
            '"$installed_executable" --select-input-source',
            clear,
        )
        self.assertLess(clear, enable)
        self.assertLess(clear, select)

    def test_refuses_to_update_while_the_legacy_input_source_is_selected(self):
        self.assertIn("legacy-selected", self.script)
        self.assertIn("RESULT=legacy-input-source-selected", self.script)

    def test_legacy_cleanup_requires_every_safety_condition(self):
        assessment = self.script[
            self.script.index("assess_legacy_application()") :
            self.script.index("cleanup_legacy_application()")
        ]
        self.assertIn("io.github.sendarionn.my-ime", assessment)
        self.assertIn("bundle_executable", assessment)
        self.assertIn("legacy-selected", assessment)
        self.assertIn("pgrep -x my-ime", assessment)
        self.assertIn("app_destination", assessment)
        self.assertIn("system_destination", assessment)

    def test_legacy_cleanup_unregisters_before_removing_the_bundle(self):
        cleanup = self.script[
            self.script.index("cleanup_legacy_application()") :
            self.script.index("finish_installation()")
        ]
        unregister = cleanup.index('"$launch_services_register" -u')
        remove = cleanup.index('remove_legacy_application "$application"')
        self.assertLess(unregister, remove)
        self.assertIn("--disable-legacy-input-source", cleanup)

    def test_legacy_cleanup_is_assessed_before_old_processes_are_stopped(self):
        assessment = self.script.index(
            'assess_legacy_application "$legacy_destination"'
        )
        stop = self.script.index("stop_process my-ime")
        self.assertLess(assessment, stop)

    def test_legacy_cleanup_removes_only_a_verified_inactive_bundle(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            legacy = root / "my-ime.app"
            contents = legacy / "Contents"
            contents.mkdir(parents=True)
            (contents / "Info.plist").write_text(
                """<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>io.github.sendarionn.my-ime</string>
<key>CFBundleExecutable</key><string>my-ime</string>
</dict></plist>
""",
                encoding="utf-8",
            )
            fake_bin = root / "bin"
            fake_bin.mkdir()
            fake_pgrep = fake_bin / "pgrep"
            fake_pgrep.write_text("#!/bin/sh\nexit 1\n", encoding="utf-8")
            fake_pgrep.chmod(0o755)
            status = root / "status"
            status.write_text(
                """#!/bin/sh
if [ "$1" = "--input-source-status" ]; then
  printf 'legacy-selected=0\\nlegacy-enabled=0\\nlegacy-registered=0\\n'
fi
""",
                encoding="utf-8",
            )
            status.chmod(0o755)

            command = r'''
source "$1"
legacy_destination="$2/my-ime.app"
system_legacy_destination="$2/system-my-ime.app"
app_destination="$2/myim.app"
system_destination="$2/system-myim.app"
launch_services_register=/usr/bin/true
PATH="$2/bin:/usr/bin:/bin"
cleanup_legacy_application "$legacy_destination" "$2/status"
'''
            result = subprocess.run(
                ["zsh", "-c", command, "cleanup-test", str(SCRIPT), str(root)],
                capture_output=True,
                text=True,
                check=False,
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("LEGACY_CLEANUP=removed", result.stdout)
            self.assertFalse(legacy.exists())

    def test_legacy_cleanup_keeps_a_bundle_with_an_unexpected_identifier(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            legacy = root / "my-ime.app"
            contents = legacy / "Contents"
            contents.mkdir(parents=True)
            (contents / "Info.plist").write_text(
                """<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>example.other</string>
<key>CFBundleExecutable</key><string>my-ime</string>
</dict></plist>
""",
                encoding="utf-8",
            )
            fake_bin = root / "bin"
            fake_bin.mkdir()
            fake_pgrep = fake_bin / "pgrep"
            fake_pgrep.write_text("#!/bin/sh\nexit 1\n", encoding="utf-8")
            fake_pgrep.chmod(0o755)
            status = root / "status"
            status.write_text(
                """#!/bin/sh
printf 'legacy-selected=0\\nlegacy-enabled=0\\nlegacy-registered=0\\n'
""",
                encoding="utf-8",
            )
            status.chmod(0o755)

            command = r'''
source "$1"
legacy_destination="$2/my-ime.app"
system_legacy_destination="$2/system-my-ime.app"
app_destination="$2/myim.app"
system_destination="$2/system-myim.app"
launch_services_register=/usr/bin/true
PATH="$2/bin:/usr/bin:/bin"
cleanup_legacy_application "$legacy_destination" "$2/status"
'''
            result = subprocess.run(
                ["zsh", "-c", command, "cleanup-test", str(SCRIPT), str(root)],
                capture_output=True,
                text=True,
                check=False,
            )

            self.assertNotEqual(result.returncode, 0)
            self.assertIn("bundle-identifier-mismatch", result.stdout)
            self.assertTrue(legacy.exists())

    def test_uses_checksums_for_replacement_and_rollback(self):
        self.assertIn("rsync -aE --checksum --delete", self.script)

    def test_rollback_reports_success_and_failure_separately(self):
        self.assertIn("RESULT=rollback-succeeded", self.script)
        self.assertIn("RESULT=rollback-failed", self.script)
        self.assertIn("local exit_code=$?", self.script)
        self.assertNotIn("local status=$?", self.script)
        self.assertIn("verify_restored_application", self.script)
        self.assertIn("verify_restored_selection_service", self.script)

    def test_verifies_backups_before_replacing_installed_artifacts(self):
        backup = self.script.index(
            'ditto "$app_destination" "$previous_destination"'
        )
        backup_verification = self.script.index(
            'myim.appのバックアップ検証に失敗しました'
        )
        replacement = self.script.index(
            '/usr/bin/rsync -aE --checksum --delete',
            backup_verification,
        )
        self.assertLess(backup, backup_verification)
        self.assertLess(backup_verification, replacement)

    def test_refuses_a_conflicting_system_installation(self):
        self.assertIn(
            'system_destination="/Library/Input Methods/myim.app"',
            self.script,
        )
        self.assertIn("システム領域のmyimと競合", self.script)

    def test_does_not_launch_input_method_as_a_regular_application(self):
        self.assertNotIn('open -gja "$app_destination"', self.script)

    def test_stops_every_bundled_process_before_replacing_the_app(self):
        self.assertIn("stop_process myim", self.script)
        self.assertIn("stop_process myim-external-browser", self.script)
        self.assertIn("stop_process myim-extension-host", self.script)

    def test_rollback_restores_both_artifacts_after_an_injected_failure(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            for name, value in [
                ("app", "new-app"),
                ("service", "new-service"),
                ("previous-app", "old-app"),
                ("previous-service", "old-service"),
            ]:
                directory = root / name
                directory.mkdir()
                (directory / "content").write_text(value, encoding="utf-8")

            command = r'''
source "$1"
set +e
app_destination="$2/app"
selection_service_destination="$2/service"
previous_destination="$2/previous-app"
previous_selection_service="$2/previous-service"
staged_destination="$2/staged-app"
staged_selection_service="$2/staged-service"
rollback_required=1
had_previous_application=1
had_previous_selection_service=1
verify_restored_application() {
    diff -qr "$previous_destination" "$app_destination" >/dev/null
}
verify_restored_selection_service() {
    diff -qr \
        "$previous_selection_service" \
        "$selection_service_destination" >/dev/null
}
restore_input_source_registration() { return 0 }
false
finish_installation
'''
            result = subprocess.run(
                ["zsh", "-c", command, "rollback-test", str(SCRIPT), str(root)],
                capture_output=True,
                text=True,
                check=False,
            )

            self.assertEqual(result.returncode, 1)
            self.assertIn("RESULT=rollback-succeeded", result.stderr)
            self.assertEqual(
                (root / "app/content").read_text(encoding="utf-8"),
                "old-app",
            )
            self.assertEqual(
                (root / "service/content").read_text(encoding="utf-8"),
                "old-service",
            )
            self.assertFalse((root / "previous-app").exists())
            self.assertFalse((root / "previous-service").exists())

    def test_rollback_failure_has_a_distinct_result_and_keeps_backup(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            (root / "app").mkdir()
            (root / "service").mkdir()
            (root / "previous-service").mkdir()
            (root / "previous-service/content").write_text(
                "old-service",
                encoding="utf-8",
            )

            command = r'''
source "$1"
set +e
app_destination="$2/app"
selection_service_destination="$2/service"
previous_destination="$2/missing-previous-app"
previous_selection_service="$2/previous-service"
staged_destination="$2/staged-app"
staged_selection_service="$2/staged-service"
rollback_required=1
had_previous_application=1
had_previous_selection_service=1
verify_restored_application() { return 0 }
verify_restored_selection_service() { return 0 }
restore_input_source_registration() { return 0 }
false
finish_installation
'''
            result = subprocess.run(
                ["zsh", "-c", command, "rollback-test", str(SCRIPT), str(root)],
                capture_output=True,
                text=True,
                check=False,
            )

            self.assertEqual(result.returncode, 3)
            self.assertIn("RESULT=rollback-failed", result.stderr)
            self.assertTrue((root / "previous-service").exists())

if __name__ == "__main__":
    unittest.main()
