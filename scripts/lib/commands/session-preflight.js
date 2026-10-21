"use strict";

// session-preflight — scripts/session-preflight.sh 원본의 Node 이식 (project-preflight 디스패처).

const path = require("path");
const { spawnSync } = require("child_process");

const ROOT = process.env.AI_DEV_STANDARD_FRAMEWORK_ROOT
  ? path.resolve(process.env.AI_DEV_STANDARD_FRAMEWORK_ROOT)
  : path.resolve(__dirname, "..", "..", "..");

// CLI는 모듈 실제 위치 기준 (FRAMEWORK_ROOT와 무관).
const CLI = path.resolve(__dirname, "..", "cli.js");

function usage() {
  process.stderr.write("사용법: scripts/session-preflight.sh [--project-dir <프로젝트경로>] [--start|--status]\n");
}

function run(args) {
  let projectDir = process.cwd();
  let mode = "start";
  for (let i = 0; i < args.length; i += 1) {
    const arg = args[i];
    if (arg === "--project-dir") {
      if (!args[i + 1]) { usage(); process.exit(2); }
      projectDir = args[i + 1]; i += 1;
    } else if (arg === "--start") mode = "start";
    else if (arg === "--status") mode = "status";
    else if (arg === "-h" || arg === "--help") { usage(); process.exit(0); }
    else { usage(); process.exit(2); }
  }

  // bash 원본은 $FRAMEWORK_ROOT/scripts/project-preflight.sh를 exec한다.
  // node 엔진은 동일 플래그로 project-preflight 명령을 실행한다 (엔진 수준 동치).
  const flagArgs =
    mode === "start"
      ? ["project-preflight", "--project-dir", projectDir, "--repair", "--write-report", "--write-session"]
      : ["project-preflight", "--project-dir", projectDir, "--session-status"];
  const result = spawnSync(process.execPath, [CLI, ...flagArgs], {
    stdio: "inherit",
    env: { ...process.env, AI_DEV_STANDARD_FRAMEWORK_ROOT: ROOT },
  });
  process.exit(result.status === null ? 1 : result.status);
}

module.exports = { run };
