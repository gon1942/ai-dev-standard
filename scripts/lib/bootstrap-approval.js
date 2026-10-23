"use strict";

// Bootstrap approval fingerprint shared by the approval recorder and initializer.

const crypto = require("crypto");
const fs = require("fs");
const path = require("path");

const FINGERPRINT_FIELD = "Bootstrap 승인 내용 지문";

function stripFingerprint(content) {
  return content.replace(new RegExp(`^- ${FINGERPRINT_FIELD}: [^\\r\\n]*\\r?\\n?`, "gm"), "");
}

function approvalPlanContent(content) {
  const mutableSections = new Set(["## TDD 실행 증거", "## 자동 검증 증거", "## 완료 기록", "## AC 판정", "## 리뷰 기록"]);
  const output = [];
  let section = null;
  let omitSection = false;
  for (const line of stripFingerprint(content).split("\n")) {
    if (/^## /.test(line)) {
      section = line.trim();
      omitSection = mutableSections.has(section);
    }
    if (omitSection) continue;
    if (section === "## Task Graph" && line.startsWith("|")) {
      const cells = line.split("|");
      if (cells.length >= 5 && cells[1].trim() !== "Task" && !/^[-: ]*$/.test(cells[1].trim())) {
        cells[cells.length - 2] = " 진행 상태 제외 ";
        output.push(cells.join("|"));
        continue;
      }
    }
    output.push(line);
  }
  return output.join("\n");
}

function computeBootstrapApprovalFingerprint(specPath, planPath, specContent, planContent) {
  const material = [
    `spec:${String(specPath).split(path.sep).join("/")}\n${stripFingerprint(specContent)}`,
    `plan:${String(planPath).split(path.sep).join("/")}\n${approvalPlanContent(planContent)}`,
  ].join("\n\0\n");
  return crypto.createHash("sha256").update(material).digest("hex");
}

function locateApprovalFiles(projectRoot, planFile) {
  const root = path.resolve(projectRoot);
  const planPath = path.resolve(root, planFile);
  const relativePlan = path.relative(root, planPath);
  if (relativePlan.startsWith(`..${path.sep}`) || relativePlan === ".." || path.isAbsolute(relativePlan)) {
    return { error: "Exec Plan 경로가 프로젝트 밖을 가리킵니다." };
  }
  if (!relativePlan.startsWith(`docs${path.sep}exec-plans${path.sep}active${path.sep}`)) {
    return { error: "활성 Exec Plan을 지정하세요." };
  }
  if (!fs.existsSync(planPath)) return { error: `Exec Plan을 찾을 수 없습니다: ${planFile}` };
  const planContent = fs.readFileSync(planPath, "utf8");
  const specMatch = planContent.match(/^- 제품 명세: (.+)$/m);
  if (!specMatch) return { error: "Exec Plan에 제품 명세 경로가 없습니다." };
  const specPath = path.resolve(root, specMatch[1]);
  const relativeSpec = path.relative(root, specPath);
  if (relativeSpec.startsWith(`..${path.sep}`) || relativeSpec === ".." || path.isAbsolute(relativeSpec)) {
    return { error: "Product Spec 경로가 프로젝트 밖을 가리킵니다." };
  }
  if (!fs.existsSync(specPath)) return { error: `Product Spec을 찾을 수 없습니다: ${specMatch[1]}` };
  return {
    specPath,
    planPath,
    specFile: path.relative(root, specPath).split(path.sep).join("/"),
    planFile: relativePlan.split(path.sep).join("/"),
    specContent: fs.readFileSync(specPath, "utf8"),
    planContent,
  };
}

function validateApprovalPair(files) {
  const field = (content, name) => {
    const match = content.match(new RegExp(`^- ${name}: (.*)$`, "m"));
    return match ? match[1].trim() : "";
  };
  if (!/^- 상태: approved$/m.test(files.specContent) || !/^- 승인: approved$/m.test(files.planContent)) {
    return "Product Spec과 Exec Plan이 모두 승인 상태여야 합니다.";
  }
  if (!/^## Bootstrap 검증 프로필$/m.test(files.planContent)) {
    return "Bootstrap 승인 지문은 '## Bootstrap 검증 프로필'이 포함된 Exec Plan에서만 기록할 수 있습니다.";
  }
  const pair = ["사전 승인 묶음", "승인 결정자", "승인 일자"];
  if (pair.some((name) => !field(files.specContent, name) || field(files.specContent, name) !== field(files.planContent, name))) {
    return "Product Spec과 Exec Plan의 승인 기록이 일치하지 않습니다.";
  }
  return null;
}

function approvalFingerprint(files) {
  return computeBootstrapApprovalFingerprint(files.specFile, files.planFile, files.specContent, files.planContent);
}

function verifyBootstrapApproval(projectRoot, planFile) {
  const files = locateApprovalFiles(projectRoot, planFile);
  if (files.error) return { valid: false, message: files.error };
  const pairError = validateApprovalPair(files);
  if (pairError) return { valid: false, message: pairError };
  const specMatches = [...files.specContent.matchAll(new RegExp(`^- ${FINGERPRINT_FIELD}: sha256:([a-f0-9]{64})$`, "gm"))];
  const planMatches = [...files.planContent.matchAll(new RegExp(`^- ${FINGERPRINT_FIELD}: sha256:([a-f0-9]{64})$`, "gm"))];
  const specMatch = specMatches[0];
  const planMatch = planMatches[0];
  if (specMatches.length !== 1 || planMatches.length !== 1 || !specMatch || !planMatch || specMatch[1] !== planMatch[1]) {
    return { valid: false, message: "Product Spec과 Exec Plan의 Bootstrap 승인 내용 지문이 없거나 일치하지 않습니다." };
  }
  const expected = approvalFingerprint(files);
  if (specMatch[1] !== expected) {
    return { valid: false, message: "Bootstrap 승인 내용 지문이 현재 Product Spec/Exec Plan과 다릅니다. 변경된 문서 쌍의 재승인이 필요합니다." };
  }
  return { valid: true, fingerprint: expected, files };
}

function insertFingerprint(content, value) {
  const fieldLine = `- ${FINGERPRINT_FIELD}: sha256:${value}`;
  const fieldPattern = new RegExp(`^- ${FINGERPRINT_FIELD}: .*?$`, "m");
  if (fieldPattern.test(content)) return content.replace(fieldPattern, fieldLine);
  const approvalDate = /^- 승인 일자: .+$/m;
  if (!approvalDate.test(content)) return `${content.trimEnd()}\n${fieldLine}\n`;
  return content.replace(approvalDate, (line) => `${line}\n${fieldLine}`);
}

function recordBootstrapApproval(projectRoot, planFile) {
  const files = locateApprovalFiles(projectRoot, planFile);
  if (files.error) return { ok: false, message: files.error };
  const pairError = validateApprovalPair(files);
  if (pairError) return { ok: false, message: pairError };
  const current = verifyBootstrapApproval(projectRoot, planFile);
  if (current.valid) return { ok: true, fingerprint: current.fingerprint, unchanged: true };
  const readField = (content) => {
    const match = content.match(new RegExp(`^- ${FINGERPRINT_FIELD}: (.*)$`, "m"));
    return match ? match[1].trim() : null;
  };
  const specFingerprint = readField(files.specContent);
  const planFingerprint = readField(files.planContent);
  const initialStamp = (specFingerprint === null && planFingerprint === null)
    || (specFingerprint === "pending" && planFingerprint === "pending");
  if (!initialStamp) {
    return { ok: false, message: "기존 Bootstrap 승인 지문이 현재 문서와 다릅니다. 승인 상태를 무효화하고 수정 문서 쌍을 다시 승인받으세요." };
  }
  const fingerprint = approvalFingerprint(files);
  fs.writeFileSync(files.specPath, insertFingerprint(files.specContent, fingerprint), "utf8");
  fs.writeFileSync(files.planPath, insertFingerprint(files.planContent, fingerprint), "utf8");
  return { ok: true, fingerprint, unchanged: false };
}

module.exports = { recordBootstrapApproval, verifyBootstrapApproval, computeBootstrapApprovalFingerprint };
