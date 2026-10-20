#!/usr/bin/env bash
# 프레임워크 개발 원본에서 신규 프로젝트용 배포 템플릿을 만든다.
# 원본 작업 이력·세션 캐시·원본 전용 회귀 테스트는 포함하지 않는다.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT=""
STAGING=""

usage() {
  echo "사용법: scripts/build-framework-template.sh --output <존재하지 않는 출력 경로>" >&2
}

cleanup() {
  if [ -n "$STAGING" ] && [ -d "$STAGING" ]; then
    rm -rf -- "$STAGING"
  fi
}
trap cleanup EXIT

while [ "$#" -gt 0 ]; do
  case "$1" in
    --output)
      [ -n "${2:-}" ] || { usage; exit 2; }
      OUTPUT="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

[ -n "$OUTPUT" ] || { usage; exit 2; }

OUTPUT_PARENT="$(dirname "$OUTPUT")"
OUTPUT_NAME="$(basename "$OUTPUT")"
[ "$OUTPUT_NAME" != "." ] && [ "$OUTPUT_NAME" != ".." ] || {
  echo "출력 경로는 디렉터리 이름이어야 합니다: $OUTPUT" >&2
  exit 2
}
mkdir -p "$OUTPUT_PARENT"
OUTPUT_PARENT="$(cd "$OUTPUT_PARENT" && pwd)"
OUTPUT="$OUTPUT_PARENT/$OUTPUT_NAME"

if [ -e "$OUTPUT" ]; then
  echo "출력 경로가 이미 존재합니다. 기존 파일을 보호하기 위해 중단합니다: $OUTPUT" >&2
  exit 2
fi

STAGING="$(mktemp -d "$OUTPUT_PARENT/.ai-dev-standard-template.XXXXXX")"

# bootstrap은 선언된 runtime 자산과 공통 문서를 새 대상에만 복사한다.
"$ROOT/scripts/bootstrap-framework.sh" --project-dir "$STAGING" --init >/dev/null

# 원본 README는 프레임워크 개발 저장소 설명이다. 배포 대상에는 프로젝트 시작용 README를 둔다.
cp "$ROOT/templates/project/README.md" "$STAGING/README.md"
cp "$ROOT/.gitignore" "$STAGING/.gitignore"

# GitHub Template로 만든 저장소에서도 빈 공식 기록 영역이 유지되도록 한다.
for directory in \
  docs/exec-plans/active \
  docs/exec-plans/completed \
  docs/agent-improvements/candidates \
  docs/agent-improvements/approved \
  docs/agent-improvements/rejected; do
  mkdir -p "$STAGING/$directory"
  : > "$STAGING/$directory/.gitkeep"
done

# 이 목록은 원본 개발 저장소에만 있어야 한다. 혹시 Bootstrap 범위가 넓어져도 배포 전에 실패한다.
for excluded_path in \
  docs/generated/project-preflight.md \
  docs/generated/project-preflight.json \
  .ai-dev-standard/session-preflight.json \
  .opencode/node_modules \
  .opencode/package.json \
  .opencode/package-lock.json \
  scripts/test-framework.sh \
  scripts/test-framework-assets.sh \
  scripts/test-framework-template.sh \
  scripts/test-project-preflight.sh \
  scripts/test-review.sh \
  scripts/test-validate-plan.sh \
  scripts/test-plan-templates.sh; do
  if [ -e "$STAGING/$excluded_path" ]; then
    echo "배포 템플릿에 포함되면 안 되는 자산이 있습니다: $excluded_path" >&2
    exit 1
  fi
done

if find "$STAGING/docs/product-specs" -maxdepth 1 -type f ! -name index.md -print -quit | grep -q .; then
  echo "배포 템플릿에 원본 Product Spec 이력이 포함되었습니다." >&2
  exit 1
fi
if find "$STAGING/docs/exec-plans/active" -maxdepth 1 -type f ! -name .gitkeep -print -quit | grep -q .; then
  echo "배포 템플릿에 원본 활성 Exec Plan 이력이 포함되었습니다." >&2
  exit 1
fi
if find "$STAGING/docs/exec-plans/completed" -maxdepth 1 -type f ! -name .gitkeep -print -quit | grep -q .; then
  echo "배포 템플릿에 원본 완료 Exec Plan 이력이 포함되었습니다." >&2
  exit 1
fi

grep -Fxq 'AI_DEV_STANDARD_MODE=template' "$STAGING/.ai-dev-standard.env" || {
  echo "배포 템플릿은 template 모드여야 합니다." >&2
  exit 1
}
"$STAGING/scripts/check-framework.sh" --project-dir "$STAGING" >/dev/null

mv "$STAGING" "$OUTPUT"
STAGING=""
echo "배포 템플릿 생성: $OUTPUT"
