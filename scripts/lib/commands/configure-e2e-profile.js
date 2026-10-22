"use strict";

const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");
const { ROOT, fail } = require("../util");
const { resolveActivePlan } = require("../evidence");
const {
  E2E_PROFILES,
  loadE2EConfig,
  needsAutomaticConfiguration,
  parseDecision,
  parseProfileProposal,
  profileProposalProblems,
} = require("../e2e");
const { packageManager, commandForProfile, filesForProfile } = require("../e2e-profile");

const USAGE = "사용법: node scripts/lib/cli.js configure-e2e-profile <docs/exec-plans/active/실행계획.md> <node-api|playwright|cypress>";

function runExternal(command, args) {
  const result = spawnSync(command, args, { cwd: ROOT, stdio: "inherit", shell: false });
  return !result.error && result.status === 0;
}

function run(args) {
  if (args.length !== 2 || !E2E_PROFILES.has(args[1])) fail(USAGE, 2);
  const { planAbs, planFile } = resolveActivePlan([args[0]], USAGE);
  const profile = args[1];
  const plan = fs.readFileSync(planAbs, "utf8");
  if (!/^- 승인: approved$/m.test(plan)) {
    fail("E2E 프로필 구성은 승인된 Exec Plan에서만 실행할 수 있습니다.", 2);
  }

  const decision = parseDecision(plan);
  if (decision.unsupported || !needsAutomaticConfiguration(decision)) {
    fail("자동 E2E가 필요한 승인 Plan에서만 E2E 프로필을 구성할 수 있습니다.", 2);
  }
  const proposal = parseProfileProposal(plan);
  const specFile = (plan.match(/^- 제품 명세: (.+)$/m) || [])[1];
  if (!specFile || !fs.existsSync(path.join(ROOT, specFile))) {
    fail(`제품 명세를 찾을 수 없습니다: ${specFile || "(없음)"}`, 2);
  }
  const specAcs = Array.from(new Set(fs.readFileSync(path.join(ROOT, specFile), "utf8").match(/AC-[0-9]+/g) || [])).sort();
  const problems = profileProposalProblems(proposal, decision, specAcs);
  if (problems.length > 0) fail(problems[0], 2);
  if (proposal.profile !== profile) {
    fail("요청한 E2E 프로필이 승인된 Plan의 선택 프로필과 일치하지 않습니다.", 2);
  }

  const existing = loadE2EConfig();
  if (existing.status === "ok") {
    process.stdout.write(`E2E 프로필 구성: 기존 설정 재사용 (${planFile})\n`);
    return;
  }
  if (existing.status === "invalid") {
    fail(`기존 E2E 설정 오류로 덮어쓸 수 없습니다: ${existing.message}`, 1);
  }

  const manager = profile === "node-api" ? null : packageManager();
  if (profile !== "node-api" && !manager) {
    fail("E2E 프로필 구성 BLOCKED: package-lock.json, pnpm-lock.yaml, yarn.lock 중 하나가 필요합니다.", 1);
  }
  for (const [command, commandArgs] of commandForProfile(profile, manager)) {
    if (!runExternal(command, commandArgs)) {
      fail(`E2E 프로필 구성 FAIL: ${command} ${commandArgs.join(" ")} 실행 실패 — 부분 설치 상태를 확인한 뒤 재시도하거나 수동 UAT 대안을 사용하세요.`, 1);
    }
  }

  const output = filesForProfile(profile);
  for (const [file, content] of output.files) {
    const filePath = path.join(ROOT, file);
    if (fs.existsSync(filePath)) {
      fail(`기존 ${file}을(를) 덮어쓸 수 없습니다. 설정을 재사용하거나 Plan을 보완하세요.`, 1);
    }
    fs.writeFileSync(filePath, content, "utf8");
  }
  const configDir = path.join(ROOT, ".ai-dev-standard");
  fs.mkdirSync(configDir, { recursive: true });
  fs.writeFileSync(path.join(configDir, "e2e.json"), `${JSON.stringify(output.config, null, 2)}\n`, "utf8");
  process.stdout.write(`E2E 프로필 구성: ${profile} (${planFile})\n`);
}

module.exports = { run };
