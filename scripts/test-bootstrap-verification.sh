#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NODE="$(command -v node)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TMP_ROOT"' EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

write_fixture() {
  local root="$1" command_code="$2" approved="$3"
  mkdir -p "$root/docs/product-specs" "$root/docs/exec-plans/active" "$root/.ai-dev-standard"
  cat > "$root/.ai-dev-standard.env" <<'EOF'
AI_DEV_STANDARD_MODE=template
AI_DEV_STANDARD_REQUIRE_LINT=false
AI_DEV_STANDARD_REQUIRE_TYPECHECK=false
AI_DEV_STANDARD_REQUIRE_TEST=false
EOF
  cat > "$root/docs/product-specs/bootstrap.md" <<EOF
# Product Spec: bootstrap fixture

- 상태: $approved
- 사전 승인 묶음: PREAPPROVAL-20261023-000001
- 승인 결정자: gon
- 승인 일자: 2026-10-23

## 완료 조건

| ID | 완료 조건 | 기대 결과 |
|---|---|---|
| AC-01 | fixture | configured |
EOF
  cat > "$root/docs/exec-plans/active/bootstrap.md" <<'EOF'
# Exec Plan: bootstrap fixture

- 상태: active
- 승인: __APPROVED__
- 검증 계약 버전: 2
- 제품 명세: docs/product-specs/bootstrap.md
- 사전 승인 묶음: PREAPPROVAL-20261023-000001
- 승인 결정자: gon
- 승인 일자: 2026-10-23

## 구현 계획

- 목적: bootstrap fixture

## 구현 작업

| 순서 | 변경 대상 | 변경 내용·인터페이스 | 테스트·검증 명령 | 기대 증거 | AC |
|---:|---|---|---|---|---|
| 1 | `.ai-dev-standard/verification.json` | bootstrap profile | node | pass | AC-01 |

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

```json
{"schema_version":1,"components":[{"id":"app","paths":["src/"],"checks":[{"id":"smoke","kind":"test","command":"__NODE__","args":["-e","process.exit(__EXIT__)"],"cwd":".","required":true}]}]}
```
EOF
  sed -i "s/__APPROVED__/$approved/g; s|__NODE__|$NODE|g; s/__EXIT__/$command_code/g" "$root/docs/exec-plans/active/bootstrap.md"
}

PASS_ROOT="$TMP_ROOT/pass"
write_fixture "$PASS_ROOT" 0 approved
AI_DEV_STANDARD_ROOT="$PASS_ROOT" node "$ROOT/scripts/lib/cli.js" record-bootstrap-approval docs/exec-plans/active/bootstrap.md >/dev/null
set +e
AI_DEV_STANDARD_ROOT="$PASS_ROOT" node "$ROOT/scripts/lib/cli.js" configure-verification docs/exec-plans/active/bootstrap.md > "$TMP_ROOT/pass.out" 2>&1
PASS_CODE=$?
set -e
[ "$PASS_CODE" -eq 0 ] || fail "approved bootstrap should pass: $(cat "$TMP_ROOT/pass.out")"
grep -Fxq 'AI_DEV_STANDARD_MODE=active' "$PASS_ROOT/.ai-dev-standard.env" || fail 'successful bootstrap did not activate project'
grep -Fq '"result": "pass"' "$PASS_ROOT/.ai-dev-standard/verification-ready.json" || fail 'readiness evidence missing'
grep -Fq 'verification configuration ready' "$TMP_ROOT/pass.out" || fail 'configuration success was not reported'

FAIL_ROOT="$TMP_ROOT/fail"
write_fixture "$FAIL_ROOT" 9 approved
AI_DEV_STANDARD_ROOT="$FAIL_ROOT" node "$ROOT/scripts/lib/cli.js" record-bootstrap-approval docs/exec-plans/active/bootstrap.md >/dev/null
set +e
AI_DEV_STANDARD_ROOT="$FAIL_ROOT" node "$ROOT/scripts/lib/cli.js" configure-verification docs/exec-plans/active/bootstrap.md > "$TMP_ROOT/fail.out" 2>&1
FAIL_CODE=$?
set -e
[ "$FAIL_CODE" -eq 1 ] || fail "failed bootstrap checks must exit 1, got $FAIL_CODE"
grep -Fxq 'AI_DEV_STANDARD_MODE=initializing' "$FAIL_ROOT/.ai-dev-standard.env" || fail 'failed bootstrap must remain initializing'
[ ! -f "$FAIL_ROOT/.ai-dev-standard/verification-ready.json" ] || fail 'failed bootstrap wrote a PASS readiness record'

DENIED_ROOT="$TMP_ROOT/denied"
write_fixture "$DENIED_ROOT" 0 pending
set +e
AI_DEV_STANDARD_ROOT="$DENIED_ROOT" node "$ROOT/scripts/lib/cli.js" configure-verification docs/exec-plans/active/bootstrap.md > "$TMP_ROOT/denied.out" 2>&1
DENIED_CODE=$?
set -e
[ "$DENIED_CODE" -ne 0 ] || fail 'unapproved bootstrap plan was accepted'
grep -Fxq 'AI_DEV_STANDARD_MODE=template' "$DENIED_ROOT/.ai-dev-standard.env" || fail 'unapproved bootstrap changed mode'
[ ! -f "$DENIED_ROOT/.ai-dev-standard/verification.json" ] || fail 'unapproved bootstrap wrote profile'

echo 'PASS: bootstrap verification requires approved plan and activates only after required checks pass'
