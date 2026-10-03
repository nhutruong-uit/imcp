#!/usr/bin/env bash
# Runs the WHOLE test suite and stops at the first failing step (run it before creating a PR):
#   1. Change checks against origin/develop (scripts/check_changes.sh): format of the changed C++ lines, commit
#      messages, no build output / .env in the repository
#   2. Re-initialize the QLTTTA database from scratch (scripts/db_init.sh) => always the same seed data
#   3. Database tests: database/12_tests.sql (constraints, business rules, functions/triggers/cursors, XML,
#      permissions, naming and least-privilege rules)
#   4. Server-level tests: database/13_server_tests.sql (backup/restore, BULK INSERT, distributed database,
#      account lockout with real sign-ins) - needs sysadmin and the MSOLEDBSQL provider (SQL Server 2019+)
#   5. Build the application + unit tests (incl. tst_conventions) + end-to-end GUI tests against the database
#
# Usage:
#   SQL_PASSWORD='<sa password>' ./scripts/test_all.sh --docker imcp-mssql   # sqlcmd inside the container
#   SQL_PASSWORD='<sa password>' ./scripts/test_all.sh                    # sqlcmd on this machine (SQL_SERVER)
#   ... ./scripts/test_all.sh --docker imcp-mssql --no-init                   # skip step 2
#
# Environment: SQL_SERVER (default localhost,1433), SQL_USER (default sa), SQL_PASSWORD (required),
#   QLTTTA_E2E_PASSWORD (demo account password, default as in docs/SETUP.md),
#   PRESET (default macos-debug, linux-debug on Linux),
#   EXTRA_CMAKE_ARGS (e.g. -DCMAKE_OSX_SYSROOT=... when CMake reports a "broken" compiler),
#   SQL_CSV_PATH (without --docker: path of database/samples/student_import.csv as seen by the SQL Server
#   machine; default: a copy in /tmp, which works when SQL Server runs natively on this machine),
#   CHANGE_BASE (base branch of step 1, default origin/develop)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SQL_SERVER="${SQL_SERVER:-localhost,1433}"
SQL_USER="${SQL_USER:-sa}"
PRESET="${PRESET:-}"
if [[ -z "$PRESET" ]]; then
  if [[ "$(uname -s)" == Linux ]]; then PRESET=linux-debug; else PRESET=macos-debug; fi
fi
CONTAINER=""
INIT_DB=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --docker)  CONTAINER="${2:?Missing container name, e.g. --docker imcp-mssql}"; shift 2 ;;
    --no-init) INIT_DB=0; shift ;;
    *) echo "Invalid argument: $1" >&2; exit 2 ;;
  esac
done
: "${SQL_PASSWORD:?Set SQL_PASSWORD (password of the sa account)}"
export QLTTTA_E2E_PASSWORD="${QLTTTA_E2E_PASSWORD:-Demo@2026}"   # demo accounts, not a real password

RESULTS="$ROOT/build/test-results"
mkdir -p "$RESULTS"
step() { printf '\n==== %s ====\n' "$1"; }

# 1. Change checks (fast, so they come first)
step "1/5 Change checks (scripts/check_changes.sh)"
"$ROOT/scripts/check_changes.sh" "${CHANGE_BASE:-origin/develop}"

# 2. Re-initialize the database
if [[ $INIT_DB -eq 1 ]]; then
  step "2/5 Re-initialize the database"
  if [[ -n "$CONTAINER" ]]; then "$ROOT/scripts/db_init.sh" --docker "$CONTAINER"; else "$ROOT/scripts/db_init.sh"; fi
fi

# Runs a test script of database/ ($1) into build/test-results/$2 ($3... = extra sqlcmd arguments) and stops
# the suite when a case fails (the script THROWs => sqlcmd -b returns an error code)
DB_PASSED=0
DB_TOTAL=0
run_db_tests() {
  local file="$1" log="$RESULTS/$2" exit_code total passed
  shift 2
  # Outside "set +e": a failed copy stops the suite instead of running an older copy left in the container
  if [[ -n "$CONTAINER" ]]; then docker cp "$ROOT/database/$file" "$CONTAINER:/tmp/$file" >/dev/null; fi
  set +e
  if [[ -n "$CONTAINER" ]]; then
    SQLCMDPASSWORD="$SQL_PASSWORD" docker exec -e SQLCMDPASSWORD "$CONTAINER" /opt/mssql-tools18/bin/sqlcmd \
      -S localhost -U "$SQL_USER" -C -I -b -f 65001 -d QLTTTA -W -s '|' "$@" -i "/tmp/$file" > "$log" 2>&1
  else
    SQLCMDPASSWORD="$SQL_PASSWORD" sqlcmd -S "$SQL_SERVER" -U "$SQL_USER" -C -I -b -f 65001 -d QLTTTA -W -s '|' \
      "$@" -i "$ROOT/database/$file" > "$log" 2>&1
  fi
  exit_code=$?
  set -e
  # Verdict column of the summary table: PASSED / FAILED (case codes Txx, Pxx, Sxx)
  total=$(grep -cE '^[TPS][0-9]{2}\|' "$log" || true)
  passed=$(grep -E '^[TPS][0-9]{2}\|' "$log" | grep -c '|PASSED|' || true)
  echo "Result: $passed/$total cases passed (details: ${log#"$ROOT"/})"
  if [[ $exit_code -ne 0 ]]; then
    grep -E '^[TPS][0-9]{2}\|.*\|FAILED\|' "$log" || tail -20 "$log"
    echo "FAILED: some test cases of database/$file failed." >&2
    exit 1
  fi
  DB_PASSED=$((DB_PASSED + passed))
  DB_TOTAL=$((DB_TOTAL + total))
}

# 3. Database tests
step "3/5 Database tests (database/12_tests.sql)"
run_db_tests 12_tests.sql database_tests.txt

# 4. Server-level tests: 13_server_tests.sql includes 11_distributed_demo.sql (:r, read by sqlcmd) and
#    BULK INSERTs the sample CSV (read by the SQL Server service, so the file must be on the server machine)
step "4/5 Server-level tests (database/13_server_tests.sql)"
if [[ -n "$CONTAINER" ]]; then
  docker cp "$ROOT/database/11_distributed_demo.sql" "$CONTAINER:/tmp/11_distributed_demo.sql" >/dev/null
  docker cp "$ROOT/database/samples/student_import.csv" "$CONTAINER:/tmp/student_import.csv" >/dev/null
  run_db_tests 13_server_tests.sql server_tests.txt -v DatabaseDir=/tmp CsvPath=/tmp/student_import.csv
else
  CSV_PATH="${SQL_CSV_PATH:-}"
  if [[ -z "$CSV_PATH" ]]; then
    CSV_PATH=/tmp/qlttta_student_import.csv
    cp "$ROOT/database/samples/student_import.csv" "$CSV_PATH"
    chmod 644 "$CSV_PATH"
  fi
  run_db_tests 13_server_tests.sql server_tests.txt -v DatabaseDir="$ROOT/database" CsvPath="$CSV_PATH"
fi

# 5. Build + unit tests + end-to-end
step "5/5 Build, unit tests and GUI tests (ctest)"
# shellcheck disable=SC2086
cmake --preset "$PRESET" ${EXTRA_CMAKE_ARGS:-} > "$RESULTS/cmake_configure.log" 2>&1 \
  || { cat "$RESULTS/cmake_configure.log"; exit 1; }
cmake --build --preset "$PRESET"
QLTTTA_SERVER="${QLTTTA_SERVER:-$SQL_SERVER}" ctest --preset "$PRESET" --output-on-failure \
  --output-junit "$RESULTS/ctest.xml"

# A silently skipped end-to-end test is not accepted (e.g. missing password, database unreachable)
if grep -q 'status="notrun"\|status="skipped"\|<skipped' "$RESULTS/ctest.xml"; then
  echo "FAILED: some tests were skipped - check the database connection / QLTTTA_E2E_PASSWORD." >&2
  exit 1
fi

printf '\nALL TESTS PASSED: database %s/%s cases (12_tests + 13_server_tests), unit tests + end-to-end GUI tests passed.\n' \
  "$DB_PASSED" "$DB_TOTAL"
