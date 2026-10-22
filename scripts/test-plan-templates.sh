#!/usr/bin/env bash
# 명세·실행 계획 템플릿의 필수 섹션·표 헤더를 생성 실측으로 회귀 검사한다.
# 버그 재현 게이트 회귀는 test-validate-plan.sh가 담당한다.
set -euo pipefail
cd "$(dirname "$0")/.."

TOKEN="plan-templates-$$"
SPEC="docs/product-specs/${TOKEN}.md"
PLAN="docs/exec-plans/active/${TOKEN}.md"
cleanup() { rm -f "$SPEC" "$PLAN"; }
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

sed -i 's/^- 상태: draft$/- 상태: approved/' "$SPEC"
scripts/new-exec-plan.sh "$SPEC" >/dev/null
PLAN="$(ls docs/exec-plans/active/*-"$TOKEN".md)"

require '^## 구현 계획$' "$PLAN" "구현 계획 섹션"
require '^## 구현 작업$' "$PLAN" "구현 작업 섹션"
require_fixed '| 순서 | 변경 대상 | 변경 내용·인터페이스 | 테스트·검증 명령 | 기대 증거 | AC |' "$PLAN" "6열 작업 표 헤더"
require '조사 필요' "$PLAN" "조사 필요 마커 규칙"
require '^## 검증 계획$' "$PLAN" "검증 계획 섹션"
require '^## 회귀 검증 대상$' "$PLAN" "회귀 대상 섹션"
require '^- 검증 계약 버전: 2$' "$PLAN" "검증 계약 버전"
require '^## E2E 판정$' "$PLAN" "E2E 판정 섹션"
require '^- 필요 여부: 불필요$' "$PLAN" "E2E 기본 판정"
require '^- 방식: 해당 없음$' "$PLAN" "E2E 기본 방식"

echo 'PASS: plan templates (spec sections + 6-column work table)'
