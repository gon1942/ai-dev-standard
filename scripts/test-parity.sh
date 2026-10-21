#!/usr/bin/env bash
# bash↔Node 동치성 시험 — Node 이관(트랙 B)의 증거.
# repository-test 범위: 프레임워크 원본 전용, 배포 대상에 복사되지 않는다.
#
# 동치성 정의 (design-docs/verification-rearchitecture.md §5):
#   L1 (계약): 종료 코드 + 핵심 출력 라인 일치
#   L2 (참고): 타임스탬프 정규화 후 전체 출력·생성 파일 내용 일치
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS_COUNT=0
FAIL_COUNT=0

# 타임스탬프(파일명·문서 내 날짜-시각 조합)를 공통 토큰으로 정규화한다.
normalize() {
  sed -E 's/[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6}/TIMESTAMP/g; s/[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}/DATETIME/g'
}

# compare <케이스명> <bash_exit> <bash_out_file> <node_exit> <node_out_file>
compare_outputs() {
  local label="$1" bash_code="$2" bash_out="$3" node_code="$4" node_out="$5"
  if [ "$bash_code" != "$node_code" ]; then
    echo "FAIL [$label] 종료 코드 불일치: bash=$bash_code node=$node_code" >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return
  fi
  if ! diff -q <(normalize < "$bash_out") <(normalize < "$node_out") >/dev/null; then
    echo "FAIL [$label] 출력 불일치:" >&2
    diff <(normalize < "$bash_out") <(normalize < "$node_out") | head -5 >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return
  fi
  PASS_COUNT=$((PASS_COUNT + 1))
}

# compare_trees <케이스명> <bash_root> <node_root> — 생성 파일 목록·내용(L2) 비교
# (비교 대상은 생성물 docs/ 만 — 세팅용 scripts/ 사본은 제외)
compare_trees() {
  local label="$1" bash_root="$2" node_root="$3"
  local bash_list node_list bash_real
  bash_real="$(cd "$bash_root" && find . -type f -not -path './scripts/*' | sort)"
  bash_list="$(printf '%s\n' "$bash_real" | normalize)"
  node_list="$(cd "$node_root" && find . -type f -not -path './scripts/*' | sort | normalize)"
  if [ "$bash_list" != "$node_list" ]; then
    echo "FAIL [$label] 생성 파일 목록 불일치:" >&2
    diff <(printf '%s\n' "$bash_list") <(printf '%s\n' "$node_list") >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return
  fi
  local rel
  while IFS= read -r rel; do
    if ! diff -q <(normalize < "$bash_root/$rel") <(normalize < "$node_root/$rel") >/dev/null; then
      echo "FAIL [$label] 파일 내용 불일치: $rel" >&2
      diff <(normalize < "$bash_root/$rel") <(normalize < "$node_root/$rel") | head -5 >&2
      FAIL_COUNT=$((FAIL_COUNT + 1))
      return
    fi
  done <<< "$bash_real"
  PASS_COUNT=$((PASS_COUNT + 1))
}

# bash 구현은 대상 루트의 scripts/ 에서 실행해야 루트가 분리된다.
setup_case() {
  local case_dir="$1"
  mkdir -p "$case_dir/scripts"
  cp "$ROOT/scripts/new-product-spec.sh" "$ROOT/scripts/new-exec-plan.sh" "$case_dir/scripts/"
}

# ── 케이스 1: 명세 생성 성공 (한글 작업명으로 SAFE_NAME 동치 확인) ──
{
  BD="$TMP/c1-bash"; ND="$TMP/c1-node"
  setup_case "$BD"; mkdir -p "$ND"
  set +e
  (cd "$BD" && bash scripts/new-product-spec.sh "가-힣 테스트" "사용자 요청 원문") > "$TMP/c1-bash.out" 2>&1
  BC=$?
  AI_DEV_STANDARD_ROOT="$ND" node "$ROOT/bin/ai-dev-standard.js" new-product-spec "가-힣 테스트" "사용자 요청 원문" > "$TMP/c1-node.out" 2>&1
  NC=$?
  set -e
  compare_outputs "spec-성공" "$BC" "$TMP/c1-bash.out" "$NC" "$TMP/c1-node.out"
  compare_trees "spec-성공-파일" "$BD" "$ND"
}

# ── 케이스 2: 명세 사용법 오류 (인자 1개 → exit 2) ──
{
  BD="$TMP/c2-bash"; ND="$TMP/c2-node"
  setup_case "$BD"; mkdir -p "$ND"
  set +e
  (cd "$BD" && bash scripts/new-product-spec.sh "작업명만") > "$TMP/c2-bash.out" 2>&1
  BC=$?
  AI_DEV_STANDARD_ROOT="$ND" node "$ROOT/bin/ai-dev-standard.js" new-product-spec "작업명만" > "$TMP/c2-node.out" 2>&1
  NC=$?
  set -e
  compare_outputs "spec-사용법오류" "$BC" "$TMP/c2-bash.out" "$NC" "$TMP/c2-node.out"
}

# ── 케이스 3: 미승인 명세 → 계획 생성 거부 (exit 2) ──
{
  BD="$TMP/c3-bash"; ND="$TMP/c3-node"
  setup_case "$BD"; mkdir -p "$ND"
  for D in "$BD" "$ND"; do
    mkdir -p "$D/docs/product-specs"
    cat > "$D/docs/product-specs/spec.md" <<'EOS'
# Product Spec: 동치성 확인

- 상태: draft
EOS
  done
  set +e
  (cd "$BD" && bash scripts/new-exec-plan.sh docs/product-specs/spec.md) > "$TMP/c3-bash.out" 2>&1
  BC=$?
  AI_DEV_STANDARD_ROOT="$ND" node "$ROOT/bin/ai-dev-standard.js" new-exec-plan docs/product-specs/spec.md > "$TMP/c3-node.out" 2>&1
  NC=$?
  set -e
  compare_outputs "계획-미승인거부" "$BC" "$TMP/c3-bash.out" "$NC" "$TMP/c3-node.out"
}

# ── 케이스 4: 승인 명세 → 계획 생성 성공 ──
{
  BD="$TMP/c4-bash"; ND="$TMP/c4-node"
  setup_case "$BD"; mkdir -p "$ND"
  for D in "$BD" "$ND"; do
    mkdir -p "$D/docs/product-specs"
    cat > "$D/docs/product-specs/spec.md" <<'EOS'
# Product Spec: 동치성 확인

- 상태: approved
EOS
  done
  set +e
  (cd "$BD" && bash scripts/new-exec-plan.sh docs/product-specs/spec.md) > "$TMP/c4-bash.out" 2>&1
  BC=$?
  AI_DEV_STANDARD_ROOT="$ND" node "$ROOT/bin/ai-dev-standard.js" new-exec-plan docs/product-specs/spec.md > "$TMP/c4-node.out" 2>&1
  NC=$?
  set -e
  compare_outputs "계획-성공" "$BC" "$TMP/c4-bash.out" "$NC" "$TMP/c4-node.out"
  compare_trees "계획-성공-파일" "$BD" "$ND"
}

echo "동치성: $PASS_COUNT PASS, $FAIL_COUNT FAIL"
if [ "$FAIL_COUNT" -gt 0 ]; then
  echo "PARITY: FAIL" >&2
  exit 1
fi
echo "PARITY: PASS — bash와 Node 구현이 동치성 기준(L1·L2)을 충족했습니다."
