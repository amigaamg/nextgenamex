param()
Set-Location 'C:\Users\Administrator\Desktop\NEXTGEN'
$env:PGPASSWORD = 'postgres'
& 'scripts\reset.ps1' > $null 2>&1
$log = & 'scripts\run_all.ps1' 2>&1
$log | Out-File -FilePath 'runall.log' -Encoding utf8
Write-Host '=== VERDICT ==='
($log | Select-String -Pattern 'passed','FAIL','ERROR','psql failed','fully installed' -SimpleMatch).Line
Write-Host '--- TAIL ---'
$log | Select-Object -Last 8
