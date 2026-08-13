# Runs the H9 documentation compiler machine test.
[CmdletBinding()]
param()

. (Join-Path $PSScriptRoot 'amexan-config.ps1')

Invoke-Psql $script:PGDatabase (Join-Path $script:Root 'database\tests\amexan_machine_test_h9.sql')
Write-Host "H9 documentation compiler test passed."
