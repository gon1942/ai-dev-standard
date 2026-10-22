"use strict";

// 증거 기록 명령이 공유하는 활성 Plan 경계와 소스 상태 지문.
// 실행 증거 종류가 달라도 같은 경로 보호·Git 상태 해석을 사용한다.

const crypto = require("crypto");
const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");
const { ROOT, fail } = require("./util");

function normalizeRelative(filePath) {
  return filePath.split(path.sep).join("/");
}

function resolveActivePlan(args, usage) {
  if (args.length !== 1) fail(usage, 2);

  const planAbs = path.resolve(ROOT, args[0]);
  const activeDir = path.resolve(ROOT, "docs", "exec-plans", "active");
  const relative = normalizeRelative(path.relative(ROOT, planAbs));
  const activePrefix = `${normalizeRelative(path.relative(ROOT, activeDir))}/`;
  if (
    !fs.existsSync(planAbs) ||
    !fs.statSync(planAbs).isFile() ||
    relative.startsWith("../") ||
    /[\r\n]/.test(relative) ||
    !relative.startsWith(activePrefix)
  ) {
    fail(`활성 실행 계획 파일을 지정하세요: ${args[0]}`, 2);
  }
  return { planAbs, planFile: relative };
}

function sourceState(planFile) {
  const git = (args) => spawnSync("git", args, { cwd: ROOT, encoding: "utf8" });
  const inGit = git(["rev-parse", "--is-inside-work-tree"]);
  if (inGit.status !== 0 || inGit.stdout.trim() !== "true") {
    return ["- 소스 상태: Git 저장소가 아님 — 미확인"];
  }

  const headResult = git(["rev-parse", "HEAD"]);
  const head = headResult.status === 0 ? headResult.stdout.trim() : "커밋 없음";
  const statusResult = git([
    "-c",
    "core.quotepath=false",
    "status",
    "--porcelain=v1",
    "--untracked-files=all",
  ]);
  if (statusResult.status !== 0) {
    return [`- Git HEAD: ${head}`, "- 작업 트리 상태: 확인 실패 — 미확인"];
  }

  const entries = statusResult.stdout
    .split("\n")
    .filter((line) => line.length > 0)
    .filter((line) => !line.slice(3).split(" -> ").map(normalizeRelative).includes(planFile));
  const digest = crypto.createHash("sha256").update(entries.join("\n"), "utf8").digest("hex");
  return [
    `- Git HEAD: ${head}`,
    `- 작업 트리 식별자(계획 파일 제외): sha256:${digest} (${entries.length}건)`,
  ];
}

module.exports = { resolveActivePlan, sourceState };
