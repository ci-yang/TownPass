"""Exercise the build entry point without creating an APK or requiring Flutter."""

import os
import subprocess
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().with_name("build-codefest.sh")


class BuildCodefestTest(unittest.TestCase):
    def run_script(self, url: str, *arguments: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["bash", str(SCRIPT), "--dry-run", *arguments],
            env={**os.environ, "CODEFEST_SERVICE_URL": url},
            capture_output=True,
            text=True,
            check=False,
        )

    def test_release_accepts_explicit_https_url(self) -> None:
        result = self.run_script("https://codefest.ciyang.dev/demo")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("build apk --release", result.stdout)
        self.assertIn(
            "--dart-define=CODEFEST_SERVICE_URL=https://codefest.ciyang.dev/demo",
            result.stdout,
        )
        self.assertIn("--enforce-lockfile", result.stdout)

    def test_check_prepares_configuration_without_apk(self) -> None:
        result = self.run_script("https://codefest.ciyang.dev", "--check")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("--config-only", result.stdout)

    def test_missing_url_fails_before_any_build_command(self) -> None:
        result = self.run_script("")
        self.assertEqual(result.returncode, 2)
        self.assertEqual(result.stdout, "")

    def test_insecure_or_malformed_urls_fail_before_build(self) -> None:
        for url in (
            "http://codefest.ciyang.dev",
            "https:///missing-host",
            "javascript:alert(1)",
            "https://user:password@codefest.ciyang.dev",
            "https://codefest.ciyang.dev:invalid",
            "https://codefest.ciyang.dev:70000",
            "https://codefest.ciyang.dev:0",
            "https://codefest.ciyang.dev/with space",
            "https://codefest.ciyang.dev/\nnew-line",
            "https://codefest.ciyang.dev/,ANOTHER_DEFINE=value",
            "https://codefest.ciyang.dev\\@10.0.2.2",
        ):
            with self.subTest(url=url):
                result = self.run_script(url)
                self.assertEqual(result.returncode, 2, result.stdout)
                self.assertEqual(result.stdout, "")

    def test_debug_http_requires_both_flags(self) -> None:
        for arguments in ((), ("--debug",), ("--allow-emulator-http",)):
            with self.subTest(arguments=arguments):
                result = self.run_script("http://10.0.2.2:5173", *arguments)
                self.assertEqual(result.returncode, 2)
        result = self.run_script(
            "http://10.0.2.2:5173", "--debug", "--allow-emulator-http"
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("build apk --debug", result.stdout)

    def test_http_exception_does_not_accept_other_hosts(self) -> None:
        for url in (
            "http://192.168.1.23:5173",
            "http://10.0.2.2.example.com:5173",
            "http://10.0.2.2@evil.example:5173",
        ):
            with self.subTest(url=url):
                result = self.run_script(url, "--debug", "--allow-emulator-http")
                self.assertEqual(result.returncode, 2)

    def test_extra_flags_cannot_override_url_or_build_mode(self) -> None:
        result = self.run_script(
            "https://codefest.ciyang.dev",
            "--dart-define=CODEFEST_SERVICE_URL=http://bad",
        )
        self.assertEqual(result.returncode, 2)


if __name__ == "__main__":
    unittest.main()
