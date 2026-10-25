#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NODE="$(command -v node)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TMP_ROOT"' EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }
PROJECT="$TMP_ROOT/project"
mkdir -p "$PROJECT/.ai-dev-standard" "$PROJECT/docs/exec-plans/active" "$PROJECT/src"
cat > "$PROJECT/.ai-dev-standard.env" <<'EOF'
AI_DEV_STANDARD_MODE=active
AI_DEV_STANDARD_REQUIRE_LINT=false
AI_DEV_STANDARD_REQUIRE_TYPECHECK=false
AI_DEV_STANDARD_REQUIRE_TEST=false
EOF
cat > "$PROJECT/package.json" <<'EOF'
{"name":"fixture","version":"1.0.0"}
EOF
cat > "$PROJECT/.ai-dev-standard/verification.json" <<EOF
{"schema_version":1,"components":[{"id":"node","paths":["src/"],"checks":[{"id":"tests","kind":"test","command":"$NODE","args":["-e","process.exit(0)"],"cwd":".","required":true}]}]}
EOF
AI_DEV_STANDARD_ROOT="$PROJECT" FRAMEWORK_ROOT="$ROOT" node - <<'NODE'
const fs = require("fs");
const path = require("path");
const root = process.env.AI_DEV_STANDARD_ROOT;
const { loadVerificationProfile, writeVerificationReadiness } = require(path.join(process.env.FRAMEWORK_ROOT, "scripts/lib/verification"));
const profile = loadVerificationProfile(root).profile;
if (!writeVerificationReadiness(root, profile, "bootstrap-plan")) process.exit(1);
NODE

git -C "$PROJECT" init -q
git -C "$PROJECT" add -A
git -C "$PROJECT" -c user.name='framework-test' -c user.email='framework-test@example.invalid' commit -qm fixture

PLAN="$PROJECT/docs/exec-plans/active/work.md"
cat > "$PLAN" <<'EOF'
# Exec Plan: convergence fixture

- 상태: active
- 승인: approved
- 제품 명세: docs/product-specs/work.md

## 구현 계획

- 목적: convergence fixture

## 검증 계획

| AC | 검증 방법 | 기대 증거 |
|---|---|---|
| AC-01 | configured command | PASS |

## 회귀 검증 대상

- verification profile

## 완료 기록

- 완료: fixture

## AC 판정

| AC | 판정 | 증거 |
|---|---|---|
| AC-01 | PASS | automated fixture |

## 자동 검증 증거

### 실행 2026-10-23T00:00:00.000Z
- 실행 시각: 2026-10-23T00:00:00.000Z
- 종료 코드: 0
- 소스 지문: FINGERPRINT

- 리뷰: PASS
EOF

FINGERPRINT="$(AI_DEV_STANDARD_ROOT="$PROJECT" FRAMEWORK_ROOT="$ROOT" node - <<'NODE'
const path = require("path");
const root = process.env.AI_DEV_STANDARD_ROOT;
const { computeSourceFingerprint } = require(path.join(process.env.FRAMEWORK_ROOT, "scripts/lib/evidence"));
process.stdout.write(computeSourceFingerprint("docs/exec-plans/active/work.md"));
NODE
)"
sed -i "s/FINGERPRINT/$FINGERPRINT/g" "$PLAN"

set +e
AI_DEV_STANDARD_ROOT="$PROJECT" node "$ROOT/scripts/lib/cli.js" converge-plan docs/exec-plans/active/work.md > "$TMP_ROOT/ready.out" 2>&1
READY_CODE=$?
set -e
[ "$READY_CODE" -eq 0 ] || fail "matching verification readiness should converge: $(cat "$TMP_ROOT/ready.out")"

printf '%s\n' '{"name":"fixture","version":"1.0.1"}' > "$PROJECT/package.json"
FINGERPRINT="$(AI_DEV_STANDARD_ROOT="$PROJECT" FRAMEWORK_ROOT="$ROOT" node - <<'NODE'
const path = require("path");
const root = process.env.AI_DEV_STANDARD_ROOT;
const { computeSourceFingerprint } = require(path.join(process.env.FRAMEWORK_ROOT, "scripts/lib/evidence"));
process.stdout.write(computeSourceFingerprint("docs/exec-plans/active/work.md"));
NODE
)"
sed -i "s/- 소스 지문: .*/- 소스 지문: $FINGERPRINT/" "$PLAN"
set +e
AI_DEV_STANDARD_ROOT="$PROJECT" node "$ROOT/scripts/lib/cli.js" converge-plan docs/exec-plans/active/work.md > "$TMP_ROOT/stale.out" 2>&1
STALE_CODE=$?
set -e
[ "$STALE_CODE" -ne 0 ] || fail 'stale verification profile readiness must block convergence even with a fresh source fingerprint'
grep -Fq '검증 준비' "$TMP_ROOT/stale.out" || fail "stale-profile block reason missing: $(cat "$TMP_ROOT/stale.out")"

AI_DEV_STANDARD_ROOT="$PROJECT" node "$ROOT/scripts/lib/cli.js" record-verification-evidence docs/exec-plans/active/work.md > "$TMP_ROOT/refresh.out" 2>&1 || \
  fail "successful verify should refresh readiness evidence: $(cat "$TMP_ROOT/refresh.out")"
AI_DEV_STANDARD_ROOT="$PROJECT" node "$ROOT/scripts/lib/cli.js" converge-plan docs/exec-plans/active/work.md > "$TMP_ROOT/refreshed.out" 2>&1 || \
  fail "fresh verification evidence should restore convergence: $(cat "$TMP_ROOT/refreshed.out")"

sed -i '/^- 제품 명세:/a - 리뷰 계약 버전: 1' "$PLAN"
set +e
AI_DEV_STANDARD_ROOT="$PROJECT" node "$ROOT/scripts/lib/cli.js" converge-plan docs/exec-plans/active/work.md > "$TMP_ROOT/review-missing.out" 2>&1
REVIEW_MISSING_CODE=$?
set -e
[ "$REVIEW_MISSING_CODE" -ne 0 ] || fail 'versioned review without a structured review record must block convergence'
grep -Fq '리뷰' "$TMP_ROOT/review-missing.out" || fail "missing-review block reason absent: $(cat "$TMP_ROOT/review-missing.out")"
AI_DEV_STANDARD_ROOT="$PROJECT" node "$ROOT/scripts/lib/cli.js" work-status > "$TMP_ROOT/review-status.out"
grep -Fq '리뷰' "$TMP_ROOT/review-status.out" || fail "work-status must explain incomplete versioned review evidence: $(cat "$TMP_ROOT/review-status.out")"
if grep -Fq '### 전환 누락' "$TMP_ROOT/review-status.out"; then
  fail 'work-status must not classify a plan with incomplete versioned review evidence as ready for convergence'
fi

cat >> "$PLAN" <<'EOF'

## 리뷰 기록

- 리뷰어: independent-reviewer-fixture
- 검토 기준점: HEAD
- 검토 소스 지문: REVIEW_FINGERPRINT
- Standards Review: PASS
- Spec Review: PASS
- Evidence Review: PASS
- 결과: PASS
- 리뷰: PASS
- 발견사항: 없음
EOF
REVIEW_FINGERPRINT="$(AI_DEV_STANDARD_ROOT="$PROJECT" FRAMEWORK_ROOT="$ROOT" node - <<'NODE'
const path = require("path");
const { computeSourceFingerprint } = require(path.join(process.env.FRAMEWORK_ROOT, "scripts/lib/evidence"));
process.stdout.write(computeSourceFingerprint("docs/exec-plans/active/work.md"));
NODE
)"
sed -i "s/REVIEW_FINGERPRINT/$REVIEW_FINGERPRINT/" "$PLAN"
AI_DEV_STANDARD_ROOT="$PROJECT" node "$ROOT/scripts/lib/cli.js" converge-plan docs/exec-plans/active/work.md > "$TMP_ROOT/review-valid.out" 2>&1 || \
  fail "valid versioned review record should converge: $(cat "$TMP_ROOT/review-valid.out")"
AI_DEV_STANDARD_ROOT="$PROJECT" node "$ROOT/scripts/lib/cli.js" work-status > "$TMP_ROOT/review-valid-status.out"
grep -Fq '리뷰 기록 형식 확인됨' "$TMP_ROOT/review-valid-status.out" || fail 'work-status must report valid versioned review evidence and direct to Converge'

printf 'changed after review\n' > "$PROJECT/src/review-freshness.js"
FINGERPRINT="$(AI_DEV_STANDARD_ROOT="$PROJECT" FRAMEWORK_ROOT="$ROOT" node - <<'NODE'
const path = require("path");
const { computeSourceFingerprint } = require(path.join(process.env.FRAMEWORK_ROOT, "scripts/lib/evidence"));
process.stdout.write(computeSourceFingerprint("docs/exec-plans/active/work.md"));
NODE
)"
sed -i "s/^- 소스 지문: .*/- 소스 지문: $FINGERPRINT/" "$PLAN"
AI_DEV_STANDARD_ROOT="$PROJECT" node "$ROOT/scripts/lib/cli.js" work-status > "$TMP_ROOT/review-stale-status.out"
grep -Fq 'Converge를 실행해' "$TMP_ROOT/review-stale-status.out" || fail 'work-status must require Converge freshness validation before transition'
set +e
AI_DEV_STANDARD_ROOT="$PROJECT" node "$ROOT/scripts/lib/cli.js" converge-plan docs/exec-plans/active/work.md > "$TMP_ROOT/review-stale.out" 2>&1
REVIEW_STALE_CODE=$?
set -e
[ "$REVIEW_STALE_CODE" -ne 0 ] || fail 'review with stale source fingerprint must block convergence after verification refresh'
grep -Fq '리뷰' "$TMP_ROOT/review-stale.out" || fail "stale-review block reason absent: $(cat "$TMP_ROOT/review-stale.out")"

# fast 체인 PASS만 있는 계획은 수렴이 차단된다 — 수렴 전 full 체인 1회가 필수다.
# 리뷰 신선도 게이트에 걸리지 않도록 리뷰는 레거시 형식(버전 미기재)으로 되돌린다.
FAST_PLAN="$PROJECT/docs/exec-plans/active/work-fast.md"
sed 's/# Exec Plan: convergence fixture/# Exec Plan: convergence fast fixture/' "$PLAN" > "$FAST_PLAN"
sed -i '/^- 리뷰 계약 버전:/d' "$FAST_PLAN"
sed -i '/^## 리뷰 기록$/,/^## /{/^## 리뷰 기록$/d; /^## /!d}' "$FAST_PLAN"
sed -i 's/^- 종료 코드: 0$/- 실행 명령: `node scripts\/lib\/cli.js verify-plan docs\/exec-plans\/active\/work-fast.md --fast`\n- 종료 코드: 0/' "$FAST_PLAN"
set +e
AI_DEV_STANDARD_ROOT="$PROJECT" node "$ROOT/scripts/lib/cli.js" converge-plan docs/exec-plans/active/work-fast.md > "$TMP_ROOT/fast-only.out" 2>&1
FAST_ONLY_CODE=$?
set -e
[ "$FAST_ONLY_CODE" -ne 0 ] || fail 'fast-only evidence must block convergence'
grep -Fq 'fast 체인입니다' "$TMP_ROOT/fast-only.out" || fail "fast-only block reason absent: $(cat "$TMP_ROOT/fast-only.out")"
rm -f "$FAST_PLAN"

echo 'PASS: convergence checks review evidence version and source freshness while retaining legacy support'
