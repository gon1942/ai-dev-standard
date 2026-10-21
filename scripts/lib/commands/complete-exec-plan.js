"use strict";

// complete-exec-plan — scripts/complete-exec-plan.sh 원본의 Node 이식.

const fs = require("fs");
const path = require("path");
const { ROOT, fail } = require("../util");

function run(args) {
  if (args.length !== 2 || !fs.existsSync(path.resolve(ROOT, args[0])) || !args[1]) {
    fail("사용법: scripts/complete-exec-plan.sh <active-실행계획> <승인자>", 2);
  }
  const planFile = args[0];
  const approver = args[1];
  if (!planFile.startsWith("docs/exec-plans/active/")) {
    fail("active 실행 계획만 완료할 수 있습니다.", 2);
  }
  const planAbs = path.resolve(ROOT, planFile);
  const plan = fs.readFileSync(planAbs, "utf8");
  if (!/^- 상태: READY_FOR_REVIEW$/m.test(plan)) {
    fail("READY_FOR_REVIEW 상태의 실행 계획만 완료할 수 있습니다.", 2);
  }

  const completedDir = path.join(ROOT, "docs", "exec-plans", "completed");
  fs.mkdirSync(completedDir, { recursive: true });
  const targetRel = `docs/exec-plans/completed/${path.basename(planFile)}`;
  const targetAbs = path.join(completedDir, path.basename(planFile));
  if (fs.existsSync(targetAbs)) {
    fail(`완료 실행 계획이 이미 존재합니다: ${targetRel}`, 1);
  }

  const updated = plan.replace(/^- 상태: READY_FOR_REVIEW$/m, "- 상태: done") + `\n- 완료 승인: ${approver}\n`;
  fs.writeFileSync(planAbs, updated, "utf8");
  fs.renameSync(planAbs, targetAbs);
  process.stdout.write(`실행 계획 완료: ${targetRel}\n`);
}

module.exports = { run };
