# One-shot: bootstrap DB -> migrations -> seed -> acceptance test -> machine test -> H6/H7/H8/H9/H10 tests.
[CmdletBinding()]
param()

. (Join-Path $PSScriptRoot 'amexan-config.ps1')

& (Join-Path $PSScriptRoot 'run_migrations.ps1')
& (Join-Path $PSScriptRoot 'seed.ps1')
& (Join-Path $PSScriptRoot 'run_acceptance.ps1')
& (Join-Path $PSScriptRoot 'run_machine_test.ps1')
& (Join-Path $PSScriptRoot 'run_h6_test.ps1')
& (Join-Path $PSScriptRoot 'run_h7_test.ps1')
& (Join-Path $PSScriptRoot 'run_h8_test.ps1')
& (Join-Path $PSScriptRoot 'run_h8_completion_test.ps1')
& (Join-Path $PSScriptRoot 'run_h9_test.ps1')
& (Join-Path $PSScriptRoot 'run_h9_completion_test.ps1')
& (Join-Path $PSScriptRoot 'run_h10_test.ps1')

Write-Host "`nAMEXAN Phase 1 foundation is fully installed, verified, and the machine tests pass (H1-H10)."
