#!/usr/bin/env bash
# Builds the macOS installer (.dmg) - works on a personal machine and on GitHub Actions.
#   1. Release build
#   2. macdeployqt: copies the Qt frameworks + plugins (including the ODBC plugin) into QLTTTA.app
#   3. Bundles the FreeTDS driver (LGPL) + unixODBC + OpenSSL => the Mac needs no extra driver
#   4. Ad-hoc signing (mandatory on Apple Silicon) and the .dmg file in dist/
#
# Requirements: brew install qt qt-unixodbc unixodbc freetds cmake ninja
# Optional: EXTRA_CMAKE_ARGS="-DCMAKE_OSX_SYSROOT=..." when the Command Line Tools SDK is broken.
#
# Usage:
#   ./scripts/package-macos.sh                        # Qt from Homebrew => dist/QLTTTA-<version>-macos-<arch>.dmg
#   QT_ROOT_DIR=/path/to/Qt/6.x/macos ./scripts/package-macos.sh   # another Qt installation
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
BREW="$(brew --prefix)"
QT_PREFIX="${QT_ROOT_DIR:-$(brew --prefix qt)}"
VERSION="$(sed -n 's/^ *VERSION \([0-9][0-9.]*\).*/\1/p' CMakeLists.txt | head -1)"
ARCH="$(uname -m)"

echo ">> Release build (QLTTTA $VERSION, $ARCH)"
# shellcheck disable=SC2086
cmake --preset macos-release ${EXTRA_CMAKE_ARGS:-}
cmake --build --preset macos-release

APP="build/macos-release/src/app/QLTTTA.app"
FW="$APP/Contents/Frameworks"

echo ">> macdeployqt"
# Homebrew Qt: dependencies use @rpath -> add a temporary rpath so macdeployqt finds them, remove it afterwards
install_name_tool -add_rpath "$BREW/lib" "$APP/Contents/MacOS/QLTTTA" 2>/dev/null || true
"$QT_PREFIX/bin/macdeployqt" "$APP" -always-overwrite
install_name_tool -delete_rpath "$BREW/lib" "$APP/Contents/MacOS/QLTTTA" 2>/dev/null || true

echo ">> Bundle the FreeTDS driver"
mkdir -p "$FW"
copy_lib() {   # copies a library into Frameworks unless it is already there
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

# Rewrite every absolute /opt/homebrew/... path to @loader_path (the same Frameworks folder)
for lib in "$FW"/libtdsodbc.so "$FW"/libodbc*.dylib "$FW"/libltdl*.dylib "$FW"/libssl*.dylib "$FW"/libcrypto*.dylib; do
  install_name_tool -id "@loader_path/$(basename "$lib")" "$lib" 2>/dev/null || true
  otool -L "$lib" | tail -n +2 | awk '{print $1}' | { grep -E "^($BREW|/usr/local/(opt|Cellar))" || true; } | while read -r dep; do
    install_name_tool -change "$dep" "@loader_path/$(basename "$dep")" "$lib"
  done
done

echo ">> Ad-hoc signing"
codesign --force --deep --sign - "$APP"
codesign --verify --deep "$APP"

echo ">> Create the DMG"
STAGE="build/macos-release/dmg"
rm -rf "$STAGE" && mkdir -p "$STAGE" dist
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cp "$ROOT/packaging/macos/INSTALL.txt" "$STAGE/"
DMG="dist/QLTTTA-$VERSION-macos-$ARCH.dmg"
rm -f "$DMG"
hdiutil create -volname "QLTTTA $VERSION" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
echo "Done: $DMG"
