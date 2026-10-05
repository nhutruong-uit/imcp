#!/usr/bin/env bash
# PostToolUse hook (.claude/settings.json): formats the C++ file Claude has just written or edited, the way the
# team formats by hand (02-cpp-qt.md): git clang-format (changed lines only) for a tracked file, clang-format -i
# for a new file. Never blocks Claude: a non-C++ file, a file outside the repository or a missing clang-format
# simply exits 0.
#
# Usage (normally run by Claude Code with the hook JSON on stdin):
#   echo '{"tool_input":{"file_path":"src/domain/entities/Role.cpp"}}' | .claude/hooks/format-cpp.sh
set -euo pipefail

INPUT="$(cat)"
if command -v jq > /dev/null 2>&1; then
  FILE="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_response.filePath // empty')"
else
  # No jq (e.g. Git Bash on Windows): first "file_path" value, JSON backslashes unescaped
  FILE="$(printf '%s' "$INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 |
          sed 's/^.*:[[:space:]]*"//; s/"$//; s/\\\\/\\/g' || true)"
fi

case "$FILE" in *.cpp | *.h) ;; *) exit 0 ;; esac
[[ -f "$FILE" ]] || exit 0
command -v clang-format > /dev/null 2>&1 || exit 0
FILE="$(cd "$(dirname "$FILE")" && pwd)/$(basename "$FILE")"
# The repository of the FILE, not of this script: a session working in a git worktree (.claude/worktrees/...) runs
# the hook of the main checkout, and the main checkout does not track the worktree's files (they would otherwise be
# taken for new files and formatted as a whole)
ROOT="$(git -C "$(dirname "$FILE")" rev-parse --show-toplevel 2> /dev/null)" || exit 0
# Same path style as FILE: Git for Windows prints D:/repo, while pwd in Git Bash gives /d/repo
ROOT="$(cd "$ROOT" && pwd)"
case "$FILE" in "$ROOT"/build/* | "$ROOT"/dist/*) exit 0 ;; "$ROOT"/*) ;; *) exit 0 ;; esac

cd "$ROOT"
if git ls-files --error-unmatch -- "$FILE" > /dev/null 2>&1; then
  git clang-format --force --quiet -- "$FILE" > /dev/null 2>&1 || true
else
  clang-format -i "$FILE" || true
fi
exit 0
