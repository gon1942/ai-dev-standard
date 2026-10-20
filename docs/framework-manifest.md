# Framework Manifest — 기존 프로젝트 적용 계약

이 문서는 공통 프레임워크 자체의 **필수 자산, 소유권, 적용 방식**의 단일 진실 공급원이다.
`apply-existing-project`를 수행하는 에이전트는 대상 프로젝트를 수정하기 전에 이 문서와
`docs/framework-onboarding.md`를 읽는다.

## 적용 원칙

1. 에이전트는 프레임워크 원본과 대상 프로젝트의 소스·설정·테스트·기존 지침을 모두 읽고 비교한다.
2. 파일마다 아래 네 상태 중 하나를 선택해 적용 계획에 기록한다. 분류 없는 변경은 하지 않는다.
3. `생성`과 재생성 가능한 현황 문서 외의 의미 있는 변경은 diff와 함께 사용자에게 제안하고 승인 뒤에만 한다.
4. 대상 프로젝트의 더 구체적인 `AGENTS.md`, `CLAUDE.md`, 보안 규칙, 배포 규칙은 보존하며 공통 규칙이 이를 덮어쓰지 않는다.
5. 이 문서는 특정 프로젝트의 작업 이력·세션 파일·의존성·소스 코드를 포함하지 않는다.

## 실행 자산 목록

`docs/framework-runtime-assets.tsv`는 대상 프로젝트에 배포할 실행 자산의 **기계용 목록**이다.
`bootstrap-framework.sh`, `check-framework.sh`, 적용 분류 보고서와 Session Preflight는 이 목록을
사용한다. 이 문서는 자산의 소유권·승인 경계·적용 정책을 설명하는 사람용 계약으로 유지한다.

- `target-script`, `target-hook`: 대상에 없을 때만 복사하고 골격 검사에서 필수로 확인한다.
- `repository-test`: 이 프레임워크 원본의 회귀 테스트다. 대상 프로젝트에 복사하거나 대상의
  `verify.sh`에서 강제로 실행하지 않는다.
- 목록의 대상 배포 경로는 `scripts/` 또는 `global-hooks/` 아래의 상대 경로만 허용한다.
  절대 경로·상위 경로(`..`)·정규화되지 않은 경로는 골격 검사에서 차단한다.
- 실행 자산을 추가·삭제할 때는 TSV 목록과 이 Manifest의 정책 설명, bootstrap·check 회귀 테스트를
  함께 갱신한다.

| 처리 | 의미 | 실행 경계 |
|---|---|---|
| `생성` | 대상에 없고 공통 흐름에 필요한 자산 | 누락 파일/디렉터리만 생성 가능 |
| `보존` | 대상의 기존 사실·정책·도구별 규칙 | 원문을 덮어쓰지 않음 |
| `병합 제안` | 공통 진입점 또는 프로젝트 사실을 함께 담아야 하는 자산 | diff와 사용자 승인 후 반영 |
| `제외` | 작업 이력, 런타임 산출물 또는 특정 프로젝트 전용 자산 | 복사·변경하지 않음 |

## 관리 자산

| 경로 또는 영역 | 기본 처리 | 적용 규칙 |
|---|---|---|
| `docs/development-workflow.md` | 생성 | 없으면 공통 표준 흐름을 생성한다. 있으면 대상의 흐름을 보존하고 차이만 병합 제안한다. |
| `docs/definition-of-done.md`, `docs/coding-standards.md`, `docs/testing-policy.md` | 생성 | 없으면 생성한다. 기존 정책은 자동 교체하지 않는다. 충돌은 병합 제안한다. |
| `docs/framework-onboarding.md` | 생성 | 최초 적용·구조 복구·명시적 재분석에서만 실행되는 절차를 제공한다. |
| `docs/framework-runtime-assets.tsv` | 생성 | 대상 배포 실행 자산과 원본 전용 회귀 자산의 기계용 목록이다. |
| `docs/project-bootstrap.md`, `docs/project-constitution.md` | 생성 또는 병합 제안 | 최초 적용 후 분석·질문·승인으로 프로젝트 문맥과 원칙을 확정한다. |
| `docs/project-preflight.md` | 생성 | Plan 전 공통 준비 상태 검사·판정 규칙을 제공한다. |
| `docs/session-preflight.md` | 생성 | 세션 시작 검사·캐시·무효화 규칙을 제공한다. |
| `docs/global-session-hooks.md` | 생성 | 선택형 전역 SessionStart 설치와 보안 경계를 제공한다. |
| `docs/skill-contracts/` | 생성 | 도구 중립 Plan·Implement·Verify·Review·Improve 실행 계약의 SSOT다. |
| `docs/product-specs/`, `docs/exec-plans/{active,completed}/`, `docs/design-docs/` | 생성 | 비어 있으면 디렉터리와 인덱스만 생성한다. 기존 기록은 보존한다. |
| `docs/generated/project-inventory.md` | 생성/재생성 | `analyze-project.sh --write`가 소스에서 발견한 사실만 기록한다. 수동 설계 판단을 넣지 않는다. |
| `docs/agent-improvements/` | 생성 | 후보·승인·기각 기록 영역만 만든다. 승인 전 공통 규칙을 수정하지 않는다. |
| `AGENTS.md`, `CLAUDE.md`, 하위 지침 파일 | 병합 제안 | 대상의 기존 규칙·보안·운영 지침을 우선 보존한다. 공통 흐름 참조를 최소 추가하는 diff만 제안한다. |
| `ARCHITECTURE.md`, `docs/design-docs/project-context.md` | 생성 또는 병합 제안 | 소스·설정에서 확인 가능한 프로젝트 사실만 초안/갱신안으로 만든다. 불확실한 설계는 질문으로 남긴다. |
| `.ai-dev-standard.env` | 생성 또는 병합 제안 | 없으면 `template`으로 생성한다. 실제 lint/typecheck/test 명령 연결과 `active` 전환은 사용자 승인 후에만 한다. |
| `docs/framework-runtime-assets.tsv`의 `target-script`, `target-hook` | 생성 또는 병합 제안 | lint·test·Plan·Verify·Review·수렴·완료·개선 후보·온보딩 실행 자산이다. 없으면 제공하고, 기존 파일은 덮어쓰지 않는다. |
| `.opencode/`, `.claude/` | 병합 제안 | 기존 도구 설정·스킬을 보존한다. 공통 어댑터 추가는 충돌 없는 경로에서만 제안한다. |
| 소스, 패키지 잠금 파일, 의존성, CI/CD, 배포 설정 | 제외 | 이 적용 단계에서 변경하지 않는다. 필요하면 별도 제품 명세와 실행 계획을 만든다. |
| `docs/tasks/`, `docs/product-specs`의 과거 기록, `.opencode/plan.md`, `node_modules/`, 빌드 산출물, `repository-test` 자산 | 제외 | 복사·변환·삭제하지 않는다. |

## 에이전트 적용 절차

1. 대상 경로가 맞는지 확인하고, 대상 내부의 `AGENTS.md`와 더 가까운 지침 파일을 먼저 읽는다.
2. 프레임워크 원본에서 이 매니페스트와 표준 문서를 읽는다.
3. `scripts/analyze-project.sh --project-dir <대상>`과
   `scripts/plan-framework-apply.sh --project-dir <대상>`을 읽기 전용으로 실행한다.
4. 보고서의 `생성·보존·병합 제안·제외` 목록, 충돌, 사용자 질문을 사용자에게 제시한다.
5. 사용자가 승인한 범위에서만 누락 골격을 만들고, 기존 파일은 제안된 diff만 반영한다.
6. 적용 결과를 검사하고, 실제 검증 명령의 연결은 별도 제품 명세·실행 계획으로 진행한다.

## 승인 필요 경계

다음은 사용자의 명시적 승인이 없으면 하지 않는다.

- 기존 파일 내용의 수정·이동·삭제 또는 `AGENTS.md`/`CLAUDE.md` 병합
- 실제 lint/typecheck/test 명령 변경과 `AI_DEV_STANDARD_MODE=active` 전환
- 의존성 설치·변경, 소스 코드 변경, CI/CD·배포 설정 변경
- 공통 정책·보안·완료 기준·검증 정책 변경

`scripts/bootstrap-framework.sh --init`은 위 승인 뒤에도 **없는 파일과 디렉터리만** 생성하는 보조 수단이다.
의미 있는 병합 판단은 LLM이 이 매니페스트에 따라 수행하고, 사람이 diff를 승인한다.
