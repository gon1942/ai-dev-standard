"use strict";

// new-improvement-candidate — scripts/new-improvement-candidate.sh 원본의 Node 이식.

const fs = require("fs");
const path = require("path");
const { ROOT, safeName, timestamp, fail, ensureDir } = require("../util");

function run(args) {
  if (args.length !== 4 || !fs.existsSync(path.resolve(ROOT, args[3]))) {
    fail("사용법: scripts/new-improvement-candidate.sh <제목> <문제> <근거> <출처-실행계획>", 2);
  }
  const [title, problem, evidence, sourcePlan] = args;
  let safeTitle = safeName(title);
  if (!safeTitle) safeTitle = "improvement";
  const { date, time } = timestamp();
  const fileRel = `docs/agent-improvements/candidates/${date}-${time}-${safeTitle}.md`;
  const fileAbs = path.join(ROOT, fileRel);
  ensureDir(path.join(ROOT, "docs", "agent-improvements", "candidates"));

  const content = `# Improvement Candidate: ${title}

- 상태: candidate
- 생성: ${date}
- 출처 실행 계획: ${sourcePlan}

## 문제

${problem}

## 근거

${evidence}

## 제안

- ...

## 영향 범위와 위험

- 영향 파일: ...
- 위험: ...

## 사람 결정

- 결정: 대기
- 결정자: ...
- 사유: ...
`;

  fs.writeFileSync(fileAbs, content, "utf8");
  process.stdout.write(`개선 후보 생성: ${fileRel}\n`);
}

module.exports = { run };
