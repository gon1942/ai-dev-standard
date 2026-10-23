#!/usr/bin/env bash
# Plan 단계 전 공통 프로젝트 준비 상태를 분석·복구·판정한다.
set -uo pipefail

FRAMEWORK_ROOT="${AI_DEV_STANDARD_FRAMEWORK_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROJECT_DIR="$(pwd)"
FORMAT="markdown"
REPAIR=false
WRITE_REPORT=false
RUN_CHECKS=false
WRITE_SESSION=false
SESSION_STATUS=false

usage() {
  echo "사용법: scripts/project-preflight.sh [--project-dir <프로젝트경로>] [--repair] [--run-checks] [--format markdown|json] [--write-report] [--write-session|--session-status]" >&2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --project-dir) [ -n "${2:-}" ] || { usage; exit 2; }; PROJECT_DIR="$2"; shift 2 ;;
    --repair) REPAIR=true; shift ;;
    --run-checks) RUN_CHECKS=true; shift ;;
    --write-report) WRITE_REPORT=true; shift ;;
    --write-session) WRITE_SESSION=true; shift ;;
    --session-status) SESSION_STATUS=true; shift ;;
    --format)
      [ "${2:-}" = "markdown" ] || [ "${2:-}" = "json" ] || { usage; exit 2; }
      FORMAT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) usage; exit 2 ;;
  esac
done

if [ ! -d "$PROJECT_DIR" ]; then
  echo "BLOCK: 프로젝트 경로가 없습니다: $PROJECT_DIR" >&2
  exit 2
fi
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

runtime_asset_entries() {
  local catalog="$FRAMEWORK_ROOT/docs/framework-runtime-assets.tsv"
  [ -f "$catalog" ] || return 0
  awk -F '\t' '$1 == "target-script" || $1 == "target-hook" { print $1 "\t" $2 }' "$catalog"
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

session_fingerprint() {
  local paths=(
    AGENTS.md CLAUDE.md .ai-dev-standard.env .ai-dev-standard/verification.json
    .ai-dev-standard/verification-ready.json .ai-dev-standard/bootstrap-status.json
    package.json package-lock.json pnpm-lock.yaml yarn.lock
    pyproject.toml requirements.txt go.mod go.sum Cargo.toml Cargo.lock pom.xml build.gradle build.gradle.kts
    scripts/verify.sh scripts/lint.sh scripts/test.sh scripts/verify-plan.sh
    docs/development-workflow.md docs/project-preflight.md docs/framework-runtime-assets.tsv
  )
  local scope path
  while IFS=$'\t' read -r scope path; do
    if is_safe_runtime_asset_path "$path"; then
      paths+=("$path")
    fi
  done < <(runtime_asset_entries)
  for path in "${paths[@]}"; do
    if [ -f "$PROJECT_DIR/$path" ]; then
      sha256sum "$PROJECT_DIR/$path"
    else
      printf 'MISSING  %s\n' "$path"
    fi
  done | sha256sum | awk '{print $1}'
}

SESSION_FILE="$PROJECT_DIR/.ai-dev-standard/session-preflight.json"
if [ "$SESSION_STATUS" = true ]; then
  if [ ! -f "$SESSION_FILE" ]; then
    echo '{"session_status":"missing","can_plan":false,"can_initialize":false,"can_code":false,"verification_ready":false}'
    exit 2
  fi
  current_fingerprint="$(session_fingerprint)"
  stored_fingerprint="$(sed -n 's/^[[:space:]]*"fingerprint": "\([^"]*\)".*/\1/p' "$SESSION_FILE")"
  if [ -z "$stored_fingerprint" ] || [ "$current_fingerprint" != "$stored_fingerprint" ]; then
    echo '{"session_status":"stale","can_plan":false,"can_initialize":false,"can_code":false,"verification_ready":false}'
    exit 2
  fi
  cat "$SESSION_FILE"
  if grep -q '"verdict": "BLOCK"' "$SESSION_FILE"; then exit 2; fi
  exit 0
fi

warnings=()
blocks=()
generated=()
checks=()
stack=()
package_manager="unknown"
framework_status="unknown"
mode="missing"
require_lint=""
require_test=""
can_plan=false
can_code=false
can_initialize=false
verification_ready=false

add_warning() { warnings+=("$1"); }
add_block() { blocks+=("$1"); }
add_check() { checks+=("$1"); }
has_file() { [ -f "$PROJECT_DIR/$1" ]; }

if [ "$REPAIR" = true ]; then
  before="$($FRAMEWORK_ROOT/scripts/check-framework.sh --project-dir "$PROJECT_DIR" 2>&1 || true)"
  if printf '%s\n' "$before" | grep -q '^FAIL '; then
    "$FRAMEWORK_ROOT/scripts/bootstrap-framework.sh" --project-dir "$PROJECT_DIR" --init >/dev/null
    generated+=("누락 공통 골격 (bootstrap-framework --init)")
  fi
fi

if framework_check="$("$FRAMEWORK_ROOT/scripts/check-framework.sh" --project-dir "$PROJECT_DIR" 2>&1)"; then
  framework_status="valid"
  add_check "공통 프레임워크 골격: PASS"
else
  framework_status="invalid"
  add_block "공통 프레임워크 필수 자산 누락 또는 설정 오류"
fi

# 기술 스택과 패키지 관리 신호. 존재하지 않는 신호는 강제 조건이 아니다.
if has_file package.json; then
  stack+=("JavaScript/Node.js")
  if command -v node >/dev/null 2>&1; then
    if node -e "JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8'))" "$PROJECT_DIR/package.json" >/dev/null 2>&1; then
      add_check "package.json 문법: PASS"
    else
      add_block "package.json 구문 오류"
    fi
  else
    add_warning "package.json은 있으나 node 런타임이 없어 JSON 실행 검사를 생략"
  fi
  if has_file pnpm-lock.yaml; then package_manager="pnpm"
  elif has_file yarn.lock; then package_manager="yarn"
  elif has_file package-lock.json; then package_manager="npm"
  else package_manager="Node 패키지 관리자 미확정"; add_warning "Node 프로젝트의 lockfile이 없어 패키지 관리자를 확정할 수 없음"; fi
  if grep -Eq '"(next|react|vue|@angular/core|express|nestjs)"' "$PROJECT_DIR/package.json"; then
    stack+=("프레임워크 감지됨")
  fi
fi
if has_file pyproject.toml || has_file requirements.txt; then
  stack+=("Python")
  if has_file pyproject.toml && command -v python3 >/dev/null 2>&1; then
    if python3 -c "import sys; import tomllib; tomllib.load(open(sys.argv[1], 'rb'))" "$PROJECT_DIR/pyproject.toml" >/dev/null 2>&1; then
      add_check "pyproject.toml 문법: PASS"
    else
      add_warning "pyproject.toml 문법 검사를 수행할 수 없음 (Python 3.11+ 또는 파일 내용 확인 필요)"
    fi
  fi
fi
has_file go.mod && stack+=("Go")
has_file Cargo.toml && stack+=("Rust")
has_file Dockerfile && stack+=("Docker")
if has_file pom.xml || has_file build.gradle || has_file build.gradle.kts || has_file mvnw || has_file gradlew; then stack+=("Java/JVM"); fi
if has_file .shellcheckrc || { for shell_dir in src bin ops; do [ -d "$PROJECT_DIR/$shell_dir" ] && find "$PROJECT_DIR/$shell_dir" -maxdepth 1 -type f -name '*.sh' -print -quit | grep -q . && break; done; }; then stack+=("Shell"); fi
if [ -d "$PROJECT_DIR/systemd" ] || [ -d "$PROJECT_DIR/deploy/systemd" ]; then stack+=("System service"); fi
if [ "${#stack[@]}" -eq 0 ]; then
  stack+=("판별 불가")
  add_warning "기술 스택 신호가 없어 프로젝트별 명령·템플릿 생성을 추정하지 않음"
fi

# 설정과 스크립트 유효성. config은 source하지 않아 임의 코드 실행을 피한다.
if has_file .ai-dev-standard.env; then
  mode_line="$(grep -E '^AI_DEV_STANDARD_MODE=' "$PROJECT_DIR/.ai-dev-standard.env" | tail -n 1)"
  mode="${mode_line#AI_DEV_STANDARD_MODE=}"
  case "$mode" in
    active) add_check "검증 모드: active"; can_code=true ;;
    template) add_warning "검증 모드가 template: Bootstrap/Plan은 가능하지만 기능 Coding/READY_FOR_REVIEW는 차단" ;;
    initializing) add_warning "검증 모드가 initializing: 승인된 초기 설정만 가능하며 기능 Coding/READY_FOR_REVIEW는 차단" ;;
    *) add_block ".ai-dev-standard.env의 AI_DEV_STANDARD_MODE 값이 유효하지 않음" ;;
  esac
  for key in AI_DEV_STANDARD_REQUIRE_LINT AI_DEV_STANDARD_REQUIRE_TYPECHECK AI_DEV_STANDARD_REQUIRE_TEST; do
    value="$(grep -E "^${key}=" "$PROJECT_DIR/.ai-dev-standard.env" | tail -n 1 | cut -d= -f2-)"
    if [ "$value" != "true" ] && [ "$value" != "false" ]; then
      add_block ".ai-dev-standard.env의 ${key} 값이 true 또는 false가 아님"
    fi
    case "$key" in
      AI_DEV_STANDARD_REQUIRE_LINT) require_lint="$value" ;;
      AI_DEV_STANDARD_REQUIRE_TEST) require_test="$value" ;;
    esac
  done
fi

if [ -f "$PROJECT_DIR/.ai-dev-standard/verification.json" ]; then
  profile_state="$(node -e 'const v=require(process.argv[1]); const r=v.loadVerificationProfile(process.argv[2]); if(r.status!=="ok"){console.log(JSON.stringify({status:r.status,message:r.message||r.status}));process.exit(0)} console.log(JSON.stringify({status:"ok",ready:v.isVerificationReady(process.argv[2]).ready,reason:v.isVerificationReady(process.argv[2]).reason||""}))' "$FRAMEWORK_ROOT/lib/verification.js" "$PROJECT_DIR" 2>/dev/null || true)"
  if [ -n "$profile_state" ]; then
    profile_status="$(printf '%s' "$profile_state" | sed -n 's/.*"status":"\([^"]*\)".*/\1/p')"
    if [ "$profile_status" = "invalid" ]; then
      add_block "검증 프로필 오류: $(printf '%s' "$profile_state" | sed -n 's/.*"message":"\([^"]*\)".*/\1/p')"
    elif [ "$profile_status" = "ok" ]; then
      add_check "검증 프로필: 유효"
      ready_value="$(printf '%s' "$profile_state" | sed -n 's/.*"ready":\(true\|false\).*/\1/p')"
      if [ "$ready_value" = "true" ]; then verification_ready=true; add_check "검증 준비 증거: 최신"
      else add_warning "검증 준비 증거 없음 또는 오래됨: $(printf '%s' "$profile_state" | sed -n 's/.*"reason":"\([^"]*\)".*/\1/p')"; fi
    fi
  fi
fi

# 필수 문서는 존재뿐 아니라 비어 있지 않아야 한다. 의미 해석·병합은 LLM과 사람 승인 영역이다.
for document in AGENTS.md ARCHITECTURE.md docs/development-workflow.md docs/definition-of-done.md docs/testing-policy.md; do
  if has_file "$document" && ! grep -q '[^[:space:]]' "$PROJECT_DIR/$document"; then
    add_block "$document 파일이 비어 있음"
  fi
done

# active 모드에서 필수 검사를 선언했는데 감지 가능한 실행 근거가 없으면 Coding을 시작할 수 없다.
if [ "$mode" = "active" ] && [ "$require_lint" = "true" ]; then
  if ! has_file .eslintrc.json && ! has_file eslint.config.js && ! has_file eslint.config.mjs \
    && ! has_file pyproject.toml && ! has_file .ruff.toml; then
    add_block "active 모드에서 필수 lint가 설정됐지만 감지 가능한 lint 구성이 없음"
  fi
fi
if [ "$mode" = "active" ] && [ "$require_test" = "true" ]; then
  has_test_configuration=false
  if has_file jest.config.js || has_file jest.config.cjs || has_file jest.config.mjs \
    || has_file pytest.ini || has_file pyproject.toml || [ -d "$PROJECT_DIR/tests" ] \
    || [ -x "$PROJECT_DIR/scripts/test-framework.sh" ]; then
    has_test_configuration=true
  fi
  if [ "$has_test_configuration" != "true" ]; then
    add_block "active 모드에서 필수 test가 설정됐지만 감지 가능한 테스트 구성이 없음"
  fi
fi

while IFS=$'\t' read -r scope path; do
  if ! is_safe_runtime_asset_path "$path"; then
    add_block "허용되지 않은 실행 자산 경로: $path"
    continue
  fi
  case "$scope" in
    target-script)
      if has_file "$path"; then
        case "$path" in
          *.sh)
            if bash -n "$PROJECT_DIR/$path"; then
              add_check "$path 문법: PASS"
            else
              add_block "$path 셸 문법 오류"
            fi
            ;;
          *.js)
            if node --check "$PROJECT_DIR/$path" >/dev/null 2>&1; then
              add_check "$path 문법: PASS"
            else
              add_block "$path Node 문법 오류"
            fi
            ;;
        esac
      fi
      ;;
    target-hook)
      case "$path" in
        *.sh)
          if has_file "$path"; then
            if bash -n "$PROJECT_DIR/$path"; then
              add_check "$path 문법: PASS"
            else
              add_block "$path 셸 문법 오류"
            fi
          fi
          ;;
      esac
      ;;
  esac
done < <(runtime_asset_entries)

if [ "$RUN_CHECKS" = true ]; then
  if [ "$mode" = "active" ]; then
    if (cd "$PROJECT_DIR" && bash scripts/verify.sh) >/tmp/project-preflight-verify.$$ 2>&1; then
      add_check "verify.sh 실행: PASS"
    else
      add_block "verify.sh 실행 실패 (출력은 실행 환경에서 확인 필요)"
    fi
    rm -f /tmp/project-preflight-verify.$$
  else
    add_warning "--run-checks는 active 모드에서만 통합 검증을 실행함"
  fi
fi

# 특정 에이전트 설정은 선택 사항이다. 발견은 하되 다른 도구 사용을 차단하지 않는다.
agent_paths=()
[ -f "$PROJECT_DIR/AGENTS.md" ] && agent_paths+=("AGENTS.md")
[ -f "$PROJECT_DIR/CLAUDE.md" ] && agent_paths+=("CLAUDE.md")
[ -d "$PROJECT_DIR/.opencode" ] && agent_paths+=(".opencode/")
[ -d "$PROJECT_DIR/.claude" ] && agent_paths+=(".claude/")
[ -d "$PROJECT_DIR/.agents/skills" ] && agent_paths+=(".agents/skills/")
[ "${#agent_paths[@]}" -eq 0 ] && add_warning "에이전트 지침 또는 설정을 감지하지 못함"

if [ "${#blocks[@]}" -eq 0 ]; then
  can_plan=true
fi
if [ "${#blocks[@]}" -eq 0 ] && { [ "$mode" = "template" ] || [ "$mode" = "initializing" ]; }; then can_initialize=true; fi
if [ "${#blocks[@]}" -gt 0 ]; then
  verdict="BLOCK"
elif [ "${#warnings[@]}" -gt 0 ]; then
  verdict="WARNING"
else
  verdict="PASS"
fi
[ "$mode" = "active" ] && [ "$verdict" != "BLOCK" ] || can_code=false

join_by() { local separator="$1"; shift; local first=true; for value in "$@"; do $first || printf '%s' "$separator"; printf '%s' "$value"; first=false; done; }
json_escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
json_array() { local first=true; printf '['; for value in "$@"; do $first || printf ','; printf '"%s"' "$(json_escape "$value")"; first=false; done; printf ']'; }

markdown_report() {
  echo "# Project Preflight Report"
  echo
  printf -- '- 대상 프로젝트: `%s`\n' "$PROJECT_DIR"
  printf -- '- 최종 판정: **%s**\n' "$verdict"
  printf -- '- Plan 진행: **%s**\n' "$can_plan"
  printf -- '- 초기화 진행: **%s**\n' "$can_initialize"
  printf -- '- 검증 준비 완료: **%s**\n' "$verification_ready"
  printf -- '- Coding 진행: **%s**\n' "$can_code"
  echo
  echo "## 감지된 환경"
  printf -- '- 기술 스택: %s\n' "$(join_by ', ' "${stack[@]}")"
  printf -- '- 패키지 관리자: %s\n' "$package_manager"
  printf -- '- 검증 모드: %s\n' "$mode"
  printf -- '- 에이전트 설정: %s\n' "${agent_paths[*]:-감지하지 못함}"
  echo
  echo "## 실행한 검사"
  for item in "${checks[@]}"; do printf -- '- PASS: %s\n' "$item"; done
  echo
  echo "## 자동 생성 항목"
  if [ "${#generated[@]}" -eq 0 ]; then echo "- 없음"; else for item in "${generated[@]}"; do printf -- '- %s\n' "$item"; done; fi
  echo
  echo "## WARNING"
  if [ "${#warnings[@]}" -eq 0 ]; then echo "- 없음"; else for item in "${warnings[@]}"; do printf -- '- %s\n' "$item"; done; fi
  echo
  echo "## BLOCK"
  if [ "${#blocks[@]}" -eq 0 ]; then echo "- 없음"; else for item in "${blocks[@]}"; do printf -- '- %s\n' "$item"; done; fi
  echo
  echo "## 다음 단계"
  case "$verdict" in
    PASS) echo "- Plan → Coding → Verification을 진행할 수 있습니다." ;;
    WARNING)
      if [ "$can_code" = true ]; then
        echo "- WARNING 항목을 기록하고 Plan → Coding → Verification을 진행할 수 있습니다."
      else
        echo "- Plan은 진행할 수 있습니다. Coding 전 WARNING을 해결하거나 active 검증 구성을 확정하세요."
      fi
      ;;
    BLOCK) echo "- BLOCK 원인을 해결한 뒤 같은 Preflight를 재실행하세요. Plan/Coding으로 진행하지 마세요." ;;
  esac
}

json_report() {
  printf '{\n'
  printf '  "project": "%s",\n' "$(json_escape "$PROJECT_DIR")"
  printf '  "verdict": "%s",\n' "$verdict"
  printf '  "can_plan": %s,\n' "$can_plan"
  printf '  "can_initialize": %s,\n' "$can_initialize"
  printf '  "can_code": %s,\n' "$can_code"
  printf '  "verification_ready": %s,\n' "$verification_ready"
  printf '  "stack": '; json_array "${stack[@]}"; printf ',\n'
  printf '  "package_manager": "%s",\n' "$(json_escape "$package_manager")"
  printf '  "verification_mode": "%s",\n' "$mode"
  printf '  "checks": '; json_array "${checks[@]}"; printf ',\n'
  printf '  "generated": '; json_array "${generated[@]}"; printf ',\n'
  printf '  "warnings": '; json_array "${warnings[@]}"; printf ',\n'
  printf '  "blocks": '; json_array "${blocks[@]}"; printf '\n}\n'
}

write_session() {
  mkdir -p "$PROJECT_DIR/.ai-dev-standard"
  session_temp="$(mktemp)"
  cat > "$session_temp" <<EOF
{
  "project": "$(json_escape "$PROJECT_DIR")",
  "checked_at": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
  "fingerprint": "$(session_fingerprint)",
  "verdict": "$verdict",
  "can_plan": $can_plan,
  "can_initialize": $can_initialize,
  "can_code": $can_code,
  "verification_ready": $verification_ready
}
EOF
  mv "$session_temp" "$SESSION_FILE"
}

if [ "$WRITE_REPORT" = true ]; then
  mkdir -p "$PROJECT_DIR/docs/generated"
  markdown_temp="$(mktemp)"; json_temp="$(mktemp)"
  markdown_report > "$markdown_temp"; json_report > "$json_temp"
  for pair in "$markdown_temp:$PROJECT_DIR/docs/generated/project-preflight.md" "$json_temp:$PROJECT_DIR/docs/generated/project-preflight.json"; do
    source_file="${pair%%:*}"; target_file="${pair#*:}"
    if [ ! -f "$target_file" ] || ! cmp -s "$source_file" "$target_file"; then mv "$source_file" "$target_file"; else rm -f "$source_file"; fi
  done
fi

if [ "$WRITE_SESSION" = true ]; then write_session; fi

if [ "$FORMAT" = "json" ]; then json_report; else markdown_report; fi
case "$verdict" in
  BLOCK) exit 2 ;;
  *) exit 0 ;;
esac
