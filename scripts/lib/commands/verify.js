"use strict";

// verify — scripts/verify.sh 원본의 Node 이식.
// lint·test는 node 엔진(cli.js)을 직접 호출한다 (bash 원본은 lint.sh/test.sh 호출 —
// 양쪽 모두 동일 엔진으로 수렴하며 동치성은 test-parity.sh가 증명한다).

const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");
const { ROOT, fail, parseEnv } = require("../util");

// CLI는 모듈 실제 위치 기준으로 찾는다 (AI_DEV_STANDARD_ROOT 오버라이드와 무관).
const CLI = path.resolve(__dirname, "..", "cli.js");

function toolExists(tool) {
  const probe = process.platform === "win32" ? spawnSync("where", [tool]) : spawnSync("which", [tool]);
  return probe.status === 0;
}

function run(args) {
  void args;
  const configFile = path.join(ROOT, ".ai-dev-standard.env");
  if (!fs.existsSync(configFile)) {
    fail("설정 파일이 없습니다: .ai-dev-standard.env", 2);
  }
  const env = parseEnv(fs.readFileSync(configFile, "utf8"));
  const mode = env.AI_DEV_STANDARD_MODE || "";
  const requireLint = env.AI_DEV_STANDARD_REQUIRE_LINT || "";
  const requireTypecheck = env.AI_DEV_STANDARD_REQUIRE_TYPECHECK || "";
  const requireTest = env.AI_DEV_STANDARD_REQUIRE_TEST || "";

  if (mode !== "template" && mode !== "active") {
    fail("AI_DEV_STANDARD_MODE는 template 또는 active여야 합니다.", 2);
  }
  for (const value of [requireLint, requireTypecheck, requireTest]) {
    if (value !== "true" && value !== "false") {
      fail("필수 검사 설정은 true 또는 false여야 합니다.", 2);
    }
  }

  let failed = false;

  const runCheck = (label, required, command, cmdArgs) => {
    const result = spawnSync(command, cmdArgs, { stdio: "inherit", cwd: ROOT });
    const code = result.status;
    if (code === 0) return;
    if (mode === "template") {
      process.stdout.write(`--- ${label}: 템플릿 모드에서는 미구성 검사를 차단하지 않음 ---\n`);
      return;
    }
    if (code === 3 && required === "false") {
      process.stdout.write(`--- ${label}: 선택 검사 미구성 ---\n`);
      return;
    }
    failed = true;
  };

  process.stdout.write("==========================================\n");
  process.stdout.write(" verify.sh — 로컬 표준 검증\n");
  process.stdout.write("==========================================\n");

  process.stdout.write("\n[1/3] Lint\n");
  runCheck("Lint", requireLint, process.execPath, [CLI, "lint"]);

  process.stdout.write("\n[2/3] TypeCheck\n");
  // PLACEHOLDER: 프로젝트 타입체커로 교체 (현재: tsconfig 있으면 tsc --noEmit)
  let tcDone = false;
  if (fs.existsSync(path.join(ROOT, "tsconfig.json")) && toolExists("npx")) {
    const tsc = spawnSync("npx", ["--no-install", "tsc", "--noEmit"], { stdio: "inherit", cwd: ROOT });
    if (tsc.status === 0) {
      process.stdout.write("=== TYPECHECK: PASS ===\n");
    } else {
      process.stderr.write("=== TYPECHECK: FAIL ===\n");
      failed = true;
    }
    tcDone = true;
  }
  if (!tcDone) {
    if (mode === "template") {
      process.stdout.write("--- TypeCheck: 템플릿 모드에서는 미구성 검사를 차단하지 않음 ---\n");
    } else if (requireTypecheck === "true") {
      process.stderr.write("=== TYPECHECK: SKIP (필수 검사 미구성) ===\n");
      failed = true;
    } else {
      process.stdout.write("--- TypeCheck: 선택 검사 미구성 ---\n");
    }
  }

  process.stdout.write("\n[3/3] Tests (all)\n");
  runCheck("Tests", requireTest, process.execPath, [CLI, "test", "all"]);

  process.stdout.write("\n==========================================\n");
  if (!failed && mode === "active") {
    process.stdout.write(" RESULT: PASS — READY_FOR_REVIEW 가능\n");
  } else if (!failed) {
    process.stdout.write(" RESULT: TEMPLATE PASS — active 설정 전에는 READY_FOR_REVIEW 불가\n");
  } else {
    process.stderr.write(" RESULT: FAIL — 수정 후 재실행\n");
  }
  process.stdout.write("==========================================\n");
  process.exit(failed ? 1 : 0);
}

module.exports = { run };
