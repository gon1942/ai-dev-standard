"use strict";

// converge-plan — scripts/converge-plan.sh 원본의 Node 이식.

const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");
const { ROOT, fail, sectionInside } = require("../util");
const {
  parseDecision,
  isManualUat,
  manualUatEvidenceIsPass,
  automaticE2eEvidenceIsPass,
} = require("../e2e");

// CLI는 모듈 실제 위치 기준으로 찾는다 (AI_DEV_STANDARD_ROOT 오버라이드와 무관).
const CLI = path.resolve(__dirname, "..", "cli.js");

function run(args) {
  if (args.length !== 1) {
    fail("사용법: scripts/converge-plan.sh <docs/exec-plans/active/실행계획.md>", 2);
  }
  const planFile = args[0];
  const planAbs = path.resolve(ROOT, planFile);
  if (!fs.existsSync(planAbs)) {
    fail("사용법: scripts/converge-plan.sh <docs/exec-plans/active/실행계획.md>", 2);
  }
  if (!planFile.startsWith("docs/exec-plans/active/")) {
    fail(`활성 실행 계획 파일을 지정하세요: ${planFile}`, 2);
  }

  const envFile = path.join(ROOT, ".ai-dev-standard.env");
  const envText = fs.existsSync(envFile) ? fs.readFileSync(envFile, "utf8") : "";
  if (!/^AI_DEV_STANDARD_MODE=active$/m.test(envText)) {
    fail(
      "CONVERGENCE: BLOCKED — AI_DEV_STANDARD_MODE=active 설정 후에만 READY_FOR_REVIEW를 판정할 수 있습니다.",
      1
    );
  }

  const plan = fs.readFileSync(planAbs, "utf8");
  if (!/^## 완료 기록$/m.test(plan)) {
    fail("CONVERGENCE: BLOCKED — 완료 기록이 없습니다.", 1);
  }
  if (!/^## AC 판정$/m.test(plan)) {
    fail("CONVERGENCE: BLOCKED — AC 판정 표가 없습니다.", 1);
  }
  if (!/^- 리뷰: PASS$/m.test(plan)) {
    fail("CONVERGENCE: BLOCKED — 리뷰 결과가 PASS가 아닙니다.", 1);
  }

  const acRows = sectionInside(plan, /^## AC 판정$/).filter((line) => /^\| AC-[^|]+ \|/.test(line));
  if (acRows.length === 0) {
    fail("CONVERGENCE: BLOCKED — AC 판정 항목이 없습니다.", 1);
  }
  if (acRows.some((row) => !/^\| AC-[^|]+ \| PASS \| .+ \|$/.test(row))) {
    fail("CONVERGENCE: BLOCKED — 모든 AC는 PASS와 비어 있지 않은 증거를 가져야 합니다.", 1);
  }

  const e2e = parseDecision(plan);
  if (e2e.unsupported) {
    fail("CONVERGENCE: BLOCKED — 지원하지 않는 검증 계약 버전입니다.", 1);
  }
  if (!e2e.legacy && e2e.needed === "필요") {
    if (isManualUat(e2e)) {
      if (!manualUatEvidenceIsPass(plan)) {
        fail("CONVERGENCE: BLOCKED — 수동 UAT E2E 증거가 PASS가 아닙니다.", 1);
      }
    } else {
      if (!automaticE2eEvidenceIsPass(plan)) {
        fail("CONVERGENCE: BLOCKED — 자동 E2E 증거가 PASS가 아닙니다.", 1);
      }
    }
  }

  // bash: scripts/verify-plan.sh — set -e로 실패 전파. node 엔진 호출로 동치.
  const verifyPlan = spawnSync(process.execPath, [CLI, "verify-plan", planFile], {
    stdio: "inherit",
    cwd: ROOT,
  });
  if (verifyPlan.status !== 0) {
    process.exit(verifyPlan.status === null ? 1 : verifyPlan.status);
  }
  process.stdout.write(
    "CONVERGENCE: PASS — 모든 AC, 검증, 리뷰 증거가 충족되었습니다. READY_FOR_REVIEW 선언 가능.\n"
  );
}

module.exports = { run };
