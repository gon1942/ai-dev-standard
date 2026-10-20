#!/usr/bin/env bash
# 비교 기준 commit이 없거나 잘못돼도 Review 진입점은 체크리스트를 안전하게 출력해야 한다.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
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

echo 'PASS: review checklist handles a missing comparison base safely'
