"use strict";

// record-verification-evidence — 검증 실행 증거를 활성 Exec Plan에 자동 기록한다.
// 기본 verify-plan은 계속 읽기 전용이며, 이 명령만 계획 파일을 변경한다.

const path = require("path");
const { spawnSync } = require("child_process");
const { ROOT, appendSectionEntry } = require("../util");
const { resolveActivePlan, sourceState, computeSourceFingerprint } = require("../evidence");
const { loadVerificationProfile, writeVerificationReadiness } = require("../verification");

const CLI = path.resolve(__dirname, "..", "cli.js");

function usage() {
  process.stderr.write(
    "사용법: node scripts/lib/cli.js record-verification-evidence <docs/exec-plans/active/실행계획.md> [--fast]\n"
  );
}

function activePlan(args) {
  if (args.length >= 1 && (args[0] === "-h" || args[0] === "--help")) {
    usage();
    process.exit(0);
  }
  const fast = args.includes("--fast");
  if (args.filter((a) => a !== "--fast").length !== 1) {
    usage();
    process.exit(2);
  }
  const { planAbs, planFile } = resolveActivePlan(args.filter((a) => a !== "--fast"), "사용법: node scripts/lib/cli.js record-verification-evidence <docs/exec-plans/active/실행계획.md>");
  return { planAbs, planFile, fast };
}

function markdownCode(value) {
  return String(value).replace(/`/g, "\\`");
}

function appendEvidence(planAbs, planFile, exitCode, sourceLines, fast = false) {
  const timestamp = new Date().toISOString();
  const result = exitCode === 0 ? "PASS" : "FAIL";
  const fingerprint = computeSourceFingerprint(planFile);
  const entry = [
    `### 실행 ${timestamp}`,
    `- 실행 시각: ${timestamp}`,
    `- 실행 명령: \`node scripts/lib/cli.js verify-plan ${markdownCode(planFile)}${fast ? " --fast" : ""}\``,
    `- 종료 코드: ${exitCode}`,
    `- 결과 요약: ${result}${fast ? " (fast — test 체인) " : " "}(verify-plan 종료 코드 기준; 전체 출력은 기록하지 않음)`,
    `- 소스 지문: ${fingerprint ? fingerprint : "확인불가(Git 아님 또는 오류)"}`,
    ...sourceLines,
  ].join("\n");
  appendSectionEntry(planAbs, "## 자동 검증 증거", entry);
}

function run(args) {
  const { planAbs, planFile, fast } = activePlan(args);
  const state = sourceState(planFile);
  const verify = spawnSync(process.execPath, [CLI, "verify-plan", planFile, ...(fast ? ["--fast"] : [])], {
    cwd: ROOT,
    stdio: "inherit",
  });
  let exitCode = typeof verify.status === "number" ? verify.status : 1;

  if (exitCode === 0) {
    const profile = loadVerificationProfile(ROOT);
    if (profile.status === "ok" && !writeVerificationReadiness(ROOT, profile.profile, planFile)) {
      process.stderr.write("검증 준비 상태 기록 실패\n");
      exitCode = 1;
    }
  }

  try {
    appendEvidence(planAbs, planFile, exitCode, state, fast);
  } catch (error) {
    process.stderr.write(`검증 증거 기록 실패: ${error.message}\n`);
    process.exit(1);
  }

  process.stdout.write(
    `검증 증거 기록: ${planFile} (${exitCode === 0 ? (fast ? "PASS (fast — test 체인) — 구현 계속, 완료 전 full 검증 1회 필수" : "PASS — 다음: AC 판정 기록 후 독립 Review") : `FAIL, 종료 코드 ${exitCode} — 수정 후 재실행`})\n`
  );
  process.exit(exitCode);
}

module.exports = { run };
