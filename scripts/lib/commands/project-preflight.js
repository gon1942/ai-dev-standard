"use strict";

// project-preflight — scripts/project-preflight.sh 원본의 Node 이식.

const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const { spawnSync } = require("child_process");
const { isVerificationReady, loadVerificationProfile } = require("../verification");

const FRAMEWORK_ROOT = process.env.AI_DEV_STANDARD_FRAMEWORK_ROOT
  ? path.resolve(process.env.AI_DEV_STANDARD_FRAMEWORK_ROOT)
  : path.resolve(__dirname, "..", "..", "..");

function usage() {
  process.stderr.write(
    "사용법: scripts/project-preflight.sh [--project-dir <프로젝트경로>] [--repair] [--run-checks] [--format markdown|json] [--write-report] [--write-session|--session-status]\n"
  );
}

function isSafeRuntimeAssetPath(p) {
  if (!(p.startsWith("scripts/") || p.startsWith("global-hooks/"))) return false;
  const guard = `/${p}/`;
  return !(guard.includes("/../") || guard.includes("/./") || guard.includes("//"));
}

function runtimeAssetEntries() {
  const catalog = path.join(FRAMEWORK_ROOT, "docs", "framework-runtime-assets.tsv");
  if (!fs.existsSync(catalog)) return [];
  const out = [];
  for (const rawLine of fs.readFileSync(catalog, "utf8").split("\n")) {
    const line = rawLine.replace(/\r$/, "");
    const tab = line.indexOf("\t");
    if (tab === -1) continue;
    const scope = line.slice(0, tab);
    if (scope === "target-script" || scope === "target-hook") {
      const rest = line.slice(tab + 1);
      const tab2 = rest.indexOf("\t");
      out.push([scope, tab2 === -1 ? rest : rest.slice(0, tab2)]);
    }
  }
  return out;
}

function sha256File(filePath) {
  return crypto.createHash("sha256").update(fs.readFileSync(filePath)).digest("hex");
}

function sessionFingerprint(projectDir) {
  const paths = [
    "AGENTS.md", "CLAUDE.md", ".ai-dev-standard.env", ".ai-dev-standard/verification.json",
    ".ai-dev-standard/verification-ready.json", ".ai-dev-standard/bootstrap-status.json",
    "package.json", "package-lock.json", "pnpm-lock.yaml",
    "yarn.lock", "pyproject.toml", "requirements.txt", "go.mod", "go.sum", "Cargo.toml", "Cargo.lock",
    "pom.xml", "build.gradle", "build.gradle.kts", "scripts/verify.sh", "scripts/lint.sh", "scripts/test.sh",
    "scripts/verify-plan.sh", "docs/development-workflow.md", "docs/project-preflight.md",
    "docs/framework-runtime-assets.tsv",
  ];
  for (const [, assetPath] of runtimeAssetEntries()) {
    if (isSafeRuntimeAssetPath(assetPath)) paths.push(assetPath);
  }
  const concat = paths
    .map((p) => {
      const absolute = path.join(projectDir, p);
      // bash sha256sum은 "해시<공백2>절대경로" 라인을 해시한다 — 값 동치를 위해 동일 형식 사용.
      return fs.existsSync(absolute) ? `${sha256File(absolute)}  ${absolute}\n` : `MISSING  ${p}\n`;
    })
    .join("");
  return crypto.createHash("sha256").update(concat).digest("hex");
}

function run(args) {
  let projectDir = process.cwd();
  let format = "markdown";
  let repair = false;
  let writeReport = false;
  let runChecks = false;
  let writeSessionFlag = false;
  let sessionStatus = false;

  for (let i = 0; i < args.length; i += 1) {
    const arg = args[i];
    if (arg === "--project-dir") {
      if (!args[i + 1]) { usage(); process.exit(2); }
      projectDir = args[i + 1]; i += 1;
    } else if (arg === "--repair") repair = true;
    else if (arg === "--run-checks") runChecks = true;
    else if (arg === "--write-report") writeReport = true;
    else if (arg === "--write-session") writeSessionFlag = true;
    else if (arg === "--session-status") sessionStatus = true;
    else if (arg === "--format") {
      if (args[i + 1] !== "markdown" && args[i + 1] !== "json") { usage(); process.exit(2); }
      format = args[i + 1]; i += 1;
    } else if (arg === "-h" || arg === "--help") { usage(); process.exit(0); }
    else { usage(); process.exit(2); }
  }

  if (!fs.existsSync(projectDir) || !fs.statSync(projectDir).isDirectory()) {
    process.stderr.write(`BLOCK: 프로젝트 경로가 없습니다: ${projectDir}\n`);
    process.exit(2);
  }
  projectDir = path.resolve(projectDir);

  const sessionFile = path.join(projectDir, ".ai-dev-standard", "session-preflight.json");
  if (sessionStatus) {
    if (!fs.existsSync(sessionFile)) {
      process.stdout.write('{"session_status":"missing","can_plan":false,"can_initialize":false,"can_code":false,"verification_ready":false}\n');
      process.exit(2);
    }
    const current = sessionFingerprint(projectDir);
    const stored =
      (fs.readFileSync(sessionFile, "utf8").match(/^\s*"fingerprint": "([^"]*)".*/m) || [])[1] || "";
    if (!stored || current !== stored) {
      process.stdout.write('{"session_status":"stale","can_plan":false,"can_initialize":false,"can_code":false,"verification_ready":false}\n');
      process.exit(2);
    }
    process.stdout.write(fs.readFileSync(sessionFile, "utf8"));
    process.exit(fs.readFileSync(sessionFile, "utf8").includes('"verdict": "BLOCK"') ? 2 : 0);
  }

  const warnings = [];
  const blocks = [];
  const generated = [];
  const checks = [];
  const stack = [];
  let packageManager = "unknown";
  let frameworkStatus = "unknown";
  let mode = "missing";
  let requireLint = "";
  let requireTest = "";
  let canPlan = false;
  let canCode = false;
  let canInitialize = false;
  let verificationReady = false;

  const hasFile = (p) => fs.existsSync(path.join(projectDir, p));
  const hasDir = (p) => fs.existsSync(path.join(projectDir, p)) && fs.statSync(path.join(projectDir, p)).isDirectory();

  const runFrameworkScript = (script, scriptArgs) =>
    spawnSync("bash", [path.join(FRAMEWORK_ROOT, "scripts", script), ...scriptArgs], {
      encoding: "utf8",
    });

  if (repair) {
    const before = runFrameworkScript("check-framework.sh", ["--project-dir", projectDir]);
    const beforeOutput = `${(before.stdout || "")}\n${(before.stderr || "")}`;
    if (/^FAIL /m.test(beforeOutput)) {
      runFrameworkScript("bootstrap-framework.sh", ["--project-dir", projectDir, "--init"]);
      generated.push("누락 공통 골격 (bootstrap-framework --init)");
    }
  }

  const frameworkCheck = runFrameworkScript("check-framework.sh", ["--project-dir", projectDir]);
  if (frameworkCheck.status === 0) {
    frameworkStatus = "valid";
    checks.push("공통 프레임워크 골격: PASS");
  } else {
    frameworkStatus = "invalid";
    blocks.push("공통 프레임워크 필수 자산 누락 또는 설정 오류");
  }

  if (hasFile("package.json")) {
    stack.push("JavaScript/Node.js");
    const nodeProbe = spawnSync("node", ["-e", "process.exit(0)"]);
    if (nodeProbe.status === 0) {
      const jsonCheck = spawnSync(
        "node",
        ["-e", "JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8'))", path.join(projectDir, "package.json")]
      );
      if (jsonCheck.status === 0) checks.push("package.json 문법: PASS");
      else blocks.push("package.json 구문 오류");
    } else {
      warnings.push("package.json은 있으나 node 런타임이 없어 JSON 실행 검사를 생략");
    }
    if (hasFile("pnpm-lock.yaml")) packageManager = "pnpm";
    else if (hasFile("yarn.lock")) packageManager = "yarn";
    else if (hasFile("package-lock.json")) packageManager = "npm";
    else {
      packageManager = "Node 패키지 관리자 미확정";
      warnings.push("Node 프로젝트의 lockfile이 없어 패키지 관리자를 확정할 수 없음");
    }
    if (/"(next|react|vue|@angular\/core|express|nestjs)"/.test(fs.readFileSync(path.join(projectDir, "package.json"), "utf8"))) {
      stack.push("프레임워크 감지됨");
    }
  }
  if (hasFile("pyproject.toml") || hasFile("requirements.txt")) {
    stack.push("Python");
    if (hasFile("pyproject.toml")) {
      const pyProbe = spawnSync("python3", ["-c", "import sys; import tomllib"]);
      if (pyProbe.status === 0) {
        const tomlCheck = spawnSync(
          "python3",
          ["-c", "import sys; import tomllib; tomllib.load(open(sys.argv[1], 'rb'))", path.join(projectDir, "pyproject.toml")]
        );
        if (tomlCheck.status === 0) checks.push("pyproject.toml 문법: PASS");
        else warnings.push("pyproject.toml 문법 검사를 수행할 수 없음 (Python 3.11+ 또는 파일 내용 확인 필요)");
      }
    }
  }
  if (hasFile("go.mod")) stack.push("Go");
  if (hasFile("Cargo.toml")) stack.push("Rust");
  if (hasFile("pom.xml") || hasFile("build.gradle") || hasFile("build.gradle.kts") || hasFile("mvnw") || hasFile("gradlew")) stack.push("Java/JVM");
  if (hasFile("Dockerfile")) stack.push("Docker");
  if (hasFile(".shellcheckrc") || ["src", "bin", "ops"].some((dir) => hasDir(dir) && fs.readdirSync(path.join(projectDir, dir)).some((name) => name.endsWith(".sh")))) stack.push("Shell");
  if (["systemd", "deploy/systemd"].some(hasDir)) stack.push("System service");
  if (stack.length === 0) {
    stack.push("판별 불가");
    warnings.push("기술 스택 신호가 없어 프로젝트별 명령·템플릿 생성을 추정하지 않음");
  }

  if (hasFile(".ai-dev-standard.env")) {
    const envLines = fs.readFileSync(path.join(projectDir, ".ai-dev-standard.env"), "utf8").split("\n");
    const modeLines = envLines.filter((l) => /^AI_DEV_STANDARD_MODE=/.test(l));
    mode = modeLines.length ? modeLines[modeLines.length - 1].replace(/^AI_DEV_STANDARD_MODE=/, "") : "";
    if (mode === "active") {
      checks.push("검증 모드: active");
      // active 모드의 전제: 소스 지문 재사용·diff 리뷰·수렴 검사는 Git 저장소 위에서만 작동한다.
      if (!fs.existsSync(path.join(projectDir, ".git"))) {
        blocks.push("active 모드에는 Git 저장소가 필요합니다 — git init 후 초기 커밋 (증거 지문 재사용·diff 리뷰·수렴 검사의 전제)");
      }
    }
    else if (mode === "template") warnings.push("검증 모드가 template: Bootstrap/Plan은 가능하지만 기능 Coding/READY_FOR_REVIEW는 차단");
    else if (mode === "initializing") warnings.push("검증 모드가 initializing: 승인된 초기 설정만 가능하며 기능 Coding/READY_FOR_REVIEW는 차단");
    else blocks.push(".ai-dev-standard.env의 AI_DEV_STANDARD_MODE 값이 유효하지 않음");
    for (const key of ["AI_DEV_STANDARD_REQUIRE_LINT", "AI_DEV_STANDARD_REQUIRE_TYPECHECK", "AI_DEV_STANDARD_REQUIRE_TEST"]) {
      const keyLines = envLines.filter((l) => l.startsWith(`${key}=`));
      const value = keyLines.length ? keyLines[keyLines.length - 1].slice(key.length + 1) : "";
      if (value !== "true" && value !== "false") {
        blocks.push(`.ai-dev-standard.env의 ${key} 값이 true 또는 false가 아님`);
      }
      if (key === "AI_DEV_STANDARD_REQUIRE_LINT") requireLint = value;
      if (key === "AI_DEV_STANDARD_REQUIRE_TEST") requireTest = value;
    }
  }

  const verificationProfile = loadVerificationProfile(projectDir);
  if (verificationProfile.status === "invalid") {
    blocks.push(`검증 프로필 오류: ${verificationProfile.message}`);
  } else if (verificationProfile.status === "ok") {
    const readiness = isVerificationReady(projectDir);
    verificationReady = readiness.ready;
    checks.push("검증 프로필: 유효");
    if (verificationReady) checks.push("검증 준비 증거: 최신");
    else warnings.push(`검증 준비 증거 없음 또는 오래됨: ${readiness.reason}`);
  }

  for (const document of ["AGENTS.md", "ARCHITECTURE.md", "docs/development-workflow.md", "docs/definition-of-done.md", "docs/testing-policy.md"]) {
    const documentPath = path.join(projectDir, document);
    if (fs.existsSync(documentPath) && !/\S/.test(fs.readFileSync(documentPath, "utf8"))) {
      blocks.push(`${document} 파일이 비어 있음`);
    }
  }

  if (mode === "active" && verificationProfile.status === "missing" && requireLint === "true") {
    if (!hasFile(".eslintrc.json") && !hasFile("eslint.config.js") && !hasFile("eslint.config.mjs")
      && !hasFile("pyproject.toml") && !hasFile(".ruff.toml")) {
      blocks.push("active 모드에서 필수 lint가 설정됐지만 감지 가능한 lint 구성이 없음");
    }
  }
  if (mode === "active" && verificationProfile.status === "missing" && requireTest === "true") {
    let hasTestConfiguration = false;
    const frameworkTestPath = path.join(projectDir, "scripts", "test-framework.sh");
    if (hasFile("jest.config.js") || hasFile("jest.config.cjs") || hasFile("jest.config.mjs")
      || hasFile("pytest.ini") || hasFile("pyproject.toml")
      || (fs.existsSync(path.join(projectDir, "tests")) && fs.statSync(path.join(projectDir, "tests")).isDirectory())
      || (fs.existsSync(frameworkTestPath) && (fs.statSync(frameworkTestPath).mode & 0o111) !== 0)) {
      hasTestConfiguration = true;
    }
    if (!hasTestConfiguration) {
      blocks.push("active 모드에서 필수 test가 설정됐지만 감지 가능한 테스트 구성이 없음");
    }
  }

  for (const [scope, assetPath] of runtimeAssetEntries()) {
    if (!isSafeRuntimeAssetPath(assetPath)) {
      blocks.push(`허용되지 않은 실행 자산 경로: ${assetPath}`);
      continue;
    }
    const assetAbs = path.join(projectDir, assetPath);
    if (scope === "target-script" && fs.existsSync(assetAbs)) {
      if (assetPath.endsWith(".sh")) {
        const syntax = spawnSync("bash", ["-n", assetAbs]);
        if (syntax.status === 0) checks.push(`${assetPath} 문법: PASS`);
        else blocks.push(`${assetPath} 셸 문법 오류`);
      } else if (assetPath.endsWith(".js")) {
        const syntax = spawnSync("node", ["--check", assetAbs], { stdio: "ignore" });
        if (syntax.status === 0) checks.push(`${assetPath} 문법: PASS`);
        else blocks.push(`${assetPath} Node 문법 오류`);
      }
    } else if (scope === "target-hook" && assetPath.endsWith(".sh") && fs.existsSync(assetAbs)) {
      const syntax = spawnSync("bash", ["-n", assetAbs]);
      if (syntax.status === 0) checks.push(`${assetPath} 문법: PASS`);
      else blocks.push(`${assetPath} 셸 문법 오류`);
    }
  }

  if (runChecks) {
    if (mode === "active") {
      const verify = spawnSync("bash", ["scripts/verify.sh"], { cwd: projectDir, stdio: "ignore" });
      if (verify.status === 0) checks.push("verify.sh 실행: PASS");
      else blocks.push("verify.sh 실행 실패 (출력은 실행 환경에서 확인 필요)");
    } else {
      warnings.push("--run-checks는 active 모드에서만 통합 검증을 실행함");
    }
  }

  const agentPaths = [];
  if (hasFile("AGENTS.md")) agentPaths.push("AGENTS.md");
  if (hasFile("CLAUDE.md")) agentPaths.push("CLAUDE.md");
  if (fs.existsSync(path.join(projectDir, ".opencode"))) agentPaths.push(".opencode/");
  if (fs.existsSync(path.join(projectDir, ".claude"))) agentPaths.push(".claude/");
  if (fs.existsSync(path.join(projectDir, ".agents", "skills"))) agentPaths.push(".agents/skills/");
  if (agentPaths.length === 0) warnings.push("에이전트 지침 또는 설정을 감지하지 못함");

  if (blocks.length === 0) canPlan = true;
  canInitialize = blocks.length === 0 && (mode === "template" || mode === "initializing");
  let verdict;
  if (blocks.length > 0) verdict = "BLOCK";
  else if (warnings.length > 0) verdict = "WARNING";
  else verdict = "PASS";
  canCode = mode === "active" && verdict !== "BLOCK";

  const joinBy = (sep, values) => values.join(sep);
  const jsonEscape = (s) => String(s).replace(/\\/g, "\\\\").replace(/"/g, '\\"');
  const jsonArray = (values) => `[${values.map((v) => `"${jsonEscape(v)}"`).join(",")}]`;
  const bashBool = (b) => (b ? "true" : "false");

  function markdownReport() {
    const out = [];
    out.push("# Project Preflight Report");
    out.push("");
    out.push(`- 대상 프로젝트: \`${projectDir}\``);
    out.push(`- 최종 판정: **${verdict}**`);
    out.push(`- Plan 진행: **${bashBool(canPlan)}**`);
    out.push(`- 초기화 진행: **${bashBool(canInitialize)}**`);
    out.push(`- 검증 준비 완료: **${bashBool(verificationReady)}**`);
    out.push(`- Coding 진행: **${bashBool(canCode)}**`);
    out.push("");
    out.push("## 감지된 환경");
    out.push(`- 기술 스택: ${joinBy(", ", stack)}`);
    out.push(`- 패키지 관리자: ${packageManager}`);
    out.push(`- 검증 모드: ${mode}`);
    out.push(`- 에이전트 설정: ${agentPaths.length ? agentPaths.join(" ") : "감지하지 못함"}`);
    out.push("");
    out.push("## 실행한 검사");
    for (const item of checks) out.push(`- PASS: ${item}`);
    out.push("");
    out.push("## 자동 생성 항목");
    if (generated.length === 0) out.push("- 없음");
    else for (const item of generated) out.push(`- ${item}`);
    out.push("");
    out.push("## WARNING");
    if (warnings.length === 0) out.push("- 없음");
    else for (const item of warnings) out.push(`- ${item}`);
    out.push("");
    out.push("## BLOCK");
    if (blocks.length === 0) out.push("- 없음");
    else for (const item of blocks) out.push(`- ${item}`);
    out.push("");
    out.push("## 다음 단계");
    if (verdict === "PASS") out.push("- Plan → Coding → Verification을 진행할 수 있습니다.");
    else if (verdict === "WARNING") {
      if (canCode) out.push("- WARNING 항목을 기록하고 Plan → Coding → Verification을 진행할 수 있습니다.");
      else if (canInitialize) out.push("- Plan과 승인된 Bootstrap 설정을 진행할 수 있습니다. 설정된 검증 명령이 통과하기 전 기능 Coding은 시작하지 마세요.");
      else out.push("- Plan은 진행할 수 있습니다. 필수 BLOCK/WARNING을 해소한 뒤 다시 확인하세요.");
    } else out.push("- BLOCK 원인을 해결한 뒤 같은 Preflight를 재실행하세요. Plan/Coding으로 진행하지 마세요.");
    return out.join("\n") + "\n";
  }

  function jsonReport() {
    const lines = [];
    lines.push("{");
    lines.push(`  "project": "${jsonEscape(projectDir)}",`);
    lines.push(`  "verdict": "${verdict}",`);
    lines.push(`  "can_plan": ${bashBool(canPlan)},`);
    lines.push(`  "can_initialize": ${bashBool(canInitialize)},`);
    lines.push(`  "can_code": ${bashBool(canCode)},`);
    lines.push(`  "verification_ready": ${bashBool(verificationReady)},`);
    lines.push(`  "stack": ${jsonArray(stack)},`);
    lines.push(`  "package_manager": "${jsonEscape(packageManager)}",`);
    lines.push(`  "verification_mode": "${mode}",`);
    lines.push(`  "checks": ${jsonArray(checks)},`);
    lines.push(`  "generated": ${jsonArray(generated)},`);
    lines.push(`  "warnings": ${jsonArray(warnings)},`);
    lines.push(`  "blocks": ${jsonArray(blocks)}`);
    lines.push("}");
    return lines.join("\n") + "\n";
  }

  if (writeReport) {
    fs.mkdirSync(path.join(projectDir, "docs", "generated"), { recursive: true });
    const pairs = [
      [markdownReport(), path.join(projectDir, "docs", "generated", "project-preflight.md")],
      [jsonReport(), path.join(projectDir, "docs", "generated", "project-preflight.json")],
    ];
    for (const [content, target] of pairs) {
      if (!fs.existsSync(target) || fs.readFileSync(target, "utf8") !== content) {
        fs.writeFileSync(target, content, "utf8");
      }
    }
  }

  if (writeSessionFlag) {
    fs.mkdirSync(path.join(projectDir, ".ai-dev-standard"), { recursive: true });
    const now = new Date();
    const checkedAt = now.toISOString().replace(/\.\d{3}Z$/, "Z");
    const session = `{
  "project": "${jsonEscape(projectDir)}",
  "checked_at": "${checkedAt}",
  "fingerprint": "${sessionFingerprint(projectDir)}",
  "verdict": "${verdict}",
  "can_plan": ${bashBool(canPlan)},
  "can_initialize": ${bashBool(canInitialize)},
  "can_code": ${bashBool(canCode)},
  "verification_ready": ${bashBool(verificationReady)}
}
`;
    fs.writeFileSync(sessionFile, session, "utf8");
  }

  process.stdout.write(format === "json" ? jsonReport() : markdownReport());
  process.exit(verdict === "BLOCK" ? 2 : 0);
}

module.exports = { run };
