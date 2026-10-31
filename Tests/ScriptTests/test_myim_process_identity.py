import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).parents[2]
LIBRARY = ROOT / "Scripts" / "lib" / "myim-process-identity.sh"
INSTALLER = ROOT / "Scripts" / "install-macos-im.sh"
DIAGNOSTICS = ROOT / "Scripts" / "diagnose-installation.sh"


_original_home = None
_temporary_home = None


def setUpModule():
    # The installer writes its log and lock under HOME; tests must not
    # touch the user's files
    global _original_home, _temporary_home
    _original_home = os.environ.get("HOME")
    _temporary_home = tempfile.TemporaryDirectory()
    os.environ["HOME"] = _temporary_home.name


def tearDownModule():
    if _original_home is None:
        os.environ.pop("HOME", None)
    else:
        os.environ["HOME"] = _original_home
    _temporary_home.cleanup()


class ProcessIdentityTests(unittest.TestCase):
    """The running myim is current only when it has loaded the installed
    executable, not just when it was started from the same path"""

    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.root = Path(self.directory.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.executable = self.root / "myim.app" / "Contents" / "MacOS" / "myim"
        self.executable.parent.mkdir(parents=True)
        self.executable.write_text("old build", encoding="utf-8")

    def tearDown(self):
        self.directory.cleanup()

    def fake(self, name, body):
        path = self.bin / name
        path.write_text("#!/bin/sh\n" + body, encoding="utf-8")
        path.chmod(0o755)

    def fake_process(self, pid, command, loaded_inode):
        self.fake("ps", f"printf '%s\\n' '{command}'\n")
        self.fake(
            "lsof",
            f"printf 'p{pid}\\nftxt\\ni{loaded_inode}\\nn{command}\\n"
            "ftxt\\ni1\\nn/usr/lib/dyld\\n'\n",
        )

    def run_zsh(self, command, *arguments):
        environment = dict(os.environ)
        environment["PATH"] = f"{self.bin}:/usr/bin:/bin"
        return subprocess.run(
            ["zsh", "-c", command, "identity-test", *arguments],
            capture_output=True,
            text=True,
            check=False,
            env=environment,
        )

    def state(self, pid="501"):
        result = self.run_zsh(
            'source "$1"; myim_process_executable_state "$2" "$3"',
            str(LIBRARY),
            pid,
            str(self.executable),
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout.strip()

    def inode(self):
        return os.stat(self.executable).st_ino

    def test_process_running_the_installed_file_is_current(self):
        self.fake_process(501, str(self.executable), self.inode())

        self.assertEqual(self.state(), "current")

    def test_process_started_before_the_files_were_replaced_is_stale(self):
        # The process loaded the old file, then the installer put a new
        # file in its place, as rsync does, which gives it a new inode
        old_inode = self.inode()
        self.fake_process(501, str(self.executable), old_inode)
        replacement = self.root / "replacement"
        replacement.write_text("new build", encoding="utf-8")
        os.replace(replacement, self.executable)

        self.assertNotEqual(self.inode(), old_inode)
        self.assertEqual(self.state(), "stale-executable")

    def test_process_started_from_another_location_is_foreign(self):
        self.fake_process(501, "/Applications/other/myim", self.inode())

        self.assertEqual(self.state(), "foreign-path")

    def test_unreadable_loaded_executable_is_not_called_current(self):
        self.fake("ps", f"printf '%s\\n' '{self.executable}'\n")
        self.fake("lsof", "exit 1\n")

        self.assertEqual(self.state(), "unknown")

    def test_terminates_only_processes_running_a_replaced_executable(self):
        command = r'''
source "$1"
set +e
log_install() { :; }
myim_running_process_ids() { print 501; print 502; print 503; }
myim_process_executable_state() {
    case "$1" in
        501) print current ;;
        502) print stale-executable ;;
        503) print foreign-path ;;
    esac
}
killed=()
kill() {
    if [[ "$1" == "-TERM" ]]; then killed+=("$2"); return 0; fi
    [[ "$1" == "-0" ]] && return 1
}
terminate_stale_processes "$2"
print "status=$? stale=${stale_process_ids[*]} killed=${killed[*]}"
'''
        result = self.run_zsh(command, str(INSTALLER), str(self.executable))

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("status=0 stale=502 killed=502", result.stdout)

    def test_reports_a_stale_process_that_does_not_exit(self):
        command = r'''
source "$1"
set +e
log_install() { :; }
sleep() { :; }
myim_running_process_ids() { print 502; }
myim_process_executable_state() { print stale-executable; }
kill() { return 0; }
terminate_stale_processes "$2"
print "status=$?"
'''
        result = self.run_zsh(command, str(INSTALLER), str(self.executable))

        self.assertIn("status=1", result.stdout)

    def test_running_server_check_stops_at_a_stale_process(self):
        # Without the executable check the stale process would be waited
        # on for the whole timeout and could match an old launch record
        command = r'''
source "$1"
set +e
sleep() { print waited; }
pgrep() { print 502; }
ps() { print -r -- "$2"; }
myim_process_executable_state() { print stale-executable; }
wait_for_running_server "$2" 999 commit
print "status=$?"
'''
        result = self.run_zsh(command, str(INSTALLER), str(self.executable))

        self.assertIn("status=1", result.stdout)
        self.assertNotIn("waited", result.stdout)

    def test_second_installation_is_refused_while_one_runs(self):
        command = r'''
source "$1"
set +e
install_lock="$2/install.lock"
mkdir -p "$install_lock"
print -r -- "$$" > "$install_lock/pid"
( acquire_install_lock ) 2>&1
print "status=$?"
'''
        result = self.run_zsh(command, str(INSTALLER), str(self.root))

        self.assertIn("RESULT=install-already-running", result.stdout)
        self.assertIn("status=1", result.stdout)

    def test_lock_left_by_a_finished_installation_is_taken_over(self):
        command = r'''
source "$1"
set +e
install_lock="$2/install.lock"
mkdir -p "$install_lock"
print -r -- 999999 > "$install_lock/pid"
acquire_install_lock
print "owner=$(cat "$install_lock/pid") self=$$"
release_install_lock
[[ -e "$install_lock" ]] && print kept || print released
'''
        result = self.run_zsh(command, str(INSTALLER), str(self.root))
        owner, current = (
            line.split("=")[1]
            for line in result.stdout.split()[:2]
        )

        self.assertEqual(owner, current, result.stdout + result.stderr)
        self.assertIn("released", result.stdout)


class InstallerProcessUpdateTests(unittest.TestCase):
    def setUp(self):
        self.script = INSTALLER.read_text(encoding="utf-8")

    def test_stale_processes_are_stopped_after_the_files_are_replaced(self):
        replace = self.script.index(
            '/usr/bin/rsync -aE --checksum --delete \\\n'
            '        "$staged_destination/"'
        )
        stop = self.script.index(
            'if ! terminate_stale_processes "$installed_executable"'
        )
        register = self.script.index(
            '"$installed_executable" --register-input-source'
        )

        self.assertLess(replace, stop)
        self.assertLess(stop, register)

    def test_process_verification_is_retried_a_bounded_number_of_times(self):
        self.assertIn("process_update_attempts=3", self.script)
        self.assertIn("for attempt in {1..$process_update_attempts}", self.script)
        self.assertIn('sleep "$process_retry_interval"', self.script)

    def test_a_remaining_old_build_fails_the_installation(self):
        self.assertIn('echo "RESULT=process-update-failed"', self.script)
        self.assertIn("exit 4", self.script)
        self.assertIn("RUNNING_PROCESS pid=", self.script)

    def test_installation_steps_are_logged(self):
        for event in [
            "install start",
            "existing processes",
            "files placed",
            "process verified",
            "install finished",
            "install failed",
            "install incomplete",
        ]:
            self.assertIn(f'log_install "{event}', self.script)

    def test_installer_and_diagnostics_share_the_process_check(self):
        diagnostics = DIAGNOSTICS.read_text(encoding="utf-8")
        source = "Scripts/lib/myim-process-identity.sh"

        self.assertIn(source, self.script)
        self.assertIn(source, diagnostics)
        self.assertIn("myim_process_executable_state", self.script)
        self.assertIn("myim_process_executable_state", diagnostics)
        self.assertIn("PROCESS_EXECUTABLE=", diagnostics)
        self.assertIn('run_state="stale-executable"', diagnostics)
        self.assertIn("--expected-build", diagnostics)


if __name__ == "__main__":
    unittest.main()
