# Standard Review Contract

## Entry conditions

- `standard-verify`가 모든 필수 검증과 AC 판정을 완료했고, 각 AC가 `PASS`다.
- Verify 조건이 충족되면 에이전트는 사용자에게 다음 단계 진행 여부를 묻지 않고 즉시 Review를 시작한다.
- FAIL·미검증·검증 증거 누락이면 Review를 시작하지 않는다. 해당 AC·필요한 증거·복귀 단계(Implement 또는 Verify)를 사용자에게 구체적으로 안내한다.

## Required actions

- `scripts/review.sh --plan <계획> [기준점]`으로 Review Packet을 준비한다. Packet은 Product Spec, Exec Plan, AC·검증 요약, 기준점 이후 변경 상태(추적·스테이징·작업 트리·미추적 파일), 소스 지문을 제시한다.
- 비교 기준은 생략 시 현재 `HEAD`다. 더 넓은 브랜치 범위가 필요하면 기준점을 명시한다. 미추적 파일은 diff에 표시되지 않으므로 Packet에 나온 경로를 직접 읽는다.
- `scripts/review.sh`는 자료 준비 도구이며 리뷰 실행기나 테스트 실행기가 아니다. Review에서 테스트를 다시 돌리지 않는다. 검증 증거의 지문이 최신이고 결함 신호가 없으면 Verify 증거를 재사용한다. 리뷰 결과가 검증 문제를 드러내거나 소스가 바뀌면 그때만 Verify로 복귀한다.
- 기본은 구현자와 분리된 **단일 리뷰어 1회**가 Standards / Spec / Evidence 세 관점을 모두 검토하는 것이다. 병렬 리뷰는 대규모·고위험 작업에만 계획에 이유를 남기고 사용한다. Task마다 반복 리뷰하지 않고 Spec의 통합 구현 후 최종 리뷰를 수행한다.
- 리뷰는 구현을 수행한 에이전트와 분리된 관점(별도 에이전트·세션 또는 사람)으로
  수행하며, 구현자의 설명이 아닌 diff와 기록만 근거로 삼는다.
- 독립 리뷰 수행이 불가능하면(별도 세션·에이전트 확보 불가) 리뷰 완료로 보고하지
  않는다. "리뷰 대기" 상태와 필요한 조치(사람 리뷰 요청 등)를 명시한다. 수렴
  게이트는 리뷰 PASS가 기록되기 전까지 계속 차단된다.
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
- 리뷰 기록은 리뷰어 식별자, 검토 기준점, 검토 소스 지문, Standards / Spec / Evidence 각 판정,
  전체 판정과 발견사항을 포함한다. Exec Plan에 `리뷰 계약 버전: 1`이 있으면 구조화 리뷰
  기록을 사용하고 Converge가 현재 소스 지문과 일치하는지 확인한다. 버전 없는 기존 Plan은
  기존 리뷰 기록 형식을 유지한다.
- 버전 1 Plan에는 아래 형식으로 `## 리뷰 기록`을 작성한다. `검토 소스 지문`은 Review
  Packet의 `[검토 지문]` 값을 그대로 복사한다. 각 축과 전체 판정은 통과할 때 `PASS`, 막는
  발견이 있으면 `FAIL`로 기록한다. 발견사항에는 `없음` 또는 심도·근거·대상 파일을 적는다.

  ```markdown
  ## 리뷰 기록

  - 리뷰어: <독립 리뷰어 식별자>
  - 검토 기준점: <Review Packet의 기준>
  - 검토 소스 지문: <64자리 SHA-256>
  - Standards Review: PASS
  - Spec Review: PASS
  - Evidence Review: PASS
  - 결과: PASS
  - 리뷰: PASS
  - 발견사항: 없음
  ```

  판정이 실패하면 실패 축과 `결과`·`리뷰`를 모두 `FAIL`로 바꾸고 발견사항 및 복귀 단계를
  기록한다. 실패한 기록은 완료 증거로 사용할 수 없다.
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

## 외부 스킬 도입 판단

- Superpowers `requesting-code-review`의 독립 리뷰어 호출과 최소 입력 원칙을 공통 어댑터에
  반영한다. 플랫폼별 외부 스킬을 필수 설치하지 않는다.
- Matt Pocock `code-review`의 Standards/Spec 분리는 참고하되, 기존 Evidence 검토를 유지한다.
  두 개 이상의 병렬 리뷰어를 기본화하지 않아 비용과 지연이 불필요하게 증가하지 않게 한다.
- `receiving-code-review`는 피드백을 검증·처리하는 별도 작업에 해당하므로 이번 Review 실행
  단계에 추가하지 않는다.
