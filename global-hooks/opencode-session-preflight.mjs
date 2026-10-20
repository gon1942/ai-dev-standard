// OpenCode loads global plugins from ~/.config/opencode/plugin.
// Run once per session creation; failures are informational and never alter project files directly.
import { execFile } from "node:child_process";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);
const hookPath = process.env.AI_DEV_STANDARD_SESSION_HOOK
  || "/home/gon/.ai-dev-standard/hooks/session-start.sh";
const seen = new Set();

export const AiDevStandardSessionPreflight = async () => ({
  event: async ({ event }) => {
    if (event?.type !== "session.created") return;
    const sessionId = event?.properties?.info?.id || event?.properties?.sessionID;
    if (!sessionId || seen.has(sessionId)) return;
    seen.add(sessionId);
    try {
      await execFileAsync(hookPath, [], { cwd: process.cwd(), timeout: 15000 });
    } catch {
      // A failed preflight is recorded by its own status file; do not break OpenCode startup.
    }
  },
});

export default AiDevStandardSessionPreflight;
