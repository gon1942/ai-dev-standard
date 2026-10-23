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
  docs/project-bootstrap.md \
  docs/project-constitution.md \
  docs/skill-contracts/standard-plan.md \
  docs/skill-contracts/standard-human-decision.md \
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
  scripts/lib/commands/record-verification-evidence.js \
  scripts/record-verification-evidence.sh \
  scripts/lib/evidence.js \
  scripts/lib/e2e.js \
  scripts/lib/e2e-profile.js \
  scripts/lib/commands/record-e2e-evidence.js \
  scripts/record-e2e-evidence.sh \
  scripts/lib/commands/configure-e2e-profile.js \
  scripts/configure-e2e-profile.sh \
  docs/exec-plans/active/.gitkeep \
  docs/exec-plans/completed/.gitkeep \
  docs/agent-improvements/candidates/.gitkeep; do
  require_file "$TARGET/$path"
done

grep -Fq 'Session Preflight' "$TARGET/docs/development-workflow.md" || fail '축약된 workflow 문서가 배포되었습니다'
grep -Fq '공통 개발 프레임워크가 적용되어 있다' "$TARGET/README.md" || fail '프로젝트용 README가 없습니다'
grep -Fq '빈 프로젝트에서 사용자가 “로그인 페이지를 만들어줘”' "$TARGET/docs/project-bootstrap.md" || \
  fail '빈 프로젝트에서 스택 미지정 시 확인/제안 규칙이 배포되지 않았습니다'
grep -Fq 'record-bootstrap-approval' "$TARGET/docs/skill-contracts/standard-human-decision.md" || \
  fail 'Bootstrap 승인 내용 지문 절차가 배포되지 않았습니다'
grep -Fq 'bootstrap-status.json' "$TARGET/docs/session-preflight.md" || \
  fail 'Bootstrap 재개 상태 안내가 배포되지 않았습니다'
grep -Fq '전환 누락: <건수 또는 없음>' "$TARGET/docs/development-workflow.md" || \
  fail '배포 템플릿에 상태 보고 분류가 없습니다'
grep -Fq '`승인 대기`는 `work-status`에서 `READY_FOR_REVIEW`로 분류된 계획만 의미한다' \
  "$TARGET/docs/development-workflow.md" || fail '배포 템플릿에 승인 대기 의미 규칙이 없습니다'
grep -Fq 'node scripts/lib/cli.js work-status' "$TARGET/CLAUDE.md" || \
  fail '배포 템플릿의 Claude 어댑터에 work-status 실행 규칙이 없습니다'
grep -Fq 'node scripts/lib/cli.js work-status' "$TARGET/.claude/skills/project-preflight/SKILL.md" || \
  fail '배포 템플릿의 Claude Preflight 스킬에 work-status 실행 규칙이 없습니다'
node -e '
  const settings = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
  const allow = settings.permissions?.allow || [];
  if (!allow.includes("Bash(node scripts/lib/cli.js work-status)")) process.exit(1);
  if (!allow.includes("Bash(node scripts/lib/cli.js record-verification-evidence*)")) process.exit(1);
  if (!allow.includes("Bash(node scripts/lib/cli.js record-e2e-evidence*)")) process.exit(1);
' "$TARGET/.claude/settings.json" || fail '배포 템플릿의 Claude Node 실행 권한이 없습니다'
grep -Fq 'node scripts/lib/cli.js record-verification-evidence' "$TARGET/.claude/commands/verify.md" || \
  fail '배포 템플릿의 Claude Verify 명령이 Node 진입점을 사용하지 않습니다'
grep -Fq 'node scripts/lib/cli.js record-e2e-evidence' "$TARGET/.claude/commands/verify.md" || \
  fail '배포 템플릿의 Claude Verify 명령에 E2E 증거 경로가 없습니다'

# 원본은 개발 중인 작업 기록을 로컬에만 두지만, 설치 프로젝트는 팀의 작업 상태를
# 공유해야 한다. 두 .gitignore 정책이 섞이지 않았는지 확인한다.
git -C "$ROOT" check-ignore -q --no-index docs/product-specs/source-record.md || \
  fail '원본 저장소의 작업 기록 제외 정책이 사라졌습니다'
# 실제 팀 프로젝트처럼 Git 저장소를 초기화한 뒤 ignore 정책을 확인한다.
git -C "$TARGET" init -q
for work_record in \
  docs/product-specs/project-record.md \
  docs/exec-plans/active/project-record.md \
  docs/exec-plans/completed/project-record.md; do
  if git -C "$TARGET" check-ignore -q "$work_record"; then
    fail "설치 프로젝트의 공식 작업 기록이 Git에서 제외됩니다: $work_record"
  fi
done
for local_only in .env node_modules/package/index.js .ai-dev-standard/session-preflight.json; do
  git -C "$TARGET" check-ignore -q "$local_only" || \
    fail "설치 프로젝트의 로컬 전용 파일이 Git에서 추적됩니다: $local_only"
done

while IFS= read -r forbidden; do
  case "$forbidden" in ''|'#'*) continue ;; esac
  [ ! -e "$TARGET/$forbidden" ] || fail "원본 또는 로컬 자산이 배포되었습니다: $forbidden"
done < "$ROOT/scripts/framework-template-excludes.txt"
if find "$TARGET/scripts" -maxdepth 1 -type f -name 'test-*.sh' -print -quit | grep -q .; then
  fail '원본 전용 회귀 테스트가 배포되었습니다'
fi

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
grep -Fq '# Work Status (Session Restore)' "$TMP_ROOT/session-hook-output" || \
  fail '배포 템플릿의 Session hook이 work-status를 실행하지 못했습니다'
[ -f "$TARGET/.ai-dev-standard/session-preflight.json" ] || \
  fail '배포 템플릿의 Session hook이 세션 검사 결과를 기록하지 못했습니다'

mkdir "$NONEMPTY"
: > "$NONEMPTY/existing-file"
if bash "$ROOT/scripts/build-framework-template.sh" --output "$NONEMPTY" >/dev/null 2>&1; then
  fail '비어 있지 않은 출력 경로를 덮어썼습니다'
fi
[ -f "$NONEMPTY/existing-file" ] || fail '출력 경로 보호 중 기존 파일이 사라졌습니다'

echo 'PASS: distribution template is clean, complete, and protected'
