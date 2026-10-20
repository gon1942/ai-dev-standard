#!/usr/bin/env bash
# 사람의 승인 또는 기각 결정을 기록하고 후보를 해당 보관소로 이동한다.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ "$#" -ne 4 ] || [ ! -f "$2" ]; then
  echo "사용법: scripts/decide-improvement.sh <approve|reject> <후보파일> <결정자> <사유>" >&2
  exit 2
fi

DECISION="$1"
CANDIDATE="$2"
DECIDER="$3"
REASON="$4"
case "$DECISION" in approve) STATUS="approved" ;; reject) STATUS="rejected" ;; *) echo "결정은 approve 또는 reject여야 합니다." >&2; exit 2 ;; esac
case "$CANDIDATE" in
  docs/agent-improvements/candidates/*)
    case "$CANDIDATE" in
      *".."*) echo "후보 경로에는 상위 디렉터리를 사용할 수 없습니다." >&2; exit 2 ;;
    esac
    ;;
  *) echo "candidates 경로의 파일만 결정할 수 있습니다." >&2; exit 2 ;;
esac

DEST_DIR="docs/agent-improvements/${STATUS}"
mkdir -p "$DEST_DIR"
DEST="$DEST_DIR/$(basename "$CANDIDATE")"
if [ -e "$DEST" ]; then
  echo "결정 대상이 이미 존재합니다: $DEST" >&2
  exit 1
fi

TEMP_FILE="$(mktemp)"
awk -v status="$STATUS" -v decider="$DECIDER" -v reason="$REASON" '
  /^- 상태: candidate$/ { print "- 상태: " status; next }
  /^- 결정: 대기$/ { print "- 결정: " status; next }
  /^- 결정자: \.\.\.$/ { print "- 결정자: " decider; next }
  /^- 사유: \.\.\.$/ { print "- 사유: " reason; next }
  { print }
' "$CANDIDATE" > "$TEMP_FILE"
mv "$TEMP_FILE" "$CANDIDATE"
mv "$CANDIDATE" "$DEST"
echo "개선 후보 ${STATUS}: $DEST"
