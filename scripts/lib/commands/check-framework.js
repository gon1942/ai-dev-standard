"use strict";

// check-framework — scripts/check-framework.sh 원본의 Node 이식.

const fs = require("fs");
const path = require("path");
const { fail } = require("../util");

// 카탈로그는 모듈 실제 위치 기준 (AI_DEV_STANDARD_ROOT 오버라이드와 무관).
const ASSET_CATALOG = path.resolve(__dirname, "..", "..", "..", "docs", "framework-runtime-assets.tsv");

function isSafeRuntimeAssetPath(p) {
  if (!(p.startsWith("scripts/") || p.startsWith("global-hooks/"))) return false;
  const guard = `/${p}/`;
  return !(guard.includes("/../") || guard.includes("/./") || guard.includes("//"));
}

function run(args) {
  let projectDir = ".";
  if (args[0] === "--project-dir" && args[1] && args.length === 2) {
    projectDir = args[1];
  } else if (args.length !== 0) {
    fail("사용법: scripts/check-framework.sh [--project-dir <프로젝트경로>]", 2);
  }
  if (!fs.existsSync(projectDir) || !fs.statSync(projectDir).isDirectory()) {
    fail(`프로젝트 경로가 없습니다: ${projectDir}`, 2);
  }

  const requiredFiles = [
    "AGENTS.md",
    "ARCHITECTURE.md",
    "docs/development-workflow.md",
    "docs/definition-of-done.md",
    "docs/coding-standards.md",
    "docs/testing-policy.md",
    "docs/framework-onboarding.md",
    "docs/framework-manifest.md",
    "docs/framework-runtime-assets.tsv",
    "docs/project-bootstrap.md",
    "docs/project-preflight.md",
    "docs/session-preflight.md",
    "docs/global-session-hooks.md",
    "docs/skill-contracts/standard-plan.md",
    "docs/skill-contracts/standard-implement.md",
    "docs/skill-contracts/standard-verify.md",
    "docs/skill-contracts/standard-review.md",
    "docs/skill-contracts/standard-improve.md",
    "docs/project-constitution.md",
    "docs/design-docs/project-context.md",
    ".ai-dev-standard.env",
  ];
  const requiredDirs = [
    "docs/product-specs",
    "docs/exec-plans/active",
    "docs/exec-plans/completed",
    "docs/design-docs",
    "docs/agent-improvements/candidates",
    "docs/agent-improvements/approved",
    "docs/agent-improvements/rejected",
  ];

  let catalogError = false;
  if (fs.existsSync(ASSET_CATALOG)) {
    for (const rawLine of fs.readFileSync(ASSET_CATALOG, "utf8").split("\n")) {
      const line = rawLine.replace(/\r$/, "");
      const firstTab = line.indexOf("\t");
      const scope = firstTab === -1 ? line : line.slice(0, firstTab);
      if (scope === "" || scope.startsWith("#")) continue;
      if (scope === "target-script" || scope === "target-hook") {
        const rest = firstTab === -1 ? "" : line.slice(firstTab + 1);
        const secondTab = rest.indexOf("\t");
        const assetPath = secondTab === -1 ? rest : rest.slice(0, secondTab);
        if (isSafeRuntimeAssetPath(assetPath)) {
          requiredFiles.push(assetPath);
        } else {
          process.stderr.write(`FAIL catalog: 허용되지 않은 실행 자산 경로: ${assetPath}\n`);
          catalogError = true;
        }
      } else if (scope === "repository-test") {
        // 배포 제외 자산 — 검사 대상 아님
      } else {
        process.stderr.write(`FAIL catalog: 알 수 없는 실행 자산 범위: ${scope}\n`);
        catalogError = true;
      }
    }
  }

  let missing = catalogError;
  process.stdout.write(`=== AI Dev Standard 골격 검사: ${projectDir} ===\n`);
  for (const file of requiredFiles) {
    if (fs.existsSync(path.join(projectDir, file))) {
      process.stdout.write(`PASS file: ${file}\n`);
    } else {
      process.stdout.write(`FAIL file: ${file}\n`);
      missing = true;
    }
  }
  for (const dir of requiredDirs) {
    if (fs.existsSync(path.join(projectDir, dir)) && fs.statSync(path.join(projectDir, dir)).isDirectory()) {
      process.stdout.write(`PASS dir:  ${dir}/\n`);
    } else {
      process.stdout.write(`FAIL dir:  ${dir}/\n`);
      missing = true;
    }
  }

  const envPath = path.join(projectDir, ".ai-dev-standard.env");
  if (fs.existsSync(envPath)) {
    if (/^AI_DEV_STANDARD_MODE=(template|active)$/m.test(fs.readFileSync(envPath, "utf8"))) {
      process.stdout.write("PASS config: AI_DEV_STANDARD_MODE 설정됨\n");
    } else {
      process.stdout.write("FAIL config: AI_DEV_STANDARD_MODE=template 또는 active 필요\n");
      missing = true;
    }
  }

  if (missing) {
    fail("RESULT: FAIL — 누락 항목은 scripts/bootstrap-framework.sh --init으로 생성 후보를 확인하세요.", 1);
  }
  process.stdout.write("RESULT: PASS — 필수 골격이 있습니다. 프로젝트별 설정은 분석·승인 절차로 확인하세요.\n");
}

module.exports = { run };
