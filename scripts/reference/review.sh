#!/usr/bin/env bash
# 독립 리뷰 진입점 — Standards Review와 Spec Review를 분리해 수행한다.
# 기본 동작: git diff 기반 체크리스트 출력(사람/AI 리뷰어가 공통으로 사용)
# 확장: 리뷰 전용 에이전트 또는 사람 리뷰 절차로 연결 (PLACEHOLDER)
set -uo pipefail
cd "$(dirname "$0")/.."

BASE=""
PLAN_ARG=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --plan)
      [ -n "${2:-}" ] || { echo "사용법: review [base] [--plan <실행계획>]" >&2; exit 2; }
      PLAN_ARG="$2"; shift 2 ;;
    *)
      if [ -z "$BASE" ]; then BASE="$1"; fi; shift ;;
  esac
done
BASE="${BASE:-HEAD~1}"
if [ -n "$PLAN_ARG" ] && [ ! -f "$PLAN_ARG" ]; then
  echo "실행 계획 파일을 찾을 수 없습니다: $PLAN_ARG" >&2
  exit 2
fi
if git rev-parse --verify --quiet "${BASE}^{commit}" >/dev/null 2>&1; then
  BASE_AVAILABLE=true
  BASE_LABEL="$BASE"
else
  BASE_AVAILABLE=false
  BASE_LABEL="비교 기준 없음"
fi

if [ -n "$PLAN_ARG" ]; then
  PURPOSE="$(sed -n 's/^- 목적: //p' "$PLAN_ARG" | head -n 1)"
  [ -n "$PURPOSE" ] || PURPOSE="(계획에 목적 미기입)"
  AC_ROWS="$(awk '/^## AC 판정$/{inside=1; next} /^## /{inside=0} inside && /^\| AC-[^|]+ \|/{print}' "$PLAN_ARG")"
  AC_TOTAL=0; AC_PASS=0
  if [ -n "$AC_ROWS" ]; then
    AC_TOTAL="$(printf '%s\n' "$AC_ROWS" | wc -l | tr -d ' ')"
    AC_PASS="$(printf '%s\n' "$AC_ROWS" | grep -c '| PASS |')"
  fi
  AUTO_RESULT="$(awk '/^## 자동 검증 증거$/{inside=1; next} /^## /{inside=0} inside && /^- 결과 요약: /{value=$0; sub(/^- 결과 요약: /, "", value); sub(/ .*/, "", value)} END{print value}' "$PLAN_ARG")"
  AUTO_EXIT="$(awk '/^## 자동 검증 증거$/{inside=1; next} /^## /{inside=0} inside && /^- 종료 코드: /{value=$0; sub(/^- 종료 코드: /, "", value)} END{print value}' "$PLAN_ARG")"
  VERIFY_LINE="$(sed -n 's/^[[:space:]]*- \([[:alnum:]_.-]* 결과: .*\)$/\1/p' "$PLAN_ARG" | head -n 1)"
  if [ -n "$AUTO_RESULT" ] && [ -n "$AUTO_EXIT" ]; then
    VERIFY_LINE="자동 검증 증거: ${AUTO_RESULT} (종료 코드 ${AUTO_EXIT})"
  fi
  [ -n "$VERIFY_LINE" ] || VERIFY_LINE="검증 기록 미기입"
  echo "=== 작업 요약 ==="
  echo "[목적] $PURPOSE"
  if [ "$BASE_AVAILABLE" = true ]; then
    CHANGED="$(git diff --name-only "$BASE" | grep -c . || true)"
    echo "[내용] 변경 파일 ${CHANGED}건 — 상세는 아래 diff stat 참조"
  else
    echo "[내용] git 비교 기준 없음 — 작업 트리 확인 필요"
  fi
  if [ "$AC_TOTAL" -eq 0 ]; then AC_PART="AC 판정 없음"; else AC_PART="AC 판정 ${AC_PASS}/${AC_TOTAL} PASS"; fi
  echo "[결과·검증] ${AC_PART} · ${VERIFY_LINE}"
  E2E_VERSION="$(sed -n 's/^- 검증 계약 버전: //p' "$PLAN_ARG" | head -n 1)"
  E2E_NEEDED="$(sed -n '/^## E2E 판정$/{inside=1; next} /^## /{inside=0} inside && /^- 필요 여부: /{sub(/^- 필요 여부: /, ""); print; exit}' "$PLAN_ARG")"
  E2E_METHOD="$(sed -n '/^## E2E 판정$/{inside=1; next} /^## /{inside=0} inside && /^- 방식: /{sub(/^- 방식: /, ""); print; exit}' "$PLAN_ARG")"
  if [ "$E2E_VERSION" != "2" ]; then
    E2E_LINE="E2E 판정: 레거시 Plan"
  elif [ "$E2E_NEEDED" = "불필요" ]; then
    E2E_LINE="E2E 판정: 불필요"
  elif [ "$E2E_METHOD" = "수동 Browser UAT" ]; then
    if sed -n '/^## E2E 검증 증거$/{inside=1; next} /^## /{inside=0} inside {print}' "$PLAN_ARG" | grep -Fq -- '- 판정: PASS'; then E2E_RESULT="PASS"; else E2E_RESULT="미검증"; fi
    E2E_LINE="E2E 판정: 수동 Browser UAT — ${E2E_RESULT}"
  else
    E2E_RESULT="$(sed -n '/^## E2E 검증 증거$/{inside=1; next} /^## /{inside=0} inside && /^- 결과 요약: /{sub(/^- 결과 요약: /, ""); sub(/ .*/, ""); value=$0} END{print value}' "$PLAN_ARG")"
    [ -n "$E2E_RESULT" ] || E2E_RESULT="미검증"
    E2E_LINE="E2E 판정: ${E2E_METHOD} — ${E2E_RESULT}"
  fi
  echo "[E2E] ${E2E_LINE}"
  echo ""
fi

echo "=== 독립 리뷰 체크리스트 (base: ${BASE_LABEL}) ==="
echo ""
echo "[Standards Review] git diff ${BASE} 대상으로 점검한다:"
echo ""
echo " 1. 의도한 파일만 변경되었는가 (계획 범위 내)"
echo " 2. 요청 범위 밖 변경이 없는가"
echo " 3. 예상치 못한 삭제/이동이 없는가"
echo " 4. 불필요한 포맷 변경이 없는가"
echo " 5. debug/TODO/임시 파일 잔존 없는가"
echo " 6. 의존성/설정 변경이 의도된 것인가"
echo " 7. 민감정보(키·토큰·.env) 포함 없는가"
echo " 8. 제품 명세와 실행 계획이 변경과 함께 있는가"
echo " 9. 불필요한 중복 구현이 없는가 — 기존 기능 탐색·선택 근거 확인"
echo " 10. 과도한 추상화·불필요한 복잡성이 없는가"
echo ""
echo "[Spec Review] 제품 명세와 실행 계획의 각 AC를 대상으로 점검한다:"
echo " 1. 각 AC가 실제 구현에 의해 충족됐는가"
echo " 2. 각 AC에 테스트·수동 확인·측정 중 하나의 증거가 있는가"
echo " 3. 미검증 AC와 요구사항에서 벗어난 동작이 명시됐는가"
echo " 4. AC별 판정을 PASS / FAIL / 미검증으로 기록했는가"
echo ""
echo "[Evidence Review] 완료 기록의 각 PASS가 실제 실행 증거와 일치하는가:"
echo " 1. PASS마다 실행 명령과 종료 코드가 기록돼 있는가"
echo " 2. 인용한 증거가 그 AC를 판정할 수 있는 검사의 출력인가 (다른 검사의 PASS 전용 금지)"
echo " 3. 증거 없는 PASS·오인용 인용은 FAIL로 판정하는가"
echo ""
echo "--- diff stat ---"
if [ "$BASE_AVAILABLE" = true ]; then
  git diff --stat "${BASE}"
else
  echo "(git 비교 기준이 없거나 base가 무효함 — git status --short와 현재 작업 트리를 검토하세요)"
fi
echo ""
echo "# PLACEHOLDER: 여기에 두 관점의 독립 리뷰 에이전트 호출을 연결한다."
echo '# 예) claude -p "$(git diff <base>) 를 위 체크리스트로 리뷰해라"'
echo '# 예) opencode run -a reviewer "..."'
