#!/usr/bin/env bash
# 승인된 제품 명세에서 공식 실행 계획을 만든다.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
  echo "사용법: scripts/new-exec-plan.sh <docs/product-specs/명세파일.md>" >&2
  exit 2
fi

SPEC_FILE="$1"
if ! grep -Eq '^- 상태: approved$' "$SPEC_FILE"; then
  echo "승인된 제품 명세만 실행 계획으로 전환할 수 있습니다: $SPEC_FILE" >&2
  exit 2
fi

NAME="$(sed -n 's/^# Product Spec: //p' "$SPEC_FILE" | head -n 1)"
DATE="$(date +%F)"
TIME="$(date +%H%M%S)"
SAFE_NAME="$(printf '%s' "$NAME" | tr ' /' '--' | tr -cd '[:alnum:]가-힣_-')"
PLAN_FILE="docs/exec-plans/active/${DATE}-${TIME}-${SAFE_NAME}.md"
mkdir -p docs/exec-plans/active

cat > "$PLAN_FILE" <<EOF
# Exec Plan: ${NAME}

- 상태: active
- 승인: pending
- 제품 명세: ${SPEC_FILE}
- 생성: ${DATE}, 담당: <이름/도구>

## 구현 계획

- 목적: ...
- 범위: ...
- 제외: ...
- 영향 파일 (예상): ...

## 구현 작업

<!-- 깊이가 단순이면 이 표를 생략할 수 있다. 확실하지 않은 항목은 지어내지 않고
     "조사 필요"로 남기고, 조사 후 이 계획을 갱신해 재승인받는다.
     운영 데이터 조회·계측 삽입 등 상태·권한에 영향을 주는 조사는 별도 승인이 필요하다. -->

| 순서 | 변경 대상 | 변경 내용·인터페이스 | 테스트·검증 명령 | 기대 증거 | AC |
|---:|---|---|---|---|---|
| 1 | ... | ... | ... | ... | ... |

## 검증 계획

| AC | 검증 방법 | 기대 증거 |
|---|---|---|
| AC-01 | 자동 테스트, 수동 확인, UAT, 측정 중 선택 | 테스트명·명령 출력·수동 확인 결과·UAT 관찰 기록 |

## 회귀 검증 대상

- 영향을 받는 기존 기능 또는 테스트: ...
EOF

echo "실행 계획 생성: $PLAN_FILE"
