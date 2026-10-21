#!/usr/bin/env bash
# 완료된 작업에서 발견한 개선 후보를 기록한다. 이 스크립트는 어떤 규칙도 수정하지 않는다.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ "$#" -ne 4 ] || [ ! -f "$4" ]; then
  echo "사용법: scripts/new-improvement-candidate.sh <제목> <문제> <근거> <출처-실행계획>" >&2
  exit 2
fi

TITLE="$1"
PROBLEM="$2"
EVIDENCE="$3"
SOURCE_PLAN="$4"
SAFE_TITLE="$(printf '%s' "$TITLE" | tr ' /' '--' | tr -cd '[:alnum:]가-힣_-')"
if [ -z "$SAFE_TITLE" ]; then
  SAFE_TITLE="improvement"
fi
DATE="$(date +%F)"
TIME="$(date +%H%M%S)"
FILE="docs/agent-improvements/candidates/${DATE}-${TIME}-${SAFE_TITLE}.md"
mkdir -p docs/agent-improvements/candidates

cat > "$FILE" <<EOF
# Improvement Candidate: ${TITLE}

- 상태: candidate
- 생성: ${DATE}
- 출처 실행 계획: ${SOURCE_PLAN}

## 문제

${PROBLEM}

## 근거

${EVIDENCE}

## 제안

- ...

## 영향 범위와 위험

- 영향 파일: ...
- 위험: ...

## 사람 결정

- 결정: 대기
- 결정자: ...
- 사유: ...
EOF

echo "개선 후보 생성: $FILE"
