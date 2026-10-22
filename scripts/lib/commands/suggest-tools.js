"use strict";

// suggest-tools — 세션 시작 시 보조 도구 설치 상태 확인·설치 안내.
// 설치는 강제하지 않는다. 사용자가 확인하면 에이전트가 적절한 명령을 안내한다.

const fs = require("fs");
const path = require("path");
const os = require("os");
const { ROOT } = require("../util");

function readJsonSafe(filePath) {
  try {
    return JSON.parse(fs.readFileSync(filePath, "utf8"));
  } catch {
    return null;
  }
}

function ponytailPluginInstalled() {
  const configPath = path.join(os.homedir(), ".config", "opencode", "opencode.json");
  const localConfig = path.join(ROOT, "opencode.json");
  for (const p of [localConfig, configPath]) {
    const config = readJsonSafe(p);
    if (config && Array.isArray(config.plugin) && config.plugin.includes("@dietrichgebert/ponytail")) {
      return true;
    }
  }
  return false;
}

function ponytailSkillIncluded() {
  return (
    fs.existsSync(path.join(ROOT, ".opencode", "skills", "ponytail", "SKILL.md")) ||
    fs.existsSync(path.join(ROOT, ".claude", "skills", "ponytail", "SKILL.md")) ||
    fs.existsSync(path.join(ROOT, ".agents", "skills", "ponytail", "SKILL.md"))
  );
}

function jscpdAvailable() {
  // duplicate-check가 이미 verify 체인에 포함돼 있으므로 항상 사용 가능
  return true;
}

function run(args) {
  void args;
  const out = [];
  const write = (line) => out.push(line);

  write("=== 보조 도구 확인 ===");
  write("");

  // 이미 프로젝트에 포함된 것
  write("프로젝트에 포함된 것:");
  if (ponytailSkillIncluded()) {
    write("  ✓ Ponytail 스킬 (구현 계약 의무 — 세 도구 공통)");
  }
  if (jscpdAvailable()) {
    write("  ✓ 중복 검사 jscpd (verify 체인 자동 포함)");
  }
  write("");

  // 추가 설치 권장
  write("추가 설치 권장:");
  if (!ponytailPluginInstalled()) {
    write("  □ Ponytail 플러그인 (OpenCode 전용 — 지속적 프롬프팅)");
    write("    효과: 구현 중 매 턴 '이 코드 필요한가?' 자동 주입");
    write("    설치 방법:");
    write("      1. 프로젝트 opencode.json의 plugin 배열에 추가:");
    write('         "@dietrichgebert/ponytail"');
    write("      2. 또는 전역 설정(~/.config/opencode/opencode.json)에 추가");
    write("      3. OpenCode 재시작");
    write("");
    write("    에이전트가 설치를 진행할 수 있습니다.");
    write("    설치하시겠습니까? (y/N)");
  } else {
    write("  ✓ Ponytail 플러그인 (이미 설치됨)");
  }

  write("");
  write("참고:");
  write("  - Ponytail 스킬(계약 의무)은 플러그인 없이도 구현 단계에서 자동 적용됩니다.");
  write("  - 플러그인은 추가 향상(지속적 프롬프팅)이며 필수가 아닙니다.");
  write("  - 설치하지 않아도 프레임워크의 모든 게이트·검증은 완전히 작동합니다.");

  process.stdout.write(out.join("\n") + "\n");
}

module.exports = { run };
