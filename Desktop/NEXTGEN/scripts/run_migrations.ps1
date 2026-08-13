# Runs every migration file in database/migrations in order.
[CmdletBinding()]
param()

. (Join-Path $PSScriptRoot 'amexan-config.ps1')

Ensure-Database

foreach ($migration in Get-MigrationFiles) {
    Write-Host "Applying: $($migration.Name)"
    Invoke-Psql $script:PGDatabase $migration.FullName
}

Write-Host "All migrations applied to '$($script:PGDatabase)'."
