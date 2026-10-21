#!/usr/bin/env bash
# 린트/정적 검사 — PLACEHOLDER: 프로젝트 린터로 교체
# exit 0이어야 통과. 도구가 없으면 SKIP을 출력하고 통과한다(초기 스캐폴드 호환).
set -uo pipefail
cd "$(dirname "$0")/.."

FAILED=0
RAN_ANY=0
run_if_exists() {
  local name="$1"; shift
  if command -v "$1" >/dev/null 2>&1; then
    echo "--- ${name} ---"
    RAN_ANY=1
    if ! "$@"; then FAILED=1; fi
  else
    echo "--- ${name}: SKIP (도구 없음) ---"
  fi
}

# JS/TS (예: ESLint)
if [ -f ".eslintrc.json" ] || [ -f "eslint.config.js" ] || [ -f "eslint.config.mjs" ]; then
  run_if_exists "eslint" npx --no-install eslint . --max-warnings=0
fi

# Python (예: ruff)
if [ -f "pyproject.toml" ] || [ -f ".ruff.toml" ]; then
  run_if_exists "ruff" ruff check .
fi

if [ "$RAN_ANY" -eq 0 ]; then
  echo "=== LINT: SKIP (실행한 검사 없음) ==="
  exit 3
elif [ "$FAILED" -eq 0 ]; then
  echo "=== LINT: PASS ==="
else
  echo "=== LINT: FAIL ===" >&2
fi
exit $FAILED
