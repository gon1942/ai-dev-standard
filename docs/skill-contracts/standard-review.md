# Standard Review Contract

## Entry conditions

- Verify 증거와 AC별 판정이 있다.

## Required actions

- `scripts/review.sh` 기준으로 Standards Review와 Spec Review를 분리한다.
- 리뷰는 구현을 수행한 에이전트와 분리된 관점(별도 에이전트·세션 또는 사람)으로
  수행하며, 구현자의 설명이 아닌 diff와 기록만 근거로 삼는다.
- **리뷰어 입력은 최소로 제한한다**: 제품 명세(AC) + 변경 범위(diff) + 검증 증거만
  전달한다. 구현 세션의 대화 이력이나 구현자의 자기 평가는 전달하지 않는다.
- Standards는 범위·삭제·보안·임시 산출물·코드 표준을, Spec은 각 AC와 증거의 일치를,
  Evidence는 각 PASS가 실제 실행 증거(명령·종료 코드·출력)와 일치하는지를 점검한다.
- CRG가 준비되어 있으면 blast radius로 변경 심볼의 caller·dependent·연관 테스트 누락을 점검하고, 실제 diff와 원본 소스로 교차 확인한다.
- CRG 탐색 기록이 있으면 명령·결과 반영·원본 교차 확인이 diff와 일치하는지 점검한다.
- 발견은 심도로 분류해 기록한다:
  - `CRITICAL` — 승인 불가. 수정 전 `READY_FOR_REVIEW` 선언 불가
    (범위 위반, 증거 왜곡 정황, 보안 문제, 기존 기능 회귀 등)
  - `WARNING` — 사람 판단 필요 (아래 Exit 조건 준용)
  - `SUGGESTION` — 이번 승인을 막지 않는 개선 제안
- 판정과 근거를 Exec Plan에 기록한다.
- `READY_FOR_REVIEW` 선언 전 `scripts/converge-plan.sh <계획>`을 실행해
  AC·검증·리뷰 증거의 수렴을 확인한다.
- 수렴이 PASS면 사용자에게 **검토 결정 필요**로 보고한다. 사용자 보고 형식은
  `standard-human-decision` 계약을 따르며, 변경 사항 검토 결과·자동 검증·명세 충족·남은 위험과
  완료 처리·개선 요청·보류 선택을 함께 제시한다.
- `DONE` 또는 완료 표현은 사람의 명시적 승인 뒤 `complete-exec-plan`이 계획을
  `completed/`로 이동한 후에만 사용한다.
- 검증 계약 버전 2 Plan의 검토 요약에는 E2E 판정·실행 결과 또는 미검증 사유를 별도 표시한다.
  E2E가 필요하지만 증거가 없으면 PASS 리뷰·완료 처리를 제안하지 않는다.

## Outputs

- Standards/Spec Review 결과
- `scripts/converge-plan.sh <계획>`의 수렴 결과
- 사람 결정을 위한 검토 요청 보고

## Exit conditions / next stage

- `CRITICAL`이 있으면 수정 전 `READY_FOR_REVIEW` 및 완료 승인을 제안하지 않고
  Implement 또는 Verify로 되돌린다.
- `WARNING`이 있으면 위험과 근거를 제시하고, 사람의 완료 승인·개선 요청·보류 판단을 기다린다.
- `SUGGESTION`만 있거나 리뷰가 PASS이고 수렴이 PASS면 `READY_FOR_REVIEW`로 보고하고,
  사람에게 완료 승인·개선 요청·보류를 제시한다.
- 완료 승인을 받으면 `complete-exec-plan`으로 계획을 `completed/`로 이동할 수 있다.
  `done`은 이 처리 후에만 사용한다.
