#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
REPO_URL="${REPO_URL:-https://i3i4i5.github.io/}"
mkdir -p debs
# 生成 Packages（兼容无法直接 realpath 的环境）
if apt-ftparchive packages "$ROOT/debs" >/dev/null 2>&1; then
  apt-ftparchive packages "$ROOT/debs" | sed "s#^Filename: .*/#Filename: debs/#" > Packages
else
  SCAN="$(mktemp -d)/debs"; mkdir -p "$SCAN"; cp -f "$ROOT/debs"/*.deb "$SCAN"/ 2>/dev/null || true
  apt-ftparchive packages "$SCAN" | sed "s#^Filename: .*/#Filename: debs/#" > Packages
fi
gzip -9 -kf Packages
# 故意不生成 bz2：旧 Sileo 优先拉 .bz2 但 Release 不记录其哈希会报校验错
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
