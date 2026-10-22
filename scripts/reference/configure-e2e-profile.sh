#!/usr/bin/env bash
# 승인된 Plan의 E2E 프로필만 구성하는 Bash 기준선.
set -euo pipefail
cd "$(dirname "$0")/.."

usage() {
  echo "사용법: node scripts/lib/cli.js configure-e2e-profile <docs/exec-plans/active/실행계획.md> <node-api|playwright|cypress>" >&2
  exit 2
}

[ "$#" -eq 2 ] || usage
PLAN_FILE="$1"
PROFILE="$2"
case "$PLAN_FILE" in docs/exec-plans/active/*) ;; *) echo "활성 실행 계획 파일을 지정하세요: $PLAN_FILE" >&2; exit 2;; esac
[ -f "$PLAN_FILE" ] || { echo "활성 실행 계획 파일을 지정하세요: $PLAN_FILE" >&2; exit 2; }
case "$PROFILE" in node-api|playwright|cypress) ;; *) usage;; esac

grep -Fxq -- '- 승인: approved' "$PLAN_FILE" || { echo "E2E 프로필 구성은 승인된 Exec Plan에서만 실행할 수 있습니다." >&2; exit 2; }
E2E_SECTION="$(awk '/^## E2E 판정$/{inside=1; next} /^## /{inside=0} inside {print}' "$PLAN_FILE")"
value() { printf '%s\n' "$1" | sed -n "s/^- $2: //p" | head -n 1; }
NEEDED="$(value "$E2E_SECTION" '필요 여부')"
METHOD="$(value "$E2E_SECTION" '방식')"
if [ "$NEEDED" != "필요" ] || [ "$METHOD" = "수동 Browser UAT" ] || [ "$METHOD" = "해당 없음" ]; then
  echo "자동 E2E가 필요한 승인 Plan에서만 E2E 프로필을 구성할 수 있습니다." >&2
  exit 2
fi

PROFILE_SECTION="$(awk '/^## E2E 프로필 제안$/{inside=1; next} /^## /{inside=0} inside {print}' "$PLAN_FILE")"
SELECTED="$(value "$PROFILE_SECTION" '선택 프로필')"
[ "$SELECTED" = "$PROFILE" ] || { echo "요청한 E2E 프로필이 승인된 Plan의 선택 프로필과 일치하지 않습니다." >&2; exit 2; }

CONFIG=.ai-dev-standard/e2e.json
if [ -e "$CONFIG" ]; then
  node -e 'JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"))' "$CONFIG" >/dev/null 2>&1 || {
    echo "기존 E2E 설정 오류로 덮어쓸 수 없습니다: JSON 파싱 실패" >&2
    exit 1
  }
  echo "E2E 프로필 구성: 기존 설정 재사용 ($PLAN_FILE)"
  exit 0
fi

if [ "$PROFILE" != "node-api" ]; then
  if [ -f pnpm-lock.yaml ]; then MANAGER=pnpm
  elif [ -f yarn.lock ]; then MANAGER=yarn
  elif [ -f package-lock.json ]; then MANAGER=npm
  else
    echo "E2E 프로필 구성 BLOCKED: package-lock.json, pnpm-lock.yaml, yarn.lock 중 하나가 필요합니다." >&2
    exit 1
  fi
  if [ "$PROFILE" = "playwright" ]; then PACKAGE=@playwright/test; BROWSER=chromium
  else PACKAGE=cypress; BROWSER=""; fi
  if [ "$MANAGER" = npm ]; then
    npm install --save-dev "$PACKAGE" || { echo "E2E 프로필 구성 FAIL: npm install --save-dev $PACKAGE 실행 실패 — 부분 설치 상태를 확인한 뒤 재시도하거나 수동 UAT 대안을 사용하세요." >&2; exit 1; }
    if [ "$PROFILE" = playwright ]; then npx --no-install playwright install "$BROWSER"; else npx --no-install cypress install; fi
  elif [ "$MANAGER" = pnpm ]; then
    pnpm add --save-dev "$PACKAGE" || { echo "E2E 프로필 구성 FAIL: pnpm add --save-dev $PACKAGE 실행 실패 — 부분 설치 상태를 확인한 뒤 재시도하거나 수동 UAT 대안을 사용하세요." >&2; exit 1; }
    if [ "$PROFILE" = playwright ]; then pnpm exec playwright install "$BROWSER"; else pnpm exec cypress install; fi
  else
    yarn add --dev "$PACKAGE" || { echo "E2E 프로필 구성 FAIL: yarn add --dev $PACKAGE 실행 실패 — 부분 설치 상태를 확인한 뒤 재시도하거나 수동 UAT 대안을 사용하세요." >&2; exit 1; }
    if [ "$PROFILE" = playwright ]; then yarn playwright install "$BROWSER"; else yarn cypress install; fi
  fi
  [ "$?" -eq 0 ] || { echo "E2E 프로필 구성 FAIL: 브라우저 도구 설치 실행 실패 — 부분 설치 상태를 확인한 뒤 재시도하거나 수동 UAT 대안을 사용하세요." >&2; exit 1; }
fi

mkdir -p .ai-dev-standard
case "$PROFILE" in
  node-api)
    printf '{\n  "command": "node",\n  "args": [\n    "--test"\n  ]\n}\n' > "$CONFIG"
    ;;
  playwright)
    [ ! -e playwright.config.js ] || { echo "기존 playwright.config.js을(를) 덮어쓸 수 없습니다. 설정을 재사용하거나 Plan을 보완하세요." >&2; exit 1; }
    printf 'module.exports = { testDir: "tests/e2e" };\n' > playwright.config.js
    printf '{\n  "command": "npx",\n  "args": [\n    "--no-install",\n    "playwright",\n    "test"\n  ]\n}\n' > "$CONFIG"
    ;;
  cypress)
    [ ! -e cypress.config.js ] || { echo "기존 cypress.config.js을(를) 덮어쓸 수 없습니다. 설정을 재사용하거나 Plan을 보완하세요." >&2; exit 1; }
    printf 'module.exports = { e2e: { specPattern: "tests/e2e/**/*.cy.{js,ts}" } };\n' > cypress.config.js
    printf '{\n  "command": "npx",\n  "args": [\n    "--no-install",\n    "cypress",\n    "run"\n  ]\n}\n' > "$CONFIG"
    ;;
esac
echo "E2E 프로필 구성: $PROFILE ($PLAN_FILE)"
