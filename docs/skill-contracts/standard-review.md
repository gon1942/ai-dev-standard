# Standard Review Contract

## Entry conditions

- Verify 증거와 AC별 판정이 있다.

## Required actions

- `scripts/review.sh` 기준으로 Standards Review와 Spec Review를 분리한다.
- 리뷰는 구현을 수행한 에이전트와 분리된 관점(별도 에이전트·세션 또는 사람)으로
  수행하며, 구현자의 설명이 아닌 diff와 기록만 근거로 삼는다.
- Standards는 범위·삭제·보안·임시 산출물·코드 표준을, Spec은 각 AC와 증거의 일치를,
  Evidence는 각 PASS가 실제 실행 증거(명령·종료 코드·출력)와 일치하는지를 점검한다.
- 판정과 근거를 Exec Plan에 기록한다.
- `READY_FOR_REVIEW` 선언 전 `scripts/converge-plan.sh <계획>`을 실행해
  AC·검증·리뷰 증거의 수렴을 확인한다.

## Outputs

- Standards/Spec Review 결과
- `scripts/converge-plan.sh <계획>`의 수렴 결과

## Exit conditions / next stage

- 두 리뷰와 수렴이 PASS면 `READY_FOR_REVIEW`까지 가능하다.
- FAIL이면 통과시키지 않고 Verify 또는 Implement로 되돌린다.
  WARN은 사유와 함께 사람 판단을 기다린다(자동으로 다음 단계로 진행하지 않는다).
  `done`은 사람 승인 전용이다.
