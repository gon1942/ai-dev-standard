#!/usr/bin/env bash
# Codex/Claude 전역 SessionStart hook. 프레임워크가 있는 프로젝트만 안전하게 검사한다.
set -uo pipefail

PROJECT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SESSION_SCRIPT="$PROJECT_DIR/scripts/session-preflight.sh"
# 전역 설치기는 AI_DEV_STANDARD_ROOT로 지속 경로의 원본을 명시한다. 프로젝트에
# 포함된 hook은 이 값이 없어도 프로젝트 내부 runner만 사용해야 하며, 개발자 로컬
# 절대 경로를 기본값으로 둘 수 없다.
FRAMEWORK_ROOT="${AI_DEV_STANDARD_ROOT:-$PROJECT_DIR}"

if [ ! -x "$SESSION_SCRIPT" ] && [ ! -f "$PROJECT_DIR/.ai-dev-standard.env" ]; then
  printf '%s\n' "AI Dev Standard: framework not applied at $PROJECT_DIR. Analyze first and propose framework application; do not modify existing files without approval."
  exit 0
fi

RUNNER="$SESSION_SCRIPT"
if [ -n "${AI_DEV_STANDARD_ROOT:-}" ] && [ -x "$FRAMEWORK_ROOT/scripts/session-preflight.sh" ]; then
  # 전역 원본을 실행해, 대상의 일부 template/docs가 삭제된 경우에도 안전하게 복구한다.
  RUNNER="$FRAMEWORK_ROOT/scripts/session-preflight.sh"
fi

if [ ! -x "$RUNNER" ]; then
  printf '%s\n' "AI Dev Standard Session Preflight is BLOCKED. session-preflight.sh가 없으므로 프레임워크 원본 또는 대상 골격을 복구해야 합니다."
  exit 0
fi

if AI_DEV_STANDARD_FRAMEWORK_ROOT="$FRAMEWORK_ROOT" "$RUNNER" --project-dir "$PROJECT_DIR" --start >/dev/null 2>&1; then
  status="$(AI_DEV_STANDARD_FRAMEWORK_ROOT="$FRAMEWORK_ROOT" "$RUNNER" --project-dir "$PROJECT_DIR" --status 2>/dev/null || true)"
  printf '%s\n' "AI Dev Standard Session Preflight completed: $status"
else
  printf '%s\n' "AI Dev Standard Session Preflight is BLOCKED. Read .ai-dev-standard/session-preflight.json and resolve the reported issue before Plan or Coding."
fi
