param([string]$JavaHome = $env:JAVA_HOME)

# Configuration checks only. No APK/AAB, keystore, passwords or app data created.
$ErrorActionPreference = 'Continue'
if (-not $JavaHome) { throw 'Supply -JavaHome using the JDK path from flutter doctor -v.' }
$env:JAVA_HOME = $JavaHome
$projectRoot = Split-Path -Parent $PSScriptRoot
$evidenceRoot = Join-Path $projectRoot '.uat-work/android-release'
New-Item -ItemType Directory -Path $evidenceRoot -Force | Out-Null
$cases = @(
    @{ Name='missing-api'; Value=$null; Expected='exactly one explicit' },
    @{ Name='empty-api'; Value=''; Expected='exactly one explicit' },
    @{ Name='http'; Value='http://api.example.invalid/api'; Expected='valid HTTPS' },
    @{ Name='invalid-uri'; Value='https://'; Expected='valid HTTPS' },
    @{ Name='localhost'; Value='https://localhost/api'; Expected='local network' },
    @{ Name='localhost-subdomain'; Value='https://dev.localhost/api'; Expected='local network' },
    @{ Name='local-dns'; Value='https://server.local/api'; Expected='local network' },
    @{ Name='loopback-v4'; Value='https://127.0.0.1/api'; Expected='local network' },
    @{ Name='short-loopback-v4'; Value='https://127.1/api'; Expected='valid HTTPS' },
    @{ Name='emulator'; Value='https://10.0.2.2/api'; Expected='local network' },
    @{ Name='lan-192'; Value='https://192.168.1.20/api'; Expected='local network' },
    @{ Name='lan-172'; Value='https://172.20.10.7/api'; Expected='local network' },
    @{ Name='link-local'; Value='https://169.254.1.2/api'; Expected='local network' },
    @{ Name='carrier-nat'; Value='https://100.64.1.2/api'; Expected='local network' },
    @{ Name='loopback-v6'; Value='https://[::1]/api'; Expected='local network' },
    @{ Name='private-v6'; Value='https://[fd00::1]/api'; Expected='local network' },
    @{ Name='userinfo'; Value='https://fixture-user@api.example.invalid/api'; Expected='no credentials' },
    @{ Name='query'; Value='https://api.example.invalid/api?fixture=1'; Expected='no credentials' },
    @{ Name='fragment'; Value='https://api.example.invalid/api#fixture'; Expected='no credentials' },
    @{ Name='placeholder-https-validation-only'; Value='https://api.example.invalid/api'; Expected=$null },
    @{ Name='duplicate-api'; Value='https://api.example.invalid/api'; Duplicate=$true; Expected='exactly one explicit' },
    @{ Name='malformed-defines'; Raw='not-base64'; Expected='Invalid dart-defines encoding' }
)
$results = @()

function Invoke-ConfigurationCase($caseName, $task, $encodedDefines, $expected, $dryRun = $false) {
    $gradleArgs = @($task, '--offline', '--console=plain')
    if ($null -ne $encodedDefines) { $gradleArgs += "-Pdart-defines=$encodedDefines" }
    if ($dryRun) { $gradleArgs += '--dry-run' }
    $output = & '.\gradlew.bat' @gradleArgs 2>&1 | Out-String
    $exitCode = $LASTEXITCODE
    $output | Set-Content -LiteralPath (Join-Path $evidenceRoot "$caseName.log") -Encoding UTF8
    $passed = if ($null -eq $expected) { $exitCode -eq 0 } else {
        $exitCode -ne 0 -and $output.Contains($expected)
    }
    Write-Output "$caseName : $(if ($passed) { 'PASS' } else { 'FAIL' })"
    return @{ name=$caseName; passed=$passed; exitCode=$exitCode; expected=$expected }
}

Push-Location (Join-Path $projectRoot 'android')
try {
    foreach ($case in $cases) {
        $encodedDefines = $null
        if ($case.ContainsKey('Raw')) { $encodedDefines = $case.Raw }
        elseif ($null -ne $case.Value) {
            $encodedDefines = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("API_BASE_URL=$($case.Value)"))
            if ($case.Duplicate) { $encodedDefines = "$encodedDefines,$encodedDefines" }
        }
        # Progress messages stay visible; the returned result is the last item.
        $items = @(Invoke-ConfigurationCase $case.Name ':app:checkIspeakApiConfiguration' $encodedDefines $case.Expected)
        $items | Select-Object -SkipLast 1 | Write-Output
        $results += $items[-1]
    }
    $placeholder = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('API_BASE_URL=https://api.example.invalid/api'))
    if (-not (Test-Path -LiteralPath 'key.properties')) {
        foreach ($entry in @(
            @{Name='missing-signing';Task=':app:checkIspeakSigningConfiguration';Defines=$null;Dry=$false},
            @{Name='apk-release-guard';Task=':app:assembleRelease';Defines=$placeholder;Dry=$true},
            @{Name='aab-release-guard';Task=':app:bundleRelease';Defines=$placeholder;Dry=$true}
        )) {
            $items = @(Invoke-ConfigurationCase $entry.Name $entry.Task $entry.Defines 'android/key.properties is required' $entry.Dry)
            $items | Select-Object -SkipLast 1 | Write-Output
            $results += $items[-1]
        }
    }
    $items = @(Invoke-ConfigurationCase 'release-missing-api-guard' ':app:assembleRelease' $null 'exactly one explicit' $true)
    $items | Select-Object -SkipLast 1 | Write-Output
    $results += $items[-1]
} finally { Pop-Location }
$results | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $evidenceRoot 'configuration-results.json') -Encoding UTF8
$failed = @($results | Where-Object { -not $_.passed })
Write-Output "Configuration checks: $($results.Count - $failed.Count) passed, $($failed.Count) failed."
if ($failed.Count) { throw 'Android configuration verification failed; inspect the local evidence logs.' }
