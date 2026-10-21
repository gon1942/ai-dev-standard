"use strict";

// new-exec-plan — scripts/new-exec-plan.sh의 Node 이식.
// 절차·출력·종료 코드는 bash 구현과 동치여야 한다 (scripts/test-parity.sh).

const fs = require("fs");
const path = require("path");
const { ROOT, safeName, timestamp, fail, ensureDir } = require("../util");

function run(args) {
  // bash는 루트로 이동 후 인자를 검사한다 — 상대 경로 인자는 루트 기준으로 해석한다.
  if (args.length !== 1) {
    fail("사용법: scripts/new-exec-plan.sh <docs/product-specs/명세파일.md>", 2);
  }
  const specPath = path.resolve(ROOT, args[0]);
  if (!fs.existsSync(specPath)) {
    fail("사용법: scripts/new-exec-plan.sh <docs/product-specs/명세파일.md>", 2);
  }

  const specFile = args[0];
  const specContent = fs.readFileSync(specPath, "utf8");
  // bash: grep -Eq '^- 상태: approved$'
  if (!/^- 상태: approved$/m.test(specContent)) {
    fail(`승인된 제품 명세만 실행 계획으로 전환할 수 있습니다: ${specFile}`, 2);
  }

  // bash: sed -n 's/^# Product Spec: //p' | head -n 1
  const nameMatch = specContent.match(/^# Product Spec: (.*)$/m);
  const name = nameMatch ? nameMatch[1] : "";
  const { date, time } = timestamp();
  const safe = safeName(name);
  const planDir = path.join(ROOT, "docs", "exec-plans", "active");
  const planRel = `docs/exec-plans/active/${date}-${time}-${safe}.md`;
  const planFile = path.join(ROOT, planRel);
  ensureDir(planDir);

  const content = `# Exec Plan: ${name}

- 상태: active
- 승인: pending
- 제품 명세: ${specFile}
- 생성: ${date}, 담당: <이름/도구>

## 구현 계획

- 목적: ...
- 범위: ...
- 제외: ...
- 영향 파일 (예상): ...

## 구현 작업

<!-- 깊이가 단순이면 이 표를 생략할 수 있다. 확실하지 않은 항목은 지어내지 않고
     "조사 필요"로 남기고, 조사 후 이 계획을 갱신해 재승인받는다.
     운영 데이터 조회·계측 삽입 등 상태·권한에 영향을 주는 조사는 별도 승인이 필요하다. -->

| 순서 | 변경 대상 | 변경 내용·인터페이스 | 테스트·검증 명령 | 기대 증거 | AC |
|---:|---|---|---|---|---|
| 1 | ... | ... | ... | ... | ... |

## 검증 계획

| AC | 검증 방법 | 기대 증거 |
|---|---|---|
| AC-01 | 자동 테스트, 수동 확인, UAT, 측정 중 선택 | 테스트명·명령 출력·수동 확인 결과·UAT 관찰 기록 |

## 회귀 검증 대상

- 영향을 받는 기존 기능 또는 테스트: ...
`;

  fs.writeFileSync(planFile, content, "utf8");
  process.stdout.write(`실행 계획 생성: ${planRel}\n`);
}

module.exports = { run };
