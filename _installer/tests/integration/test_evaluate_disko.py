"""Integration test for disko script building.

MANUAL TEST — run with: pytest -m manual tests/integration/test_evaluate_disko.py -v

Tests that the flake's diskoScript attribute can be built locally.
"""

import subprocess
from pathlib import Path

import pytest

# path to the test flake fixture
FIXTURE_DIR = Path(__file__).parent.parent / "fixtures" / "test_flake"

_NIX_FLAGS = ["--option", "experimental-features", "nix-command flakes"]


@pytest.mark.manual
class TestBuildDiskoScript:
    def test_nix_build_produces_disko_script(self):
        """nix build produces a disko script store path."""
        flake_ref = f"{FIXTURE_DIR}#nixosConfigurations.test-host.config.system.build.diskoScript"

        result = subprocess.run(
            [
                "nix",
                "build",
                *_NIX_FLAGS,
                flake_ref,
                "--no-link",
                "--print-out-paths",
            ],
            capture_output=True,
            text=True,
        )

        assert result.returncode == 0, f"nix build failed:\n{result.stderr}"
        store_path = result.stdout.strip()
        assert store_path.startswith("/nix/store/")
