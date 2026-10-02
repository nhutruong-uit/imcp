#!/usr/bin/env bash
# Runs the WHOLE test suite and stops at the first failing step (run it before creating a PR):
#   1. Re-initialize the QLTTTA database from scratch (scripts/db_init.sh) => always the same seed data
#   2. Database tests: database/12_tests.sql (constraints, business rules, functions/triggers/cursors, XML,
#      permissions)
#   3. Build the application + unit tests + end-to-end GUI tests against the real database (ctest)
#
# Usage:
#   SQL_PASSWORD='<sa password>' ./scripts/test_all.sh --docker sql2022   # sqlcmd inside the container
#   SQL_PASSWORD='<sa password>' ./scripts/test_all.sh                    # sqlcmd on this machine (SQL_SERVER)
#   ... ./scripts/test_all.sh --docker sql2022 --no-init                   # skip step 1
#
# Environment: SQL_SERVER (default localhost,1433), SQL_USER (default sa), SQL_PASSWORD (required),
#   QLTTTA_E2E_PASSWORD (demo account password, default as in docs/SETUP.md), PRESET (default macos-debug),
#   EXTRA_CMAKE_ARGS (e.g. -DCMAKE_OSX_SYSROOT=... when CMake reports a "broken" compiler)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SQL_SERVER="${SQL_SERVER:-localhost,1433}"
SQL_USER="${SQL_USER:-sa}"
PRESET="${PRESET:-macos-debug}"
CONTAINER=""
INIT_DB=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --docker)  CONTAINER="${2:?Missing container name, e.g. --docker sql2022}"; shift 2 ;;
    --no-init) INIT_DB=0; shift ;;
    *) echo "Invalid argument: $1" >&2; exit 2 ;;
  esac
done
: "${SQL_PASSWORD:?Set SQL_PASSWORD (password of the sa account)}"
export QLTTTA_E2E_PASSWORD="${QLTTTA_E2E_PASSWORD:-Demo@2026}"   # demo accounts, not a real password

RESULTS="$ROOT/build/test-results"
mkdir -p "$RESULTS"
step() { printf '\n==== %s ====\n' "$1"; }

# 1. Re-initialize the database
if [[ $INIT_DB -eq 1 ]]; then
  step "1/3 Re-initialize the database"
  if [[ -n "$CONTAINER" ]]; then "$ROOT/scripts/db_init.sh" --docker "$CONTAINER"; else "$ROOT/scripts/db_init.sh"; fi
fi

# 2. Database tests (the script THROWs when a case fails => sqlcmd -b returns an error code)
step "2/3 Database tests (database/12_tests.sql)"
DB_LOG="$RESULTS/database_tests.txt"
set +e
if [[ -n "$CONTAINER" ]]; then
  docker cp "$ROOT/database/12_tests.sql" "$CONTAINER:/tmp/12_tests.sql" >/dev/null
  SQLCMDPASSWORD="$SQL_PASSWORD" docker exec -e SQLCMDPASSWORD "$CONTAINER" /opt/mssql-tools18/bin/sqlcmd \
    -S localhost -U "$SQL_USER" -C -I -b -f 65001 -d QLTTTA -W -s '|' -i /tmp/12_tests.sql > "$DB_LOG" 2>&1
else
  SQLCMDPASSWORD="$SQL_PASSWORD" sqlcmd -S "$SQL_SERVER" -U "$SQL_USER" -C -I -b -f 65001 -d QLTTTA -W -s '|' \
    -i "$ROOT/database/12_tests.sql" > "$DB_LOG" 2>&1
fi
DB_EXIT=$?
set -e
# Verdict column of the summary table of 12_tests.sql: PASSED / FAILED
TOTAL=$(grep -cE '^[TP][0-9]{2}\|' "$DB_LOG" || true)
PASSED=$(grep -E '^[TP][0-9]{2}\|' "$DB_LOG" | grep -c '|PASSED|' || true)
echo "Result: $PASSED/$TOTAL cases passed (details: ${DB_LOG#"$ROOT"/})"
if [[ $DB_EXIT -ne 0 ]]; then
  grep -E '^[TP][0-9]{2}\|.*\|FAILED\|' "$DB_LOG" || tail -20 "$DB_LOG"
  echo "FAILED: some database test cases failed." >&2
  exit 1
fi

# 3. Build + unit tests + end-to-end
step "3/3 Build, unit tests and GUI tests (ctest)"
# shellcheck disable=SC2086
cmake --preset "$PRESET" ${EXTRA_CMAKE_ARGS:-} > "$RESULTS/cmake_configure.log" 2>&1 \
  || { cat "$RESULTS/cmake_configure.log"; exit 1; }
cmake --build --preset "$PRESET"
QLTTTA_SERVER="${QLTTTA_SERVER:-$SQL_SERVER}" ctest --preset "$PRESET" --output-on-failure \
  --output-junit "$RESULTS/ctest.xml"

# A silently skipped end-to-end test is not accepted (e.g. missing password, database unreachable)
if grep -q 'status="skipped"\|<skipped' "$RESULTS/ctest.xml"; then
  echo "FAILED: some tests were skipped - check the database connection / QLTTTA_E2E_PASSWORD." >&2
  exit 1
fi

printf '\nALL TESTS PASSED: database %s/%s cases, unit tests + end-to-end GUI tests passed.\n' "$PASSED" "$TOTAL"
