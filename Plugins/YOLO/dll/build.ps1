# ================================================================================
# YOLOs-DLL 独立打包脚本 (Windows/PowerShell)
# ================================================================================
# 将 YOLOs-CPP 仓库编译为独立 DLL，自动处理全部依赖链。
#
# Usage:
#   .\build.ps1 -YolosPath C:\path\to\YOLOs-CPP
#   .\build.ps1 -YolosPath C:\path\to\YOLOs-CPP -Download
#   .\build.ps1 -YolosPath C:\path\to\YOLOs-CPP -Clean
#   .\build.ps1 -Help
#
# 输出: build\Release\ 下的完整运行时文件集（可直接分发）
# ================================================================================

param(
    [Parameter(Mandatory=$false, HelpMessage="YOLOs-CPP 仓库根目录路径")]
    [string]$YolosPath = "",

    [string]$Version = "1.24.4",
    [switch]$Clean,
    [switch]$Help,
    [switch]$Download,
    [string]$OpenCV_DIR = ""
)

if ($Help) {
    Write-Host @"

YOLOs-DLL — 将 YOLOs-CPP 编译为独立 DLL 的打包工具

Usage:
    .\build.ps1 -YolosPath <YOLOs-CPP仓库路径> [选项]

必需参数:
    -YolosPath <path>    YOLOs-CPP 仓库根目录（包含 include/ src/ 的目录）

可选参数:
    -Version <ver>       ONNX Runtime 版本 (默认: $Version)
    -OpenCV_DIR <path>   OpenCV 安装目录 (默认自动探测)
    -Clean               清理后重新构建
    -Download            自动下载缺失的 ONNX Runtime
    -Help                显示本帮助

前置条件:
    1) 已克隆 YOLOs-CPP: git clone https://github.com/Geekgineer/YOLOs-CPP
    2) 已安装 OpenCV (Windows Pack) 或设置 OpenCV_DIR
    3) 已安装 CMake + MSVC (Visual Studio Build Tools)
    4) ONNX Runtime (可设环境变量 ONNXRUNTIME_DIR 或用 -Download 自动下载)

输出:
    dll/
      yolos.dll              主库
      yolos.lib              导入库
      onnxruntime.dll        推理引擎
      opencv_worldXXX.dll    图像处理

"@ -ForegroundColor White
    exit 0
}

$ErrorActionPreference = "Stop"

# ============================================================================
# 路径定义
# ============================================================================
$ScriptDir    = Split-Path -Parent $MyInvocation.MyCommand.Path
$BuildDir     = Join-Path $ScriptDir "build"
$ReleaseDir   = Join-Path $BuildDir "Release"
$LocalInclude = Join-Path $ScriptDir "include"           # 同步后的本地头文件
$OrtDir       = Join-Path $ScriptDir "onnxruntime-win-x64-$Version"
$OrtZip       = Join-Path $ScriptDir "onnxruntime.zip"
$OrtUrl       = "https://github.com/microsoft/onnxruntime/releases/download/v$Version/onnxruntime-win-x64-$Version.zip"

function Write-Step([string]$Text) {
    Write-Host ""
    Write-Host "--- $Text ---" -ForegroundColor Cyan
}

function Write-OK([string]$Text = "OK") {
    Write-Host "  [$Text]" -ForegroundColor Green
}

function Write-Fail([string]$Text) {
    Write-Host "  [$Text]" -ForegroundColor Red
}

Write-Host ""
Write-Host ("=" * 56) -ForegroundColor Green
Write-Host "  YOLOs-DLL 独立打包工具" -ForegroundColor Green
Write-Host ("=" * 56) -ForegroundColor Green

# ============================================================================
# 验证 / 解析 YolosPath
# ============================================================================
Write-Step "Step 1/6: 定位 YOLOs-CPP 仓库"

# 按优先级查找 YOLOs-CPP 位置
$ResolvedYolos = ""

if ($YolosPath) {
    $ResolvedYolos = $YolosPath
} elseif (Test-Path (Join-Path $ScriptDir "..\YOLOs-CPP")) {
    $ResolvedYolos = (Join-Path $ScriptDir "..\YOLOs-CPP") | Resolve-Path
} elseif (Test-Path (Join-Path $ScriptDir "..")) {
    # 假设 dll/ 就在 YOLOs-CPP 内部（开发模式）
    $Candidate = (Join-Path $ScriptDir "..") | Resolve-Path
    if ((Test-Path (Join-Path $Candidate "include\yolos\yolos.hpp"))) {
        $ResolvedYolos = $Candidate
    }
}

if (-not $ResolvedYolos) {
    Write-Host ""
    Write-Fail "ERROR] 未找到 YOLOs-CPP 仓库！" 
    Write-Host ""
    Write-Host "  请用 -YolosPath 指定路径:" -ForegroundColor Yellow
    Write-Host "    .\build.ps1 -YolosPath C:\dev\YOLOs-CPP" -ForegroundColor White
    Write-Host ""
    Write-Host "  或确保以下任一条件成立:" -ForegroundColor Yellow
    Write-Host "    1) 同级目录存在 YOLOs-CPP/ 文件夹" -ForegroundColor White
    Write-Host "    2) 本脚本位于 YOLOs-CPP\dll\ 内部" -ForegroundColor White
    Write-Host ""
    exit 1
}

$ResolvedYolos = $ResolvedYolos.ToString().TrimEnd([char]'\', [char]'/')
$YolosInclude = Join-Path $ResolvedYolos "include"
$YolosSrc     = Join-Path $ResolvedYolos "src"
$YolosHeader  = Join-Path $YolosInclude "yolos\yolos.hpp"

if (-not (Test-Path $YolosHeader)) {
    Write-Fail "ERROR] 指定路径缺少头文件: $YolosHeader"
    Write-Host "  请确认 -YolosPath 指向正确的 YOLOs-CPP 仓库根目录。" -ForegroundColor Yellow
    exit 1
}

Write-Host "  YOLOs-CPP: $ResolvedYolos" -ForegroundColor White
Write-OK

# ============================================================================
# 同步头文件到本地
# ============================================================================
Write-Step "Step 2/6: 同步头文件 -> include/"

# 清理旧缓存
if (Test-Path $LocalInclude) {
    Remove-Item $LocalInclude -Recurse -Force
}
New-Item -ItemType Directory -Path $LocalInclude -Force | Out-Null

# 复制整个 yolos/ 目录
$SrcYolosDir = Join-Path $YolosInclude "yolos"
Copy-Item -Path $SrcYolosDir -Destination $LocalInclude -Recurse -Force

# 复制 tools/ (如果有)
$SrcTools = Join-Path $YolosInclude "tools"
if (Test-Path $SrcTools) {
    Copy-Item -Path $SrcTools -Destination $LocalInclude -Recurse -Force
}

$FileCount = (Get-ChildItem $LocalInclude -Recurse -File).Count
Write-Host "  已同步 $FileCount 个头文件 -> include/" -ForegroundColor White

# 复制自定义 C API 头文件（YOLOs-CPP 原仓库不包含此文件，存放在 src/ 中）
$SrcCustomHeader = Join-Path $ScriptDir "src\yolos_c_api.hpp"
$DstCustomHeader = Join-Path $LocalInclude "yolos\core\yolos_c_api.hpp"
if (Test-Path $SrcCustomHeader) {
    New-Item -ItemType Directory -Path (Split-Path $DstCustomHeader) -Force | Out-Null
    Copy-Item $SrcCustomHeader $DstCustomHeader -Force
    Write-Host "  已复制 yolos_c_api.hpp -> include/yolos/core/" -ForegroundColor DarkGray
} else {
    Write-Fail "自定义头文件缺失: src\yolos_c_api.hpp"
    exit 1
}

Write-OK

# ============================================================================
# 下载 / 检查 ONNX Runtime
# ============================================================================
Write-Step "Step 3/6: 准备 ONNX Runtime"

$OrtFound = $false

# 按优先级搜索: 环境变量 -> 本地默认目录 -> 本地其他版本 -> 常见安装位置
function Test-OrtDir([string]$Dir) {
    (Test-Path "$Dir\include\onnxruntime_cxx_api.h")
}

# 1) 环境变量 ONNXRUNTIME_DIR
if ($env:ONNXRUNTIME_DIR -and (Test-OrtDir $env:ONNXRUNTIME_DIR)) {
    $OrtDir = $env:ONNXRUNTIME_DIR
    $OrtFound = $true
    Write-Host "  从环境变量找到: `$env:ONNXRUNTIME_DIR" -ForegroundColor Cyan
}
# 2) 本地默认目录 (dll\onnxruntime-win-x64-$Version)
elseif (Test-OrtDir $OrtDir) {
    $OrtFound = $true
}
# 3) YOLOs-CPP 同级目录或子目录中的 onnxruntime*
elseif ($ResolvedYolos) {
    # 3a) YOLOs-CPP 同级目录 (与 YOLOs-CPP 并列)
    foreach ($subName in @("onnxruntime-win-x64-*", "onnxruntime*")) {
        $Sibling = Get-ChildItem (Split-Path $ResolvedYolos) -Directory -Filter $subName -ErrorAction SilentlyContinue |
                    Sort-Object Name -Descending | Select-Object -First 1
        if ($Sibling -and (Test-OrtDir $Sibling.FullName)) {
            $OrtDir = $Sibling.FullName
            $OrtFound = $true
            Write-Host "  从 YOLOs-CPP 同级目录找到: $($Sibling.Name)" -ForegroundColor Cyan
            break
        }
    }
    # 3b) YOLOs-CPP 子目录 (YOLOs-CPP\onnxruntime-*)
    if (-not $OrtFound) {
        foreach ($subName in @("onnxruntime-win-x64-*", "onnxruntime*")) {
            $Child = Get-ChildItem $ResolvedYolos -Directory -Filter $subName -ErrorAction SilentlyContinue |
                     Sort-Object Name -Descending | Select-Object -First 1
            if ($Child -and (Test-OrtDir $Child.FullName)) {
                $OrtDir = $Child.FullName
                $OrtFound = $true
                Write-Host "  从 YOLOs-CPP 子目录找到: $($Child.Name)" -ForegroundColor Cyan
                break
            }
        }
    }
}
# 4) 本地已存在的其他版本 (dll\ 下 fallback)
else {
    $Existing = Get-ChildItem $ScriptDir -Directory -Filter "onnxruntime-win-x64-*" |
                Sort-Object Name -Descending | Select-Object -First 1
    if ($Existing -and (Test-OrtDir $Existing.FullName)) {
        $OrtDir = $Existing.FullName
        $OrtFound = $true
        Write-Host "  找到已有版本: $($Existing.Name)" -ForegroundColor Cyan
    }
}

if (-not $OrtFound) {
    if ($Download) {
        Write-Host "  下载 ONNX Runtime v$Version ..." -ForegroundColor Yellow
        
        if (Test-Path $OrtZip) { Remove-Item $OrtZip -Force -ErrorAction SilentlyContinue }
        
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $OrtUrl -OutFile $OrtZip -UseBasicParsing
        
        if (-not (Test-Path $OrtZip)) {
            Write-Fail "下载失败: $OrtUrl"
            exit 1
        }
        
        Expand-Archive -Path $OrtZip -DestinationPath $ScriptDir -Force
        Remove-Item $OrtZip -Force -ErrorAction SilentlyContinue
        
        if (-not (Test-Path "$OrtDir\include\onnxruntime_cxx_api.h")) {
            Write-Fail "解压后未找到预期文件"
            exit 1
        }
        
        $OrtFound = $true
        Write-Host "  已下载并解压到: $OrtDir" -ForegroundColor Green
    } else {
        Write-Host "" 
        Write-Fail "ONNX Runtime 未找到！"
        Write-Host "  解决方案 (按优先级):" -ForegroundColor Yellow
        Write-Host '    1) 设置环境变量: $env:ONNXRUNTIME_DIR = "C:\path\to\onnxruntime-win-x64"' -ForegroundColor White
        Write-Host "    2) 运行时加 -Download 自动下载" -ForegroundColor White
        Write-Host "    3) 手动下载解压到 dll/ 目录下" -ForegroundColor White
        Write-Host ""
        Write-Host "    .\build.ps1 -YolosPath `"$ResolvedYolos`" -Download" -ForegroundColor White
        Write-Host ""
        Write-Host "  或手动下载:" -ForegroundColor Yellow
        Write-Host "    $OrtUrl" -ForegroundColor Gray
        Write-Host "    解压后将目录重命名为 onnxruntime-win-x64-$Version 放入 dll/ 下" -ForegroundColor Gray
        Write-Host ""
        exit 1
    }
}

Write-Host "  ONNX Runtime: $(Split-Path $OrtDir -Leaf)" -ForegroundColor White
Write-OK

# ============================================================================
# 探测 OpenCV
# ============================================================================
Write-Step "Step 4/6: 探测 OpenCV"

if (-not $OpenCV_DIR) {
    $OpenCV_DIR = $env:OpenCV_DIR
}

if (-not $OpenCV_DIR -or -not (Test-Path $OpenCV_DIR)) {
    # 常见安装位置自动探测
    $SearchPaths = @(
        "C:\opencv\build",
        "C:\tools\opencv\build",
        "${env:ProgramFiles}\opencv\build",
        "${env:LOCALAPPDATA}\opencv\build"
    )
    foreach ($p in $SearchPaths) {
        if (Test-Path $p) {
            $OpenCV_DIR = $p
            break
        }
    }
}

if (-not $OpenCV_DIR -or -not (Test-Path $OpenCV_DIR)) {
    Write-Fail "找不到 OpenCV 安装！"
    Write-Host ""
    Write-Host "  解决方案:" -ForegroundColor Yellow
    Write-Host "  1) 设置环境变量: `$env:OpenCV_DIR = 'C:\opencv\build'" -ForegroundColor White
    Write-Host "  2) 或传参: -OpenCV_DIR C:\opencv\build" -ForegroundColor White
    Write-Host ""
    Write-Host "  下载地址: https://github.com/opencv/opencv/releases" -ForegroundColor Gray
    Write-Host "  (下载 Windows Pack, 如 opencv-4.X.X-windows.exe)" -ForegroundColor Gray
    Write-Host ""
    exit 1
}

# 提取 OpenCV 版本号（用于后续收集 DLL）
$OpenCVVer = ""
$CmakeCache = Join-Path $OpenCV_DIR "OpenCVConfig.cmake"
if (Test-Path $CmakeCache) {
    $match = Select-String -Path $CmakeCache -Pattern 'OpenCV_VERSION\s+"?([\d\.]+)' -AllMatches
    if ($match.Matches) { $OpenCVVer = $match.Matches[0].Groups[1].Value }
}
if (-not $OpenCVVer) {
    # 从 x64/vc16/bin 里的文件名猜测
    $OCVBinGlob = Get-ChildItem (Join-Path $OpenCV_DIR "x64\vc16\bin") -Filter "opencv_world*.dll" -ErrorAction SilentlyContinue |
                  Sort-Object Name -Descending | Select-Object -First 1
    if ($OCVBinGlob) {
        # 文件名如 opencv_world481.dll -> 4.8.1
        $digits = $OCVBinGlob.BaseString -replace 'opencv_world', ''
        if ($digits.Length -ge 3) {
            $OpenCVVer = "$($digits[0]).$($digits[1]).$($digits[2])"
        } else {
            $OpenCVVer = $OCVBinGlob.BaseString -replace 'opencv_world', ''
        }
    }
}
if (-not $OpenCVVer) { $OpenCVVer = "(未知)" }

Write-Host "  OpenCV: $OpenCV_DIR (v$OpenCVVer)" -ForegroundColor White
Write-OK

# ============================================================================
# 清理 + CMake 配置 + 构建
# ============================================================================
Write-Step "Step 5/6: 清理并构建"

# 始终清理 build 目录（确保干净构建）
if (Test-Path $BuildDir) {
    Remove-Item $BuildDir -Recurse -Force
    Write-Host "  已清理 build/" -ForegroundColor DarkGray
}

New-Item -ItemType Directory -Path $BuildDir -Force | Out-Null

$CmakeArgs = @(
    "-DONNXRUNTIME_DIR=`"$OrtDir`"",
    "-DOpenCV_DIR=`"$OpenCV_DIR`"",
    "-DOpenCV_RUNTIME=vc16",
    "-DOpenCV_ARCH=x64",
    "-DCMAKE_BUILD_TYPE=Release"
)

Write-Host "  cmake -B build -S . ..." -ForegroundColor DarkGray
$prevErrPref = $ErrorActionPreference
$ErrorActionPreference = "Continue"
& cmake -B $BuildDir -S $ScriptDir @CmakeArgs 2>&1 | ForEach-Object { Write-Host "    $_" }
$cmakeExitCode = $LASTEXITCODE
$ErrorActionPreference = $prevErrPref
if ($cmakeExitCode -ne 0) { throw "CMake 配置失败，退出码: $cmakeExitCode" }

Write-Host ""
Write-Host "  cmake --build build --config Release --parallel ..." -ForegroundColor DarkGray
$ErrorActionPreference = "Continue"
& cmake --build $BuildDir --config Release --parallel 2>&1 | ForEach-Object { Write-Host "    $_" }
$buildExitCode = $LASTEXITCODE
$ErrorActionPreference = $prevErrPref
if ($buildExitCode -ne 0) { throw "构建失败，退出码: $buildExitCode" }

Write-OK

# ============================================================================
# 复制 yolos.dll -> dll/ 根目录，然后清理临时文件
# ============================================================================
Write-Step "Step 6/6: 复制并清理"

$OutputDir = $ScriptDir

# 从 build\Release\ 复制 yolos.dll 到 dll/
$srcYolosDll = Join-Path $ReleaseDir "yolos.dll"
$dstYolosDll = Join-Path $OutputDir "yolos.dll"
if (Test-Path $srcYolosDll) {
    Copy-Item $srcYolosDll $dstYolosDll -Force
    $size = (Get-Item $dstYolosDll).Length
    $sizeKb = [math]::Round($size / 1KB, 0)
    Write-Host "  已复制 yolos.dll (${sizeKb} KB)" -ForegroundColor White
} else {
    Write-Fail "未找到构建产物: $srcYolosDll"
}

# 清理 build/
if (Test-Path $BuildDir) {
    Remove-Item $BuildDir -Recurse -Force
    Write-Host "  已清理 build/" -ForegroundColor DarkGray
}

# 清理 include/
if (Test-Path $LocalInclude) {
    Remove-Item $LocalInclude -Recurse -Force
    Write-Host "  已清理 include/" -ForegroundColor DarkGray
}

Write-OK

# ============================================================================
# 完成
# ============================================================================
Write-Host ""
Write-Host ("=" * 56) -ForegroundColor Green
Write-Host "  构建完成! 输出: dll\yolos.dll" -ForegroundColor Green
Write-Host ("=" * 56) -ForegroundColor Green
Write-Host ""
