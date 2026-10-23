"use strict";

// Materialize and execute the exact verification profile approved in the Exec Plan.

const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");
const { ROOT, fail, parseEnv } = require("../util");
const { resolveActivePlan } = require("../evidence");
const {
  isVerificationReady,
  loadVerificationProfile,
  runBootstrapSetup,
  runVerificationProfile,
  validateVerificationProfile,
  writeVerificationReadiness,
} = require("../verification");
const { verifyBootstrapApproval } = require("../bootstrap-approval");

const CLI = path.resolve(__dirname, "..", "cli.js");
const USAGE = "사용법: node scripts/lib/cli.js configure-verification <docs/exec-plans/active/실행계획.md>";

function extractApprovedProfile(plan) {
  const lines = plan.split("\n");
  const heading = lines.indexOf("## Bootstrap 검증 프로필");
  if (heading < 0) return { error: "승인 Plan에 '## Bootstrap 검증 프로필' 섹션이 없습니다." };
  let start = -1;
  let end = -1;
  for (let index = heading + 1; index < lines.length && !/^## /.test(lines[index]); index += 1) {
    if (start < 0 && /^```json\s*$/.test(lines[index])) start = index + 1;
    else if (start >= 0 && /^```\s*$/.test(lines[index])) {
      end = index;
      break;
    }
  }
  if (start < 0 || end < start) return { error: "Bootstrap 검증 프로필에 완전한 JSON 코드 블록이 필요합니다." };
  try {
    return { profile: JSON.parse(lines.slice(start, end).join("\n")) };
  } catch (error) {
    return { error: `Bootstrap 검증 프로필 JSON 파싱 실패: ${error.message}` };
  }
}

function updateEnvMode(envFile, mode) {
  const original = fs.readFileSync(envFile, "utf8");
  const lines = original.split("\n");
  let found = false;
  const updated = lines.map((line) => {
    if (!/^AI_DEV_STANDARD_MODE=/.test(line)) return line;
    found = true;
    return `AI_DEV_STANDARD_MODE=${mode}`;
  });
  if (!found) fail(".ai-dev-standard.env에 AI_DEV_STANDARD_MODE가 없습니다.", 2);
  fs.writeFileSync(envFile, updated.join("\n"), "utf8");
}

function writeBootstrapStatus(projectRoot, status) {
  const file = path.join(projectRoot, ".ai-dev-standard", "bootstrap-status.json");
  const temporary = `${file}.${process.pid}.tmp`;
  fs.writeFileSync(temporary, `${JSON.stringify({ schema_version: 1, ...status, updated_at: new Date().toISOString() }, null, 2)}\n`, "utf8");
  fs.renameSync(temporary, file);
}

function readBootstrapStatus(projectRoot) {
  try {
    return JSON.parse(fs.readFileSync(path.join(projectRoot, ".ai-dev-standard", "bootstrap-status.json"), "utf8"));
  } catch {
    return null;
  }
}

function run(args) {
  if (args.length !== 1) fail(USAGE, 2);
  const { planAbs, planFile } = resolveActivePlan(args, USAGE);
  const validation = spawnSync(process.execPath, [CLI, "validate-plan", planFile], {
    cwd: ROOT,
    stdio: "inherit",
  });
  if (validation.status !== 0) fail("Bootstrap은 validate-plan을 통과한 승인 Exec Plan에서만 실행할 수 있습니다.", 2);

  const plan = fs.readFileSync(planAbs, "utf8");
  if (!/^- 승인: approved$/m.test(plan)) fail("Bootstrap 설정은 승인된 Exec Plan에서만 실행할 수 있습니다.", 2);
  const approval = verifyBootstrapApproval(ROOT, planFile);
  if (!approval.valid) fail(`Bootstrap 승인 내용 지문 확인 실패: ${approval.message}`, 2);
  const extracted = extractApprovedProfile(plan);
  if (extracted.error) fail(extracted.error, 2);
  const profile = extracted.profile;
  const profileValidation = validateVerificationProfile(profile, ROOT);
  if (!profileValidation.valid) fail(`검증 프로필 오류: ${profileValidation.errors.join("; ")}`, 2);

  const envFile = path.join(ROOT, ".ai-dev-standard.env");
  if (!fs.existsSync(envFile)) fail("설정 파일이 없습니다: .ai-dev-standard.env", 2);
  const env = parseEnv(fs.readFileSync(envFile, "utf8"));
  if (env.AI_DEV_STANDARD_MODE !== "template" && env.AI_DEV_STANDARD_MODE !== "initializing") {
    fail("configure-verification은 template 또는 initializing 상태에서만 실행할 수 있습니다.", 2);
  }

  const profileFile = path.join(ROOT, ".ai-dev-standard", "verification.json");
  fs.mkdirSync(path.dirname(profileFile), { recursive: true });
  if (fs.existsSync(profileFile)) {
    const existing = loadVerificationProfile(ROOT);
    if (existing.status !== "ok" || JSON.stringify(existing.profile) !== JSON.stringify(profile)) {
      fail("기존 검증 프로필이 승인 Plan과 다릅니다. 기존 설정은 덮어쓰지 않았습니다.", 1);
    }
  } else {
    fs.writeFileSync(profileFile, `${JSON.stringify(profile, null, 2)}\n`, "utf8");
  }

  updateEnvMode(envFile, "initializing");
  const previousStatus = readBootstrapStatus(ROOT);
  const attemptHistory = Array.isArray(previousStatus && previousStatus.attempt_history)
    ? [...previousStatus.attempt_history]
    : [];
  if (previousStatus && previousStatus.state !== "complete") {
    attemptHistory.push({
      attempt: previousStatus.attempt || 1,
      state: previousStatus.state,
      stage: previousStatus.stage,
      failed_action: previousStatus.failed_action || null,
      exit_code: previousStatus.exit_code === undefined ? null : previousStatus.exit_code,
      updated_at: previousStatus.updated_at || null,
    });
  }
  const attempt = (previousStatus && previousStatus.attempt ? previousStatus.attempt : 0) + 1;
  const persistStatus = (status) => writeBootstrapStatus(ROOT, { ...status, attempt, attempt_history: attemptHistory });
  const completedActions = [];
  persistStatus({
    plan: planFile,
    approval_fingerprint: approval.fingerprint,
    state: "running",
    stage: "setup",
    current_action: null,
    completed_actions: completedActions,
  });
  const setup = runBootstrapSetup(ROOT, profile, (event) => {
    if (event.phase === "started") {
      persistStatus({
        plan: planFile,
        approval_fingerprint: approval.fingerprint,
        state: "running",
        stage: "setup",
        current_action: event.action_id,
        completed_actions: [...completedActions],
      });
      return;
    }
    if (event.action.status === "pass") completedActions.push(event.action.id);
    if (event.action.status === "fail") {
      persistStatus({
        plan: planFile,
        approval_fingerprint: approval.fingerprint,
        state: "failed",
        stage: "setup",
        current_action: null,
        failed_action: event.action.id,
        exit_code: event.action.exit_code,
        completed_actions: [...completedActions],
      });
    } else {
      persistStatus({
        plan: planFile,
        approval_fingerprint: approval.fingerprint,
        state: "running",
        stage: "setup",
        current_action: null,
        completed_actions: [...completedActions],
      });
    }
  });
  if (setup.status !== "pass") {
    if (!(profile.setup || []).length) {
      persistStatus({
        plan: planFile,
        approval_fingerprint: approval.fingerprint,
        state: "failed",
        stage: "setup",
        current_action: null,
        failed_action: setup.errors[0] || "profile",
        completed_actions: [...completedActions],
      });
    }
    process.stderr.write("초기 설정 작업 실패 — 프로젝트는 initializing 상태로 유지됩니다.\n");
    process.exit(1);
  }
  persistStatus({
    plan: planFile,
    approval_fingerprint: approval.fingerprint,
    state: "running",
    stage: "verification",
    current_action: null,
    completed_actions: [...completedActions],
  });
  const result = runVerificationProfile(ROOT, profile);
  if (result.status !== "pass") {
    persistStatus({
      plan: planFile,
      approval_fingerprint: approval.fingerprint,
      state: "failed",
      stage: "verification",
      current_action: null,
      failed_checks: result.errors,
      completed_actions: [...completedActions],
    });
    process.stderr.write("검증 준비 실패 — 프로젝트는 initializing 상태로 유지됩니다.\n");
    process.exit(1);
  }

  if (!writeVerificationReadiness(ROOT, profile, planFile)) {
    persistStatus({
      plan: planFile,
      approval_fingerprint: approval.fingerprint,
      state: "failed",
      stage: "readiness",
      current_action: null,
      failed_checks: ["검증 프로필 지문 계산 실패"],
      completed_actions: [...completedActions],
    });
    fail("검증 프로필 지문을 계산할 수 없습니다.", 1);
  }
  if (!isVerificationReady(ROOT).ready) {
    persistStatus({
      plan: planFile,
      approval_fingerprint: approval.fingerprint,
      state: "failed",
      stage: "readiness",
      current_action: null,
      failed_checks: ["검증 준비 증거를 현재 설정에서 확인할 수 없습니다"],
      completed_actions: [...completedActions],
    });
    fail("검증 준비 증거를 현재 설정에서 확인할 수 없습니다.", 1);
  }
  updateEnvMode(envFile, "active");
  persistStatus({
    plan: planFile,
    approval_fingerprint: approval.fingerprint,
    state: "complete",
    stage: "complete",
    current_action: null,
    completed_actions: [...completedActions],
  });
  process.stdout.write(`verification configuration ready: ${planFile}\n`);
}

module.exports = { run, extractApprovedProfile };
