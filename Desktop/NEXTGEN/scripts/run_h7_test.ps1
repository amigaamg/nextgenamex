# Runs the H7 investigation-engine machine test.
[CmdletBinding()]
param()

. (Join-Path $PSScriptRoot 'amexan-config.ps1')

Invoke-Psql $script:PGDatabase (Join-Path $script:Root 'database\tests\amexan_machine_test_h7.sql')
Write-Host "H7 investigation-selection engine test passed."