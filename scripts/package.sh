#!/usr/bin/env bash
# Builds the installer of the operating system it runs on, so every member uses the same command:
#   macOS                    -> scripts/package-macos.sh    => dist/QLTTTA-<version>-macos-<arch>.dmg
#   Windows (Git Bash, MSYS) -> scripts/package-windows.ps1 => dist\QLTTTA-<version>-windows-x64-setup.exe + -portable.zip
#   Linux                    -> no installer: the team ships macOS and Windows only
# The requirements are the ones of the platform script (docs/SETUP.md "Building installers"): Homebrew qt,
# qt-unixodbc, unixodbc, freetds, cmake and ninja on macOS; Qt (MinGW), CMake and Ninja on Windows, plus Inno Setup 6
# for setup.exe (without it only the portable .zip is built).
#
# Usage:
#   ./scripts/package.sh                          # the Qt of Homebrew (macOS) or of $QT_ROOT_DIR (Windows)
#   ./scripts/package.sh --qt-dir <Qt folder>     # another Qt installation (sets QT_ROOT_DIR / -QtDir)
#   EXTRA_CMAKE_ARGS="-DCMAKE_OSX_SYSROOT=<Xcode SDK>" ./scripts/package.sh   # macOS: CMake reports a broken compiler
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
QT_DIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --qt-dir) QT_DIR="${2:?Missing Qt folder, e.g. --qt-dir /opt/homebrew/opt/qt}"; shift 2 ;;
    -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
    *) echo "Invalid argument: $1 (see --help)" >&2; exit 2 ;;
  esac
done

case "$(uname -s)" in
  Darwin)
    if [[ -n "$QT_DIR" ]]; then export QT_ROOT_DIR="$QT_DIR"; fi
    exec "$ROOT/scripts/package-macos.sh" ;;
  MINGW*|MSYS*|CYGWIN*)
    # Windows PowerShell runs the Windows script; it needs a Windows path, not /c/...
    PS_ARGS=(-NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$ROOT/scripts/package-windows.ps1")")
    if [[ -n "$QT_DIR" ]]; then PS_ARGS+=(-QtDir "$(cygpath -w "$QT_DIR")"); fi
    exec powershell.exe "${PS_ARGS[@]}" ;;
  *)
    echo "No installer for $(uname -s): build one on macOS (.dmg) or Windows (setup.exe, portable .zip)." >&2
    exit 2 ;;
esac
