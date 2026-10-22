"use strict";

// validate-plan — scripts/validate-plan.sh 원본의 Node 이식.
// 판정 라인·오류 메시지·종료 코드가 bash와 바이트 동치여야 한다.

const fs = require("fs");
const path = require("path");
const { ROOT, fail, sectionRange, sectionInside } = require("../util");
const {
  parseDecision,
  decisionProblems,
  needsAutomaticConfiguration,
  parseProfileProposal,
  profileProposalProblems,
  loadE2EConfig,
} = require("../e2e");

function run(args) {
  // bash: 인자 1개 + 파일 존재 + docs/exec-plans/active/ 경로 검사
  if (args.length !== 1 || !fs.existsSync(path.resolve(ROOT, args[0]))) {
    fail("사용법: scripts/validate-plan.sh <docs/exec-plans/active/실행계획.md>", 2);
  }
  const planFile = args[0];
  if (!planFile.startsWith("docs/exec-plans/active/")) {
    fail("활성 실행 계획 파일을 지정하세요.", 2);
  }
  const planAbs = path.resolve(ROOT, planFile);
  const plan = fs.readFileSync(planAbs, "utf8");

  const requirePattern = (pattern) => {
    const re = new RegExp(pattern, "m");
    if (!re.test(plan)) {
      fail(`실행 계획 필수 항목 누락: ${pattern}`, 2);
    }
  };

  requirePattern("^# Exec Plan:");
  requirePattern("^- 상태: active$");
  requirePattern("^- 승인: approved$");
  requirePattern("^- 제품 명세: ");
  requirePattern("^## 구현 계획$");
  requirePattern("^## 검증 계획$");
  requirePattern("^## 회귀 검증 대상$");

  // bash: sed -n 's/^- 제품 명세: //p' | head -n 1
  const specMatch = plan.match(/^- 제품 명세: (.*)$/m);
  const specFile = specMatch ? specMatch[1].replace(/^- 제품 명세: /, "") : "";
  if (!specFile || !fs.existsSync(path.resolve(ROOT, specFile))) {
    fail(`제품 명세를 찾을 수 없습니다: ${specFile}`, 2);
  }
  const spec = fs.readFileSync(path.resolve(ROOT, specFile), "utf8");
  if (!/^- 상태: approved$/m.test(spec)) {
    fail(`승인된 제품 명세가 아닙니다: ${specFile}`, 2);
  }

  if (/^- 유형: 버그/m.test(spec)) {
    if (!/^## 재현 조건/m.test(spec)) {
      fail("버그 유형 명세에 '## 재현 조건' 섹션이 필요합니다.", 2);
    }
    const repro = sectionRange(spec, /^## 재현 조건/, /^## /).join("\n");
    if (/^- 재현 불가 사유: .+/m.test(repro)) {
      if (!/^- 대체 판정 방법: .+/m.test(repro)) {
        fail("재현 불가 버그는 '대체 판정 방법'도 명시해야 합니다.", 2);
      }
    } else {
      for (const label of ["동일 입력", "반복 재현 절차", "기대 결과"]) {
        const re = new RegExp(`^- ${label}: .+`, "m");
        if (!re.test(repro)) {
          fail(`버그 재현 조건의 '${label}'이(가) 미작성입니다 (세 항목 모두 필요).`, 2);
        }
      }
    }
  }

  if (/(^|\s)\.\.\./m.test(plan)) {
    fail("실행 계획에 미작성 placeholder(...)가 남아 있습니다.", 2);
  }

  // bash: sed -n '/^## 완료 조건/,/^## /p' | grep -oE 'AC-[0-9]+' | sort -u
  const completionSection = sectionRange(spec, /^## 완료 조건/, /^## /).join("\n");
  const specAcs = Array.from(new Set(completionSection.match(/AC-[0-9]+/g) || [])).sort();
  if (specAcs.length === 0) {
    fail("제품 명세에 Acceptance Criteria가 없습니다.", 2);
  }
  const verifySection = sectionInside(plan, /^## 검증 계획$/).join("\n");
  for (const ac of specAcs) {
    if (!verifySection.includes(ac)) {
      fail(`검증 계획에 명세 AC가 없습니다: ${ac}`, 2);
    }
  }

  const contractVersion = plan.match(/^- 검증 계약 버전: (.+)$/m);
  if (contractVersion && contractVersion[1].trim() !== "2") {
    fail("지원하지 않는 검증 계약 버전입니다.", 2);
  }
  if (contractVersion) {
    const decision = parseDecision(plan);
    const problems = decisionProblems(decision, specAcs);
    if (problems.length > 0) fail(problems[0], 2);
    if (decision.needed === "필요") {
      const e2eAcs = Array.from(new Set(decision.acs.match(/AC-[0-9]+/g) || []));
      for (const ac of e2eAcs) {
        if (!verifySection.includes(ac)) {
          fail(`E2E 판정의 대상 AC가 검증 계획에 없습니다: ${ac}`, 2);
        }
      }
    }
    if (needsAutomaticConfiguration(decision) && loadE2EConfig().status === "missing") {
      const proposalProblems = profileProposalProblems(parseProfileProposal(plan), decision, specAcs);
      if (proposalProblems.length > 0) fail(proposalProblems[0], 2);
    }
  }

  process.stdout.write(`PLAN VALID: ${planFile}\n`);
}

module.exports = { run };
