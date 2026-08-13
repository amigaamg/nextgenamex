# Runs the H8 differential-reasoning COMPLETION machine test.
[CmdletBinding()]
param()

. (Join-Path $PSScriptRoot 'amexan-config.ps1')

Invoke-Psql $script:PGDatabase (Join-Path $script:Root 'database\tests\amexan_machine_test_h8_completion.sql')
Write-Host "H8 differential-reasoning completion test passed."