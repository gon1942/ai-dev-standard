#!/usr/bin/env bash
# 테스트 실행 — 인자: unit | integration | regression | all (기본 all)
# PLACEHOLDER: 프로젝트 테스트 러너로 교체. 도구가 없으면 SKIP 출력 후 통과.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/.."

SCOPE="${1:-all}"
FAILED=0
RAN_ANY=0

run_tests() {
  local name="$1"; shift
  if command -v "$1" >/dev/null 2>&1; then
    echo "--- ${name} (${SCOPE}) ---"
    RAN_ANY=1
    if ! "$@"; then FAILED=1; fi
  fi
}

# 이 프레임워크 원본에만 존재하는 회귀 테스트 묶음이다. bootstrap 대상에는
# test-framework.sh를 복사하지 않으므로 일반 프로젝트의 테스트 책임을 바꾸지 않는다.
# 조건부 실행: 프레임워크 소스가 무변경이면 SKIP (일반 작업 시 15초 절약).
framework_source_changed() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0  # Git 불가 → 항상 실행
  local changed
  changed="$(git diff --name-only HEAD 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null)" || return 0
  printf '%s\n' "$changed" | grep -qE \
    '^(scripts/lib/|scripts/reference/|scripts/test-|docs/skill-contracts/|docs/framework-runtime-assets\.tsv|docs/definition-of-done\.md|docs/testing-policy\.md|\.gitignore|templates/|global-hooks/|bin/)' \
    && return 0  # 프레임워크 변경 감지
  return 1  # 프레임워크 무변경
}

case "$SCOPE" in
  unit|integration) ;;
  regression)
    if [ -x "$SCRIPT_DIR/test-framework.sh" ]; then
      run_tests "framework regression" bash "$SCRIPT_DIR/test-framework.sh"
    fi
    ;;
  *)
    if [ -x "$SCRIPT_DIR/test-framework.sh" ]; then
      if framework_source_changed; then
        run_tests "framework regression" bash "$SCRIPT_DIR/test-framework.sh"
      else
        echo "--- framework regression: SKIP (프레임워크 소스 무변경) ---"
        RAN_ANY=1
      fi
    fi
    ;;
esac

# Node (jest)
if [ -f "jest.config.js" ] || [ -f "jest.config.cjs" ] || [ -f "jest.config.mjs" ]; then
  case "$SCOPE" in
    unit)        run_tests "jest" npx --no-install jest --testPathPattern='tests/unit' ;;
    integration) run_tests "jest" npx --no-install jest --testPathPattern='tests/integration' ;;
    regression)  run_tests "jest" npx --no-install jest ;;
    *)           run_tests "jest" npx --no-install jest ;;
  esac
fi

# Python (pytest)
if [ -f "pytest.ini" ] || [ -f "pyproject.toml" ] || [ -d "tests" ] && command -v pytest >/dev/null 2>&1; then
  case "$SCOPE" in
    unit)        run_tests "pytest" pytest -m unit ;;
    integration) run_tests "pytest" pytest -m integration ;;
    *)           run_tests "pytest" pytest ;;
  esac
fi

if [ "$RAN_ANY" -eq 0 ]; then
  echo "=== TEST(${SCOPE}): SKIP (실행한 테스트 없음) ==="
  exit 3
fi

if [ "$FAILED" -eq 0 ]; then
  echo "=== TEST(${SCOPE}): PASS ==="
else
  echo "=== TEST(${SCOPE}): FAIL ===" >&2
fi
exit $FAILED
