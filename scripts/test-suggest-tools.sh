#!/usr/bin/env bash
# 필수 도구 자동 준비: user-site 대신 bootstrap venv를 쓰고 graph build를 하지 않는다.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
FAKE="$TMP/bin"
STATE="$TMP/state"
LOG="$TMP/log"
trap 'rm -rf -- "$TMP"' EXIT
mkdir -p "$FAKE"

cat > "$FAKE/pipx" <<'EOF'
#!/usr/bin/env bash
set -e
if [ "${PIPX_MODE:-missing}" = missing ]; then exit 1; fi
echo "system-pipx:$*:$PIPX_HOME:$PIPX_BIN_DIR" >> "$CRG_TEST_LOG"
if [ "$1" = "--version" ]; then echo 'pipx fixture'; exit 0; fi
if [ "$1" = install ]; then
  mkdir -p "$PIPX_BIN_DIR"
  printf '%s\n' '#!/usr/bin/env bash' "echo 'code-review-graph ${CRG_VERSION:-2.3.9}'" > "$PIPX_BIN_DIR/code-review-graph"
  chmod +x "$PIPX_BIN_DIR/code-review-graph"
fi
EOF
cat > "$FAKE/code-review-graph" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
cat > "$FAKE/python3" <<'EOF'
#!/usr/bin/env bash
set -e
echo "$*" >> "$CRG_TEST_LOG"
if [ "$1" = "-m" ] && [ "$2" = "venv" ]; then
  mkdir -p "$3/bin"
  cat > "$3/bin/python" <<'PYTHON'
#!/usr/bin/env bash
exit 0
PYTHON
  chmod +x "$3/bin/python"
  cat > "$3/bin/pipx" <<'INNER'
#!/usr/bin/env bash
set -e
if [ "$1" = "--version" ]; then echo 'pipx fixture'; exit 0; fi
if [ "$1" = "install" ]; then
  mkdir -p "$PIPX_BIN_DIR"
  cat > "$PIPX_BIN_DIR/code-review-graph" <<'CRG'
#!/usr/bin/env bash
echo 'code-review-graph 2.3.9'
CRG
  chmod +x "$PIPX_BIN_DIR/code-review-graph"
fi
INNER
  chmod +x "$3/bin/pipx"
  exit 0
fi
exit 0
EOF
chmod +x "$FAKE"/*

PATH="$FAKE:$PATH" XDG_STATE_HOME="$STATE" CRG_TEST_LOG="$LOG" \
  node "$ROOT/scripts/lib/cli.js" suggest-tools --install > "$TMP/out"
grep -Fq '프레임워크 전용 pipx bootstrap 설치 완료' "$TMP/out"
grep -Fq 'code-review-graph 2.3.9 설치 완료' "$TMP/out"
[ -x "$STATE/ai-dev-standard/bin/code-review-graph" ] || { echo 'FAIL: CRG가 전용 bin에 없습니다' >&2; exit 1; }
grep -Fq -- '-m venv' "$LOG"
if grep -Fq -- '--user' "$LOG"; then echo 'FAIL: user-site 설치를 시도했습니다' >&2; exit 1; fi
if grep -Eq 'build|update' "$LOG"; then echo 'FAIL: 세션 도구 준비에서 graph를 생성했습니다' >&2; exit 1; fi

# 기존 pipx도 전용 PIPX_HOME/PIPX_BIN_DIR를 받아야 하며, 이미 맞는 버전은 재설치하지 않는다.
before="$(grep -c '^system-pipx:install' "$LOG" 2>/dev/null || true)"
PATH="$FAKE:$PATH" XDG_STATE_HOME="$STATE" CRG_TEST_LOG="$LOG" PIPX_MODE=system \
  node "$ROOT/scripts/lib/cli.js" suggest-tools --install > "$TMP/system.out"
after="$(grep -c '^system-pipx:install' "$LOG" 2>/dev/null || true)"
[ "$before" = "$after" ] || { echo 'FAIL: 맞는 managed CRG를 재설치했습니다' >&2; exit 1; }

# 잘못된 managed 버전은 미설치로 판단해 전용 bin에 다시 설치한다.
printf '%s\n' '#!/usr/bin/env bash' "echo 'code-review-graph 2.3.8'" > "$STATE/ai-dev-standard/bin/code-review-graph"
chmod +x "$STATE/ai-dev-standard/bin/code-review-graph"
PATH="$FAKE:$PATH" XDG_STATE_HOME="$STATE" CRG_TEST_LOG="$LOG" PIPX_MODE=system \
  node "$ROOT/scripts/lib/cli.js" suggest-tools --install > "$TMP/mismatch.out"
grep -Fq 'code-review-graph 2.3.9 설치 완료' "$TMP/mismatch.out"
"$STATE/ai-dev-standard/bin/code-review-graph" --version | grep -Fq '2.3.9'
grep -Fq "system-pipx:install code-review-graph==2.3.9:$STATE/ai-dev-standard/pipx:$STATE/ai-dev-standard/bin" "$LOG"

# work-status는 graph 유무만 읽기 전용으로 보고하며 build/update를 호출하지 않는다.
PROJECT="$TMP/project"
mkdir -p "$PROJECT/docs/exec-plans/active" "$PROJECT/docs/exec-plans/completed"
AI_DEV_STANDARD_ROOT="$PROJECT" PATH="$FAKE:$PATH" node "$ROOT/scripts/lib/cli.js" work-status > "$TMP/graph-none.out"
grep -Fq 'CRG graph: 미생성 — 분석 시점 자동 생성 (설계 동작)' "$TMP/graph-none.out"
mkdir "$PROJECT/.code-review-graph"
AI_DEV_STANDARD_ROOT="$PROJECT" PATH="$FAKE:$PATH" node "$ROOT/scripts/lib/cli.js" work-status > "$TMP/graph-exists.out"
grep -Fq 'CRG graph: 설치됨' "$TMP/graph-exists.out"
if grep -Eq 'build|update' "$LOG"; then echo 'FAIL: work-status가 graph를 변경했습니다' >&2; exit 1; fi
echo 'PASS: CRG bootstrap venv installation is isolated and lazy'
