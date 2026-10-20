#!/usr/bin/env bash
# validate-plan의 승인·AC 추적성 게이트 회귀 검사.
set -euo pipefail
cd "$(dirname "$0")/.."

TOKEN="validate-plan-$$"
SPEC="docs/product-specs/${TOKEN}.md"
PLAN="docs/exec-plans/active/${TOKEN}.md"
cleanup() { rm -f "$SPEC" "$PLAN"; }
trap cleanup EXIT

cat > "$SPEC" <<'EOF'
# Product Spec: validation fixture

- 상태: approved

## 완료 조건 (Acceptance Criteria)

| ID | 완료 조건 | 기대 결과 |
|---|---|---|
| AC-01 | plan validation | PASS |
| AC-02 | AC traceability | PASS |
EOF

cat > "$PLAN" <<EOF
# Exec Plan: validation fixture

- 상태: active
- 승인: pending
- 제품 명세: $SPEC

## 구현 계획

- 목적: validate-plan test
- 범위: fixture
- 제외: 없음
- 영향 파일 (예상): 없음

## 검증 계획

| AC | 검증 방법 | 기대 증거 |
|---|---|---|
| AC-01 | shell test | exit 0 |
| AC-02 | shell test | exit 0 |

## 회귀 검증 대상

- validate-plan
EOF

if scripts/validate-plan.sh "$PLAN" >/dev/null 2>&1; then
  echo 'FAIL: pending 계획이 통과함' >&2
  exit 1
fi

sed -i 's/^- 승인: pending$/- 승인: approved/' "$PLAN"
sed -i '/| AC-02 | shell test | exit 0 |/d' "$PLAN"
if scripts/validate-plan.sh "$PLAN" >/dev/null 2>&1; then
  echo 'FAIL: 검증 계획에 누락된 AC가 통과함' >&2
  exit 1
fi

sed -i '/| AC-01 | shell test | exit 0 |/a| AC-02 | shell test | exit 0 |' "$PLAN"
scripts/validate-plan.sh "$PLAN" >/dev/null
echo 'PASS: validate-plan approval and AC traceability'

BUG_SPEC="docs/product-specs/${TOKEN}-bug.md"
BUG_PLAN="docs/exec-plans/active/${TOKEN}-bug.md"
cleanup() { rm -f "$SPEC" "$PLAN" "$BUG_SPEC" "$BUG_PLAN"; }

write_bug_spec() {
  cat > "$BUG_SPEC" <<EOF
# Product Spec: bug gate fixture

- 상태: approved
- 유형: 버그

## 재현 조건

$1
## 완료 조건 (Acceptance Criteria)

| ID | 완료 조건 | 기대 결과 |
|---|---|---|
| AC-01 | bug gate | PASS |
EOF
}

write_bug_plan() {
  cat > "$BUG_PLAN" <<EOF
# Exec Plan: bug gate fixture

- 상태: active
- 승인: approved
- 제품 명세: $BUG_SPEC

## 구현 계획

- 목적: bug gate regression

## 검증 계획

| AC | 검증 방법 | 기대 증거 |
|---|---|---|
| AC-01 | shell test | exit 0 |

## 회귀 검증 대상

- validate-plan
EOF
}

expect_block() {
  write_bug_plan
  if scripts/validate-plan.sh "$BUG_PLAN" >/dev/null 2>&1; then
    echo "FAIL: $1 — 차단되지 않고 통과함" >&2
    exit 1
  fi
}

# 분기 1: 재현 조건 섹션 없음 → 차단
write_bug_spec "- 동일 입력: x
- 반복 재현 절차: y
- 기대 결과: z"
sed -i '/^## 재현 조건/,/^## 완료 조건$/{/^## 완료 조건$/!d}' "$BUG_SPEC"
expect_block "버그 명세에 재현 조건 섹션 없음"

# 분기 2: 라벨만 있고 값 비움 → 차단
write_bug_spec "- 동일 입력:
- 반복 재현 절차:
- 기대 결과:"
expect_block "재현 조건 값 미작성"

# 분기 3: 부분 기입(동일 입력만) → 차단
write_bug_spec "- 동일 입력: x"
expect_block "재현 조건 부분 기입"

# 분기 4: 재현 불가 사유만 → 차단
write_bug_spec "- 재현 불가 사유: 프로덕션 의존"
expect_block "대체 판정 방법 누락"

# 분기 5: 재현 불가 사유+대체 판정 → 통과
write_bug_spec "- 재현 불가 사유: 프로덕션 의존
- 대체 판정 방법: 로그 통계 판정"
write_bug_plan
scripts/validate-plan.sh "$BUG_PLAN" >/dev/null

# 분기 6: 세 항목 모두 → 통과
write_bug_spec "- 동일 입력: x
- 반복 재현 절차: y
- 기대 결과: z"
write_bug_plan
scripts/validate-plan.sh "$BUG_PLAN" >/dev/null

# 분기 7: 유형 필드 없는 레거시 명세 → 통과(게이트 미적용)
sed -i '/^- 유형: 버그$/d' "$BUG_SPEC"
write_bug_plan
scripts/validate-plan.sh "$BUG_PLAN" >/dev/null

echo 'PASS: bug reproduction gate 7 branches'
