# Runs the AMEXAN machine test (CAP nephron proof) against the live knowledge graph.
[CmdletBinding()]
param()

. (Join-Path $PSScriptRoot 'amexan-config.ps1')

Invoke-Psql $script:PGDatabase (Join-Path $script:Root 'database\tests\amexan_machine_test.sql')
Write-Host "Machine test passed."
