#!/usr/bin/env bash
# E2E 판정·Runner·증거·수렴 게이트 회귀 검사.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
PLAN="docs/exec-plans/active/plan.md"
trap 'rm -rf -- "$TMP_ROOT"' EXIT

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

run_cli() {
  local project="$1"
  shift
  AI_DEV_STANDARD_ROOT="$project" node "$ROOT/scripts/lib/cli.js" "$@"
}

expect_ok() {
  local label="$1"
  shift
  if ! "$@" >/dev/null 2>&1; then
    fail "$label — 성공해야 하지만 실패했습니다"
  fi
}

expect_blocked() {
  local label="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    fail "$label — 차단되어야 하지만 통과했습니다"
  fi
}

write_spec() {
  local project="$1"
  mkdir -p "$project/docs/product-specs" "$project/docs/exec-plans/active"
  cat > "$project/docs/product-specs/spec.md" <<'EOF'
# Product Spec: E2E gate fixture

- 상태: approved

## 완료 조건 (Acceptance Criteria)

| ID | 완료 조건 | 기대 결과 |
|---|---|---|
| AC-01 | 사용자 흐름이 완료된다 | PASS |
EOF
}

write_env() {
  local project="$1"
  cat > "$project/.ai-dev-standard.env" <<'EOF'
AI_DEV_STANDARD_MODE=active
AI_DEV_STANDARD_REQUIRE_LINT=false
AI_DEV_STANDARD_REQUIRE_TYPECHECK=false
AI_DEV_STANDARD_REQUIRE_TEST=false
EOF
}

write_plan() {
  local project="$1" needed="$2" method="$3" acs="$4"
  cat > "$project/$PLAN" <<EOF
# Exec Plan: E2E gate fixture

- 상태: active
- 승인: approved
- 검증 계약 버전: 2
- 제품 명세: docs/product-specs/spec.md

## 구현 계획

- 목적: E2E 게이트 회귀 검사

## 검증 계획

| AC | 검증 방법 | 기대 증거 |
|---|---|---|
| AC-01 | E2E 또는 자동 검증 | PASS |

## 회귀 검증 대상

- 기존 검증 게이트

## E2E 판정

- 필요 여부: ${needed}
- 방식: ${method}
- 판정 근거: 사용자 흐름이 여러 구성 요소를 통과하는지 확인한다
- 대상 AC: ${acs}
- 자동 실행 명령 또는 수동 UAT 시나리오: 실제 E2E 실행 또는 관찰 절차
- 사전 조건: 테스트 환경이 준비되어 있다

## 완료 기록

- 완료일시: 2026-10-22 12:00
- 검증 증거: 기본 검증 PASS
- 리뷰: PASS

## AC 판정

| AC | 판정 | 증거 |
|---|---|---|
| AC-01 | PASS | 기본 검증 PASS |
EOF
}

new_fixture() {
  local name="$1" needed="$2" method="$3" acs="$4"
  local project="$TMP_ROOT/$name"
  write_spec "$project"
  write_env "$project"
  write_plan "$project" "$needed" "$method" "$acs"
  printf '%s\n' "$project"
}

write_e2e_config() {
  local project="$1" code="$2"
  mkdir -p "$project/.ai-dev-standard"
  cat > "$project/.ai-dev-standard/e2e.json" <<EOF
{
  "command": "node",
  "args": ["-e", "process.exit(${code})"]
}
EOF
}

# 1. 새 버전 템플릿은 판정 섹션을 제공하고, '불필요' Plan은 추가 실행 없이 통과한다.
UNNEEDED="$(new_fixture unneeded 불필요 '해당 없음' '해당 없음')"
expect_ok '불필요 E2E Plan 검증' run_cli "$UNNEEDED" validate-plan "$PLAN"
expect_ok '불필요 E2E Plan 수렴' run_cli "$UNNEEDED" converge-plan "$PLAN"

# 2. v2 Plan은 실질적인 판정이 없으면 Plan 단계에서 막힌다.
INVALID="$(new_fixture invalid 필요 '해당 없음' '해당 없음')"
expect_blocked 'E2E 필요인데 방식·대상 AC 누락' run_cli "$INVALID" validate-plan "$PLAN"

# 3. 기존 Plan은 검증 계약 버전 표기가 없으면 그대로 통과한다.
LEGACY="$(new_fixture legacy 불필요 '해당 없음' '해당 없음')"
sed -i '/^- 검증 계약 버전: 2$/d' "$LEGACY/$PLAN"
expect_ok '레거시 Plan 호환' run_cli "$LEGACY" validate-plan "$PLAN"

# 4. 자동 E2E는 등록된 command + args만 실행해 PASS 증거를 남기고 수렴한다.
AUTO="$(new_fixture auto 필요 '자동 Browser E2E' 'AC-01')"
write_e2e_config "$AUTO" 0
expect_ok '자동 E2E Plan 검증' run_cli "$AUTO" validate-plan "$PLAN"
expect_ok '자동 E2E 증거 기록' run_cli "$AUTO" record-e2e-evidence "$PLAN"
grep -Fxq -- '- 종료 코드: 0' "$AUTO/$PLAN" || fail '자동 E2E 종료 코드 증거가 없습니다'
grep -Fxq -- '- 결과 요약: PASS (test e2e 종료 코드 기준; 전체 출력은 기록하지 않음)' "$AUTO/$PLAN" || \
  fail '자동 E2E PASS 증거가 없습니다'
expect_ok '자동 E2E Plan 수렴' run_cli "$AUTO" converge-plan "$PLAN"

# 5. 같은 Plan에서 재실행이 FAIL이면 과거 PASS가 아닌 마지막 실행 결과가 수렴을 막는다.
write_e2e_config "$AUTO" 9
if run_cli "$AUTO" record-e2e-evidence "$PLAN" >/dev/null 2>&1; then
  fail '실패한 자동 E2E가 성공으로 보고됐습니다'
fi
expect_blocked '마지막 자동 E2E FAIL' run_cli "$AUTO" converge-plan "$PLAN"

# 6. 설정이 없으면 명시적으로 SKIP(3)이고, 필요한 E2E의 수렴은 불가하다.
MISSING="$(new_fixture missing 필요 'API/System E2E' 'AC-01')"
expect_ok 'API/System E2E Plan 검증' run_cli "$MISSING" validate-plan "$PLAN"
set +e
run_cli "$MISSING" record-e2e-evidence "$PLAN" >/dev/null 2>&1
MISSING_CODE=$?
set -e
[ "$MISSING_CODE" -eq 3 ] || fail "E2E 설정 없음의 종료 코드는 3이어야 합니다: $MISSING_CODE"
expect_blocked 'E2E 설정 없음 수렴' run_cli "$MISSING" converge-plan "$PLAN"

# 7. 잘못된 설정은 Runner에서 FAIL(1)로 구분한다.
INVALID_CONFIG="$(new_fixture invalid-config 필요 '자동 Browser E2E' 'AC-01')"
mkdir -p "$INVALID_CONFIG/.ai-dev-standard"
cat > "$INVALID_CONFIG/.ai-dev-standard/e2e.json" <<'EOF'
{"command":"node","args":["-e",1]}
EOF
set +e
run_cli "$INVALID_CONFIG" test e2e >/dev/null 2>&1
INVALID_CONFIG_CODE=$?
set -e
[ "$INVALID_CONFIG_CODE" -eq 1 ] || fail "잘못된 E2E 설정의 종료 코드는 1이어야 합니다: $INVALID_CONFIG_CODE"

# 8. 수동 Browser UAT는 형식화된 관찰 증거가 없으면 막히고, PASS 기록이 있으면 통과한다.
MANUAL="$(new_fixture manual 필요 '수동 Browser UAT' 'AC-01')"
expect_ok '수동 Browser UAT Plan 검증' run_cli "$MANUAL" validate-plan "$PLAN"
expect_blocked '수동 UAT 증거 없음' run_cli "$MANUAL" record-e2e-evidence "$PLAN"
cat >> "$MANUAL/$PLAN" <<'EOF'

## E2E 검증 증거

### 수동 UAT signup-flow
- 실행 일시: 2026-10-22T12:00:00Z
- 관찰 결과: 브라우저에서 사용자 흐름을 끝까지 완료했다
- 판정: PASS
EOF
expect_ok '수동 UAT 증거 확인' run_cli "$MANUAL" record-e2e-evidence "$PLAN"
expect_ok '수동 UAT Plan 수렴' run_cli "$MANUAL" converge-plan "$PLAN"

# 9. 명령은 셸을 사용하지 않는다. 인자가 셸 치환처럼 보이더라도 파일이 생성되면 안 된다.
SAFE="$(new_fixture safe 필요 'CLI E2E' 'AC-01')"
expect_ok 'CLI E2E Plan 검증' run_cli "$SAFE" validate-plan "$PLAN"
mkdir -p "$SAFE/.ai-dev-standard"
MARKER="$SAFE/shell-expanded"
cat > "$SAFE/.ai-dev-standard/e2e.json" <<EOF
{
  "command": "node",
  "args": ["-e", "process.exit(0)", "\$(touch $MARKER)"]
}
EOF
expect_ok '셸 없는 E2E 실행' run_cli "$SAFE" record-e2e-evidence "$PLAN"
[ ! -e "$MARKER" ] || fail 'E2E args가 셸에서 확장되었습니다'

echo 'PASS: E2E decision, runner, evidence, and convergence gates'
