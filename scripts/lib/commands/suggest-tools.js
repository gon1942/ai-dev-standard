"use strict";

// suggest-tools — 세션 시작 시 보조 도구 설치 상태 확인·설치 안내·설치 실행.
// 대화형(y/N)으로 사용자 확인 후 실제 설치를 진행한다.
// --check 플래그 또는 비TTY 환경에서는 상태 출력만 한다.

const fs = require("fs");
const path = require("path");
const os = require("os");
const readline = require("readline");
const { ROOT } = require("../util");

function readJsonSafe(filePath) {
  try {
    return JSON.parse(fs.readFileSync(filePath, "utf8"));
  } catch {
    return null;
  }
}

function ask(question) {
  return new Promise((resolve) => {
    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout,
    });
    rl.question(`${question} [y/N] `, (answer) => {
      rl.close();
      resolve(answer.trim().toLowerCase() === "y");
    });
  });
}

// ── OpenCode 플러그인 ──
function opencodePluginStatus() {
  const local = path.join(ROOT, "opencode.json");
  const global = path.join(os.homedir(), ".config", "opencode", "opencode.json");
  for (const p of [local, global]) {
    const config = readJsonSafe(p);
    if (config && Array.isArray(config.plugin) && config.plugin.includes("@dietrichgebert/ponytail")) {
      return { installed: true, path: p };
    }
  }
  return { installed: false, path: null };
}

function installOpencodePlugin() {
  const target = path.join(ROOT, "opencode.json");
  let config = readJsonSafe(target) || {};
  if (!Array.isArray(config.plugin)) config.plugin = [];
  if (!config.plugin.includes("@dietrichgebert/ponytail")) {
    config.plugin.push("@dietrichgebert/ponytail");
    fs.writeFileSync(target, JSON.stringify(config, null, 2) + "\n", "utf8");
  }
  return `opencode.json에 플러그인 등록 완료 (${path.relative(ROOT, target)})`;
}

// ── 스킬 파일 (Claude Code / Codex / OpenCode) ──
function skillStatus(toolDir) {
  const skillPath = path.join(ROOT, toolDir, "skills", "ponytail", "SKILL.md");
  return { installed: fs.existsSync(skillPath), path: skillPath };
}

function installSkill(toolDir) {
  const source = path.join(ROOT, "vendor", "ponytail", "SKILL.md");
  const target = path.join(ROOT, toolDir, "skills", "ponytail", "SKILL.md");
  if (!fs.existsSync(source)) {
    return `원본 스킬 없음: ${source}`;
  }
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.copyFileSync(source, target);
  return `스킬 복사 완료: ${path.relative(ROOT, target)}`;
}

async function run(args) {
  const checkOnly = args.includes("--check");
  const out = [];
  const write = (line) => { out.push(line); process.stdout.write(line + "\n"); };

  write("=== 보조 도구 확인 ===");
  write("");

  const actions = [];

  // ── OpenCode 플러그인 ──
  const oc = opencodePluginStatus();
  write("OpenCode:");
  if (oc.installed) {
    write("  ✓ Ponytail 플러그인 (자동 활성화)");
  } else {
    write("  □ Ponytail 플러그인 (미설치)");
    write("    효과: 구현 중 매 턴 '이 코드 필요한가?' 자동 주입");
    actions.push({ label: "OpenCode 플러그인", install: installOpencodePlugin });
  }
  write("");

  // ── 스킬 파일 (3도구) ──
  const tools = [
    { name: "OpenCode", dir: ".opencode" },
    { name: "Claude Code", dir: ".claude" },
    { name: "Codex", dir: ".agents" },
  ];

  let allSkillsInstalled = true;
  for (const tool of tools) {
    const status = skillStatus(tool.dir);
    write(`${tool.name}:`);
    if (status.installed) {
      write(`  ✓ Ponytail 스킬 (구현 계약 의무)`);
    } else {
      write(`  □ Ponytail 스킬 (미설치)`);
      allSkillsInstalled = false;
      actions.push({
        label: `${tool.name} 스킬`,
        install: () => installSkill(tool.dir),
      });
    }
  }
  write("");

  // ── jscpd ──
  write("공통:");
  write("  ✓ 중복 검사 jscpd (verify 체인 자동 포함)");
  write("");

  // ── 설치 진행 ──
  if (actions.length === 0) {
    write("모든 보조 도구가 준비돼 있습니다.");
    write("");
    write("참고: Ponytail 스킬은 구현 계약이 의무로 적용하며, 플러그인은 추가 향상(지속 프롬프팅)입니다.");
    return;
  }

  if (checkOnly) {
    write(`미설치 항목 ${actions.length}건이 있습니다:`);
    for (const a of actions) write(`  - ${a.label}`);
    write("");
    write("설치하려면 대화형으로 실행하세요 (에이전트 세션에서 자동 진행).");
    return;
  }

  // 대화형: y/N 읽고 설치 실행
  write(`미설치 항목 ${actions.length}건:`);
  for (const a of actions) write(`  - ${a.label}`);
  write("");

  const confirmed = await ask("설치를 진행할까요?");
  if (!confirmed) {
    write("설치를 건너뛰었습니다. 나중에 `node scripts/lib/cli.js suggest-tools`로 다시 실행할 수 있습니다.");
    return;
  }

  write("");
  for (const action of actions) {
    try {
      const result = action.install();
      write(`  ✓ ${action.label}: ${result}`);
    } catch (error) {
      write(`  ✗ ${action.label}: ${error.message}`);
    }
  }
  write("");
  write("설치 완료. OpenCode는 재시작 후 플러그인이 활성화됩니다.");
  write("참고: 설치하지 않아도 프레임워크의 모든 게이트·검증은 완전히 작동합니다.");
}

module.exports = { run };
