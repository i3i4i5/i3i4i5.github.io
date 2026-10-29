#!/usr/bin/env bash
# ============================================================
#  越狱源索引生成脚本（Sileo / Zebra / Cydia 通用）
#  说明：
#   - 把 deb 放进 debs/ ，本脚本会生成 Packages / Packages.gz / Packages.bz2
#   - 源根目录放 Release（可选，不签名也能用）
#   - 无根(rootless) 与 隐根(RootHide) 包可以共存于同一源，
#     靠 Architecture(iphoneos-arm64) 与 Depends 区分，Sileo 会自动挑
#  用法：bash scripts/make-index.sh
#  环境变量：
#   REPO_URL   源地址（必填），如 https://user.github.io/repo/
#   GPG_KEY    (可选) 签名密钥 ID
# ============================================================
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REPO_URL="${REPO_URL:-}"

mkdir -p debs

echo "==> 扫描 debs/ 生成 Packages"
if ! command -v apt-ftparchive >/dev/null 2>&1; then
  echo "!! 缺少 apt-ftparchive（Debian: sudo apt install -y apt-utils）"; exit 1
fi

# apt-ftparchive 只接受绝对路径；Filename 必须写成 debs/xxx.deb（相对仓库根）
DEBS_ABS="$ROOT/debs"

# 某些环境（如 minis 挂载盘）apt-ftparchive 无法 realpath 到 debs/，
# 此时退回到临时目录扫描，再把 Filename 改写成 debs/xxx.deb
SCAN="$DEBS_ABS"
if ! apt-ftparchive packages "$DEBS_ABS" >/dev/null 2>&1; then
  echo "    (debs/ 无法直接扫描，改用临时目录)"
  SCAN="$(mktemp -d)/debs"
  mkdir -p "$SCAN"
  cp -f "$DEBS_ABS"/*.deb "$SCAN"/ 2>/dev/null || true
fi

apt-ftparchive packages "$SCAN" \
  | sed "s|^Filename: .*/|Filename: debs/|" \
  > Packages

echo "    $(grep -c '^Package:' Packages || echo 0) 个包"

gzip -9 -kf Packages
bzip2 -9 -kf Packages 2>/dev/null || true

# ---------- 生成 Release ----------
echo "==> 生成 Release"
if [ -z "$REPO_URL" ]; then
  echo "!! 未设置 REPO_URL，Release 里的 Origin 用占位符，客户端仍可读取"
  REPO_URL="https://i3i4i5.github.io/"
fi

{
  echo "Origin: MyRepo"
  echo "Label: MyRepo"
  echo "Suite: stable"
  echo "Version: 1.0"
  echo "Codename: ios"
  echo "Architectures: iphoneos-arm64 iphoneos-arm64e"
  echo "Components: main"
  echo "Description: My iOS Repository (rootless + roothide)"
  echo "Support: $REPO_URL"
  if command -v md5sum >/dev/null 2>&1; then
    echo "MD5Sum:"
    md5sum Packages Packages.gz 2>/dev/null | awk '{printf " %s %s\n",$1,$2}' || true
  fi
  if command -v sha256sum >/dev/null 2>&1; then
    echo "SHA256:"
    sha256sum Packages Packages.gz 2>/dev/null | awk '{printf " %s %s\n",$1,$2}' || true
  fi
} > Release

# ---------- 签名（可选） ----------
if [ -n "${GPG_KEY:-}" ]; then
  echo "==> 用 $GPG_KEY 签名"
  gpg --batch --yes --default-key "$GPG_KEY" -abs -o Release.gpg Release
  gpg --batch --yes --default-key "$GPG_KEY" --clearsign -o InRelease Release
  gpg --armor --export "$GPG_KEY" > repo-key.gpg
else
  echo "==> 未签名（Sileo 会提示源未验证，可在设置里忽略）"
fi

echo
echo "==> 完成。包数量： $(grep -c '^Package:' Packages || echo 0)"
grep -E '^(Package|Version|Architecture|Filename):' Packages | head -40
