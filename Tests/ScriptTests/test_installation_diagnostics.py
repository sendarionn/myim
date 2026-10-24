import unittest
from pathlib import Path


ROOT = Path(__file__).parents[2]


class InstallationDiagnosticsTests(unittest.TestCase):
    def test_build_embeds_source_identity(self):
        script = (ROOT / "Scripts/build-macos-ime.sh").read_text(
            encoding="utf-8"
        )
        self.assertIn("MyIMGitCommit", script)
        self.assertIn("MyIMGitDirty", script)
        self.assertIn("MyIMBuildTimestamp", script)

    def test_diagnostic_reports_install_process_and_resource_identity(self):
        script = (ROOT / "Scripts/diagnose-installation.sh").read_text(
            encoding="utf-8"
        )
        self.assertIn("EXECUTABLE_SHA256", script)
        self.assertIn("RESOURCES_MATCH", script)
        self.assertIn("APP_BUNDLE_MATCH", script)
        self.assertIn("SELECTION_SERVICE_MATCH", script)
        self.assertIn("PROCESS_COMMAND", script)
        self.assertIn("RUNTIME_STATUS", script)
        self.assertIn("INSTALLED_IDENTITY_MATCH", script)
        self.assertIn("INSTALL_STATE", script)
        self.assertIn("RUN_STATE", script)
        self.assertIn("HISTORY_STATE", script)
        self.assertIn("SESSION_STATE", script)
        self.assertIn("LEGACY_STATE", script)
        self.assertIn(
            "起動履歴がインストール済みアプリと一致しません",
            script,
        )
        self.assertIn("RESULT=attention", script)

    def test_input_session_identity_is_recorded_per_client_application(self):
        reporter = (
            ROOT / "Sources/MyIMEMacOS/BuildIdentityReporter.swift"
        ).read_text(encoding="utf-8")
        controller = (
            ROOT / "Sources/MyIMEMacOS/InputController.swift"
        ).read_text(encoding="utf-8")
        for field in [
            'identity["client-bundle-id"]',
            'identity["pid"]',
            'identity["controller-id"]',
            'identity["session-generation"]',
            'identity["activated-at"]',
        ]:
            self.assertIn(field, reporter)
        self.assertIn('"build": info["CFBundleVersion"]', reporter)
        self.assertIn('"git-commit": info["MyIMGitCommit"]', reporter)
        self.assertIn("input-sessions", reporter)
        self.assertIn("writeInputSessionStatus", controller)
        self.assertIn("activation.globalGeneration", controller)

    def test_diagnostic_verifies_only_the_requested_client_session(self):
        script = (ROOT / "Scripts/diagnose-installation.sh").read_text(
            encoding="utf-8"
        )
        self.assertIn("--client-bundle-id", script)
        self.assertIn("SESSION_TARGET", script)
        self.assertIn("CLIENT_BUNDLE_ID", script)
        self.assertIn('session_state="verified"', script)
        self.assertIn("RESULT=installed-verified", script)
        self.assertIn("RESULT=installed-session-unverified", script)
        self.assertIn("SESSION_GUIDANCE", script)

    def test_diagnostic_does_not_treat_history_as_a_running_process(self):
        script = (ROOT / "Scripts/diagnose-installation.sh").read_text(
            encoding="utf-8"
        )
        self.assertIn('STATUS=last-launch', script)
        self.assertIn('run_state="installed-not-running"', script)
        self.assertIn('run_state="running-current"', script)
        self.assertIn('run_state="old-running"', script)
        self.assertIn('run_state="diagnostic-unavailable"', script)

    def test_diagnostic_ignores_internal_installation_backups(self):
        script = (ROOT / "Scripts/diagnose-installation.sh").read_text(
            encoding="utf-8"
        )
        self.assertIn('case "${application:t}"', script)
        self.assertIn(".myim.*)", script)

    def test_input_source_status_includes_the_legacy_identifier(self):
        manager = (
            ROOT / "Sources/MyIMEMacOS/InputSourceRegistrationManager.swift"
        ).read_text(encoding="utf-8")
        main = (ROOT / "Sources/MyIMEMacOS/main.swift").read_text(
            encoding="utf-8"
        )
        self.assertIn("io.github.sendarionn.my-ime.Japanese", manager)
        self.assertIn("legacy-registered", main)
        self.assertIn("legacy-enabled", main)
        self.assertIn("legacy-selected", main)

    def test_pkg_stops_every_bundled_process(self):
        script = (ROOT / "packaging/scripts/preinstall").read_text(
            encoding="utf-8"
        )
        for process in [
            "myim",
            "my-ime",
            "myim-external-browser",
            "myim-extension-host",
            "myim-selection-service",
        ]:
            self.assertIn(f"stop_process {process}", script)
        self.assertIn("ユーザー領域のmyimと競合", script)

    def test_pkg_postinstall_verifies_without_claiming_a_running_server(self):
        script = (ROOT / "packaging/scripts/postinstall").read_text(
            encoding="utf-8"
        )
        self.assertIn("codesign --verify --deep --strict", script)
        self.assertIn("MyIMGitCommit", script)
        self.assertIn("RESULT=installed-not-running", script)

    def test_release_package_uses_build_number_in_receipt_version(self):
        script = (ROOT / "Scripts/build-release-pkg.sh").read_text(
            encoding="utf-8"
        )
        self.assertIn('package_receipt_version="$version.$build_number"', script)
        self.assertIn('--version "$package_receipt_version"', script)
        self.assertIn("PKGペイロードがビルド成果物と一致しません", script)


if __name__ == "__main__":
    unittest.main()
