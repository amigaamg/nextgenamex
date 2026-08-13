# Runs the H9 documentation COMPLETION machine test (compile demo).
[CmdletBinding()]
param()

. (Join-Path $PSScriptRoot 'amexan-config.ps1')

Invoke-Psql $script:PGDatabase (Join-Path $script:Root 'database\tests\amexan_machine_test_h9_completion.sql')
Write-Host "H9 documentation completion test passed."
