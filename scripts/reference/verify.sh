#!/usr/bin/env bash
# 통합 검증 진입점 — AI가 구현 완료 후 로컬에서 이 스크립트를 실행한다.
# 구성: lint → typecheck → test(all)
# AI는 구현 후 반드시 이 스크립트를 실행하고 결과를 완료 기록에 남긴다.
set -uo pipefail
cd "$(dirname "$0")/.."
DIR="$(dirname "$0")"

CONFIG_FILE=".ai-dev-standard.env"
if [ ! -f "$CONFIG_FILE" ]; then
  echo "설정 파일이 없습니다: $CONFIG_FILE" >&2
  exit 2
fi
# 이 파일은 저장소가 관리하는 단순 KEY=VALUE 설정이다.
# shellcheck source=/dev/null
source "$CONFIG_FILE"

MODE="${AI_DEV_STANDARD_MODE:-}"
REQUIRE_LINT="${AI_DEV_STANDARD_REQUIRE_LINT:-}"
REQUIRE_TYPECHECK="${AI_DEV_STANDARD_REQUIRE_TYPECHECK:-}"
REQUIRE_TEST="${AI_DEV_STANDARD_REQUIRE_TEST:-}"
if [ "$MODE" != "template" ] && [ "$MODE" != "initializing" ] && [ "$MODE" != "active" ]; then
  echo "AI_DEV_STANDARD_MODE는 template, initializing 또는 active여야 합니다." >&2
  exit 2
fi
for value in "$REQUIRE_LINT" "$REQUIRE_TYPECHECK" "$REQUIRE_TEST"; do
  if [ "$value" != "true" ] && [ "$value" != "false" ]; then
    echo "필수 검사 설정은 true 또는 false여야 합니다." >&2
    exit 2
  fi
done

FAIL=0

# 신규 Bootstrap은 승인 계획의 검증 프로필을 사용한다. 기존 레거시 프로젝트는
# 프로필이 없을 때 아래의 기존 lint/typecheck/test 경로를 유지한다.
if [ "$MODE" != "template" ] && [ -f ".ai-dev-standard/verification.json" ]; then
  if ! command -v node >/dev/null 2>&1; then
    echo "검증 프로필을 실행하려면 Node.js가 필요합니다." >&2
    exit 2
  fi
  echo "=========================================="
  echo " verify.sh — 프로젝트 검증 프로필"
  echo "=========================================="
  echo ""
  node -e '
    const path = require("path");
    const verification = require(path.resolve(process.argv[1]));
    const loaded = verification.loadVerificationProfile(process.cwd());
    if (loaded.status !== "ok") {
      console.error(`검증 프로필 설정 오류: ${loaded.message || loaded.status}`);
      process.exit(2);
    }
    const result = verification.runVerificationProfile(process.cwd(), loaded.profile);
    process.exit(result.status === "pass" ? 0 : 1);
  ' "$DIR/lib/verification.js"
  PROFILE_STATUS=$?
  echo ""
  echo "=========================================="
  if [ "$PROFILE_STATUS" -ne 0 ]; then
    echo " RESULT: FAIL — 수정 후 재실행" >&2
  elif [ "$MODE" = "active" ]; then
    echo " RESULT: PASS — Verify 통과. 다음 단계: 독립 Review"
  else
    echo " RESULT: INITIALIZING PASS — active 전환은 승인된 초기화 명령에서만 가능"
  fi
  echo "=========================================="
  exit "$PROFILE_STATUS"
fi

echo "=========================================="
echo " verify.sh — 로컬 표준 검증"
echo "=========================================="

runCheck() {
  local label="$1"
  local required="$2"
  shift 2
  "$@"
  local result=$?
  if [ "$result" -eq 0 ]; then
    return 0
  fi
  if [ "$MODE" = "template" ]; then
    echo "--- ${label}: 템플릿 모드에서는 미구성 검사를 차단하지 않음 ---"
    return 0
  fi
  if [ "$result" -eq 3 ] && [ "$required" = "false" ]; then
    echo "--- ${label}: 선택 검사 미구성 ---"
    return 0
  fi
  FAIL=1
  return 0
}

echo ""
echo "[1/3] Lint"
runCheck "Lint" "$REQUIRE_LINT" "$DIR/lint.sh"

echo ""
echo "[2/3] TypeCheck"
# PLACEHOLDER: 프로젝트 타입체커로 교체 (현재: tsconfig 있으면 tsc --noEmit)
TC_DONE=0
if [ -f "tsconfig.json" ] && command -v npx >/dev/null 2>&1; then
  if npx --no-install tsc --noEmit; then
    echo "=== TYPECHECK: PASS ==="; TC_DONE=1
  else
    echo "=== TYPECHECK: FAIL ===" >&2; FAIL=1; TC_DONE=1
  fi
fi
if [ "$TC_DONE" -eq 0 ]; then
  if [ "$MODE" = "template" ]; then
    echo "--- TypeCheck: 템플릿 모드에서는 미구성 검사를 차단하지 않음 ---"
  elif [ "$REQUIRE_TYPECHECK" = "true" ]; then
    echo "=== TYPECHECK: SKIP (필수 검사 미구성) ===" >&2
    FAIL=1
  else
    echo "--- TypeCheck: 선택 검사 미구성 ---"
  fi
fi

echo ""
echo "[3/3] Tests (all)"
runCheck "Tests" "$REQUIRE_TEST" "$DIR/test.sh" all

# 선택 검사: 신규 중복 클론 경고 (jscpd 기준선). 경고 방식 — FAIL로 판정하지 않는다.
if [ "${AI_DEV_STANDARD_DUPLICATE_CHECK:-}" = "true" ]; then
  echo ""
  echo "[추가] 중복 검사 (신규 클론 — 경고)"
  if ! bash "$DIR/duplicate-check.sh"; then
    echo "--- Duplicate check 건너뜀 (jscpd 실행 불가) ---"
  fi
fi

echo ""
echo "=========================================="
if [ "$FAIL" -eq 0 ] && [ "$MODE" = "active" ]; then
  echo " RESULT: PASS — Verify 통과. 다음 단계: 독립 Review"
elif [ "$FAIL" -eq 0 ]; then
  echo " RESULT: TEMPLATE PASS — active 설정 전에는 READY_FOR_REVIEW 불가"
else
  echo " RESULT: FAIL — 수정 후 재실행" >&2
fi
echo "=========================================="
exit $FAIL
