"use strict";

const assert = require("assert");
const fs = require("fs");
const os = require("os");
const path = require("path");
const { spawnSync } = require("child_process");
const {
  loadVerificationProfile,
  validateVerificationProfile,
  runVerificationProfile,
  verificationFingerprint,
  isVerificationReady,
} = require("./lib/verification");

const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), "verification-profile-"));

function writeProfile(root, profile) {
  const configDir = path.join(root, ".ai-dev-standard");
  fs.mkdirSync(configDir, { recursive: true });
  fs.writeFileSync(path.join(configDir, "verification.json"), `${JSON.stringify(profile, null, 2)}\n`);
}

function profileFor(root, checks) {
  return {
    schema_version: 1,
    components: [{
      id: "sample",
      paths: ["src/"],
      checks,
    }],
  };
}

try {
  const validRoot = path.join(tempRoot, "valid");
  fs.mkdirSync(validRoot);
  const expectedArg = "value; do-not-run-shell";
  const capture = path.join(validRoot, "captured.txt");
  const validProfile = profileFor(validRoot, [{
    id: "node-test",
    kind: "test",
    command: process.execPath,
    args: ["-e", "require('fs').writeFileSync(process.argv[1], process.argv[2])", capture, expectedArg],
    cwd: ".",
    required: true,
  }]);
  writeProfile(validRoot, validProfile);

  const loaded = loadVerificationProfile(validRoot);
  assert.strictEqual(loaded.status, "ok", "valid profile should load");
  assert.deepStrictEqual(validateVerificationProfile(validProfile), { valid: true, errors: [] });

  const run = runVerificationProfile(validRoot, loaded.profile);
  assert.strictEqual(run.status, "pass", "all required checks should pass");
  assert.strictEqual(run.checks.length, 1);
  assert.strictEqual(run.checks[0].exit_code, 0);
  assert.strictEqual(fs.readFileSync(capture, "utf8"), expectedArg, "arguments must stay separate from a shell");
  assert.strictEqual(fs.existsSync(path.join(validRoot, "do-not-run-shell")), false);

  const badPathProfile = profileFor(validRoot, [{
    id: "escape",
    kind: "test",
    command: process.execPath,
    args: ["--version"],
    cwd: "../outside",
    required: true,
  }]);
  assert.ok(validateVerificationProfile(badPathProfile).errors.some((error) => error.includes("cwd")));

  const noRequiredProfile = profileFor(validRoot, [{
    id: "optional-only",
    kind: "lint",
    command: process.execPath,
    args: ["--version"],
    cwd: ".",
    required: false,
  }]);
  assert.ok(validateVerificationProfile(noRequiredProfile).errors.some((error) => error.includes("required")));

  const multiRoot = path.join(tempRoot, "multi");
  fs.mkdirSync(multiRoot);
  const multiProfile = {
    schema_version: 1,
    components: ["node", "shell"].map((id) => ({
      id,
      paths: [`${id}/`],
      checks: [{
        id: `${id}-test`,
        kind: "test",
        command: process.execPath,
        args: ["-e", "process.exit(0)"],
        cwd: ".",
        required: true,
      }],
    })),
  };
  const multiRun = runVerificationProfile(multiRoot, multiProfile);
  assert.strictEqual(multiRun.status, "pass");
  assert.strictEqual(multiRun.checks.length, 2, "all required components should be run");

  const failingProfile = profileFor(validRoot, [{
    id: "must-fail",
    kind: "test",
    command: process.execPath,
    args: ["-e", "process.exit(7)"],
    cwd: ".",
    required: true,
  }]);
  const failingRun = runVerificationProfile(validRoot, failingProfile);
  assert.strictEqual(failingRun.status, "fail", "a non-zero required check must fail the profile");
  assert.strictEqual(failingRun.checks[0].exit_code, 7);

  const fingerprint1 = verificationFingerprint(validRoot, validProfile);
  fs.writeFileSync(path.join(validRoot, "package.json"), "{}\n");
  const fingerprint2 = verificationFingerprint(validRoot, validProfile);
  assert.ok(fingerprint1 && fingerprint2 && fingerprint1 !== fingerprint2, "manifest changes invalidate readiness fingerprint");

  const readinessDir = path.join(validRoot, ".ai-dev-standard");
  fs.writeFileSync(path.join(readinessDir, "verification-ready.json"), JSON.stringify({
    schema_version: 1,
    fingerprint: fingerprint2,
    result: "pass",
  }));
  writeProfile(validRoot, validProfile);
  assert.strictEqual(isVerificationReady(validRoot).ready, true, "matching successful readiness record is accepted");
  writeProfile(validRoot, failingProfile);
  assert.strictEqual(isVerificationReady(validRoot).ready, false, "profile changes invalidate readiness record");

  const malformedRoot = path.join(tempRoot, "malformed");
  fs.mkdirSync(malformedRoot);
  fs.mkdirSync(path.join(malformedRoot, ".ai-dev-standard"));
  fs.writeFileSync(path.join(malformedRoot, ".ai-dev-standard/verification.json"), "{ invalid");
  assert.strictEqual(loadVerificationProfile(malformedRoot).status, "invalid", "malformed JSON must not be treated as missing");

  process.stdout.write("PASS: verification profile schema, safe execution, multi-component checks, and freshness\n");
} finally {
  fs.rmSync(tempRoot, { recursive: true, force: true });
}
