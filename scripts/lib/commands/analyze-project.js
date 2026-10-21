"use strict";

// analyze-project — scripts/analyze-project.sh 원본의 Node 이식.

const fs = require("fs");
const os = require("os");
const path = require("path");
const { fail } = require("../util");

// bash date '+%Y-%m-%d %H:%M:%S %z' 상당.
function bashStyleDate() {
  const now = new Date();
  const p = (n, w) => String(n).padStart(w, "0");
  const offsetMinutes = -now.getTimezoneOffset();
  const sign = offsetMinutes >= 0 ? "+" : "-";
  const abs = Math.abs(offsetMinutes);
  const offset = `${sign}${p(Math.floor(abs / 60), 2)}${p(abs % 60, 2)}`;
  return (
    `${now.getFullYear()}-${p(now.getMonth() + 1, 2)}-${p(now.getDate(), 2)} ` +
    `${p(now.getHours(), 2)}:${p(now.getMinutes(), 2)}:${p(now.getSeconds(), 2)} ${offset}`
  );
}

function buildInventory(projectDir) {
  const out = [];
  const write = (line) => out.push(line);
  const exists = (relativePath) => fs.existsSync(path.join(projectDir, relativePath));

  write("# Project Inventory (Generated)");
  write("");
  write("> 소스·설정에서 감지한 사실을 재생성한 문서다. 설계 결정은 `docs/design-docs/`에 기록한다.");
  write("");
  write(`- 분석 경로: \`${projectDir}\``);
  write(`- 생성일: ${bashStyleDate()}`);
  write("");
  write("## 감지된 기술 신호");
  let found = false;
  for (const [file, label] of [
    ["package.json", "Node.js"],
    ["pyproject.toml", "Python"],
    ["requirements.txt", "Python requirements"],
    ["go.mod", "Go"],
    ["Cargo.toml", "Rust"],
    ["Dockerfile", "Docker"],
    ["docker-compose.yml", "Docker Compose"],
  ]) {
    if (exists(file)) {
      write(`- ${label}: \`${file}\``);
      found = true;
    }
  }
  if (!found) write("- 감지된 언어·빌드 설정 없음 — 신규 프로젝트 프로필 질문 필요");
  write("");
  write("## 감지된 디렉터리");
  found = false;
  for (const dir of ["src", "app", "lib", "server", "client", "web", "frontend", "backend", "test", "tests", "e2e", "public"]) {
    if (fs.existsSync(path.join(projectDir, dir)) && fs.statSync(path.join(projectDir, dir)).isDirectory()) {
      write(`- \`${dir}/\``);
      found = true;
    }
  }
  if (!found) write("- 감지된 소스·테스트 디렉터리 없음");
  write("");
  write("## 실행 명령 후보");
  if (exists("package.json")) {
    write("- package.json scripts:");
    // bash: sed 범위 + grep '"키":' + 접두사. 매칭 없으면 "감지하지 못함".
    const lines = fs.readFileSync(path.join(projectDir, "package.json"), "utf8").split("\n");
    const collected = [];
    let inScripts = false;
    for (const line of lines) {
      if (!inScripts && /"scripts"\s*:/.test(line)) {
        inScripts = true;
        continue;
      }
      if (inScripts) {
        if (/^\s*\}[,]*\s*$/.test(line)) break;
        collected.push(line);
      }
    }
    const scriptLines = collected.filter((line) => /"[^"]+"\s*:/.test(line)).map((line) => `  - ${line}`);
    if (scriptLines.length > 0) {
      for (const line of scriptLines) write(line);
    } else {
      write("  - 감지하지 못함");
    }
  } else {
    write("- 프로젝트별 build/lint/test 명령 확인 필요");
  }
  write("");
  write("## 프로젝트 문서 상태");
  for (const file of ["AGENTS.md", "ARCHITECTURE.md", "docs/design-docs/project-context.md", "docs/testing-policy.md"]) {
    write(`- ${exists(file) ? "존재" : "누락"}: \`${file}\``);
  }
  write("");
  write("## 에이전트 다음 조치");
  if (!exists("package.json") && !exists("pyproject.toml") && !exists("go.mod") && !exists("Cargo.toml")) {
    write("- 신규 프로젝트로 보임: 목적, 사용자 흐름, 기술 스택, 데이터·인증, 검증 방식을 사용자에게 질문한다.");
  } else {
    write("- 기존 프로젝트로 보임: 소스 구조와 기존 문서를 비교해 누락 문서는 생성하고, 사실과 어긋난 프로젝트 문서 갱신안을 만든다.");
  }
  write("- 공통 정책·보안·검증 규칙은 소스 분석만으로 수정하지 않는다.");
  return out.join("\n") + "\n";
}

function run(args) {
  let projectDir = process.cwd();
  let writeReport = false;
  for (let i = 0; i < args.length; i += 1) {
    const arg = args[i];
    if (arg === "--project-dir") {
      if (!args[i + 1]) fail("사용법: scripts/analyze-project.sh [--project-dir <프로젝트경로>] [--write]", 2);
      projectDir = args[i + 1];
      i += 1;
    } else if (arg === "--write") {
      writeReport = true;
    } else if (arg === "-h" || arg === "--help") {
      process.stderr.write("사용법: scripts/analyze-project.sh [--project-dir <프로젝트경로>] [--write]\n");
      return;
    } else {
      fail("사용법: scripts/analyze-project.sh [--project-dir <프로젝트경로>] [--write]", 2);
    }
  }
  if (!fs.existsSync(projectDir) || !fs.statSync(projectDir).isDirectory()) {
    fail(`프로젝트 경로가 없습니다: ${projectDir}`, 2);
  }
  projectDir = path.resolve(projectDir);

  const inventory = buildInventory(projectDir);
  if (writeReport) {
    fs.mkdirSync(path.join(projectDir, "docs", "generated"), { recursive: true });
    const reportPath = path.join(projectDir, "docs", "generated", "project-inventory.md");
    fs.writeFileSync(reportPath, inventory, "utf8");
    process.stdout.write(`프로젝트 현황 생성: ${reportPath}\n`);
  } else {
    process.stdout.write(inventory);
  }
}

module.exports = { run };
