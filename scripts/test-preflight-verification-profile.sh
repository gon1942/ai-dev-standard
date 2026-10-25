#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NODE="$(command -v node)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TMP_ROOT"' EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }
bootstrap() { "$ROOT/scripts/bootstrap-framework.sh" --project-dir "$1" --init >/dev/null; }

EMPTY="$TMP_ROOT/empty"
mkdir -p "$EMPTY"
bootstrap "$EMPTY"
"$ROOT/scripts/project-preflight.sh" --project-dir "$EMPTY" --format json > "$EMPTY/preflight.json"
grep -Fq '"can_initialize": true' "$EMPTY/preflight.json" || fail 'fresh template should expose bootstrap capability'
grep -Fq '"can_code": false' "$EMPTY/preflight.json" || fail 'fresh template must block feature coding'
grep -Fq '"verification_ready": false' "$EMPTY/preflight.json" || fail 'fresh template must not claim verification readiness'

INITIALIZING="$TMP_ROOT/initializing"
mkdir -p "$INITIALIZING"
bootstrap "$INITIALIZING"
sed -i 's/^AI_DEV_STANDARD_MODE=template$/AI_DEV_STANDARD_MODE=initializing/' "$INITIALIZING/.ai-dev-standard.env"
mkdir -p "$INITIALIZING/.ai-dev-standard"
cat > "$INITIALIZING/.ai-dev-standard/verification.json" <<EOF
{"schema_version":1,"components":[{"id":"java","paths":["src/"],"checks":[{"id":"test","kind":"test","command":"$NODE","args":["-e","process.exit(0)"],"cwd":".","required":true}]}]}
EOF
if ! "$ROOT/scripts/project-preflight.sh" --project-dir "$INITIALIZING" --format json > "$INITIALIZING/preflight.json"; then
  cat "$INITIALIZING/preflight.json" >&2
  fail 'initializing project should remain available for bootstrap'
fi
grep -Fq '"can_initialize": true' "$INITIALIZING/preflight.json" || fail 'initializing profile should remain configurable'
grep -Fq '"can_code": false' "$INITIALIZING/preflight.json" || fail 'initializing must not allow feature coding before successful checks'
cat > "$INITIALIZING/.ai-dev-standard/bootstrap-status.json" <<'EOF'
{"schema_version":1,"state":"failed","stage":"setup","failed_action":"install"}
EOF
"$ROOT/scripts/project-preflight.sh" --project-dir "$INITIALIZING" --write-session --format json >/dev/null
printf '%s\n' '{"schema_version":1,"state":"failed","stage":"setup","failed_action":"test"}' > "$INITIALIZING/.ai-dev-standard/bootstrap-status.json"
set +e
"$ROOT/scripts/project-preflight.sh" --project-dir "$INITIALIZING" --session-status > "$INITIALIZING/session-status.json" 2>&1
SESSION_CODE=$?
set -e
[ "$SESSION_CODE" -eq 2 ] || fail 'changed bootstrap resume status should invalidate the session preflight cache'

ACTIVE="$TMP_ROOT/active"
mkdir -p "$ACTIVE"
bootstrap "$ACTIVE"
sed -i 's/^AI_DEV_STANDARD_MODE=template$/AI_DEV_STANDARD_MODE=active/' "$ACTIVE/.ai-dev-standard.env"
# active 모드에는 Git 저장소가 필요하다 (프레임워크 공통 전제).
git -C "$ACTIVE" init -q
git -C "$ACTIVE" add -A
git -C "$ACTIVE" -c user.name='framework-test' -c user.email='framework-test@example.invalid' commit -qm 'fixture: active 전제'
mkdir -p "$ACTIVE/.ai-dev-standard"
cat > "$ACTIVE/.ai-dev-standard/verification.json" <<EOF
{"schema_version":1,"components":[{"id":"java","paths":["src/"],"checks":[{"id":"test","kind":"test","command":"$NODE","args":["-e","process.exit(0)"],"cwd":".","required":true}]}]}
EOF
AI_DEV_STANDARD_ROOT="$ACTIVE" FRAMEWORK_ROOT="$ROOT" node - <<'NODE'
const fs = require("fs");
const path = require("path");
const root = process.env.AI_DEV_STANDARD_ROOT;
const { loadVerificationProfile, verificationFingerprint } = require(path.join(process.env.FRAMEWORK_ROOT, "scripts/lib/verification"));
const profile = loadVerificationProfile(root).profile;
const fingerprint = verificationFingerprint(root, profile);
fs.writeFileSync(path.join(root, ".ai-dev-standard/verification-ready.json"), JSON.stringify({ schema_version: 1, result: "pass", fingerprint }));
NODE
"$ROOT/scripts/project-preflight.sh" --project-dir "$ACTIVE" --format json > "$ACTIVE/preflight.json"
grep -Fq '"verification_ready": true' "$ACTIVE/preflight.json" || fail 'matching readiness evidence should be accepted'
grep -Fq '"can_code": true' "$ACTIVE/preflight.json" || fail 'active verified project should allow coding'

printf '%s\n' '<project><modelVersion>4.0.0</modelVersion></project>' > "$ACTIVE/pom.xml"
"$ROOT/scripts/project-preflight.sh" --project-dir "$ACTIVE" --format json > "$ACTIVE/stale.json"
grep -Fq '"stack": ["Java' "$ACTIVE/stale.json" || fail 'Java stack marker was not detected'
grep -Fq '"verification_ready": false' "$ACTIVE/stale.json" || fail 'manifest change should stale verification readiness'

MULTI="$TMP_ROOT/multi-stack"
mkdir -p "$MULTI" "$MULTI/systemd" "$MULTI/src"
bootstrap "$MULTI"
touch "$MULTI/go.mod" "$MULTI/Cargo.toml" "$MULTI/.shellcheckrc" "$MULTI/src/maintenance.sh"
"$ROOT/scripts/project-preflight.sh" --project-dir "$MULTI" --format json > "$MULTI/preflight.json"
for stack in 'Go' 'Rust' 'Shell' 'System service'; do
  grep -Fq "\"$stack\"" "$MULTI/preflight.json" || fail "multi-stack marker missing: $stack"
done

echo 'PASS: preflight distinguishes bootstrap, initializing, active, and stale verification profile states'
