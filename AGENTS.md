# AGENTS.md — AI 에이전트 공통 진입점

> 이 파일은 공통 진입점이다.
> 규칙·절차·실행 인터페이스의 진실 공급원은 `docs/`에 있다.
> 세부 규칙을 이 파일에 복제하지 않는다.

## 0. 세션 시작 필수 절차

모든 에이전트는 세션 시작 시 다음 명령을 실행하고 결과를 사용자에게 요약 보고한다.
이 절차 없이는 활성 작업·보조 도구 상태를 알 수 없다.

```bash
bash scripts/session-preflight.sh --start
node scripts/lib/cli.js work-status
```

work-status 출력의 **필수 구성 도구** 섹션에 미설치 도구가 있으면
**사용자에게 묻지 않고 즉시** `node scripts/lib/cli.js suggest-tools --install`을 실행해 설치한다.
이 도구들은 프레임워크 운영에 필수이며, `npx init` 또는 `apply` 시점에 이미 승인된 것이다.
별도 사용자 승인을 요청하지 않는다.

## 1. 불변 원칙

- 요청 범위 밖 변경을 하지 않는다.
- 실행하지 않은 검증을 실행했다고 보고하지 않는다.
- 필수 실행 증거 없이 검증 완료를 선언하지 않는다.
- 모든 새 작업은 Product Spec과 Exec Plan에 기록한다. 기록 없는 작업은 완료될 수 없다.
- AI는 `READY_FOR_REVIEW`까지만 선언할 수 있다.
  `done` 전환은 `docs/definition-of-done.md`의 사람 승인 및 완료 조건을 따른다.
- 사람 승인 없이 공통 정책·보안·검증 규칙·스킬·실행 게이트를 변경하지 않는다.
- 승인 없는 commit 또는 push를 하지 않는다. commit 승인과 push 승인은 별도로 취급한다.
- 민감정보(키·토큰·`.env` 등)를 출력·기록·커밋하지 않는다.
- 기존 테스트를 임의로 삭제하지 않는다. 불가피한 경우 사유를 공식 완료 기록에 남긴다.

## 2. 세션 시작

세션 시작 시 다음을 확인한다.

환경 준비:

- `docs/session-preflight.md`에 따라 세션 준비 상태를 확인한다.
- 세션 시작 시 `node scripts/lib/cli.js work-status`를 실행해 작업 상태와 필수 구성 도구 상태를 확인한다.
  필수 구성 도구에 미설치 항목이 있으면 **사용자에게 묻지 않고 즉시**
  `node scripts/lib/cli.js suggest-tools --install`을 실행해 설치한다.
  (Playwright는 제외 — 승인된 E2E 프로필로만 설치)
- `BLOCK` 또는 무효 상태에서는 Plan·Implement 단계로 진입하지 않는다.
- 같은 세션의 후속 요청에서는 전체 검사를 반복하지 않고 Preflight 캐시 유효성만 확인한다.
- 캐시 무효화 또는 재검사 조건이 발생하면 해당 계약에 따라 재검사한다.
- 필수 문서를 읽지 못했거나 준비 조건을 확인할 수 없으면 해당 단계에 진입하지 않는다.

작업 기록 복원:

- 기존 활성 작업이 있으면 그 Product Spec, Exec Plan 및 변경 파일을 확인하여 이전 작업의
  진행·검증·완료 상태를 파악한다.
- 모든 새 세션에서 `docs/development-workflow.md`의 세션 시작 절차에 따라 `work-status`를
  실행한다. 사용자가 명령을 직접 실행하거나 요청할 필요는 없다.
- 활성 작업·승인 대기·최근 완료·Git 변경 상태를 사용자에게 요약 보고한다. 새 요청이 있으면
  관련 활성 작업과 충돌 여부를, 없으면 요청 대기 상태를 함께 보고한다.
- 이전 검증 증거가 현재 소스와 여전히 일치하는지 확인한다 — 검증 PASS 이후 관련 소스가
  변경됐다면 그 PASS는 최신 완료 증거가 아니다.
- 요청과 관련된 이전 변경 파일·설계 결정·남은 위험만 상세 확인한다.
- 이전 에이전트의 완료 기록은 공식 검증 증거와 현재 작업 트리를 기준으로 확인하며,
  기록만으로 완료를 추정하지 않는다.
- 동일 작업의 활성 Exec Plan이 존재하면 중복 생성하지 않고 기존 작업을 이어간다.
- 재개한 이전 작업이 `READY_FOR_REVIEW` 상태이면 검토 대기로 취급하고 `done`으로 간주하지 않는다.
- 작업 상태는 증분 방식으로 확인하고, 매 세션 전체 프로젝트 분석을 반복하지 않는다.

## 3. 단계별 필수 문서

각 단계에 진입하기 전에 해당 문서를 읽는다.
같은 세션에서 이미 읽었고 내용이 바뀌지 않은 문서는 다시 읽지 않아도 된다.

| 진입 시점 | 필수 문서 |
|---|---|
| 세션 시작 | `docs/development-workflow.md`, `ARCHITECTURE.md`, `docs/session-preflight.md` |
| Plan | `docs/skill-contracts/standard-plan.md`, `docs/coding-standards.md`, `docs/definition-of-done.md` |
| Implement | `docs/skill-contracts/standard-implement.md`, `docs/coding-standards.md`, `docs/testing-policy.md` |
| Verify | `docs/skill-contracts/standard-verify.md`, `docs/testing-policy.md`, 필요 시 `docs/skill-contracts/standard-uat.md` |
| Review | `docs/skill-contracts/standard-review.md`, `docs/skill-contracts/standard-human-decision.md`, `docs/definition-of-done.md` |
| Improve | `docs/skill-contracts/standard-improve.md`, `docs/agent-improvements/README.md` |

## 4. 조건부 문서

다음 상황에서만 관련 문서를 읽는다.

- 프레임워크 최초 적용, 구조 이상, 사용자 재분석 요청:
  `docs/framework-onboarding.md`, `docs/framework-manifest.md`,
  `docs/project-bootstrap.md`
- Preflight가 `BLOCK`·무효이거나 재검사 원인 분석이 필요:
  `docs/project-preflight.md`
- 개선 후보 등록·승인·구현:
  `docs/agent-improvements/README.md` 및 Improve 계약
- 프로젝트의 소스 분석 현황이 필요한 경우:
  `docs/generated/project-inventory.md` (존재하는 경우)

일반 기능 요청마다 온보딩이나 전체 구조 분석을 반복하지 않는다.

## 5. 실행·검증·완료 경계

- 구체적 실행 명령과 플랫폼별 진입점은
  `docs/development-workflow.md` 및 해당 스킬 계약에 정의된 현재 실행 인터페이스를 따른다.
- Implement 진입 전에는 승인된 Product Spec·Exec Plan과 계획 게이트 통과가 필요하다.
- 스킬은 검증 전략 선정, AC 해석, 오류 분석, 의미적 충족 여부 판단을 담당한다.
- Node 런타임은 필수 명령을 직접 실행하고, Node 게이트는 증거 형식·승인 상태·상태 전이를 검사한다.
- `READY_FOR_REVIEW` 선언 전 필수 자동 검증을 수행한다. 단, 최신 PASS 증거의 내용 기반 소스 지문이 현재와 완전히 일치하면 재실행을 생략하고 그 증거를 재사용할 수 있다.
- 수동 확인·UAT 증거의 최신성은 Verify 계약과 공식 Exec Plan 기록을 따른다.
- `READY_FOR_REVIEW` 선언 전에는 필수 검증, 독립 리뷰, 수렴 게이트를 통과해야 한다.
- 공식 검증 증거와 AC별 판정은 Exec Plan에 기록한다.
- 작업 재개를 위한 보조 상태 정보가 존재하더라도 공식 검증 증거 및 완료 판정은 Exec Plan을 기준으로 한다.
- UAT의 최종 판정과 증거도 Exec Plan에 기록한다.
