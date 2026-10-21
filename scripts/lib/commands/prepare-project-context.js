"use strict";

// prepare-project-context — scripts/prepare-project-context.sh 원본의 Node 이식.

const fs = require("fs");
const path = require("path");
const { fail } = require("../util");

const CONSTITUTION_SECTIONS = [
  "## 고위험 변경과 승인 경계",
  "## 아키텍처 불변 조건",
  "## 규제·컴플라이언스 요건",
  "## 인증·권한·외부 연동 정책",
  "## 데이터·프라이버시 정책",
  "## 프로젝트별 필수 검증 수준",
  "## 안티골 — 기술적으로 가능해도 하지 않을 것",
  "## 미확정 결정·확정에 필요한 정보",
];

// 상태 행이 정확히 하나이고 값이 '확정'이며 필수 섹션이 모두 있을 때만 true.
function constitutionConfirmed(projectDir) {
  const file = path.join(projectDir, "docs", "project-constitution.md");
  if (!fs.existsSync(file)) return false;
  const lines = fs.readFileSync(file, "utf8").split("\n");
  const statusLines = lines.filter((line) => /^- 상태:/.test(line));
  if (statusLines.length !== 1) return false;
  if (!lines.includes("- 상태: 확정")) return false;
  for (const section of CONSTITUTION_SECTIONS) {
    if (!lines.includes(section)) return false;
  }
  return true;
}

function buildReport(projectDir) {
  const out = [];
  const write = (line) => out.push(line);
  const exists = (relativePath) => fs.existsSync(path.join(projectDir, relativePath));

  write("# Project Context Intake (Generated)");
  write("");
  write("> 소스 분석으로 확정할 수 없는 정보만 묻기 위한 초안이다. 답변은 project-context·architecture·project-constitution 초안의 근거가 된다.");
  write("");
  write(`- 대상 프로젝트: \`${projectDir}\``);
  write("");
  write("## 분석으로 확인된 신호");
  let found = false;
  for (const file of ["package.json", "pyproject.toml", "go.mod", "Cargo.toml", "Dockerfile"]) {
    if (exists(file)) {
      write(`- \`${file}\` 존재`);
      found = true;
    }
  }
  if (!found) write("- 기술 스택 신호 없음");
  write("");
  write("## 사용자 확인 질문");
  write("");
  if (!exists("README.md")) {
    write("1. 이 프로젝트가 해결할 문제와 주요 사용자는 누구인가?");
  } else {
    write("1. README에 없는 제품 목적·성공 기준 또는 우선순위가 있는가?");
  }
  let needsContext = true;
  const contextFile = path.join(projectDir, "docs", "design-docs", "project-context.md");
  if (
    fs.existsSync(contextFile) &&
    !/^- 상태: 초안$|^- 미확정$/m.test(fs.readFileSync(contextFile, "utf8"))
  ) {
    needsContext = false;
  }
  if (needsContext) {
    write("2. 첫 번째 핵심 사용자 흐름과, 반드시 제외할 범위는 무엇인가?");
    write("3. 도메인 용어, 권한 정책, 예외 규칙 중 먼저 확정할 것은 무엇인가?");
  }
  if (!exists("package.json") && !exists("pyproject.toml") && !exists("go.mod") && !exists("Cargo.toml")) {
    write("4. 선호 기술 스택, 데이터 저장소, 인증 방식은 무엇인가?");
  } else {
    write("4. 분석에서 발견되지 않은 데이터 저장소·인증·외부 서비스가 있는가?");
  }
  write("5. 브라우저 실측, 통합·성능·보안 검증 중 필수인 것은 무엇인가?");
  if (!constitutionConfirmed(projectDir)) {
    write("6. 사람 승인 없이 고칠 수 없는 고위험 영역과, 절대 바꾸지 않을 아키텍처 불변 조건은 무엇인가?");
    write("7. 적용받는 규제·컴플라이언스 요건과 데이터·프라이버시 정책은 무엇인가?");
    write("8. 기술적으로 가능해도 하지 않을 것(안티골)은 무엇인가? 이 프로젝트의 필수 검증 수준은?");
  }
  write("");
  write("## LLM 작성 대상");
  write("");
  write("- ARCHITECTURE.md: 소스에서 확인된 구조 + 사용자 확정 결정");
  write("- docs/design-docs/project-context.md: 목적·사용자 흐름·도메인·범위");
  write("- docs/project-constitution.md: 고위험 경계·아키텍처 불변·규제·인증·프라이버시·검증 수준·안티골");
  write("- 기존 파일은 변경 전 diff와 승인 필요");
  return out.join("\n") + "\n";
}

function run(args) {
  let projectDir = process.cwd();
  let writeReport = false;
  for (let i = 0; i < args.length; i += 1) {
    const arg = args[i];
    if (arg === "--project-dir") {
      if (!args[i + 1]) fail("사용법: scripts/prepare-project-context.sh [--project-dir <프로젝트경로>] [--write]", 2);
      projectDir = args[i + 1];
      i += 1;
    } else if (arg === "--write") {
      writeReport = true;
    } else if (arg === "-h" || arg === "--help") {
      process.stderr.write("사용법: scripts/prepare-project-context.sh [--project-dir <프로젝트경로>] [--write]\n");
      return;
    } else {
      fail("사용법: scripts/prepare-project-context.sh [--project-dir <프로젝트경로>] [--write]", 2);
    }
  }
  if (!fs.existsSync(projectDir) || !fs.statSync(projectDir).isDirectory()) {
    fail(`프로젝트 경로가 없습니다: ${projectDir}`, 2);
  }
  projectDir = path.resolve(projectDir);

  const report = buildReport(projectDir);
  if (writeReport) {
    fs.mkdirSync(path.join(projectDir, "docs", "generated"), { recursive: true });
    const reportPath = path.join(projectDir, "docs", "generated", "project-context-intake.md");
    fs.writeFileSync(reportPath, report, "utf8");
    process.stdout.write(`프로젝트 문맥 입력 초안 생성: ${reportPath}\n`);
  } else {
    process.stdout.write(report);
  }
}

module.exports = { run };
