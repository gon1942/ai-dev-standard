#!/usr/bin/env bash
# 배포 템플릿이 원본 이력 없이 재현 가능하게 만들어지는지 검증한다.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
TARGET="$TMP_ROOT/template"
NONEMPTY="$TMP_ROOT/nonempty"
trap 'rm -rf -- "$TMP_ROOT"' EXIT

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

require_file() {
  [ -f "$1" ] || fail "필수 파일이 없습니다: $1"
}

bash "$ROOT/scripts/build-framework-template.sh" --output "$TARGET" >/dev/null

"$TARGET/scripts/check-framework.sh" --project-dir "$TARGET" >/dev/null
grep -Fxq 'AI_DEV_STANDARD_MODE=template' "$TARGET/.ai-dev-standard.env" || fail '배포 템플릿이 template 모드가 아닙니다'

for path in \
  AGENTS.md \
  CLAUDE.md \
  ARCHITECTURE.md \
  CONTRIBUTING.md \
  README.md \
  docs/framework-manifest.md \
  docs/project-constitution.md \
  docs/skill-contracts/standard-plan.md \
  docs/generated/README.md \
  docs/references/README.md \
  .opencode/agents/reviewer.md \
  .opencode/skills/apply-existing-project/SKILL.md \
  .opencode/skills/project-bootstrap/SKILL.md \
  .opencode/skills/project-preflight/SKILL.md \
  .claude/settings.json \
  .claude/commands/task-record.md \
  .claude/skills/apply-existing-project/SKILL.md \
  .claude/skills/project-bootstrap/SKILL.md \
  .claude/skills/project-preflight/SKILL.md \
  docs/exec-plans/active/.gitkeep \
  docs/exec-plans/completed/.gitkeep \
  docs/agent-improvements/candidates/.gitkeep; do
  require_file "$TARGET/$path"
done

grep -Fq 'Session Preflight' "$TARGET/docs/development-workflow.md" || fail '축약된 workflow 문서가 배포되었습니다'
grep -Fq '공통 개발 프레임워크가 적용되어 있다' "$TARGET/README.md" || fail '프로젝트용 README가 없습니다'

for forbidden in \
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
  [ ! -e "$TARGET/$forbidden" ] || fail "원본 또는 로컬 자산이 배포되었습니다: $forbidden"
done

if find "$TARGET/docs/product-specs" -maxdepth 1 -type f ! -name index.md -print -quit | grep -q .; then
  fail '원본 Product Spec 이력이 배포되었습니다'
fi
if find "$TARGET/docs/exec-plans/active" -maxdepth 1 -type f ! -name .gitkeep -print -quit | grep -q .; then
  fail '원본 활성 Exec Plan 이력이 배포되었습니다'
fi
if find "$TARGET/docs/exec-plans/completed" -maxdepth 1 -type f ! -name .gitkeep -print -quit | grep -q .; then
  fail '원본 완료 Exec Plan 이력이 배포되었습니다'
fi

while IFS= read -r source_file; do
  relative_path="${source_file#"$ROOT/"}"
  require_file "$TARGET/$relative_path"
done < <(find "$ROOT/.opencode/skills" "$ROOT/.claude/skills" -type f -name SKILL.md | sort)

absolute_path_matches="$(grep -R -n -F -- "$ROOT" "$TARGET" || true)"
if [ -n "$absolute_path_matches" ]; then
  printf '%s\n' "$absolute_path_matches" >&2
  fail '배포 템플릿에 원본 저장소 절대 경로가 남아 있습니다'
fi

# 배포된 전역 hook은 개발자의 원본 경로가 아니라 적용된 프로젝트 내부 runner를
# 사용해야 한다. 여기서는 전역 원본 경로 환경값 없이 실제로 Session Preflight를
# 실행해 그 동작을 확인한다.
(
  unset AI_DEV_STANDARD_ROOT
  cd "$TARGET"
  bash global-hooks/session-start.sh
) > "$TMP_ROOT/session-hook-output"
grep -Fq 'AI Dev Standard Session Preflight completed:' "$TMP_ROOT/session-hook-output" || \
  fail '배포 템플릿의 Session hook이 프로젝트 내부 Preflight를 실행하지 못했습니다'
[ -f "$TARGET/.ai-dev-standard/session-preflight.json" ] || \
  fail '배포 템플릿의 Session hook이 세션 검사 결과를 기록하지 못했습니다'

mkdir "$NONEMPTY"
: > "$NONEMPTY/existing-file"
if bash "$ROOT/scripts/build-framework-template.sh" --output "$NONEMPTY" >/dev/null 2>&1; then
  fail '비어 있지 않은 출력 경로를 덮어썼습니다'
fi
[ -f "$NONEMPTY/existing-file" ] || fail '출력 경로 보호 중 기존 파일이 사라졌습니다'

echo 'PASS: distribution template is clean, complete, and protected'
