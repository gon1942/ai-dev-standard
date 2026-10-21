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

scripts/verify-plan.sh "$PLAN_FILE"
echo "CONVERGENCE: PASS — 모든 AC, 검증, 리뷰 증거가 충족되었습니다. READY_FOR_REVIEW 선언 가능."
