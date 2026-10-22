"use strict";

// duplicate-check — jscpd(5.1+) 내장 기준선 기능을 쓰는 얇은 래퍼.
// 신규 클론(기준선에 없는 지문)만 보고한다 — 경고 방식, 승인을 차단하지 않는다.
// 배경: 기준선 비교 엔진은 jscpd 내장(--changed/--baseline)이므로 자체 개발하지 않는다.

const path = require("path");
const fs = require("fs");
const { spawnSync } = require("child_process");
const { ROOT } = require("../util");

// CLI는 모듈 실제 위치 기준 (AI_DEV_STANDARD_ROOT 오버라이드와 무관).
const CLI = path.resolve(__dirname, "..", "cli.js");

const FORMATS = process.env.AI_DEV_STANDARD_JSCPD_FORMATS || "javascript,typescript,python,bash";
const IGNORE = process.env.AI_DEV_STANDARD_JSCPD_IGNORE || "node_modules,dist,build,.git,coverage,scripts/reference,docs/generated";

function run(args) {
  let updateBaseline = false;
  for (const arg of args) {
    if (arg === "-h" || arg === "--help") {
      process.stderr.write("사용법: node scripts/lib/cli.js duplicate-check [--update-baseline]\n");
      return;
    }
    if (arg === "--update-baseline") {
      updateBaseline = true;
    } else {
      process.stderr.write("사용법: node scripts/lib/cli.js duplicate-check [--update-baseline]\n");
      process.exit(2);
    }
  }

  const baseline = path.join(ROOT, "docs", "generated", "jscpd-baseline.json");
  const gitCheck = spawnSync("git", ["rev-parse", "--is-inside-work-tree"], { cwd: ROOT, encoding: "utf8" });
  const isGitRepo = gitCheck.status === 0 && String(gitCheck.stdout).trim() === "true";

  process.stdout.write("=== 중복 검사 (jscpd) — 기준선 대비 신규 클론 ===\n");

  const jscpdArgs = ["--yes", "jscpd", ".", "--min-tokens", "50", "--format", FORMATS,
    "--ignore", IGNORE, "--reporters", "consoleFull"];
  if (isGitRepo) {
    jscpdArgs.push("--changed", "--baseline", baseline);
    if (updateBaseline) jscpdArgs.push("--update-baseline");
  } else {
    process.stdout.write("git 저장소가 아니어서 기준선 비교 없이 전체 스캔만 수행한다.\n");
  }

  const result = spawnSync("npx", jscpdArgs, { stdio: "inherit", cwd: ROOT });
  if (result.error || result.status === null) {
    process.stderr.write("jscpd 실행 실패 — 네트워크 또는 npx 환경을 확인한다.\n");
    process.exit(1);
  }

  process.stdout.write(
    "감지된 신규 클론이 있으면 재사용/확장/신규 판단과 근거를 완료 기록에 남긴다. 합병 여부는 리뷰에서 판단한다. (경고 방식 — 승인을 차단하지 않는다)\n"
  );
  // 실행 성공(0)과 검사 실행 실패(0 외)를 구분해 전파한다.
  // 클론 발견 자체는 jscpd가 0으로 보고하므로 경고 방식이 유지된다.
  process.exit(result.status);
}

module.exports = { run };
