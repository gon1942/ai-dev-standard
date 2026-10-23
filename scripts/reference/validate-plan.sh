#!/usr/bin/env bash
# 구현 전 Exec Plan의 승인·구조·AC 추적성을 검사한다. 테스트는 실행하지 않는다.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
  echo "사용법: scripts/validate-plan.sh <docs/exec-plans/active/실행계획.md>" >&2
  exit 2
fi

PLAN_FILE="$1"
case "$PLAN_FILE" in docs/exec-plans/active/*) ;; *) echo "활성 실행 계획 파일을 지정하세요." >&2; exit 2 ;; esac

require() {
  grep -Eq "$1" "$PLAN_FILE" || { echo "실행 계획 필수 항목 누락: $1" >&2; exit 2; }
}

require '^# Exec Plan:'
require '^- 상태: active$'
require '^- 승인: approved$'
require '^- 제품 명세: '
require '^## 구현 계획$'
require '^## 검증 계획$'
require '^## 회귀 검증 대상$'

SPEC_FILE="$(sed -n 's/^- 제품 명세: //p' "$PLAN_FILE" | head -n 1)"
if [ -z "$SPEC_FILE" ] || [ ! -f "$SPEC_FILE" ]; then
  echo "제품 명세를 찾을 수 없습니다: $SPEC_FILE" >&2
  exit 2
fi
if ! grep -Eq '^- 상태: approved$' "$SPEC_FILE"; then
  echo "승인된 제품 명세가 아닙니다: $SPEC_FILE" >&2
  exit 2
fi

SPEC_BUNDLE="$(sed -n 's/^- 사전 승인 묶음: //p' "$SPEC_FILE" | head -n 1)"
PLAN_BUNDLE="$(sed -n 's/^- 사전 승인 묶음: //p' "$PLAN_FILE" | head -n 1)"
if [ -n "$SPEC_BUNDLE" ] || [ -n "$PLAN_BUNDLE" ]; then
  if [ -z "$SPEC_BUNDLE" ] || [ -z "$PLAN_BUNDLE" ]; then
    echo "사전 승인 기록이 명세와 계획 양쪽에 필요합니다." >&2
    exit 2
  fi
  if ! [[ "$SPEC_BUNDLE" =~ ^PREAPPROVAL-[0-9]{8}-[0-9]{6}$ ]] || [ "$SPEC_BUNDLE" != "$PLAN_BUNDLE" ]; then
    echo "사전 승인 묶음 ID가 명세와 계획에서 일치하지 않습니다." >&2
    exit 2
  fi
  for field in "승인 결정자" "승인 일자"; do
    SPEC_VALUE="$(sed -n "s/^- ${field}: //p" "$SPEC_FILE" | head -n 1)"
    PLAN_VALUE="$(sed -n "s/^- ${field}: //p" "$PLAN_FILE" | head -n 1)"
    if [ -z "$SPEC_VALUE" ] || [ "$SPEC_VALUE" = "pending" ] || [ "$SPEC_VALUE" != "$PLAN_VALUE" ]; then
      echo "사전 승인 결정자 또는 일자가 양쪽 문서에서 일치하지 않습니다." >&2
      exit 2
    fi
    if [ "$field" = "승인 일자" ] && ! [[ "$SPEC_VALUE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
      echo "사전 승인 결정자 또는 일자가 양쪽 문서에서 일치하지 않습니다." >&2
      exit 2
    fi
  done
fi

if grep -q '^- 유형: 버그' "$SPEC_FILE"; then
  if ! grep -q '^## 재현 조건' "$SPEC_FILE"; then
    echo "버그 유형 명세에 '## 재현 조건' 섹션이 필요합니다." >&2
    exit 2
  fi
  REPRO_SECTION="$(sed -n '/^## 재현 조건/,/^## /p' "$SPEC_FILE")"
  if printf '%s\n' "$REPRO_SECTION" | grep -Eq '^- 재현 불가 사유: .+'; then
    if ! printf '%s\n' "$REPRO_SECTION" | grep -Eq '^- 대체 판정 방법: .+'; then
      echo "재현 불가 버그는 '대체 판정 방법'도 명시해야 합니다." >&2
      exit 2
    fi
  else
    for label in "동일 입력" "반복 재현 절차" "기대 결과"; do
      if ! printf '%s\n' "$REPRO_SECTION" | grep -Eq "^- ${label}: .+"; then
        echo "버그 재현 조건의 '${label}'이(가) 미작성입니다 (세 항목 모두 필요)." >&2
        exit 2
      fi
    done
  fi
fi

if grep -Eq '(^|[[:space:]])\.\.\.' "$PLAN_FILE"; then
  echo "실행 계획에 미작성 placeholder(...)가 남아 있습니다." >&2
  exit 2
fi

# Task Graph (선택 섹션) — 데이터 행이 없으면 검증을 생략한다.
# 오류 메시지는 Node 구현(scripts/lib/commands/validate-plan.js)과 바이트 동치여야 한다.
TASK_GRAPH_ERROR="$(awk '
function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
/^## Task Graph$/{inside=1; next} /^## /{inside=0}
inside && /^\|/ {
  n=split($0, raw, "|")
  id=trim(raw[2])
  if (id == "" || id == "Task") next
  if (id ~ /^[-: ]*$/) next
  cnt++
  tg_id[cnt]=id
  tg_dep[cnt]=(n >= 3 ? trim(raw[3]) : "")
  tg_status[cnt]=(n >= 5 ? trim(raw[5]) : "")
}
END {
  if (cnt == 0) exit 0
  # 1) Task ID 형식
  for (i = 1; i <= cnt; i++) {
    if (tg_id[i] !~ /^T[0-9]+$/) {
      printf "Task Graph의 Task ID 형식이 잘못되었습니다: %s\n", tg_id[i]
      exit 0
    }
  }
  # 2) 중복 ID
  for (i = 1; i <= cnt; i++) {
    for (j = 1; j < i; j++) {
      if (tg_id[j] == tg_id[i]) {
        printf "Task Graph에 중복 Task ID가 있습니다: %s\n", tg_id[i]
        exit 0
      }
    }
  }
  # 3) 상태 값
  for (i = 1; i <= cnt; i++) {
    ok = (tg_status[i] == "구현 전" || tg_status[i] == "구현 완료" || tg_status[i] == "검증 완료")
    if (!ok) {
      value = (tg_status[i] == "" ? "(빈 값)" : tg_status[i])
      printf "Task Graph의 상태 값이 허용 목록에 없습니다: %s (허용: 구현 전, 구현 완료, 검증 완료)\n", value
      exit 0
    }
  }
  # 의존 토큰화 — depmap[id]는 공백 구분 토큰
  for (i = 1; i <= cnt; i++) {
    d = tg_dep[i]
    depmap[tg_id[i]] = ""
    if (d == "" || d == "—" || d == "해당 없음") continue
    ntok = split(d, toks, /[\t ,]+/)
    for (k = 1; k <= ntok; k++) {
      if (toks[k] == "") continue
      depmap[tg_id[i]] = depmap[tg_id[i]] (depmap[tg_id[i]] == "" ? "" : " ") toks[k]
    }
  }
  # 4) 의존 참조 유효성
  for (i = 1; i <= cnt; i++) {
    nt = split(depmap[tg_id[i]], dt, " ")
    for (k = 1; k <= nt; k++) {
      found = 0
      for (j = 1; j <= cnt; j++) if (tg_id[j] == dt[k]) { found = 1; break }
      if (!found) {
        printf "Task Graph의 의존성이 정의되지 않은 Task를 참조합니다: %s\n", dt[k]
        exit 0
      }
    }
  }
  # 5) 순환 참조 (DFS)
  cyclmsg = ""
  for (i = 1; i <= cnt && cyclmsg == ""; i++) dfs(tg_id[i])
  if (cyclmsg != "") {
    printf "Task Graph에 순환 참조가 있습니다: %s\n", cyclmsg
    exit 0
  }
}
function dfs(node,   i, nd, arr, path, s, e) {
  if (cyclmsg != "" || done[node]) return
  if (node in onstack) {
    path = ""
    for (i = pos[node]; i <= slen; i++) path = path (i > pos[node] ? " -> " : "") stack[i]
    cyclmsg = path " -> " node
    return
  }
  slen++; stack[slen] = node; pos[node] = slen; onstack[node] = 1
  nd = split(depmap[node], arr, " ")
  for (i = 1; i <= nd; i++) dfs(arr[i])
  delete onstack[node]
  slen--
  done[node] = 1
}
' "$PLAN_FILE")"
if [ -n "$TASK_GRAPH_ERROR" ]; then
  echo "$TASK_GRAPH_ERROR" >&2
  exit 2
fi

spec_acs="$(sed -n '/^## 완료 조건/,/^## /p' "$SPEC_FILE" | grep -oE 'AC-[0-9]+' | sort -u || true)"
if [ -z "$spec_acs" ]; then
  echo "제품 명세에 Acceptance Criteria가 없습니다." >&2
  exit 2
fi
for ac in $spec_acs; do
  if ! awk '/^## 검증 계획$/{inside=1; next} /^## /{inside=0} inside {print}' "$PLAN_FILE" | grep -Fq "$ac"; then
    echo "검증 계획에 명세 AC가 없습니다: $ac" >&2
    exit 2
  fi
done

CONTRACT_VERSION="$(sed -n 's/^- 검증 계약 버전: //p' "$PLAN_FILE" | head -n 1)"
if [ -n "$CONTRACT_VERSION" ] && [ "$CONTRACT_VERSION" != "2" ]; then
  echo "지원하지 않는 검증 계약 버전입니다." >&2
  exit 2
fi
if [ "$CONTRACT_VERSION" = "2" ]; then
  E2E_SECTION="$(awk '/^## E2E 판정$/{inside=1; next} /^## /{inside=0} inside {print}' "$PLAN_FILE")"
  e2e_value() { printf '%s\n' "$E2E_SECTION" | sed -n "s/^- $1: //p" | head -n 1; }
  E2E_NEEDED="$(e2e_value '필요 여부')"
  E2E_METHOD="$(e2e_value '방식')"
  E2E_REASON="$(e2e_value '판정 근거')"
  E2E_ACS="$(e2e_value '대상 AC')"
  E2E_PROCEDURE="$(e2e_value '자동 실행 명령 또는 수동 UAT 시나리오')"
  E2E_PREREQUISITES="$(e2e_value '사전 조건')"
  case "$E2E_NEEDED" in 필요|불필요) ;; *) echo "E2E 판정의 '필요 여부'는 필요 또는 불필요여야 합니다." >&2; exit 2;; esac
  case "$E2E_METHOD" in '자동 Browser E2E'|'수동 Browser UAT'|'API/System E2E'|'CLI E2E'|'해당 없음') ;; *) echo "E2E 판정의 '방식' 값이 허용 목록에 없습니다." >&2; exit 2;; esac
  [ -n "$E2E_REASON" ] && [ "$E2E_REASON" != "해당 없음" ] || { echo "E2E 판정의 '판정 근거'가 필요합니다." >&2; exit 2; }
  [ -n "$E2E_PROCEDURE" ] || { echo "E2E 판정의 자동 실행 명령 또는 수동 UAT 시나리오가 필요합니다." >&2; exit 2; }
  [ -n "$E2E_PREREQUISITES" ] || { echo "E2E 판정의 '사전 조건'이 필요합니다." >&2; exit 2; }
  if [ "$E2E_NEEDED" = "불필요" ]; then
    [ "$E2E_METHOD" = "해당 없음" ] || { echo "E2E 불필요 Plan의 방식은 '해당 없음'이어야 합니다." >&2; exit 2; }
    [ "$E2E_ACS" = "해당 없음" ] || { echo "E2E 불필요 Plan의 대상 AC는 '해당 없음'이어야 합니다." >&2; exit 2; }
  else
    [ "$E2E_METHOD" != "해당 없음" ] || { echo "E2E 필요 Plan에는 실제 검증 방식을 지정해야 합니다." >&2; exit 2; }
    E2E_AC_LIST="$(printf '%s\n' "$E2E_ACS" | grep -oE 'AC-[0-9]+' | sort -u || true)"
    [ -n "$E2E_AC_LIST" ] || { echo "E2E 필요 Plan에는 하나 이상의 대상 AC가 필요합니다." >&2; exit 2; }
    for e2e_ac in $E2E_AC_LIST; do
      printf '%s\n' "$spec_acs" | grep -Fxq "$e2e_ac" || { echo "E2E 판정의 대상 AC가 제품 명세에 없습니다." >&2; exit 2; }
      awk '/^## 검증 계획$/{inside=1; next} /^## /{inside=0} inside {print}' "$PLAN_FILE" | grep -Fq "$e2e_ac" || { echo "E2E 판정의 대상 AC가 검증 계획에 없습니다: $e2e_ac" >&2; exit 2; }
    done

    if { [ "$E2E_METHOD" = "자동 Browser E2E" ] || [ "$E2E_METHOD" = "API/System E2E" ]; } && [ ! -f .ai-dev-standard/e2e.json ]; then
      PROFILE_SECTION="$(awk '/^## E2E 프로필 제안$/{inside=1; next} /^## /{inside=0} inside {print}' "$PLAN_FILE")"
      profile_value() { printf '%s\n' "$PROFILE_SECTION" | sed -n "s/^- $1: //p" | head -n 1; }
      PROFILE_READINESS="$(profile_value '준비 상태')"
      PROFILE_NAME="$(profile_value '선택 프로필')"
      PROFILE_ACS="$(profile_value '대상 AC')"
      PROFILE_IMPACT="$(profile_value '설치 영향')"
      PROFILE_COMMAND="$(profile_value '구성 명령')"
      PROFILE_ALTERNATIVE="$(profile_value '거부/실패 대안')"
      [ -n "$PROFILE_SECTION" ] || { echo "자동 E2E 설정이 없으면 '## E2E 프로필 제안' 섹션이 필요합니다." >&2; exit 2; }
      [ "$PROFILE_READINESS" = "구성 필요" ] || { echo "E2E 프로필 제안의 '준비 상태'는 구성 필요여야 합니다." >&2; exit 2; }
      case "$PROFILE_NAME" in node-api|playwright|cypress) ;; *) echo "E2E 프로필 제안의 '선택 프로필'은 node-api, playwright, cypress 중 하나여야 합니다." >&2; exit 2;; esac
      if { [ "$PROFILE_NAME" = node-api ] && [ "$E2E_METHOD" != "API/System E2E" ]; } || { [ "$PROFILE_NAME" != node-api ] && [ "$E2E_METHOD" != "자동 Browser E2E" ]; }; then
        echo "E2E 프로필 제안의 선택 프로필과 E2E 방식이 일치하지 않습니다." >&2
        exit 2
      fi
      for profile_field in "$PROFILE_IMPACT" "$PROFILE_COMMAND" "$PROFILE_ALTERNATIVE"; do
        [ -n "$profile_field" ] && [ "$profile_field" != "해당 없음" ] || { echo "E2E 프로필 제안의 필수 항목이 필요합니다." >&2; exit 2; }
      done
      PROFILE_AC_LIST="$(printf '%s\n' "$PROFILE_ACS" | grep -oE 'AC-[0-9]+' | sort -u || true)"
      [ -n "$PROFILE_AC_LIST" ] || { echo "E2E 프로필 제안의 대상 AC가 제품 명세에 없습니다." >&2; exit 2; }
      [ "$PROFILE_AC_LIST" = "$E2E_AC_LIST" ] || { echo "E2E 프로필 제안의 대상 AC는 E2E 판정의 대상 AC와 일치해야 합니다." >&2; exit 2; }
      for profile_ac in $PROFILE_AC_LIST; do
        printf '%s\n' "$spec_acs" | grep -Fxq "$profile_ac" || { echo "E2E 프로필 제안의 대상 AC가 제품 명세에 없습니다." >&2; exit 2; }
      done
    fi
  fi
fi

echo "PLAN VALID: $PLAN_FILE"
