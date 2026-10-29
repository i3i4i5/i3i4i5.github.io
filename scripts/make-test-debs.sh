#!/usr/bin/env bash
# 造两个测试 deb：无根 / 隐根，用于验证源索引流程
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="$(pwd)/debs"
mkdir -p "$OUT"

mk() {
  local NAME="$1" VER="$2" ARCH="$3" PREFIX="$4" DEPENDS="$5" DESC="$6"
  local TMP; TMP="$(mktemp -d)"
  mkdir -p "$TMP/DEBIAN" "$TMP${PREFIX}/Library/MobileSubstrate/DynamicLibraries"

  cat > "$TMP/DEBIAN/control" <<EOF
Package: ${NAME}
Version: ${VER}
Architecture: ${ARCH}
Maintainer: Tester <test@example.com>
Author: Tester <test@example.com>
Section: Tweaks
Priority: optional
Depends: ${DEPENDS}
Description: ${DESC}
EOF

  # 假 dylib + 过滤 plist
  echo "fake dylib payload" > "$TMP${PREFIX}/Library/MobileSubstrate/DynamicLibraries/${NAME}.dylib"
  cat > "$TMP${PREFIX}/Library/MobileSubstrate/DynamicLibraries/${NAME}.plist" <<'EOF'
{ Filter = { Bundles = ( "com.apple.springboard" ); }; }
EOF

  dpkg-deb -b --root-owner-group "$TMP" "$OUT/${NAME}_${VER}_${ARCH}.deb" >/dev/null
  rm -rf "$TMP"
  echo "  -> ${NAME}_${VER}_${ARCH}.deb"
}

echo "生成测试包："
# 无根：/var/jb 前缀
mk "com.test.demo-rootless" "1.0.0" "iphoneos-arm64" "/var/jb" \
   "ellekit | mobilesubstrate, firmware (>= 14.0)" "Demo tweak for rootless jailbreak"

# 隐根：无 /var/jb 前缀，包名加后缀避免冲突
mk "com.test.demo-roothide" "1.0.0" "iphoneos-arm64" "" \
   "ellekit | mobilesubstrate" "Demo tweak for RootHide jailbreak"

ls -la "$OUT"
