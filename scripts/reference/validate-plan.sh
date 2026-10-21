#!/usr/bin/env bash
# 구현 전 Exec Plan의 승인·구조·AC 추적성을 검사한다. 테스트는 실행하지 않는다.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
  echo "사용법: scripts/validate-plan.sh <docs/exec-plans/active/실행계획.md>" >&2
  exit 2
fi

PLAN_FILE="$1"
case "$PLAN_FILE" in docs/exec-plans/active/*) ;; *) echo "활성 실행 계획 파일을 지정하세요." >&2; exit 2 ;; esac

require() {
  grep -Eq "$1" "$PLAN_FILE" || { echo "실행 계획 필수 항목 누락: $1" >&2; exit 2; }
}

require '^# Exec Plan:'
require '^- 상태: active$'
require '^- 승인: approved$'
require '^- 제품 명세: '
require '^## 구현 계획$'
require '^## 검증 계획$'
require '^## 회귀 검증 대상$'

SPEC_FILE="$(sed -n 's/^- 제품 명세: //p' "$PLAN_FILE" | head -n 1)"
if [ -z "$SPEC_FILE" ] || [ ! -f "$SPEC_FILE" ]; then
  echo "제품 명세를 찾을 수 없습니다: $SPEC_FILE" >&2
  exit 2
fi
if ! grep -Eq '^- 상태: approved$' "$SPEC_FILE"; then
  echo "승인된 제품 명세가 아닙니다: $SPEC_FILE" >&2
  exit 2
fi

if grep -q '^- 유형: 버그' "$SPEC_FILE"; then
  if ! grep -q '^## 재현 조건' "$SPEC_FILE"; then
    echo "버그 유형 명세에 '## 재현 조건' 섹션이 필요합니다." >&2
    exit 2
  fi
  REPRO_SECTION="$(sed -n '/^## 재현 조건/,/^## /p' "$SPEC_FILE")"
  if printf '%s\n' "$REPRO_SECTION" | grep -Eq '^- 재현 불가 사유: .+'; then
    if ! printf '%s\n' "$REPRO_SECTION" | grep -Eq '^- 대체 판정 방법: .+'; then
      echo "재현 불가 버그는 '대체 판정 방법'도 명시해야 합니다." >&2
      exit 2
    fi
  else
    for label in "동일 입력" "반복 재현 절차" "기대 결과"; do
      if ! printf '%s\n' "$REPRO_SECTION" | grep -Eq "^- ${label}: .+"; then
        echo "버그 재현 조건의 '${label}'이(가) 미작성입니다 (세 항목 모두 필요)." >&2
        exit 2
      fi
    done
  fi
fi

if grep -Eq '(^|[[:space:]])\.\.\.' "$PLAN_FILE"; then
  echo "실행 계획에 미작성 placeholder(...)가 남아 있습니다." >&2
  exit 2
fi

spec_acs="$(sed -n '/^## 완료 조건/,/^## /p' "$SPEC_FILE" | grep -oE 'AC-[0-9]+' | sort -u || true)"
if [ -z "$spec_acs" ]; then
  echo "제품 명세에 Acceptance Criteria가 없습니다." >&2
  exit 2
fi
for ac in $spec_acs; do
  if ! awk '/^## 검증 계획$/{inside=1; next} /^## /{inside=0} inside {print}' "$PLAN_FILE" | grep -Fq "$ac"; then
    echo "검증 계획에 명세 AC가 없습니다: $ac" >&2
    exit 2
  fi
done

echo "PLAN VALID: $PLAN_FILE"
