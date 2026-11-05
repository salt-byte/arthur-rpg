#!/usr/bin/env bash
# 在云端或新机器上准备 Godot 4.3：引擎本体 + 网页导出模板（只取网页的两个，约 17MB）。
# 用法：bash tools/setup_godot.sh [安装目录，默认 ~/godot]
set -euo pipefail
DIR="${1:-$HOME/godot}"
REL=https://github.com/godotengine/godot/releases/download/4.3-stable
mkdir -p "$DIR"
if [ ! -x "$DIR/Godot_v4.3-stable_linux.x86_64" ]; then
  curl -sSL -C - -o "$DIR/godot.zip" "$REL/Godot_v4.3-stable_linux.x86_64.zip"
  unzip -o -q "$DIR/godot.zip" -d "$DIR"
fi
T="$HOME/.local/share/godot/export_templates/4.3.stable"
if [ ! -f "$T/web_nothreads_release.zip" ]; then
  python3 "$(dirname "$0")/fetch_zip_entries.py" "$REL/Godot_v4.3-stable_export_templates.tpz" \
    version.txt,web_nothreads_release.zip,web_nothreads_debug.zip "$T"
fi
"$DIR/Godot_v4.3-stable_linux.x86_64" --version
