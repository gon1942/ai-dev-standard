#!/usr/bin/env bash
# 독립 리뷰 진입점 — Standards Review와 Spec Review를 분리해 수행한다.
# 기본 동작: git diff 기반 체크리스트 출력(사람/AI 리뷰어가 공통으로 사용)
# 확장: 리뷰 전용 에이전트 또는 사람 리뷰 절차로 연결 (PLACEHOLDER)
set -uo pipefail
cd "$(dirname "$0")/.."

BASE="${1:-HEAD~1}"
if git rev-parse --verify --quiet "${BASE}^{commit}" >/dev/null 2>&1; then
  BASE_AVAILABLE=true
  BASE_LABEL="$BASE"
else
  BASE_AVAILABLE=false
  BASE_LABEL="비교 기준 없음"
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
