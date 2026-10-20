#!/usr/bin/env bash
# 공통 프레임워크의 필수 골격을 읽기 전용으로 검사한다.
set -euo pipefail

SCRIPT_ROOT="$(cd "$(dirname "$0")" && pwd)"
ASSET_CATALOG="$SCRIPT_ROOT/../docs/framework-runtime-assets.tsv"
PROJECT_DIR="."
if [ "${1:-}" = "--project-dir" ] && [ -n "${2:-}" ] && [ "$#" -eq 2 ]; then
  PROJECT_DIR="$2"
elif [ "$#" -ne 0 ]; then
  echo "사용법: scripts/check-framework.sh [--project-dir <프로젝트경로>]" >&2
  exit 2
fi

if [ ! -d "$PROJECT_DIR" ]; then
  echo "프로젝트 경로가 없습니다: $PROJECT_DIR" >&2
  exit 2
fi

requiredFiles=(
  "AGENTS.md"
  "ARCHITECTURE.md"
  "docs/development-workflow.md"
  "docs/definition-of-done.md"
  "docs/coding-standards.md"
  "docs/testing-policy.md"
  "docs/framework-onboarding.md"
  "docs/framework-manifest.md"
  "docs/framework-runtime-assets.tsv"
  "docs/project-bootstrap.md"
  "docs/project-preflight.md"
  "docs/session-preflight.md"
  "docs/global-session-hooks.md"
  "docs/skill-contracts/standard-plan.md"
  "docs/skill-contracts/standard-implement.md"
  "docs/skill-contracts/standard-verify.md"
  "docs/skill-contracts/standard-review.md"
  "docs/skill-contracts/standard-improve.md"
  "docs/project-constitution.md"
  "docs/design-docs/project-context.md"
  ".ai-dev-standard.env"
)
requiredDirs=(
  "docs/product-specs"
  "docs/exec-plans/active"
  "docs/exec-plans/completed"
  "docs/design-docs"
  "docs/agent-improvements/candidates"
  "docs/agent-improvements/approved"
  "docs/agent-improvements/rejected"
)

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

catalog_error=0
if [ -f "$ASSET_CATALOG" ]; then
  while IFS=$'\t' read -r scope path _description; do
    case "$scope" in
      ''|'#'*) ;;
      target-script|target-hook)
        if is_safe_runtime_asset_path "$path"; then
          requiredFiles+=("$path")
        else
          echo "FAIL catalog: 허용되지 않은 실행 자산 경로: $path" >&2
          catalog_error=1
        fi
        ;;
      repository-test) ;;
      *) echo "FAIL catalog: 알 수 없는 실행 자산 범위: $scope" >&2; catalog_error=1 ;;
    esac
  done < "$ASSET_CATALOG"
fi

missing="$catalog_error"
echo "=== AI Dev Standard 골격 검사: $PROJECT_DIR ==="
for file in "${requiredFiles[@]}"; do
  if [ -f "$PROJECT_DIR/$file" ]; then
    echo "PASS file: $file"
  else
    echo "FAIL file: $file"
    missing=1
  fi
done
for dir in "${requiredDirs[@]}"; do
  if [ -d "$PROJECT_DIR/$dir" ]; then
    echo "PASS dir:  $dir/"
  else
    echo "FAIL dir:  $dir/"
    missing=1
  fi
done

if [ -f "$PROJECT_DIR/.ai-dev-standard.env" ]; then
  if grep -Eq '^AI_DEV_STANDARD_MODE=(template|active)$' "$PROJECT_DIR/.ai-dev-standard.env"; then
    echo "PASS config: AI_DEV_STANDARD_MODE 설정됨"
  else
    echo "FAIL config: AI_DEV_STANDARD_MODE=template 또는 active 필요"
    missing=1
  fi
fi

if [ "$missing" -ne 0 ]; then
  echo "RESULT: FAIL — 누락 항목은 scripts/bootstrap-framework.sh --init으로 생성 후보를 확인하세요." >&2
  exit 1
fi

echo "RESULT: PASS — 필수 골격이 있습니다. 프로젝트별 설정은 분석·승인 절차로 확인하세요."
