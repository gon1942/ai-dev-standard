# Standard Verify Contract

## Entry conditions

- 승인된 Exec Plan의 구현이 완료됐다.

## Required actions

- `scripts/verify-plan.sh <계획>`으로 lint, typecheck, test를 실행한다.
- AC별로 테스트·수동 확인·측정 중 실제 수행한 증거와 `PASS`/`FAIL`/`미검증`을 기록한다.
- 버그 작업은 재현 및 회귀를 확인한다.
- 검증 방법이 `UAT`로 지정된 AC는 `docs/skill-contracts/standard-uat.md` 계약을 함께 따른다.

### 5단계 검증 절차 (완료 선언 전 필수)

각 AC의 검증은 다음 순서를 따른다.

1. **IDENTIFY** — 이 AC의 완료를 증명할 명령·방법을 결정한다. 계획의 검증 계획을
   우선하고, 부족하면 검증 방법을 먼저 보강한다.
2. **RUN** — 검증 명령을 새로 실행한다. 과거 출력·세션 기억을 재사용하지 않는다.
3. **READ** — 출력 전체·종료 코드·실패 수를 직접 읽고 해석한다. 요약이나 성공 라인만
   확인하고 넘어가지 않는다.
4. **VERIFY** — 증거가 완료 주장을 실제로 뒷받침하는지 확인한다. 상관 없는 통과
   (lint 통과가 빌드 성공을, 테스트 통과가 요구사항 충족을 각각 증명하지 못하는 경우)와
   명세·AC와의 불일치를 구분해 판정한다.
5. **CLAIM** — 증거가 있는 AC만 완료로 기록한다. 증거 없는 완료 주장은 금지다.

### 3C 점검 (판정 보조)

판정 시 다음 세 관점을 점검한다.

- **Completeness** — 계획의 모든 작업·요구사항이 구현됐는가 (누락 없는가)
- **Correctness** — 구현이 명세의 의도와 일치하는가
- **Coherence** — 설계와 코드 구조가 기존 표준·패턴과 일관적인가

불일치 발견 시 Completeness·Correctness 문제는 Implement로, 증거 부족은 Verify에서
보완한다.

## Outputs

- 실행 명령, 종료 코드, 주요 결과가 남은 검증 증거
- AC별 판정

## Exit conditions / next stage

- 모든 필수 검증과 AC가 PASS면 `standard-review`로 진행한다.
- FAIL/BLOCKED/미검증이면 Review로 진행하지 않고 원인에 따라 Implement 또는 Verify로 돌아간다.
  이때 `docs/testing-policy.md`의 회귀 방침에 따라 기존 결함(변경 전에도 실패)과
  이번 변경의 결함을 구분해 완료 기록에 남긴다.
