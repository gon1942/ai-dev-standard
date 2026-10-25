# Standard Verify Contract

## Entry conditions

- 승인된 Exec Plan의 구현이 완료됐다.

## Required actions

- `node scripts/lib/cli.js record-verification-evidence <계획>`으로 승인된 검증 프로필의 필수 검사
  (또는 프로필이 없는 레거시 프로젝트의 필수 lint/typecheck/test)를 직접 실행하고
  종료 코드·실행 시각·현재 소스 상태의 기계적 증거를 남긴다.
- 기본 `scripts/verify-plan.sh <계획>`은 읽기 전용 진입점이다. 자동 증거 기록은 전용 명령에서만
  수행하며, 기록 명령이 PASS여도 AC·리뷰·상태·사람 승인은 바꾸지 않는다.
- `scripts/record-verification-evidence.sh`는 Unix 편의 shim이다. 도구·운영체제와 무관한
  공통 실행 경로는 Node CLI다.
- 검증 계약 버전 2 Plan이 E2E `필요`이면 자동 방식은
  `node scripts/lib/cli.js record-e2e-evidence <계획>`으로 실제 실행·종료 코드 증거를 기록한다.
  수동 Browser UAT 방식은 `standard-uat`에 따른 시나리오의 일시·관찰·판정을 기록한 뒤 같은
  명령으로 증거 형식을 확인한다.
- AC별로 테스트·수동 확인·측정 중 실제 수행한 증거와 `PASS`/`FAIL`/`미검증`을 기록한다.
- 검증 체인은 2단계다. 구현 반복 중에는 `record-verification-evidence --fast`로
  test 체인만 실행한 빠른 증거를 남기고, 수렴 전에는 full 체인(프로필 전체 검사·
  레거시 lint+typecheck+test) PASS 1회가 필수다. fast 증거만으로는 수렴 게이트가
  차단된다 — 최종 증거는 항상 full이어야 한다.
- 버그 작업은 재현 및 회귀를 확인한다.
- CRG의 `tests_for` 등으로 영향 테스트 후보를 먼저 실행할 수 있으나, graph 결과만으로 계획의 필수 회귀 검증을 생략하지 않는다.
- CRG를 Verify에서 사용한 경우 탐색 기록에 후보 테스트와 실제 회귀 검증의 구분을 남긴다.
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

- 자동 기록된 실행 명령·종료 코드·안전한 결과 요약·소스 상태
- 필요한 경우 자동 E2E 또는 수동 UAT의 E2E 증거
- AC별 판정

## Exit conditions / next stage

- 모든 필수 검증과 AC가 PASS면 `standard-review`로 진행한다.
- 모든 AC 판정이 완료되면 에이전트는 중간 보고 후 사용자 확인을 기다리지 않고
  즉시 독립 리뷰(standard-review)를 수행한다. 검증과 리뷰 사이에 사람 개입점은
  없으며, 다음 사람 개입점은 변경 사항 검토(완료 승인)다.
- 미검증·실패 AC가 있으면 "검증 완료"로 보고하지 않는다. 보고는 다음을 구분해
  제시한다: ① 통과한 항목과 증거 ② 남은 AC 목록과 확인 방법 ③ 다음 조치
  (재실행·수정·보류).
- FAIL/BLOCKED/미검증이면 Review로 진행하지 않고 원인에 따라 Implement 또는 Verify로 돌아간다.
  이때 `docs/testing-policy.md`의 회귀 방침에 따라 기존 결함(변경 전에도 실패)과
  이번 변경의 결함을 구분해 완료 기록에 남긴다.
