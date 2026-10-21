"use strict";

// install-global-session-hooks — scripts/install-global-session-hooks.sh 원본의 Node 이식.
// 원본이 내장하던 node 인라인 스크립트 로직(설정 병합·백업)을 그대로 이행했다.

const fs = require("fs");
const os = require("os");
const path = require("path");

// 프레임워크 원본 위치 — 모듈 실위치 기준 (AI_DEV_STANDARD_ROOT 오버라이드와 무관).
const FRAMEWORK_ROOT = path.resolve(__dirname, "..", "..", "..");

function mergeSessionHook(codexFile, claudeFile, hookPath, sourceRoot) {
  const command = `AI_DEV_STANDARD_ROOT=${JSON.stringify(sourceRoot)} bash ${JSON.stringify(hookPath)}`;
  for (const file of [codexFile, claudeFile]) {
    const data = fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, "utf8")) : {};
    data.hooks ||= {};
    data.hooks.SessionStart ||= [];
    const exists = data.hooks.SessionStart.some((group) =>
      (group.hooks || []).some((hook) => hook.command === command)
    );
    if (!exists) {
      data.hooks.SessionStart.push({
        hooks: [{ type: "command", command, timeout: 15, statusMessage: "AI Dev Standard preflight" }],
      });
      if (fs.existsSync(file)) {
        const backup = `${file}.ai-dev-standard.bak`;
        if (!fs.existsSync(backup)) fs.copyFileSync(file, backup);
      }
      fs.writeFileSync(file, `${JSON.stringify(data, null, 2)}\n`);
    }
  }
}

function run(args) {
  void args;
  const home = os.homedir();
  const globalRoot = process.env.AI_DEV_STANDARD_GLOBAL_ROOT || path.join(home, ".ai-dev-standard");
  const hookDir = path.join(globalRoot, "hooks");
  fs.mkdirSync(hookDir, { recursive: true });
  fs.mkdirSync(path.join(home, ".config", "opencode", "plugin"), { recursive: true });
  fs.mkdirSync(path.join(home, ".codex"), { recursive: true });
  fs.mkdirSync(path.join(home, ".claude"), { recursive: true });

  fs.copyFileSync(path.join(FRAMEWORK_ROOT, "global-hooks", "session-start.sh"), path.join(hookDir, "session-start.sh"));
  fs.chmodSync(path.join(hookDir, "session-start.sh"), 0o755);
  fs.copyFileSync(
    path.join(FRAMEWORK_ROOT, "global-hooks", "opencode-session-preflight.mjs"),
    path.join(home, ".config", "opencode", "plugin", "ai-dev-standard-session-preflight.mjs")
  );

  mergeSessionHook(
    path.join(home, ".codex", "hooks.json"),
    path.join(home, ".claude", "settings.json"),
    path.join(hookDir, "session-start.sh"),
    FRAMEWORK_ROOT
  );

  process.stdout.write(
    "Installed global SessionStart integration. Review/trust the Codex hook with /hooks, then restart Codex, OpenCode, and Claude Code.\n"
  );
}

module.exports = { run };
