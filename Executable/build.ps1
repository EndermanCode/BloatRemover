$ErrorActionPreference = "Stop"

$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (-not (Test-Path $vswhere)) {
    Write-Error "Visual Studio Build Tools not found. Install 'Build Tools for Visual Studio' and try again."
}

$vsPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $vsPath) {
    Write-Error "MSVC toolchain not found. Install the C++ build tools and try again."
}

$vcvars = Join-Path $vsPath "VC\Auxiliary\Build\vcvars64.bat"
if (-not (Test-Path $vcvars)) {
    Write-Error "vcvars64.bat not found at: $vcvars"
}

$src = Join-Path $PSScriptRoot "BloatRemoverGui.cpp"
$out = Join-Path $PSScriptRoot "BloatRemoverGui.exe"

cmd /c "`"$vcvars`" && cl /nologo /EHsc /DUNICODE /D_UNICODE `"$src`" /link user32.lib gdi32.lib advapi32.lib comdlg32.lib comctl32.lib shlwapi.lib /SUBSYSTEM:WINDOWS /MANIFEST:EMBED /MANIFESTUAC:`"level='requireAdministrator' uiAccess='false'`" /OUT:`"$out`""

if ($LASTEXITCODE -ne 0) {
    Write-Error "Build failed with exit code $LASTEXITCODE"
}

Write-Host "Built: $out"
