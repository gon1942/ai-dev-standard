#!/usr/bin/env bash
# 사용자 전역 설정에 ai-dev-standard SessionStart hook을 병합한다.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
GLOBAL_ROOT="${AI_DEV_STANDARD_GLOBAL_ROOT:-$HOME/.ai-dev-standard}"
HOOK_DIR="$GLOBAL_ROOT/hooks"
mkdir -p "$HOOK_DIR" "$HOME/.config/opencode/plugin" "$HOME/.codex" "$HOME/.claude"
cp "$ROOT/global-hooks/session-start.sh" "$HOOK_DIR/session-start.sh"
chmod +x "$HOOK_DIR/session-start.sh"
cp "$ROOT/global-hooks/opencode-session-preflight.mjs" "$HOME/.config/opencode/plugin/ai-dev-standard-session-preflight.mjs"

AI_DEV_STANDARD_SOURCE_ROOT="$ROOT" node - "$HOME/.codex/hooks.json" "$HOME/.claude/settings.json" "$HOOK_DIR/session-start.sh" <<'NODE'
const fs = require('fs');
const [codexFile, claudeFile, hookPath] = process.argv.slice(2);
const sourceRoot = process.env.AI_DEV_STANDARD_SOURCE_ROOT;
const command = `AI_DEV_STANDARD_ROOT=${JSON.stringify(sourceRoot)} bash ${JSON.stringify(hookPath)}`;
for (const file of [codexFile, claudeFile]) {
  const data = fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, 'utf8')) : {};
  data.hooks ||= {};
  data.hooks.SessionStart ||= [];
  const exists = data.hooks.SessionStart.some(group =>
    (group.hooks || []).some(hook => hook.command === command));
  if (!exists) {
    data.hooks.SessionStart.push({ hooks: [{ type: 'command', command, timeout: 15, statusMessage: 'AI Dev Standard preflight' }] });
    if (fs.existsSync(file)) {
      const backup = `${file}.ai-dev-standard.bak`;
      if (!fs.existsSync(backup)) fs.copyFileSync(file, backup);
    }
    fs.writeFileSync(file, `${JSON.stringify(data, null, 2)}\n`);
  }
}
NODE

echo "Installed global SessionStart integration. Review/trust the Codex hook with /hooks, then restart Codex, OpenCode, and Claude Code."
