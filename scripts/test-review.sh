#!/usr/bin/env bash
# 비교 기준 commit이 없거나 잘못돼도 Review 진입점은 체크리스트를 안전하게 출력해야 한다.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLAN="$ROOT/docs/exec-plans/active/test-review-$$.md"
trap 'rm -f "$PLAN"' EXIT

cat > "$PLAN" <<'EOF'
# Exec Plan: review summary fixture

## 구현 계획

- 목적: automatic evidence summary

## 자동 검증 증거

### 실행 2026-10-21T00:00:00.000Z
- 종료 코드: 0
- 결과 요약: PASS (verify-plan 종료 코드 기준; 전체 출력은 기록하지 않음)

## 완료 기록

- 리뷰: PENDING

## AC 판정

| AC | 판정 | 증거 |
|---|---|---|
| AC-01 | PASS | fixture |
EOF

OUTPUT="$(bash "$ROOT/scripts/review.sh" nonexistent-review-base 2>&1)"

printf '%s\n' "$OUTPUT" | grep -Fq '[Standards Review]' || {
  echo 'FAIL: Standards Review 체크리스트가 없습니다.' >&2
  exit 1
}
printf '%s\n' "$OUTPUT" | grep -Fq '[Spec Review]' || {
  echo 'FAIL: Spec Review 체크리스트가 없습니다.' >&2
  exit 1
}
printf '%s\n' "$OUTPUT" | grep -Fq '[Evidence Review]' || {
  echo 'FAIL: Evidence Review 체크리스트가 없습니다.' >&2
  exit 1
}
if printf '%s\n' "$OUTPUT" | grep -Fq 'fatal:'; then
  echo 'FAIL: 비교 기준이 없을 때 git fatal 출력이 남았습니다.' >&2
  exit 1
fi

PLAN_OUTPUT="$(bash "$ROOT/scripts/review.sh" nonexistent-review-base --plan "$PLAN" 2>&1)"
printf '%s\n' "$PLAN_OUTPUT" | grep -Fq '[결과·검증] AC 판정 1/1 PASS · 자동 검증 증거: PASS (종료 코드 0)' || {
  echo 'FAIL: 자동 검증 증거가 Review 작업 요약에 반영되지 않았습니다.' >&2
  exit 1
}

echo 'PASS: review checklist handles a missing comparison base and summarizes automatic evidence'

# Review packet must use the current HEAD baseline and include all tracked and untracked changes.
PACKET_ROOT="$(mktemp -d)"
PACKET_OUTPUT="${PACKET_ROOT}.out"
trap 'rm -f "$PLAN" "$PACKET_OUTPUT"; rm -rf "$PACKET_ROOT"' EXIT
mkdir -p "$PACKET_ROOT/docs/exec-plans/active" "$PACKET_ROOT/docs/product-specs"
git -C "$PACKET_ROOT" init -q
git -C "$PACKET_ROOT" config user.email review-test@example.invalid
git -C "$PACKET_ROOT" config user.name review-test
printf 'baseline\n' > "$PACKET_ROOT/tracked-worktree.txt"
printf 'baseline\n' > "$PACKET_ROOT/tracked-staged.txt"
cat > "$PACKET_ROOT/docs/product-specs/spec.md" <<'EOF'
# Product Spec: review packet fixture

## 완료 조건

| ID | 완료 조건 |
|---|---|
| AC-01 | fixture |
EOF
cat > "$PACKET_ROOT/docs/exec-plans/active/plan.md" <<'EOF'
# Exec Plan: review packet fixture

- 제품 명세: docs/product-specs/spec.md
- 목적: review packet reports exact change scope

## AC 판정

| AC | 판정 | 증거 |
|---|---|---|
| AC-01 | PASS | fixture evidence |

## 자동 검증 증거

### 실행 2026-10-23T00:00:00.000Z
- 종료 코드: 0
- 결과 요약: PASS (fixture)
EOF
git -C "$PACKET_ROOT" add .
git -C "$PACKET_ROOT" commit -qm 'fixture baseline'
printf 'changed\n' > "$PACKET_ROOT/tracked-worktree.txt"
printf 'staged change\n' > "$PACKET_ROOT/tracked-staged.txt"
git -C "$PACKET_ROOT" add tracked-staged.txt
printf 'new file\n' > "$PACKET_ROOT/untracked-review.txt"
AI_DEV_STANDARD_ROOT="$PACKET_ROOT" node "$ROOT/scripts/lib/cli.js" review \
  --plan docs/exec-plans/active/plan.md > "$PACKET_OUTPUT" 2>&1
for expected in \
  '[리뷰 기준] HEAD' \
  'tracked-worktree.txt' \
  'tracked-staged.txt' \
  'untracked-review.txt' \
  'docs/product-specs/spec.md' \
  '[검증 재실행] Review 자료 준비는 테스트·검증 명령을 실행하지 않음'; do
  grep -Fq "$expected" "$PACKET_OUTPUT" || {
    echo "FAIL: Review packet is missing: $expected" >&2
    cat "$PACKET_OUTPUT" >&2
    exit 1
  }
done
grep -Fq 'HEAD~1' "$PACKET_OUTPUT" && {
  echo 'FAIL: default review base must be current HEAD, not the preceding commit' >&2
  exit 1
}

echo 'PASS: review packet includes plan, spec, staged, unstaged, and untracked scope without rerunning verification'
