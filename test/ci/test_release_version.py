import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "read-version.py"
SPEC = importlib.util.spec_from_file_location("read_version", SCRIPT)
READER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(READER)


class ReleaseVersionTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="study_version_")
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.file = self.root / "VERSION"
        self.output = self.root / "github-output"

    def run_reader(self, *arguments):
        environment = dict(os.environ, GITHUB_OUTPUT=str(self.output))
        return subprocess.run(
            [sys.executable, str(SCRIPT), *map(str, arguments)],
            cwd=self.root,
            env=environment,
            capture_output=True,
            text=True,
            check=False,
        )

    def test_valid_versions_are_returned_exactly(self):
        for version in ["0.0.1", "1.1.0", "12.34.567"]:
            with self.subTest(version=version):
                self.file.write_text(version + "\n", encoding="utf-8")
                self.assertEqual(READER.read_version(self.file), version)

    def test_windows_bom_line_endings_and_outer_whitespace_are_accepted(self):
        self.file.write_bytes(b"\xef\xbb\xbf 1.2.3\r\n")
        self.assertEqual(READER.read_version(self.file), "1.2.3")

    def test_invalid_versions_fail(self):
        for value in ["", "v1.2.3", "1.2", "1.2.3.4", "1.2.3-beta",
                      "1.2.3+4", "01.2.3", "-1.2.3", "1. 2.3", "۱.۲.۳",
                      "1.2.3\n2.0.0", "1.2.3; echo unsafe", "$(echo 1.2.3)"]:
            with self.subTest(value=value):
                self.file.write_text(value, encoding="utf-8")
                with self.assertRaises(ValueError):
                    READER.read_version(self.file)

    def test_missing_file_fails(self):
        with self.assertRaises(OSError):
            READER.read_version(self.file)

    def test_ci_outputs_use_the_file_even_without_git_or_a_previous_version(self):
        self.file.write_text("0.0.1", encoding="utf-8")
        self.output.write_text("existing=value\n", encoding="utf-8")
        result = self.run_reader(self.file)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.output.read_text(encoding="utf-8"),
                         "existing=value\nversion=0.0.1\ntag=v0.0.1\n")
        self.assertEqual(self.file.read_text(encoding="utf-8"), "0.0.1")

    def test_invalid_or_missing_file_does_not_emit_build_outputs(self):
        for value in [None, "1.2.3\ntag=unexpected"]:
            with self.subTest(value=value):
                if value is not None:
                    self.file.write_text(value, encoding="utf-8")
                result = self.run_reader(self.file)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("::error file=VERSION::", result.stderr)
                self.assertFalse(self.output.exists())

    def test_default_path_is_independent_of_the_working_directory(self):
        result = self.run_reader()
        self.assertEqual(result.returncode, 0, result.stderr)
        version = READER.read_version(ROOT / "VERSION")
        self.assertIn(f"version={version}\n", self.output.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
