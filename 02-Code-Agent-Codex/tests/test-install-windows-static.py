#!/usr/bin/env python3
"""Static regression checks for the Windows SAM-Codex setup.

The public test runner may not have PowerShell. These checks enforce the
security- and routing-critical PowerShell contract without making network
requests or reading a real API key.
"""

from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[1]
INSTALLER = (ROOT / "install-windows.ps1").read_text(encoding="utf-8")
WRAPPER = (ROOT / "templates" / "sam-codex.ps1").read_text(encoding="utf-8")
CONFIG = (ROOT / "templates" / "codex-config.toml").read_text(encoding="utf-8")


class WindowsSamCodexSetupTests(unittest.TestCase):
    def test_install_and_launch_request_versioned_cache_envelope(self) -> None:
        for script in (INSTALLER, WRAPPER):
            self.assertIn("Set-PSDebug -Off", script)
            self.assertGreaterEqual(script.count("Set-PSDebug -Off"), 2)
            self.assertIn("& codex --version", script)
            self.assertIn("^codex-cli (", script)
            self.assertIn("$versionOutput.Count -ne 1", script)
            self.assertIn("$versionPattern.Match(", script)
            self.assertIn(
                "$clientVersion -cnotmatch "
                "'^(?:0\\.145\\.[0-9]+|0\\.146\\.0)$'",
                script,
            )
            self.assertIn("?client_version={1}", script)
            self.assertIn('"x-sam-codex-cache" = "1"', script)
            self.assertIn("sam-v2-unified-codex-catalog", script)
            self.assertIn("https://sam.soonsoon.ai/v2/codex/models", script)
            self.assertIn("[DateTimeOffset]::TryParse(", script)
            self.assertIn(
                "[string]$catalog.client_version -cne $ExpectedClientVersion",
                script,
            )
            self.assertIn("-ExpectedClientVersion $ClientVersion", script)

    def test_cache_derives_a_unique_visible_selected_model(self) -> None:
        for script in (INSTALLER, WRAPPER):
            self.assertIn("[string]$model.visibility -cne \"list\"", script)
            self.assertIn("$model.supported_in_api -ne $true", script)
            self.assertIn(
                "$slug -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$'",
                script,
            )
            self.assertIn("$seenVisibleSlugs.ContainsKey($slug)", script)
            self.assertIn("$requiredHiddenSlugs = @(", script)
            self.assertIn(
                "$seenHiddenSlugs.Count -ne $requiredHiddenSlugs.Count",
                script,
            )
            self.assertIn("$visibleSlugs.Count -lt 1", script)
            self.assertIn("$visibleSlugs -ccontains $PreferredModel", script)
            self.assertIn("return $visibleSlugs[0]", script)

        self.assertIn('"model = `"$SelectedModel`""', INSTALLER)
        self.assertIn('"model=`"$SelectedModel`""', WRAPPER)
        self.assertIn("if (Test-Path $ConfigPath)", INSTALLER)
        self.assertIn(
            "$PreferredModel = Get-ConfiguredModelPreference -Path $PreferencePath",
            INSTALLER,
        )
        self.assertIn(
            '$PreferredModel = "azure.gpt-5.6-luna"',
            WRAPPER,
        )

    def test_cache_replacement_is_atomic_and_refresh_failure_is_fail_closed(self) -> None:
        for script in (INSTALLER, WRAPPER):
            self.assertIn("[System.IO.File]::Replace($CatalogTmp, $CatalogPath, $null)", script)
            self.assertIn("[System.IO.File]::Move($CatalogTmp, $CatalogPath)", script)
            self.assertNotIn("Move-Item -Force $CatalogTmp", script)

        self.assertIn("The previous cache was not changed, but SAM Codex did not start.", WRAPPER)
        self.assertNotIn("Using the last verified SAM model catalog.", WRAPPER)
        self.assertNotIn("Remove-Item -Force $CatalogPath", INSTALLER + WRAPPER)
        self.assertNotRegex(
            WRAPPER,
            r"Get-VerifiedSamCatalogModel\s+`\s+-Path\s+\$CatalogPath",
        )
        self.assertLess(
            WRAPPER.index("The previous cache was not changed, but SAM Codex did not start."),
            WRAPPER.rindex("& codex"),
        )

    def test_config_uses_exact_isolated_cache_and_same_v2_provider(self) -> None:
        self.assertIn('model_catalog_json = "models_cache.json"', CONFIG)
        self.assertIn('base_url = "https://sam.soonsoon.ai/v2/codex"', CONFIG)
        self.assertIn('env_key = "SAM_API_KEY"', CONFIG)
        self.assertIn('required = true', CONFIG)
        self.assertIn(
            'project_root_markers = [".git", ".sam-codex-root"]',
            CONFIG,
        )
        self.assertNotIn(".codex/config.toml", INSTALLER + WRAPPER)
        self.assertIn("$CatalogPathForToml = $CatalogPath.Replace('\\', '/')", WRAPPER)
        self.assertIn("-c 'model_provider=\"sam\"'", WRAPPER)
        self.assertIn('"model_catalog_json=`"$CatalogPathForToml`""', WRAPPER)
        self.assertIn("-c 'web_search=\"disabled\"'", WRAPPER)
        self.assertIn('$DefaultWorkspace = Join-Path $HOME "SAM-Codex"', WRAPPER)
        self.assertIn('Set-Location $DefaultWorkspace', WRAPPER)
        self.assertIn("[System.IO.File]::WriteAllText(", INSTALLER)
        self.assertIn("[System.Text.UTF8Encoding]::new($false)", INSTALLER)
        self.assertNotIn("Set-Content -Path $ConfigPath", INSTALLER)

    def test_wrapper_rejects_routing_overrides_before_codex(self) -> None:
        self.assertIn('"-c",', WRAPPER)
        self.assertIn('"--config",', WRAPPER)
        self.assertIn('"--model",', WRAPPER)
        self.assertIn('"--profile",', WRAPPER)
        self.assertIn('"--local-provider",', WRAPPER)
        self.assertIn(
            "SAM-Codex blocks model/provider/config override options.",
            WRAPPER,
        )
        self.assertLess(
            WRAPPER.index(
                "SAM-Codex blocks model/provider/config override options."
            ),
            WRAPPER.rindex("& codex"),
        )

    def test_static_custom_model_command_and_alias_list_are_removed(self) -> None:
        combined = INSTALLER + WRAPPER
        self.assertNotIn('if ($args.Count -gt 0 -and $args[0] -eq "model")', combined)
        self.assertNotIn("Choose a SAM model", combined)
        self.assertNotIn("$models = @(", combined)
        for stale_alias in (
            "azure.gpt-5.6-terra",
            "azure.gpt-5.6-sol",
            "azure.gpt-5.4",
            "aws.gpt-5.6-terra",
            "aws.gpt-5.6-sol",
            "aws.gpt-5.6-luna",
            "aws.gpt-5.5",
            "aws.gpt-5.4",
        ):
            self.assertNotIn(stale_alias, combined)

    def test_key_stays_in_existing_env_file_contract(self) -> None:
        self.assertIn('$EnvFile = Join-Path $SamHome "env.ps1"', INSTALLER)
        self.assertIn('$EnvFile = Join-Path $SamHome "env.ps1"', WRAPPER)
        self.assertNotIn("Set-Content -Path $EnvFile", INSTALLER)
        self.assertIn('WriteAllText($EnvTmp, "", $Utf8NoBom)', INSTALLER)
        self.assertIn(
            "[System.IO.File]::Replace($EnvTmp, $EnvFile, $null)",
            INSTALLER,
        )
        self.assertIn("icacls is required to protect the SAM key file.", INSTALLER)
        for script in (INSTALLER, WRAPPER):
            self.assertNotRegex(script, r"Write-(?:Host|Output).*SamApiKey")
            self.assertNotRegex(script, r"Write-(?:Host|Output).*SAM_API_KEY")
        self.assertIn("if ($LASTEXITCODE -ne 0)", INSTALLER)
        self.assertIn(
            "Could not restrict permissions on the existing SAM key file.",
            INSTALLER,
        )


if __name__ == "__main__":
    unittest.main()
