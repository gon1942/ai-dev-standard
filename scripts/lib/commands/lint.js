"use strict";

// lint — scripts/lint.sh(reference/new-product-spec 시점 원본)의 Node 이식.
// 판정 라인·종료 코드가 bash와 바이트 동치여야 한다: PASS=0, FAIL=1, SKIP(실행 없음)=3.

const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");
const { ROOT } = require("../util");

function toolExists(tool) {
  // bash `command -v` 상당 — 실행 파일이 PATH에 있으면 0.
  const probe = process.platform === "win32" ? spawnSync("where", [tool]) : spawnSync("which", [tool]);
  return probe.status === 0;
}

function run(args) {
  void args;
  let failed = false;
  let ranAny = false;

  const runIfExists = (name, command, cmdArgs) => {
    if (toolExists(command)) {
      process.stdout.write(`--- ${name} ---\n`);
      ranAny = true;
      const result = spawnSync(command, cmdArgs, { stdio: "inherit", cwd: ROOT });
      if (result.status !== 0) failed = true;
    } else {
      process.stdout.write(`--- ${name}: SKIP (도구 없음) ---\n`);
    }
  };

  const exists = (relativePath) => fs.existsSync(path.join(ROOT, relativePath));

  // JS/TS (예: ESLint)
  if (exists(".eslintrc.json") || exists("eslint.config.js") || exists("eslint.config.mjs")) {
    runIfExists("eslint", "npx", ["--no-install", "eslint", ".", "--max-warnings=0"]);
  }

  // Python (예: ruff)
  if (exists("pyproject.toml") || exists(".ruff.toml")) {
    runIfExists("ruff", "ruff", ["check", "."]);
  }

  if (!ranAny) {
    process.stdout.write("=== LINT: SKIP (실행한 검사 없음) ===\n");
    process.exit(3);
  }
  if (!failed) {
    process.stdout.write("=== LINT: PASS ===\n");
    process.exit(0);
  }
  process.stderr.write("=== LINT: FAIL ===\n");
  process.exit(1);
}

module.exports = { run };
