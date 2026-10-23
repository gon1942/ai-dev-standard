"use strict";

// review — scripts/review.sh 원본의 Node 이식.

const { spawnSync } = require("child_process");
const fs = require("fs");
const path = require("path");
const { ROOT, sectionInside } = require("../util");
const { computeSourceFingerprint } = require("../evidence");
const {
  parseDecision,
  isManualUat,
  manualUatEvidenceIsPass,
  automaticE2eEvidenceIsPass,
} = require("../e2e");

function extractPlanSummary(planPath) {
  const abs = path.resolve(ROOT, planPath);
  if (!fs.existsSync(abs)) return null;
  const plan = fs.readFileSync(abs, "utf8");
  const purposeMatch = plan.match(/^- 목적: (.+)$/m);
  const purpose = purposeMatch ? purposeMatch[1] : "(계획에 목적 미기입)";
  const specMatch = plan.match(/^- 제품 명세: (.+)$/m);
  const specPath = specMatch ? specMatch[1].trim() : "(계획에 명세 경로 없음)";
  const acRows = sectionInside(plan, /^## AC 판정$/).filter((line) => /^\| AC-[^|]+ \|/.test(line));
  const acTotal = acRows.length;
  const acPass = acRows.filter((row) => /^\| AC-[^|]+ \| PASS \| .+ \|$/.test(row)).length;
  const automaticEvidence = sectionInside(plan, /^## 자동 검증 증거$/);
  let automaticResult = null;
  let automaticExitCode = null;
  for (const line of automaticEvidence) {
    const resultMatch = line.match(/^- 결과 요약: (PASS|FAIL) /);
    const exitMatch = line.match(/^- 종료 코드: (\d+)$/);
    if (resultMatch) automaticResult = resultMatch[1];
    if (exitMatch) automaticExitCode = exitMatch[1];
  }
  const evidenceMatch = plan.match(/^\s*- (\S+ 결과: .+)$/m);
  const verifyLine =
    automaticResult && automaticExitCode !== null
      ? `자동 검증 증거: ${automaticResult} (종료 코드 ${automaticExitCode})`
      : evidenceMatch
        ? evidenceMatch[1]
        : "검증 기록 미기입";
  const e2e = parseDecision(plan);
  let e2eLine = "E2E 판정: 레거시 Plan";
  if (e2e.unsupported) {
    e2eLine = "E2E 판정: 지원하지 않는 검증 계약 버전";
  } else if (!e2e.legacy && e2e.needed === "불필요") {
    e2eLine = "E2E 판정: 불필요";
  } else if (!e2e.legacy && isManualUat(e2e)) {
    e2eLine = `E2E 판정: 수동 Browser UAT — ${manualUatEvidenceIsPass(plan) ? "PASS" : "미검증"}`;
  } else if (!e2e.legacy) {
    e2eLine = `E2E 판정: ${e2e.method} — ${automaticE2eEvidenceIsPass(plan) ? "PASS" : "미검증"}`;
  }
  return { purpose, specPath, acTotal, acPass, verifyLine, e2eLine };
}

function changedPaths(base, baseAvailable) {
  const paths = new Map();
  if (baseAvailable) {
    const diff = spawnSync("git", ["diff", "--name-status", base], { cwd: ROOT, encoding: "utf8" });
    for (const line of (diff.stdout || "").split("\n")) {
      if (!line.trim()) continue;
      const [status, ...parts] = line.split("\t");
      paths.set(parts.join("\t"), status || "M");
    }
  }
  const status = spawnSync("git", ["status", "--short", "--untracked-files=all", "-z"], {
    cwd: ROOT,
    encoding: "utf8",
  });
  const entries = (status.stdout || "").split("\0").filter(Boolean);
  for (const entry of entries) {
    const code = entry.slice(0, 2);
    const file = entry.slice(3);
    if (file) paths.set(file, code.trim() || "??");
  }
  return [...paths.entries()].sort(([a], [b]) => a.localeCompare(b));
}

function run(args) {
  // 인자: [base] [--plan <실행계획>] — base는 기존대로 첫 위치 인자.
  let base = null;
  let planArg = null;
  for (let i = 0; i < args.length; i += 1) {
    if (args[i] === "--plan") {
      if (!args[i + 1]) {
        process.stderr.write("사용법: review [base] [--plan <실행계획>]\n");
        process.exit(2);
      }
      planArg = args[i + 1];
      i += 1;
    } else if (base === null) {
      base = args[i];
    }
  }
  if (base === null) base = "HEAD";

  const verify = spawnSync("git", ["rev-parse", "--verify", "--quiet", `${base}^{commit}`], { cwd: ROOT });
  const baseAvailable = verify.status === 0;
  const baseLabel = baseAvailable ? base : "비교 기준 없음";

  const write = (line) => process.stdout.write(`${line}\n`);

  if (planArg !== null) {
    const summary = extractPlanSummary(planArg);
    if (summary === null) {
      process.stderr.write(`실행 계획 파일을 찾을 수 없습니다: ${planArg}\n`);
      process.exit(2);
    }
    const changes = changedPaths(base, baseAvailable);
    const sourceFingerprint = computeSourceFingerprint(planArg);
    write("=== Review Packet ===");
    write(`[목적] ${summary.purpose}`);
    write(`[제품 명세] ${summary.specPath}`);
    write(`[리뷰 기준] ${baseAvailable ? base : "Git 기준점 확인 불가"}`);
    write(`[검토 지문] ${sourceFingerprint || "확인 불가"}`);
    write(`[변경 파일] ${changes.length}건`);
    if (changes.length === 0) write(" (변경 파일 없음)");
    for (const [file, status] of changes) write(` ${status.padEnd(2)} ${file}`);
    const acPart =
      summary.acTotal === 0 ? "AC 판정 없음" : `AC 판정 ${summary.acPass}/${summary.acTotal} PASS`;
    write(`[결과·검증] ${acPart} · ${summary.verifyLine}`);
    write(`[E2E] ${summary.e2eLine}`);
    write("[검증 재실행] Review 자료 준비는 테스트·검증 명령을 실행하지 않음");
    write("");
  }

  write(`=== 독립 리뷰 절차 (base: ${baseLabel}) ===`);
  write("");
  write(`[Standards Review] git diff ${base} 대상으로 점검한다:`);
  write("");
  write(" 1. 의도한 파일만 변경되었는가 (계획 범위 내)");
  write(" 2. 요청 범위 밖 변경이 없는가");
  write(" 3. 예상치 못한 삭제/이동이 없는가");
  write(" 4. 불필요한 포맷 변경이 없는가");
  write(" 5. debug/TODO/임시 파일 잔존 없는가");
  write(" 6. 의존성/설정 변경이 의도된 것인가");
  write(" 7. 민감정보(키·토큰·.env) 포함 없는가");
  write(" 8. 제품 명세와 실행 계획이 변경과 함께 있는가");
  write(" 9. 불필요한 중복 구현이 없는가 — 기존 기능 탐색·선택 근거 확인");
  write(" 10. 과도한 추상화·불필요한 복잡성이 없는가");
  write("");
  write("[Spec Review] 제품 명세와 실행 계획의 각 AC를 대상으로 점검한다:");
  write(" 1. 각 AC가 실제 구현에 의해 충족됐는가");
  write(" 2. 각 AC에 테스트·수동 확인·측정 중 하나의 증거가 있는가");
  write(" 3. 미검증 AC와 요구사항에서 벗어난 동작이 명시됐는가");
  write(" 4. AC별 판정을 PASS / FAIL / 미검증으로 기록했는가");
  write("");
  write("[Evidence Review] 완료 기록의 각 PASS가 실제 실행 증거와 일치하는가:");
  write(" 1. PASS마다 실행 명령과 종료 코드가 기록돼 있는가");
  write(" 2. 인용한 증거가 그 AC를 판정할 수 있는 검사의 출력인가 (다른 검사의 PASS 전용 금지)");
  write(" 3. 증거 없는 PASS·오인용 인용은 FAIL로 판정하는가");
  write("");
  write("--- diff stat ---");
  if (baseAvailable) {
    const diff = spawnSync("git", ["diff", "--stat", base], { cwd: ROOT, stdio: "inherit" });
    void diff;
  } else {
    write("(git 비교 기준이 없거나 base가 무효함 — git status --short와 현재 작업 트리를 검토하세요)");
  }
  write("");
  write("독립 리뷰어는 Product Spec·Exec Plan·위 변경 범위·검증 증거만 근거로 검토하고, 구현 세션 대화는 전달하지 않는다.");
  write("기본은 단일 리뷰어가 Standards / Spec / Evidence를 한 번씩 검토한다. 별도 병렬 리뷰는 계획에 사유가 있을 때만 사용한다.");
  write("검증 증거가 최신이면 재실행하지 않는다. 소스 변경이나 증거 문제가 확인될 때만 Verify로 되돌린다.");
}

module.exports = { run, changedPaths, extractPlanSummary };
