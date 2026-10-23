"use strict";

const { sectionInside } = require("./util");

function reviewContractVersion(plan) {
  return (plan.match(/^- 리뷰 계약 버전: (\d+)$/m) || [])[1] || null;
}

function validateReviewEvidence(plan, currentFingerprint) {
  const version = reviewContractVersion(plan);
  if (version === null) {
    return {
      valid: /^- 리뷰: PASS$/m.test(plan),
      legacy: true,
      reason: "레거시 리뷰 결과가 PASS가 아닙니다.",
    };
  }
  if (version !== "1") {
    return { valid: false, legacy: false, reason: `지원하지 않는 리뷰 계약 버전입니다: ${version}` };
  }

  const lines = sectionInside(plan, /^## 리뷰 기록$/);
  const value = (key) => {
    const escaped = key.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    return (lines.join("\n").match(new RegExp(`^- ${escaped}: (.+)$`, "m")) || [])[1]?.trim() || "";
  };

  const requiredFields = [
    ["리뷰어", "리뷰어 식별자가 없습니다."],
    ["검토 기준점", "리뷰 기준점이 없습니다."],
    ["검토 소스 지문", "리뷰 소스 지문이 없습니다."],
    ["발견사항", "리뷰 발견사항 기록이 없습니다."],
  ];
  for (const [key, reason] of requiredFields) {
    if (!value(key) || ["pending", "tbd", "..."].includes(value(key).toLowerCase())) {
      return { valid: false, legacy: false, reason };
    }
  }

  const fingerprint = value("검토 소스 지문");
  if (!/^[a-f0-9]{64}$/.test(fingerprint)) {
    return { valid: false, legacy: false, reason: "리뷰 소스 지문 형식이 잘못되었습니다." };
  }
  if (currentFingerprint !== undefined) {
    if (!currentFingerprint) {
      return { valid: false, legacy: false, reason: "현재 소스 지문을 확인할 수 없습니다." };
    }
    if (fingerprint !== currentFingerprint) {
      return { valid: false, legacy: false, reason: "리뷰 소스 지문이 현재 소스와 일치하지 않습니다." };
    }
  }

  for (const axis of ["Standards Review", "Spec Review", "Evidence Review"]) {
    if (value(axis) !== "PASS") {
      return { valid: false, legacy: false, reason: `${axis}가 PASS가 아닙니다.` };
    }
  }
  if (value("결과") !== "PASS" || value("리뷰") !== "PASS") {
    return { valid: false, legacy: false, reason: "전체 리뷰 결과가 PASS가 아닙니다." };
  }
  return { valid: true, legacy: false, reason: "리뷰 기록과 현재 소스 지문이 일치합니다." };
}

module.exports = { reviewContractVersion, validateReviewEvidence };
