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

// 계획 파일의 증거 섹션 끝에 재실행 기록을 추가한다. 각 증거 명령이 완료 기록·AC 판정을
// 침범하지 않도록 섹션의 다음 ## 헤딩 바로 앞에만 삽입한다.
function appendSectionEntry(filePath, heading, entry) {
  const content = fs.readFileSync(filePath, "utf8");
  const lines = content.split("\n");
  const headingIndex = lines.findIndex((line) => line === heading);
  if (headingIndex >= 0) {
    let insertAt = headingIndex + 1;
    while (insertAt < lines.length && !/^## /.test(lines[insertAt])) insertAt += 1;
    lines.splice(insertAt, 0, "", entry);
    fs.writeFileSync(filePath, lines.join("\n"), "utf8");
    return;
  }
  fs.appendFileSync(filePath, `${content.endsWith("\n") ? "\n" : "\n\n"}${heading}\n\n${entry}\n`, "utf8");
}

// .ai-dev-standard.env 파싱 — bash `source`와 동일하게 KEY=VALUE 단순 형식만 다룬다.
function parseEnv(text) {
  const result = {};
  for (const line of text.split("\n")) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const eq = trimmed.indexOf("=");
    if (eq > 0) result[trimmed.slice(0, eq)] = trimmed.slice(eq + 1);
  }
  return result;
}

// awk '/^## 제목$/{inside=1; next} /^## /{inside=0} inside {print}' 상당 — 경계 제외.
function sectionInside(content, headingRe) {
  const lines = content.split("\n");
  const out = [];
  let inside = false;
  for (const line of lines) {
    if (headingRe.test(line)) {
      inside = true;
      continue;
    }
    if (/^## /.test(line)) inside = false;
    if (inside) out.push(line);
  }
  return out;
}

// awk '/시작/,/끝/' 상당 — 시작 라인과 끝 라인을 포함한다.
function sectionRange(content, startRe, endRe) {
  const lines = content.split("\n");
  const out = [];
  let started = false;
  for (const line of lines) {
    if (!started) {
      if (startRe.test(line)) {
        started = true;
        out.push(line);
      }
      continue;
    }
    out.push(line);
    if (endRe.test(line)) break;
  }
  return out;
}

module.exports = {
  ROOT,
  safeName,
  timestamp,
  fail,
  ensureDir,
  appendSectionEntry,
  parseEnv,
  sectionInside,
  sectionRange,
};
