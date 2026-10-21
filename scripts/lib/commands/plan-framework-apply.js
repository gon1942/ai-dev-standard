"use strict";

// plan-framework-apply — scripts/plan-framework-apply.sh 원본의 Node 이식.

const fs = require("fs");
const path = require("path");
const { fail } = require("../util");

// 프레임워크 원본 위치 — 모듈 실위치 기준.
const FRAMEWORK_ROOT = path.resolve(__dirname, "..", "..", "..");

function isSafeRuntimeAssetPath(p) {
  if (!(p.startsWith("scripts/") || p.startsWith("global-hooks/"))) return false;
  const guard = `/${p}/`;
  return !(guard.includes("/../") || guard.includes("/./") || guard.includes("//"));
}

function stateFor(projectDir, assetPath, recommendation) {
  if (fs.existsSync(path.join(projectDir, assetPath))) {
    return recommendation === "생성" ? "보존 또는 병합 제안" : recommendation;
  }
  return recommendation;
}

// find <dir> \( -name AGENTS.md -o -name CLAUDE.md \) -not node_modules/.git | sort 상당.
function findGuidelineFiles(projectDir) {
  const results = [];
  const walk = (dir) => {
    let entries = [];
    try {
      entries = fs.readdirSync(dir, { withFileTypes: true });
    } catch {
      return;
    }
    for (const entry of entries) {
      if (entry.name === "node_modules" || entry.name === ".git") continue;
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) walk(full);
      else if (entry.isFile() && (entry.name === "AGENTS.md" || entry.name === "CLAUDE.md")) {
        results.push(full);
      }
    }
  };
  walk(projectDir);
  return results.sort();
}

function parseTsvLine(line) {
  const firstTab = line.indexOf("\t");
  if (firstTab === -1) return { scope: line, assetPath: "", label: "" };
  const scope = line.slice(0, firstTab);
  const rest = line.slice(firstTab + 1);
  const secondTab = rest.indexOf("\t");
  const assetPath = secondTab === -1 ? rest : rest.slice(0, secondTab);
  const label = secondTab === -1 ? "" : rest.slice(secondTab + 1);
  return { scope, assetPath, label };
}

function buildReport(projectDir) {
  const out = [];
  const write = (line) => out.push(line);

  write("# Framework Apply Plan (Generated)");
  write("");
  write("> 읽기 전용 분석 보고서다. 적용 규칙의 SSOT는 docs/framework-manifest.md다.");
  write("");
  write(`- 프레임워크 원본: \`${FRAMEWORK_ROOT}\``);
  write(`- 대상 프로젝트: \`${projectDir}\``);
  write("");
  write("## 적용 분류");
  write("");
  write("| 자산 | 권장 처리 | 근거 |");
  write("|---|---|---|");
  for (const [assetPath, label] of [
    ["docs/development-workflow.md", "공통 작업 흐름"],
    ["docs/definition-of-done.md", "완료 기준"],
    ["docs/coding-standards.md", "코딩 표준"],
    ["docs/testing-policy.md", "테스트 정책"],
    ["docs/framework-onboarding.md", "온보딩 지침"],
    ["docs/framework-manifest.md", "적용 자산과 승인 경계"],
    ["docs/framework-runtime-assets.tsv", "기계용 실행 자산 목록"],
    ["docs/global-session-hooks.md", "선택형 전역 세션 hook 안내"],
    ["docs/product-specs", "제품 명세 기록 영역"],
    ["docs/exec-plans/active", "활성 실행 계획 영역"],
    ["docs/exec-plans/completed", "완료 실행 계획 영역"],
    ["docs/design-docs", "설계 문서 영역"],
    ["docs/agent-improvements", "개선 기록 영역"],
    ["ARCHITECTURE.md", "프로젝트 구조 지도"],
    ["docs/design-docs/project-context.md", "프로젝트 문맥"],
    [".ai-dev-standard.env", "검증 모드 설정"],
  ]) {
    write(`| \`${assetPath}\` | ${stateFor(projectDir, assetPath, "생성")} | ${label} |`);
  }
  const catalog = path.join(FRAMEWORK_ROOT, "docs", "framework-runtime-assets.tsv");
  if (fs.existsSync(catalog)) {
    for (const rawLine of fs.readFileSync(catalog, "utf8").split("\n")) {
      const line = rawLine.replace(/\r$/, "");
      if (line === "") continue;
      const { scope, assetPath, label } = parseTsvLine(line);
      if (scope === "" || scope.startsWith("#") || scope === "repository-test") continue;
      if (scope === "target-script" || scope === "target-hook") {
        if (isSafeRuntimeAssetPath(assetPath)) {
          write(`| \`${assetPath}\` | ${stateFor(projectDir, assetPath, "생성")} | ${label} |`);
        } else {
          write(`| \`${assetPath}\` | 확인 필요 | 허용되지 않은 실행 자산 경로 |`);
        }
      } else {
        write(`| \`${assetPath}\` | 확인 필요 | 알 수 없는 실행 자산 범위: ${scope} |`);
      }
    }
  } else {
    write("| `docs/framework-runtime-assets.tsv` | 확인 필요 | 프레임워크 원본의 실행 자산 목록이 없음 |");
  }
  write("| `AGENTS.md`, `CLAUDE.md`, 하위 지침 | 병합 제안 | 대상의 기존 규칙을 보존하고 참조만 최소 추가 |");
  write("| `.opencode/`, `.claude/` | 병합 제안 | 기존 도구 설정을 보존하고 충돌 없는 어댑터만 제안 |");
  write("| 소스·의존성·잠금 파일·CI/CD·배포 | 제외 | 이 적용 단계에서는 변경하지 않음 |");
  write("| 작업 이력·세션 파일·빌드 산출물·원본 전용 회귀 테스트 | 제외 | 복사·변환·삭제하지 않음 |");
  write("");
  write("## 감지된 대상 지침");
  const guidelines = findGuidelineFiles(projectDir);
  if (guidelines.length > 0) {
    for (const file of guidelines) {
      write(`- \`${file.startsWith(projectDir + path.sep) ? file.slice(projectDir.length + 1) : file}\``);
    }
  } else {
    write("- 없음 — 공통 진입점 생성 후보");
  }
  write("");
  write("## 승인 전 사용자 확인 사항");
  write("");
  write("- 기존 지침 파일에 공통 흐름 참조를 추가해도 되는가?");
  write("- 기존 lint/typecheck/test 명령 중 공통 검증에 연결할 명령은 무엇인가?");
  write("- 구조 문서의 사실 갱신 범위와, 보존해야 할 기존 문서는 무엇인가?");
  write("");
  write("## 다음 단계");
  write("");
  write("- 이 보고서는 대상 파일을 바꾸지 않는다. 에이전트는 승인된 범위에서만 누락 골격 생성 또는 제안된 diff 반영을 수행한다.");
  return out.join("\n") + "\n";
}

function run(args) {
  let projectDir = process.cwd();
  let writeReport = false;
  for (let i = 0; i < args.length; i += 1) {
    const arg = args[i];
    if (arg === "--project-dir") {
      if (!args[i + 1]) fail("사용법: scripts/plan-framework-apply.sh [--project-dir <프로젝트경로>] [--write]", 2);
      projectDir = args[i + 1];
      i += 1;
    } else if (arg === "--write") {
      writeReport = true;
    } else if (arg === "-h" || arg === "--help") {
      process.stderr.write("사용법: scripts/plan-framework-apply.sh [--project-dir <프로젝트경로>] [--write]\n");
      return;
    } else {
      fail("사용법: scripts/plan-framework-apply.sh [--project-dir <프로젝트경로>] [--write]", 2);
    }
  }
  if (!fs.existsSync(projectDir) || !fs.statSync(projectDir).isDirectory()) {
    fail(`프로젝트 경로가 없습니다: ${projectDir}`, 2);
  }
  projectDir = path.resolve(projectDir);

  const report = buildReport(projectDir);
  if (writeReport) {
    fs.mkdirSync(path.join(projectDir, "docs", "generated"), { recursive: true });
    const reportPath = path.join(projectDir, "docs", "generated", "framework-apply-plan.md");
    fs.writeFileSync(reportPath, report, "utf8");
    process.stdout.write(`프레임워크 적용 계획 생성: ${reportPath}\n`);
  } else {
    process.stdout.write(report);
  }
}

module.exports = { run };
