# Runs the H6 physical-examination engine machine test.
[CmdletBinding()]
param()

. (Join-Path $PSScriptRoot 'amexan-config.ps1')

Invoke-Psql $script:PGDatabase (Join-Path $script:Root 'database\tests\amexan_machine_test_h6.sql')
Write-Host "H6 physical-examination engine test passed."
