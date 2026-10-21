#!/usr/bin/env bash
# 사용자 요청을 공식 제품 명세로 기록한다.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ "$#" -ne 2 ] || [ -z "$1" ] || [ -z "$2" ]; then
  echo "사용법: scripts/new-product-spec.sh <작업명> <사용자 요청 원문>" >&2
  exit 2
fi

NAME="$1"
REQUEST="$2"
SAFE_NAME="$(printf '%s' "$NAME" | tr ' /' '--' | tr -cd '[:alnum:]가-힣_-')"
DATE="$(date +%F)"
TIME="$(date +%H%M%S)"
SPEC_FILE="docs/product-specs/${DATE}-${TIME}-${SAFE_NAME}.md"
mkdir -p docs/product-specs

if [ -e "$SPEC_FILE" ]; then
  echo "이미 존재하는 명세 파일: $SPEC_FILE" >&2
  exit 1
fi

cat > "$SPEC_FILE" <<EOF
# Product Spec: ${NAME}

- 상태: draft
- 유형: 신규 기능  (신규 기능 | 수정 | 버그 | 리팩터링 | 성능)
- 깊이: 일반  (단순 | 일반 | 설계 필요)
- 생성: ${DATE}
- 사용자 요청: ${REQUEST}

## 문제·목표

- 문제: ...
- 영향: ...
- 목표: ...
- 성공 기준: ...

## 재현 조건 (유형이 버그인 경우만 작성, 다른 유형은 이 섹션을 지운다)

재현 가능하면 아래 세 항목을 모두 채운다:

- 동일 입력:
- 반복 재현 절차:
- 기대 결과:

재현이 불가능한 버그면 위 세 항목을 지우고 아래 두 항목을 모두 채운다:

- 재현 불가 사유:
- 대체 판정 방법:

## 대안과 선택 사유 (구현 방식이 여럿 가능한 경우만 작성, 없으면 이 섹션을 지운다)

| 안 | 장점 | 단점 | 선택 여부·사유 |
|---|---|---|---|
| ... | ... | ... | ... |

## 확인 필요 사항

- ...

## 확정 요구사항

- ...

## 완료 조건 (Acceptance Criteria)

| ID | 완료 조건 | 기대 결과 |
|---|---|---|
| AC-01 | ... | ... |

## 범위

- 포함: ...
- 비목표(제외): 이번 작업에서 의도적으로 하지 않는 것: ...
EOF

echo "제품 명세 생성: $SPEC_FILE"
