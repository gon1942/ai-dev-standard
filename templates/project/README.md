# <프로젝트 이름>

이 저장소에는 AI Dev Standard 공통 개발 프레임워크가 적용되어 있다.

## 첫 시작

1. 사용하는 AI 에이전트(Codex, OpenCode, Claude Code)를 이 프로젝트 루트에서 실행한다.
2. 에이전트에게 프로젝트 목적, 기술 스택, 주요 사용자 흐름, 인증·데이터·검증 요구사항을 설명한다.
3. 에이전트는 `docs/project-bootstrap.md`에 따라 `ARCHITECTURE.md`,
   `docs/design-docs/project-context.md`, `docs/project-constitution.md` 초안을 제안한다.
4. 사용자의 요청과 기존 프로젝트 신호로 기술 스택·검증 방식을 계획하고, Product Spec과
   Exec Plan의 통합 사전 승인을 받는다. 도구 선택은 계획에 포함하며 ESLint를 일괄 설치하지 않는다.
5. 신규 프로젝트는 승인 후 `node scripts/lib/cli.js record-bootstrap-approval <계획>`으로 승인 내용
   지문을 기록하고, 승인된 `Bootstrap 검증 프로필`을 `scripts/configure-verification.sh <계획>`으로
   구성·실행한다. 필수 setup 및 검사가 모두 통과해야 `active`로 전환된다.

처음에는 `template` 모드다. Preflight는 Plan, 초기화, 기능 Coding 권한을 분리한다.
`initializing` 중에는 승인된 검증 명령만 실행하고 일반 기능 코딩은 하지 않는다. 프로필이 없는
기존 프로젝트는 이전 lint/test 규칙을 호환해 사용한다.

## 작업 흐름

```text
Session Preflight
  → Product Spec + Exec Plan 통합 사전 승인 (1회)
  → Implement
  → Verify
  → Review
  → READY_FOR_REVIEW
  → 리뷰 후 사람 완료 승인·머지 (별도 1회)
```

자세한 규칙은 `AGENTS.md`와 `docs/development-workflow.md`를 따른다.
