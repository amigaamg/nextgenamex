# Drops and recreates the AMEXAN database from scratch.
[CmdletBinding()]
param()

. (Join-Path $PSScriptRoot 'amexan-config.ps1')

$env:PGPASSWORD = $script:PGSuperPass
& $script:Psql -U $script:PGSuperUser -h $script:PGHost -p $script:PGPort `
    -d 'postgres' -v ON_ERROR_STOP=1 -qAt `
    -c "DROP DATABASE IF EXISTS `"$script:PGDatabase`" WITH (FORCE)"
if ($LASTEXITCODE -ne 0) { throw "Could not drop database." }

Write-Host "Database '$($script:PGDatabase)' dropped."
