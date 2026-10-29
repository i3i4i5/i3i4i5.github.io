#!/usr/bin/env bash
# ============================================================
#  发布一个 deb 到本源的辅助脚本
#  用法：
#    bash scripts/add-deb.sh 路径/xxx.deb
#  作用：把 deb 拷进 debs/，重建索引，可选自动 commit
# ============================================================
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

[ $# -ge 1 ] || { echo "用法: $0 <file.deb> [...]"; exit 1; }

for f in "$@"; do
  [ -f "$f" ] || { echo "找不到 $f"; exit 1; }
  base="$(basename "$f")"
  cp -f "$f" "debs/$base"
  echo "==> 已加入 debs/$base"
  # 打印 control 关键字段，方便核对是无根还是隐根
  echo "    --- control ---"
  dpkg-deb -f "debs/$base" Package Version Architecture Depends 2>/dev/null | sed 's/^/    /'
done

REPO_URL="${REPO_URL:-}" GPG_KEY="${GPG_KEY:-}" bash scripts/make-index.sh
