#!/usr/bin/env bash
# Initializes the QLTTTA database (macOS / Linux): runs database/00..07 in order.
#
# Usage:
#   SQL_PASSWORD='<sa password>' ./scripts/db_init.sh                  # sqlcmd installed on this machine
#   SQL_PASSWORD='<sa password>' ./scripts/db_init.sh --docker imcp-mssql  # sqlcmd inside the container
#
# Environment: SQL_SERVER (default localhost,1433), SQL_USER (default sa), SQL_PASSWORD (required)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DB_DIR="$ROOT/database"
SQL_SERVER="${SQL_SERVER:-localhost,1433}"
SQL_USER="${SQL_USER:-sa}"
CONTAINER=""

if [[ "${1:-}" == "--docker" ]]; then
  CONTAINER="${2:?Missing container name, e.g. --docker imcp-mssql}"
fi
: "${SQL_PASSWORD:?Set SQL_PASSWORD (password of the sa account)}"

FILES=(00_create_database.sql 01_tables.sql 02_functions.sql 03_views.sql
       04_procedures.sql 05_triggers.sql 06_security.sql 07_seed_data.sql)

run_sql() {
  local file="$1" db="$2"
  if [[ -n "$CONTAINER" ]]; then
    docker cp "$DB_DIR/$file" "$CONTAINER:/tmp/$file" >/dev/null
    SQLCMDPASSWORD="$SQL_PASSWORD" docker exec -e SQLCMDPASSWORD "$CONTAINER" \
      /opt/mssql-tools18/bin/sqlcmd -S localhost -U "$SQL_USER" -C -I -b -f 65001 -d "$db" -i "/tmp/$file"
  else
    SQLCMDPASSWORD="$SQL_PASSWORD" sqlcmd -S "$SQL_SERVER" -U "$SQL_USER" -C -I -b -f 65001 -d "$db" -i "$DB_DIR/$file"
  fi
}

for f in "${FILES[@]}"; do
  db=QLTTTA
  [[ "$f" == 00_* ]] && db=master
  echo ">> $f"
  run_sql "$f" "$db"
done
echo "Done. The QLTTTA database is ready (demo accounts: see docs/SETUP.md)."
