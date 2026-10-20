# Exec Plan: Session Preflight

- 상태: active
- 제품 명세: docs/product-specs/2026-10-19-session-preflight.md
- 생성: 2026-10-19, 담당: Codex

## 구현 계획

- 목적: 세션 시작 한 번의 환경 검사를 재사용하고, 환경 변경 때만 무효화한다.
- 범위: session cache, 지문 검사, 세션 스크립트, 도구 어댑터, 문서와 회귀 테스트.
- 제외: 특정 AI 도구의 비이식적 hook 강제 설정.
- 영향 파일 (예상): scripts/, docs/, .gitignore, AGENTS.md, .opencode/, .claude/

## 검증 계획

| AC | 검증 방법 | 기대 증거 |
|---|---|---|
| AC-01 | 세션 시작 실행 | 비추적 JSON에 결과·지문 저장 |
| AC-02 | status 전후 비교 | 설정 파일 수정 후 stale 판정 |
| AC-03 | BLOCK 대상 세션 실행 | exit 코드와 Plan/Coding 차단 상태 확인 |
| AC-04 | 어댑터·문서 검토 | 동일 session-preflight 진입점 참조 |

## 회귀 검증 대상

- scripts/project-preflight.sh
- scripts/test-project-preflight.sh
- scripts/check-framework.sh

## 완료 기록

| AC | 판정 | 증거 |
|---|---|---|
| AC-01 | PASS | `session-preflight --start`가 `.ai-dev-standard/session-preflight.json`에 판정·지문·진행 가능 여부를 저장한다. |
| AC-02 | PASS | 회귀 테스트에서 설정 파일 변경 뒤 `--status`가 `session_status: stale`과 종료 코드 2를 반환했다. |
| AC-03 | PASS | `scripts/session-preflight.sh --start|--status`가 공통 엔진을 호출하며 cache 없음/무효를 차단한다. |
| AC-04 | PASS | AGENTS, workflow, OpenCode/Claude 스킬이 세션 시작과 작업 요청 상태 확인을 구분한다. |

- 검증 결과: 구조·시나리오 검증 통과. 저장소가 `template` 모드이므로 실행 계획 상태는 `active`를 유지한다.
