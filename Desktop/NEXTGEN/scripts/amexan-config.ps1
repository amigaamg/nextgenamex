# Shared connection configuration for AMEXAN scripts
# Override any value via environment variables.

$script:Root = Split-Path -Parent $PSScriptRoot
$script:Psql = "C:\Program Files\PostgreSQL\16\bin\psql.exe"

if (-not (Test-Path -LiteralPath $script:Psql)) {
    $script:Psql = "psql"
}

function Get-Env($Name, $Default) {
    $v = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrEmpty($v)) { return $Default }
    return $v
}

$script:PGHost      = Get-Env 'AMEXAN_PGHOST' 'localhost'
$script:PGPort      = Get-Env 'AMEXAN_PGPORT' '5432'
$script:PGSuperUser = Get-Env 'AMEXAN_PGSUPERUSER' 'postgres'
$script:PGSuperPass = Get-Env 'AMEXAN_PGSUPERPASSWORD' 'postgres'
$script:PGDatabase  = Get-Env 'AMEXAN_PGDATABASE' 'amexan'
$script:PGRole      = Get-Env 'AMEXAN_PGROLE' 'amexan'
$script:PGRolePass  = Get-Env 'AMEXAN_PGROLEPASSWORD' 'amexan'

function Invoke-Psql {
    param(
        [Parameter(Mandatory = $true)][string]$Database,
        [Parameter(Mandatory = $true)][string]$ScriptPath
    )
    $env:PGPASSWORD = $script:PGSuperPass
    & $script:Psql -U $script:PGSuperUser -h $script:PGHost -p $script:PGPort `
        -d $Database -v ON_ERROR_STOP=1 -f $ScriptPath
    if ($LASTEXITCODE -ne 0) {
        throw "psql failed (exit $LASTEXITCODE) on: $ScriptPath"
    }
}

function Invoke-PsqlText {
    param(
        [Parameter(Mandatory = $true)][string]$Database,
        [Parameter(Mandatory = $true)][string]$Sql
    )
    $env:PGPASSWORD = $script:PGSuperPass
    $Sql | & $script:Psql -U $script:PGSuperUser -h $script:PGHost -p $script:PGPort `
        -d $Database -v ON_ERROR_STOP=1 -qAt
    if ($LASTEXITCODE -ne 0) {
        throw "psql failed (exit $LASTEXITCODE)"
    }
}

function Ensure-Database {
    $exists = Invoke-PsqlText 'postgres' "SELECT 1 FROM pg_database WHERE datname = '$script:PGDatabase'"
    if ([string]::IsNullOrWhiteSpace($exists)) {
        Write-Host "Creating database '$($script:PGDatabase)' and role '$($script:PGRole)'..."
        Invoke-Psql 'postgres' (Join-Path $script:Root 'database\00_bootstrap.sql')
    }
}

function Get-MigrationFiles {
    Get-ChildItem -LiteralPath (Join-Path $script:Root 'database\migrations') `
        -Filter '*.sql' | Sort-Object Name
}
