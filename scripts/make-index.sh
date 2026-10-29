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
# 注：故意不生成 Packages.bz2。旧版 Sileo 会优先拉 .bz2，
# 若 Release 未同步其哈希就会报「哈希校验不匹配」。只用 .gz 最稳。

# ---------- 生成 Release ----------
echo "==> 生成 Release"
if [ -z "$REPO_URL" ]; then
  echo "!! 未设置 REPO_URL，Release 里的 Support 用占位符，客户端仍可读取"
  REPO_URL="https://i3i4i5.github.io/"
fi

# 计算文件哈希+大小，按 Debian Release 标准三字段格式： <hash> <size> <file>
gen_hashes() {
  local alg="$1"; shift
  local f
  for f in "$@"; do
    [ -f "$f" ] || continue
    local size; size=$(wc -c < "$f" | tr -d ' ')
    local h
    case "$alg" in
      md5)    h=$(md5sum "$f"    | awk '{print $1}') ;;
      sha256) h=$(sha256sum "$f" | awk '{print $1}') ;;
    esac
    printf ' %s %s %s\n' "$h" "$size" "$f"
  done
}

{
  echo "Origin: 牛逼源"
  echo "Label: 牛逼源"
  echo "Suite: stable"
  echo "Version: 1.0"
  echo "Codename: ios"
  echo "Architectures: iphoneos-arm64 iphoneos-arm64e"
  echo "Components: main"
  echo "Description: 牛逼源 - rootless / RootHide 双版本插件"
  echo "Support: $REPO_URL"
  echo "MD5Sum:"
  gen_hashes md5 Packages Packages.gz
  echo "SHA256:"
  gen_hashes sha256 Packages Packages.gz
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
