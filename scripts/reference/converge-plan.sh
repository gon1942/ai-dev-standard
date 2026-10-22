#!/usr/bin/env bash
# 실행 계획의 AC, 검증, 리뷰 증거가 모두 충족됐는지 읽기 전용으로 판정한다.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
  echo "사용법: scripts/converge-plan.sh <docs/exec-plans/active/실행계획.md>" >&2
  exit 2
fi

PLAN_FILE="$1"
case "$PLAN_FILE" in
  docs/exec-plans/active/*) ;;
  *) echo "활성 실행 계획 파일을 지정하세요: $PLAN_FILE" >&2; exit 2 ;;
esac

if ! grep -Eq '^AI_DEV_STANDARD_MODE=active$' .ai-dev-standard.env; then
  echo "CONVERGENCE: BLOCKED — AI_DEV_STANDARD_MODE=active 설정 후에만 READY_FOR_REVIEW를 판정할 수 있습니다." >&2
  exit 1
fi

if ! grep -Eq '^## 완료 기록$' "$PLAN_FILE"; then
  echo "CONVERGENCE: BLOCKED — 완료 기록이 없습니다." >&2
  exit 1
fi
if ! grep -Eq '^## AC 판정$' "$PLAN_FILE"; then
  echo "CONVERGENCE: BLOCKED — AC 판정 표가 없습니다." >&2
  exit 1
fi
if ! grep -Eq '^- 리뷰: PASS$' "$PLAN_FILE"; then
  echo "CONVERGENCE: BLOCKED — 리뷰 결과가 PASS가 아닙니다." >&2
  exit 1
fi

ac_rows="$(awk '/^## AC 판정$/{inside=1; next} inside && /^## /{exit} inside && /^\| AC-[^|]+ \|/{print}' "$PLAN_FILE")"
if [ -z "$ac_rows" ]; then
  echo "CONVERGENCE: BLOCKED — AC 판정 항목이 없습니다." >&2
  exit 1
fi
if printf '%s\n' "$ac_rows" | grep -Evq '^\| AC-[^|]+ \| PASS \| .+ \|$'; then
  echo "CONVERGENCE: BLOCKED — 모든 AC는 PASS와 비어 있지 않은 증거를 가져야 합니다." >&2
  exit 1
fi

CONTRACT_VERSION="$(sed -n 's/^- 검증 계약 버전: //p' "$PLAN_FILE" | head -n 1)"
if [ -n "$CONTRACT_VERSION" ] && [ "$CONTRACT_VERSION" != "2" ]; then
  echo "CONVERGENCE: BLOCKED — 지원하지 않는 검증 계약 버전입니다." >&2
  exit 1
fi
E2E_SECTION="$(awk '/^## E2E 판정$/{inside=1; next} /^## /{inside=0} inside {print}' "$PLAN_FILE")"
E2E_NEEDED="$(printf '%s\n' "$E2E_SECTION" | sed -n 's/^- 필요 여부: //p' | head -n 1)"
E2E_METHOD="$(printf '%s\n' "$E2E_SECTION" | sed -n 's/^- 방식: //p' | head -n 1)"
if [ "$CONTRACT_VERSION" = "2" ] && [ "$E2E_NEEDED" = "필요" ]; then
  E2E_EVIDENCE="$(awk '/^## E2E 검증 증거$/{inside=1; next} /^## /{inside=0} inside {print}' "$PLAN_FILE")"
  if [ "$E2E_METHOD" = "수동 Browser UAT" ]; then
    printf '%s\n' "$E2E_EVIDENCE" | grep -Eq '^### 수동 UAT ' &&
      printf '%s\n' "$E2E_EVIDENCE" | grep -Eq '^- 실행 일시: .+' &&
      printf '%s\n' "$E2E_EVIDENCE" | grep -Eq '^- 관찰 결과: .+' &&
      printf '%s\n' "$E2E_EVIDENCE" | grep -Fxq -- '- 판정: PASS' || {
      echo "CONVERGENCE: BLOCKED — 수동 UAT E2E 증거가 PASS가 아닙니다." >&2
      exit 1
    }
  else
    # 과거 PASS가 이후 실행의 FAIL을 가리지 않도록 마지막 자동 E2E 실행 블록만 본다.
    E2E_LAST_AUTO="$(printf '%s\n' "$E2E_EVIDENCE" | awk '/^### 자동 E2E 실행 /{capture=1; out=$0 "\n"; next} capture{out=out $0 "\n"} END{printf "%s", out}')"
    printf '%s\n' "$E2E_LAST_AUTO" | grep -Fxq -- '- 종료 코드: 0' &&
      printf '%s\n' "$E2E_LAST_AUTO" | grep -Fxq -- '- 결과 요약: PASS (test e2e 종료 코드 기준; 전체 출력은 기록하지 않음)' || {
      echo "CONVERGENCE: BLOCKED — 자동 E2E 증거가 PASS가 아닙니다." >&2
      exit 1
    }
  fi
fi

scripts/verify-plan.sh "$PLAN_FILE"
echo "CONVERGENCE: PASS — 모든 AC, 검증, 리뷰 증거가 충족되었습니다. READY_FOR_REVIEW 선언 가능."
