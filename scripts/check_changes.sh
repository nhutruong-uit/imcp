#!/usr/bin/env bash
# Checks the CHANGES of the current branch against its base branch - the conventions only git can see:
#   1. clang-format on the changed C++ lines only (git clang-format, version pinned in .clang-format-version)
#   2. commit messages: English Conventional Commits "type(scope): summary", no AI attribution lines
#   3. no build output (build/, dist/) or .env file in the repository
# File conventions (SQL syntax and headers, layers, scripts, numbers in the docs) are tested by tst_conventions.
#
# Usage:
#   ./scripts/check_changes.sh                # against origin/develop (git fetch first)
#   ./scripts/check_changes.sh origin/main    # against another base
# Exit code 1 when a check fails. A missing base (shallow clone, no remote) is reported as SKIPPED.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
BASE="${1:-origin/develop}"
TYPES='feat|fix|test|docs|ci|build|refactor|style|chore|perf|revert'
FAILED=0
fail() { echo "FAILED: $1" >&2; FAILED=1; }

if ! BASE_COMMIT="$(git merge-base HEAD "$BASE" 2>/dev/null)"; then
  echo "SKIPPED: base '$BASE' not found (shallow clone or no remote) - run 'git fetch origin' to check the changes."
  exit 0
fi
echo "Changes since $BASE ($(git rev-parse --short "$BASE_COMMIT")):"

# 1. Format of the changed C++ lines (committed and uncommitted; new files once they are git-added)
WANTED="$(tr -d '[:space:]' < .clang-format-version)"
if ! command -v clang-format > /dev/null || ! git clang-format -h > /dev/null 2>&1; then
  fail "clang-format / git clang-format not found (brew install clang-format, or pip install clang-format==$WANTED)"
else
  HAVE="$(clang-format --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
  if [[ "${HAVE%%.*}" != "${WANTED%%.*}" ]]; then
    echo "WARNING: clang-format $HAVE is installed, the team uses $WANTED - the result may differ from CI."
  fi
  FORMAT="$(git clang-format --diff --extensions h,cpp "$BASE_COMMIT" -- src tests tools 2>&1 || true)"
  if [[ "$FORMAT" == *"no modified files to format"* || "$FORMAT" == *"did not modify any files"* ]]; then
    echo "  format: changed C++ lines follow .clang-format"
  else
    echo "$FORMAT"
    fail "changed C++ lines are not formatted - run: git clang-format $BASE_COMMIT"
  fi
fi

# 2. Commit messages (merge commits excluded)
COMMITS=0
for c in $(git rev-list --no-merges "$BASE_COMMIT..HEAD"); do
  COMMITS=$((COMMITS + 1))
  SUBJECT="$(git log -1 --format=%s "$c")"
  SHORT="$(git rev-parse --short "$c")"
  if ! [[ "$SUBJECT" =~ ^($TYPES)(\([a-z0-9._-]+\))?!?:\ [^\ ] ]]; then
    fail "$SHORT \"$SUBJECT\": use \"type(scope): summary\" with type = ${TYPES//|/, }"
  fi
  if printf '%s' "$SUBJECT" | LC_ALL=C grep -q '[^ -~]'; then
    fail "$SHORT \"$SUBJECT\": the subject must be English (ASCII only)"
  fi
  if (( ${#SUBJECT} > 100 )); then
    fail "$SHORT: the subject is longer than 100 characters"
  fi
  if git log -1 --format=%B "$c" | grep -qiE 'Co-Authored-By:.*(Claude|anthropic)|Generated with .*Claude'; then
    fail "$SHORT: remove the AI attribution line (team rule, see AGENTS.md)"
  fi
done
echo "  commits: $COMMITS checked"

# 3. Files that never belong in the repository
TRACKED="$(git ls-files -- build dist; git ls-files | grep -E '(^|/)\.env$' || true)"
if [[ -n "$TRACKED" ]]; then
  echo "$TRACKED"
  fail "build output or .env files are tracked - git rm --cached them"
fi

if [[ $FAILED -ne 0 ]]; then
  exit 1
fi
echo "Change checks passed."
