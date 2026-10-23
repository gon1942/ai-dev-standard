#!/usr/bin/env bash
# 명세·실행 계획 템플릿의 필수 섹션·표 헤더를 생성 실측으로 회귀 검사한다.
# 버그 재현 게이트 회귀는 test-validate-plan.sh가 담당한다.
set -euo pipefail
cd "$(dirname "$0")/.."

TOKEN="plan-templates-$$"
SPEC="docs/product-specs/${TOKEN}.md"
PLAN="docs/exec-plans/active/${TOKEN}.md"
DRAFT_PLAN=""
cleanup() { rm -f "$SPEC" "$PLAN" "$DRAFT_PLAN"; }
trap cleanup EXIT

require() {
  grep -Eq "$1" "$2" || { echo "FAIL: $3 — '$1' 없음: $2" >&2; exit 1; }
}
require_fixed() {
  grep -Fq "$1" "$2" || { echo "FAIL: $3 — '$1' 없음: $2" >&2; exit 1; }
}

scripts/new-product-spec.sh "$TOKEN" "template regression test" >/dev/null
SPEC="$(ls docs/product-specs/*-"$TOKEN".md)"

require '^- 유형: ' "$SPEC" "명세 유형 필드"
require '^- 깊이: ' "$SPEC" "명세 깊이 필드"
require '^## 문제·목표$' "$SPEC" "문제·목표 섹션"
require '^## 재현 조건' "$SPEC" "재현 조건 섹션"
require '재현 불가 사유' "$SPEC" "재현 불가 분기"
require '대체 판정 방법' "$SPEC" "대체 판정 항목"
require '^## 대안과 선택 사유' "$SPEC" "대안 섹션"
require '^## 완료 조건' "$SPEC" "AC 섹션"
require '^## 범위$' "$SPEC" "범위 섹션"
require '비목표\(제외\)' "$SPEC" "비목표 항목"

# Draft Product Spec과 Exec Plan을 사전 승인 한 묶음으로 준비할 수 있어야 한다.
scripts/new-exec-plan.sh "$SPEC" >/dev/null
DRAFT_PLAN="$(ls -t docs/exec-plans/active/*-"$TOKEN".md | head -n 1)"
require '^- 상태: draft$' "$SPEC" "draft 명세의 승인 전 상태 유지"
require '^- 승인: pending$' "$DRAFT_PLAN" "공동 승인 대기 계획"
require '^- 사전 승인 묶음: PREAPPROVAL-[0-9]{8}-[0-9]{6}$' "$SPEC" "명세 승인 묶음 ID"
require '^- 사전 승인 묶음: PREAPPROVAL-[0-9]{8}-[0-9]{6}$' "$DRAFT_PLAN" "계획 승인 묶음 ID"
SPEC_BUNDLE="$(sed -n 's/^- 사전 승인 묶음: //p' "$SPEC")"
PLAN_BUNDLE="$(sed -n 's/^- 사전 승인 묶음: //p' "$DRAFT_PLAN")"
[ "$SPEC_BUNDLE" = "$PLAN_BUNDLE" ] || { echo 'FAIL: 명세와 계획의 승인 묶음 ID가 다름' >&2; exit 1; }
if scripts/validate-plan.sh "$DRAFT_PLAN" >/dev/null 2>&1; then
  echo 'FAIL: 공동 사전 승인 전 계획이 구현 게이트를 통과함' >&2
  exit 1
fi

sed -i 's/^- 상태: draft$/- 상태: approved/' "$SPEC"
scripts/new-exec-plan.sh "$SPEC" >/dev/null
PLAN="$(ls -t docs/exec-plans/active/*-"$TOKEN".md | head -n 1)"

require '^## 구현 계획$' "$PLAN" "구현 계획 섹션"
require '^## 구현 작업$' "$PLAN" "구현 작업 섹션"
require_fixed '| 순서 | 변경 대상 | 변경 내용·인터페이스 | 테스트·검증 명령 | 기대 증거 | AC |' "$PLAN" "6열 작업 표 헤더"
require '조사 필요' "$PLAN" "조사 필요 마커 규칙"
require "## Task Graph" "$PLAN" "Task Graph 선택 안내"
require '^## 검증 계획$' "$PLAN" "검증 계획 섹션"
require '^## 회귀 검증 대상$' "$PLAN" "회귀 대상 섹션"
require '^- 검증 계약 버전: 2$' "$PLAN" "검증 계약 버전"
require '^## E2E 판정$' "$PLAN" "E2E 판정 섹션"
require '^- 필요 여부: 불필요$' "$PLAN" "E2E 기본 판정"
require '^- 방식: 해당 없음$' "$PLAN" "E2E 기본 방식"

echo 'PASS: plan templates (spec sections + 6-column work table)'
