# Product Spec: Session Preflight

- 상태: approved
- 생성: 2026-10-19
- 사용자 요청: Project Preflight를 매 작업 요청이 아닌 AI 에이전트 세션 시작 시 실행하고, 결과를 세션 동안 재사용한다.

## 확정 요구사항

- 세션 시작 Preflight 결과를 로컬·비추적 파일에 저장한다.
- 환경 판단 파일의 지문이 바뀌면 저장 결과를 무효화한다.
- PASS/WARNING/BLOCK과 Plan/Coding 가능 여부를 세션 상태로 제공한다.
- 도구별 어댑터는 세션 시작에 공통 엔진을 실행하고 작업 요청에서는 캐시 상태만 확인한다.
- BLOCK 또는 무효 상태는 Plan/Coding을 막고 재검사를 요구한다.

## 완료 조건 (Acceptance Criteria)

| ID | 완료 조건 | 기대 결과 |
|---|---|---|
| AC-01 | 세션 결과 저장 | 로컬 JSON에 판정·진행 가능 여부·지문이 저장된다. |
| AC-02 | 캐시 유효성 검사 | 판단 파일 변경 전에는 유효, 변경 뒤에는 무효가 된다. |
| AC-03 | 세션 진입점 | start/status 명령으로 재검사와 상태 확인을 제공한다. |
| AC-04 | 공통 도구 연동 | Codex/OpenCode/Claude 지침이 세션 시작과 작업 요청을 구분한다. |

## 범위

- 포함: session 상태·지문·공통 세션 진입점·어댑터/문서 갱신
- 제외: 도구별 비표준 lifecycle hook 강제 설치, 세션 상태의 Git 추적
