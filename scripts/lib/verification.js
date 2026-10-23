"use strict";

// Project verification profile loader and runner.

const crypto = require("crypto");
const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");

const PROFILE_PATH = ".ai-dev-standard/verification.json";
const READINESS_PATH = ".ai-dev-standard/verification-ready.json";
const KINDS = new Set(["lint", "typecheck", "test", "build", "system"]);
const FINGERPRINT_INPUTS = [
  "package.json", "package-lock.json", "pnpm-lock.yaml", "yarn.lock", "bun.lockb",
  "pyproject.toml", "requirements.txt", "requirements-dev.txt", "Pipfile", "Pipfile.lock",
  "go.mod", "go.sum", "Cargo.toml", "Cargo.lock", "pom.xml", "build.gradle",
  "build.gradle.kts", "settings.gradle", "settings.gradle.kts", "composer.json",
  "composer.lock", "Dockerfile", "docker-compose.yml", "compose.yml",
];

function isPlainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function safeRelativePath(projectRoot, relativePath) {
  if (typeof relativePath !== "string" || relativePath.length === 0 || path.isAbsolute(relativePath)) return false;
  const resolved = path.resolve(projectRoot, relativePath);
  const relative = path.relative(projectRoot, resolved);
  if (!(relative === "" || (!relative.startsWith(`..${path.sep}`) && relative !== ".."))) return false;

  // Existing symlinks must not redirect a project-relative path outside the project.
  const rootReal = fs.realpathSync(projectRoot);
  let existing = resolved;
  while (!fs.existsSync(existing) && existing !== path.dirname(existing)) existing = path.dirname(existing);
  try {
    const existingReal = fs.realpathSync(existing);
    const realRelative = path.relative(rootReal, existingReal);
    return realRelative === "" || (!realRelative.startsWith(`..${path.sep}`) && realRelative !== ".." && !path.isAbsolute(realRelative));
  } catch {
    return false;
  }
}

function validateVerificationProfile(profile, projectRoot = process.cwd()) {
  const errors = [];
  if (!isPlainObject(profile)) return { valid: false, errors: ["profile must be an object"] };
  if (profile.schema_version !== 1) errors.push("schema_version must be 1");
  if (profile.setup !== undefined && !Array.isArray(profile.setup)) errors.push("setup must be an array when provided");
  const setupIds = new Set();
  for (const [setupIndex, action] of (Array.isArray(profile.setup) ? profile.setup : []).entries()) {
    const where = `setup[${setupIndex}]`;
    if (!isPlainObject(action)) {
      errors.push(`${where} must be an object`);
      continue;
    }
    if (typeof action.id !== "string" || !/^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(action.id)) errors.push(`${where}.id is invalid`);
    else if (setupIds.has(action.id)) errors.push(`${where}.id is duplicated`);
    else setupIds.add(action.id);
    if (typeof action.command !== "string" || !action.command.trim()) errors.push(`${where}.command is required`);
    if (!Array.isArray(action.args) || action.args.some((arg) => typeof arg !== "string")) errors.push(`${where}.args must be an array of strings`);
    const cwd = action.cwd === undefined ? "." : action.cwd;
    if (!safeRelativePath(projectRoot, cwd)) errors.push(`${where}.cwd must remain within the project`);
    if (typeof action.required !== "boolean") errors.push(`${where}.required must be boolean`);
  }
  if (!Array.isArray(profile.components) || profile.components.length === 0) {
    errors.push("components must be a non-empty array");
    return { valid: errors.length === 0, errors };
  }

  const componentIds = new Set();
  const checkIds = new Set();
  for (const [componentIndex, component] of profile.components.entries()) {
    const where = `components[${componentIndex}]`;
    if (!isPlainObject(component)) {
      errors.push(`${where} must be an object`);
      continue;
    }
    if (typeof component.id !== "string" || !/^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(component.id)) {
      errors.push(`${where}.id is invalid`);
    } else if (componentIds.has(component.id)) {
      errors.push(`${where}.id is duplicated`);
    } else {
      componentIds.add(component.id);
    }
    if (!Array.isArray(component.paths) || component.paths.length === 0) {
      errors.push(`${where}.paths must be a non-empty array`);
    } else {
      for (const item of component.paths) {
        const candidate = typeof item === "string" ? item.replace(/[*?].*$/, "") : item;
        if (typeof item !== "string" || !item || !safeRelativePath(projectRoot, candidate || ".")) {
          errors.push(`${where}.paths contains an invalid project-relative path`);
        }
      }
    }
    if (!Array.isArray(component.checks) || component.checks.length === 0) {
      errors.push(`${where}.checks must be a non-empty array`);
      continue;
    }
    let hasRequired = false;
    for (const [checkIndex, check] of component.checks.entries()) {
      const checkWhere = `${where}.checks[${checkIndex}]`;
      if (!isPlainObject(check)) {
        errors.push(`${checkWhere} must be an object`);
        continue;
      }
      if (typeof check.id !== "string" || !/^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(check.id)) {
        errors.push(`${checkWhere}.id is invalid`);
      } else if (checkIds.has(check.id)) {
        errors.push(`${checkWhere}.id is duplicated`);
      } else {
        checkIds.add(check.id);
      }
      if (!KINDS.has(check.kind)) errors.push(`${checkWhere}.kind is unsupported`);
      if (typeof check.command !== "string" || !check.command.trim()) errors.push(`${checkWhere}.command is required`);
      if (!Array.isArray(check.args) || check.args.some((arg) => typeof arg !== "string")) {
        errors.push(`${checkWhere}.args must be an array of strings`);
      }
      const cwd = check.cwd === undefined ? "." : check.cwd;
      if (!safeRelativePath(projectRoot, cwd)) errors.push(`${checkWhere}.cwd must remain within the project`);
      if (typeof check.required !== "boolean") errors.push(`${checkWhere}.required must be boolean`);
      else if (check.required) hasRequired = true;
    }
    if (!hasRequired) errors.push(`${where} must contain at least one required check`);
  }

  return { valid: errors.length === 0, errors };
}

function loadVerificationProfile(projectRoot) {
  const file = path.join(projectRoot, PROFILE_PATH);
  if (!fs.existsSync(file)) return { status: "missing", file };
  let profile;
  try {
    profile = JSON.parse(fs.readFileSync(file, "utf8"));
  } catch (error) {
    return { status: "invalid", file, message: `JSON 파싱 실패: ${error.message}` };
  }
  const validation = validateVerificationProfile(profile, projectRoot);
  if (!validation.valid) return { status: "invalid", file, message: validation.errors.join("; "), errors: validation.errors };
  return { status: "ok", file, profile };
}

function runVerificationProfile(projectRoot, profile) {
  const validation = validateVerificationProfile(profile, projectRoot);
  if (!validation.valid) return { status: "fail", checks: [], errors: validation.errors };

  const checks = [];
  for (const component of profile.components) {
    for (const check of component.checks) {
      const cwd = path.resolve(projectRoot, check.cwd || ".");
      process.stdout.write(`--- ${component.id}/${check.id} (${check.kind}): ${check.command} ${check.args.join(" ")} ---\n`);
      const result = spawnSync(check.command, check.args, { cwd, stdio: "inherit", shell: false });
      const succeeded = !result.error && result.status === 0;
      const item = {
        component_id: component.id,
        check_id: check.id,
        kind: check.kind,
        command: check.command,
        args: check.args,
        cwd: check.cwd || ".",
        required: check.required,
        exit_code: typeof result.status === "number" ? result.status : null,
        status: succeeded ? "pass" : (check.required ? "fail" : "warn"),
      };
      if (result.error) item.error_code = result.error.code || "EXECUTION_ERROR";
      checks.push(item);
      process.stdout.write(`--- ${component.id}/${check.id}: ${item.status.toUpperCase()}${item.exit_code === null ? " (명령 실행 불가)" : ` (exit ${item.exit_code})`} ---\n`);
    }
  }
  const failedRequired = checks.some((check) => check.required && check.status !== "pass");
  const errors = checks.filter((check) => check.required && check.status !== "pass")
    .map((check) => `${check.component_id}/${check.check_id}: ${check.error_code || `exit ${check.exit_code}`}`);
  return { status: failedRequired ? "fail" : "pass", checks, errors };
}

function runBootstrapSetup(projectRoot, profile, onAction = () => {}) {
  const validation = validateVerificationProfile(profile, projectRoot);
  if (!validation.valid) return { status: "fail", actions: [], errors: validation.errors };
  const actions = [];
  for (const action of profile.setup || []) {
    const cwd = path.resolve(projectRoot, action.cwd || ".");
    onAction({ phase: "started", action_id: action.id });
    process.stdout.write(`--- setup/${action.id}: ${action.command} ${action.args.join(" ")} ---\n`);
    const result = spawnSync(action.command, action.args, { cwd, stdio: "inherit", shell: false });
    const succeeded = !result.error && result.status === 0;
    const item = {
      id: action.id,
      command: action.command,
      args: action.args,
      cwd: action.cwd || ".",
      required: action.required,
      exit_code: typeof result.status === "number" ? result.status : null,
      status: succeeded ? "pass" : (action.required ? "fail" : "warn"),
    };
    if (result.error) item.error_code = result.error.code || "EXECUTION_ERROR";
    actions.push(item);
    onAction({ phase: item.status, action: item });
    process.stdout.write(`--- setup/${action.id}: ${item.status.toUpperCase()}${item.exit_code === null ? " (명령 실행 불가)" : ` (exit ${item.exit_code})`} ---\n`);
  }
  const failed = actions.some((action) => action.required && action.status !== "pass");
  const errors = actions.filter((action) => action.required && action.status !== "pass")
    .map((action) => `setup/${action.id}: ${action.error_code || `exit ${action.exit_code}`}`);
  return { status: failed ? "fail" : "pass", actions, errors };
}

function verificationFingerprint(projectRoot, profile) {
  const validation = validateVerificationProfile(profile, projectRoot);
  if (!validation.valid) return null;
  const hash = crypto.createHash("sha256");
  const profileFile = path.join(projectRoot, PROFILE_PATH);
  hash.update("PROFILE\n");
  hash.update(fs.existsSync(profileFile) ? fs.readFileSync(profileFile) : JSON.stringify(profile));
  for (const relativePath of FINGERPRINT_INPUTS) {
    const file = path.join(projectRoot, relativePath);
    hash.update(`\n${relativePath}:`);
    if (fs.existsSync(file) && fs.statSync(file).isFile()) hash.update(fs.readFileSync(file));
    else hash.update("<missing>");
  }
  return hash.digest("hex");
}

function writeVerificationReadiness(projectRoot, profile, planFile) {
  const fingerprint = verificationFingerprint(projectRoot, profile);
  if (!fingerprint) return false;
  const readinessFile = path.join(projectRoot, READINESS_PATH);
  let current = null;
  try {
    current = JSON.parse(fs.readFileSync(readinessFile, "utf8"));
  } catch {
    // Missing or malformed generated status is replaced only after successful checks.
  }
  if (current && current.schema_version === 1 && current.result === "pass" && current.fingerprint === fingerprint) {
    return true;
  }
  fs.mkdirSync(path.dirname(readinessFile), { recursive: true });
  fs.writeFileSync(readinessFile, `${JSON.stringify({
    schema_version: 1,
    result: "pass",
    fingerprint,
    plan: planFile || null,
    verified_at: new Date().toISOString(),
  }, null, 2)}\n`, "utf8");
  return true;
}

function isVerificationReady(projectRoot) {
  const loaded = loadVerificationProfile(projectRoot);
  if (loaded.status !== "ok") return { ready: false, reason: loaded.status === "missing" ? "검증 프로필 없음" : loaded.message };
  const readinessFile = path.join(projectRoot, READINESS_PATH);
  if (!fs.existsSync(readinessFile)) return { ready: false, reason: "검증 준비 실행 기록 없음" };
  let readiness;
  try {
    readiness = JSON.parse(fs.readFileSync(readinessFile, "utf8"));
  } catch (error) {
    return { ready: false, reason: `검증 준비 기록 파싱 실패: ${error.message}` };
  }
  const currentFingerprint = verificationFingerprint(projectRoot, loaded.profile);
  if (readiness.schema_version !== 1 || readiness.result !== "pass" || !currentFingerprint
    || readiness.fingerprint !== currentFingerprint) {
    return { ready: false, reason: "검증 프로필 또는 실행 환경이 준비 완료 기록 이후 변경됨" };
  }
  return { ready: true, fingerprint: currentFingerprint };
}

module.exports = {
  loadVerificationProfile,
  validateVerificationProfile,
  runVerificationProfile,
  runBootstrapSetup,
  verificationFingerprint,
  writeVerificationReadiness,
  isVerificationReady,
};
