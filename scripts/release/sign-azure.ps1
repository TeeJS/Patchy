# Signs one file with Azure Artifact Signing (formerly Trusted Signing) and verifies it.
# build-release.bat calls this from :SignFile when PATCHY_SIGN_SCRIPT points here; the
# GitHub release workflow (.github/workflows/release-windows.yml) sets that up.
#
# PATCHY_SIGNING_DIR must hold dlib-x64\Azure.CodeSigning.Dlib.dll and a BOM-less
# metadata.json. Authentication comes from whatever credential metadata.json leaves
# enabled (the workflow uses the Azure CLI session from azure/login).
param([Parameter(Mandatory = $true)][string]$Path)

$ErrorActionPreference = 'Stop'

$signingDir = $env:PATCHY_SIGNING_DIR
if (-not $signingDir) { throw 'PATCHY_SIGNING_DIR is not set.' }
$dlib = Join-Path $signingDir 'dlib-x64\Azure.CodeSigning.Dlib.dll'
$metadata = Join-Path $signingDir 'metadata.json'
foreach ($required in @($dlib, $metadata, $Path)) {
  if (-not (Test-Path -LiteralPath $required)) { throw "Not found: $required" }
}

$signtool = Get-ChildItem "${env:ProgramFiles(x86)}\Windows Kits\10\bin" -Recurse -Filter signtool.exe |
  Where-Object { $_.Directory.Name -eq 'x64' } |
  Sort-Object FullName -Descending |
  Select-Object -First 1 -ExpandProperty FullName
if (-not $signtool) { throw 'signtool.exe (x64) was not found under the Windows 10 SDK.' }

& $signtool sign /v /fd SHA256 /tr 'http://timestamp.acs.microsoft.com' /td SHA256 /dlib $dlib /dmdf $metadata $Path
if ($LASTEXITCODE -ne 0) { throw "Signing failed for $Path (exit $LASTEXITCODE)." }

& $signtool verify /pa /v $Path
if ($LASTEXITCODE -ne 0) { throw "Signature verification failed for $Path (exit $LASTEXITCODE)." }
