# Standard Implement Contract

## Entry conditions

- 승인된 Product Spec과 Exec Plan이 있다.
- `scripts/validate-plan.sh <계획>`이 통과한다.
- Session Preflight가 `can_code=true`다.

## Required actions

- 승인된 AC·범위 안에서만 최소 변경으로 구현한다.
- 버그는 재현 테스트를, 자동화 가능한 변경은 테스트 우선을 적용한다.
  버그 유형은 `docs/testing-policy.md`의 진단 루프
  (재현→최소화→가설→계측→최소 수정)를 따른다.
  가능하면 실패 테스트→최소 구현→리팩터의 작은 단위로 진행하고
  단위마다 관련 테스트를 실행한다.
- 계획 밖 변경이 필요하면 중단하고 Plan으로 돌아간다.
- 수정 파일과 구현 판단을 Exec Plan 완료 기록 초안에 남긴다.

## Outputs

- 소스·테스트 변경
- 구현 근거가 있는 Exec Plan

## Exit conditions / next stage

- 계획한 구현이 끝나면 `standard-verify`로 진행한다. 구현 자체가 PASS 판정은 아니다.
