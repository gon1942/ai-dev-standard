# CLAUDE.md — Claude Code 공통 지침 (어댑터)

> 이 파일은 얇은 진입점이다. 규칙의 진실 공급원은 `docs/`에 있다.

## 이 프로젝트의 규칙

Claude Code는 먼저 `AGENTS.md`를 읽고, 그 다음 필요한 도구별 skill과 `docs/` 계약을 읽는다.
`CLAUDE.md`는 Claude Code를 이 공통 진입점에 연결하는 얇은 어댑터다.

모든 규칙은 `AGENTS.md`와 `docs/`에서 관리한다:

- 작업 흐름: `docs/development-workflow.md`
- 완료 기준: `docs/definition-of-done.md`
- 코드 규칙: `docs/coding-standards.md`
- 테스트 정책: `docs/testing-policy.md`
- 기존 프로젝트 적용 계약: `docs/framework-manifest.md`
- 프로젝트 문맥 설정: `docs/project-bootstrap.md`
- Plan 전 준비 상태 검사: `docs/project-preflight.md`
- 세션 시작 검사·캐시: `docs/session-preflight.md`

## 요약 (전체는 위 문서에서)

1. 요청 범위 밖 변경 금지
2. 구현 후 `node scripts/lib/cli.js record-verification-evidence <실행계획>` 실행 —
   기계적 실행 증거를 남기고 AC 판정은 별도로 기록한다
3. 모든 새 작업은 `docs/product-specs/`와 `docs/exec-plans/`에 기록한다
4. 완료 선언은 `READY_FOR_REVIEW`까지만
5. 실행하지 않은 테스트를 실행했다고 보고하지 않는다
6. 프레임워크 최초 적용·구조 이상·사용자 재분석 요청일 때만 온보딩한다. 이때
   `scripts/check-framework.sh`와 읽기 전용 분석을 실행하고, 사용자 승인 전에는
   `scripts/bootstrap-framework.sh --init`을 실행하지 않는다.
7. 기존 프로젝트 적용은 매니페스트에 따라 생성·보존·병합 제안·제외를 먼저 분류하며,
   기존 파일을 자동 덮어쓰지 않는다.
8. 새 세션에서는 Session Preflight 뒤 `node scripts/lib/cli.js work-status`를 실행하고,
   활성 작업·전환 누락·승인 대기·진행 중·최근 완료·Git 변경을 사용자에게 정확한 건수 또는
   `없음`으로 보고한다. 사용자가 명령을 직접 실행하거나 요청할 필요는 없다. `승인 대기`는
   `READY_FOR_REVIEW` 상태의 계획만 뜻한다. 작업 요청에서는 Preflight 캐시 상태만 확인한다.
   BLOCK/무효 상태면 상태는 보고하되 Plan·Implement를 진행하지 않는다.
9. **필수 구성 도구는 사용자에게 묻지 않고 즉시 설치한다.**
   `npx init`로 프로젝트를 만들 때 도구 설치가 이미 승인된 것으로 간주한다.
   `work-status` 출력에서 미설치 도구를 발견하면 즉시
   `node scripts/lib/cli.js suggest-tools --install`을 실행한다.
   이는 프레임워크 운영에 필수적인 설정이므로 별도 사용자 승인이 필요 없다.

## 프로젝트 스킬

- `.claude/skills/plan` — Product Spec·Exec Plan·승인 게이트 워크플로
- `.claude/skills/implement` — 구현 워크플로
- `.claude/skills/verify` — 검증 워크플로
- `.claude/skills/review` — 독립 리뷰 워크플로
- `.claude/skills/improve` — 사람 승인형 개선 후보 워크플로
- `.claude/skills/apply-existing-project` — 기존 프로젝트 적용 워크플로
- `.claude/skills/project-bootstrap` — 프로젝트 문맥 설정 워크플로
- `.claude/skills/project-preflight` — Plan 전 공통 준비 상태 검사

## 커맨드

- `/verify` — 실행 계획 기반 검증·증거 기록 실행
- `/task-record` — 제품 명세·실행 계획 생성/갱신
