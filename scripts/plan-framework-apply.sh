#!/usr/bin/env bash
# 기존 프로젝트에 프레임워크를 적용하기 전, 변경 없이 적용 분류 보고서를 만든다.
set -euo pipefail

FRAMEWORK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_DIR="$(pwd)"
WRITE_REPORT=false

usage() {
  echo "사용법: scripts/plan-framework-apply.sh [--project-dir <프로젝트경로>] [--write]" >&2
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

state_for() {
  local path="$1"
  local default="$2"
  if [ -e "$PROJECT_DIR/$path" ]; then
    case "$default" in
      생성) printf '보존 또는 병합 제안' ;;
      *) printf '%s' "$default" ;;
    esac
  else
    printf '%s' "$default"
  fi
}

is_safe_runtime_asset_path() {
  local path="$1"
  case "$path" in
    scripts/*|global-hooks/*) ;;
    *) return 1 ;;
  esac
  case "/$path/" in
    *'/../'*|*'/./'*|*'//'*) return 1 ;;
  esac
}

report() {
  echo "# Framework Apply Plan (Generated)"
  echo ""
  echo "> 읽기 전용 분석 보고서다. 적용 규칙의 SSOT는 docs/framework-manifest.md다."
  echo ""
  printf -- '- 프레임워크 원본: `%s`\n' "$FRAMEWORK_ROOT"
  printf -- '- 대상 프로젝트: `%s`\n' "$PROJECT_DIR"
  echo ""
  echo "## 적용 분류"
  echo ""
  echo "| 자산 | 권장 처리 | 근거 |"
  echo "|---|---|---|"
  for item in \
    'docs/development-workflow.md|공통 작업 흐름' \
    'docs/definition-of-done.md|완료 기준' \
    'docs/coding-standards.md|코딩 표준' \
    'docs/testing-policy.md|테스트 정책' \
    'docs/framework-onboarding.md|온보딩 지침' \
    'docs/framework-manifest.md|적용 자산과 승인 경계' \
    'docs/framework-runtime-assets.tsv|기계용 실행 자산 목록' \
    'docs/global-session-hooks.md|선택형 전역 세션 hook 안내' \
    'docs/product-specs|제품 명세 기록 영역' \
    'docs/exec-plans/active|활성 실행 계획 영역' \
    'docs/exec-plans/completed|완료 실행 계획 영역' \
    'docs/design-docs|설계 문서 영역' \
    'docs/agent-improvements|개선 기록 영역' \
    'ARCHITECTURE.md|프로젝트 구조 지도' \
    'docs/design-docs/project-context.md|프로젝트 문맥' \
    '.ai-dev-standard.env|검증 모드 설정'; do
    path_name="${item%%|*}"
    label="${item#*|}"
    printf -- '| `%s` | %s | %s |\n' "$path_name" "$(state_for "$path_name" 생성)" "$label"
  done
  if [ -f "$FRAMEWORK_ROOT/docs/framework-runtime-assets.tsv" ]; then
    while IFS=$'\t' read -r scope path_name label; do
      case "$scope" in
        ''|'#'*|repository-test) ;;
        target-script|target-hook)
          if is_safe_runtime_asset_path "$path_name"; then
            printf -- '| `%s` | %s | %s |\n' "$path_name" "$(state_for "$path_name" 생성)" "$label"
          else
            printf -- '| `%s` | 확인 필요 | 허용되지 않은 실행 자산 경로 |\n' "$path_name"
          fi
          ;;
        *)
          printf -- '| `%s` | 확인 필요 | 알 수 없는 실행 자산 범위: %s |\n' "$path_name" "$scope"
          ;;
      esac
    done < "$FRAMEWORK_ROOT/docs/framework-runtime-assets.tsv"
  else
    echo '| `docs/framework-runtime-assets.tsv` | 확인 필요 | 프레임워크 원본의 실행 자산 목록이 없음 |'
  fi
  echo '| `AGENTS.md`, `CLAUDE.md`, 하위 지침 | 병합 제안 | 대상의 기존 규칙을 보존하고 참조만 최소 추가 |'
  echo '| `.opencode/`, `.claude/` | 병합 제안 | 기존 도구 설정을 보존하고 충돌 없는 어댑터만 제안 |'
  echo '| 소스·의존성·잠금 파일·CI/CD·배포 | 제외 | 이 적용 단계에서는 변경하지 않음 |'
  echo '| 작업 이력·세션 파일·빌드 산출물·원본 전용 회귀 테스트 | 제외 | 복사·변환·삭제하지 않음 |'
  echo ""
  echo "## 감지된 대상 지침"
  found=false
  while IFS= read -r file; do
    relative="${file#"$PROJECT_DIR"/}"
    printf -- '- `%s`\n' "$relative"
    found=true
  done < <(find "$PROJECT_DIR" \( -name AGENTS.md -o -name CLAUDE.md \) -type f -not -path '*/node_modules/*' -not -path '*/.git/*' | sort)
  "$found" || echo "- 없음 — 공통 진입점 생성 후보"
  echo ""
  echo "## 승인 전 사용자 확인 사항"
  echo ""
  echo "- 기존 지침 파일에 공통 흐름 참조를 추가해도 되는가?"
  echo "- 기존 lint/typecheck/test 명령 중 공통 검증에 연결할 명령은 무엇인가?"
  echo "- 구조 문서의 사실 갱신 범위와, 보존해야 할 기존 문서는 무엇인가?"
  echo ""
  echo "## 다음 단계"
  echo ""
  echo "- 이 보고서는 대상 파일을 바꾸지 않는다. 에이전트는 승인된 범위에서만 누락 골격 생성 또는 제안된 diff 반영을 수행한다."
}

if [ "$WRITE_REPORT" = true ]; then
  mkdir -p "$PROJECT_DIR/docs/generated"
  temp_file="$(mktemp)"
  report > "$temp_file"
  mv "$temp_file" "$PROJECT_DIR/docs/generated/framework-apply-plan.md"
  echo "프레임워크 적용 계획 생성: $PROJECT_DIR/docs/generated/framework-apply-plan.md"
else
  report
fi
