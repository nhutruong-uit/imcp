#!/usr/bin/env bash
# Builds the macOS installer (.dmg) - works on a personal machine and on GitHub Actions.
#   1. Release build
#   2. macdeployqt: copies the Qt frameworks + plugins (including the ODBC plugin) into QLTTTA.app
#   3. Bundles the FreeTDS driver (LGPL) + unixODBC + OpenSSL => the Mac needs no extra driver
#   4. Writes the oldest macOS every bundled binary runs on into Info.plist (LSMinimumSystemVersion)
#   5. Ad-hoc signing (mandatory on Apple Silicon) and the .dmg file in dist/ with "READ ME FIRST.txt"
#
# The Homebrew libraries are built for the macOS of the build machine, so the .dmg runs on that macOS version or
# later: build on the oldest macOS you want to support (release.yml pins its runner for this reason).
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
# Our own binary targets the macOS major version of this machine (e.g. 15.0), like the Homebrew libraries; left
# unset, the compiler targets the exact version (e.g. 15.5) and would lock out earlier updates of the same macOS
DEPLOYMENT_TARGET="$(sw_vers -productVersion | cut -d. -f1).0"

echo ">> Release build (QLTTTA $VERSION, $ARCH, deployment target macOS $DEPLOYMENT_TARGET)"
# shellcheck disable=SC2086
cmake --preset macos-release -DCMAKE_OSX_DEPLOYMENT_TARGET="$DEPLOYMENT_TARGET" ${EXTRA_CMAKE_ARGS:-}
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

echo ">> Minimum macOS version"
# The app runs only where all its binaries run: take the highest "minos" of every Mach-O file in the bundle. With it
# in Info.plist, an older macOS refuses to open the app with its own "requires macOS X or later" message instead of
# crashing at launch. Must happen before signing (the signature covers Info.plist).
MIN_MACOS="$(find "$APP" -type f | while IFS= read -r f; do
  case "$(file -b "$f")" in Mach-O*) otool -l "$f" | awk '$1 == "minos" { print $2 }' ;; esac
done | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)"
[[ -n "$MIN_MACOS" ]] || { echo "No minos found in the binaries of $APP" >&2; exit 1; }
plutil -replace LSMinimumSystemVersion -string "$MIN_MACOS" "$APP/Contents/Info.plist"
echo "   LSMinimumSystemVersion = $MIN_MACOS"

echo ">> Ad-hoc signing"
codesign --force --deep --sign - "$APP"
codesign --verify --deep "$APP"

echo ">> Create the DMG"
STAGE="build/macos-release/dmg"
rm -rf "$STAGE" && mkdir -p "$STAGE" dist
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
# The name tells the user to read it before the first launch, which macOS blocks once (the app is not notarized)
sed "s/@MIN_MACOS@/$MIN_MACOS/" "$ROOT/packaging/macos/INSTALL.txt" > "$STAGE/READ ME FIRST.txt"
DMG="dist/QLTTTA-$VERSION-macos-$ARCH.dmg"
rm -f "$DMG"
hdiutil create -volname "QLTTTA $VERSION" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
echo "Done: $DMG (macOS $MIN_MACOS or later)"
