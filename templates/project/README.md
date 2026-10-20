# <프로젝트 이름>

이 저장소에는 AI Dev Standard 공통 개발 프레임워크가 적용되어 있다.

## 첫 시작

1. 사용하는 AI 에이전트(Codex, OpenCode, Claude Code)를 이 프로젝트 루트에서 실행한다.
2. 에이전트에게 프로젝트 목적, 기술 스택, 주요 사용자 흐름, 인증·데이터·검증 요구사항을 설명한다.
3. 에이전트는 `docs/project-bootstrap.md`에 따라 `ARCHITECTURE.md`,
   `docs/design-docs/project-context.md`, `docs/project-constitution.md` 초안을 제안한다.
4. 실제 lint·typecheck·test 명령을 확인하고 승인한 뒤 `.ai-dev-standard.env`를
   `active` 모드로 전환한다.

처음에는 `template` 모드이므로 Plan은 만들 수 있지만, 실제 검증 구성이 확정되기 전에는
`READY_FOR_REVIEW`를 선언할 수 없다.

## 작업 흐름

```text
Session Preflight
  → Product Spec 승인
  → Exec Plan 승인
  → Implement
  → Verify
  → Review
  → READY_FOR_REVIEW
  → 사람 승인·머지
```

자세한 규칙은 `AGENTS.md`와 `docs/development-workflow.md`를 따른다.
