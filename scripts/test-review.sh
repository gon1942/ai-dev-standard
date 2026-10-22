#!/usr/bin/env bash
# 비교 기준 commit이 없거나 잘못돼도 Review 진입점은 체크리스트를 안전하게 출력해야 한다.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLAN="$ROOT/docs/exec-plans/active/test-review-$$.md"
trap 'rm -f "$PLAN"' EXIT

cat > "$PLAN" <<'EOF'
# Exec Plan: review summary fixture

## 구현 계획

- 목적: automatic evidence summary

## 자동 검증 증거

### 실행 2026-10-21T00:00:00.000Z
- 종료 코드: 0
- 결과 요약: PASS (verify-plan 종료 코드 기준; 전체 출력은 기록하지 않음)

## 완료 기록

- 리뷰: PENDING

## AC 판정

| AC | 판정 | 증거 |
|---|---|---|
| AC-01 | PASS | fixture |
EOF

OUTPUT="$(bash "$ROOT/scripts/review.sh" nonexistent-review-base 2>&1)"

printf '%s\n' "$OUTPUT" | grep -Fq '[Standards Review]' || {
  echo 'FAIL: Standards Review 체크리스트가 없습니다.' >&2
  exit 1
}
printf '%s\n' "$OUTPUT" | grep -Fq '[Spec Review]' || {
  echo 'FAIL: Spec Review 체크리스트가 없습니다.' >&2
  exit 1
}
printf '%s\n' "$OUTPUT" | grep -Fq '[Evidence Review]' || {
  echo 'FAIL: Evidence Review 체크리스트가 없습니다.' >&2
  exit 1
}
if printf '%s\n' "$OUTPUT" | grep -Fq 'fatal:'; then
  echo 'FAIL: 비교 기준이 없을 때 git fatal 출력이 남았습니다.' >&2
  exit 1
fi

PLAN_OUTPUT="$(bash "$ROOT/scripts/review.sh" nonexistent-review-base --plan "$PLAN" 2>&1)"
printf '%s\n' "$PLAN_OUTPUT" | grep -Fq '[결과·검증] AC 판정 1/1 PASS · 자동 검증 증거: PASS (종료 코드 0)' || {
  echo 'FAIL: 자동 검증 증거가 Review 작업 요약에 반영되지 않았습니다.' >&2
  exit 1
}

echo 'PASS: review checklist handles a missing comparison base and summarizes automatic evidence'
