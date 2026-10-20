# AGENTS.md — AI 에이전트 공통 지침 (어댑터)

> 이 파일은 얇은 진입점이다. 규칙의 진실 공급원은 `docs/`에 있다.
> 규칙을 여기 복제하지 마라 — 어긋난다.

## 시작 시 반드시 읽을 문서

1. `docs/development-workflow.md` — 표준 작업 흐름 (필수)
2. `docs/coding-standards.md` — 코드 규칙 (구현 전)
3. `docs/definition-of-done.md` — 완료 기준 + 실행 계획 스키마 (완료 전)
4. `ARCHITECTURE.md` — 저장소 지식 구조와 의존성 지도
5. `docs/agent-improvements/README.md` — 개선 후보·사람 승인 규칙
6. `docs/framework-onboarding.md` — 신규·기존 프로젝트 온보딩 절차
7. `docs/framework-manifest.md` — 기존 프로젝트 적용 시 필수 자산·승인 경계
8. `docs/project-bootstrap.md` — 최초 적용 시 프로젝트 문맥 설정 절차
9. `docs/project-preflight.md` — Plan 전 공통 준비 상태 판정
10. `docs/session-preflight.md` — 세션 시작 검사·캐시·무효화 규칙
11. `docs/generated/project-inventory.md` — 있으면 현재 소스 분석 현황 (재생성 가능)
12. `docs/skill-contracts/` — Plan·Implement·Verify·Review·Improve 공통 실행 계약

## 다섯 줄 원칙

1. 요청 범위 밖 변경 금지
2. 구현 후 `scripts/verify-plan.sh <실행계획>` 실행 — 결과를 계획에 남긴다
3. 모든 새 작업은 제품 명세와 실행 계획으로 기록한다 (기록 없는 완료 없음)
4. 완료 선언은 `READY_FOR_REVIEW`까지만 — `done`은 사람 승인
5. 실행하지 않은 테스트를 실행했다고 보고하지 않는다
6. 개선 후보는 기록만 하고, 사람 승인 전 공통 규칙·스킬·스크립트를 수정하지 않는다
7. 온보딩은 프레임워크 최초 적용·구조 이상·사용자 재분석 요청에서만 수행한다.
   일반 기능 요청마다 구조 검사를 반복하지 않는다.
8. 소스에서 확인한 프로젝트 사실은 `ARCHITECTURE.md`와 설계 문서에 반영할 수 있지만,
   공통 정책·보안·검증 규칙은 사람 승인 없이 바꾸지 않는다.
9. 기존 프로젝트 적용은 매니페스트에 따라 생성·보존·병합 제안·제외로 먼저 분류한다.
   기존 파일 병합은 사용자 승인 전 수행하지 않는다.
10. `READY_FOR_REVIEW` 선언 전 `scripts/converge-plan.sh <실행계획>`으로 AC·검증·리뷰
    증거를 수렴 판정한다.
11. 세션 시작 시 `scripts/session-preflight.sh --start`를 한 번 실행한다. 작업 요청마다 전체
    검사를 반복하지 말고 `--status`로 캐시 유효성만 확인한다. BLOCK/무효 상태면 Plan/Coding으로 진행하지 않는다.

## 금지

- 승인 없는 commit / push
- 기존 테스트 삭제 (불가피하면 완료 기록에 사유)
- 민감정보(키·토큰·.env) 출력/커밋
