#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""构建 DurabilityAnchor 一键安装包。

路径全部按本文件位置推导，clone 到任何机器都能直接运行。
仅使用 Python 3 标准库。

    python tools/build_installer.py
    python tools/build_installer.py --ue4ss "D:\\下载\\UE4SS_xxx.zip"
    python tools/build_installer.py --no-zip
    python tools/build_installer.py --without-ue4ss
"""

import argparse
import io
import os
import shutil
import zipfile

VERSION = "1.9"
NAME = "DurabilityAnchor_" + VERSION

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUILD = os.path.join(ROOT, "build")
OUT = os.path.join(BUILD, NAME)
ZIP_OUT = os.path.join(BUILD, NAME + "_一键安装包.zip")

BAT = """@echo off
chcp 65001 >nul
setlocal
title DurabilityAnchor {version}
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\\{ps1}"
echo.
pause
"""


def write_text(path, text, encoding="utf-8", bom=False, crlf=True):
    data = text.replace("\r\n", "\n")
    if crlf:
        data = data.replace("\n", "\r\n")
    with io.open(path, "w", encoding=encoding, newline="") as f:
        if bom:
            f.write("\ufeff")
        f.write(data)


def copy_doc(src, dst):
    """docs 里的 UTF-8/LF 文本 -> 安装包里的 UTF-8 BOM + CRLF（Windows 友好）"""
    with io.open(src, "r", encoding="utf-8-sig") as f:
        text = f.read()
    write_text(dst, text, "utf-8", bom=True, crlf=True)


def find_ue4ss(explicit):
    if explicit:
        return explicit if os.path.isfile(explicit) else None
    env = os.environ.get("UE4SS_ZIP")
    if env and os.path.isfile(env):
        return env
    candidate = os.path.join(ROOT, "vendor", "ue4ss_runtime.zip")
    if os.path.isfile(candidate):
        return candidate
    vendor = os.path.join(ROOT, "vendor")
    if os.path.isdir(vendor):
        zips = sorted(
            os.path.join(vendor, f) for f in os.listdir(vendor)
            if f.lower().endswith(".zip")
        )
        if zips:
            return zips[0]
    return None


def build(ue4ss_zip, make_zip):
    if os.path.isdir(OUT):
        shutil.rmtree(OUT)
    os.makedirs(os.path.join(OUT, "tools"))
    os.makedirs(os.path.join(OUT, "payload", "DurabilityAnchor", "scripts"))

    # --- payload: mod 本体 ---
    src_mod = os.path.join(ROOT, "src", "DurabilityAnchor")
    dst_mod = os.path.join(OUT, "payload", "DurabilityAnchor")
    shutil.copy2(os.path.join(src_mod, "scripts", "main.lua"),
                 os.path.join(dst_mod, "scripts", "main.lua"))
    open(os.path.join(dst_mod, "enabled.txt"), "wb").close()

    # --- payload: UE4SS 运行时 ---
    if ue4ss_zip:
        shutil.copy2(ue4ss_zip, os.path.join(OUT, "payload", "ue4ss_runtime.zip"))
        print("  [OK] UE4SS 运行时: %s" % ue4ss_zip)
    else:
        print("  [!] 精简包：不含 UE4SS 运行时（仅适用于已装 UE4SS 的机器）")

    # --- tools: 安装/卸载脚本（按字节复制，保留 UTF-8 BOM + CRLF）---
    for ps1 in ("install.ps1", "uninstall.ps1"):
        shutil.copy2(os.path.join(ROOT, "tools", ps1), os.path.join(OUT, "tools", ps1))

    # --- 根目录: bat 与说明文档 ---
    write_text(os.path.join(OUT, "一键安装.bat"),
               BAT.format(version=VERSION, ps1="install.ps1"), "ascii")
    write_text(os.path.join(OUT, "一键卸载.bat"),
               BAT.format(version=VERSION, ps1="uninstall.ps1"), "ascii")
    # docs/ 是可选的：精简仓库时删掉它也能正常构建，只是包里少两份说明
    for src, dst in (("使用说明.txt", "使用说明.txt"), ("readme.md", "readme.md")):
        p = os.path.join(ROOT, "docs", src)
        if os.path.isfile(p):
            copy_doc(p, os.path.join(OUT, dst))
        else:
            print("  [!] 跳过可选文档 docs/%s（不存在）" % src)
    shutil.copy2(os.path.join(ROOT, "LICENSE-UE4SS.txt"),
                 os.path.join(OUT, "LICENSE-UE4SS.txt"))

    print("\n生成目录: %s" % OUT)
    for base, _dirs, files in os.walk(OUT):
        for f in sorted(files):
            p = os.path.join(base, f)
            print("  %9.1f KB  %s" % (os.path.getsize(p) / 1024.0,
                                     os.path.relpath(p, OUT)))

    if not make_zip:
        return

    with zipfile.ZipFile(ZIP_OUT, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for base, _dirs, files in os.walk(OUT):
            for f in files:
                p = os.path.join(base, f)
                z.write(p, os.path.join(NAME, os.path.relpath(p, OUT)))
    print("\n压缩包: %s  (%.2f MB)" % (ZIP_OUT, os.path.getsize(ZIP_OUT) / 1048576.0))


def main():
    ap = argparse.ArgumentParser(description="构建 DurabilityAnchor 一键安装包")
    ap.add_argument("--ue4ss", help="UE4SS 官方 zip 的路径（默认找 vendor/ue4ss_runtime.zip）")
    ap.add_argument("--no-zip", action="store_true", help="只生成目录，不生成压缩包")
    ap.add_argument("--without-ue4ss", action="store_true",
                    help="显式生成不含 UE4SS 运行时的精简包")
    args = ap.parse_args()

    ue4ss_zip = find_ue4ss(args.ue4ss)
    if not ue4ss_zip and not args.without_ue4ss:
        ap.error(
            "找不到 UE4SS 运行时 zip。请下载 UE4SS v3.0.1 实验版放到\n"
            "  %s\n"
            "或用 --ue4ss <路径> 指定；确认只需精简包时加 --without-ue4ss。\n"
            "发布页: https://github.com/UE4SS-RE/RE-UE4SS/releases"
            % os.path.join(ROOT, "vendor", "ue4ss_runtime.zip")
        )

    os.makedirs(BUILD, exist_ok=True)
    build(ue4ss_zip, not args.no_zip)


if __name__ == "__main__":
    main()
