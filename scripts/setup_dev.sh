#!/usr/bin/env bash
# Sets up a development machine for QLTTTA in one command (macOS) - the tools of docs/SETUP.md level C:
#   1. Base tools: Xcode Command Line Tools, Homebrew, GitHub CLI
#   2. Build toolchain (Homebrew): Qt 6 + its ODBC plugin, unixODBC, FreeTDS, CMake, Ninja
#   3. clang-format of the team version (.clang-format-version, through pipx): check_changes and the Claude Code hook
#   4. SQL Server 2022 Developer in Docker (docker-compose.yml, .env with a generated sa password), or the SQL Server
#      container that already runs on this machine
#   5. Editor: the recommended VS Code extensions (.vscode/extensions.json), when VS Code is installed
#   6. Git: identity, origin/develop, GitHub CLI login (checked only - you do these yourself)
#   7. Verify: initialize the database, sign in as a demo account, then scripts/test_all.sh
# Every step checks first and installs only what is missing, so it is safe to re-run. Steps that accept a license
# (Docker Desktop, SQL Server Developer, Microsoft ODBC Driver 18) only run with --accept-licenses.
# Windows: scripts/setup_dev.ps1. Linux: not covered - follow the "Full tests" job of .github/workflows/ci.yml.
#
# Usage:
#   ./scripts/setup_dev.sh --check              # report what is installed / missing, change nothing
#   ./scripts/setup_dev.sh --accept-licenses    # set up everything (you accept the licenses listed above)
#   ./scripts/setup_dev.sh                      # open-source tools only (Docker / SQL Server steps are skipped)
#   options: --container <name> (SQL Server container to use), --with-msodbc (Microsoft ODBC Driver 18, optional:
#            the app falls back to FreeTDS), --skip-tests (stop before step 7)
# Environment: SQL_PASSWORD (sa password, default: read from the container), QLTTTA_E2E_PASSWORD (demo accounts).
# Exit code 0 when the machine is ready, 1 when a line of the summary needs attention.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PRESET=macos-debug
CHECK=0
ACCEPT=0
MSODBC=0
SKIP_TESTS=0
CONTAINER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check)           CHECK=1; shift ;;
    --accept-licenses) ACCEPT=1; shift ;;
    --with-msodbc)     MSODBC=1; shift ;;
    --skip-tests)      SKIP_TESTS=1; shift ;;
    --container)       CONTAINER="${2:?Missing container name, e.g. --container imcp-mssql}"; shift 2 ;;
    *) echo "Invalid argument: $1" >&2; exit 2 ;;
  esac
done

case "$(uname -s)" in
  Darwin) ;;
  Linux)
    echo "Linux is not covered by this script: install the tools of the \"Full tests\" job in .github/workflows/ci.yml." >&2
    exit 1 ;;
  *)
    echo "On Windows run: powershell -ExecutionPolicy Bypass -File scripts\\setup_dev.ps1" >&2
    exit 1 ;;
esac

SUMMARY=()
NOT_READY=0
step() { printf '\n==== %s ====\n' "$1"; }
# report <status> <component> <detail>: OK / INSTALLED / WARN are fine, MISSING / SKIPPED / ACTION / FAILED are not
report() {
  SUMMARY+=("$(printf '%-9s %-24s %s' "$1" "$2" "$3")")
  case "$1" in OK | INSTALLED | WARN) ;; *) NOT_READY=1 ;; esac
}
version_ge() { [[ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -1)" == "$2" ]]; }

# 1. Base tools
step "1/7 Base tools"
if xcode-select -p > /dev/null 2>&1; then
  report OK "Xcode Command Line Tools" "$(xcode-select -p)"
elif [[ $CHECK -eq 1 ]]; then
  report MISSING "Xcode Command Line Tools" "xcode-select --install"
else
  xcode-select --install > /dev/null 2>&1 || true
  report ACTION "Xcode Command Line Tools" "finish the install dialog that just opened, then re-run this script"
fi

BREW="$(command -v brew || true)"
for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
  [[ -z "$BREW" && -x "$candidate" ]] && BREW="$candidate"
done
if [[ -n "$BREW" ]]; then
  eval "$("$BREW" shellenv)"
  export HOMEBREW_NO_ENV_HINTS=1
  report OK "Homebrew" "$(brew --version | head -1)"
else
  # The official installer asks for your admin password, so it is never run from here
  report ACTION "Homebrew" "install it yourself from https://brew.sh (needs your password), then re-run"
fi

# brew_pkg <formula> [minimum version]: installs a missing formula, upgrades one older than the minimum
brew_pkg() {
  local name="$1" min="${2:-}" have
  if [[ -z "$BREW" ]]; then
    report SKIPPED "$name" "needs Homebrew"
    return 1
  fi
  have="$(brew list --formula --versions "$name" 2> /dev/null | awk '{print $NF}')"
  have="${have%%_*}"
  if [[ -n "$have" ]] && { [[ -z "$min" ]] || version_ge "$have" "$min"; }; then
    report OK "$name" "$have"
    return 0
  fi
  if [[ $CHECK -eq 1 ]]; then
    report MISSING "$name" "${have:+$have is older than $min - }brew install $name"
    return 1
  fi
  echo ">> brew install $name"
  if { [[ -n "$have" ]] && brew upgrade "$name"; } || { [[ -z "$have" ]] && brew install "$name"; }; then
    report INSTALLED "$name" "$(brew list --formula --versions "$name" | awk '{print $NF}')"
    return 0
  fi
  report FAILED "$name" "brew install $name failed (see the output above)"
  return 1
}
brew_pkg gh || true

# 2. Build toolchain (Qt >= 6.7 and CMake >= 3.25: CMakePresets.json, docs/SETUP.md)
step "2/7 Build toolchain"
TOOLCHAIN=1
brew_pkg qt 6.7 || TOOLCHAIN=0
brew_pkg qt-unixodbc || TOOLCHAIN=0 # Qt's ODBC driver plugin
brew_pkg unixodbc || TOOLCHAIN=0
brew_pkg freetds || TOOLCHAIN=0 # the app uses FreeTDS when Microsoft ODBC Driver 18 is missing
brew_pkg cmake 3.25 || TOOLCHAIN=0
brew_pkg ninja || TOOLCHAIN=0

if [[ $MSODBC -eq 1 ]]; then
  if [[ -n "$BREW" ]] && brew list --formula msodbcsql18 > /dev/null 2>&1; then
    report OK "msodbcsql18" "Microsoft ODBC Driver 18"
  elif [[ $CHECK -eq 1 ]]; then
    report MISSING "msodbcsql18" "Microsoft ODBC Driver 18 (optional)"
  elif [[ $ACCEPT -eq 0 || -z "$BREW" ]]; then
    report SKIPPED "msodbcsql18" "needs Homebrew and --accept-licenses (Microsoft ODBC Driver license)"
  elif brew tap microsoft/mssql-release https://github.com/Microsoft/homebrew-mssql-release &&
       HOMEBREW_ACCEPT_EULA=Y brew install msodbcsql18; then
    # docs/SETUP.md troubleshooting: the driver looks for OpenSSL in $(brew --prefix)/opt/openssl
    OPT="$(brew --prefix)/opt"
    [[ -e "$OPT/openssl" || ! -d "$OPT/openssl@3" ]] || ln -s openssl@3 "$OPT/openssl"
    report INSTALLED "msodbcsql18" "Microsoft ODBC Driver 18"
  else
    report FAILED "msodbcsql18" "brew install msodbcsql18 failed"
  fi
fi

# 3. clang-format of the team version, the same pip package as CI (a different major version formats differently)
step "3/7 clang-format"
WANTED="$(tr -d '[:space:]' < "$ROOT/.clang-format-version")"
cf_version() { clang-format --version 2> /dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true; }
cf_ok() {
  local have
  have="$(cf_version)"
  [[ -n "$have" && "${have%%.*}" == "${WANTED%%.*}" ]] && git clang-format -h > /dev/null 2>&1
}
[[ ":$PATH:" == *":$HOME/.local/bin:"* ]] || export PATH="$PATH:$HOME/.local/bin" # where pipx puts its commands
FOUND="$(cf_version)"
if cf_ok; then
  report OK "clang-format" "$FOUND ($(command -v clang-format))"
elif [[ $CHECK -eq 1 ]]; then
  report MISSING "clang-format" "team version $WANTED${FOUND:+, found $FOUND}"
elif brew_pkg pipx && pipx install --force "clang-format==$WANTED" && pipx ensurepath > /dev/null; then
  if cf_ok; then
    report INSTALLED "clang-format" "$WANTED (pipx, ~/.local/bin; open a new terminal to use it)"
  else
    report WARN "clang-format" "$WANTED is in ~/.local/bin, but $(command -v clang-format) ($(cf_version)) comes first on PATH"
  fi
else
  report FAILED "clang-format" "pipx install clang-format==$WANTED failed"
fi

# 4. SQL Server 2022 in Docker (amd64 image: Apple Silicon runs it through Rosetta)
step "4/7 SQL Server (Docker)"
SQL_READY=0
SQL_PW=""
[[ -d "$HOME/.docker/bin" ]] && export PATH="$PATH:$HOME/.docker/bin" # Docker Desktop's CLI without admin rights
docker_running() { command -v docker > /dev/null 2>&1 && docker info > /dev/null 2>&1; }
container_running() { [[ "$(docker container inspect -f '{{.State.Running}}' "$1" 2> /dev/null)" == true ]]; }
sqlcmd_in() { # sqlcmd_in <user> <password> <sqlcmd arguments...>: sqlcmd inside the container
  local user="$1" password="$2"
  shift 2
  SQLCMDPASSWORD="$password" docker exec -e SQLCMDPASSWORD "$CONTAINER" /opt/mssql-tools18/bin/sqlcmd \
    -S localhost -U "$user" -C -l 5 "$@"
}

if ! command -v docker > /dev/null 2>&1 && [[ ! -d /Applications/Docker.app ]]; then
  if [[ $CHECK -eq 1 ]]; then
    report MISSING "Docker Desktop" "brew install --cask docker-desktop"
  elif [[ $ACCEPT -eq 0 || -z "$BREW" ]]; then
    report SKIPPED "Docker Desktop" "needs Homebrew and --accept-licenses (Docker Subscription Service Agreement)"
  elif brew install --cask docker-desktop; then
    report INSTALLED "Docker Desktop" "brew cask docker-desktop"
  else
    report FAILED "Docker Desktop" "brew install --cask docker-desktop failed"
  fi
fi
if [[ -d /Applications/Docker.app && $CHECK -eq 0 ]] && ! docker_running; then
  echo ">> starting Docker Desktop (up to 3 minutes)"
  open -a Docker 2> /dev/null || true
  for _ in $(seq 1 60); do
    docker_running && break
    sleep 3
  done
fi

if ! command -v docker > /dev/null 2>&1 && [[ ! -d /Applications/Docker.app ]]; then
  : # reported above
elif ! docker_running; then
  report ACTION "Docker Desktop" "not running: open it once, accept its terms, enable Settings > General > Rosetta, re-run"
else
  # Container: --container, else the project's imcp-mssql, else an SQL Server container that already runs
  if [[ -z "$CONTAINER" ]] && docker container inspect imcp-mssql > /dev/null 2>&1; then
    CONTAINER=imcp-mssql
  fi
  if [[ -z "$CONTAINER" ]]; then
    CONTAINER="$(docker ps --format '{{.Names}} {{.Image}}' | awk '$2 ~ /mssql\/server/ {print $1; exit}')"
  fi

  if [[ -n "$CONTAINER" ]] && ! docker container inspect "$CONTAINER" > /dev/null 2>&1; then
    report FAILED "SQL Server container" "no container named $CONTAINER (docker ps -a)"
    CONTAINER=""
  elif [[ -z "$CONTAINER" && $CHECK -eq 1 ]]; then
    report MISSING "SQL Server container" "docker compose up -d (creates imcp-mssql)"
  elif [[ -z "$CONTAINER" && $ACCEPT -eq 0 ]]; then
    report SKIPPED "SQL Server container" "needs --accept-licenses (SQL Server Developer Edition license)"
  elif [[ -z "$CONTAINER" ]] && lsof -nP -iTCP:1433 -sTCP:LISTEN > /dev/null 2>&1; then
    report FAILED "SQL Server container" "port 1433 is used by another program: stop it or pass --container <name>"
  elif [[ -z "$CONTAINER" ]]; then
    # .env holds the sa password of docker-compose.yml: generated once, never printed (gitignored)
    if ! grep -q '^MSSQL_SA_PASSWORD=.' "$ROOT/.env" 2> /dev/null; then
      (umask 077 && printf 'MSSQL_SA_PASSWORD=Dev-%s-Aa1\n' "$(openssl rand -hex 12)" >> "$ROOT/.env")
      echo ">> created .env with a random sa password"
    fi
    echo ">> docker compose up -d"
    if (cd "$ROOT" && docker compose up -d); then
      CONTAINER=imcp-mssql
    else
      report FAILED "SQL Server container" "docker compose up -d failed (see the output above)"
    fi
  elif ! container_running "$CONTAINER" && [[ $CHECK -eq 0 ]]; then
    echo ">> docker start $CONTAINER"
    docker start "$CONTAINER" > /dev/null || true
  fi

  if [[ -n "$CONTAINER" ]] && container_running "$CONTAINER"; then
    SQL_PW="${SQL_PASSWORD:-$(docker exec "$CONTAINER" printenv MSSQL_SA_PASSWORD 2> /dev/null || true)}"
    for _ in $(seq 1 60); do # a new container needs about 20 seconds before it accepts sign-ins
      [[ -n "$SQL_PW" ]] && sqlcmd_in sa "$SQL_PW" -Q "SELECT 1" > /dev/null 2>&1 && SQL_READY=1 && break
      [[ $CHECK -eq 1 || -z "$SQL_PW" ]] && break
      sleep 2
    done
    if [[ $SQL_READY -eq 1 ]]; then
      report OK "SQL Server container" "$CONTAINER, signed in as sa"
      [[ -n "$(docker port "$CONTAINER" 1433/tcp 2> /dev/null)" ]] ||
        report WARN "SQL Server port" "$CONTAINER does not publish 1433: the app and the e2e test use localhost,1433"
      [[ "$(docker exec "$CONTAINER" printenv TZ 2> /dev/null || true)" == Asia/Ho_Chi_Minh ]] ||
        report WARN "SQL Server time zone" "$CONTAINER runs on UTC: dates can be one day off (docs/SETUP.md)"
    elif [[ -z "$SQL_PW" ]]; then
      report ACTION "SQL Server container" "cannot read the sa password of $CONTAINER: set SQL_PASSWORD and re-run"
    else
      # Apple Silicon: the amd64 image needs Docker Desktop's Rosetta emulation (Settings > General)
      report FAILED "SQL Server container" "cannot sign in as sa to $CONTAINER (docker logs $CONTAINER; Rosetta enabled?)"
    fi
  elif [[ -n "$CONTAINER" ]]; then
    report MISSING "SQL Server container" "$CONTAINER is stopped (docker start $CONTAINER)"
  fi
fi

# 5. Editor extensions (clangd, CMake Tools, SQL Server); Microsoft C/C++ conflicts with clangd (docs/CONTRIBUTING.md)
step "5/7 Editor"
extensions() { # extensions <recommendations | unwantedRecommendations>: IDs listed in .vscode/extensions.json
  sed -n "/\"$1\"/,/]/p" "$ROOT/.vscode/extensions.json" | grep -oE '"[A-Za-z0-9-]+\.[A-Za-z0-9.-]+"' | tr -d '"'
}
CODE="$(command -v code || true)"
APP_CODE="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" # "code" not added to PATH yet
[[ -z "$CODE" && -x "$APP_CODE" ]] && CODE="$APP_CODE"
if [[ -n "$CODE" ]]; then
  HAVE_EXT="$("$CODE" --list-extensions 2> /dev/null | tr '[:upper:]' '[:lower:]')"
  has_ext() { grep -qxF "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" <<< "$HAVE_EXT"; }
  NEW_EXT=()
  for ext in $(extensions recommendations); do
    has_ext "$ext" || NEW_EXT+=("$ext")
  done
  if [[ ${#NEW_EXT[@]} -eq 0 ]]; then
    report OK "VS Code extensions" "$(extensions recommendations | tr '\n' ' ')"
  elif [[ $CHECK -eq 1 ]]; then
    report MISSING "VS Code extensions" "${NEW_EXT[*]}"
  else
    for ext in "${NEW_EXT[@]}"; do "$CODE" --install-extension "$ext" > /dev/null; done
    report INSTALLED "VS Code extensions" "${NEW_EXT[*]}"
  fi
  for ext in $(extensions unwantedRecommendations); do
    if has_ext "$ext"; then
      report WARN "VS Code extensions" "$ext conflicts with clangd: code --uninstall-extension $ext"
    fi
  done
else
  report WARN "VS Code" "not found - skipped (Qt Creator or Cursor also work)"
fi

# 6. Git and GitHub (identity and login belong to you, so they are only checked)
step "6/7 Git and GitHub"
NAME="$(git -C "$ROOT" config user.name || true)"
EMAIL="$(git -C "$ROOT" config user.email || true)"
if [[ -n "$NAME" && -n "$EMAIL" ]]; then
  report OK "git identity" "$NAME <$EMAIL>"
else
  report ACTION "git identity" "git config --global user.name \"Your Name\"; git config --global user.email <email>"
fi
if ! git -C "$ROOT" rev-parse --verify -q origin/develop > /dev/null && [[ $CHECK -eq 0 ]]; then
  git -C "$ROOT" fetch -q origin || true
fi
if git -C "$ROOT" rev-parse --verify -q origin/develop > /dev/null; then
  report OK "origin/develop" "base branch of check_changes"
else
  report MISSING "origin/develop" "git fetch origin"
fi
if ! command -v gh > /dev/null 2>&1; then
  : # reported in step 1
elif gh auth status > /dev/null 2>&1; then
  report OK "GitHub CLI login" "used by /imcp-create-pr and /imcp-review"
else
  report ACTION "GitHub CLI login" "gh auth login --web --git-protocol https"
fi

# 7. Verify: database init, a demo sign-in, then the full test suite (the command every PR needs)
step "7/7 Verify"
TESTED=0
if [[ $CHECK -eq 1 || $SKIP_TESTS -eq 1 ]]; then
  echo "Not run (--check / --skip-tests)."
elif [[ $TOOLCHAIN -eq 0 || $SQL_READY -eq 0 ]] || ! cf_ok; then
  report SKIPPED "scripts/test_all.sh" "fix the lines above first"
else
  mkdir -p "$ROOT/build/setup"
  CONFIGURE_LOG="$ROOT/build/setup/cmake_configure.log"
  CONFIGURED=1
  # shellcheck disable=SC2086
  if ! cmake --preset "$PRESET" ${EXTRA_CMAKE_ARGS:-} > "$CONFIGURE_LOG" 2>&1; then
    # docs/SETUP.md troubleshooting: a Command Line Tools SDK newer than Xcode makes CMake report a broken compiler
    SDK=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk
    if [[ -d "$SDK" ]] && grep -qE 'is not able to compile|tapi|unknown architecture' "$CONFIGURE_LOG"; then
      export EXTRA_CMAKE_ARGS="-DCMAKE_OSX_SYSROOT=$SDK"
      rm -rf "${ROOT:?}/build/$PRESET"
      if cmake --preset "$PRESET" "$EXTRA_CMAKE_ARGS" > "$CONFIGURE_LOG" 2>&1; then
        report WARN "CMake configure" "needed EXTRA_CMAKE_ARGS=$EXTRA_CMAKE_ARGS (kept in build/$PRESET)"
      else
        CONFIGURED=0
      fi
    else
      CONFIGURED=0
    fi
  fi

  export QLTTTA_E2E_PASSWORD="${QLTTTA_E2E_PASSWORD:-Demo@2026}" # demo accounts, not a real password
  if [[ $CONFIGURED -eq 0 ]]; then
    tail -20 "$CONFIGURE_LOG"
    report FAILED "CMake configure" "see build/setup/cmake_configure.log"
  elif ! SQL_PASSWORD="$SQL_PW" "$ROOT/scripts/db_init.sh" --docker "$CONTAINER"; then
    report FAILED "Database init" "scripts/db_init.sh failed (see the output above)"
  elif ! sqlcmd_in ql_quan "$QLTTTA_E2E_PASSWORD" -d QLTTTA -Q "SELECT 1" > /dev/null 2>&1; then
    report FAILED "Demo sign-in" "ql_quan cannot sign in to QLTTTA"
  elif SQL_PASSWORD="$SQL_PW" "$ROOT/scripts/test_all.sh" --docker "$CONTAINER" --no-init; then
    report OK "scripts/test_all.sh" "ALL TESTS PASSED (database, server-level, unit and end-to-end tests)"
    TESTED=1
  else
    report FAILED "scripts/test_all.sh" "see the output above and build/test-results/"
  fi
fi

step "Summary"
printf '  %s\n' "${SUMMARY[@]}"
if [[ $NOT_READY -ne 0 ]]; then
  echo
  echo "Not ready yet: handle the MISSING / SKIPPED / ACTION / FAILED lines, then re-run ./scripts/setup_dev.sh"
  exit 1
fi
[[ $TESTED -eq 1 ]] || echo "Tools are in place; the test suite was not run."
cat << EOF

Ready. On this machine:
  Run the app:      open build/$PRESET/src/app/QLTTTA.app   (demo accounts: docs/SETUP.md)
  Before every PR:  SQL_PASSWORD="\$(docker exec $CONTAINER printenv MSSQL_SA_PASSWORD)" ./scripts/test_all.sh --docker $CONTAINER
  Then read:        AGENTS.md, docs/CONTRIBUTING.md, docs/ARCHITECTURE.md (reference module: Students)
EOF
