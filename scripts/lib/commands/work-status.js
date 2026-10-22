"use strict";

// work-status — 세션 시작 시 작업 기록 복원을 지원하는 요약 명령.
// active/ 계획을 상태별로 분류하고 completed/ 최근 완료와 Git 변경 상태를 함께 보여준다.
// 판별 기준은 converge-plan과 동일한 형식 규칙을 따른다 (읽기 전용 — 아무 것도 변경하지 않는다).

const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");
const { ROOT, sectionInside } = require("../util");

function readIfExists(filePath) {
  return fs.existsSync(filePath) ? fs.readFileSync(filePath, "utf8") : null;
}

function classifyActivePlan(content) {
  const statusMatch = content.match(/^- 상태: (.+)$/m);
  const status = statusMatch ? statusMatch[1].trim() : "unknown";
  const hasCompletion = /^## 완료 기록$/m.test(content);
  const reviewPass = /^- 리뷰: PASS$/m.test(content);
  const acRows = sectionInside(content, /^## AC 판정$/).filter((line) => /^\| AC-[^|]+ \|/.test(line));
  const allPass =
    acRows.length > 0 && acRows.every((row) => /^\| AC-[^|]+ \| PASS \| .+ \|$/.test(row));
  const convergedEvidence = hasCompletion && reviewPass && allPass;

  if (status === "READY_FOR_REVIEW") {
    return { status, category: "승인 대기", detail: "사람 승인 후 complete-exec-plan으로 완료 처리" };
  }
  if (convergedEvidence && status === "active") {
    return {
      status,
      category: "전환 누락",
      detail: "수렴 증거 완결(완료 기록·AC PASS·리뷰 PASS)이나 상태가 active — READY_FOR_REVIEW 기록 필요",
    };
  }
  const reasons = [];
  if (!hasCompletion) reasons.push("완료 기록 없음");
  if (!reviewPass) reasons.push("리뷰 PASS 없음");
  if (acRows.length === 0) reasons.push("AC 판정 표 없음");
  else if (!allPass) reasons.push("AC 미통과 존재");
  return {
    status,
    category: "진행 중",
    detail: reasons.length ? reasons.join("·") : "구현 또는 검증 진행 중",
  };
}

function run(args) {
  if (args.length > 0 && args[0] !== "-h" && args[0] !== "--help") {
    process.stderr.write("사용법: node scripts/lib/cli.js work-status\n");
    process.exit(2);
  }
  if (args[0] === "-h" || args[0] === "--help") {
    process.stderr.write("사용법: node scripts/lib/cli.js work-status\n");
    return;
  }

  const activeDir = path.join(ROOT, "docs", "exec-plans", "active");
  const completedDir = path.join(ROOT, "docs", "exec-plans", "completed");
  const out = [];
  const write = (line) => out.push(line);

  write("# Work Status (Session Restore)");
  write("");
  write(`- 대상: ${ROOT}`);
  write("");

  // ── 활성 작업 분류 ──
  const activeFiles = fs.existsSync(activeDir)
    ? fs.readdirSync(activeDir).filter((f) => f.endsWith(".md")).sort()
    : [];
  write("## 활성 작업 (docs/exec-plans/active/)");
  write("");
  if (activeFiles.length === 0) {
    write("- 없음");
  } else {
    const buckets = { "전환 누락": [], "승인 대기": [], "진행 중": [] };
    for (const file of activeFiles) {
      const content = readIfExists(path.join(activeDir, file));
      if (content === null) continue;
      const info = classifyActivePlan(content);
      (buckets[info.category] || buckets["진행 중"]).push({ file, ...info });
    }
    write(`- 총 ${activeFiles.length}개`);
    for (const [category, items] of Object.entries(buckets)) {
      if (items.length === 0) continue;
      write("");
      write(`### ${category} (${items.length})`);
      for (const item of items) {
        write(`- \`${item.file}\` — ${item.detail}`);
      }
    }
  }
  write("");

  // ── 최근 완료 ──
  const completedFiles = fs.existsSync(completedDir)
    ? fs.readdirSync(completedDir).filter((f) => f.endsWith(".md")).sort().reverse()
    : [];
  write("## 최근 완료 (docs/exec-plans/completed/)");
  write("");
  if (completedFiles.length === 0) {
    write("- 없음");
  } else {
    write(`- 총 ${completedFiles.length}개 (최근 5개 표시)`);
    for (const file of completedFiles.slice(0, 5)) {
      const content = readIfExists(path.join(completedDir, file)) || "";
      const approver = (content.match(/^- 완료 승인: (.+)$/m) || [])[1] || "승인자 미기록";
      write(`- \`${file}\` (승인: ${approver})`);
    }
  }
  write("");

  // ── Git 변경 상태 ──
  write("## Git 변경 상태");
  write("");
  const gitCheck = spawnSync("git", ["rev-parse", "--is-inside-work-tree"], { cwd: ROOT });
  if (gitCheck.status === 0) {
    const status = spawnSync("git", ["status", "--short"], { cwd: ROOT, encoding: "utf8" });
    const lines = (status.stdout || "").split("\n").filter((l) => l.trim() !== "");
    if (lines.length === 0) {
      write("- 작업 트리 깨끗함 (커밋 대기 없음)");
    } else {
      write(`- 변경 ${lines.length}건 (커밋 대기):`);
      for (const line of lines.slice(0, 10)) write(`  - ${line}`);
      if (lines.length > 10) write(`  - ... 외 ${lines.length - 10}건`);
    }
  } else {
    write("- git 저장소 아님 — 작업 트리 직접 확인 필요");
  }
  write("");

  // ── 다음 조치 ──
  write("## 다음 조치");
  write("");
  write("- 전환 누락: 상태를 READY_FOR_REVIEW로 기록한 뒤 사람 승인을 기다린다");
  write("- 승인 대기: 사람 승인 후 complete-exec-plan으로 완료 보관한다");
  write("- 진행 중: 해당 Exec Plan을 이어서 작업한다");
  write("- 증거 신선성: 검증 PASS 이후 관련 소스가 변경됐다면 그 PASS는 최신 완료 증거가 아니다 — 재검증한다");

  // ── 필수 구성 도구 상태 (도구별 확인) ──
  write("");
  write("## 필수 구성 도구");
  write("");
  const tools = getToolStatus();
  for (const t of tools) {
    if (t.optional) {
      // package.json 없는 템플릿 상태 — 기술스택 감지 후 설치 (실패 아님)
      write(`- ${t.name}: ${t.installed ? "설치됨" : "기술스택 감지 후 설치 (package.json 없음)"}`);
    } else {
      write(`- ${t.name}: ${t.installed ? "설치됨" : "미설치 — 설치 필요"}`);
    }
  }
  const uninstalledTools = tools.filter((t) => !t.installed && !t.optional);
  if (uninstalledTools.length > 0) {
    write("");
    write("미설치 필수 도구가 있습니다: `node scripts/lib/cli.js suggest-tools --install` 실행");
  }

  process.stdout.write(out.join("\n") + "\n");
}

// 보조 도구 상태 요약 (suggest-tools와 동일한 판정, 출력만 간략히)
function getToolStatus() {
  const fs2 = require("fs");
  const path2 = require("path");
  const os = require("os");
  const result = [];

  // Ponytail 플러그인
  const localOc = path2.join(ROOT, "opencode.json");
  const globalOc = path2.join(os.homedir(), ".config", "opencode", "opencode.json");
  let ponytailPlugin = false;
  for (const p of [localOc, globalOc]) {
    try {
      const config = JSON.parse(fs2.readFileSync(p, "utf8"));
      if (config.plugin && config.plugin.includes("@dietrichgebert/ponytail")) {
        ponytailPlugin = true;
        break;
      }
    } catch {}
  }
  result.push({
    name: "Ponytail 플러그인",
    installed: ponytailPlugin,
    hint: ponytailPlugin ? "" : "구현 중 지속 프롬프팅 보조",
  });

  // Ponytail 스킬 (도구별 확인)
  const skillOc = fs2.existsSync(path2.join(ROOT, ".opencode", "skills", "ponytail", "SKILL.md"));
  const skillClaude = fs2.existsSync(path2.join(ROOT, ".claude", "skills", "ponytail", "SKILL.md"));
  const skillCodex = fs2.existsSync(path2.join(ROOT, ".agents", "skills", "ponytail", "SKILL.md"));
  result.push({ name: "Ponytail 스킬 (OpenCode)", installed: skillOc, hint: "" });
  result.push({ name: "Ponytail 스킬 (Claude Code)", installed: skillClaude, hint: "" });
  result.push({ name: "Ponytail 스킬 (Codex)", installed: skillCodex, hint: "" });

  // Playwright (조건부 필수 — package.json 있으면 필수, 없으면 대기)
  let playwright = false;
  try {
    const pkg = JSON.parse(fs2.readFileSync(path2.join(ROOT, "package.json"), "utf8"));
    if ((pkg.devDependencies && pkg.devDependencies["@playwright/test"]) ||
        (pkg.dependencies && pkg.dependencies["@playwright/test"])) {
      playwright = true;
    }
  } catch {}
  const hasPackageJson = fs2.existsSync(path2.join(ROOT, "package.json"));
  result.push({
    name: "Playwright",
    installed: playwright,
    hint: "",
    optional: !hasPackageJson, // package.json 없으면 대기, 있으면 필수
  });

  // jscpd — 항상 사용 가능
  result.push({ name: "중복 검사 (jscpd)", installed: true, hint: "" });

  return result;
}

module.exports = { run };
