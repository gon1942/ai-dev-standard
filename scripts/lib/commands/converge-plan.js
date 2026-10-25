"use strict";

// converge-plan — scripts/converge-plan.sh 원본의 Node 이식.

const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");
const { ROOT, fail, sectionInside } = require("../util");
const { computeSourceFingerprint } = require("../evidence");
const { isVerificationReady, loadVerificationProfile } = require("../verification");
const { validateReviewEvidence } = require("../review-evidence");
const {
  parseDecision,
  isManualUat,
  manualUatEvidenceIsPass,
  automaticE2eEvidenceIsPass,
} = require("../e2e");

// CLI는 모듈 실제 위치 기준으로 찾는다 (AI_DEV_STANDARD_ROOT 오버라이드와 무관).
const CLI = path.resolve(__dirname, "..", "cli.js");

function run(args) {
  if (args.length !== 1) {
    fail("사용법: scripts/converge-plan.sh <docs/exec-plans/active/실행계획.md>", 2);
  }
  const planFile = args[0];
  const planAbs = path.resolve(ROOT, planFile);
  if (!fs.existsSync(planAbs)) {
    fail("사용법: scripts/converge-plan.sh <docs/exec-plans/active/실행계획.md>", 2);
  }
  if (!planFile.startsWith("docs/exec-plans/active/")) {
    fail(`활성 실행 계획 파일을 지정하세요: ${planFile}`, 2);
  }

  const envFile = path.join(ROOT, ".ai-dev-standard.env");
  const envText = fs.existsSync(envFile) ? fs.readFileSync(envFile, "utf8") : "";
  if (!/^AI_DEV_STANDARD_MODE=active$/m.test(envText)) {
    fail(
      "CONVERGENCE: BLOCKED — AI_DEV_STANDARD_MODE=active 설정 후에만 READY_FOR_REVIEW를 판정할 수 있습니다.",
      1
    );
  }

  const verificationProfile = loadVerificationProfile(ROOT);
  if (verificationProfile.status === "invalid") {
    fail(`CONVERGENCE: BLOCKED — 검증 프로필 설정 오류: ${verificationProfile.message}`, 1);
  }
  if (verificationProfile.status === "ok") {
    const readiness = isVerificationReady(ROOT);
    if (!readiness.ready) {
      fail(`CONVERGENCE: BLOCKED — 검증 준비 증거가 없거나 오래되었습니다 (${readiness.reason}).`, 1);
    }
  }

  const plan = fs.readFileSync(planAbs, "utf8");
  if (!/^## 완료 기록$/m.test(plan)) {
    fail("CONVERGENCE: BLOCKED — 완료 기록이 없습니다.", 1);
  }
  if (!/^## AC 판정$/m.test(plan)) {
    fail("CONVERGENCE: BLOCKED — AC 판정 표가 없습니다.", 1);
  }
  const currentFingerprint = computeSourceFingerprint(planFile);
  const review = validateReviewEvidence(plan, currentFingerprint || undefined);
  if (!review.valid) fail(`CONVERGENCE: BLOCKED — ${review.reason}`, 1);

  const acRows = sectionInside(plan, /^## AC 판정$/).filter((line) => /^\| AC-[^|]+ \|/.test(line));
  if (acRows.length === 0) {
    fail("CONVERGENCE: BLOCKED — AC 판정 항목이 없습니다.", 1);
  }
  if (acRows.some((row) => !/^\| AC-[^|]+ \| PASS \| .+ \|$/.test(row))) {
    fail("CONVERGENCE: BLOCKED — 모든 AC는 PASS와 비어 있지 않은 증거를 가져야 합니다.", 1);
  }

  const e2e = parseDecision(plan);
  if (e2e.unsupported) {
    fail("CONVERGENCE: BLOCKED — 지원하지 않는 검증 계약 버전입니다.", 1);
  }
  if (!e2e.legacy && e2e.needed === "필요") {
    if (isManualUat(e2e)) {
      if (!manualUatEvidenceIsPass(plan)) {
        fail("CONVERGENCE: BLOCKED — 수동 UAT E2E 증거가 PASS가 아닙니다.", 1);
      }
    } else {
      if (!automaticE2eEvidenceIsPass(plan)) {
        fail("CONVERGENCE: BLOCKED — 자동 E2E 증거가 PASS가 아닙니다.", 1);
      }
    }
  }

  // ── 지문 비교로 검증 재사용 판정 ──
  // 최신 PASS 증거의 소스 지문이 현재 지문과 일치하면 verify 재실행을 생략한다.
  // 불일치·확인불가 → BLOCKED (record-verification-evidence 재실행 요구).
  const latestFingerprint = extractLatestPassFingerprint(plan);
  if (latestFingerprint && currentFingerprint && latestFingerprint === currentFingerprint) {
    process.stdout.write("=== 최신 PASS 증거 재사용 (소스 지문 일치 — verify 재실행 생략) ===\n");
  } else if (!currentFingerprint) {
    fail(
      "CONVERGENCE: BLOCKED — 소스 지문을 확인할 수 없습니다 (Git 상태 불가).\n" +
        "record-verification-evidence를 다시 실행한 뒤 재시도하세요.",
      1
    );
  } else if (latestFingerprint === "FAST_ONLY") {
    fail(
      "CONVERGENCE: BLOCKED — 최신 PASS 증거가 fast 체인입니다.\n" +
        "수렴 전 full 검증 1회가 필수입니다 — record-verification-evidence를(full) 실행한 뒤 재시도하세요.",
      1
    );
  } else if (!latestFingerprint) {
    fail(
      "CONVERGENCE: BLOCKED — 최신 PASS 증거에 소스 지문이 없습니다 (레거시 형식).\n" +
        "record-verification-evidence를 다시 실행한 뒤 재시도하세요.",
      1
    );
  } else {
    fail(
      "CONVERGENCE: BLOCKED — 소스가 마지막 검증 이후 변경되었습니다 (지문 불일치).\n" +
        "record-verification-evidence를 다시 실행한 뒤 재시도하세요.",
      1
    );
  }

  process.stdout.write(
    "CONVERGENCE: PASS — 모든 AC, 검증, 리뷰 증거가 충족되었습니다. READY_FOR_REVIEW 선언 가능.\n"
  );
}

// 계획 파일에서 최신 full PASS 증거의 소스 지문을 추출한다.
// fast 체인(--fast) 증거는 구현 반복용이다 — 수렴은 full 체인 PASS를 요구한다.
// 레거시 항목(--fast 표기 없음)은 full로 취급한다.
function extractLatestPassFingerprint(plan) {
  const evidenceSection = sectionInside(plan, /^## 자동 검증 증거$/);
  const entries = [];
  let current = null;
  for (const line of evidenceSection) {
    if (line.startsWith("### 실행 ")) current = { lines: [] };
    if (current) current.lines.push(line);
    if (current && !line.trim()) {
      entries.push(current);
      current = null;
    }
  }
  if (current) entries.push(current);

  let sawFastPass = false;
  for (let i = entries.length - 1; i >= 0; i--) {
    const entry = entries[i].lines.join("\n");
    if (!/- 종료 코드: 0/.test(entry)) continue;
    const fast = /--fast/.test(entry);
    if (fast) {
      sawFastPass = true;
      continue;
    }
    if (/- 소스 지문: ([a-f0-9]{64})/.test(entry)) {
      return (entry.match(/- 소스 지문: ([a-f0-9]{64})/) || [])[1] || null;
    }
  }
  if (sawFastPass) return "FAST_ONLY";
  return null;
}

module.exports = { run };
