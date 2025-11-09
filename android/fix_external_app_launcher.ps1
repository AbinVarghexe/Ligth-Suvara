# PowerShell script to fix external_app_launcher namespace issue (if needed)
# This script patches the build.gradle file to add the namespace for older versions
# Note: Version 4.0.3+ already has the namespace set, so this script may not be needed

$versions = @("4.0.3", "3.1.0")
$fixed = $false

foreach ($version in $versions) {
    $pubCachePath = "$env:LOCALAPPDATA\Pub\Cache\hosted\pub.dev\external_app_launcher-$version\android\build.gradle"
    
    if (Test-Path $pubCachePath) {
        $content = Get-Content $pubCachePath -Raw
        
        # Check if namespace is already set
        if ($content -notmatch 'namespace\s+') {
            # Check if android block exists
            if ($content -match 'android\s*\{') {
                # Add namespace right after android {
                $packageName = 'com.example.launchexternalapp'
                $content = $content -replace '(android\s*\{)', "`$1`n    namespace '$packageName'"
                
                # Write back to file
                Set-Content -Path $pubCachePath -Value $content -NoNewline
                Write-Host "Successfully added namespace to external_app_launcher $version" -ForegroundColor Green
                $fixed = $true
            } else {
                Write-Host "Could not find android block in build.gradle for version $version" -ForegroundColor Yellow
            }
        } else {
            Write-Host "Namespace already set in external_app_launcher $version" -ForegroundColor Cyan
        }
        break
    }
}

if (-not $fixed) {
    Write-Host "Could not find external_app_launcher build.gradle in pub cache" -ForegroundColor Red
    Write-Host "Please run 'flutter pub get' first" -ForegroundColor Yellow
}

