"use strict";

// Record the agreed content fingerprint immediately after explicit human preapproval.

const path = require("path");
const { spawnSync } = require("child_process");
const { ROOT, fail } = require("../util");
const { recordBootstrapApproval } = require("../bootstrap-approval");

const CLI = path.resolve(__dirname, "..", "cli.js");

function run(args) {
  if (args.length !== 1) fail("사용법: node scripts/lib/cli.js record-bootstrap-approval <활성 실행계획>", 2);
  const planFile = args[0];
  const validation = spawnSync(process.execPath, [CLI, "validate-plan", planFile], { cwd: ROOT, stdio: "inherit" });
  if (validation.status !== 0) fail("유효한 승인 Exec Plan에서만 Bootstrap 승인 지문을 기록할 수 있습니다.", 2);
  const result = recordBootstrapApproval(ROOT, planFile);
  if (!result.ok) fail(result.message, 2);
  process.stdout.write(`Bootstrap 승인 내용 지문 기록: ${result.fingerprint}\n`);
}

module.exports = { run };
