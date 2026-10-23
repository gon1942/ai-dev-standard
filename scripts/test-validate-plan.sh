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

# 공동 사전 승인 식별자가 있는 경우 양쪽 기록이 모두 일치해야 한다.
sed -i '/^- 상태: approved$/a- 사전 승인 묶음: PREAPPROVAL-20261023-000001\n- 승인 결정자: 사용자\n- 승인 일자: 2026-10-23' "$SPEC"
sed -i '/^- 승인: approved$/a- 사전 승인 묶음: PREAPPROVAL-20261023-000001\n- 승인 결정자: 사용자\n- 승인 일자: 2026-10-23' "$PLAN"
scripts/validate-plan.sh "$PLAN" >/dev/null

sed -i 's/PREAPPROVAL-20261023-000001/PREAPPROVAL-20261023-000002/' "$PLAN"
if scripts/validate-plan.sh "$PLAN" >/dev/null 2>&1; then
  echo 'FAIL: 불일치한 사전 승인 묶음이 통과함' >&2
  exit 1
fi
sed -i 's/PREAPPROVAL-20261023-000002/PREAPPROVAL-20261023-000001/' "$PLAN"
sed -i 's/^- 승인 일자: 2026-10-23$/- 승인 일자: yesterday/' "$PLAN"
if scripts/validate-plan.sh "$PLAN" >/dev/null 2>&1; then
  echo 'FAIL: 형식이 잘못된 사전 승인 일자가 통과함' >&2
  exit 1
fi
sed -i 's/^- 승인 일자: yesterday$/- 승인 일자: 2026-10-23/' "$PLAN"
sed -i '/^- 승인 결정자:/d' "$PLAN"
if scripts/validate-plan.sh "$PLAN" >/dev/null 2>&1; then
  echo 'FAIL: 부분 기록된 사전 승인이 통과함' >&2
  exit 1
fi
sed -i '/^- 사전 승인 묶음:/d; /^- 승인 일자:/d' "$PLAN"
sed -i '/^- 사전 승인 묶음:/d; /^- 승인 결정자:/d; /^- 승인 일자:/d' "$SPEC"
scripts/validate-plan.sh "$PLAN" >/dev/null

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

# ── Task Graph 게이트 (선택 섹션) ──
TG_PLAN="docs/exec-plans/active/${TOKEN}-tg.md"
cleanup() { rm -f "$SPEC" "$PLAN" "$BUG_SPEC" "$BUG_PLAN" "$TG_PLAN"; }

write_tg_plan() {
  cat > "$TG_PLAN" <<EOF
# Exec Plan: task graph fixture

- 상태: active
- 승인: approved
- 제품 명세: $SPEC

## 구현 계획

- 목적: task graph gate

## 구현 작업

| 순서 | 변경 대상 | 변경 내용·인터페이스 | 테스트·검증 명령 | 기대 증거 | AC |
|---:|---|---|---|---|---|
| 1 | a | b | c | d | AC-01 |
| 2 | a | b | c | d | AC-02 |

$1

## 검증 계획

| AC | 검증 방법 | 기대 증거 |
|---|---|---|
| AC-01 | shell test | exit 0 |
| AC-02 | shell test | exit 0 |

## 회귀 검증 대상

- validate-plan
EOF
}

TG_SECTION='## Task Graph

| Task | 의존 | 소유 파일 | 상태 |
|---|---|---|---|
| T1 | — | scripts/a.js | 구현 전 |
| T2 | T1 | scripts/b.js | 구현 전 |'

# 정상 그래프 → 통과
write_tg_plan "$TG_SECTION"
scripts/validate-plan.sh "$TG_PLAN" >/dev/null

# 섹션 없음(하위 호환) → 통과
write_tg_plan ""
scripts/validate-plan.sh "$TG_PLAN" >/dev/null

# 섹션 있고 행 0개 → 통과 (검증 생략)
write_tg_plan '## Task Graph'
scripts/validate-plan.sh "$TG_PLAN" >/dev/null

expect_tg_block() {
  write_tg_plan "$1"
  if scripts/validate-plan.sh "$TG_PLAN" >/dev/null 2>&1; then
    echo "FAIL: Task Graph — $2 — 차단되지 않고 통과함" >&2
    exit 1
  fi
}

# 중복 ID → 차단
expect_tg_block '## Task Graph

| Task | 의존 | 소유 파일 | 상태 |
|---|---|---|---|
| T1 | — | a.js | 구현 전 |
| T1 | — | b.js | 구현 전 |' "중복 Task ID"

# 미정의 참조 → 차단
expect_tg_block '## Task Graph

| Task | 의존 | 소유 파일 | 상태 |
|---|---|---|---|
| T1 | T9 | a.js | 구현 전 |' "미정의 의존 참조"

# 순환 참조 → 차단
expect_tg_block '## Task Graph

| Task | 의존 | 소유 파일 | 상태 |
|---|---|---|---|
| T1 | T2 | a.js | 구현 전 |
| T2 | T1 | b.js | 구현 전 |' "순환 참조"

# 자기 참조 → 차단 (1-node 순환)
expect_tg_block '## Task Graph

| Task | 의존 | 소유 파일 | 상태 |
|---|---|---|---|
| T1 | T1 | a.js | 구현 전 |' "자기 참조"

# 허용 외 상태 → 차단
expect_tg_block '## Task Graph

| Task | 의존 | 소유 파일 | 상태 |
|---|---|---|---|
| T1 | — | a.js | 완료 |' "허용 외 상태 값"

# ID 형식 오류 → 차단
expect_tg_block '## Task Graph

| Task | 의존 | 소유 파일 | 상태 |
|---|---|---|---|
| A1 | — | a.js | 구현 전 |' "Task ID 형식"

echo 'PASS: task graph gate 9 branches'
