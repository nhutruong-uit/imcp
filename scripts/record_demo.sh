#!/usr/bin/env bash
# Records the demo video of the application by itself (macOS / Linux): builds tools/qlttta_demo_video, which signs in
# as the four demo accounts, plays through the screens and encodes docs/demo/QLTTTA_Demo_vi.mp4 with ffmpeg
# (how it works, what the video shows and how to change the story: docs/demo/README.md).
#
# Usage:
#   ./scripts/record_demo.sh                                   # Vietnamese video -> docs/demo/QLTTTA_Demo_vi.mp4
#   ./scripts/record_demo.sh --init-db --docker imcp-mssql     # load the seed data first (re-creates QLTTTA!)
#   ./scripts/record_demo.sh --lang en --out build/demo_en.mp4 # English video, written outside docs/
#   ./scripts/record_demo.sh --chapters manager,teacher --out build/try.mp4   # only some chapters (to try a change)
#
# --init-db runs scripts/db_init.sh first (SQL_PASSWORD required, --docker NAME as in db_init.sh): the demo
# changes a little data, and the seed dates are relative to the day it was loaded, so a fresh load gives the same
# video every time. Without it the database is used as it is.
# Environment: SQL_SERVER (default localhost,1433; QLTTTA_SERVER overrides it for the application only),
#   QLTTTA_DEMO_PASSWORD (demo accounts, default as in docs/SETUP.md), PRESET (default macos-debug, linux-debug on
#   Linux), EXTRA_CMAKE_ARGS (e.g. -DCMAKE_OSX_SYSROOT=... when CMake reports a "broken" compiler),
#   QLTTTA_FFMPEG (ffmpeg program), QLTTTA_DEMO_FPS / QLTTTA_DEMO_SIZE / QLTTTA_DEMO_CRF (see
#   tools/demo_video_tool.cpp). Needs ffmpeg: brew install ffmpeg
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SQL_SERVER="${SQL_SERVER:-localhost,1433}"
PRESET="${PRESET:-}"
if [[ -z "$PRESET" ]]; then
  if [[ "$(uname -s)" == Linux ]]; then PRESET=linux-debug; else PRESET=macos-debug; fi
fi
LANG_CODE=vi
OUT=""
CHAPTERS=""
CONTAINER=""
INIT_DB=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --lang)     LANG_CODE="${2:?Missing language: vi or en}"; shift 2 ;;
    --out)      OUT="${2:?Missing file name}"; shift 2 ;;
    --chapters) CHAPTERS="${2:?Missing chapter names, e.g. manager,teacher}"; shift 2 ;;
    --docker)   CONTAINER="${2:?Missing container name, e.g. --docker imcp-mssql}"; shift 2 ;;
    --init-db)  INIT_DB=1; shift ;;
    *) echo "Invalid argument: $1" >&2; exit 2 ;;
  esac
done

if ! command -v "${QLTTTA_FFMPEG:-ffmpeg}" >/dev/null 2>&1; then
  echo "ffmpeg was not found in PATH (macOS: brew install ffmpeg; Linux: your package manager)." >&2
  exit 1
fi

cd "$ROOT"   # the tool reads docs/demo/captions.tsv and writes docs/demo/ relative to the repository root

if [[ $INIT_DB -eq 1 ]]; then
  : "${SQL_PASSWORD:?Set SQL_PASSWORD (password of the sa account) to load the seed data}"
  printf '\n==== Load the seed data ====\n'
  if [[ -n "$CONTAINER" ]]; then ./scripts/db_init.sh --docker "$CONTAINER"; else ./scripts/db_init.sh; fi
fi

printf '\n==== Build the recording tool ====\n'
# shellcheck disable=SC2086
cmake --preset "$PRESET" -DQLTTTA_BUILD_TOOLS=ON ${EXTRA_CMAKE_ARGS:-} > /dev/null
cmake --build --preset "$PRESET" --target qlttta_demo_video
TOOL="$(find "build/$PRESET" -type f -name qlttta_demo_video -perm -u+x | head -n 1)"
[[ -n "$TOOL" ]] || { echo "qlttta_demo_video was not built." >&2; exit 1; }

printf '\n==== Record ====\n'
export QT_QPA_PLATFORM=offscreen   # no window appears and no Screen Recording permission is needed
export QLTTTA_SERVER="${QLTTTA_SERVER:-$SQL_SERVER}"
export QLTTTA_DEMO_PASSWORD="${QLTTTA_DEMO_PASSWORD:-Demo@2026}"   # demo accounts, not a real password
export QLTTTA_DEMO_LANG="$LANG_CODE"
[[ -z "$OUT" ]] || export QLTTTA_DEMO_OUT="$OUT"
[[ -z "$CHAPTERS" ]] || export QLTTTA_DEMO_CHAPTERS="$CHAPTERS"
"$TOOL"

VIDEO="${OUT:-docs/demo/QLTTTA_Demo_$LANG_CODE.mp4}"
SIZE_MB=$(( $(wc -c < "$VIDEO") / 1048576 ))
printf '\nDone: %s (%s MB). A video larger than 15 MB is too heavy for git: raise QLTTTA_DEMO_CRF or lower QLTTTA_DEMO_FPS.\n' \
  "$VIDEO" "$SIZE_MB"
