# RMT.Update.exe 编译脚本（不依赖 VS 工程，直接用 .NET Framework 自带的 csc）
# 用法：.\build.ps1 [-NoPause]
# 产物：Plugins\Update\RMT.Update.exe（AnyCPU，x86/x64 发行包共用一份）
param(
    [switch]$NoPause
)

$ErrorActionPreference = "Stop"
$SrcDir = $PSScriptRoot
$OutExe = Join-Path $SrcDir "RMT.Update.exe"
$ErrLog = Join-Path $env:TEMP "RMT-update-build.log"

function Find-Csc {
    $candidates = New-Object System.Collections.Generic.List[string]
    $roots = @()
    if ($env:ProgramFiles) { $roots += $env:ProgramFiles }
    $pf86 = [Environment]::GetEnvironmentVariable("ProgramFiles(x86)")
    if ($pf86) { $roots += $pf86 }

    $years = @("2022", "2019", "2017")
    $editions = @("Enterprise", "Professional", "Community", "BuildTools")
    foreach ($root in $roots) {
        foreach ($y in $years) {
            foreach ($e in $editions) {
                $p = Join-Path $root ("Microsoft Visual Studio\{0}\{1}\MSBuild\Current\Bin\Roslyn\csc.exe" -f $y, $e)
                if (Test-Path -LiteralPath $p) { [void]$candidates.Add($p) }
            }
        }
    }

    $fw64 = Join-Path $env:WINDIR "Microsoft.NET\Framework64\v4.0.30319\csc.exe"
    $fw32 = Join-Path $env:WINDIR "Microsoft.NET\Framework\v4.0.30319\csc.exe"
    if (Test-Path -LiteralPath $fw64) { [void]$candidates.Add($fw64) }
    if (Test-Path -LiteralPath $fw32) { [void]$candidates.Add($fw32) }

    foreach ($c in $candidates) {
        if (Test-Path -LiteralPath $c) { return $c }
    }
    return $null
}

$csc = Find-Csc
if (-not $csc) {
    Write-Host "ERROR: csc.exe not found (.NET Framework 4.x or VS Build Tools required)" -ForegroundColor Red
    if (-not $NoPause) { Read-Host "Press Enter" }
    exit 1
}

$fwLib = Join-Path $env:WINDIR "Microsoft.NET\Framework64\v4.0.30319"
if (-not (Test-Path -LiteralPath $fwLib)) {
    $fwLib = Join-Path $env:WINDIR "Microsoft.NET\Framework\v4.0.30319"
}

$sources = @(Get-ChildItem -LiteralPath $SrcDir -Filter "*.cs" | Sort-Object Name | ForEach-Object { $_.FullName })
if ($sources.Count -lt 1) {
    Write-Host "ERROR: no .cs files in $SrcDir" -ForegroundColor Red
    if (-not $NoPause) { Read-Host "Press Enter" }
    exit 1
}

if (Test-Path -LiteralPath $OutExe) {
    try {
        Remove-Item -LiteralPath $OutExe -Force -ErrorAction Stop
    } catch {
        Write-Host "ERROR: RMT.Update.exe is locked (an update may be running). Retry later." -ForegroundColor Red
        if (-not $NoPause) { Read-Host "Press Enter" }
        exit 1
    }
}

$refNames = @(
    "System.dll",
    "System.Core.dll",
    "System.Drawing.dll",
    "System.Windows.Forms.dll",
    "System.IO.Compression.dll",
    "System.IO.Compression.FileSystem.dll",
    "System.Xml.dll"
)
$refArgs = @()
foreach ($name in $refNames) {
    $p = Join-Path $fwLib $name
    if (Test-Path -LiteralPath $p) {
        $refArgs += "/reference:`"$p`""
    } else {
        Write-Host "WARN: missing reference $p" -ForegroundColor Yellow
    }
}

$icon = Join-Path (Split-Path -Parent (Split-Path -Parent $SrcDir)) "Images\Soft\rabit.ico"
$iconArg = @()
if (Test-Path -LiteralPath $icon) { $iconArg += "/win32icon:`"$icon`"" }

$srcArgs = @()
foreach ($s in $sources) { $srcArgs += "`"$s`"" }

# C# 5 语法即可（csc v4.0.30319）：不要引入字符串插值、?.、nameof 之类的 C# 6+ 写法。
$argList = @(
    "/nologo", "/target:winexe", "/platform:anycpu", "/optimize+",
    "/out:`"$OutExe`"", "/lib:`"$fwLib`""
) + $refArgs + $iconArg + $srcArgs

cmd.exe /c "`"$csc`" $($argList -join ' ') > `"$ErrLog`" 2>&1"
$code = $LASTEXITCODE

if ($code -ne 0 -or -not (Test-Path -LiteralPath $OutExe)) {
    Write-Host "ERROR: compile failed (exit $code). Log: $ErrLog" -ForegroundColor Red
    if (Test-Path -LiteralPath $ErrLog) { Get-Content -LiteralPath $ErrLog | Write-Host }
    if (-not $NoPause) { Read-Host "Press Enter" }
    exit 1
}

$size = [math]::Round((Get-Item -LiteralPath $OutExe).Length / 1KB, 1)
Write-Host "OK: $OutExe ($size KB)" -ForegroundColor Green
if (-not $NoPause) { Read-Host "Press Enter" }
exit 0
