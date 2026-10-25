"use strict";

// verify-plan — scripts/verify-plan.sh 원본의 Node 이식.

const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");
const { ROOT, fail, sectionInside } = require("../util");

// CLI는 모듈 실제 위치 기준으로 찾는다 (AI_DEV_STANDARD_ROOT 오버라이드와 무관).
const CLI = path.resolve(__dirname, "..", "cli.js");

function run(args) {
  // --fast: 구현 반복용 경량 체인 — verify에 전달한다. 수렴 전 full 1회는 별도 필수.
  const fast = args.includes("--fast");
  const planArgs = args.filter((a) => a !== "--fast");
  if (planArgs.length !== 1 || !fs.existsSync(path.resolve(ROOT, planArgs[0]))) {
    fail("사용법: scripts/verify-plan.sh <docs/exec-plans/active/실행계획.md> [--fast]", 2);
  }
  const planFile = planArgs[0];
  if (!planFile.startsWith("docs/exec-plans/active/")) {
    fail(`활성 실행 계획 파일을 지정하세요: ${planFile}`, 2);
  }
  const plan = fs.readFileSync(path.resolve(ROOT, planFile), "utf8");

  for (const heading of [
    "^# Exec Plan:",
    "^- 제품 명세:",
    "^## 구현 계획$",
    "^## 검증 계획$",
    "^## 회귀 검증 대상$",
  ]) {
    if (!new RegExp(heading, "m").test(plan)) {
      fail(`실행 계획 필수 항목 누락: ${heading}`, 2);
    }
  }

  // bash: bash scripts/verify.sh — node 엔진 호출로 동치 (엔진 수준 동치성).
  const verify = spawnSync(process.execPath, [CLI, "verify", ...(fast ? ["--fast"] : [])], { stdio: "inherit", cwd: ROOT });
  const result = verify.status === null ? 1 : verify.status;

  process.stdout.write("\n");
  process.stdout.write(
    "실행 계획의 검증 계획·회귀 대상을 수행하고 같은 파일에 AC 판정과 증거를 기록하세요:\n"
  );
  // awk A: 검증 계획 헤딩 포함, 회귀 헤딩 미포함
  const lines = plan.split("\n");
  const printFrom = (startRe, stopRe, includeStart) => {
    let show = false;
    for (const line of lines) {
      if (startRe.test(line)) {
        show = true;
        if (includeStart) process.stdout.write(`${line}\n`);
        continue;
      }
      if (show && stopRe.test(line)) break;
      if (show) process.stdout.write(`${line}\n`);
    }
  };
  printFrom(/^## 검증 계획$/, /^## 회귀 검증 대상$/, true);
  // awk B: 회귀 헤딩 포함, 다음 ## 미포함
  printFrom(/^## 회귀 검증 대상$/, /^## (?!회귀 검증 대상$)/, true);

  process.exit(result);
}

module.exports = { run };
