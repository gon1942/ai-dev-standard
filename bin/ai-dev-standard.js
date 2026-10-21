#!/usr/bin/env node
// ai-dev-standard — 공통 개발 표준 프레임워크 CLI (얇은 래퍼)
// 기존 bash 엔진(build-framework-template / plan-framework-apply / bootstrap-framework /
// check-framework / project-preflight)을 재사용한다. dependency 없이 Node 표준 라이브러리만 사용한다.

"use strict";

const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");
const readline = require("readline");

const PKG_ROOT = path.resolve(__dirname, "..");
const TEMPLATE_DIR = path.join(PKG_ROOT, "dist", "template");

const USAGE = `ai-dev-standard — 공통 개발 표준 프레임워크 CLI

사용법:
  ai-dev-standard init <경로>                신규 프로젝트에 프레임워크 골격을 생성한다
  ai-dev-standard apply [옵션]               기존 프로젝트에 적용한다 (분석 → 제안 → 승인 후 골격만 생성)
  ai-dev-standard update [옵션]              적용된 프로젝트의 누락 골격만 보강한다
  ai-dev-standard doctor [옵션]              골격 검사와 프로젝트 준비 상태 검사를 실행한다

옵션:
  --project-dir <경로>   대상 프로젝트 경로 (기본: 현재 디렉터리)
  --yes                  apply에서 골격 생성 확인을 건너뛴다
  -h, --help             이 도움말을 출력한다
  -v, --version          버전을 출력한다

예시:
  npx @gon1942/ai-dev-standard init my-project
  cd existing-project && npx @gon1942/ai-dev-standard apply
  npx @gon1942/ai-dev-standard update --project-dir ../my-project
`;

function fail(message) {
  process.stderr.write(`오류: ${message}\n`);
  process.exit(1);
}

function info(message) {
  process.stdout.write(`${message}\n`);
}

// bash 사용 가능 여부 확인 (Windows는 Git Bash 또는 WSL 필요)
function ensureBash() {
  const probe = spawnSync("bash", ["-c", "exit 0"], { stdio: "ignore" });
  if (probe.error || probe.status !== 0) {
    fail(
      "bash를 찾을 수 없습니다. 이 CLI는 프레임워크의 bash 엔진을 사용합니다.\n" +
        "Windows에서는 Git Bash 또는 WSL 환경에서 실행해 주세요."
    );
  }
}

// bash 스크립트 실행 (stdio 상속으로 사용자에게 그대로 보여준다)
function runBash(scriptPath, args) {
  const result = spawnSync("bash", [scriptPath, ...args], { stdio: "inherit" });
  if (result.error) {
    fail(`스크립트 실행 실패: ${scriptPath} (${result.error.message})`);
  }
  return result.status === 0;
}

// 로컬 개발 사용 시 dist/template이 없으면 배포 템플릿을 빌드한다.
// npm으로 설치한 경우 패키지에 dist/template이 포함되어 있어 이 단계를 건너뛴다.
function ensureTemplate() {
  if (fs.existsSync(path.join(TEMPLATE_DIR, "AGENTS.md"))) return;
  info("배포 템플릿이 없어 빌드합니다 (scripts/build-framework-template.sh)...");
  const ok = runBash(path.join(PKG_ROOT, "scripts", "build-framework-template.sh"), [
    "--output",
    TEMPLATE_DIR,
  ]);
  if (!ok) {
    fail("배포 템플릿 빌드에 실패했습니다.");
  }
}

function resolveProjectDir(options) {
  return path.resolve(options.projectDir || process.cwd());
}

// 확인 프롬프트. 기본값은 거부(N)이다.
function confirm(question) {
  return new Promise((resolvePromise) => {
    const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
    rl.question(`${question} [y/N] `, (answer) => {
      rl.close();
      resolvePromise(answer.trim().toLowerCase() === "y");
    });
  });
}

async function commandInit(destination) {
  if (!destination) fail("init 명령에는 대상 경로가 필요합니다. 예: ai-dev-standard init my-project");
  const dest = path.resolve(destination);
  if (fs.existsSync(dest)) {
    fail(`대상 경로가 이미 존재합니다. 기존 파일을 보호하기 위해 중단합니다: ${dest}`);
  }
  ensureBash();
  ensureTemplate();

  info(`프레임워크 골격을 생성합니다: ${dest}`);
  fs.mkdirSync(path.dirname(dest), { recursive: true });
  fs.cpSync(TEMPLATE_DIR, dest, { recursive: true });

  info("");
  info("완료. 다음 단계:");
  info(`  1. cd ${destination}`);
  info("  2. .ai-dev-standard.env 에서 AI_DEV_STANDARD_MODE=active 로 변경하고 필수 검사를 선택");
  info("  3. grep -rn PLACEHOLDER 로 표시된 항목을 프로젝트 스택에 맞게 수정 (lint.sh, test.sh)");
  info("  4. scripts/verify.sh 를 실행해 필수 검사가 실제로 동작하는지 확인");
  info("  5. 첫 커밋");
}

async function commandApply(options) {
  ensureBash();
  const projectDir = resolveProjectDir(options);
  info(`대상 프로젝트: ${projectDir}`);
  info("");
  info("== 적용 분석 (plan-framework-apply) ==");
  const planned = runBash(path.join(PKG_ROOT, "scripts", "plan-framework-apply.sh"), [
    "--project-dir",
    projectDir,
  ]);
  if (!planned) {
    fail("적용 분석이 실패했습니다. 위 출력을 확인해 주세요.");
  }

  info("");
  const agreed =
    options.yes ||
    (await confirm("위 제안대로 없는 골격만 생성할까요? (기존 파일은 변경하지 않습니다)"));
  if (!agreed) {
    info("골격 생성을 건너뛰었습니다. 다시 적용하려면 이 명령을 다시 실행하세요.");
    return;
  }
  info("");
  info("== 골격 생성 (bootstrap-framework --init) ==");
  const ok = runBash(path.join(PKG_ROOT, "scripts", "bootstrap-framework.sh"), [
    "--project-dir",
    projectDir,
    "--init",
  ]);
  if (!ok) {
    fail("골격 생성이 실패했습니다. 위 출력을 확인해 주세요.");
  }
  info("");
  info("완료. 프로젝트 문맥 확정은 에이전트에게 project-bootstrap 절차를 요청하세요.");
}

async function commandUpdate(options) {
  ensureBash();
  const projectDir = resolveProjectDir(options);
  const envFile = path.join(projectDir, ".ai-dev-standard.env");
  if (!fs.existsSync(envFile)) {
    fail(`프레임워크가 적용되지 않은 프로젝트입니다 (.ai-dev-standard.env 없음): ${projectDir}\n먼저 apply 명령으로 적용해 주세요.`);
  }
  info(`누락 골격만 보강합니다 (기존 파일은 유지): ${projectDir}`);
  const ok = runBash(path.join(PKG_ROOT, "scripts", "bootstrap-framework.sh"), [
    "--project-dir",
    projectDir,
    "--init",
  ]);
  if (!ok) {
    fail("업데이트가 실패했습니다. 위 출력을 확인해 주세요.");
  }
  info("완료.");
}

async function commandDoctor(options) {
  ensureBash();
  const projectDir = resolveProjectDir(options);
  info(`대상 프로젝트: ${projectDir}`);
  info("");
  info("== 골격 검사 (check-framework) ==");
  const skeletonOk = runBash(path.join(PKG_ROOT, "scripts", "check-framework.sh"), [
    "--project-dir",
    projectDir,
  ]);
  info("");
  info("== 프로젝트 준비 상태 검사 (project-preflight) ==");
  const preflightOk = runBash(path.join(PKG_ROOT, "scripts", "project-preflight.sh"), [
    "--project-dir",
    projectDir,
  ]);
  info("");
  info(`결과: 골격 검사 ${skeletonOk ? "PASS" : "FAIL"}, 준비 상태 검사 ${preflightOk ? "PASS" : "FAIL"}`);
  if (!skeletonOk || !preflightOk) process.exit(1);
}

async function main() {
  const argv = process.argv.slice(2);
  const command = argv[0];

  // 첫 인자로 -h/--help, -v/--version이 올 때는 전역 플래그로 먼저 처리한다.
  if (command === "-h" || command === "--help") {
    info(USAGE);
    return;
  }
  if (command === "-v" || command === "--version") {
    const pkg = JSON.parse(fs.readFileSync(path.join(PKG_ROOT, "package.json"), "utf8"));
    info(pkg.version);
    return;
  }

  // 내부 엔진 명령 — bash 스크립트의 Node 이관 구현.
  // 동치성은 scripts/test-parity.sh가 증명한다 (활성 전환 전까지 bash가 기준 구현이다).
  if (command === "new-product-spec" || command === "new-exec-plan") {
    const commandModule = require(path.join(PKG_ROOT, "lib", "commands", command));
    commandModule.run(argv.slice(1));
    return;
  }

  const options = { projectDir: null, yes: false };

  for (let i = 1; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "--project-dir") {
      const next = argv[i + 1];
      if (!next) fail("--project-dir 다음에 경로가 필요합니다.");
      options.projectDir = next;
      i += 1;
    } else if (arg === "--yes") {
      options.yes = true;
    } else if (arg === "-h" || arg === "--help") {
      info(USAGE);
      return;
    } else if (arg === "-v" || arg === "--version") {
      const pkg = JSON.parse(fs.readFileSync(path.join(PKG_ROOT, "package.json"), "utf8"));
      info(pkg.version);
      return;
    } else if (command === "init" && i === 1 && !arg.startsWith("-")) {
      options.destination = arg;
    } else {
      fail(`알 수 없는 인자: ${arg}\n\n${USAGE}`);
    }
  }

  switch (command) {
    case "init":
      await commandInit(options.destination);
      break;
    case "apply":
      await commandApply(options);
      break;
    case "update":
      await commandUpdate(options);
      break;
    case "doctor":
      await commandDoctor(options);
      break;
    case undefined:
      info(USAGE);
      process.exitCode = 2;
      break;
    default:
      fail(`알 수 없는 명령: ${command}\n\n${USAGE}`);
  }
}

main().catch((error) => {
  fail(error && error.message ? error.message : String(error));
});
