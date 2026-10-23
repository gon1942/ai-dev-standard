# Standard Implement Contract

## Entry conditions

- 승인된 Product Spec과 Exec Plan이 있다.
- `scripts/validate-plan.sh <계획>`이 통과한다.
- Session Preflight가 `can_code=true`다.
- 신규 프로젝트 검증 환경 구성 중에는 기능 구현을 시작하지 않는다. 승인된 계획에 따른
  `configure-verification` 실행이 필수 검사 PASS 후 `active` 전환을 완료해야 한다.
- 초기화 작업이 승인된 Bootstrap Plan에 있으면 먼저 `record-bootstrap-approval`의 내용 지문이
  일치하는지 확인하고 `configure-verification`으로 setup과 초기 검증을 실행한다. setup을 사용자가
  거부하면 실행하지 않으며, 실패하면 initializing에서 멈춰 원인·복구 방안을 보고한다.

## Required actions

- 승인된 AC·범위 안에서만 최소 변경으로 구현한다.
- 구현 파일을 수정하기 전에 프로젝트의 Ponytail 스킬을 반드시 읽고 적용한다:
  - Codex: `.agents/skills/ponytail/SKILL.md`
  - Claude Code: `.claude/skills/ponytail/SKILL.md`
  - OpenCode: `.opencode/skills/ponytail/SKILL.md`
  해당 도구 경로에 스킬이 없으면 임의로 생략하지 말고 구현을 중단해 프레임워크 골격을 보완한다.
  Ponytail은 이 구현 단계에서만 활성화하며 Plan·Verify·Review 단계에 상시 적용하지 않는다.
  승인 범위, TDD, 보안·접근성·검증 의무는 Ponytail보다 우선하며 완화할 수 없다.
  기존 코드나 계획된 구현 방식과 다른 재사용 방안을 발견하면 파일을 수정하기 전에 Plan으로 돌아가 계획을 갱신한다.
- 기능 변경과 버그 수정은 테스트 우선 개발을 의무로 수행한다 —
  RED 확인·증거 기록·기존 구현 재사용 예외의 기준은 `docs/testing-policy.md` §2.2를 따른다.
  버그 유형은 같은 문서의 진단 루프(재현→최소화→가설→계측→최소 수정)를 따른다.
- E2E 프로필 구성은 승인된 Exec Plan의 `## E2E 프로필 제안`에 선택된 프로필과 정확히 일치할 때만
  실행한다. 승인 전 설치·브라우저 다운로드·설정 생성은 금지하며, 기존 유효 설정은 덮어쓰지 않는다.
- 계획 밖 변경이 필요하면 중단하고 Plan으로 돌아간다.
- 수정 파일과 구현 판단을 Exec Plan 완료 기록 초안에 남긴다.
- Task Graph의 개별 Task가 끝나면 Task 상태와 진행 기록만 갱신한다. 완료된 Task마다 사용자에게 커밋 여부를 묻거나 커밋을 제안하지 않는다.
- 커밋 제안 시점, Spec 단위 기본값, 예외 및 별도 push 승인 규칙은 `docs/development-workflow.md` §7을 따른다. 구현 단계가 끝났다는 이유만으로 커밋을 제안하지 않는다.

## Execution mode (실행 모드)

- 기본 실행 모드는 `sequential`이다. Exec Plan에 `- 실행 모드:` 표기가 없으면
  `sequential`로 해석한다(기존 계획과 하위 호환). `parallel`은 P1~P5를 전부 통과하고
  사람이 Exec Plan 승인 시 명시한 경우에만 사용할 수 있다(커밋 정책은
  `standard-orchestration.md`). 병렬 실행은 활성화됐다(2026-10-23,
  task-graph-3단계 PoC 실측 기반 — OpenCode `verified`). P3 `unverified` 도구
  (Codex·Claude Code)에서는 여전히 sequential로 실행한다.
- Task Graph가 있는 계획은 아래 판별 기준으로 병렬 가능성을 판별할 수 있다.
  **판별과 실행 승인은 분리된다** — 판별 결과가 병렬 가능이어도 2단계에서는
  반드시 sequential로 실행하고, 판별 근거만 계획에 기록한다.
- 판별 기준 (P1~P4는 판별 조건, P5는 사람 실행 승인):
  - P1 frontier ≥ 2 — 의존이 모두 완료되어 즉시 실행 가능한 Task가 2개 이상인가.
    frontier는 Task Graph에서 파생되며, Task 상태 갱신(구현 완료·검증 완료)마다
    재계산할 수 있도록 정의한다. 2단계에서는 계획 시점 1회 판별만 수행한다.
  - P2 충돌 없음 — 병렬 후보 Task들의 변경 대상이 서로 겹치지 않는가. 비교 대상은
    Task 소유 파일뿐 아니라 공유 자원 전부다: 공유 인터페이스(같은 모듈의
    export·API 시그니처), 설정 파일(package.json, opencode.json, .env.example 등),
    생성 파일(dist/, docs/generated/ 등). 한 Task가 수정하고 다른 Task가 읽는
    자원도 충돌 후보로 본다.
  - P3 도구 지원 — 실행 환경이 격리된 서브에이전트와 Git Worktree를 지원하는가.
    **공식 제품 지원과 현재 환경 실측을 별도로 기록한다.**
    - 공식 제품 지원(제품 문서 기준): Codex와 Claude Code는 서브에이전트 및
      Worktree 기능을 지원한다. OpenCode는 서브에이전트를 지원하며 Worktree 연계는
      별도 확인이 필요하다.
    - 현재 환경 실측(이 프로젝트 기준):
      - OpenCode — `verified` (2026-10-23 PoC, `docs/exec-plans/` task-graph-3단계 계획:
        worktree 2개 병렬 구현·TDD·로컬 커밋·fast-forward 통합·통합 후 재검증 전 과정 성공)
      - Codex — `unverified`. 과거 별도 리뷰 에이전트 호출 실패 사례
        (`docs/references/2026-10-21-verification-engine-research.md`)는 해당 한 건의
        관찰이며, 병렬 실행 기능 전체가 미지원이라는 결론으로 확장하지 않는다.
      - Claude Code — `unverified`
    P3 판정 상태는 네 가지로 구분한다:
    - `verified` — 현재 환경에서 서브에이전트+Worktree 병렬 실행 실측 성공
    - `unverified` — 실측 없음 (현재 Codex·Claude Code 이 상태)
    - `unsupported` — 공식 문서상 미지원
    - `failed` — 실측했으나 실패
    **P3 실행 판정은 현재 환경의 실측 증거를 기준으로 한다.** `verified`만 P3
    통과이며, `unverified`·`unsupported`·`failed`는 sequential로 실행한다.
    공통 프레임워크는 모든 에이전트가 동일한 실행 기술을 사용하도록 강제하지
    않는다 — 실행 방식이 달라도 동일한 Exec Plan, AC, Verify·Review·Converge
    Gate를 적용한다. 에이전트별 병렬 기능은 개별 실측 검증을 통해 선택적으로
    활성화한다.
  - P4 검증 환경 독립 — gitignored 테스트 데이터, 환경변수, 외부 서비스에 의존하는
    Task는 병렬 실행 환경(Worktree)에서 검증이 조용히 건너뛰어질 수 있으므로 병렬
    판별에서 별도 표시하고, 해당 Task는 메인 체크아웃 실행 대상으로 기록한다.
  - P5 사람 승인 — 병렬 실행 자체는 Product Spec과 Exec Plan 통합 사전 승인 시
    Exec Plan에 실행 모드를 명시해 승인한다. 판별(P1~P4)이 전부 충족돼도 P5 없이
    병렬로 실행하지 않는다.
- 실행 모드와 무관하게 Verify·독립 Review·Converge 게이트는 동일하게 적용한다.
  병렬 실행이 도입되더라도(3단계 이후) 통합 후 전체 재검증 없이는 게이트를
  통과할 수 없다.
- 병렬 실행이 승인된 경우(P1~P5 전부 통과 + 사람의 `parallel` 명시) 구현은
  `docs/skill-contracts/standard-orchestration.md`를 따른다. 통합 브랜치·worktree
  브랜치의 로컬 커밋은 해당 Exec Plan 승인에 포괄 승인된다(공통 정책 — AGENTS.md §1).

## Outputs

- 소스·테스트 변경
- 구현 근거가 있는 Exec Plan

## Exit conditions / next stage

- 계획한 구현이 끝나면 `standard-verify`로 진행한다. 구현 자체가 PASS 판정은 아니다.
- 전체 작업의 통합 검증·리뷰·수렴 전에 커밋 제안을 하지 않는다. 승인된 병렬 Worktree 절차의 내부 로컬 커밋은 `standard-orchestration.md` 범위에서만 다룬다.
