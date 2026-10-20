#!/usr/bin/env bash
# 프로젝트의 소스·설정·테스트 구조를 읽어 재생성 가능한 현황을 만든다.
set -euo pipefail

PROJECT_DIR="$(pwd)"
WRITE_REPORT=false

usage() {
  echo "사용법: scripts/analyze-project.sh [--project-dir <프로젝트경로>] [--write]" >&2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --project-dir)
      [ -n "${2:-}" ] || { usage; exit 2; }
      PROJECT_DIR="$2"
      shift 2
      ;;
    --write) WRITE_REPORT=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage; exit 2 ;;
  esac
done

if [ ! -d "$PROJECT_DIR" ]; then
  echo "프로젝트 경로가 없습니다: $PROJECT_DIR" >&2
  exit 2
fi
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

inventory() {
  echo "# Project Inventory (Generated)"
  echo ""
  echo '> 소스·설정에서 감지한 사실을 재생성한 문서다. 설계 결정은 `docs/design-docs/`에 기록한다.'
  echo ""
  printf -- '- 분석 경로: `%s`\n' "$PROJECT_DIR"
  echo "- 생성일: $(date '+%Y-%m-%d %H:%M:%S %z')"
  echo ""
  echo "## 감지된 기술 신호"
  found=false
  for item in "package.json:Node.js" "pyproject.toml:Python" "requirements.txt:Python requirements" "go.mod:Go" "Cargo.toml:Rust" "Dockerfile:Docker" "docker-compose.yml:Docker Compose"; do
    file="${item%%:*}"
    label="${item#*:}"
    if [ -f "$PROJECT_DIR/$file" ]; then
      printf -- '- %s: `%s`\n' "$label" "$file"
      found=true
    fi
  done
  "$found" || echo "- 감지된 언어·빌드 설정 없음 — 신규 프로젝트 프로필 질문 필요"
  echo ""
  echo "## 감지된 디렉터리"
  found=false
  for dir in src app lib server client web frontend backend test tests e2e public; do
    if [ -d "$PROJECT_DIR/$dir" ]; then
      printf -- '- `%s/`\n' "$dir"
      found=true
    fi
  done
  "$found" || echo "- 감지된 소스·테스트 디렉터리 없음"
  echo ""
  echo "## 실행 명령 후보"
  if [ -f "$PROJECT_DIR/package.json" ]; then
    echo "- package.json scripts:"
    sed -n '/"scripts"[[:space:]]*:/,/^[[:space:]]*}[,]*[[:space:]]*$/p' "$PROJECT_DIR/package.json" \
      | grep -E '"[^"]+"[[:space:]]*:' \
      | sed 's/^/  - /' || echo "  - 감지하지 못함"
  else
    echo "- 프로젝트별 build/lint/test 명령 확인 필요"
  fi
  echo ""
  echo "## 프로젝트 문서 상태"
  for file in AGENTS.md ARCHITECTURE.md docs/design-docs/project-context.md docs/testing-policy.md; do
    if [ -f "$PROJECT_DIR/$file" ]; then
      printf -- '- 존재: `%s`\n' "$file"
    else
      printf -- '- 누락: `%s`\n' "$file"
    fi
  done
  echo ""
  echo "## 에이전트 다음 조치"
  if [ ! -f "$PROJECT_DIR/package.json" ] && [ ! -f "$PROJECT_DIR/pyproject.toml" ] && [ ! -f "$PROJECT_DIR/go.mod" ] && [ ! -f "$PROJECT_DIR/Cargo.toml" ]; then
    echo "- 신규 프로젝트로 보임: 목적, 사용자 흐름, 기술 스택, 데이터·인증, 검증 방식을 사용자에게 질문한다."
  else
    echo "- 기존 프로젝트로 보임: 소스 구조와 기존 문서를 비교해 누락 문서는 생성하고, 사실과 어긋난 프로젝트 문서 갱신안을 만든다."
  fi
  echo "- 공통 정책·보안·검증 규칙은 소스 분석만으로 수정하지 않는다."
}

if [ "$WRITE_REPORT" = true ]; then
  mkdir -p "$PROJECT_DIR/docs/generated"
  tempFile="$(mktemp)"
  inventory > "$tempFile"
  mv "$tempFile" "$PROJECT_DIR/docs/generated/project-inventory.md"
  echo "프로젝트 현황 생성: $PROJECT_DIR/docs/generated/project-inventory.md"
else
  inventory
fi
