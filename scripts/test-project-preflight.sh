#!/usr/bin/env bash
# Project Preflight의 핵심 정상·복구·차단 시나리오 회귀 테스트.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

assert_contains() {
  local needle="$1" file="$2"
  grep -Fq "$needle" "$file" || { echo "FAIL: '$needle' 없음: $file" >&2; exit 1; }
}

bootstrap() {
  "$ROOT/scripts/bootstrap-framework.sh" --project-dir "$1" --init >/dev/null
}

# T2, T3, T5, T6, T8, T11: Node 프로젝트의 안전 복구·보존·반복·PASS.
node_project="$TMP_ROOT/node"
mkdir -p "$node_project"
printf '%s\n' '# Existing rule' 'preserve-this-line' > "$node_project/AGENTS.md"
printf '%s\n' '{"name":"fixture","scripts":{"test":"node --version"}}' > "$node_project/package.json"
printf '%s\n' '{}' > "$node_project/package-lock.json"
"$ROOT/scripts/project-preflight.sh" --project-dir "$node_project" --repair --write-report >/dev/null
assert_contains 'preserve-this-line' "$node_project/AGENTS.md"
bootstrap "$node_project" # 두 번째 초기화도 기존 파일을 덮어쓰지 않아야 한다.
sed -i 's/^AI_DEV_STANDARD_MODE=.*/AI_DEV_STANDARD_MODE=active/' "$node_project/.ai-dev-standard.env"
sed -i 's/^AI_DEV_STANDARD_REQUIRE_LINT=.*/AI_DEV_STANDARD_REQUIRE_LINT=false/' "$node_project/.ai-dev-standard.env"
sed -i 's/^AI_DEV_STANDARD_REQUIRE_TEST=.*/AI_DEV_STANDARD_REQUIRE_TEST=false/' "$node_project/.ai-dev-standard.env"

# active 모드에는 Git 저장소가 필요하다 — .git 없으면 BLOCK되고 안내 문구가 보고돼야 한다.
if "$ROOT/scripts/project-preflight.sh" --project-dir "$node_project" --run-checks --format json > "$node_project/nogit.json" 2>/dev/null; then
  echo 'FAIL: active 모드에서 Git 저장소 없이 통과함' >&2
  exit 1
fi
grep -Fq 'Git 저장소가 필요합니다' "$node_project/nogit.json" || { echo 'FAIL: Git 필수 BLOCK 문구 없음' >&2; exit 1; }

# git 초기화 후에는 통과해야 한다 (지문 재사용·diff 리뷰 전제 확보).
git -C "$node_project" init -q
git -C "$node_project" add -A
git -C "$node_project" -c user.name='framework-test' -c user.email='framework-test@example.invalid' commit -qm 'fixture: active 사전 조건'
if ! "$ROOT/scripts/project-preflight.sh" --project-dir "$node_project" --run-checks --format json > "$node_project/first.json"; then
  (cd "$node_project" && bash scripts/verify.sh) >&2 || true
  cat "$node_project/first.json" >&2
  exit 1
fi
assert_contains '"verdict": "PASS"' "$node_project/first.json"
assert_contains '"can_plan": true' "$node_project/first.json"
assert_contains '"can_code": true' "$node_project/first.json"
# 세션 시작 결과는 로컬 캐시에 저장되고, 작업 요청에서는 재검사 없이 상태만 확인한다.
"$ROOT/scripts/session-preflight.sh" --project-dir "$node_project" --start >/dev/null
[ -f "$node_project/.ai-dev-standard/session-preflight.json" ] || { echo 'FAIL: 세션 캐시 없음' >&2; exit 1; }
"$ROOT/scripts/session-preflight.sh" --project-dir "$node_project" --status > "$node_project/session.json"
assert_contains '"verdict": "PASS"' "$node_project/session.json"
printf '%s\n' '# fingerprint change' >> "$node_project/.ai-dev-standard.env"
if "$ROOT/scripts/session-preflight.sh" --project-dir "$node_project" --status > "$node_project/stale.json"; then
  echo 'FAIL: 지문 변경 뒤 세션 캐시가 무효화되지 않음' >&2
  exit 1
fi
assert_contains '"session_status":"stale"' "$node_project/stale.json"
sed -i '/^# fingerprint change$/d' "$node_project/.ai-dev-standard.env"
"$ROOT/scripts/project-preflight.sh" --project-dir "$node_project" --write-report >/dev/null
first_hash="$(sha256sum "$node_project/docs/generated/project-preflight.md" "$node_project/docs/generated/project-preflight.json")"
"$ROOT/scripts/project-preflight.sh" --project-dir "$node_project" --write-report >/dev/null
second_hash="$(sha256sum "$node_project/docs/generated/project-preflight.md" "$node_project/docs/generated/project-preflight.json")"
[ "$first_hash" = "$second_hash" ] || { echo 'FAIL: 반복 실행이 보고서를 불필요하게 변경함' >&2; exit 1; }

# T7: Python 신호를 감지한다.
python_project="$TMP_ROOT/python"
mkdir -p "$python_project"
printf '%s\n' '[project]' 'name = "fixture"' 'version = "0.1.0"' > "$python_project/pyproject.toml"
"$ROOT/scripts/project-preflight.sh" --project-dir "$python_project" --repair --format json > "$python_project/result.json"
assert_contains 'Python' "$python_project/result.json"

# T4, T12: 손상된 package.json은 BLOCK이며 Plan 진입도 차단한다.
invalid_project="$TMP_ROOT/invalid-json"
mkdir -p "$invalid_project"
printf '%s\n' '{ invalid json' > "$invalid_project/package.json"
if "$ROOT/scripts/project-preflight.sh" --project-dir "$invalid_project" --repair --format json > "$invalid_project/result.json"; then
  echo 'FAIL: 손상된 package.json이 BLOCK되지 않음' >&2
  exit 1
fi
assert_contains 'package.json 구문 오류' "$invalid_project/result.json"
assert_contains '"can_plan": false' "$invalid_project/result.json"

# T9: 필수 환경 설정 오류는 BLOCK이다.
bad_env_project="$TMP_ROOT/bad-env"
mkdir -p "$bad_env_project"
bootstrap "$bad_env_project"
sed -i 's/^AI_DEV_STANDARD_MODE=.*/AI_DEV_STANDARD_MODE=invalid/' "$bad_env_project/.ai-dev-standard.env"
if "$ROOT/scripts/project-preflight.sh" --project-dir "$bad_env_project" --format json > "$bad_env_project/result.json"; then
  echo 'FAIL: 잘못된 환경 설정이 BLOCK되지 않음' >&2
  exit 1
fi
assert_contains 'AI_DEV_STANDARD_MODE 값이 유효하지 않음' "$bad_env_project/result.json"

# T10: 기술 스택을 알 수 없는 빈 프로젝트는 추정 생성 없이 WARNING이다.
empty_project="$TMP_ROOT/empty"
mkdir -p "$empty_project"
"$ROOT/scripts/project-preflight.sh" --project-dir "$empty_project" --repair --format json > "$empty_project/result.json"
assert_contains '"verdict": "WARNING"' "$empty_project/result.json"
assert_contains '기술 스택 신호가 없어' "$empty_project/result.json"

# 전역 SessionStart는 손상된 대상의 로컬 script가 아니라 원본 프레임워크를 템플릿 공급원으로 쓴다.
damaged_project="$TMP_ROOT/damaged-session"
mkdir -p "$damaged_project"
bootstrap "$damaged_project"
rm -f "$damaged_project/AGENTS.md"
rm -rf "$damaged_project/docs"
AI_DEV_STANDARD_FRAMEWORK_ROOT="$ROOT" "$damaged_project/scripts/session-preflight.sh" --project-dir "$damaged_project" --start >/dev/null
[ -f "$damaged_project/AGENTS.md" ] || { echo 'FAIL: 전역 원본으로 AGENTS.md를 복구하지 못함' >&2; exit 1; }
[ -f "$damaged_project/docs/framework-manifest.md" ] || { echo 'FAIL: 전역 원본으로 docs를 복구하지 못함' >&2; exit 1; }

# 프레임워크가 적용되지 않은 Git 프로젝트에서는 작업 상태 복원을 시도하지 않는다.
unapplied_project="$TMP_ROOT/unapplied-session"
mkdir -p "$unapplied_project"
git -C "$unapplied_project" init -q
(
  cd "$unapplied_project"
  AI_DEV_STANDARD_ROOT="$ROOT" bash "$ROOT/global-hooks/session-start.sh"
) > "$unapplied_project/session-hook-output"
assert_contains 'AI Dev Standard: framework not applied' "$unapplied_project/session-hook-output"
if grep -Fq '# Work Status (Session Restore)' "$unapplied_project/session-hook-output"; then
  echo 'FAIL: 미적용 프로젝트에서 Session hook이 work-status를 실행했습니다' >&2
  exit 1
fi

# 전역 프레임워크 원본 경로가 지정돼도 work-status는 현재 프로젝트를 대상으로 해야 한다.
applied_project="$TMP_ROOT/applied-session"
mkdir -p "$applied_project"
bootstrap "$applied_project"
(
  cd "$applied_project"
  AI_DEV_STANDARD_ROOT="$ROOT" bash "$ROOT/global-hooks/session-start.sh"
) > "$applied_project/session-hook-output"
assert_contains "대상: $applied_project" "$applied_project/session-hook-output"
assert_contains '## 활성 작업 (docs/exec-plans/active/)' "$applied_project/session-hook-output"
if grep -Fq "대상: $ROOT" "$applied_project/session-hook-output" || \
  grep -Fq '2026-10-19-global-session-hooks.md' "$applied_project/session-hook-output"; then
  echo 'FAIL: Session hook의 work-status가 프로젝트가 아닌 프레임워크 저장소를 대상으로 했습니다' >&2
  exit 1
fi
(
  cd "$applied_project"
  AI_DEV_STANDARD_FRAMEWORK_ROOT="$ROOT" bash "$ROOT/global-hooks/session-start.sh"
) > "$applied_project/session-hook-new-root-output"
assert_contains "대상: $applied_project" "$applied_project/session-hook-new-root-output"
if grep -Fq "대상: $ROOT" "$applied_project/session-hook-new-root-output" || \
  grep -Fq '2026-10-19-global-session-hooks.md' "$applied_project/session-hook-new-root-output"; then
  echo 'FAIL: 새 환경변수 경로에서도 work-status가 프레임워크 저장소를 대상으로 했습니다' >&2
  exit 1
fi

echo 'PASS: Project Preflight scenarios (T2-T12 + damaged SessionStart recovery; T1은 Node active PASS로 포함)'
