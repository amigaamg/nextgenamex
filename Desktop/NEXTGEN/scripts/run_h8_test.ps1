# Runs the H8 differential-reasoning machine test.
[CmdletBinding()]
param()

. (Join-Path $PSScriptRoot 'amexan-config.ps1')

Invoke-Psql $script:PGDatabase (Join-Path $script:Root 'database\tests\amexan_machine_test_h8.sql')
Write-Host "H8 differential-reasoning engine test passed."
