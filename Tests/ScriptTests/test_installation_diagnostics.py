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
        self.assertIn("PROCESS_COMMAND", script)
        self.assertIn("RUNTIME_STATUS", script)
        self.assertIn("INSTALLED_IDENTITY_MATCH", script)
        self.assertIn(
            "起動時ビルド情報がインストール済みアプリと一致しません",
            script,
        )
        self.assertIn("RESULT=attention", script)

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
