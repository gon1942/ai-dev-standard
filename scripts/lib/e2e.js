"use strict";

// E2E 판정과 프로젝트별 자동 E2E 설정을 명시적으로 해석한다.
// 임의 셸 문자열을 평가하지 않고 command + args 배열만 허용한다.

const fs = require("fs");
const path = require("path");
const { ROOT, sectionInside } = require("./util");

const E2E_METHODS = new Set([
  "자동 Browser E2E",
  "수동 Browser UAT",
  "API/System E2E",
  "CLI E2E",
  "해당 없음",
]);

function value(lines, label) {
  const match = lines.join("\n").match(new RegExp(`^- ${label}: (.+)$`, "m"));
  return match ? match[1].trim() : "";
}

function parseDecision(plan) {
  const versionMatch = plan.match(/^- 검증 계약 버전: (.+)$/m);
  if (!versionMatch) return { legacy: true, unsupported: false };
  if (versionMatch[1].trim() !== "2") return { legacy: false, unsupported: true };

  const lines = sectionInside(plan, /^## E2E 판정$/);
  return {
    legacy: false,
    unsupported: false,
    needed: value(lines, "필요 여부"),
    method: value(lines, "방식"),
    reason: value(lines, "판정 근거"),
    acs: value(lines, "대상 AC"),
    procedure: value(lines, "자동 실행 명령 또는 수동 UAT 시나리오"),
    prerequisites: value(lines, "사전 조건"),
  };
}

function decisionProblems(decision, specAcs) {
  if (decision.legacy) return [];
  const problems = [];
  if (decision.needed !== "필요" && decision.needed !== "불필요") {
    problems.push("E2E 판정의 '필요 여부'는 필요 또는 불필요여야 합니다.");
  }
  if (!E2E_METHODS.has(decision.method)) {
    problems.push("E2E 판정의 '방식' 값이 허용 목록에 없습니다.");
  }
  if (!decision.reason || decision.reason === "해당 없음") {
    problems.push("E2E 판정의 '판정 근거'가 필요합니다.");
  }
  if (!decision.procedure) {
    problems.push("E2E 판정의 자동 실행 명령 또는 수동 UAT 시나리오가 필요합니다.");
  }
  if (!decision.prerequisites) {
    problems.push("E2E 판정의 '사전 조건'이 필요합니다.");
  }

  if (decision.needed === "불필요") {
    if (decision.method !== "해당 없음") {
      problems.push("E2E 불필요 Plan의 방식은 '해당 없음'이어야 합니다.");
    }
    if (decision.acs !== "해당 없음") {
      problems.push("E2E 불필요 Plan의 대상 AC는 '해당 없음'이어야 합니다.");
    }
  }

  if (decision.needed === "필요") {
    if (decision.method === "해당 없음") {
      problems.push("E2E 필요 Plan에는 실제 검증 방식을 지정해야 합니다.");
    }
    const acs = Array.from(new Set(decision.acs.match(/AC-[0-9]+/g) || []));
    if (acs.length === 0) {
      problems.push("E2E 필요 Plan에는 하나 이상의 대상 AC가 필요합니다.");
    } else if (acs.some((ac) => !specAcs.includes(ac))) {
      problems.push("E2E 판정의 대상 AC가 제품 명세에 없습니다.");
    }
  }
  return problems;
}

function isManualUat(decision) {
  return decision.needed === "필요" && decision.method === "수동 Browser UAT";
}

function manualUatEvidenceIsPass(plan) {
  const evidence = sectionInside(plan, /^## E2E 검증 증거$/).join("\n");
  return /^### 수동 UAT /m.test(evidence) &&
    /^- 실행 일시: .+/m.test(evidence) &&
    /^- 관찰 결과: .+/m.test(evidence) &&
    /^- 판정: PASS$/m.test(evidence);
}

// 자동 E2E는 같은 Plan에 재실행 기록이 여럿 남을 수 있다. 과거 PASS가 이후의 FAIL을
// 가리지 않도록 마지막 자동 실행 블록만 현재 증거로 해석한다.
function automaticE2eEvidenceIsPass(plan) {
  const lines = sectionInside(plan, /^## E2E 검증 증거$/);
  const starts = [];
  for (let index = 0; index < lines.length; index += 1) {
    if (/^### 자동 E2E 실행 /.test(lines[index])) starts.push(index);
  }
  if (starts.length === 0) return false;
  const block = lines.slice(starts.at(-1)).join("\n");
  return /^- 종료 코드: 0$/m.test(block) &&
    /^- 결과 요약: PASS \(test e2e 종료 코드 기준; 전체 출력은 기록하지 않음\)$/m.test(block);
}

function e2eConfigPath() {
  return path.join(ROOT, ".ai-dev-standard", "e2e.json");
}

function loadE2EConfig() {
  const file = e2eConfigPath();
  if (!fs.existsSync(file)) return { status: "missing", file };
  try {
    const config = JSON.parse(fs.readFileSync(file, "utf8"));
    if (
      !config ||
      typeof config.command !== "string" ||
      config.command.trim() === "" ||
      !Array.isArray(config.args) ||
      config.args.some((arg) => typeof arg !== "string")
    ) {
      return { status: "invalid", file, message: "command 문자열과 args 문자열 배열이 필요합니다." };
    }
    return { status: "ok", file, command: config.command, args: config.args };
  } catch (error) {
    return { status: "invalid", file, message: `JSON 파싱 실패: ${error.message}` };
  }
}

module.exports = {
  parseDecision,
  decisionProblems,
  isManualUat,
  manualUatEvidenceIsPass,
  automaticE2eEvidenceIsPass,
  loadE2EConfig,
};
