#!/usr/bin/env bash
# 신규·기존 프로젝트에 공통 프레임워크를 안전하게 온보딩한다.
set -euo pipefail

SCRIPT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ASSET_CATALOG="$SCRIPT_ROOT/docs/framework-runtime-assets.tsv"
TARGET_ROOT="$(pwd)"
MODE="analyze"

usage() {
  echo "사용법: scripts/bootstrap-framework.sh [--project-dir <프로젝트경로>] [--analyze|--init]" >&2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --project-dir)
      [ -n "${2:-}" ] || { usage; exit 2; }
      TARGET_ROOT="$2"
      shift 2
      ;;
    --analyze) MODE="analyze"; shift ;;
    --init) MODE="init"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage; exit 2 ;;
  esac
done

if [ ! -d "$TARGET_ROOT" ]; then
  echo "프로젝트 경로가 없습니다: $TARGET_ROOT" >&2
  exit 2
fi
TARGET_ROOT="$(cd "$TARGET_ROOT" && pwd)"

report() {
  "$SCRIPT_ROOT/scripts/analyze-project.sh" --project-dir "$TARGET_ROOT"
  echo ""
  "$SCRIPT_ROOT/scripts/check-framework.sh" --project-dir "$TARGET_ROOT" || true
}

write_if_missing() {
  local path="$1"
  if [ -e "$TARGET_ROOT/$path" ]; then
    echo "KEEP: $path"
    cat >/dev/null
    return
  fi
  mkdir -p "$(dirname "$TARGET_ROOT/$path")"
  cat > "$TARGET_ROOT/$path"
  case "$path" in scripts/*.sh) chmod +x "$TARGET_ROOT/$path" ;; esac
  echo "CREATE: $path"
}

copy_from_framework_if_missing() {
  local path="$1"
  if [ -e "$TARGET_ROOT/$path" ]; then
    echo "KEEP: $path"
    return
  fi
  if [ ! -f "$SCRIPT_ROOT/$path" ]; then
    echo "SKIP: $path (프레임워크 원본에 없음)" >&2
    return
  fi
  mkdir -p "$(dirname "$TARGET_ROOT/$path")"
  cp "$SCRIPT_ROOT/$path" "$TARGET_ROOT/$path"
  chmod +x "$TARGET_ROOT/$path"
  echo "CREATE: $path (프레임워크 원본 복사)"
}

copy_document_from_framework_if_missing() {
  local path="$1"
  if [ -e "$TARGET_ROOT/$path" ]; then
    echo "KEEP: $path"
    return
  fi
  if [ ! -f "$SCRIPT_ROOT/$path" ]; then
    echo "SKIP: $path (프레임워크 원본에 없음)" >&2
    return
  fi
  mkdir -p "$(dirname "$TARGET_ROOT/$path")"
  cp "$SCRIPT_ROOT/$path" "$TARGET_ROOT/$path"
  echo "CREATE: $path (프레임워크 원본 복사)"
}

copy_adapter_from_framework_if_missing() {
  local path="$1"
  if [ -e "$TARGET_ROOT/$path" ]; then
    echo "KEEP: $path"
    return
  fi
  if [ ! -f "$SCRIPT_ROOT/$path" ]; then
    echo "SKIP: $path (프레임워크 원본에 없음)" >&2
    return
  fi
  mkdir -p "$(dirname "$TARGET_ROOT/$path")"
  cp "$SCRIPT_ROOT/$path" "$TARGET_ROOT/$path"
  echo "CREATE: $path (도구 어댑터 복사)"
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

copy_runtime_assets() {
  if [ ! -f "$ASSET_CATALOG" ]; then
    echo "프레임워크 실행 자산 목록이 없습니다: $ASSET_CATALOG" >&2
    return 1
  fi

  while IFS=$'\t' read -r scope path _description; do
    case "$scope" in
      ''|'#'*) ;;
      target-script|target-hook)
        if ! is_safe_runtime_asset_path "$path"; then
          echo "허용되지 않은 실행 자산 경로: $path" >&2
          return 1
        fi
        copy_from_framework_if_missing "$path"
        ;;
      repository-test) ;;
      *)
        echo "알 수 없는 실행 자산 범위: $scope" >&2
        return 1
        ;;
    esac
  done < "$ASSET_CATALOG"
}

initialize() {
  echo "=== 안전한 골격 생성: $TARGET_ROOT ==="
  echo "기존 파일은 덮어쓰지 않습니다. 프로젝트 코드·의존성도 변경하지 않습니다."
  for dir in docs/product-specs docs/exec-plans/active docs/exec-plans/completed \
    docs/design-docs docs/agent-improvements/candidates docs/agent-improvements/approved \
    docs/agent-improvements/rejected docs/generated; do
    if [ -d "$TARGET_ROOT/$dir" ]; then
      echo "KEEP: $dir/"
    else
      mkdir -p "$TARGET_ROOT/$dir"
      echo "CREATE: $dir/"
    fi
  done

  write_if_missing ".ai-dev-standard.env" <<'EOF'
# 프로젝트 명령을 확인한 뒤 active로 전환한다.
AI_DEV_STANDARD_MODE=template
AI_DEV_STANDARD_REQUIRE_LINT=true
AI_DEV_STANDARD_REQUIRE_TYPECHECK=false
AI_DEV_STANDARD_REQUIRE_TEST=true
EOF

  # 새 프로젝트도 원본과 같은 공통 계약을 읽어야 한다. 기존 파일은 보존하므로,
  # 여기서는 없는 파일만 전체 문서·어댑터로 채운다.
  for document in \
    AGENTS.md \
    CLAUDE.md \
    ARCHITECTURE.md \
    CONTRIBUTING.md \
    docs/development-workflow.md \
    docs/definition-of-done.md \
    docs/coding-standards.md \
    docs/testing-policy.md \
    docs/framework-onboarding.md \
    docs/framework-manifest.md \
    docs/framework-runtime-assets.tsv \
    docs/project-bootstrap.md \
    docs/project-preflight.md \
    docs/session-preflight.md \
    docs/global-session-hooks.md \
    docs/project-constitution.md \
    docs/design-docs/project-context.md \
    docs/design-docs/index.md \
    docs/generated/README.md \
    docs/references/README.md \
    docs/product-specs/index.md \
    docs/agent-improvements/README.md; do
    copy_document_from_framework_if_missing "$document"
  done
  for contract in standard-plan.md standard-implement.md standard-orchestration.md standard-verify.md standard-uat.md standard-review.md standard-improve.md standard-human-decision.md; do
    copy_document_from_framework_if_missing "docs/skill-contracts/$contract"
  done
  copy_runtime_assets

  for tool in .opencode .claude .agents; do
    skill_root="$SCRIPT_ROOT/$tool/skills"
    if [ -d "$skill_root" ]; then
      while IFS= read -r source_file; do
        relative_path="${source_file#"$SCRIPT_ROOT/"}"
        copy_adapter_from_framework_if_missing "$relative_path"
      done < <(find "$skill_root" -type f -name SKILL.md | sort)
    fi
  done

  for adapter_file in .opencode/agents/reviewer.md .claude/settings.json \
    .claude/commands/task-record.md .claude/commands/verify.md; do
    copy_adapter_from_framework_if_missing "$adapter_file"
  done
  echo ""
  echo "다음 단계: 에이전트가 project-bootstrap 절차로 문맥 질문과 설계 문서 초안을 제안하고, 사용자 승인 후에만 기존 파일을 갱신합니다."
}

case "$MODE" in
  analyze) report ;;
  init) initialize ;;
esac
