# Exec Plan: Project Preflight

- 상태: active
- 제품 명세: docs/product-specs/2026-10-19-project-preflight.md
- 생성: 2026-10-19, 담당: Codex

## 구현 계획

- 목적: 모든 에이전트가 Plan 전 동일한 프로젝트 준비 상태를 판정하도록 한다.
- 범위: 기존 분석/검사/초기화 재사용, 안전 복구, Markdown/JSON 보고, 상태 게이트, 얇은 어댑터.
- 제외: 기존 파일 내용 자동 병합, 의존성·CI/CD·소스 변경.
- 영향 파일 (예상): scripts/, docs/, AGENTS.md, .opencode/, .claude/, README.md

## 검증 계획

| AC | 검증 방법 | 기대 증거 |
|---|---|---|
| AC-01 | Node/Python 임시 프로젝트에서 Markdown/JSON 실행 | 기술 신호·판정·후속 가능 여부 출력 |
| AC-02 | 누락 대상에 `--repair` 후 재실행 | 생성 후 기존 AGENTS 내용 보존 |
| AC-03 | 손상 env·JSON·스크립트 대상 | BLOCK과 원인 출력 |
| AC-04 | 도구별 스킬·AGENTS 문서 검토 | 동일 엔진과 상태 규칙 참조 |
| AC-05 | 반복 실행과 기존 스크립트 회귀 검사 | 두 번째 실행 무변경, shell syntax/check-framework 통과 |

## 회귀 검증 대상

- scripts/analyze-project.sh
- scripts/check-framework.sh
- scripts/bootstrap-framework.sh
- scripts/verify-plan.sh

## 완료 기록

| AC | 판정 | 증거 |
|---|---|---|
| AC-01 | PASS | `scripts/project-preflight.sh`가 Markdown/JSON, 기술 신호, 검사·판정·진행 가능 여부를 제공한다. |
| AC-02 | PASS | 임시 Node 대상에서 `--repair`로 누락 골격을 생성하고 기존 `AGENTS.md` 내용을 보존했다. |
| AC-03 | PASS | template WARNING, active PASS, 손상 `package.json`/잘못된 env BLOCK을 실제 실행으로 확인했다. |
| AC-04 | PASS | AGENTS, workflow, OpenCode/Claude preflight 스킬이 단일 엔진과 동일 상태 게이트를 참조한다. |
| AC-05 | PASS | `scripts/test-project-preflight.sh`로 T2~T12와 Node active PASS를 재실행 가능하게 만들었다. |

- 검증 결과: 구조·시나리오 검증 통과. 저장소가 `template` 모드이므로 실행 계획 상태는 `active`를 유지한다.
