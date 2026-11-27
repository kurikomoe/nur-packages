"""Offline country-check regression against the installed launcher and tzdata."""

import os
import runpy
import subprocess
import sys
from unittest import TestCase
from unittest.mock import patch

check = runpy.run_path(sys.argv[1])["check_exit_country"]
case = TestCase()
with patch("subprocess.run") as fetch, patch.dict(os.environ):
    for zone, country in (
        ("Asia/Tokyo", "JP"),
        ("America/New_York", "US"),
        ("America/Los_Angeles", "US"),
        # Copenhagen and Berlin share clock rules but have separate countries.
        ("Europe/Copenhagen", "DK"),
    ):
        os.environ["TZ"] = zone
        fetch.return_value = subprocess.CompletedProcess(
            [], 0, f"loc={country}\n\n200".encode()
        )
        check()

    for response, error in (
        (b"loc=DE\n\n200", "does not match"),
        (b"colo=CPH\n\n200", "no unique country"),
        (b"loc=DK\nloc=DE\n\n200", "no unique country"),
        (b"loc=DK\n\n302", "lookup .* failed"),
        (b"loc=DK\n\n503", "lookup .* failed"),
    ):
        fetch.return_value = subprocess.CompletedProcess([], 0, response)
        with case.assertRaisesRegex(RuntimeError, error):
            check()

    fetch.return_value = subprocess.CompletedProcess([], 28, b"\n000")
    with case.assertRaisesRegex(RuntimeError, "curl 28"):
        check()
    os.environ["TZ"] = "Etc/UTC"
    fetch.reset_mock()
    with case.assertRaisesRegex(ValueError, "cannot determine country"):
        check()
    fetch.assert_not_called()
