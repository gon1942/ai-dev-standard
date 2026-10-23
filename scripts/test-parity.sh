#!/usr/bin/env bash
# bash(reference)↔Node 동치성 시험 — Node 이관(트랙 B)의 증거.
# repository-test 범위: 프레임워크 원본 전용, 배포 대상에 복사되지 않는다.
#
# bash 측 기준선은 scripts/reference/의 원본 구현이다 (활성 scripts/*.sh는 shim).
# 동치성 정의 (design-docs/verification-rearchitecture.md §5):
#   L1 (계약): 종료 코드 + 핵심 출력 라인 일치
#   L2 (참고): 타임스탬프 정규화 후 전체 출력·생성 파일 내용 일치
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REF="$ROOT/scripts/reference"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS_COUNT=0
FAIL_COUNT=0

normalize() {
  sed -E 's/[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6}/TIMESTAMP/g; s/PREAPPROVAL-[0-9]{8}-[0-9]{6}/PREAPPROVAL-TIMESTAMP/g; s/[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}/DATETIME/g; s/[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}/DATETIME/g; s#\.npm/_logs/\S+#NPMLOG#g'
}

compare_outputs() {
  local label="$1" bash_code="$2" bash_out="$3" node_code="$4" node_out="$5"
  if [ "$bash_code" != "$node_code" ]; then
    echo "FAIL [$label] 종료 코드 불일치: bash=$bash_code node=$node_code" >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return
  fi
  if ! diff -q <(normalize < "$bash_out") <(normalize < "$node_out") >/dev/null; then
    echo "FAIL [$label] 출력 불일치:" >&2
    diff <(normalize < "$bash_out") <(normalize < "$node_out") | head -5 >&2 || true
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return
  fi
  PASS_COUNT=$((PASS_COUNT + 1))
}

compare_trees() {
  local label="$1" bash_root="$2" node_root="$3"
  # 파일명에 생성 시각이 포함되는 산출물(실행 계획 등)은 bash·Node 실행이 초 경계를
  # 걸치면 실제 파일명이 1초 차이 날 수 있다. 정규화 키로 매핑해 비교한다.
  local bash_map node_map
  bash_map="$(cd "$bash_root" && find . -type f -not -path './scripts/*' | sort | \
    while IFS= read -r f; do printf '%s\t%s\n' "$(printf '%s' "$f" | normalize)" "$f"; done)"
  node_map="$(cd "$node_root" && find . -type f -not -path './scripts/*' | sort | \
    while IFS= read -r f; do printf '%s\t%s\n' "$(printf '%s' "$f" | normalize)" "$f"; done)"
  if [ "$(printf '%s\n' "$bash_map" | awk -F'\t' '{print $1}')" != \
       "$(printf '%s\n' "$node_map" | awk -F'\t' '{print $1}')" ]; then
    echo "FAIL [$label] 생성 파일 목록 불일치:" >&2
    diff <(printf '%s\n' "$bash_map" | awk -F'\t' '{print $1}') \
         <(printf '%s\n' "$node_map" | awk -F'\t' '{print $1}') >&2 || true
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return
  fi
  local key bfile nfile
  while IFS=$'\t' read -r key bfile; do
    [ -n "$key" ] || continue
    nfile="$(printf '%s\n' "$node_map" | awk -F'\t' -v k="$key" '$1==k{print $2; exit}')"
    if [ -z "$nfile" ]; then
      echo "FAIL [$label] 대응 파일 없음: $bfile" >&2
      FAIL_COUNT=$((FAIL_COUNT + 1))
      return
    fi
    if ! diff -q <(normalize < "$bash_root/$bfile") <(normalize < "$node_root/$nfile") >/dev/null; then
      echo "FAIL [$label] 파일 내용 불일치: $bfile" >&2
      diff <(normalize < "$bash_root/$bfile") <(normalize < "$node_root/$nfile") | head -5 >&2 || true
      FAIL_COUNT=$((FAIL_COUNT + 1))
      return
    fi
  done <<< "$bash_map"
  PASS_COUNT=$((PASS_COUNT + 1))
}

# bash 기준선(reference 원본)은 대상 루트의 scripts/에서 실행해야 루트가 분리된다.
setup_case() {
  local case_dir="$1"; shift
  mkdir -p "$case_dir/scripts"
  local script
  for script in "$@"; do
    cp "$REF/$script" "$case_dir/scripts/$script"
  done
}

node_cli() {
  local root="$1"; shift
  AI_DEV_STANDARD_ROOT="$root" node "$ROOT/scripts/lib/cli.js" "$@"
}

# ── 케이스 1: 명세 생성 성공 (한글 작업명으로 SAFE_NAME 동치 확인) ──
{
  BD="$TMP/c1-bash"; ND="$TMP/c1-node"
  setup_case "$BD" new-product-spec.sh new-exec-plan.sh; mkdir -p "$ND"
  set +e
  (cd "$BD" && bash scripts/new-product-spec.sh "가-힣 테스트" "사용자 요청 원문") > "$TMP/c1-bash.out" 2>&1
  BC=$?
  node_cli "$ND" new-product-spec "가-힣 테스트" "사용자 요청 원문" > "$TMP/c1-node.out" 2>&1
  NC=$?
  set -e
  compare_outputs "spec-성공" "$BC" "$TMP/c1-bash.out" "$NC" "$TMP/c1-node.out"
  compare_trees "spec-성공-파일" "$BD" "$ND"
}

# ── 케이스 2: 명세 사용법 오류 (인자 1개 → exit 2) ──
{
  BD="$TMP/c2-bash"; ND="$TMP/c2-node"
  setup_case "$BD" new-product-spec.sh; mkdir -p "$ND"
  set +e
  (cd "$BD" && bash scripts/new-product-spec.sh "작업명만") > "$TMP/c2-bash.out" 2>&1
  BC=$?
  node_cli "$ND" new-product-spec "작업명만" > "$TMP/c2-node.out" 2>&1
  NC=$?
  set -e
  compare_outputs "spec-사용법오류" "$BC" "$TMP/c2-bash.out" "$NC" "$TMP/c2-node.out"
}

# ── 케이스 3: draft 명세 → 공동 승인 대기 계획 생성 ──
{
  BD="$TMP/c3-bash"; ND="$TMP/c3-node"
  setup_case "$BD" new-exec-plan.sh; mkdir -p "$ND"
  for D in "$BD" "$ND"; do
    mkdir -p "$D/docs/product-specs"
    printf '# Product Spec: 동치성 확인\n\n- 상태: draft\n' > "$D/docs/product-specs/spec.md"
  done
  set +e
  (cd "$BD" && bash scripts/new-exec-plan.sh docs/product-specs/spec.md) > "$TMP/c3-bash.out" 2>&1
  BC=$?
  node_cli "$ND" new-exec-plan docs/product-specs/spec.md > "$TMP/c3-node.out" 2>&1
  NC=$?
  set -e
  compare_outputs "계획-draft-공동승인대기" "$BC" "$TMP/c3-bash.out" "$NC" "$TMP/c3-node.out"
  compare_trees "계획-draft-공동승인대기-파일" "$BD" "$ND"
}

# ── 케이스 4: 승인 명세 → 계획 생성 성공 ──
{
  BD="$TMP/c4-bash"; ND="$TMP/c4-node"
  setup_case "$BD" new-exec-plan.sh; mkdir -p "$ND"
  for D in "$BD" "$ND"; do
    mkdir -p "$D/docs/product-specs"
    printf '# Product Spec: 동치성 확인\n\n- 상태: approved\n' > "$D/docs/product-specs/spec.md"
  done
  set +e
  (cd "$BD" && bash scripts/new-exec-plan.sh docs/product-specs/spec.md) > "$TMP/c4-bash.out" 2>&1
  BC=$?
  node_cli "$ND" new-exec-plan docs/product-specs/spec.md > "$TMP/c4-node.out" 2>&1
  NC=$?
  set -e
  compare_outputs "계획-성공" "$BC" "$TMP/c4-bash.out" "$NC" "$TMP/c4-node.out"
  compare_trees "계획-성공-파일" "$BD" "$ND"
}

# ── 케이스 5: lint — 설정 없음 → SKIP exit 3 ──
{
  BD="$TMP/c5-bash"; ND="$TMP/c5-node"
  setup_case "$BD" lint.sh; mkdir -p "$ND"
  set +e
  (cd "$BD" && bash scripts/lint.sh) > "$TMP/c5-bash.out" 2>&1
  BC=$?
  node_cli "$ND" lint > "$TMP/c5-node.out" 2>&1
  NC=$?
  set -e
  compare_outputs "lint-설정없음" "$BC" "$TMP/c5-bash.out" "$NC" "$TMP/c5-node.out"
}

# ── 케이스 6: lint — eslint 설정 + 설치 안 된 eslint → FAIL exit 1 ──
{
  BD="$TMP/c6-bash"; ND="$TMP/c6-node"
  setup_case "$BD" lint.sh; mkdir -p "$ND"
  for D in "$BD" "$ND"; do echo "{}" > "$D/eslint.config.js"; done
  set +e
  (cd "$BD" && bash scripts/lint.sh) > "$TMP/c6-bash.out" 2>&1
  BC=$?
  node_cli "$ND" lint > "$TMP/c6-node.out" 2>&1
  NC=$?
  set -e
  compare_outputs "lint-실패" "$BC" "$TMP/c6-bash.out" "$NC" "$TMP/c6-node.out"
}

# ── 케이스 7: test — 설정 없음 → SKIP exit 3 ──
{
  BD="$TMP/c7-bash"; ND="$TMP/c7-node"
  setup_case "$BD" test.sh; mkdir -p "$ND"
  set +e
  (cd "$BD" && bash scripts/test.sh) > "$TMP/c7-bash.out" 2>&1
  BC=$?
  node_cli "$ND" test > "$TMP/c7-node.out" 2>&1
  NC=$?
  set -e
  compare_outputs "test-설정없음" "$BC" "$TMP/c7-bash.out" "$NC" "$TMP/c7-node.out"
}

# ── 케이스 8~16: 핵심 게이트 4종 (validate-plan·verify·verify-plan·converge) ──

write_gate_fixtures() {
  local dir="$1" mode="$2" require_test="$3" plan_variant="$4"
  mkdir -p "$dir/docs/product-specs" "$dir/docs/exec-plans/active"
  cat > "$dir/docs/product-specs/spec.md" <<'EOS'
# Product Spec: 게이트 동치성

- 상태: approved
- 유형: 신규 기능  (신규 기능 | 수정 | 버그 | 리팩터링 | 성능)

## 완료 조건 (Acceptance Criteria)

| ID | 완료 조건 | 기대 결과 |
|---|---|---|
| AC-01 | 기능 동작 | 예상 결과 |
| AC-02 | 회귀 없음 | 기존 테스트 PASS |
EOS
  cat > "$dir/docs/exec-plans/active/plan.md" <<EOS
# Exec Plan: 게이트 동치성

- 상태: active
- 승인: ${PLAN_APPROVAL:-approved}
- 제품 명세: docs/product-specs/spec.md

## 구현 계획

- 목적: 동치성 검증

## 검증 계획

${PLAN_VERIFY_ROWS:-| AC-01 | 자동 테스트 | 결과 |
| AC-02 | 자동 테스트 | 결과 |}

## 회귀 검증 대상

- 없음
EOS
  if [ "$plan_variant" = "converged" ]; then
    cat >> "$dir/docs/exec-plans/active/plan.md" <<'EOS'

## 완료 기록

- 완료일시: 2026-10-21 10:00
- 검증 증거:
  - verify-plan.sh 결과: PASS
- 리뷰: PASS

## AC 판정

| AC | 판정 | 증거 |
|---|---|---|
| AC-01 | PASS | 테스트 통과 |
| AC-02 | PASS | 회귀 없음 확인 |
EOS
  fi
  cat > "$dir/.ai-dev-standard.env" <<EOF
AI_DEV_STANDARD_MODE=${mode}
AI_DEV_STANDARD_REQUIRE_LINT=false
AI_DEV_STANDARD_REQUIRE_TYPECHECK=false
AI_DEV_STANDARD_REQUIRE_TEST=${require_test}
EOF
}

# g1: validate-plan 사용법 오류 (인자 없음 → exit 2)
{
  BD="$TMP/g1-bash"; ND="$TMP/g1-node"
  setup_case "$BD" validate-plan.sh; mkdir -p "$ND"
  set +e
  (cd "$BD" && bash scripts/validate-plan.sh) > "$TMP/g1-bash.out" 2>&1; BC=$?
  node_cli "$ND" validate-plan > "$TMP/g1-node.out" 2>&1; NC=$?
  set -e
  compare_outputs "게이트-사용법오류" "$BC" "$TMP/g1-bash.out" "$NC" "$TMP/g1-node.out"
}

# g2: validate-plan 유효 계획 → PLAN VALID exit 0
{
  BD="$TMP/g2-bash"; ND="$TMP/g2-node"
  setup_case "$BD" validate-plan.sh
  write_gate_fixtures "$BD" template false simple
  write_gate_fixtures "$ND" template false simple
  set +e
  (cd "$BD" && bash scripts/validate-plan.sh docs/exec-plans/active/plan.md) > "$TMP/g2-bash.out" 2>&1; BC=$?
  node_cli "$ND" validate-plan docs/exec-plans/active/plan.md > "$TMP/g2-node.out" 2>&1; NC=$?
  set -e
  compare_outputs "게이트-유효계획" "$BC" "$TMP/g2-bash.out" "$NC" "$TMP/g2-node.out"
}

# g3: validate-plan 미승인 → exit 2
{
  BD="$TMP/g3-bash"; ND="$TMP/g3-node"
  setup_case "$BD" validate-plan.sh
  write_gate_fixtures "$BD" template false simple
  PLAN_APPROVAL="pending" write_gate_fixtures "$ND" template false simple
  for D in "$BD"; do
    sed -i.bak 's/^- 승인: approved$/- 승인: pending/' "$D/docs/exec-plans/active/plan.md" && rm -f "$D/docs/exec-plans/active/plan.md.bak"
  done
  set +e
  (cd "$BD" && bash scripts/validate-plan.sh docs/exec-plans/active/plan.md) > "$TMP/g3-bash.out" 2>&1; BC=$?
  node_cli "$ND" validate-plan docs/exec-plans/active/plan.md > "$TMP/g3-node.out" 2>&1; NC=$?
  set -e
  compare_outputs "게이트-미승인" "$BC" "$TMP/g3-bash.out" "$NC" "$TMP/g3-node.out"
}

# g4: validate-plan AC 누락 → exit 2
{
  BD="$TMP/g4-bash"; ND="$TMP/g4-node"
  setup_case "$BD" validate-plan.sh
  write_gate_fixtures "$BD" template false simple
  write_gate_fixtures "$ND" template false simple
  for D in "$BD" "$ND"; do
    sed -i.bak '/AC-02/d' "$D/docs/exec-plans/active/plan.md" && rm -f "$D/docs/exec-plans/active/plan.md.bak"
  done
  set +e
  (cd "$BD" && bash scripts/validate-plan.sh docs/exec-plans/active/plan.md) > "$TMP/g4-bash.out" 2>&1; BC=$?
  node_cli "$ND" validate-plan docs/exec-plans/active/plan.md > "$TMP/g4-node.out" 2>&1; NC=$?
  set -e
  compare_outputs "게이트-AC누락" "$BC" "$TMP/g4-bash.out" "$NC" "$TMP/g4-node.out"
}

# g4b: validate-plan Task Graph 정상 → PLAN VALID exit 0 (선택 섹션 하위 호환)
{
  BD="$TMP/g4b-bash"; ND="$TMP/g4b-node"
  setup_case "$BD" validate-plan.sh
  write_gate_fixtures "$BD" template false simple
  write_gate_fixtures "$ND" template false simple
  for D in "$BD" "$ND"; do
    cat >> "$D/docs/exec-plans/active/plan.md" <<'EOS'

## Task Graph

| Task | 의존 | 소유 파일 | 상태 |
|---|---|---|---|
| T1 | — | scripts/a.js | 구현 전 |
| T2 | T1 | scripts/b.js | 구현 전 |
EOS
  done
  set +e
  (cd "$BD" && bash scripts/validate-plan.sh docs/exec-plans/active/plan.md) > "$TMP/g4b-bash.out" 2>&1; BC=$?
  node_cli "$ND" validate-plan docs/exec-plans/active/plan.md > "$TMP/g4b-node.out" 2>&1; NC=$?
  set -e
  compare_outputs "게이트-태스크그래프정상" "$BC" "$TMP/g4b-bash.out" "$NC" "$TMP/g4b-node.out"
}

# g4c: validate-plan Task Graph 순환 참조 → exit 2 동일 메시지
{
  BD="$TMP/g4c-bash"; ND="$TMP/g4c-node"
  setup_case "$BD" validate-plan.sh
  write_gate_fixtures "$BD" template false simple
  write_gate_fixtures "$ND" template false simple
  for D in "$BD" "$ND"; do
    cat >> "$D/docs/exec-plans/active/plan.md" <<'EOS'

## Task Graph

| Task | 의존 | 소유 파일 | 상태 |
|---|---|---|---|
| T1 | T2 | scripts/a.js | 구현 전 |
| T2 | T1 | scripts/b.js | 구현 전 |
EOS
  done
  set +e
  (cd "$BD" && bash scripts/validate-plan.sh docs/exec-plans/active/plan.md) > "$TMP/g4c-bash.out" 2>&1; BC=$?
  node_cli "$ND" validate-plan docs/exec-plans/active/plan.md > "$TMP/g4c-node.out" 2>&1; NC=$?
  set -e
  compare_outputs "게이트-태스크그래프순환" "$BC" "$TMP/g4c-bash.out" "$NC" "$TMP/g4c-node.out"
}

# g4d~g4g: validate-plan Task Graph 오류 분기 4종 → exit 2 동일 메시지
taskgraph_error_case() {
  local label="$1" row="$2"
  local bd="$TMP/${label}-bash" nd="$TMP/${label}-node"
  setup_case "$bd" validate-plan.sh
  write_gate_fixtures "$bd" template false simple
  write_gate_fixtures "$nd" template false simple
  local d
  for d in "$bd" "$nd"; do
    printf '\n## Task Graph\n\n| Task | 의존 | 소유 파일 | 상태 |\n|---|---|---|---|\n%s\n' "$row" >> "$d/docs/exec-plans/active/plan.md"
  done
  set +e
  (cd "$bd" && bash scripts/validate-plan.sh docs/exec-plans/active/plan.md) > "$TMP/${label}-bash.out" 2>&1; local bc=$?
  node_cli "$nd" validate-plan docs/exec-plans/active/plan.md > "$TMP/${label}-node.out" 2>&1; local nc=$?
  set -e
  compare_outputs "게이트-${label}" "$bc" "$TMP/${label}-bash.out" "$nc" "$TMP/${label}-node.out"
}
taskgraph_error_case "태스크그래프중복" '| T1 | — | a.js | 구현 전 |
| T1 | — | b.js | 구현 전 |'
taskgraph_error_case "태스크그래프미정의참조" '| T1 | T9 | a.js | 구현 전 |'
taskgraph_error_case "태스크그래프상태오류" '| T1 | — | a.js | 완료 |'
taskgraph_error_case "태스크그래프ID형식" '| A1 | — | a.js | 구현 전 |'
# S2 보강(1단계 리뷰): 빈 값 상태·해당 없음 의존(정상 통과)·다중 오류 우선순위
taskgraph_error_case "태스크그래프빈값상태" '| T1 | — | a.js |  |'
taskgraph_error_case "태스크그래프해당없음의존" '| T1 | 해당 없음 | a.js | 구현 전 |
| T2 | T1 | b.js | 구현 전 |'
taskgraph_error_case "태스크그래프다중오류" '| A1 | — | a.js | 완료 |'

# CRG 탐색 기록 게이트 (선택 섹션 — 사용 시에만 형식 검사)
crg_record_case() {
  local label="$1" record="$2"
  local bd="$TMP/${label}-bash" nd="$TMP/${label}-node"
  setup_case "$bd" validate-plan.sh
  write_gate_fixtures "$bd" template false simple
  write_gate_fixtures "$nd" template false simple
  local d
  for d in "$bd" "$nd"; do
    printf '\n%s\n' "$record" >> "$d/docs/exec-plans/active/plan.md"
  done
  set +e
  (cd "$bd" && bash scripts/validate-plan.sh docs/exec-plans/active/plan.md) > "$TMP/${label}-bash.out" 2>&1; local bc=$?
  node_cli "$nd" validate-plan docs/exec-plans/active/plan.md > "$TMP/${label}-node.out" 2>&1; local nc=$?
  set -e
  compare_outputs "게이트-${label}" "$bc" "$TMP/${label}-bash.out" "$nc" "$TMP/${label}-node.out"
}
CRG_VALID_RECORD='## CRG 탐색 기록

- 사용 단계: Plan, Verify
- graph 상태: build
- 실행 명령: code-review-graph build
- 결과 반영: caller 3건 영향 파일 반영
- 원본 소스 교차 확인: scripts/a.js'
CRG_BAD_STAGE_RECORD='## CRG 탐색 기록

- 사용 단계: Implement
- graph 상태: build
- 실행 명령: code-review-graph build
- 결과 반영: caller 확인
- 원본 소스 교차 확인: scripts/a.js'
crg_record_case "CRG기록정상" "$CRG_VALID_RECORD"
crg_record_case "CRG기록단계오류" "$CRG_BAD_STAGE_RECORD"
# 후행 구분자 단계 목록("Plan, Verify,") — 양측 모두 유효로 취급 (동치 회귀 고정)
CRG_TRAILING_RECORD='## CRG 탐색 기록

- 사용 단계: Plan, Verify,
- graph 상태: update
- 실행 명령: code-review-graph update
- 결과 반영: 테스트 후보 2건 회귀 대상 추가
- 원본 소스 교차 확인: scripts/a.js'
crg_record_case "CRG기록후행구분자" "$CRG_TRAILING_RECORD"

# g5: verify — template 모드, 설정 없음 → TEMPLATE PASS exit 0
{
  BD="$TMP/g5-bash"; ND="$TMP/g5-node"
  setup_case "$BD" lint.sh test.sh verify.sh
  write_gate_fixtures "$BD" template false simple
  write_gate_fixtures "$ND" template false simple
  set +e
  (cd "$BD" && bash scripts/verify.sh) > "$TMP/g5-bash.out" 2>&1; BC=$?
  node_cli "$ND" verify > "$TMP/g5-node.out" 2>&1; NC=$?
  set -e
  compare_outputs "검증-템플릿통과" "$BC" "$TMP/g5-bash.out" "$NC" "$TMP/g5-node.out"
}

# g6: verify — 잘못된 모드 → exit 2
{
  BD="$TMP/g6-bash"; ND="$TMP/g6-node"
  setup_case "$BD" lint.sh test.sh verify.sh
  write_gate_fixtures "$BD" wrong false simple
  write_gate_fixtures "$ND" wrong false simple
  set +e
  (cd "$BD" && bash scripts/verify.sh) > "$TMP/g6-bash.out" 2>&1; BC=$?
  node_cli "$ND" verify > "$TMP/g6-node.out" 2>&1; NC=$?
  set -e
  compare_outputs "검증-잘못된모드" "$BC" "$TMP/g6-bash.out" "$NC" "$TMP/g6-node.out"
}

# g7: verify — active + 필수 테스트 미구성 → FAIL exit 1
{
  BD="$TMP/g7-bash"; ND="$TMP/g7-node"
  setup_case "$BD" lint.sh test.sh verify.sh
  write_gate_fixtures "$BD" active true simple
  write_gate_fixtures "$ND" active true simple
  set +e
  (cd "$BD" && bash scripts/verify.sh) > "$TMP/g7-bash.out" 2>&1; BC=$?
  node_cli "$ND" verify > "$TMP/g7-node.out" 2>&1; NC=$?
  set -e
  compare_outputs "검증-필수미구성실패" "$BC" "$TMP/g7-bash.out" "$NC" "$TMP/g7-node.out"
}

# g8: converge — template 모드 → BLOCKED exit 1
{
  BD="$TMP/g8-bash"; ND="$TMP/g8-node"
  setup_case "$BD" lint.sh test.sh verify.sh verify-plan.sh converge-plan.sh
  write_gate_fixtures "$BD" template false converged
  write_gate_fixtures "$ND" template false converged
  set +e
  (cd "$BD" && bash scripts/converge-plan.sh docs/exec-plans/active/plan.md) > "$TMP/g8-bash.out" 2>&1; BC=$?
  node_cli "$ND" converge-plan docs/exec-plans/active/plan.md > "$TMP/g8-node.out" 2>&1; NC=$?
  set -e
  compare_outputs "수렴-템플릿차단" "$BC" "$TMP/g8-bash.out" "$NC" "$TMP/g8-node.out"
}

# g9: converge — active + 완전 증거 → CONVERGENCE PASS exit 0
{
  BD="$TMP/g9-bash"; ND="$TMP/g9-node"
  setup_case "$BD" lint.sh test.sh verify.sh verify-plan.sh converge-plan.sh
  write_gate_fixtures "$BD" active false converged
  write_gate_fixtures "$ND" active false converged
  set +e
  (cd "$BD" && bash scripts/converge-plan.sh docs/exec-plans/active/plan.md) > "$TMP/g9-bash.out" 2>&1; BC=$?
  node_cli "$ND" converge-plan docs/exec-plans/active/plan.md > "$TMP/g9-node.out" 2>&1; NC=$?
  set -e
  compare_outputs "수렴-완전통과" "$BC" "$TMP/g9-bash.out" "$NC" "$TMP/g9-node.out"
}

# ── 케이스 17~21: 5a 자립 3종 (check-framework·analyze-project·install-hooks) ──

# p1: check-framework 사용법 오류 → exit 2
{
  BD="$TMP/p1-bash"; ND="$TMP/p1-node"
  setup_case "$BD" check-framework.sh; mkdir -p "$ND"
  set +e
  (cd "$BD" && bash scripts/check-framework.sh --bad-flag) > "$TMP/p1-bash.out" 2>&1; BC=$?
  node_cli "$ND" check-framework --bad-flag > "$TMP/p1-node.out" 2>&1; NC=$?
  set -e
  compare_outputs "골격-사용법오류" "$BC" "$TMP/p1-bash.out" "$NC" "$TMP/p1-node.out"
}

# p2: check-framework 완전한 대상 → 전부 PASS exit 0
# 두 쪽 모두 동일 카탈로그(실제 tsv 사본)를 검사하도록 대상을 완전하게 구성한다.
{
  BD="$TMP/p2-bash"; ND="$TMP/p2-node"; TGT="$TMP/p2-target"
  setup_case "$BD" check-framework.sh
  mkdir -p "$ND" "$TGT/docs/skill-contracts" "$TGT/docs/design-docs" "$TGT/scripts/lib/commands" "$TGT/global-hooks"
  mkdir -p "$BD/docs"
  cp "$ROOT/docs/framework-runtime-assets.tsv" "$BD/docs/framework-runtime-assets.tsv"
  for f in AGENTS.md ARCHITECTURE.md docs/development-workflow.md docs/definition-of-done.md \
    docs/coding-standards.md docs/testing-policy.md docs/framework-onboarding.md \
    docs/framework-manifest.md docs/project-bootstrap.md docs/project-preflight.md \
    docs/session-preflight.md docs/global-session-hooks.md docs/project-constitution.md \
    docs/design-docs/project-context.md; do
    cp "$ROOT/$f" "$TGT/$f" 2>/dev/null || touch "$TGT/$f"
  done
  cp "$ROOT/docs/framework-runtime-assets.tsv" "$TGT/docs/framework-runtime-assets.tsv"
  for c in standard-plan.md standard-implement.md standard-verify.md standard-review.md standard-improve.md standard-uat.md; do
    cp "$ROOT/docs/skill-contracts/$c" "$TGT/docs/skill-contracts/$c" 2>/dev/null || touch "$TGT/docs/skill-contracts/$c"
  done
  cp "$ROOT/.ai-dev-standard.env" "$TGT/.ai-dev-standard.env"
  while IFS=$'\t' read -r scope asset _desc; do
    case "$scope" in target-script|target-hook) mkdir -p "$TGT/$(dirname "$asset")"; cp "$ROOT/$asset" "$TGT/$asset" 2>/dev/null || touch "$TGT/$asset" ;; esac
  done < "$ROOT/docs/framework-runtime-assets.tsv"
  for d in docs/product-specs docs/exec-plans/active docs/exec-plans/completed docs/design-docs \
    docs/agent-improvements/candidates docs/agent-improvements/approved docs/agent-improvements/rejected; do
    mkdir -p "$TGT/$d"
  done
  set +e
  (cd "$BD" && bash scripts/check-framework.sh --project-dir "$TGT") > "$TMP/p2-bash.out" 2>&1; BC=$?
  node_cli "$ND" check-framework --project-dir "$TGT" > "$TMP/p2-node.out" 2>&1; NC=$?
  set -e
  # --project-dir 인자 출력은 경로라 양쪽 동일 — 그대로 비교.
  compare_outputs "골격-완전통과" "$BC" "$TMP/p2-bash.out" "$NC" "$TMP/p2-node.out"
}

# p3: analyze-project 빈 대상 → 인벤토리 출력 (생성일 정규화)
{
  BD="$TMP/p3-bash"; ND="$TMP/p3-node"; TGT="$TMP/p3-target"
  setup_case "$BD" analyze-project.sh
  mkdir -p "$ND" "$TGT"
  set +e
  (cd "$BD" && bash scripts/analyze-project.sh --project-dir "$TGT") > "$TMP/p3-bash.out" 2>&1; BC=$?
  node_cli "$ND" analyze-project --project-dir "$TGT" > "$TMP/p3-node.out" 2>&1; NC=$?
  set -e
  compare_outputs "분석-빈대상" "$BC" "$TMP/p3-bash.out" "$NC" "$TMP/p3-node.out"
}

# p4: analyze-project --write → 보고서 생성 + 내용 비교 (대상 경로 토큰화)
{
  BD="$TMP/p4-bash"; ND="$TMP/p4-node"; TB="$TMP/p4-b/t"; TN="$TMP/p4-n/t"
  setup_case "$BD" analyze-project.sh
  mkdir -p "$ND" "$TB" "$TN"
  set +e
  (cd "$BD" && bash scripts/analyze-project.sh --project-dir "$TB" --write) > "$TMP/p4-bash.out" 2>&1; BC=$?
  node_cli "$ND" analyze-project --project-dir "$TN" --write > "$TMP/p4-node.out" 2>&1; NC=$?
  set -e
  sed -i "s#$TB#TARGET#g" "$TMP/p4-bash.out"
  sed -i "s#$TN#TARGET#g" "$TMP/p4-node.out"
  compare_outputs "분석-보고서생성" "$BC" "$TMP/p4-bash.out" "$NC" "$TMP/p4-node.out"
  if ! diff -q <(sed "s#$TB#TARGET#g" "$TB/docs/generated/project-inventory.md") \
               <(sed "s#$TN#TARGET#g" "$TN/docs/generated/project-inventory.md") >/dev/null; then
    echo "FAIL [분석-보고서내용] 불일치" >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
  else
    PASS_COUNT=$((PASS_COUNT + 1))
  fi
}

# p5: install-global-session-hooks — HOME 격리 후 설치 결과 비교
# 원본 루트 경로(bash=$BD 사본, node=실제 저장소)는 명령 문자열에 들어가므로 토큰화한다.
{
  BD="$TMP/p5-bash"; ND="$TMP/p5-node"; HB="$TMP/p5-home-b"; HN="$TMP/p5-home-n"
  setup_case "$BD" install-global-session-hooks.sh
  mkdir -p "$BD/global-hooks" "$ND" "$HB" "$HN"
  cp "$ROOT/global-hooks/session-start.sh" "$ROOT/global-hooks/opencode-session-preflight.mjs" "$BD/global-hooks/"
  for H in "$HB" "$HN"; do
    SOURCE_FOR_HOME="$BD"
    [ "$H" = "$HN" ] && SOURCE_FOR_HOME="$ROOT"
    mkdir -p "$H/.codex" "$H/.claude"
    node - "$H" "$SOURCE_FOR_HOME" "$H/.ai-dev-standard/hooks/session-start.sh" <<'NODE'
const fs = require('fs');
const [home, sourceRoot, hookPath] = process.argv.slice(2);
const oldCommand = `AI_DEV_STANDARD_ROOT=${JSON.stringify(`${sourceRoot}-old`)} bash ${JSON.stringify(hookPath)}`;
const settings = { hooks: { SessionStart: [{ hooks: [
  { type: 'command', command: oldCommand },
  { type: 'command', command: 'echo preserve-me' },
] }] } };
for (const file of ['.codex/hooks.json', '.claude/settings.json']) {
  fs.writeFileSync(`${home}/${file}`, `${JSON.stringify(settings)}\n`);
}
NODE
  done
  set +e
  (cd "$BD" && HOME="$HB" AI_DEV_STANDARD_GLOBAL_ROOT="$HB/.ai-dev-standard" bash scripts/install-global-session-hooks.sh) > "$TMP/p5-bash.out" 2>&1; BC=$?
  HOME="$HN" AI_DEV_STANDARD_GLOBAL_ROOT="$HN/.ai-dev-standard" AI_DEV_STANDARD_ROOT="$ROOT" node "$ROOT/scripts/lib/cli.js" install-global-session-hooks > "$TMP/p5-node.out" 2>&1; NC=$?
  set -e
  (cd "$BD" && HOME="$HB" AI_DEV_STANDARD_GLOBAL_ROOT="$HB/.ai-dev-standard" bash scripts/install-global-session-hooks.sh) >/dev/null
  HOME="$HN" AI_DEV_STANDARD_GLOBAL_ROOT="$HN/.ai-dev-standard" AI_DEV_STANDARD_ROOT="$ROOT" node "$ROOT/scripts/lib/cli.js" install-global-session-hooks >/dev/null
  compare_outputs "설치-출력" "$BC" "$TMP/p5-bash.out" "$NC" "$TMP/p5-node.out"
  bash_norm="$(cd "$HB" && find . -type f | sort | sed "s#$BD#SRCROOT#g")"
  node_norm="$(cd "$HN" && find . -type f | sort | sed "s#$ROOT#SRCROOT#g")"
  if [ "$bash_norm" != "$node_norm" ]; then
    echo "FAIL [설치-파일목록] 불일치" >&2
    diff <(printf '%s\n' "$bash_norm") <(printf '%s\n' "$node_norm") >&2 || true
    FAIL_COUNT=$((FAIL_COUNT + 1))
  else
    PASS_COUNT=$((PASS_COUNT + 1))
  fi
  ok=0
  while IFS= read -r rel; do
    if ! diff -q <(sed "s#$BD#SRCROOT#g; s#$HB#HOMETOKEN#g" "$HB/$rel") <(sed "s#$ROOT#SRCROOT#g; s#$HN#HOMETOKEN#g" "$HN/$rel") >/dev/null; then
      echo "FAIL [설치-내용] $rel" >&2
      FAIL_COUNT=$((FAIL_COUNT + 1)); ok=1; break
    fi
  done <<< "$bash_norm"
  [ "$ok" -eq 0 ] && PASS_COUNT=$((PASS_COUNT + 1))
  for H in "$HB" "$HN"; do
    EXPECTED_SOURCE_ROOT="$BD"
    [ "$H" = "$HN" ] && EXPECTED_SOURCE_ROOT="$ROOT"
    for F in "$H/.codex/hooks.json" "$H/.claude/settings.json"; do
      if node -e '
        const fs = require("fs");
        const settings = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
        const expectedRoot = process.argv[2];
        const hooks = settings.hooks.SessionStart.flatMap(group => group.hooks || []);
        const frameworkHooks = hooks.filter(hook => /ai-dev-standard.*session-start\.sh/.test(hook.command || ""));
        if (frameworkHooks.length !== 1) process.exit(1);
        if (!frameworkHooks[0].command.includes("AI_DEV_STANDARD_FRAMEWORK_ROOT=")) process.exit(2);
        if (!frameworkHooks[0].command.includes(`AI_DEV_STANDARD_FRAMEWORK_ROOT=${JSON.stringify(expectedRoot)}`)) process.exit(3);
        if (/(^| )AI_DEV_STANDARD_ROOT=/.test(frameworkHooks[0].command)) process.exit(3);
        if (!hooks.some(hook => hook.command === "echo preserve-me")) process.exit(4);
      ' "$F" "$EXPECTED_SOURCE_ROOT"; then
        :
      else
        echo "FAIL [설정 마이그레이션] 기존 hook 교체 또는 사용자 hook 보존 실패: $F" >&2
        FAIL_COUNT=$((FAIL_COUNT + 1))
      fi
    done
  done
}

# ── 케이스 22~24: 5b-1 (prepare-project-context·plan-framework-apply) ──

# q1: prepare-context 빈 대상 → 전체 질문 보고서
{
  BD="$TMP/q1-bash"; ND="$TMP/q1-node"; TGT="$TMP/q1-target"
  setup_case "$BD" prepare-project-context.sh
  mkdir -p "$ND" "$TGT"
  set +e
  (cd "$BD" && bash scripts/prepare-project-context.sh --project-dir "$TGT") > "$TMP/q1-bash.out" 2>&1; BC=$?
  node_cli "$ND" prepare-project-context --project-dir "$TGT" > "$TMP/q1-node.out" 2>&1; NC=$?
  set -e
  compare_outputs "문맥-빈대상" "$BC" "$TMP/q1-bash.out" "$NC" "$TMP/q1-node.out"
}

# q2: prepare-context --write — README·확정 문맥·확정 constitution 갖춘 대상
{
  BD="$TMP/q2-bash"; ND="$TMP/q2-node"; TB="$TMP/q2-b/t"; TN="$TMP/q2-n/t"
  setup_case "$BD" prepare-project-context.sh
  mkdir -p "$ND"
  for T in "$TB" "$TN"; do
    mkdir -p "$T/docs/design-docs"
    echo "# readme" > "$T/README.md"
    printf -- '- 상태: 확정됨\n' > "$T/docs/design-docs/project-context.md"
    {
      echo "# constitution"
      echo "- 상태: 확정"
      for s in "## 고위험 변경과 승인 경계" "## 아키텍처 불변 조건" "## 규제·컴플라이언스 요건" \
        "## 인증·권한·외부 연동 정책" "## 데이터·프라이버시 정책" "## 프로젝트별 필수 검증 수준" \
        "## 안티골 — 기술적으로 가능해도 하지 않을 것" "## 미확정 결정·확정에 필요한 정보"; do
        echo "$s"
      done
    } > "$T/docs/project-constitution.md"
  done
  set +e
  (cd "$BD" && bash scripts/prepare-project-context.sh --project-dir "$TB" --write) > "$TMP/q2-bash.out" 2>&1; BC=$?
  node_cli "$ND" prepare-project-context --project-dir "$TN" --write > "$TMP/q2-node.out" 2>&1; NC=$?
  set -e
  sed -i "s#$TB#TARGET#g" "$TMP/q2-bash.out"
  sed -i "s#$TN#TARGET#g" "$TMP/q2-node.out"
  compare_outputs "문맥-확정대상기록" "$BC" "$TMP/q2-bash.out" "$NC" "$TMP/q2-node.out"
  if diff -q <(sed "s#$TB#TARGET#g" "$TB/docs/generated/project-context-intake.md") \
             <(sed "s#$TN#TARGET#g" "$TN/docs/generated/project-context-intake.md") >/dev/null; then
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "FAIL [문맥-보고서내용] 불일치" >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

# r1: plan-framework-apply — AGENTS.md 있는 대상 + 동일 카탈로그 (원본 경로 토큰화)
{
  BD="$TMP/r1-bash"; ND="$TMP/r1-node"; TGT="$TMP/r1-target"
  setup_case "$BD" plan-framework-apply.sh
  mkdir -p "$ND" "$TGT/sub" "$BD/docs"
  cp "$ROOT/docs/framework-runtime-assets.tsv" "$BD/docs/framework-runtime-assets.tsv"
  echo "# agents" > "$TGT/AGENTS.md"
  echo "# claude" > "$TGT/sub/CLAUDE.md"
  set +e
  (cd "$BD" && bash scripts/plan-framework-apply.sh --project-dir "$TGT") > "$TMP/r1-bash.out" 2>&1; BC=$?
  node_cli "$ND" plan-framework-apply --project-dir "$TGT" > "$TMP/r1-node.out" 2>&1; NC=$?
  set -e
  sed -i "s#$BD#SRCROOT#g" "$TMP/r1-bash.out"
  sed -i "s#$ROOT#SRCROOT#g" "$TMP/r1-node.out"
  compare_outputs "적용계획-보고서" "$BC" "$TMP/r1-bash.out" "$NC" "$TMP/r1-node.out"
}

# ── 케이스 25~29: 5b-2 (bootstrap·project-preflight·session-preflight) ──

# 전체 프레임워크 사본 — bash 측 SCRIPT_ROOT/FRAMEWORK_ROOT로 쓴다 (reference 원본으로 복원).
FW="$TMP/fw-copy"
cp -r "$ROOT" "$FW"
rm -rf "$FW/.git" "$FW/dist" "$FW/.opencode/node_modules"
cp "$FW/scripts/reference/"*.sh "$FW/scripts/"

# t1: session-preflight 사용법 오류 → exit 2
{
  BD="$TMP/t1-bash"; ND="$TMP/t1-node"
  setup_case "$BD" session-preflight.sh; mkdir -p "$ND"
  set +e
  (cd "$BD" && bash scripts/session-preflight.sh --bad) > "$TMP/t1-bash.out" 2>&1; BC=$?
  node_cli "$ND" session-preflight --bad > "$TMP/t1-node.out" 2>&1; NC=$?
  set -e
  compare_outputs "세션-사용법오류" "$BC" "$TMP/t1-bash.out" "$NC" "$TMP/t1-node.out"
}

# t2: project-preflight 빈 대상 → BLOCK 보고서 exit 2 (동일 대상·동일 프레임워크 사본)
{
  TGT="$TMP/t2-target"
  mkdir -p "$TGT"
  set +e
  (cd "$FW" && AI_DEV_STANDARD_FRAMEWORK_ROOT="$FW" bash scripts/reference/project-preflight.sh --project-dir "$TGT") > "$TMP/t2-bash.out" 2>&1; BC=$?
  AI_DEV_STANDARD_FRAMEWORK_ROOT="$FW" node "$ROOT/scripts/lib/cli.js" project-preflight --project-dir "$TGT" > "$TMP/t2-node.out" 2>&1; NC=$?
  set -e
  compare_outputs "프리플라이트-빈대상차단" "$BC" "$TMP/t2-bash.out" "$NC" "$TMP/t2-node.out"
}

# t3: project-preflight --session-status 없음 → json exit 2
{
  TGT="$TMP/t3-target"
  mkdir -p "$TGT"
  set +e
  (cd "$FW" && AI_DEV_STANDARD_FRAMEWORK_ROOT="$FW" bash scripts/reference/project-preflight.sh --project-dir "$TGT" --session-status) > "$TMP/t3-bash.out" 2>&1; BC=$?
  AI_DEV_STANDARD_FRAMEWORK_ROOT="$FW" node "$ROOT/scripts/lib/cli.js" project-preflight --project-dir "$TGT" --session-status > "$TMP/t3-node.out" 2>&1; NC=$?
  set -e
  compare_outputs "프리플라이트-세션없음" "$BC" "$TMP/t3-bash.out" "$NC" "$TMP/t3-node.out"
}

# t4: bootstrap --init → CREATE 시퀀스·트리 비교 (대상 경로 토큰화)
{
  TB="$TMP/t4-b/t"; TN="$TMP/t4-n/t"
  mkdir -p "$TB" "$TN"
  set +e
  (cd "$FW" && bash scripts/bootstrap-framework.sh --project-dir "$TB" --init) > "$TMP/t4-bash.out" 2>&1; BC=$?
  node "$ROOT/scripts/lib/cli.js" bootstrap-framework --project-dir "$TN" --init > "$TMP/t4-node.out" 2>&1; NC=$?
  set -e
  sed -i "s#$TB#TARGET#g" "$TMP/t4-bash.out"
  sed -i "s#$TN#TARGET#g" "$TMP/t4-node.out"
  compare_outputs "골격생성-시퀀스" "$BC" "$TMP/t4-bash.out" "$NC" "$TMP/t4-node.out"
  bash_list="$(cd "$TB" && find . -type f | sort)"
  node_list="$(cd "$TN" && find . -type f | sort)"
  if [ "$bash_list" != "$node_list" ]; then
    echo "FAIL [골격생성-파일목록] 불일치" >&2
    diff <(printf '%s\n' "$bash_list") <(printf '%s\n' "$node_list") | head -5 >&2 || true
    FAIL_COUNT=$((FAIL_COUNT + 1))
  else
    PASS_COUNT=$((PASS_COUNT + 1))
  fi
}

# t5: init 대상 하나에 양 구현 순차 실행 — json·세션 파일 동치 (fingerprint는 프로젝트
# 경로를 포함하므로 값 동치는 동일 프로젝트에서만 성립한다).
{
  ST="$TMP/t5-shared/t"
  mkdir -p "$ST"
  (cd "$FW" && bash scripts/bootstrap-framework.sh --project-dir "$ST" --init) >/dev/null 2>&1
  set +e
  (cd "$FW" && AI_DEV_STANDARD_FRAMEWORK_ROOT="$FW" bash scripts/reference/project-preflight.sh --project-dir "$ST" --write-session --format json) > "$TMP/t5-bash.out" 2>&1; BC=$?
  cp "$ST/.ai-dev-standard/session-preflight.json" "$TMP/t5-bash-session.json"
  AI_DEV_STANDARD_FRAMEWORK_ROOT="$FW" node "$ROOT/scripts/lib/cli.js" project-preflight --project-dir "$ST" --write-session --format json > "$TMP/t5-node.out" 2>&1; NC=$?
  set -e
  compare_outputs "프리플라이트-세션기록" "$BC" "$TMP/t5-bash.out" "$NC" "$TMP/t5-node.out"
  bash_sess="$(sed -E 's/"checked_at": "[^"]*"/"checked_at": "TIME"/' "$TMP/t5-bash-session.json")"
  node_sess="$(sed -E 's/"checked_at": "[^"]*"/"checked_at": "TIME"/' "$ST/.ai-dev-standard/session-preflight.json")"
  if [ "$bash_sess" != "$node_sess" ]; then
    echo "FAIL [프리플라이트-세션내용] 불일치" >&2
    diff <(printf '%s\n' "$bash_sess") <(printf '%s\n' "$node_sess") >&2 || true
    FAIL_COUNT=$((FAIL_COUNT + 1))
  else
    PASS_COUNT=$((PASS_COUNT + 1))
  fi
}

# ── 케이스 30~36: 잔여 4종 (review·complete-exec-plan·개선루프 2종) ──

# v1: review — git 아닌 환경 → 비교 기준 없음 폴백
{
  BD="$TMP/v1-bash"; ND="$TMP/v1-node"
  setup_case "$BD" review.sh; mkdir -p "$ND"
  set +e
  (cd "$BD" && bash scripts/review.sh) > "$TMP/v1-bash.out" 2>&1; BC=$?
  node_cli "$ND" review > "$TMP/v1-node.out" 2>&1; NC=$?
  set -e
  compare_outputs "리뷰-기준없음" "$BC" "$TMP/v1-bash.out" "$NC" "$TMP/v1-node.out"
}

# v2: complete-exec-plan 사용법 오류 → exit 2
{
  BD="$TMP/v2-bash"; ND="$TMP/v2-node"
  setup_case "$BD" complete-exec-plan.sh; mkdir -p "$ND"
  set +e
  (cd "$BD" && bash scripts/complete-exec-plan.sh one) > "$TMP/v2-bash.out" 2>&1; BC=$?
  node_cli "$ND" complete-exec-plan one > "$TMP/v2-node.out" 2>&1; NC=$?
  set -e
  compare_outputs "완료-사용법오류" "$BC" "$TMP/v2-bash.out" "$NC" "$TMP/v2-node.out"
}

# v3: complete-exec-plan 상태 오류(active) → exit 2
{
  BD="$TMP/v3-bash"; ND="$TMP/v3-node"
  setup_case "$BD" complete-exec-plan.sh
  mkdir -p "$BD/docs/exec-plans/active" "$ND/docs/exec-plans/active"
  printf -- '# Exec Plan: x\n\n- 상태: active\n' > "$BD/docs/exec-plans/active/plan.md"
  printf -- '# Exec Plan: x\n\n- 상태: active\n' > "$ND/docs/exec-plans/active/plan.md"
  set +e
  (cd "$BD" && bash scripts/complete-exec-plan.sh docs/exec-plans/active/plan.md 승인자) > "$TMP/v3-bash.out" 2>&1; BC=$?
  node_cli "$ND" complete-exec-plan docs/exec-plans/active/plan.md 승인자 > "$TMP/v3-node.out" 2>&1; NC=$?
  set -e
  compare_outputs "완료-상태오류" "$BC" "$TMP/v3-bash.out" "$NC" "$TMP/v3-node.out"
}

# v4: complete-exec-plan 성공 → done 이동·승인 라인·트리 비교
{
  BD="$TMP/v4-bash"; ND="$TMP/v4-node"
  setup_case "$BD" complete-exec-plan.sh
  for D in "$BD" "$ND"; do
    mkdir -p "$D/docs/exec-plans/active"
    printf -- '# Exec Plan: x\n\n- 상태: READY_FOR_REVIEW\n\n## 완료 기록\n- 리뷰: PASS\n' > "$D/docs/exec-plans/active/plan.md"
  done
  set +e
  (cd "$BD" && bash scripts/complete-exec-plan.sh docs/exec-plans/active/plan.md gon) > "$TMP/v4-bash.out" 2>&1; BC=$?
  node_cli "$ND" complete-exec-plan docs/exec-plans/active/plan.md gon > "$TMP/v4-node.out" 2>&1; NC=$?
  set -e
  compare_outputs "완료-성공" "$BC" "$TMP/v4-bash.out" "$NC" "$TMP/v4-node.out"
  compare_trees "완료-파일" "$BD" "$ND"
}

# v5: 개선 후보 사용법 오류 (3인자) → exit 2
{
  BD="$TMP/v5-bash"; ND="$TMP/v5-node"
  setup_case "$BD" new-improvement-candidate.sh; mkdir -p "$ND"
  set +e
  (cd "$BD" && bash scripts/new-improvement-candidate.sh a b c) > "$TMP/v5-bash.out" 2>&1; BC=$?
  node_cli "$ND" new-improvement-candidate a b c > "$TMP/v5-node.out" 2>&1; NC=$?
  set -e
  compare_outputs "후보-사용법오류" "$BC" "$TMP/v5-bash.out" "$NC" "$TMP/v5-node.out"
}

# v6: 후보 생성(한글 제목) → decide approve → approved 이동·내용 비교
{
  BD="$TMP/v6-bash"; ND="$TMP/v6-node"
  setup_case "$BD" new-improvement-candidate.sh decide-improvement.sh
  for D in "$BD" "$ND"; do mkdir -p "$D/docs/exec-plans/completed"; printf 'plan\n' > "$D/docs/exec-plans/completed/src.md"; done
  set +e
  (cd "$BD" && bash scripts/new-improvement-candidate.sh "개선 제목" "문제 설명" "근거 설명" docs/exec-plans/completed/src.md) > "$TMP/v6-bash.out" 2>&1; BC=$?
  node_cli "$ND" new-improvement-candidate "개선 제목" "문제 설명" "근거 설명" docs/exec-plans/completed/src.md > "$TMP/v6-node.out" 2>&1; NC=$?
  set -e
  sed -i "s/[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}-[0-9]\{6\}/TIMESTAMP/g" "$TMP/v6-bash.out" "$TMP/v6-node.out"
  compare_outputs "후보-생성" "$BC" "$TMP/v6-bash.out" "$NC" "$TMP/v6-node.out"
  BCAND="$(ls "$BD/docs/agent-improvements/candidates/")"
  NCAND="$(ls "$ND/docs/agent-improvements/candidates/")"
  # 후보 파일명에 생성 시각이 포함되므로 비교는 정규화 키로 한다 (초 경계 경쟁 방지).
  # 이후 decide-improvement 경로에는 실제 파일명($BCAND/$NCAND)을 그대로 쓴다.
  if [ "$(printf '%s' "$BCAND" | normalize)" != "$(printf '%s' "$NCAND" | normalize)" ]; then
    echo "FAIL [후보-파일명] 불일치: $BCAND vs $NCAND" >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
  else
    PASS_COUNT=$((PASS_COUNT + 1))
  fi
  set +e
  (cd "$BD" && bash scripts/decide-improvement.sh approve "docs/agent-improvements/candidates/$BCAND" 결정자 "승인 사유") > "$TMP/v6d-bash.out" 2>&1; BCD=$?
  node_cli "$ND" decide-improvement approve "docs/agent-improvements/candidates/$NCAND" 결정자 "승인 사유" > "$TMP/v6d-node.out" 2>&1; NCD=$?
  set -e
  compare_outputs "후보-승인" "$BCD" "$TMP/v6d-bash.out" "$NCD" "$TMP/v6d-node.out"
  if diff -q <(normalize < "$BD/docs/agent-improvements/approved/$BCAND") <(normalize < "$ND/docs/agent-improvements/approved/$NCAND") >/dev/null; then
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "FAIL [후보-승인내용] 불일치" >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

# v7: decide 잘못된 결정 → exit 2
{
  BD="$TMP/v7-bash"; ND="$TMP/v7-node"
  setup_case "$BD" decide-improvement.sh
  for D in "$BD" "$ND"; do
    mkdir -p "$D/docs/agent-improvements/candidates"
    printf -- '# IC\n\n- 상태: candidate\n' > "$D/docs/agent-improvements/candidates/c.md"
  done
  set +e
  (cd "$BD" && bash scripts/decide-improvement.sh maybe docs/agent-improvements/candidates/c.md x y) > "$TMP/v7-bash.out" 2>&1; BC=$?
  node_cli "$ND" decide-improvement maybe docs/agent-improvements/candidates/c.md x y > "$TMP/v7-node.out" 2>&1; NC=$?
  set -e
  compare_outputs "후보-잘못된결정" "$BC" "$TMP/v7-bash.out" "$NC" "$TMP/v7-node.out"
}

# v8: 승인된 Node API E2E 프로필 구성 → 설정 파일·출력 동치
{
  BD="$TMP/v8-bash"; ND="$TMP/v8-node"
  setup_case "$BD" configure-e2e-profile.sh
  for D in "$BD" "$ND"; do
    mkdir -p "$D/docs/product-specs" "$D/docs/exec-plans/active"
    : > "$D/package-lock.json"
    cat > "$D/docs/product-specs/spec.md" <<'EOS'
# Product Spec: E2E profile parity

- 상태: approved

## 완료 조건 (Acceptance Criteria)

| ID | 완료 조건 | 기대 결과 |
|---|---|---|
| AC-01 | API 흐름 | PASS |
EOS
    cat > "$D/docs/exec-plans/active/plan.md" <<'EOS'
# Exec Plan: E2E profile parity

- 상태: active
- 승인: approved
- 검증 계약 버전: 2
- 제품 명세: docs/product-specs/spec.md

## E2E 판정

- 필요 여부: 필요
- 방식: API/System E2E
- 대상 AC: AC-01

## E2E 프로필 제안

- 준비 상태: 구성 필요
- 선택 프로필: node-api
- 대상 AC: AC-01
- 설치 영향: Node 기본 테스트 실행을 사용한다
- 구성 명령: node scripts/lib/cli.js configure-e2e-profile docs/exec-plans/active/plan.md node-api
- 거부/실패 대안: 수동 UAT 또는 미검증 보류
EOS
  done
  set +e
  (cd "$BD" && bash scripts/configure-e2e-profile.sh docs/exec-plans/active/plan.md node-api) > "$TMP/v8-bash.out" 2>&1; BC=$?
  node_cli "$ND" configure-e2e-profile docs/exec-plans/active/plan.md node-api > "$TMP/v8-node.out" 2>&1; NC=$?
  set -e
  compare_outputs "E2E-프로필-Node-구성" "$BC" "$TMP/v8-bash.out" "$NC" "$TMP/v8-node.out"
  compare_trees "E2E-프로필-Node-파일" "$BD" "$ND"
}

echo "동치성: $PASS_COUNT PASS, $FAIL_COUNT FAIL"
if [ "$FAIL_COUNT" -gt 0 ]; then
  echo "PARITY: FAIL" >&2
  exit 1
fi
echo "PARITY: PASS — reference(bash)와 Node 구현이 동치성 기준(L1·L2)을 충족했습니다."
