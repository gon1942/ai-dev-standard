"use strict";

// record-verification-evidence — 검증 실행 증거를 활성 Exec Plan에 자동 기록한다.
// 기본 verify-plan은 계속 읽기 전용이며, 이 명령만 계획 파일을 변경한다.

const path = require("path");
const { spawnSync } = require("child_process");
const { ROOT, appendSectionEntry } = require("../util");
const { resolveActivePlan, sourceState } = require("../evidence");

const CLI = path.resolve(__dirname, "..", "cli.js");

function usage() {
  process.stderr.write(
    "사용법: node scripts/lib/cli.js record-verification-evidence <docs/exec-plans/active/실행계획.md>\n"
  );
}

function activePlan(args) {
  if (args.length !== 1 || args[0] === "-h" || args[0] === "--help") {
    usage();
    process.exit(args.length === 1 ? 0 : 2);
  }
  return resolveActivePlan(args, "사용법: node scripts/lib/cli.js record-verification-evidence <docs/exec-plans/active/실행계획.md>");
}

function markdownCode(value) {
  return String(value).replace(/`/g, "\\`");
}

function appendEvidence(planAbs, planFile, exitCode, sourceLines) {
  const timestamp = new Date().toISOString();
  const result = exitCode === 0 ? "PASS" : "FAIL";
  const entry = [
    `### 실행 ${timestamp}`,
    `- 실행 시각: ${timestamp}`,
    `- 실행 명령: \`node scripts/lib/cli.js verify-plan ${markdownCode(planFile)}\``,
    `- 종료 코드: ${exitCode}`,
    `- 결과 요약: ${result} (verify-plan 종료 코드 기준; 전체 출력은 기록하지 않음)`,
    ...sourceLines,
  ].join("\n");
  appendSectionEntry(planAbs, "## 자동 검증 증거", entry);
}

function run(args) {
  const { planAbs, planFile } = activePlan(args);
  const state = sourceState(planFile);
  const verify = spawnSync(process.execPath, [CLI, "verify-plan", planFile], {
    cwd: ROOT,
    stdio: "inherit",
  });
  const exitCode = typeof verify.status === "number" ? verify.status : 1;

  try {
    appendEvidence(planAbs, planFile, exitCode, state);
  } catch (error) {
    process.stderr.write(`검증 증거 기록 실패: ${error.message}\n`);
    process.exit(1);
  }

  process.stdout.write(
    `검증 증거 기록: ${planFile} (${exitCode === 0 ? "PASS" : `FAIL, 종료 코드 ${exitCode}`})\n`
  );
  process.exit(exitCode);
}

module.exports = { run };
