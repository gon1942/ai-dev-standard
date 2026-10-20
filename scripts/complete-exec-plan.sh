#!/usr/bin/env bash
# 사람 승인 후 READY_FOR_REVIEW 실행 계획을 완료 보관소로 이동한다.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ "$#" -ne 2 ] || [ ! -f "$1" ] || [ -z "$2" ]; then
  echo "사용법: scripts/complete-exec-plan.sh <active-실행계획> <승인자>" >&2
  exit 2
fi

PLAN_FILE="$1"
APPROVER="$2"
case "$PLAN_FILE" in docs/exec-plans/active/*) ;; *) echo "active 실행 계획만 완료할 수 있습니다." >&2; exit 2 ;; esac
if ! grep -Eq '^- 상태: READY_FOR_REVIEW$' "$PLAN_FILE"; then
  echo "READY_FOR_REVIEW 상태의 실행 계획만 완료할 수 있습니다." >&2
  exit 2
fi

mkdir -p docs/exec-plans/completed
TARGET="docs/exec-plans/completed/$(basename "$PLAN_FILE")"
if [ -e "$TARGET" ]; then
  echo "완료 실행 계획이 이미 존재합니다: $TARGET" >&2
  exit 1
fi

TEMP_FILE="$(mktemp)"
sed 's/^- 상태: READY_FOR_REVIEW$/- 상태: done/' "$PLAN_FILE" > "$TEMP_FILE"
printf '\n- 완료 승인: %s\n' "$APPROVER" >> "$TEMP_FILE"
mv "$TEMP_FILE" "$PLAN_FILE"
mv "$PLAN_FILE" "$TARGET"
echo "실행 계획 완료: $TARGET"
