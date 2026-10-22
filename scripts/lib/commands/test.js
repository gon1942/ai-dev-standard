"use strict";

// test — scripts/test.sh 원본의 Node 이식.
// 인자: unit | integration | regression | all (기본 all)
// 판정 라인·종료 코드가 bash와 바이트 동치여야 한다: PASS=0, FAIL=1, SKIP(실행 없음)=3.

const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");
const { ROOT } = require("../util");
const { loadE2EConfig } = require("../e2e");

function toolExists(tool) {
  const probe = process.platform === "win32" ? spawnSync("where", [tool]) : spawnSync("which", [tool]);
  return probe.status === 0;
}

function run(args) {
  const scope = args[0] || "all";
  if (!["unit", "integration", "regression", "e2e", "all"].includes(scope)) {
    process.stderr.write("사용법: test [unit|integration|regression|e2e|all]\n");
    process.exit(2);
  }

  // E2E는 프로젝트가 명시한 command + args 배열만 실행한다. Playwright를 포함한
  // 특정 도구를 탐지·설치하지 않으므로 Node·Python·CLI 프로젝트 모두 같은 경계를 쓴다.
  if (scope === "e2e") {
    const config = loadE2EConfig();
    if (config.status === "missing") {
      process.stdout.write("=== TEST(e2e): SKIP (E2E 설정 없음) ===\n");
      process.exit(3);
    }
    if (config.status === "invalid") {
      process.stderr.write(`=== TEST(e2e): FAIL (E2E 설정 오류: ${config.message}) ===\n`);
      process.exit(1);
    }

    process.stdout.write(`--- E2E (e2e): ${config.command} ${config.args.join(" ")} ---\n`);
    const result = spawnSync(config.command, config.args, { stdio: "inherit", cwd: ROOT, shell: false });
    if (result.error || result.status === null) {
      process.stderr.write("=== TEST(e2e): FAIL (E2E 명령을 실행할 수 없음) ===\n");
      process.exit(1);
    }
    if (result.status === 0) {
      process.stdout.write("=== TEST(e2e): PASS ===\n");
      process.exit(0);
    }
    process.stderr.write(`=== TEST(e2e): FAIL (종료 코드 ${result.status}) ===\n`);
    process.exit(result.status);
  }

  let failed = false;
  let ranAny = false;

  const runTests = (name, command, cmdArgs) => {
    if (toolExists(command)) {
      process.stdout.write(`--- ${name} (${scope}) ---\n`);
      ranAny = true;
      const result = spawnSync(command, cmdArgs, { stdio: "inherit", cwd: ROOT });
      if (result.status !== 0) failed = true;
    }
    // bash run_tests는 도구가 없으면 조용히 지나간다 (SKIP 라인 없음).
  };

  // 프레임워크 원본 전용 회귀 묶음 — 배포 대상에는 test-framework.sh가 없으므로 건너뛴다.
  if (scope !== "unit" && scope !== "integration") {
    const frameworkTest = path.join(ROOT, "scripts", "test-framework.sh");
    if (fs.existsSync(frameworkTest)) {
      runTests("framework regression", "bash", [frameworkTest]);
    }
  }

  // Node (jest)
  if (
    fs.existsSync(path.join(ROOT, "jest.config.js")) ||
    fs.existsSync(path.join(ROOT, "jest.config.cjs")) ||
    fs.existsSync(path.join(ROOT, "jest.config.mjs"))
  ) {
    if (scope === "unit") {
      runTests("jest", "npx", ["--no-install", "jest", "--testPathPattern=tests/unit"]);
    } else if (scope === "integration") {
      runTests("jest", "npx", ["--no-install", "jest", "--testPathPattern=tests/integration"]);
    } else {
      runTests("jest", "npx", ["--no-install", "jest"]);
    }
  }

  // Python (pytest) — bash 원본 조건 그대로:
  // pytest.ini || pyproject.toml || (tests 디렉터리 && pytest 존재)
  const pytestConfigured =
    fs.existsSync(path.join(ROOT, "pytest.ini")) ||
    fs.existsSync(path.join(ROOT, "pyproject.toml")) ||
    (fs.existsSync(path.join(ROOT, "tests")) && toolExists("pytest"));
  if (pytestConfigured) {
    if (scope === "unit") {
      runTests("pytest", "pytest", ["-m", "unit"]);
    } else if (scope === "integration") {
      runTests("pytest", "pytest", ["-m", "integration"]);
    } else {
      runTests("pytest", "pytest", []);
    }
  }

  if (!ranAny) {
    process.stdout.write(`=== TEST(${scope}): SKIP (실행한 테스트 없음) ===\n`);
    process.exit(3);
  }
  if (!failed) {
    process.stdout.write(`=== TEST(${scope}): PASS ===\n`);
    process.exit(0);
  }
  process.stderr.write(`=== TEST(${scope}): FAIL ===\n`);
  process.exit(1);
}

module.exports = { run };
