# Seeds reference/lookup data.
[CmdletBinding()]
param()

. (Join-Path $PSScriptRoot 'amexan-config.ps1')

Ensure-Database

$seedDir = Join-Path $script:Root 'database\seed'
foreach ($seed in (Get-ChildItem -LiteralPath $seedDir -Filter 'seed_*.sql' | Sort-Object Name)) {
    Write-Host "Seeding: $($seed.Name)"
    Invoke-Psql $script:PGDatabase $seed.FullName
}

Write-Host "Reference data seeded."
