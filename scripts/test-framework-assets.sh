#!/usr/bin/env bash
# 대상 프로젝트에 배포되는 실행 자산과 원본 전용 회귀 자산의 분리를 검증한다.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CATALOG="$ROOT/docs/framework-runtime-assets.tsv"
TMP_ROOT="$(mktemp -d)"
TARGET="$TMP_ROOT/target"
trap 'rm -rf "$TMP_ROOT"' EXIT

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

require_file() {
  [ -f "$1" ] || fail "필수 파일이 없습니다: $1"
}

require_executable() {
  [ -x "$1" ] || fail "실행 권한이 없습니다: $1"
}

require_file "$CATALOG"
mkdir -p "$TARGET"
printf '%s\n' '# Existing target instruction' 'preserve-this-line' > "$TARGET/AGENTS.md"

"$ROOT/scripts/bootstrap-framework.sh" --project-dir "$TARGET" --init >/dev/null
"$ROOT/scripts/check-framework.sh" --project-dir "$TARGET" >/dev/null
grep -Fqx 'preserve-this-line' "$TARGET/AGENTS.md" || fail '기존 AGENTS.md가 보존되지 않았습니다'

APPLY_REPORT="$TMP_ROOT/framework-apply-plan.md"
"$ROOT/scripts/plan-framework-apply.sh" --project-dir "$TARGET" > "$APPLY_REPORT"

while IFS=$'\t' read -r scope path description; do
  case "$scope" in
    ''|'#'*) continue ;;
    target-script|target-hook)
      require_file "$TARGET/$path"
      require_executable "$TARGET/$path"
      grep -Fq "\`$path\`" "$APPLY_REPORT" || fail "적용 보고서에 실행 자산이 없습니다: $path"
      ;;
    repository-test)
      [ ! -e "$TARGET/$path" ] || fail "원본 전용 테스트가 대상에 복사되었습니다: $path"
      ;;
    *) fail "알 수 없는 실행 자산 범위입니다: $scope" ;;
  esac
done < "$CATALOG"

# Constitution 템플릿·질문 스킵 회귀
CONST="$TARGET/docs/project-constitution.md"
require_file "$CONST"
for section in '## 고위험 변경과 승인 경계' '## 아키텍처 불변 조건' '## 규제·컴플라이언스 요건' '## 인증·권한·외부 연동 정책' '## 데이터·프라이버시 정책' '## 프로젝트별 필수 검증 수준' '## 안티골 — 기술적으로 가능해도 하지 않을 것' '## 미확정 결정·확정에 필요한 정보'; do
  grep -Fqx -- "$section" "$CONST" || fail "새 Constitution 템플릿에 필수 섹션이 없습니다: $section"
done
grep -Fq '사람 승인으로 진행' "$CONST" || fail 'Constitution 변경 경계 문구가 없습니다'

# 초안 상태 → Constitution 질문이 출력돼야 한다
DRAFT_OUT="$("$ROOT/scripts/prepare-project-context.sh" --project-dir "$TARGET")"
grep -Fq '고위험 영역' <<<"$DRAFT_OUT" || fail '초안 Constitution인데 고위험 질문이 출력되지 않았습니다'
grep -Fq '안티골' <<<"$DRAFT_OUT" || fail '초안 Constitution인데 안티골 질문이 출력되지 않았습니다'

# 오염된 상태 값('확정 임시') → 다시 질문해야 한다
sed -i 's/^- 상태: 초안$/- 상태: 확정 임시/' "$CONST"
DIRTY_OUT="$("$ROOT/scripts/prepare-project-context.sh" --project-dir "$TARGET")"
grep -Fq '고위험 영역' <<<"$DIRTY_OUT" || fail "오염된 상태 값('확정 임시')인데 질문이 스킵되었습니다"

# 정확히 확정(단일 상태 행+전체 섹션) → 질문이 스킵돼야 한다
sed -i 's/^- 상태: 확정 임시$/- 상태: 확정/' "$CONST"
CONFIRMED_OUT="$("$ROOT/scripts/prepare-project-context.sh" --project-dir "$TARGET")"
grep -Fq '고위험 영역' <<<"$CONFIRMED_OUT" && fail '확정 Constitution인데 질문이 반복되었습니다'

# 상태 행 중복 → 다시 질문해야 한다
printf '%s\n' '- 상태: 초안' >> "$CONST"
DUPLICATE_STATUS_OUT="$("$ROOT/scripts/prepare-project-context.sh" --project-dir "$TARGET")"
grep -Fq '고위험 영역' <<<"$DUPLICATE_STATUS_OUT" || fail '상태 행이 중복됐는데 질문이 스킵되었습니다'
sed -i '$d' "$CONST"

# 상태 행 누락 → 다시 질문해야 한다
sed -i '/^- 상태: 확정$/d' "$CONST"
MISSING_STATUS_OUT="$("$ROOT/scripts/prepare-project-context.sh" --project-dir "$TARGET")"
grep -Fq '고위험 영역' <<<"$MISSING_STATUS_OUT" || fail '상태 행이 없는데 질문이 스킵되었습니다'
sed -i '/^- 최종 승인:/i - 상태: 확정' "$CONST"

# 형식 불완전(안티골 섹션 누락) → 다시 질문해야 한다
sed -i '/^## 안티골/d' "$CONST"
BROKEN_OUT="$("$ROOT/scripts/prepare-project-context.sh" --project-dir "$TARGET")"
grep -Fq '고위험 영역' <<<"$BROKEN_OUT" || fail '안티골 섹션이 누락됐는데 질문이 스킵되었습니다'

# 형식 불완전(미확정 결정 섹션 누락) → 다시 질문해야 한다
sed -i '/^## 미확정 결정/d' "$CONST"
BROKEN2_OUT="$("$ROOT/scripts/prepare-project-context.sh" --project-dir "$TARGET")"
grep -Fq '고위험 영역' <<<"$BROKEN2_OUT" || fail '미확정 결정 섹션이 누락됐는데 질문이 스킵되었습니다'

# 대상 내부의 목록이 변조됐을 때 check-framework가 프로젝트 밖 경로를 검사하지 않고 실패해야 한다.
printf '%s\n' 'target-script	../outside.sh	unsafe fixture' > "$TARGET/docs/framework-runtime-assets.tsv"
if "$TARGET/scripts/check-framework.sh" --project-dir "$TARGET" >/dev/null 2>&1; then
  fail '허용되지 않은 실행 자산 경로가 골격 검사에 통과했습니다'
fi

echo 'PASS: framework runtime assets are deployed, checked, and separated from repository tests'
