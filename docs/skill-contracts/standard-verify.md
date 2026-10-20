# Standard Verify Contract

## Entry conditions

- 승인된 Exec Plan의 구현이 완료됐다.

## Required actions

- `scripts/verify-plan.sh <계획>`으로 lint, typecheck, test를 실행한다.
- AC별로 테스트·수동 확인·측정 중 실제 수행한 증거와 `PASS`/`FAIL`/`미검증`을 기록한다.
- 버그 작업은 재현 및 회귀를 확인한다.

## Outputs

- 실행 명령, 종료 코드, 주요 결과가 남은 검증 증거
- AC별 판정

## Exit conditions / next stage

- 모든 필수 검증과 AC가 PASS면 `standard-review`로 진행한다.
- FAIL/BLOCKED/미검증이면 Review로 진행하지 않고 원인에 따라 Implement 또는 Verify로 돌아간다.
  이때 `docs/testing-policy.md`의 회귀 방침에 따라 기존 결함(변경 전에도 실패)과
  이번 변경의 결함을 구분해 완료 기록에 남긴다.
