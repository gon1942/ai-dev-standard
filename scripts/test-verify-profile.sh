#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NODE="$(command -v node)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TMP_ROOT"' EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

write_env() {
  cat > "$1/.ai-dev-standard.env" <<'EOF'
AI_DEV_STANDARD_MODE=initializing
AI_DEV_STANDARD_REQUIRE_LINT=false
AI_DEV_STANDARD_REQUIRE_TYPECHECK=false
AI_DEV_STANDARD_REQUIRE_TEST=false
EOF
}

write_profile() {
  local root="$1" result="$2"
  mkdir -p "$root/.ai-dev-standard"
  cat > "$root/.ai-dev-standard/verification.json" <<EOF
{"schema_version":1,"components":[{"id":"node","paths":["src/"],"checks":[{"id":"unit","kind":"test","command":"$NODE","args":["-e","process.exit($result)"],"cwd":".","required":true}]}]}
EOF
}

INIT_ROOT="$TMP_ROOT/initializing"
mkdir -p "$INIT_ROOT"
write_env "$INIT_ROOT"
write_profile "$INIT_ROOT" 0
set +e
AI_DEV_STANDARD_ROOT="$INIT_ROOT" node "$ROOT/scripts/lib/cli.js" verify > "$TMP_ROOT/init.out" 2>&1
INIT_CODE=$?
set -e
[ "$INIT_CODE" -eq 0 ] || fail "initializing profile PASS should run successfully, got $INIT_CODE: $(cat "$TMP_ROOT/init.out")"
grep -Fq 'INITIALIZING PASS' "$TMP_ROOT/init.out" || fail 'initializing pass must not be reported as active READY'
grep -Fq 'node/unit: PASS' "$TMP_ROOT/init.out" || fail 'configured required check did not run'

ACTIVE_ROOT="$TMP_ROOT/active"
mkdir -p "$ACTIVE_ROOT"
write_env "$ACTIVE_ROOT"
sed -i 's/initializing/active/' "$ACTIVE_ROOT/.ai-dev-standard.env"
write_profile "$ACTIVE_ROOT" 0
AI_DEV_STANDARD_ROOT="$ACTIVE_ROOT" node "$ROOT/scripts/lib/cli.js" verify > "$TMP_ROOT/active.out" 2>&1
grep -Fq 'Verify 통과. 다음 단계: 독립 Review' "$TMP_ROOT/active.out" || \
  fail 'automatic verification PASS must direct the agent to Review without implying READY_FOR_REVIEW'
if grep -Fq 'READY_FOR_REVIEW 가능' "$TMP_ROOT/active.out"; then
  fail 'verification-only success must not claim READY_FOR_REVIEW eligibility'
fi

FAIL_ROOT="$TMP_ROOT/failing"
mkdir -p "$FAIL_ROOT"
write_env "$FAIL_ROOT"
sed -i 's/initializing/active/' "$FAIL_ROOT/.ai-dev-standard.env"
write_profile "$FAIL_ROOT" 7
set +e
AI_DEV_STANDARD_ROOT="$FAIL_ROOT" node "$ROOT/scripts/lib/cli.js" verify > "$TMP_ROOT/fail.out" 2>&1
FAIL_CODE=$?
set -e
[ "$FAIL_CODE" -eq 1 ] || fail "required profile failure must fail verify with exit 1, got $FAIL_CODE"
grep -Fq 'node/unit: FAIL' "$TMP_ROOT/fail.out" || fail 'failed required check is not reported'

INVALID_ROOT="$TMP_ROOT/invalid"
mkdir -p "$INVALID_ROOT/.ai-dev-standard"
write_env "$INVALID_ROOT"
sed -i 's/initializing/active/' "$INVALID_ROOT/.ai-dev-standard.env"
printf '%s\n' '{ invalid json' > "$INVALID_ROOT/.ai-dev-standard/verification.json"
set +e
AI_DEV_STANDARD_ROOT="$INVALID_ROOT" node "$ROOT/scripts/lib/cli.js" verify > "$TMP_ROOT/invalid.out" 2>&1
INVALID_CODE=$?
set -e
[ "$INVALID_CODE" -eq 2 ] || fail "invalid profile must be a configuration error, got $INVALID_CODE"

echo 'PASS: verify runs profile checks, distinguishes initializing from active, and blocks failures'
