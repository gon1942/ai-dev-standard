"use strict";

// bootstrap-framework — scripts/bootstrap-framework.sh 원본의 Node 이식.

const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");

// 프레임워크 소스 루트 — 기본은 모듈 실위치, AI_DEV_STANDARD_FRAMEWORK_ROOT로 재정의 가능
// (동치성 시험과 배포 도구가 소스를 지정할 때 사용).
const SCRIPT_ROOT = process.env.AI_DEV_STANDARD_FRAMEWORK_ROOT
  ? path.resolve(process.env.AI_DEV_STANDARD_FRAMEWORK_ROOT)
  : path.resolve(__dirname, "..", "..", "..");
const ASSET_CATALOG = path.join(SCRIPT_ROOT, "docs", "framework-runtime-assets.tsv");

function usage() {
  process.stderr.write("사용법: scripts/bootstrap-framework.sh [--project-dir <프로젝트경로>] [--analyze|--init]\n");
}

function isSafeRuntimeAssetPath(p) {
  if (!(p.startsWith("scripts/") || p.startsWith("global-hooks/"))) return false;
  const guard = `/${p}/`;
  return !(guard.includes("/../") || guard.includes("/./") || guard.includes("//"));
}

function parseTsvLine(line) {
  const tab = line.indexOf("\t");
  if (tab === -1) return { scope: line, assetPath: "", description: "" };
  const scope = line.slice(0, tab);
  const rest = line.slice(tab + 1);
  const tab2 = rest.indexOf("\t");
  return {
    scope,
    assetPath: tab2 === -1 ? rest : rest.slice(0, tab2),
    description: tab2 === -1 ? "" : rest.slice(tab2 + 1),
  };
}

function run(args) {
  let targetRoot = process.cwd();
  let mode = "analyze";
  for (let i = 0; i < args.length; i += 1) {
    const arg = args[i];
    if (arg === "--project-dir") {
      if (!args[i + 1]) { usage(); process.exit(2); }
      targetRoot = args[i + 1]; i += 1;
    } else if (arg === "--analyze") mode = "analyze";
    else if (arg === "--init") mode = "init";
    else if (arg === "-h" || arg === "--help") { usage(); process.exit(0); }
    else { usage(); process.exit(2); }
  }
  if (!fs.existsSync(targetRoot) || !fs.statSync(targetRoot).isDirectory()) {
    process.stderr.write(`프로젝트 경로가 없습니다: ${targetRoot}\n`);
    process.exit(2);
  }
  targetRoot = path.resolve(targetRoot);

  const envContent = `# 프로젝트 명령을 확인한 뒤 active로 전환한다.
AI_DEV_STANDARD_MODE=template
AI_DEV_STANDARD_REQUIRE_LINT=true
AI_DEV_STANDARD_REQUIRE_TYPECHECK=false
AI_DEV_STANDARD_REQUIRE_TEST=true
AI_DEV_STANDARD_DUPLICATE_CHECK=true
`;

  function writeIfMissing(relativePath, content) {
    const target = path.join(targetRoot, relativePath);
    if (fs.existsSync(target)) {
      process.stdout.write(`KEEP: ${relativePath}\n`);
      return;
    }
    fs.mkdirSync(path.dirname(target), { recursive: true });
    fs.writeFileSync(target, content, "utf8");
    if (relativePath.startsWith("scripts/") && relativePath.endsWith(".sh")) {
      fs.chmodSync(target, 0o755);
    }
    process.stdout.write(`CREATE: ${relativePath}\n`);
  }

  function copyIfMissing(relativePath, label, executable) {
    const target = path.join(targetRoot, relativePath);
    if (fs.existsSync(target)) {
      process.stdout.write(`KEEP: ${relativePath}\n`);
      return;
    }
    const source = path.join(SCRIPT_ROOT, relativePath);
    if (!fs.existsSync(source) || !fs.statSync(source).isFile()) {
      process.stderr.write(`SKIP: ${relativePath} (프레임워크 원본에 없음)\n`);
      return;
    }
    fs.mkdirSync(path.dirname(target), { recursive: true });
    fs.copyFileSync(source, target);
    if (executable) fs.chmodSync(target, 0o755);
    process.stdout.write(`CREATE: ${relativePath} (${label})\n`);
  }

  const copyFromFramework = (p) => copyIfMissing(p, "프레임워크 원본 복사", true);
  const copyDocument = (p) => copyIfMissing(p, "프레임워크 원본 복사", false);
  const copyAdapter = (p) => copyIfMissing(p, "도구 어댑터 복사", false);

  function copyRuntimeAssets() {
    if (!fs.existsSync(ASSET_CATALOG)) {
      process.stderr.write(`프레임워크 실행 자산 목록이 없습니다: ${ASSET_CATALOG}\n`);
      process.exit(1);
    }
    for (const rawLine of fs.readFileSync(ASSET_CATALOG, "utf8").split("\n")) {
      const line = rawLine.replace(/\r$/, "");
      if (line === "") continue;
      const { scope, assetPath } = parseTsvLine(line);
      if (scope === "" || scope.startsWith("#")) continue;
      if (scope === "target-script" || scope === "target-hook") {
        if (!isSafeRuntimeAssetPath(assetPath)) {
          process.stderr.write(`허용되지 않은 실행 자산 경로: ${assetPath}\n`);
          process.exit(1);
        }
        copyFromFramework(assetPath);
      } else if (scope !== "repository-test") {
        process.stderr.write(`알 수 없는 실행 자산 범위: ${scope}\n`);
        process.exit(1);
      }
    }
  }

  function report() {
    spawnSync("bash", [path.join(SCRIPT_ROOT, "scripts", "analyze-project.sh"), "--project-dir", targetRoot], { stdio: "inherit" });
    process.stdout.write("\n");
    spawnSync("bash", [path.join(SCRIPT_ROOT, "scripts", "check-framework.sh"), "--project-dir", targetRoot], { stdio: "inherit" });
  }

  function findSkillFiles(tool) {
    const skillRoot = path.join(SCRIPT_ROOT, tool, "skills");
    const results = [];
    if (!fs.existsSync(skillRoot)) return results;
    const walk = (dir) => {
      for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        const full = path.join(dir, entry.name);
        if (entry.isDirectory()) walk(full);
        else if (entry.isFile() && entry.name === "SKILL.md") results.push(full);
      }
    };
    walk(skillRoot);
    return results.sort();
  }

  function initialize() {
    process.stdout.write(`=== 안전한 골격 생성: ${targetRoot} ===\n`);
    process.stdout.write("기존 파일은 덮어쓰지 않습니다. 프로젝트 코드·의존성도 변경하지 않습니다.\n");
    for (const dir of [
      "docs/product-specs", "docs/exec-plans/active", "docs/exec-plans/completed",
      "docs/design-docs", "docs/agent-improvements/candidates", "docs/agent-improvements/approved",
      "docs/agent-improvements/rejected", "docs/generated",
    ]) {
      if (fs.existsSync(path.join(targetRoot, dir))) {
        process.stdout.write(`KEEP: ${dir}/\n`);
      } else {
        fs.mkdirSync(path.join(targetRoot, dir), { recursive: true });
        process.stdout.write(`CREATE: ${dir}/\n`);
      }
    }
    writeIfMissing(".ai-dev-standard.env", envContent);
    for (const document of [
      "AGENTS.md", "CLAUDE.md", "ARCHITECTURE.md", "CONTRIBUTING.md",
      "docs/development-workflow.md", "docs/definition-of-done.md", "docs/coding-standards.md",
      "docs/testing-policy.md", "docs/framework-onboarding.md", "docs/framework-manifest.md",
      "docs/framework-runtime-assets.tsv", "docs/project-bootstrap.md", "docs/project-preflight.md",
      "docs/session-preflight.md", "docs/global-session-hooks.md", "docs/project-constitution.md",
      "docs/design-docs/project-context.md", "docs/design-docs/index.md",
      "docs/generated/README.md", "docs/references/README.md",
      "docs/product-specs/index.md", "docs/agent-improvements/README.md",
    ]) {
      copyDocument(document);
    }
    for (const contract of [
      "standard-plan.md", "standard-implement.md", "standard-orchestration.md",
      "standard-verify.md", "standard-uat.md", "standard-review.md", "standard-improve.md",
    ]) {
      copyDocument(`docs/skill-contracts/${contract}`);
    }
    copyRuntimeAssets();
    for (const tool of [".opencode", ".claude", ".agents"]) {
      for (const sourceFile of findSkillFiles(tool)) {
        copyAdapter(path.relative(SCRIPT_ROOT, sourceFile));
      }
    }
    for (const adapterFile of [
      ".opencode/agents/reviewer.md", ".claude/settings.json",
      ".claude/commands/task-record.md", ".claude/commands/verify.md",
    ]) {
      copyAdapter(adapterFile);
    }
    process.stdout.write("\n");
    process.stdout.write("다음 단계: 에이전트가 project-bootstrap 절차로 문맥 질문과 설계 문서 초안을 제안하고, 사용자 승인 후에만 기존 파일을 갱신합니다.\n");
  }

  if (mode === "analyze") report();
  else initialize();
}

module.exports = { run };
