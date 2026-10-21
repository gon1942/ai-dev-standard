"use strict";

// 공통 유틸 — Node 엔진(lib/commands/*)이 공유하는 기능.
// bash 스크립트와의 동치성이 검증 기준이다 (scripts/test-parity.sh).

const fs = require("fs");
const path = require("path");

// bash `cd "$(dirname "$0")/.."`와 동일한 루트 결정.
// 기본: 이 모듈 위치의 상위 두 단계(lib/commands → lib → 루트).
// AI_DEV_STANDARD_ROOT 환경변수가 있으면 우선한다 (동치성 시험·적용 도구용 재정의점).
const ROOT = process.env.AI_DEV_STANDARD_ROOT
  ? path.resolve(process.env.AI_DEV_STANDARD_ROOT)
  : path.resolve(__dirname, "..", "..");

// bash: tr ' /' '--' && tr -cd '[:alnum:]가-힣_-' 에 상당하는 안전 파일명 변환.
function safeName(name) {
  return String(name)
    .replace(/[ /]/g, "-")
    .replace(/[^0-9A-Za-z가-힣_-]/g, "");
}

// bash: date +%F / date +%H%M%S (로컬 시간 기준)
function timestamp() {
  const now = new Date();
  const pad = (value, width) => String(value).padStart(width, "0");
  return {
    date: `${now.getFullYear()}-${pad(now.getMonth() + 1, 2)}-${pad(now.getDate(), 2)}`,
    time: `${pad(now.getHours(), 2)}${pad(now.getMinutes(), 2)}${pad(now.getSeconds(), 2)}`,
  };
}

function fail(message, code) {
  process.stderr.write(`${message}\n`);
  process.exit(code);
}

function ensureDir(dirPath) {
  fs.mkdirSync(dirPath, { recursive: true });
}

module.exports = { ROOT, safeName, timestamp, fail, ensureDir };
