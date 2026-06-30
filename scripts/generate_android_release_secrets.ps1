param(
    [string]$OutputDirectory = ".release",
    [string]$Alias = "upload"
)

$ErrorActionPreference = "Stop"

function New-SecretValue {
    $bytes = New-Object byte[] 24
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $rng.GetBytes($bytes)
    } finally {
        $rng.Dispose()
    }
    return [Convert]::ToBase64String($bytes).Replace("+", "A").Replace("/", "B").Replace("=", "C")
}

$keytool = Get-Command keytool -ErrorAction Stop
$outputPath = Join-Path (Get-Location) $OutputDirectory
$keystorePath = Join-Path $outputPath "upload-keystore.jks"
$secretsPath = Join-Path $outputPath "github-actions-secrets.txt"

New-Item -ItemType Directory -Force -Path $outputPath | Out-Null

if (Test-Path $keystorePath) {
    throw "Keystore already exists at $keystorePath. Move it somewhere safe before generating a new one."
}

$keystorePassword = New-SecretValue
$keyPassword = New-SecretValue

& $keytool.Source `
    -genkeypair `
    -v `
    -keystore $keystorePath `
    -storetype JKS `
    -keyalg RSA `
    -keysize 2048 `
    -validity 10000 `
    -alias $Alias `
    -storepass $keystorePassword `
    -keypass $keyPassword `
    -dname "CN=Barangay Events, OU=Barangay Events, O=Barangay Events, L=San Jose del Monte, S=Bulacan, C=PH"

$keystoreFile = [Convert]::ToBase64String([IO.File]::ReadAllBytes($keystorePath))

@"
KEYSTORE_FILE=$keystoreFile
KEYSTORE_PASSWORD=$keystorePassword
KEY_ALIAS=$Alias
KEY_PASSWORD=$keyPassword
"@ | Set-Content -Path $secretsPath -Encoding UTF8

Write-Host "Created keystore: $keystorePath"
Write-Host "Created GitHub secrets file: $secretsPath"
Write-Host "Add each KEY=value pair as a repository secret in GitHub Actions."
