#!/usr/bin/env bash
# 에이전트 세션 시작 시 Preflight를 실행하고 이후 작업에서 상태만 조회한다.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# 전역 SessionStart hook은 원본 프레임워크를 템플릿 공급원으로 전달한다.
# 대상 프로젝트 자체가 완전하면 이 값 없이 대상 안의 공통 엔진을 사용한다.
FRAMEWORK_ROOT="${AI_DEV_STANDARD_FRAMEWORK_ROOT:-$ROOT}"
PROJECT_DIR="$(pwd)"
MODE="start"

usage() {
  echo "사용법: scripts/session-preflight.sh [--project-dir <프로젝트경로>] [--start|--status]" >&2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --project-dir) [ -n "${2:-}" ] || { usage; exit 2; }; PROJECT_DIR="$2"; shift 2 ;;
    --start) MODE="start"; shift ;;
    --status) MODE="status"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage; exit 2 ;;
  esac
done

case "$MODE" in
  start)
    exec "$FRAMEWORK_ROOT/scripts/project-preflight.sh" --project-dir "$PROJECT_DIR" --repair --write-report --write-session
    ;;
  status)
    exec "$FRAMEWORK_ROOT/scripts/project-preflight.sh" --project-dir "$PROJECT_DIR" --session-status
    ;;
esac
