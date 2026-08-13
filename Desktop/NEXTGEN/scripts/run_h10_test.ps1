# Runs the H10 provenance, governance & clinical knowledge control machine test.
[CmdletBinding()]
param()

. (Join-Path $PSScriptRoot 'amexan-config.ps1')

Invoke-Psql $script:PGDatabase (Join-Path $script:Root 'database\tests\amexan_machine_test_h10.sql')
Write-Host "H10 governance & knowledge control test passed."