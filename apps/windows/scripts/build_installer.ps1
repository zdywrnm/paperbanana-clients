param(
  [string]$Version = "0.1.1",
  [string]$Configuration = "Release",
  [string]$DotnetPath = "B:\tools\dotnet\dotnet.exe",
  [string]$InnoCompilerPath = "B:\tools\InnoSetup6\ISCC.exe"
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectDir = Resolve-Path (Join-Path $scriptDir "..")
$repoRoot = Resolve-Path (Join-Path $projectDir "..\..")
$projectFile = Join-Path $projectDir "PaperBanana.Windows.csproj"
$publishDir = Join-Path $projectDir "artifacts\publish"
$installerDir = Join-Path $projectDir "artifacts\installer"
$innoScript = Join-Path $projectDir "installer\PaperBanana.Windows.iss"

if (!(Test-Path $DotnetPath)) {
  throw "dotnet SDK not found: $DotnetPath"
}
if (!(Test-Path $InnoCompilerPath)) {
  throw "Inno Setup compiler not found: $InnoCompilerPath"
}

Remove-Item -LiteralPath $publishDir -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $installerDir -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $publishDir, $installerDir | Out-Null

Push-Location $repoRoot
try {
  & $DotnetPath publish $projectFile `
    -c $Configuration `
    -r win-x64 `
    --self-contained true `
    -p:Version=$Version `
    -p:AssemblyVersion="$Version.0" `
    -p:FileVersion="$Version.0" `
    -p:PublishSingleFile=false `
    -o $publishDir
  if ($LASTEXITCODE -ne 0) {
    throw "dotnet publish failed with exit code $LASTEXITCODE"
  }

  $buildOutput = Join-Path $projectDir "bin\$Configuration\net8.0-windows10.0.19041.0\win-x64"
  Get-ChildItem -LiteralPath $buildOutput -File | Where-Object { $_.Extension -eq ".xbf" -or $_.Name -eq "PaperBanana.Windows.pri" } | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $publishDir $_.Name) -Force
  }

  $env:PAPERBANANA_WINDOWS_VERSION = $Version
  & $InnoCompilerPath $innoScript
  if ($LASTEXITCODE -ne 0) {
    throw "Inno Setup failed with exit code $LASTEXITCODE"
  }
}
finally {
  Pop-Location
  Remove-Item Env:PAPERBANANA_WINDOWS_VERSION -ErrorAction SilentlyContinue
}

$installer = Join-Path $installerDir "PaperBanana-Windows-Native-$Version-Setup.exe"
if (!(Test-Path $installer)) {
  throw "Installer was not created: $installer"
}

$hash = Get-FileHash -Algorithm SHA256 -LiteralPath $installer
$hashLine = "$($hash.Hash)  $(Split-Path -Leaf $installer)"
$hashPath = "$installer.sha256"
Set-Content -LiteralPath $hashPath -Value $hashLine -Encoding ASCII

Write-Output "Installer: $installer"
Write-Output "SHA256: $hashPath"
