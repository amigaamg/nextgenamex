# Runs the Phase 1 acceptance test.
[CmdletBinding()]
param()

. (Join-Path $PSScriptRoot 'amexan-config.ps1')

Invoke-Psql $script:PGDatabase (Join-Path $script:Root 'database\tests\acceptance_test.sql')
Write-Host "Acceptance test passed."
