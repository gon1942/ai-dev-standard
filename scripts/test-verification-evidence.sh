#!/usr/bin/env bash
# record-verification-evidence의 성공·실패·안전성·상태 불변 회귀 검사.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
SUCCESS_ROOT="$TMP_ROOT/success"
FAIL_ROOT="$TMP_ROOT/fail"
trap 'rm -rf -- "$TMP_ROOT"' EXIT

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

write_env() {
  cat > "$1/.ai-dev-standard.env" <<'EOF'
AI_DEV_STANDARD_MODE=template
AI_DEV_STANDARD_REQUIRE_LINT=false
AI_DEV_STANDARD_REQUIRE_TYPECHECK=false
AI_DEV_STANDARD_REQUIRE_TEST=false
EOF
}

git_baseline() {
  git -C "$1" init -q
  git -C "$1" add -A
  git -C "$1" -c user.name='framework-test' -c user.email='framework-test@example.invalid' commit -qm fixture
}

write_valid_plan() {
  mkdir -p "$1/docs/exec-plans/active"
  cat > "$1/docs/exec-plans/active/evidence.md" <<'EOF'
# Exec Plan: evidence fixture

- 상태: active
- 승인: approved
- 제품 명세: docs/product-specs/evidence.md

## 구현 계획

- 목적: regression fixture

## 검증 계획

| AC | 검증 방법 | 기대 증거 |
|---|---|---|
| AC-01 | fixture | UNSAFE_OUTPUT_SENTINEL |

## 회귀 검증 대상

- record-verification-evidence
EOF
}

mkdir -p "$SUCCESS_ROOT"
write_env "$SUCCESS_ROOT"
write_valid_plan "$SUCCESS_ROOT"
git_baseline "$SUCCESS_ROOT"
SUCCESS_PLAN="docs/exec-plans/active/evidence.md"

# 기존 읽기 전용 검증·수렴 명령은 계획 파일을 고치지 않는다.
BEFORE_READONLY="$(sha256sum "$SUCCESS_ROOT/$SUCCESS_PLAN" | awk '{print $1}')"
AI_DEV_STANDARD_ROOT="$SUCCESS_ROOT" node "$ROOT/scripts/lib/cli.js" \
  verify-plan "$SUCCESS_PLAN" > "$TMP_ROOT/verify-plan.out" 2>&1
[ "$BEFORE_READONLY" = "$(sha256sum "$SUCCESS_ROOT/$SUCCESS_PLAN" | awk '{print $1}')" ] || \
  fail '기본 verify-plan이 계획 파일을 변경했습니다'
set +e
AI_DEV_STANDARD_ROOT="$SUCCESS_ROOT" node "$ROOT/scripts/lib/cli.js" \
  converge-plan "$SUCCESS_PLAN" > "$TMP_ROOT/converge-plan.out" 2>&1
CONVERGE_CODE=$?
set -e
[ "$CONVERGE_CODE" -ne 0 ] || fail '불완전 fixture의 수렴이 예기치 않게 통과했습니다'
[ "$BEFORE_READONLY" = "$(sha256sum "$SUCCESS_ROOT/$SUCCESS_PLAN" | awk '{print $1}')" ] || \
  fail '기본 converge-plan이 계획 파일을 변경했습니다'

# 계획 파일만 바꾼 상태에서 수집한다. 기록한 계획 자체가 소스 지문에 포함되면 안 된다.
printf '%s\n' '- 계획 자체 변경: source state exclusion fixture' >> "$SUCCESS_ROOT/$SUCCESS_PLAN"

AI_DEV_STANDARD_ROOT="$SUCCESS_ROOT" node "$ROOT/scripts/lib/cli.js" \
  record-verification-evidence "$SUCCESS_PLAN" > "$TMP_ROOT/direct.out" 2>&1
AI_DEV_STANDARD_ROOT="$SUCCESS_ROOT" "$ROOT/scripts/record-verification-evidence.sh" \
  "$SUCCESS_PLAN" > "$TMP_ROOT/shim.out" 2>&1
AI_DEV_STANDARD_ROOT="$SUCCESS_ROOT" node "$ROOT/bin/ai-dev-standard.js" \
  record-verification-evidence "$SUCCESS_PLAN" > "$TMP_ROOT/public-cli.out" 2>&1

SUCCESS_TEXT="$(cat "$SUCCESS_ROOT/$SUCCESS_PLAN")"
[ "$(grep -c '^### 실행 ' <<<"$SUCCESS_TEXT")" -eq 3 ] || fail 'Node·shim·공개 CLI가 각각 증거를 기록하지 않았습니다'
grep -Fq '## 자동 검증 증거' <<<"$SUCCESS_TEXT" || fail '자동 검증 증거 섹션이 없습니다'
grep -Fq -- '- 실행 명령: `node scripts/lib/cli.js verify-plan docs/exec-plans/active/evidence.md`' \
  <<<"$SUCCESS_TEXT" || fail '실제 실행 명령이 기록되지 않았습니다'
grep -Fq -- '- 종료 코드: 0' <<<"$SUCCESS_TEXT" || fail 'PASS 종료 코드가 기록되지 않았습니다'
grep -Fq -- '- 결과 요약: PASS (verify-plan 종료 코드 기준; 전체 출력은 기록하지 않음)' \
  <<<"$SUCCESS_TEXT" || fail '안전한 PASS 요약이 기록되지 않았습니다'
grep -Fq '작업 트리 식별자(계획 파일 제외): sha256:' <<<"$SUCCESS_TEXT" || fail '소스 상태 식별자가 없습니다'
grep -Fq '(0건)' <<<"$SUCCESS_TEXT" || fail '계획 파일이 소스 상태 지문에서 제외되지 않았습니다'

EVIDENCE_TEXT="$(sed -n '/^## 자동 검증 증거$/,$p' "$SUCCESS_ROOT/$SUCCESS_PLAN")"
if grep -Fq 'UNSAFE_OUTPUT_SENTINEL' <<<"$EVIDENCE_TEXT"; then
  fail 'verify-plan 출력 전문이 자동 증거에 기록되었습니다'
fi
grep -Fxq -- '- 상태: active' <<<"$SUCCESS_TEXT" || fail '자동 기록이 상태를 변경했습니다'
grep -Fxq -- '- 승인: approved' <<<"$SUCCESS_TEXT" || fail '자동 기록이 승인 상태를 변경했습니다'
if grep -Eq '^## AC 판정$|^- 리뷰:|READY_FOR_REVIEW|^- 완료 승인:|^- 상태: done$' <<<"$EVIDENCE_TEXT"; then
  fail '자동 기록이 AC·리뷰·완료 상태를 변경했습니다'
fi

# 완료 기록이 이미 있을 때 재검증해도 증거는 해당 섹션 안에 쌓여야 한다.
cat >> "$SUCCESS_ROOT/$SUCCESS_PLAN" <<'EOF'

## 완료 기록

- 리뷰: PENDING
EOF
AI_DEV_STANDARD_ROOT="$SUCCESS_ROOT" node "$ROOT/scripts/lib/cli.js" \
  record-verification-evidence "$SUCCESS_PLAN" > "$TMP_ROOT/reverify.out" 2>&1
SUCCESS_TEXT="$(cat "$SUCCESS_ROOT/$SUCCESS_PLAN")"
[ "$(grep -c '^### 실행 ' <<<"$SUCCESS_TEXT")" -eq 4 ] || fail '재검증 증거가 추가되지 않았습니다'
AUTO_LAST_LINE="$(awk '/^## 자동 검증 증거$/{inside=1; next} inside && /^### 실행 /{line=NR} /^## 완료 기록$/{inside=0} END{print line}' "$SUCCESS_ROOT/$SUCCESS_PLAN")"
COMPLETE_LINE="$(grep -n '^## 완료 기록$' "$SUCCESS_ROOT/$SUCCESS_PLAN" | cut -d: -f1)"
[ -n "$AUTO_LAST_LINE" ] && [ "$AUTO_LAST_LINE" -lt "$COMPLETE_LINE" ] || \
  fail '재검증 증거가 자동 검증 증거 섹션 밖에 기록되었습니다'

mkdir -p "$FAIL_ROOT/docs/exec-plans/active"
write_env "$FAIL_ROOT"
cat > "$FAIL_ROOT/docs/exec-plans/active/invalid.md" <<'EOF'
# Exec Plan: invalid fixture

- 상태: active
- 승인: approved
- 제품 명세: docs/product-specs/invalid.md

## 구현 계획

- 목적: required verification section is intentionally absent
EOF
git_baseline "$FAIL_ROOT"
FAIL_PLAN="docs/exec-plans/active/invalid.md"

set +e
AI_DEV_STANDARD_ROOT="$FAIL_ROOT" node "$ROOT/scripts/lib/cli.js" \
  record-verification-evidence "$FAIL_PLAN" > "$TMP_ROOT/fail.out" 2>&1
FAIL_CODE=$?
set -e
[ "$FAIL_CODE" -eq 2 ] || fail "실패한 verify-plan 종료 코드가 보존되지 않았습니다: $FAIL_CODE"
FAIL_TEXT="$(cat "$FAIL_ROOT/$FAIL_PLAN")"
grep -Fq '## 자동 검증 증거' <<<"$FAIL_TEXT" || fail 'FAIL 증거가 기록되지 않았습니다'
grep -Fq -- '- 종료 코드: 2' <<<"$FAIL_TEXT" || fail 'FAIL 종료 코드가 기록되지 않았습니다'
grep -Fq -- '- 결과 요약: FAIL (verify-plan 종료 코드 기준; 전체 출력은 기록하지 않음)' \
  <<<"$FAIL_TEXT" || fail '안전한 FAIL 요약이 기록되지 않았습니다'
grep -Fxq -- '- 상태: active' <<<"$FAIL_TEXT" || fail '실패 증거가 상태를 변경했습니다'

set +e
AI_DEV_STANDARD_ROOT="$SUCCESS_ROOT" node "$ROOT/scripts/lib/cli.js" \
  record-verification-evidence docs/exec-plans/completed/not-active.md > "$TMP_ROOT/invalid.out" 2>&1
INVALID_CODE=$?
set -e
[ "$INVALID_CODE" -eq 2 ] || fail '잘못된 활성 계획 경로가 차단되지 않았습니다'

echo 'PASS: verification evidence records PASS/FAIL safely without state transitions'
