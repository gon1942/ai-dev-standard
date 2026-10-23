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

// CRG 탐색 기록 검증 — 선택 섹션. 섹션이 없으면 하위 호환으로 통과한다.
function crgRecordProblem(plan) {
  if (!/^## CRG 탐색 기록/m.test(plan)) return null;
  const section = sectionInside(plan, /^## CRG 탐색 기록/).join("\n");
  const field = (name) => {
    const m = section.match(new RegExp(`^- ${name}: (.*)$`, "m"));
    return m ? m[1].trim() : null;
  };
  const stages = field("사용 단계");
  if (stages === null || stages === "" ||
      stages.split(/[\s,]+/).filter(Boolean).some((s) => !["Plan", "Verify", "Review"].includes(s))) {
    return "CRG 탐색 기록의 '사용 단계'는 Plan, Verify, Review 중 하나여야 합니다.";
  }
  const graph = field("graph 상태");
  if (graph === null || !["기존 graph", "build", "update"].includes(graph)) {
    return "CRG 탐색 기록의 'graph 상태'는 기존 graph, build, update 중 하나여야 합니다.";
  }
  for (const name of ["실행 명령", "결과 반영", "원본 소스 교차 확인"]) {
    const value = field(name);
    if (value === null || value === "") {
      return `CRG 탐색 기록의 필수 항목이 없거나 비어 있습니다: ${name}`;
    }
  }
  return null;
}

// Task Graph 검증 — 선택 섹션. 오류 메시지는 bash 참조 구현과 바이트 동치여야 한다.
function taskGraphProblems(plan) {
  const section = sectionInside(plan, /^## Task Graph$/).join("\n");
  const rows = [];
  for (const line of section.split("\n")) {
    if (!line.startsWith("|")) continue;
    const cells = line.split("|").map((c) => c.trim());
    const id = cells[1] || "";
    if (id === "" || id === "Task") continue; // 빈 셀·헤더
    if (/^[-: ]*$/.test(id)) continue; // 구분 행
    rows.push({
      id,
      deps: cells[2] || "",
      status: cells[4] || "",
    });
  }
  if (rows.length === 0) return [];

  const depList = (deps) => {
    const d = deps.trim();
    if (d === "" || d === "—" || d === "해당 없음") return [];
    return d.split(/[\s,]+/).filter(Boolean);
  };

  // 1) Task ID 형식
  for (const r of rows) {
    if (!/^T[0-9]+$/.test(r.id)) {
      return [`Task Graph의 Task ID 형식이 잘못되었습니다: ${r.id}`];
    }
  }
  // 2) 중복 ID
  const seen = new Set();
  for (const r of rows) {
    if (seen.has(r.id)) {
      return [`Task Graph에 중복 Task ID가 있습니다: ${r.id}`];
    }
    seen.add(r.id);
  }
  // 3) 상태 값 (구현 완료와 검증 완료는 구분된 값)
  const STATUS = ["구현 전", "구현 완료", "검증 완료"];
  for (const r of rows) {
    const value = r.status === "" ? "(빈 값)" : r.status;
    if (!STATUS.includes(r.status)) {
      return [`Task Graph의 상태 값이 허용 목록에 없습니다: ${value} (허용: 구현 전, 구현 완료, 검증 완료)`];
    }
  }
  // 4) 의존 참조 유효성
  const ids = new Set(rows.map((r) => r.id));
  for (const r of rows) {
    for (const tok of depList(r.deps)) {
      if (!ids.has(tok)) {
        return [`Task Graph의 의존성이 정의되지 않은 Task를 참조합니다: ${tok}`];
      }
    }
  }
  // 5) 순환 참조
  const deps = new Map(rows.map((r) => [r.id, depList(r.deps)]));
  const visiting = [];
  const visited = new Set();
  let cycle = null;
  const dfs = (node) => {
    if (cycle || visited.has(node)) return;
    const at = visiting.indexOf(node);
    if (at !== -1) {
      cycle = visiting.slice(at).concat(node).join(" -> ");
      return;
    }
    visiting.push(node);
    for (const d of deps.get(node) || []) dfs(d);
    visiting.pop();
    visited.add(node);
  };
  for (const r of rows) {
    dfs(r.id);
    if (cycle) break;
  }
  if (cycle) {
    return [`Task Graph에 순환 참조가 있습니다: ${cycle}`];
  }
  return [];
}

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

  const field = (content, name) => {
    const match = content.match(new RegExp(`^- ${name}: (.*)$`, "m"));
    return match ? match[1].trim() : "";
  };
  const specBundle = field(spec, "사전 승인 묶음");
  const planBundle = field(plan, "사전 승인 묶음");
  if (specBundle || planBundle) {
    if (!specBundle || !planBundle) {
      fail("사전 승인 기록이 명세와 계획 양쪽에 필요합니다.", 2);
    }
    if (!/^PREAPPROVAL-[0-9]{8}-[0-9]{6}$/.test(specBundle) || specBundle !== planBundle) {
      fail("사전 승인 묶음 ID가 명세와 계획에서 일치하지 않습니다.", 2);
    }
    for (const name of ["승인 결정자", "승인 일자"]) {
      const specValue = field(spec, name);
      const planValue = field(plan, name);
      if (!specValue || specValue === "pending" || specValue !== planValue ||
          (name === "승인 일자" && !/^\d{4}-\d{2}-\d{2}$/.test(specValue))) {
        fail("사전 승인 결정자 또는 일자가 양쪽 문서에서 일치하지 않습니다.", 2);
      }
    }
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

  // Task Graph (선택 섹션) — 데이터 행이 없으면 검증을 생략한다.
  {
    const problems = taskGraphProblems(plan);
    if (problems.length > 0) fail(problems[0], 2);
  }

  // CRG 탐색 기록 (선택 섹션) — 사용 시에만 형식을 검사한다. 오류 메시지는 bash 참조와 바이트 동치.
  {
    const problem = crgRecordProblem(plan);
    if (problem) fail(problem, 2);
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
