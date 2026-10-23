#!/usr/bin/env bash
# 제품 명세 초안 또는 승인 명세에서 공식 실행 계획을 만든다.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
  echo "사용법: scripts/new-exec-plan.sh <docs/product-specs/명세파일.md>" >&2
  exit 2
fi

SPEC_FILE="$1"
SPEC_STATUS="$(sed -n 's/^- 상태: //p' "$SPEC_FILE" | head -n 1)"
if [ "$SPEC_STATUS" != "approved" ] && [ "$SPEC_STATUS" != "draft" ]; then
  echo "제품 명세 상태를 확인할 수 없습니다: $SPEC_FILE" >&2
  exit 2
fi

NAME="$(sed -n 's/^# Product Spec: //p' "$SPEC_FILE" | head -n 1)"
DATE="$(date +%F)"
TIME="$(date +%H%M%S)"
PREAPPROVAL_ID=""
if [ "$SPEC_STATUS" = "draft" ]; then
  PREAPPROVAL_ID="$(sed -n 's/^- 사전 승인 묶음: \(PREAPPROVAL-[0-9][0-9]*-[0-9][0-9]*\)$/\1/p' "$SPEC_FILE" | head -n 1)"
  if [ -z "$PREAPPROVAL_ID" ]; then
    PREAPPROVAL_ID="PREAPPROVAL-$(date +%Y%m%d)-${TIME}"
  fi
fi
SAFE_NAME="$(printf '%s' "$NAME" | tr ' /' '--' | tr -cd '[:alnum:]가-힣_-')"
PLAN_FILE="docs/exec-plans/active/${DATE}-${TIME}-${SAFE_NAME}.md"
mkdir -p docs/exec-plans/active

cat > "$PLAN_FILE" <<EOF
# Exec Plan: ${NAME}

- 상태: active
- 승인: pending
- 검증 계약 버전: 2
- 제품 명세: ${SPEC_FILE}
$(if [ -n "$PREAPPROVAL_ID" ]; then printf '%s\n' "- 사전 승인 묶음: ${PREAPPROVAL_ID}" '- 승인 결정자: pending' '- 승인 일자: pending'; fi)
- 생성: ${DATE}, 담당: <이름/도구>

## 구현 계획

- 목적: ...
- 범위: ...
- 제외: ...
- 영향 파일 (예상): ...

## 구현 작업

<!-- 깊이가 단순이면 이 표를 생략할 수 있다. 확실하지 않은 항목은 지어내지 않고
     "조사 필요"로 남기고, 조사 후 이 계획을 갱신해 재승인받는다.
     운영 데이터 조회·계측 삽입 등 상태·권한에 영향을 주는 조사는 별도 승인이 필요하다.
     복수 작업의 의존성 관리가 필요하면 선택적으로 '## Task Graph' 섹션을 추가한다:
     | Task | 의존 | 소유 파일 | 상태 | — Task는 T1 형식, 의존은 — 또는 선행 Task ID,
     상태는 구현 전/구현 완료/검증 완료만 허용. 단일 작업 계획은 이 섹션 없이도 유효하다. -->

| 순서 | 변경 대상 | 변경 내용·인터페이스 | 테스트·검증 명령 | 기대 증거 | AC |
|---:|---|---|---|---|---|
| 1 | ... | ... | ... | ... | ... |

## 검증 계획

| AC | 검증 방법 | 기대 증거 |
|---|---|---|
| AC-01 | 자동 테스트, 수동 확인, UAT, 측정 중 선택 | 테스트명·명령 출력·수동 확인 결과·UAT 관찰 기록 |

## 회귀 검증 대상

- 영향을 받는 기존 기능 또는 테스트: ...

## E2E 판정

- 필요 여부: 불필요
- 방식: 해당 없음
- 판정 근거: ...
- 대상 AC: 해당 없음
- 자동 실행 명령 또는 수동 UAT 시나리오: 해당 없음
- 사전 조건: 해당 없음
EOF

if [ -n "$PREAPPROVAL_ID" ] && ! grep -Eq '^- 사전 승인 묶음: ' "$SPEC_FILE"; then
  SPEC_TMP="${SPEC_FILE}.tmp.$$"
  awk -v id="$PREAPPROVAL_ID" 'BEGIN{inserted=0} /^## / && !inserted {print "- 사전 승인 묶음: " id; inserted=1} {print} END{if (!inserted) print "- 사전 승인 묶음: " id}' "$SPEC_FILE" > "$SPEC_TMP"
  mv "$SPEC_TMP" "$SPEC_FILE"
fi

echo "실행 계획 생성: $PLAN_FILE"
