#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NODE="$(command -v node)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TMP_ROOT"' EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

write_fixture() {
  local root="$1" setup_exit="$2"
  mkdir -p "$root/docs/product-specs" "$root/docs/exec-plans/active" "$root/.ai-dev-standard"
  cat > "$root/.ai-dev-standard.env" <<'EOF'
AI_DEV_STANDARD_MODE=template
AI_DEV_STANDARD_REQUIRE_LINT=false
AI_DEV_STANDARD_REQUIRE_TYPECHECK=false
AI_DEV_STANDARD_REQUIRE_TEST=false
EOF
  cat > "$root/docs/product-specs/bootstrap.md" <<'EOF'
# Product Spec: approval fixture

- 상태: approved
- 유형: 신규 기능
- 깊이: 일반
- 사전 승인 묶음: PREAPPROVAL-20261023-100000
- 승인 결정자: gon
- 승인 일자: 2026-10-23

## 문제·목표

- 문제: fixture
- 영향: fixture
- 목표: fixture
- 성공 기준: fixture

## 확정 요구사항

- fixture

## 완료 조건 (Acceptance Criteria)

| ID | 검증 항목 | 기대 결과 |
|---|---|---|
| AC-01 | fixture | pass |
EOF
  cat > "$root/docs/exec-plans/active/bootstrap.md" <<EOF
# Exec Plan: approval fixture

- 상태: active
- 승인: approved
- 검증 계약 버전: 2
- 제품 명세: docs/product-specs/bootstrap.md
- 사전 승인 묶음: PREAPPROVAL-20261023-100000
- 승인 결정자: gon
- 승인 일자: 2026-10-23

## 구현 계획

- 목적: bootstrap fixture

## 구현 작업

| 순서 | 변경 대상 | 변경 내용·인터페이스 | 테스트·검증 명령 | 기대 증거 | AC |
|---:|---|---|---|---|---|
| 1 | \`.ai-dev-standard/verification.json\` | configure | node | pass | AC-01 |

## Task Graph

| Task | 의존 | 소유 파일 | 상태 |
|---|---|---|---|
| T1 | — | .ai-dev-standard/verification.json | 구현 전 |

## 검증 계획

| AC | 검증 방법 | 기대 증거 |
|---|---|---|
| AC-01 | profile test | PASS |

## 회귀 검증 대상

- bootstrap configuration command

## E2E 판정

- 필요 여부: 불필요
- 방식: 해당 없음
- 판정 근거: CLI fixture
- 대상 AC: 해당 없음
- 자동 실행 명령 또는 수동 UAT 시나리오: 해당 없음
- 사전 조건: 해당 없음

## Bootstrap 검증 프로필

\`\`\`json
 {"schema_version":1,"setup":[{"id":"install-fixture","command":"$NODE","args":["-e","require('fs').writeFileSync('setup-ran.txt','partial'); if ($setup_exit === 9) process.exit(9); require('fs').writeFileSync('setup-ran.txt','yes')"],"cwd":".","required":true}],"components":[{"id":"app","paths":["src/"],"checks":[{"id":"smoke","kind":"test","command":"$NODE","args":["-e","process.exit(0)"],"cwd":".","required":true}]}]}
\`\`\`
EOF
}

TAMPERED="$TMP_ROOT/tampered"
write_fixture "$TAMPERED" 0
set +e
AI_DEV_STANDARD_ROOT="$TAMPERED" node "$ROOT/scripts/lib/cli.js" record-bootstrap-approval docs/exec-plans/active/bootstrap.md > "$TMP_ROOT/stamp.out" 2>&1
STAMP_CODE=$?
set -e
[ "$STAMP_CODE" -eq 0 ] || fail "approved pair should record its content fingerprint: $(cat "$TMP_ROOT/stamp.out")"
sed -i 's/bootstrap fixture/changed after approval/' "$TAMPERED/docs/exec-plans/active/bootstrap.md"
set +e
AI_DEV_STANDARD_ROOT="$TAMPERED" node "$ROOT/scripts/lib/cli.js" configure-verification docs/exec-plans/active/bootstrap.md > "$TMP_ROOT/tamper.out" 2>&1
TAMPER_CODE=$?
set -e
[ "$TAMPER_CODE" -ne 0 ] || fail 'changed approved plan was accepted'
grep -Fq '승인 내용 지문' "$TMP_ROOT/tamper.out" || fail "tamper rejection reason missing: $(cat "$TMP_ROOT/tamper.out")"
grep -Fxq 'AI_DEV_STANDARD_MODE=template' "$TAMPERED/.ai-dev-standard.env" || fail 'tampered plan changed project mode'
[ ! -e "$TAMPERED/.ai-dev-standard/verification.json" ] || fail 'tampered plan wrote verification profile'
set +e
AI_DEV_STANDARD_ROOT="$TAMPERED" node "$ROOT/scripts/lib/cli.js" record-bootstrap-approval docs/exec-plans/active/bootstrap.md > "$TMP_ROOT/restamp.out" 2>&1
RESTAMP_CODE=$?
set -e
[ "$RESTAMP_CODE" -ne 0 ] || fail 'stale approval fingerprint was silently replaced without reapproval'

UNSTAMPED="$TMP_ROOT/unstamped"
write_fixture "$UNSTAMPED" 0
set +e
AI_DEV_STANDARD_ROOT="$UNSTAMPED" node "$ROOT/scripts/lib/cli.js" configure-verification docs/exec-plans/active/bootstrap.md > "$TMP_ROOT/unstamped.out" 2>&1
UNSTAMPED_CODE=$?
set -e
[ "$UNSTAMPED_CODE" -ne 0 ] || fail 'approved bootstrap without a recorded content fingerprint was accepted'
grep -Fxq 'AI_DEV_STANDARD_MODE=template' "$UNSTAMPED/.ai-dev-standard.env" || fail 'unstamped bootstrap changed project mode'
[ ! -e "$UNSTAMPED/.ai-dev-standard/verification.json" ] || fail 'unstamped bootstrap wrote verification profile'
[ ! -e "$UNSTAMPED/setup-ran.txt" ] || fail 'unstamped bootstrap executed setup before approval integrity check'

PASS_ROOT="$TMP_ROOT/pass"
write_fixture "$PASS_ROOT" 0
AI_DEV_STANDARD_ROOT="$PASS_ROOT" node "$ROOT/scripts/lib/cli.js" record-bootstrap-approval docs/exec-plans/active/bootstrap.md >/dev/null
cat >> "$PASS_ROOT/docs/exec-plans/active/bootstrap.md" <<'EOF'

## 자동 검증 증거

- 실행 로그: Bootstrap 전후의 가변 증거는 승인 내용 범위가 아니다.
EOF
AI_DEV_STANDARD_ROOT="$PASS_ROOT" node "$ROOT/scripts/lib/cli.js" configure-verification docs/exec-plans/active/bootstrap.md > "$TMP_ROOT/pass.out" 2>&1 || \
  fail "approved setup and checks should pass: $(cat "$TMP_ROOT/pass.out")"
[ "$(cat "$PASS_ROOT/setup-ran.txt")" = yes ] || fail 'approved setup command was not executed'
grep -Fxq 'AI_DEV_STANDARD_MODE=active' "$PASS_ROOT/.ai-dev-standard.env" || fail 'passing bootstrap did not activate project'
node - "$PASS_ROOT/.ai-dev-standard/bootstrap-status.json" <<'NODE'
const fs = require("fs");
const status = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
if (status.state !== "complete" || status.stage !== "complete" || status.completed_actions[0] !== "install-fixture") process.exit(1);
NODE

FAIL_ROOT="$TMP_ROOT/fail"
write_fixture "$FAIL_ROOT" 9
AI_DEV_STANDARD_ROOT="$FAIL_ROOT" node "$ROOT/scripts/lib/cli.js" record-bootstrap-approval docs/exec-plans/active/bootstrap.md >/dev/null
set +e
AI_DEV_STANDARD_ROOT="$FAIL_ROOT" node "$ROOT/scripts/lib/cli.js" configure-verification docs/exec-plans/active/bootstrap.md > "$TMP_ROOT/fail.out" 2>&1
FAIL_CODE=$?
set -e
[ "$FAIL_CODE" -ne 0 ] || fail 'failed setup command incorrectly activated project'
grep -Fxq 'AI_DEV_STANDARD_MODE=initializing' "$FAIL_ROOT/.ai-dev-standard.env" || fail 'failed setup must remain initializing'
[ -f "$FAIL_ROOT/setup-ran.txt" ] || fail 'partial setup fixture did not simulate a partial installation'
[ ! -e "$FAIL_ROOT/.ai-dev-standard/verification-ready.json" ] || fail 'failed setup wrote readiness PASS'
node - "$FAIL_ROOT/.ai-dev-standard/bootstrap-status.json" <<'NODE'
const fs = require("fs");
const status = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
if (status.state !== "failed" || status.stage !== "setup" || status.failed_action !== "install-fixture" || status.exit_code !== 9) process.exit(1);
NODE
set +e
AI_DEV_STANDARD_ROOT="$FAIL_ROOT" node "$ROOT/scripts/lib/cli.js" configure-verification docs/exec-plans/active/bootstrap.md > "$TMP_ROOT/retry.out" 2>&1
RETRY_CODE=$?
set -e
[ "$RETRY_CODE" -ne 0 ] || fail 'repeated failing setup should not activate project'
node - "$FAIL_ROOT/.ai-dev-standard/bootstrap-status.json" <<'NODE'
const fs = require("fs");
const status = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
if (status.attempt !== 2 || status.attempt_history.length !== 1 || status.attempt_history[0].failed_action !== "install-fixture") process.exit(1);
NODE

echo 'PASS: bootstrap approval fingerprint detects plan changes and approved setup actions run safely'
