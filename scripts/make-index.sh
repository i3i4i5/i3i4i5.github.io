#!/usr/bin/env bash
# 越狱源索引生成脚本（Sileo/Zebra/Cydia 通用）
# 生成 Packages / Packages.gz / Release，并套用 overrides.json 的自定义名称/详情
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
REPO_URL="${REPO_URL:-https://i3i4i5.github.io/}"
mkdir -p debs

command -v apt-ftparchive >/dev/null 2>&1 || { echo "缺少 apt-ftparchive"; exit 1; }

DEBS_ABS="$ROOT/debs"
if apt-ftparchive packages "$DEBS_ABS" >/dev/null 2>&1; then
  apt-ftparchive packages "$DEBS_ABS" | sed "s#^Filename: .*/#Filename: debs/#" > Packages
else
  SCAN="$(mktemp -d)/debs"; mkdir -p "$SCAN"; cp -f "$DEBS_ABS"/*.deb "$SCAN"/ 2>/dev/null || true
  apt-ftparchive packages "$SCAN" | sed "s#^Filename: .*/#Filename: debs/#" > Packages
fi

# 套用自定义名称/详情（overrides.json -> Packages 的 Name/Description）
if [ -f overrides.json ] && command -v python3 >/dev/null 2>&1; then
  python3 scripts/apply-overrides.py || echo "(override 应用跳过)"
fi

gzip -9 -kf Packages

gen_hashes(){ local alg="$1"; shift; local f; for f in "$@"; do [ -f "$f" ] || continue;
  local size; size=$(wc -c < "$f" | tr -d ' '); local h;
  case "$alg" in md5) h=$(md5sum "$f"|awk '{print $1}');; sha256) h=$(sha256sum "$f"|awk '{print $1}');; esac
  printf ' %s %s %s\n' "$h" "$size" "$f"; done; }

{ echo "Origin: 牛逼源"; echo "Label: 牛逼源"; echo "Suite: stable"; echo "Version: 1.0";
  echo "Codename: ios"; echo "Architectures: iphoneos-arm64 iphoneos-arm64e";
  echo "Components: main"; echo "Description: 牛逼源 - rootless / RootHide 双版本插件";
  echo "Support: $REPO_URL"; echo "MD5Sum:"; gen_hashes md5 Packages Packages.gz;
  echo "SHA256:"; gen_hashes sha256 Packages Packages.gz; } > Release

echo "索引完成: $(grep -c '^Package:' Packages) 个包"
