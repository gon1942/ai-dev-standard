#!/usr/bin/env bash
# 프로젝트 분석으로 알 수 없는 문맥 질문만 정리한다.
set -euo pipefail

PROJECT_DIR="$(pwd)"
WRITE_REPORT=false

usage() {
  echo "사용법: scripts/prepare-project-context.sh [--project-dir <프로젝트경로>] [--write]" >&2
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

# Constitution 질문 스킵 판정 — 상태 행이 정확히 하나이고 값이 정확히 '확정'이며
# 필수 섹션이 모두 존재할 때만 스킵한다. 파일 없음·초안·상태 오염('확정 임시' 등)·
# 상태 행 중복·섹션 누락은 모두 질문을 제시한다.
constitution_confirmed() {
  local file="$PROJECT_DIR/docs/project-constitution.md"
  [ -f "$file" ] || return 1
  local status_count
  status_count="$(grep -Ec '^- 상태:' "$file" || true)"
  [ "$status_count" -eq 1 ] || return 1
  grep -Fxq -- '- 상태: 확정' "$file" || return 1
  local section
  for section in \
    '## 고위험 변경과 승인 경계' \
    '## 아키텍처 불변 조건' \
    '## 규제·컴플라이언스 요건' \
    '## 인증·권한·외부 연동 정책' \
    '## 데이터·프라이버시 정책' \
    '## 프로젝트별 필수 검증 수준' \
    '## 안티골 — 기술적으로 가능해도 하지 않을 것' \
    '## 미확정 결정·확정에 필요한 정보'; do
    grep -Fqx -- "$section" "$file" || return 1
  done
  return 0
}

report() {
  echo "# Project Context Intake (Generated)"
  echo ""
  echo "> 소스 분석으로 확정할 수 없는 정보만 묻기 위한 초안이다. 답변은 project-context·architecture·project-constitution 초안의 근거가 된다."
  echo ""
  printf -- '- 대상 프로젝트: `%s`\n' "$PROJECT_DIR"
  echo ""
  echo "## 분석으로 확인된 신호"
  found=false
  for file in package.json pyproject.toml go.mod Cargo.toml Dockerfile; do
    if [ -f "$PROJECT_DIR/$file" ]; then
      printf -- '- `%s` 존재\n' "$file"
      found=true
    fi
  done
  "$found" || echo "- 기술 스택 신호 없음"
  echo ""
  echo "## 사용자 확인 질문"
  echo ""
  if [ ! -f "$PROJECT_DIR/README.md" ]; then
    echo "1. 이 프로젝트가 해결할 문제와 주요 사용자는 누구인가?"
  else
    echo "1. README에 없는 제품 목적·성공 기준 또는 우선순위가 있는가?"
  fi
  needs_context=true
  if [ -f "$PROJECT_DIR/docs/design-docs/project-context.md" ] \
    && ! grep -Eq '^- 상태: 초안$|^- 미확정$' "$PROJECT_DIR/docs/design-docs/project-context.md"; then
    needs_context=false
  fi
  if [ "$needs_context" = true ]; then
    echo "2. 첫 번째 핵심 사용자 흐름과, 반드시 제외할 범위는 무엇인가?"
    echo "3. 도메인 용어, 권한 정책, 예외 규칙 중 먼저 확정할 것은 무엇인가?"
  fi
  if [ ! -f "$PROJECT_DIR/package.json" ] && [ ! -f "$PROJECT_DIR/pyproject.toml" ] && [ ! -f "$PROJECT_DIR/go.mod" ] && [ ! -f "$PROJECT_DIR/Cargo.toml" ]; then
    echo "4. 선호 기술 스택, 데이터 저장소, 인증 방식은 무엇인가?"
  else
    echo "4. 분석에서 발견되지 않은 데이터 저장소·인증·외부 서비스가 있는가?"
  fi
  echo "5. 브라우저 실측, 통합·성능·보안 검증 중 필수인 것은 무엇인가?"
  if ! constitution_confirmed; then
    echo "6. 사람 승인 없이 고칠 수 없는 고위험 영역과, 절대 바꾸지 않을 아키텍처 불변 조건은 무엇인가?"
    echo "7. 적용받는 규제·컴플라이언스 요건과 데이터·프라이버시 정책은 무엇인가?"
    echo "8. 기술적으로 가능해도 하지 않을 것(안티골)은 무엇인가? 이 프로젝트의 필수 검증 수준은?"
  fi
  echo ""
  echo "## LLM 작성 대상"
  echo ""
  echo "- ARCHITECTURE.md: 소스에서 확인된 구조 + 사용자 확정 결정"
  echo "- docs/design-docs/project-context.md: 목적·사용자 흐름·도메인·범위"
  echo "- docs/project-constitution.md: 고위험 경계·아키텍처 불변·규제·인증·프라이버시·검증 수준·안티골"
  echo "- 기존 파일은 변경 전 diff와 승인 필요"
}

if [ "$WRITE_REPORT" = true ]; then
  mkdir -p "$PROJECT_DIR/docs/generated"
  temp_file="$(mktemp)"
  report > "$temp_file"
  mv "$temp_file" "$PROJECT_DIR/docs/generated/project-context-intake.md"
  echo "프로젝트 문맥 입력 초안 생성: $PROJECT_DIR/docs/generated/project-context-intake.md"
else
  report
fi
