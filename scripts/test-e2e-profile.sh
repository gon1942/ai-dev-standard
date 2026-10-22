#!/usr/bin/env bash
# 승인형 E2E 프로필 제안·구성 회귀 검사.
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

run_cli_with_fake_package_tools() {
  local project="$1" log="$2"
  shift 2
  PATH="$project/bin:$PATH" E2E_PROFILE_LOG="$log" \
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

write_fixture() {
  local project="$1" approval="$2" method="$3" profile="${4:-}"
  mkdir -p "$project/docs/product-specs" "$project/docs/exec-plans/active" "$project/tests/e2e"
  cat > "$project/package.json" <<'EOF'
{"name":"e2e-profile-fixture","private":true}
EOF
  : > "$project/package-lock.json"
  cat > "$project/docs/product-specs/spec.md" <<'EOF'
# Product Spec: E2E profile fixture

- 상태: approved

## 완료 조건 (Acceptance Criteria)

| ID | 완료 조건 | 기대 결과 |
|---|---|---|
| AC-01 | 사용자 흐름을 검증한다 | PASS |
EOF
  cat > "$project/$PLAN" <<EOF
# Exec Plan: E2E profile fixture

- 상태: active
- 승인: ${approval}
- 검증 계약 버전: 2
- 제품 명세: docs/product-specs/spec.md

## 구현 계획

- 목적: E2E profile fixture

## 검증 계획

| AC | 검증 방법 | 기대 증거 |
|---|---|---|
| AC-01 | E2E | PASS |

## 회귀 검증 대상

- E2E profile command

## E2E 판정

- 필요 여부: 필요
- 방식: ${method}
- 판정 근거: 사용자 흐름을 실제 실행 환경에서 검증한다
- 대상 AC: AC-01
- 자동 실행 명령 또는 수동 UAT 시나리오: E2E profile command
- 사전 조건: 테스트 fixture가 준비되어 있다
EOF
  if [ -n "$profile" ]; then
    cat >> "$project/$PLAN" <<EOF

## E2E 프로필 제안

- 준비 상태: 구성 필요
- 선택 프로필: ${profile}
- 대상 AC: AC-01
- 설치 영향: 승인된 프로필의 개발 의존성과 브라우저 binary를 추가할 수 있다
- 구성 명령: node scripts/lib/cli.js configure-e2e-profile ${PLAN} ${profile}
- 거부/실패 대안: 수동 UAT 또는 미검증 보류
EOF
  fi
  cat > "$project/tests/e2e/smoke.test.js" <<'EOF'
require('node:test').test('fixture e2e command', () => {});
EOF
}

write_fake_package_tools() {
  local project="$1"
  mkdir -p "$project/bin"
  for tool in npm npx; do
    cat > "$project/bin/$tool" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s %s\n' "$(basename "$0")" "$*" >> "$E2E_PROFILE_LOG"
exit "${E2E_PROFILE_FAKE_EXIT:-0}"
EOF
    chmod +x "$project/bin/$tool"
  done
}

# RED: 자동 E2E인데 설정과 프로필 제안이 모두 없으면 Plan 단계에서 차단되어야 한다.
MISSING_PROPOSAL="$TMP_ROOT/missing-proposal"
write_fixture "$MISSING_PROPOSAL" approved 'API/System E2E'
expect_blocked '자동 E2E 설정 부재의 프로필 제안 누락' run_cli "$MISSING_PROPOSAL" validate-plan "$PLAN"

PENDING="$TMP_ROOT/pending"
write_fixture "$PENDING" pending 'API/System E2E' node-api
expect_blocked '승인 전 프로필 구성' run_cli "$PENDING" configure-e2e-profile "$PLAN" node-api

NODE_PROFILE="$TMP_ROOT/node-profile"
write_fixture "$NODE_PROFILE" approved 'API/System E2E' node-api
expect_ok 'Node API 프로필 Plan 검증' run_cli "$NODE_PROFILE" validate-plan "$PLAN"
expect_ok 'Node API 프로필 구성' run_cli "$NODE_PROFILE" configure-e2e-profile "$PLAN" node-api
grep -Fq '"command": "node"' "$NODE_PROFILE/.ai-dev-standard/e2e.json" || fail 'Node API E2E 설정이 생성되지 않았습니다'
expect_ok 'Node API E2E 실행' run_cli "$NODE_PROFILE" test e2e

PLAYWRIGHT="$TMP_ROOT/playwright"
write_fixture "$PLAYWRIGHT" approved '자동 Browser E2E' playwright
write_fake_package_tools "$PLAYWRIGHT"
expect_ok 'Playwright 프로필 Plan 검증' run_cli "$PLAYWRIGHT" validate-plan "$PLAN"
expect_ok 'Playwright 프로필 구성' run_cli_with_fake_package_tools "$PLAYWRIGHT" "$PLAYWRIGHT/package.log" configure-e2e-profile "$PLAN" playwright
grep -Fq '"playwright"' "$PLAYWRIGHT/.ai-dev-standard/e2e.json" || fail 'Playwright E2E 설정이 생성되지 않았습니다'
grep -Fq 'npm install --save-dev @playwright/test' "$PLAYWRIGHT/package.log" || fail 'Playwright 의존성 설치 명령이 없습니다'
grep -Fq 'npx --no-install playwright install chromium' "$PLAYWRIGHT/package.log" || fail 'Playwright 브라우저 설치 명령이 없습니다'
expect_ok 'Playwright E2E 실행 계약' run_cli_with_fake_package_tools "$PLAYWRIGHT" "$PLAYWRIGHT/package.log" test e2e

CYPRESS="$TMP_ROOT/cypress"
write_fixture "$CYPRESS" approved '자동 Browser E2E' cypress
write_fake_package_tools "$CYPRESS"
expect_ok 'Cypress 프로필 Plan 검증' run_cli "$CYPRESS" validate-plan "$PLAN"
expect_ok 'Cypress 프로필 구성' run_cli_with_fake_package_tools "$CYPRESS" "$CYPRESS/package.log" configure-e2e-profile "$PLAN" cypress
grep -Fq '"cypress"' "$CYPRESS/.ai-dev-standard/e2e.json" || fail 'Cypress E2E 설정이 생성되지 않았습니다'
grep -Fq 'npm install --save-dev cypress' "$CYPRESS/package.log" || fail 'Cypress 의존성 설치 명령이 없습니다'
expect_ok 'Cypress E2E 실행 계약' run_cli_with_fake_package_tools "$CYPRESS" "$CYPRESS/package.log" test e2e

EXISTING="$TMP_ROOT/existing"
write_fixture "$EXISTING" approved '자동 Browser E2E' playwright
mkdir -p "$EXISTING/.ai-dev-standard"
printf '%s\n' '{"command":"node","args":["-e","process.exit(0)"]}' > "$EXISTING/.ai-dev-standard/e2e.json"
expect_ok '기존 자동 E2E Plan 검증' run_cli "$EXISTING" validate-plan "$PLAN"
expect_ok '기존 자동 E2E 설정 재사용' run_cli "$EXISTING" configure-e2e-profile "$PLAN" playwright
grep -Fq 'process.exit(0)' "$EXISTING/.ai-dev-standard/e2e.json" || fail '기존 E2E 설정을 덮어썼습니다'

FAILED_INSTALL="$TMP_ROOT/failed-install"
write_fixture "$FAILED_INSTALL" approved '자동 Browser E2E' playwright
write_fake_package_tools "$FAILED_INSTALL"
if PATH="$FAILED_INSTALL/bin:$PATH" E2E_PROFILE_LOG="$FAILED_INSTALL/package.log" E2E_PROFILE_FAKE_EXIT=9 \
  AI_DEV_STANDARD_ROOT="$FAILED_INSTALL" node "$ROOT/scripts/lib/cli.js" configure-e2e-profile "$PLAN" playwright >/dev/null 2>&1; then
  fail '패키지 설치 실패가 성공으로 보고됐습니다'
fi
[ ! -e "$FAILED_INSTALL/.ai-dev-standard/e2e.json" ] || fail '실패한 설치가 E2E 설정을 남겼습니다'

MANUAL="$TMP_ROOT/manual-uat"
write_fixture "$MANUAL" approved '수동 Browser UAT'
expect_ok '수동 UAT 대안 Plan 검증' run_cli "$MANUAL" validate-plan "$PLAN"
expect_blocked '수동 UAT Plan의 도구 구성' run_cli "$MANUAL" configure-e2e-profile "$PLAN" playwright

CLI_E2E="$TMP_ROOT/cli-e2e"
write_fixture "$CLI_E2E" approved 'CLI E2E'
expect_ok 'CLI E2E는 Browser/API 프로필 제안 없이 Plan 검증' run_cli "$CLI_E2E" validate-plan "$PLAN"

echo 'PASS: approved E2E profile proposal and configuration'
