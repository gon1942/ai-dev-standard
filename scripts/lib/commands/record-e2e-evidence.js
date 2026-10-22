"use strict";

// record-e2e-evidence — E2E 판정이 필요한 Plan의 실행 증거를 별도 기록한다.
// 일반 verify 증거와 AC·리뷰·완료 상태는 이 명령이 변경하지 않는다.

const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");
const { ROOT, fail, appendSectionEntry } = require("../util");
const { resolveActivePlan, sourceState } = require("../evidence");
const { parseDecision, isManualUat, manualUatEvidenceIsPass } = require("../e2e");

const CLI = path.resolve(__dirname, "..", "cli.js");

function appendAutomaticEvidence(planAbs, planFile, exitCode) {
  const timestamp = new Date().toISOString();
  const result = exitCode === 0 ? "PASS" : exitCode === 3 ? "SKIP" : "FAIL";
  const entry = [
    `### 자동 E2E 실행 ${timestamp}`,
    `- 실행 시각: ${timestamp}`,
    `- 실행 명령: \`node scripts/lib/cli.js test e2e\``,
    `- 종료 코드: ${exitCode}`,
    `- 결과 요약: ${result} (test e2e 종료 코드 기준; 전체 출력은 기록하지 않음)`,
    ...sourceState(planFile),
  ].join("\n");
  appendSectionEntry(planAbs, "## E2E 검증 증거", entry);
}

function run(args) {
  const { planAbs, planFile } = resolveActivePlan(
    args,
    "사용법: node scripts/lib/cli.js record-e2e-evidence <docs/exec-plans/active/실행계획.md>"
  );
  const plan = fs.readFileSync(planAbs, "utf8");
  const decision = parseDecision(plan);
  if (decision.unsupported) {
    fail("지원하지 않는 검증 계약 버전입니다.", 2);
  }
  if (decision.legacy || decision.needed === "불필요") {
    process.stdout.write("E2E 검증: 실행 불필요\n");
    return;
  }
  if (isManualUat(decision)) {
    if (!manualUatEvidenceIsPass(plan)) {
      process.stderr.write("E2E 검증: BLOCKED — 수동 UAT의 실행 일시·관찰 결과·PASS 판정이 필요합니다.\n");
      process.exit(1);
    }
    process.stdout.write("E2E 검증: PASS — 수동 UAT 증거 확인\n");
    return;
  }

  const result = spawnSync(process.execPath, [CLI, "test", "e2e"], { cwd: ROOT, stdio: "inherit" });
  const exitCode = typeof result.status === "number" ? result.status : 1;
  try {
    appendAutomaticEvidence(planAbs, planFile, exitCode);
  } catch (error) {
    process.stderr.write(`E2E 증거 기록 실패: ${error.message}\n`);
    process.exit(1);
  }
  process.stdout.write(`E2E 검증 증거 기록: ${planFile} (${exitCode === 0 ? "PASS" : `종료 코드 ${exitCode}`})\n`);
  process.exit(exitCode);
}

module.exports = { run };
