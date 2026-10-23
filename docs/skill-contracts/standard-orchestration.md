# Standard Orchestration Contract

병렬 실행(오케스트레이션) 계약. 순차 실행은 `standard-implement.md`를 따른다.
이 계약은 실행 방식만 규정하며 완료 판정 구조(Verify·독립 Review·Converge·사람 승인)는
실행 모드와 무관하게 동일하게 적용된다.

## Entry conditions

- 승인된 Product Spec과 Exec Plan이 있고 `validate-plan.sh`을 통과했다.
- Exec Plan에 `## Task Graph`가 있고 병렬 후보 Task들의 P1~P4 판별 기준
  (`standard-implement.md` 실행 모드 절)을 전부 통과했다.
- P3 도구 지원 상태가 해당 도구에서 `verified`다. `unverified`·`unsupported`·`failed`면
  이 계약을 적용하지 않고 순차로 실행한다.
- 사람이 Exec Plan 승인 시 실행 모드 `parallel`을 명시해 승인했다 (P5).
  `parallel`은 병렬 커밋 정책이 확정된 이후에만 Exec Plan에 사용할 수 있다.

## Required actions

1. **통합 브랜치를 생성한다.** HEAD 기반으로 `poc/`·`feature/` 등 접두사의 통합
   브랜치를 만든다. 모든 Task 결과는 이 브랜치에 통합된다.
2. **Task별 worktree와 브랜치를 생성한다.** 병렬 실행 Task마다 격리된 worktree를
   통합 브랜치 기반으로 만든다. 각 Task는 시작 전 자기 worktree가 통합 브랜치
   최신 기반인지 확인하고, 아니면 그 위로 reset한다.
3. **병렬 구현을 수행한다.** 각 worktree에서 해당 Task만 구현한다.
   - 구현은 `standard-implement.md` 의무(최소 변경·Ponytail·TDD)를 그대로 따른다.
   - 각 Task는 자체 RED→GREEN 증거(실행 명령·종료 코드·실패 출력·해당 AC)를 남긴다.
   - 서로 다른 Task의 진행 중인 작업을 참조하지 않는다. 공유 정보는 계획·스펙·
     탐색 노트로 전달한다.
   - gitignored 테스트 데이터·환경변수·외부 서비스에 의존하는 Task(P4 표시)는
     worktree가 아닌 메인 체크아웃에서 실행한다.
4. **로컬 커밋을 작성한다.** 각 worktree에서 완료된 Task를 커밋한다. 이 커밋은
   해당 Exec Plan 승인에 포괄 승인돼 있다(공통 정책 — AGENTS.md §1). 통합 요청
   전에 통합 브랜치 tip을 자기 브랜치에 반영해(역방향 merge) 통합이
   fast-forward로 끝나도록 한다.
5. **통합한다.** 완료 보고가 온 Task부터 순서대로 통합 브랜치에 merge한다.
   fast-forward 원칙이며 conflict 해결 병합이 발생하면 즉시 중단하고 복구 절차로
   간다. merge마다 frontier를 재계산해 새로 실행 가능한 Task가 있으면 기동한다.
6. **통합 후 전체 재검증을 수행한다.** 모든 Task 통합이 끝나면 통합 브랜치에서
   전체 검증 체인을 실행한다. 개별 worktree의 PASS는 통합 결과의 PASS가 아니다.
   재검증 없이는 게이트를 통과할 수 없다.
7. **정리한다.** 모든 worktree를 삭제한다. 통합 브랜치의 공유 브랜치(main·develop)
   병합·push는 사람 별도 승인 대상이며 이 계약이 자동화하지 않는다.

## 실패·복구

- 서브에이전트 실패: 동일 Task 1회 재시도. 2회 연속 실패 시 해당 Task를 순차로
  강전환하고 원인을 Exec Plan에 기록한 뒤 나머지를 계속한다.
- merge 충돌: 자동 해결을 시도하지 않는다. 충돌한 두 Task에 긴급 의존(Task Graph
  엣지)을 추가하고 순차 재실행한다.
- 오케스트레이터 중단: 이미 통합 브랜치에 merge된 Task는 유효하다(증거 지문이
  통합 상태를 기억). 미통합 worktree는 폐기하고 재개한다.
- worktree에서 테스트가 조용히 건너뛰어지는 것을 발견하면(P4 위반) 해당 Task만
  메인 체크아웃에서 재실행한다.

## P3 실측 기록

- 병렬 실행 실측(PoC·실전 동일)이 성공하면 대상 도구의 P3 상태를 `unverified`에서
  `verified`로 갱신하고, 실패하면 `failed`로 기록한다. 갱신은 실측을 수행한 계획의
  완료 기록에 근거하며 `standard-implement.md` P3의 환경 실측 목록에 반영한다.
- `verified`는 판별 통과일 뿐 실행 승인(P5)을 대체하지 않는다.

## Outputs

- 통합 브랜치의 구현 결과와 Task별 RED·GREEN 증거
- 통합 후 전체 재검증 증거
- PoC의 경우 실측 메트릭(소요 시간·충돌 발생·재검증 결과)

## Exit conditions / next stage

- 통합 후 재검증까지 끝나면 `standard-verify` 이후 절차(독립 리뷰·수렴·사람 승인)를
  순차 실행과 동일하게 따른다. 병렬 실행 자체가 완료 판정은 아니다.
