#!/usr/bin/env bash
# 활성 실행 계획을 기준으로 공통 검증과 계획 검토를 수행한다.
set -euo pipefail
cd "$(dirname "$0")/.."

FAST=0
if [ "${2:-}" = "--fast" ]; then FAST=1; fi
if [ "$#" -lt 1 ] || [ "$#" -gt 2 ] || [ ! -f "$1" ]; then
  echo "사용법: scripts/verify-plan.sh <docs/exec-plans/active/실행계획.md> [--fast]" >&2
  exit 2
fi

PLAN_FILE="$1"
case "$PLAN_FILE" in
  docs/exec-plans/active/*) ;;
  *) echo "활성 실행 계획 파일을 지정하세요: $PLAN_FILE" >&2; exit 2 ;;
esac

for heading in '^# Exec Plan:' '^- 제품 명세:' '^## 구현 계획$' '^## 검증 계획$' '^## 회귀 검증 대상$'; do
  if ! grep -Eq "$heading" "$PLAN_FILE"; then
    echo "실행 계획 필수 항목 누락: ${heading}" >&2
    exit 2
  fi
done

if [ "$FAST" -eq 1 ]; then bash scripts/verify.sh --fast; else bash scripts/verify.sh; fi
RESULT=$?
echo ""
echo "실행 계획의 검증 계획·회귀 대상을 수행하고 같은 파일에 AC 판정과 증거를 기록하세요:"
awk '/^## 검증 계획$/{show=1} /^## 회귀 검증 대상$/{exit} show {print}' "$PLAN_FILE"
awk '/^## 회귀 검증 대상$/{show=1} show && /^## / && !/^## 회귀 검증 대상$/{exit} show {print}' "$PLAN_FILE"
exit "$RESULT"
