param([string]$GamePath, [switch]$NoLaunch)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

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
    }
    return $null
}

Say ''
Say '  DurabilityAnchor 卸载' 'Cyan'
Say ''

if (Get-Process 'Test_C-Win64-Shipping' -ErrorAction SilentlyContinue) {
    Warn '游戏正在运行，请先退出游戏。'
    Read-Host '按回车键退出'
    exit 1
}

$game = Find-GameDir
if (-not $game) {
    Warn '没有找到游戏目录，请把 PROJECT QUARANTINE 文件夹拖进来后回车：'
    $manual = Read-Host
    if ($manual) { $game = $manual.Trim().Trim('"') }
}
if (-not $game) { Bad '未提供有效目录，退出。'; Read-Host '按回车键退出'; exit 1 }

$bin = Join-Path $game 'Test_C\Binaries\Win64'
$modDst = Join-Path $bin 'ue4ss\Mods\DurabilityAnchor'

if (Test-Path $modDst) {
    Remove-Item -LiteralPath $modDst -Recurse -Force
    Ok '已删除 mod 目录'
} else {
    Warn '没有找到已安装的 mod 目录'
}

$modsTxt = Join-Path $bin 'ue4ss\Mods\mods.txt'
if (Test-Path $modsTxt) {
    $lines = @(Get-Content -LiteralPath $modsTxt)
    $out = New-Object System.Collections.Generic.List[string]
    foreach ($l in $lines) {
        if ($l -match '^\s*DurabilityAnchor\s*:') { $out.Add('DurabilityAnchor : 0') } else { $out.Add($l) }
    }
    [System.IO.File]::WriteAllLines($modsTxt, $out, [System.Text.Encoding]::ASCII)
    Ok 'mods.txt 已把 DurabilityAnchor 置为 0'
}

Say ''
Say '  卸载完成。' 'Green'
Say '  UE4SS 运行时保留未动（可能还有别的 mod 在用）。'
Say '  想彻底移除 UE4SS：删除 Test_C\Binaries\Win64 下的 dwmapi.dll 和 ue4ss 文件夹。'
Say '  卸载后耐久上限会恢复原版行为，存档没有残留改动。'
Say ''
