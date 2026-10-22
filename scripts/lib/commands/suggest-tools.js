"use strict";

// suggest-tools — 세션 시작 시 보조 도구 설치 상태 확인·설치 안내·설치 실행.
// 보조 도구 목록을 표시하고 미설치 항목을 번호로 선택받아 설치한다.
// --check: 상태만 출력, --install: 승인 없이 전체 설치

const fs = require("fs");
const path = require("path");
const os = require("os");
const readline = require("readline");
const { spawnSync } = require("child_process");
const { ROOT } = require("../util");

function readJsonSafe(filePath) {
  try {
    return JSON.parse(fs.readFileSync(filePath, "utf8"));
  } catch {
    return null;
  }
}

function askNumber(prompt, max) {
  return new Promise((resolve) => {
    const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
    rl.question(`${prompt} (1-${max}, 취소=엔터): `, (answer) => {
      rl.close();
      const n = parseInt(answer.trim(), 10);
      resolve(Number.isNaN(n) ? 0 : n);
    });
  });
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
    id: "ponytail-skill",
    name: "Ponytail 스킬",
    desc: "구현 계약 의무 — 세 도구 공통 (Codex·Claude·OpenCode)",
    check: () => {
      return (
        fs.existsSync(path.join(ROOT, ".opencode", "skills", "ponytail", "SKILL.md")) ||
        fs.existsSync(path.join(ROOT, ".claude", "skills", "ponytail", "SKILL.md")) ||
        fs.existsSync(path.join(ROOT, ".agents", "skills", "ponytail", "SKILL.md"))
      );
    },
    install: () => {
      const source = path.join(ROOT, "vendor", "ponytail", "SKILL.md");
      if (!fs.existsSync(source)) throw new Error(`원본 없음: ${source}`);
      for (const dir of [".opencode", ".claude", ".agents"]) {
        const target = path.join(ROOT, dir, "skills", "ponytail", "SKILL.md");
        if (!fs.existsSync(target)) {
          fs.mkdirSync(path.dirname(target), { recursive: true });
          fs.copyFileSync(source, target);
        }
      }
      return "세 도구 스킬 복사 완료";
    },
  },
  {
    id: "playwright",
    name: "Playwright",
    desc: "E2E 브라우저 테스트 자동화",
    check: () => {
      // node_modules에 설치돼 있는지 또는 package.json에 있는지 확인
      const pkg = readJsonSafe(path.join(ROOT, "package.json"));
      if (pkg && pkg.devDependencies && pkg.devDependencies["@playwright/test"]) return true;
      if (pkg && pkg.dependencies && pkg.dependencies["@playwright/test"]) return true;
      return fs.existsSync(path.join(ROOT, "node_modules", "@playwright", "test"));
    },
    install: () => {
      // 패키지 매니저 감지
      let mgr = "npm";
      if (fs.existsSync(path.join(ROOT, "pnpm-lock.yaml"))) mgr = "pnpm";
      else if (fs.existsSync(path.join(ROOT, "yarn.lock"))) mgr = "yarn";
      else if (!fs.existsSync(path.join(ROOT, "package.json"))) {
        throw new Error("package.json이 없습니다. Node.js 프로젝트에서만 설치 가능합니다.");
      }
      // @playwright/test 설치
      const installCmd = mgr === "npm" ? ["install", "--save-dev", "@playwright/test"]
        : mgr === "pnpm" ? ["add", "--save-dev", "@playwright/test"]
        : ["add", "--dev", "@playwright/test"];
      const result = spawnSync(mgr, installCmd, { cwd: ROOT, stdio: "inherit" });
      if (result.status !== 0) throw new Error(`${mgr} install 실패`);
      // Chromium 브라우저 설치
      const browser = spawnSync("npx", ["--no-install", "playwright", "install", "chromium"], {
        cwd: ROOT, stdio: "inherit",
      });
      if (browser.status !== 0) throw new Error("Chromium 다운로드 실패");
      return `@playwright/test + Chromium 설치 완료 (${mgr})`;
    },
  },
  {
    id: "jscpd",
    name: "중복 검사 (jscpd)",
    desc: "verify 체인 자동 포함 — 별도 설치 불필요",
    check: () => true, // 항상 사용 가능 (npx 일회 실행)
    install: null,     // 설치 불필요
  },
];

async function run(args) {
  const checkOnly = args.includes("--check");
  const installAll = args.includes("--install");
  const write = (line) => process.stdout.write(line + "\n");

  write("=== 보조 도구 확인 ===");
  write("");

  // ── 상태 표시 ──
  const uninstalled = [];
  write("도구                    상태      설명");
  write("─────────────────────────────────────────────────────────────");

  for (const tool of TOOLS) {
    const installed = tool.check();
    const status = installed ? "설치됨" : "미설치";
    const pad = tool.name.length >= 10 ? "  " : " ".repeat(12 - tool.name.length);
    write(`  ${tool.name}${pad}${status}    ${tool.desc}`);
    if (!installed && tool.install) {
      uninstalled.push(tool);
    }
  }
  write("");

  // ── 모두 설치돼 있으면 종료 ──
  if (uninstalled.length === 0) {
    write("모든 보조 도구가 준비돼 있습니다.");
    return;
  }

  // ── --check 모드 ──
  if (checkOnly) {
    write(`미설치 ${uninstalled.length}건이 있습니다. 설치하려면 --install 또는 대화형으로 실행하세요.`);
    return;
  }

  // ── --install 모드 (에이전트가 채팅 승인 후 실행) ──
  if (installAll) {
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
    write(failed ? "일부 설치가 실패했습니다." : "설치 완료.");
    if (failed) process.exitCode = 1;
    return;
  }

  // ── 대화형: 번호 선택 ──
  write(`미설치 도구 ${uninstalled.length}건:`);
  write("");
  uninstalled.forEach((tool, i) => {
    write(`  ${i + 1}. ${tool.name} — 설치`);
  });
  write(`  ${uninstalled.length + 1}. 모두 설치`);
  write(`  ${uninstalled.length + 2}. 건너뛰기`);
  write("");

  const choice = await askNumber("선택", uninstalled.length + 2);

  if (choice === 0 || choice === uninstalled.length + 2) {
    write("건너뛰었습니다. 나중에 `node scripts/lib/cli.js suggest-tools`로 다시 실행할 수 있습니다.");
    return;
  }

  const targets = choice === uninstalled.length + 1 ? uninstalled : [uninstalled[choice - 1]];

  write("");
  let failed = false;
  for (const tool of targets) {
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
    write("설치 완료.");
  }
  write("참고: 설치하지 않아도 프레임워크의 모든 게이트·검증은 완전히 작동합니다.");
}

module.exports = { run };
