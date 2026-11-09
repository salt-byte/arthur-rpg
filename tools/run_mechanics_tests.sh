#!/usr/bin/env bash
# 跑 scripts/mechanics/ 里从插件 mechanics-library 带进来的参考代码测试（照原作的规则，用它们自带的 example.json）。
# 用法：bash tools/run_mechanics_tests.sh   环境变量 GODOT 指定 Godot 可执行文件（默认 ~/godot/Godot_v4.3-stable_linux.x86_64）
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-$HOME/godot/Godot_v4.3-stable_linux.x86_64}"
fail=0
for t in "$ROOT"/scripts/mechanics/*/test_*.gd; do
  rel="res://${t#$ROOT/}"
  out=$(timeout 120 "$GODOT" --headless --path "$ROOT" -s "$rel" 2>&1); code=$?
  n=$(echo "$out" | grep -c '^\[test\].* PASS')
  if [ $code -ne 0 ] || echo "$out" | grep -qE 'SCRIPT ERROR|Parse Error|\[test\].* FAIL'; then
    fail=$((fail+1)); echo "FAIL $rel"; echo "$out" | grep -E 'ERROR|FAIL' | head -10
  else echo "PASS $rel（$n 个用例）"; fi
done
exit $fail
