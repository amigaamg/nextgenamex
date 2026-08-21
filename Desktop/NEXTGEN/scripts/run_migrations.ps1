# Runs every migration file in database/migrations in order.
#
# Migrations already recorded in system.migration are SKIPPED, so this script
# is safe to re-run on an existing database. On a fresh database the registry
# does not exist yet and every migration runs.
[CmdletBinding()]
param()

. (Join-Path $PSScriptRoot 'amexan-config.ps1')

Ensure-Database

# Migrations applied so far (recorded by the ops registry in migration 049).
$applied = @{}
try {
    $rows = Invoke-PsqlText $script:PGDatabase "SELECT version FROM system.migration"
    foreach ($row in $rows) {
        $v = 0
        if ([int]::TryParse(($row -replace '\s',''), [ref]$v)) {
            $applied[$v] = $true
        }
    }
} catch {
    # Registry does not exist yet (fresh database) — run everything.
}

foreach ($migration in Get-MigrationFiles) {
    $version = [int]($migration.BaseName -replace '^(\d{3})_.*', '$1')

    if ($applied.ContainsKey($version)) {
        Write-Host "Skipping (already applied): $($migration.Name)"
        continue
    }

    Write-Host "Applying: $($migration.Name)"
    Invoke-Psql $script:PGDatabase $migration.FullName

    # Record into system.migration (if the ops registry exists yet).
    $name = $migration.Name -replace "'", "''"
    $record = "INSERT INTO system.migration (version, name, applied_by)
               VALUES ($version, '$name', CURRENT_USER)
               ON CONFLICT (version) DO UPDATE
                 SET name = EXCLUDED.name, applied_by = EXCLUDED.applied_by"
    try {
        Invoke-PsqlText $script:PGDatabase $record
    } catch {
        Write-Warning "Could not record $($migration.Name) in system.migration"
    }
}

Write-Host "All migrations applied to '$($script:PGDatabase)'."
