param([string]$GamePath, [switch]$NoLaunch)

$ErrorActionPreference = 'Stop'
$ModName = 'DurabilityAnchor'
$Root    = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Payload = Join-Path $Root 'payload'

function Say([string]$m, [string]$c = 'Gray') { Write-Host $m -ForegroundColor $c }
function Ok([string]$m)   { Say ('   [OK] ' + $m) 'Green' }
function Warn([string]$m) { Say ('   [!]  ' + $m) 'Yellow' }
function Bad([string]$m)  { Say ('   [x]  ' + $m) 'Red' }

function Find-GameDir {
    $list = New-Object System.Collections.Generic.List[string]
    if ($GamePath) { $list.Add($GamePath.Trim().Trim('"')) }

    $steam = $null
    foreach ($key in @('HKCU:\Software\Valve\Steam',
                       'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam',
                       'HKLM:\SOFTWARE\Valve\Steam')) {
        if (Test-Path $key) {
            $p = Get-ItemProperty $key -ErrorAction SilentlyContinue
            if ($p) {
                if ($p.SteamPath)   { $steam = $p.SteamPath;   break }
                if ($p.InstallPath) { $steam = $p.InstallPath; break }
            }
        }
    }

    if ($steam) {
        $list.Add($steam)
        $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
        if (Test-Path $vdf) {
            $txt = Get-Content $vdf -Raw
            foreach ($m in [regex]::Matches($txt, '"path"\s+"([^"]+)"')) {
                $list.Add($m.Groups[1].Value.Replace('\\', '\'))
            }
        }
    }

    foreach ($base in $list) {
        if (-not $base -or -not (Test-Path $base)) { continue }
        $g = Join-Path $base 'steamapps\common\PROJECT QUARANTINE'
        if (Test-Path (Join-Path $g 'Test_C\Binaries\Win64\Test_C-Win64-Shipping.exe')) { return (Resolve-Path $g).Path }
        if (Test-Path (Join-Path $base 'Test_C\Binaries\Win64\Test_C-Win64-Shipping.exe')) { return (Resolve-Path $base).Path }
    }
    return $null
}

Say ''
Say '  ==================================================' 'Cyan'
Say '   DurabilityAnchor 1.9  ·  修理不降低耐久上限' 'Cyan'
Say '  ==================================================' 'Cyan'
Say ''

if (Get-Process 'Test_C-Win64-Shipping' -ErrorAction SilentlyContinue) {
    Warn '游戏正在运行，请先完全退出游戏再安装。'
    Read-Host '按回车键退出'
    exit 1
}

Say '  [1/4] 定位游戏目录...'
$game = Find-GameDir
if (-not $game) {
    Warn '没有自动找到游戏。请把 PROJECT QUARANTINE 文件夹拖到本窗口后按回车：'
    $manual = Read-Host
    if ($manual) {
        $t = $manual.Trim().Trim('"')
        if (Test-Path (Join-Path $t 'Test_C\Binaries\Win64\Test_C-Win64-Shipping.exe')) { $game = $t }
        elseif (Test-Path (Join-Path $t 'Test_C-Win64-Shipping.exe')) { $game = Split-Path -Parent (Split-Path -Parent $t) }
    }
}
if (-not $game) { Bad '未提供有效的游戏目录，安装已取消。'; Read-Host '按回车键退出'; exit 1 }
Ok ('游戏目录: ' + $game)

$bin = Join-Path $game 'Test_C\Binaries\Win64'
if (-not (Test-Path (Join-Path $bin 'Test_C-Win64-Shipping.exe'))) {
    Bad '这个目录里找不到 Test_C-Win64-Shipping.exe，安装已取消。'
    Read-Host '按回车键退出'
    exit 1
}

Say ''
Say '  [2/4] 检查 UE4SS 运行时...'
$hasUE4SS = (Test-Path (Join-Path $bin 'dwmapi.dll')) -and (Test-Path (Join-Path $bin 'ue4ss\UE4SS.dll'))
if ($hasUE4SS) {
    Ok '已存在 UE4SS，跳过安装（不会覆盖你现有的其他 mod 和设置）'
} else {
    $zip = Join-Path $Payload 'ue4ss_runtime.zip'
    if (-not (Test-Path $zip)) { Bad '安装包缺少 payload\ue4ss_runtime.zip'; Read-Host '按回车键退出'; exit 1 }
    Expand-Archive -LiteralPath $zip -DestinationPath $bin -Force
    Ok 'UE4SS 运行时已安装到 Test_C\Binaries\Win64'

    $ini = Join-Path $bin 'ue4ss\UE4SS-settings.ini'
    if (Test-Path $ini) {
        $t = Get-Content $ini -Raw
        $t = $t -replace '(?m)^(\s*MajorVersion\s*=\s*)\s*$', '${1}5'
        $t = $t -replace '(?m)^(\s*MinorVersion\s*=\s*)\s*$', '${1}6'
        [System.IO.File]::WriteAllText($ini, $t, (New-Object System.Text.UTF8Encoding($false)))
        Ok '已写入引擎版本覆盖 (UE 5.6)'
    }
}

Say ''
Say '  [3/4] 安装 mod 文件...'
$modDst = Join-Path $bin 'ue4ss\Mods\DurabilityAnchor'
New-Item -ItemType Directory -Force -Path (Join-Path $modDst 'scripts') | Out-Null
Copy-Item -Path (Join-Path $Payload 'DurabilityAnchor\scripts\main.lua') -Destination (Join-Path $modDst 'scripts\main.lua') -Force
New-Item -ItemType File -Force -Path (Join-Path $modDst 'enabled.txt') | Out-Null
Ok ('已安装到 ' + $modDst)

Say ''
Say '  [4/4] 写入启用列表 (mods.txt)...'
$modsTxt = Join-Path $bin 'ue4ss\Mods\mods.txt'
if (Test-Path $modsTxt) {
    Copy-Item $modsTxt ($modsTxt + '.bak') -Force
    $lines = @(Get-Content -LiteralPath $modsTxt)
    $found = $false
    $out = New-Object System.Collections.Generic.List[string]
    foreach ($l in $lines) {
        if ($l -match '^\s*DurabilityAnchor\s*:') { $found = $true; $out.Add('DurabilityAnchor : 1') }
        else { $out.Add($l) }
    }
    if (-not $found) {
        $idx = -1
        for ($i = 0; $i -lt $out.Count; $i++) {
            if ($out[$i] -match '^\s*;.*Built-in keybinds') { $idx = $i; break }
        }
        if ($idx -ge 0) { $out.Insert($idx, 'DurabilityAnchor : 1') } else { $out.Add('DurabilityAnchor : 1') }
    }
    [System.IO.File]::WriteAllLines($modsTxt, $out, [System.Text.Encoding]::ASCII)
    Ok 'mods.txt 已启用 DurabilityAnchor（原文件备份为 mods.txt.bak）'
} else {
    Warn '没找到 mods.txt，将依赖 enabled.txt 自动启用'
}

Say ''
Say '  ==================================================' 'Green'
Say '   安装完成' 'Green'
Say '  ==================================================' 'Green'
Say '   · 进游戏后打开修理台，选中要修的物品，「上限」应显示 100%'
Say '   · 让物品掉耐久后再修一次，可确认上限不再下降'
Say '   · 如果没生效，看 ue4ss\UE4SS.log 里搜 DurabilityAnchor'
Say '   · 卸载：运行「一键卸载.bat」'
Say ''

if ($NoLaunch) { exit 0 }
$ans = Read-Host '现在启动游戏吗？(Y/N)'
if ($ans -match '^[Yy]') {
    Say '正在通过 Steam 启动...'
    try { Start-Process 'steam://rungameid/2116120' } catch { Start-Process (Join-Path $bin 'Test_C-Win64-Shipping.exe') }
}
