"use strict";

// decide-improvement — scripts/decide-improvement.sh 원본의 Node 이식.

const fs = require("fs");
const path = require("path");
const { ROOT, fail } = require("../util");

function run(args) {
  if (args.length !== 4 || !fs.existsSync(path.resolve(ROOT, args[1]))) {
    fail("사용법: scripts/decide-improvement.sh <approve|reject> <후보파일> <결정자> <사유>", 2);
  }
  const [decision, candidate, decider, reason] = args;
  let status;
  if (decision === "approve") status = "approved";
  else if (decision === "reject") status = "rejected";
  else {
    fail("결정은 approve 또는 reject여야 합니다.", 2);
  }
  if (!candidate.startsWith("docs/agent-improvements/candidates/")) {
    fail("candidates 경로의 파일만 결정할 수 있습니다.", 2);
  }
  if (candidate.includes("..")) {
    fail("후보 경로에는 상위 디렉터리를 사용할 수 없습니다.", 2);
  }

  const destDirRel = `docs/agent-improvements/${status}`;
  const destDir = path.join(ROOT, destDirRel);
  fs.mkdirSync(destDir, { recursive: true });
  const destRel = `${destDirRel}/${path.basename(candidate)}`;
  const destAbs = path.join(destDir, path.basename(candidate));
  if (fs.existsSync(destAbs)) {
    fail(`결정 대상이 이미 존재합니다: ${destRel}`, 1);
  }

  // bash awk 대체 — 네 개 정확한 라인 패턴만 치환한다.
  const candidateAbs = path.resolve(ROOT, candidate);
  const content = fs
    .readFileSync(candidateAbs, "utf8")
    .split("\n")
    .map((line) => {
      if (line === "- 상태: candidate") return `- 상태: ${status}`;
      if (line === "- 결정: 대기") return `- 결정: ${status}`;
      if (line === "- 결정자: ...") return `- 결정자: ${decider}`;
      if (line === "- 사유: ...") return `- 사유: ${reason}`;
      return line;
    })
    .join("\n");
  fs.writeFileSync(candidateAbs, content, "utf8");
  fs.renameSync(candidateAbs, destAbs);
  process.stdout.write(`개선 후보 ${status}: ${destRel}\n`);
}

module.exports = { run };
