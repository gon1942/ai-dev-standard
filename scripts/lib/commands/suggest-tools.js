"use strict";

// suggest-tools — 필수 구성 도구 설치 상태 확인·설치 실행.
// 이 도구들은 프레임워크 운영에 필요하므로 선택이 아닌 자동 설치를 원칙으로 한다.
// 기본 동작: 미설치 항목을 자동으로 설치한다.
// --check: 상태만 출력 (설치하지 않음)

const fs = require("fs");
const path = require("path");
const os = require("os");
const { spawnSync } = require("child_process");
const { ROOT } = require("../util");

function readJsonSafe(filePath) {
  try {
    return JSON.parse(fs.readFileSync(filePath, "utf8"));
  } catch {
    return null;
  }
}

// ── 도구 정의 ──
const TOOLS = [
  {
    id: "ponytail-plugin",
    name: "Ponytail 플러그인",
    desc: "구현 중 최소 구현 판단 보조 (지속 프롬프팅)",
    check: () => {
      const local = path.join(ROOT, "opencode.json");
      const global = path.join(os.homedir(), ".config", "opencode", "opencode.json");
      for (const p of [local, global]) {
        const config = readJsonSafe(p);
        if (config && Array.isArray(config.plugin) && config.plugin.includes("@dietrichgebert/ponytail")) {
          return true;
        }
      }
      return false;
    },
    install: () => {
      const target = path.join(ROOT, "opencode.json");
      let config = readJsonSafe(target) || {};
      if (!Array.isArray(config.plugin)) config.plugin = [];
      if (!config.plugin.includes("@dietrichgebert/ponytail")) {
        config.plugin.push("@dietrichgebert/ponytail");
        fs.writeFileSync(target, JSON.stringify(config, null, 2) + "\n", "utf8");
      }
      return `opencode.json에 등록 완료 (OpenCode 재시작 필요)`;
    },
  },
  {
    id: "ponytail-skill-opencode",
    name: "Ponytail 스킬 (OpenCode)",
    desc: "구현 계약 의무",
    check: () => fs.existsSync(path.join(ROOT, ".opencode", "skills", "ponytail", "SKILL.md")),
    install: () => {
      const source = path.join(ROOT, "vendor", "ponytail", "SKILL.md");
      if (!fs.existsSync(source)) throw new Error(`원본 없음: ${source}`);
      const target = path.join(ROOT, ".opencode", "skills", "ponytail", "SKILL.md");
      fs.mkdirSync(path.dirname(target), { recursive: true });
      fs.copyFileSync(source, target);
      return "스킬 복사 완료";
    },
  },
  {
    id: "ponytail-skill-claude",
    name: "Ponytail 스킬 (Claude Code)",
    desc: "구현 계약 의무",
    check: () => fs.existsSync(path.join(ROOT, ".claude", "skills", "ponytail", "SKILL.md")),
    install: () => {
      const source = path.join(ROOT, "vendor", "ponytail", "SKILL.md");
      if (!fs.existsSync(source)) throw new Error(`원본 없음: ${source}`);
      const target = path.join(ROOT, ".claude", "skills", "ponytail", "SKILL.md");
      fs.mkdirSync(path.dirname(target), { recursive: true });
      fs.copyFileSync(source, target);
      return "스킬 복사 완료";
    },
  },
  {
    id: "ponytail-skill-codex",
    name: "Ponytail 스킬 (Codex)",
    desc: "구현 계약 의무",
    check: () => fs.existsSync(path.join(ROOT, ".agents", "skills", "ponytail", "SKILL.md")),
    install: () => {
      const source = path.join(ROOT, "vendor", "ponytail", "SKILL.md");
      if (!fs.existsSync(source)) throw new Error(`원본 없음: ${source}`);
      const target = path.join(ROOT, ".agents", "skills", "ponytail", "SKILL.md");
      fs.mkdirSync(path.dirname(target), { recursive: true });
      fs.copyFileSync(source, target);
      return "스킬 복사 완료";
    },
  },
  {
    id: "playwright",
    name: "Playwright",
    desc: fs.existsSync(path.join(ROOT, "package.json"))
      ? "E2E 브라우저 테스트"
      : "E2E 테스트 — 기술스택 감지 후 설치",
    check: () => {
      const pkg = readJsonSafe(path.join(ROOT, "package.json"));
      if (pkg && pkg.devDependencies && pkg.devDependencies["@playwright/test"]) return true;
      if (pkg && pkg.dependencies && pkg.dependencies["@playwright/test"]) return true;
      return fs.existsSync(path.join(ROOT, "node_modules", "@playwright", "test"));
    },
    // 조건부 필수: package.json 있는 프로젝트만 자동 설치 (빈 템플릿은 대기)
    install: fs.existsSync(path.join(ROOT, "package.json"))
      ? () => {
          const result = spawnSync("npm", ["install", "--save-dev", "@playwright/test"], {
            cwd: ROOT, stdio: "inherit",
          });
          if (result.status !== 0) throw new Error("npm install 실패");
          const browser = spawnSync("npx", ["--no-install", "playwright", "install", "chromium"], {
            cwd: ROOT, stdio: "inherit",
          });
          if (browser.status !== 0) throw new Error("Chromium 다운로드 실패");
          return "@playwright/test + Chromium 설치 완료";
        }
      : null,
  },
  {
    id: "jscpd",
    name: "중복 검사 (jscpd)",
    desc: "verify 체인 자동 포함 — 별도 설치 불필요",
    check: () => true,
    install: null,
  },
];

async function run(args) {
  const checkOnly = args.includes("--check");
  const write = (line) => process.stdout.write(line + "\n");

  write("=== 필수 구성 도구 확인 ===");
  write("");

  // ── 상태 표시 ──
  const uninstalled = [];
  write("도구                      상태      설명");
  write("─────────────────────────────────────────────────────────────");

  for (const tool of TOOLS) {
    const installed = tool.check();
    const status = installed ? "설치됨" : "미설치";
    const pad = " ".repeat(Math.max(1, 22 - tool.name.length));
    write(`  ${tool.name}${pad}${status}    ${tool.desc}`);
    if (!installed && tool.install) {
      uninstalled.push(tool);
    }
  }
  write("");

  // ── 모두 설치돼 있으면 종료 ──
  if (uninstalled.length === 0) {
    write("모든 필수 구성 도구가 준비돼 있습니다.");
    return;
  }

  // ── --check 모드 ──
  if (checkOnly) {
    write(`미설치 ${uninstalled.length}건이 있습니다. 자동 설치하려면 --install 또는 기본 실행하세요.`);
    process.exitCode = 1;
    return;
  }

  // ── 자동 설치 (기본 동작) ──
  write(`미설치 ${uninstalled.length}건을 자동 설치합니다...`);
  write("");
  let failed = false;
  for (const tool of uninstalled) {
    try {
      const result = tool.install();
      write(`  ✓ ${tool.name}: ${result}`);
    } catch (error) {
      write(`  ✗ ${tool.name}: ${error.message}`);
      failed = true;
    }
  }
  write("");
  if (failed) {
    write("일부 설치가 실패했습니다. 실패 항목을 확인한 뒤 재시도하세요.");
    process.exitCode = 1;
  } else {
    write("설치 완료. OpenCode는 재시작 후 플러그인이 활성화됩니다.");
  }
}

module.exports = { run };
