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
  sed -E 's/[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6}/TIMESTAMP/g; s/[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}/DATETIME/g; s#\.npm/_logs/\S+#NPMLOG#g'
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
    diff <(normalize < "$bash_out") <(normalize < "$node_out") | head -5 >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return
  fi
  PASS_COUNT=$((PASS_COUNT + 1))
}

compare_trees() {
  local label="$1" bash_root="$2" node_root="$3"
  local bash_list node_list bash_real
  bash_real="$(cd "$bash_root" && find . -type f -not -path './scripts/*' | sort)"
  bash_list="$(printf '%s\n' "$bash_real" | normalize)"
  node_list="$(cd "$node_root" && find . -type f -not -path './scripts/*' | sort | normalize)"
  if [ "$bash_list" != "$node_list" ]; then
    echo "FAIL [$label] 생성 파일 목록 불일치:" >&2
    diff <(printf '%s\n' "$bash_list") <(printf '%s\n' "$node_list") >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return
  fi
  local rel
  while IFS= read -r rel; do
    if ! diff -q <(normalize < "$bash_root/$rel") <(normalize < "$node_root/$rel") >/dev/null; then
      echo "FAIL [$label] 파일 내용 불일치: $rel" >&2
      diff <(normalize < "$bash_root/$rel") <(normalize < "$node_root/$rel") | head -5 >&2
      FAIL_COUNT=$((FAIL_COUNT + 1))
      return
    fi
  done <<< "$bash_real"
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

# ── 케이스 3: 미승인 명세 → 계획 생성 거부 (exit 2) ──
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
  compare_outputs "계획-미승인거부" "$BC" "$TMP/c3-bash.out" "$NC" "$TMP/c3-node.out"
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
  set +e
  (cd "$BD" && HOME="$HB" AI_DEV_STANDARD_GLOBAL_ROOT="$HB/.ai-dev-standard" bash scripts/install-global-session-hooks.sh) > "$TMP/p5-bash.out" 2>&1; BC=$?
  HOME="$HN" AI_DEV_STANDARD_GLOBAL_ROOT="$HN/.ai-dev-standard" AI_DEV_STANDARD_ROOT="$ROOT" node "$ROOT/scripts/lib/cli.js" install-global-session-hooks > "$TMP/p5-node.out" 2>&1; NC=$?
  set -e
  compare_outputs "설치-출력" "$BC" "$TMP/p5-bash.out" "$NC" "$TMP/p5-node.out"
  bash_norm="$(cd "$HB" && find . -type f | sort | sed "s#$BD#SRCROOT#g")"
  node_norm="$(cd "$HN" && find . -type f | sort | sed "s#$ROOT#SRCROOT#g")"
  if [ "$bash_norm" != "$node_norm" ]; then
    echo "FAIL [설치-파일목록] 불일치" >&2
    diff <(printf '%s\n' "$bash_norm") <(printf '%s\n' "$node_norm") >&2
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
    diff <(printf '%s\n' "$bash_list") <(printf '%s\n' "$node_list") | head -5 >&2
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
    diff <(printf '%s\n' "$bash_sess") <(printf '%s\n' "$node_sess") >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
  else
    PASS_COUNT=$((PASS_COUNT + 1))
  fi
}

echo "동치성: $PASS_COUNT PASS, $FAIL_COUNT FAIL"
if [ "$FAIL_COUNT" -gt 0 ]; then
  echo "PARITY: FAIL" >&2
  exit 1
fi
echo "PARITY: PASS — reference(bash)와 Node 구현이 동치성 기준(L1·L2)을 충족했습니다."
