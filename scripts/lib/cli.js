#!/usr/bin/env node
"use strict";

// 내부 엔진 진입점 — shim(scripts/*.sh)과 bin/ai-dev-standard.js가 공유한다.
// bash 활성 구현과의 동치성은 scripts/test-parity.sh가 reference 기준선으로 증명한다.

const path = require("path");
const commands = {
  "new-product-spec": "./commands/new-product-spec",
  "new-exec-plan": "./commands/new-exec-plan",
  lint: "./commands/lint",
  test: "./commands/test",
  "validate-plan": "./commands/validate-plan",
  verify: "./commands/verify",
  "verify-plan": "./commands/verify-plan",
  "converge-plan": "./commands/converge-plan",
  "check-framework": "./commands/check-framework",
  "analyze-project": "./commands/analyze-project",
  "install-global-session-hooks": "./commands/install-global-session-hooks",
  "prepare-project-context": "./commands/prepare-project-context",
  "plan-framework-apply": "./commands/plan-framework-apply",
  "bootstrap-framework": "./commands/bootstrap-framework",
  "project-preflight": "./commands/project-preflight",
  "session-preflight": "./commands/session-preflight",
};

function runInternalCommand(name, args) {
  const entry = commands[name];
  if (!entry) return false;
  require(path.join(__dirname, entry)).run(args);
  return true;
}

module.exports = { runInternalCommand };

if (require.main === module) {
  const [name, ...rest] = process.argv.slice(2);
  if (!name || !runInternalCommand(name, rest)) {
    process.stderr.write(
      `사용법: node scripts/lib/cli.js <${Object.keys(commands).join("|")}> [인자...]\n`
    );
    process.exit(2);
  }
}
