#!/usr/bin/env bash
# Đóng gói bản cài macOS (.dmg) - chạy được cả trên máy cá nhân lẫn GitHub Actions.
#   1. Build Release
#   2. macdeployqt: chép Qt framework + plugin (gồm plugin ODBC) vào QLTTTA.app
#   3. Kèm driver FreeTDS (LGPL) + unixODBC + OpenSSL => máy Mac không cần cài thêm driver
#   4. Ký ad-hoc (bắt buộc với Apple Silicon) và tạo file .dmg trong thư mục dist/
#
# Yêu cầu: brew install qt qt-unixodbc unixodbc freetds cmake ninja
# Tùy chọn: EXTRA_CMAKE_ARGS="-DCMAKE_OSX_SYSROOT=..." nếu SDK của Command Line Tools lỗi.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
BREW="$(brew --prefix)"
QT_PREFIX="${QT_ROOT_DIR:-$(brew --prefix qt)}"
VERSION="$(sed -n 's/^ *VERSION \([0-9][0-9.]*\).*/\1/p' CMakeLists.txt | head -1)"
ARCH="$(uname -m)"

echo ">> Build Release (QLTTTA $VERSION, $ARCH)"
# shellcheck disable=SC2086
cmake --preset macos-release ${EXTRA_CMAKE_ARGS:-}
cmake --build --preset macos-release

APP="build/macos-release/src/app/QLTTTA.app"
FW="$APP/Contents/Frameworks"

echo ">> macdeployqt"
# Qt của Homebrew: thư viện phụ thuộc dùng @rpath -> thêm rpath tạm để macdeployqt tìm thấy, deploy xong thì gỡ
install_name_tool -add_rpath "$BREW/lib" "$APP/Contents/MacOS/QLTTTA" 2>/dev/null || true
"$QT_PREFIX/bin/macdeployqt" "$APP" -always-overwrite
install_name_tool -delete_rpath "$BREW/lib" "$APP/Contents/MacOS/QLTTTA" 2>/dev/null || true

echo ">> Kèm driver FreeTDS"
mkdir -p "$FW"
copy_lib() {   # chép thư viện vào Frameworks nếu chưa có
  local src="$1" name
  name="$(basename "$src")"
  [[ -f "$FW/$name" ]] || cp -L "$src" "$FW/$name"
  chmod u+w "$FW/$name"
}
copy_lib "$BREW/opt/freetds/lib/libtdsodbc.so"
copy_lib "$BREW/opt/unixodbc/lib/libodbc.2.dylib"
copy_lib "$BREW/opt/unixodbc/lib/libodbcinst.2.dylib"
copy_lib "$BREW/opt/libtool/lib/libltdl.7.dylib"
copy_lib "$BREW/opt/openssl@3/lib/libssl.3.dylib"
copy_lib "$BREW/opt/openssl@3/lib/libcrypto.3.dylib"

# Đổi mọi đường dẫn tuyệt đối /opt/homebrew/... thành @loader_path (cùng thư mục Frameworks)
for lib in "$FW"/libtdsodbc.so "$FW"/libodbc*.dylib "$FW"/libltdl*.dylib "$FW"/libssl*.dylib "$FW"/libcrypto*.dylib; do
  install_name_tool -id "@loader_path/$(basename "$lib")" "$lib" 2>/dev/null || true
  otool -L "$lib" | tail -n +2 | awk '{print $1}' | { grep -E "^($BREW|/usr/local/(opt|Cellar))" || true; } | while read -r dep; do
    install_name_tool -change "$dep" "@loader_path/$(basename "$dep")" "$lib"
  done
done

echo ">> Ký ad-hoc"
codesign --force --deep --sign - "$APP"
codesign --verify --deep "$APP"

echo ">> Tạo DMG"
STAGE="build/macos-release/dmg"
rm -rf "$STAGE" && mkdir -p "$STAGE" dist
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cp "$ROOT/packaging/macos/HUONG_DAN_CAI_DAT.txt" "$STAGE/"
DMG="dist/QLTTTA-$VERSION-macos-$ARCH.dmg"
rm -f "$DMG"
hdiutil create -volname "QLTTTA $VERSION" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
echo "Hoàn tất: $DMG"
