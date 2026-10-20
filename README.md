# AI Dev Standard — 공통 개발 표준 프레임워크

> Codex · OpenCode · Claude Code — 서로 다른 AI 코딩 도구가 하나의 프로젝트에서
> **동일한 절차로 계획·구현·검증·기록**하게 만드는 공통 개발 표준

이 저장소는 프레임워크를 개발·검증하는 원본이다. 신규 프로젝트에는 원본을 그대로
복사하지 않고, 검증된 배포 템플릿을 사용한다. 기존 프로젝트에는 승인된 범위에서 골격만
안전하게 적용할 수 있다. 원본과 배포물의 경계는
[`docs/framework-distribution.md`](docs/framework-distribution.md)를 따른다.

## 왜 필요한가

AI 코딩 도구를 여러 개 쓰거나, 사람과 AI가 같은 프로젝트에서 작업할 때 발생하는 문제를
다음처럼 해결한다.

| 일반적인 AI 개발 문제 | AI Dev Standard의 대응 |
|---|---|
| 에이전트마다 작업 순서와 품질 기준이 다름 | `docs/`의 공통 계약과 동일한 Plan → Implement → Verification 흐름 |
| AI가 요청을 받은 즉시 코드를 수정함 | Product Spec과 Exec Plan을 먼저 만들고 사람 승인을 받음 |
| "테스트 통과"라는 말만 남고 무엇을 확인했는지 모름 | AC별 증거, 실제 명령, 종료 코드, 리뷰 결과를 Exec Plan에 기록 |
| 도구별 설정이 서로 어긋남 | 규칙은 `docs/` 한 곳에 유지, 도구별 스킬은 얇은 어댑터 |
| 반복된 실수가 대화 기록에만 남음 | 개선 후보를 기록하고 사람이 승인/기각 |

## 핵심 설계 (5원칙)

1. **진실 공급원은 `docs/`** — AGENTS.md/CLAUDE.md/스킬은 얇은 어댑터
2. **검증 진입점은 `scripts/verify.sh` 하나** — 구현 완료 후 로컬에서 실행
3. **AI 완료 선언 ≠ 기능 완료** — `READY_FOR_REVIEW`까지만 AI가 선언,
   `done`은 검증 증거 + 사람 승인
4. **제품 명세와 실행 계획이 1급 자산** — 기록 없는 완료 없음
5. **실행 계층** — 프롬프트(지침) → 스크립트(검증)

## 하는 일 / 하지 않는 일

| 하는 일 | 하지 않는 일 |
|---|---|
| 프로젝트가 개발 준비 상태인지 세션 시작에 검사 | 사용자의 요구사항이나 제품 결정을 임의로 확정 |
| 요구사항을 Product Spec·AC·Exec Plan으로 기록 | 승인 없이 기존 코드·정책·의존성·CI/CD를 대규모 변경 |
| 구현 뒤 실제 검증·리뷰 증거를 수렴 | 테스트를 실행하지 않고 PASS라고 보고 |
| 반복 문제를 개선 후보로 제안 | 사람 승인 없이 규칙·스킬·스크립트를 자동 수정 |

## 하나의 요청이 남기는 기록

모든 작업은 대화 기록이 아니라 **저장소의 공식 파일**로 남는다.

```text
사용자: "로그인 페이지를 만들어줘"

사용자 요청
  → docs/product-specs/<로그인>.md      요구사항, 범위, 제외 범위, AC
  → docs/exec-plans/active/<로그인>.md  구현 방법, AC별 검증 방법, 증거, 리뷰 결과
  → 코드·테스트 변경
  → 사람 승인 후 docs/exec-plans/completed/<로그인>.md 로 보관
```

나중에 다른 사람이나 다른 AI가 봐도 "무엇을 요청했고, 어떤 기준으로 구현했고,
무엇으로 검증했는지"를 파일에서 확인할 수 있다.

## 표준 작업 흐름

```
세션 시작 Preflight → 요청 → 제품 명세(draft) → 사람 승인(approved) → 실행 계획(active)
    → 구현(implement 스킬) → 검증(scripts/verify-plan.sh <실행계획>)
    → 독립 리뷰(review 스킬) → 완료 기록 작성
    → 최종 수렴(converge-plan) → PR → 사람 승인 → completed/ 이동
    → 선택적 회고(개선 후보 기록) → 사람 결정 → 별도 제품 명세/실행 계획
```

| 단계 | 목적 | 완료 기준 |
|---|---|---|
| 세션 준비 | 작업 가능 범위 결정 (PASS/WARNING/BLOCK) | `session-preflight.sh --start` |
| Plan | 요청을 승인 가능한 명세·계획으로 확정 | 승인된 Spec + Plan + `validate-plan` PASS |
| Implement | 승인된 범위 안에서 코드·테스트 변경 | 계획된 구현 완료 |
| Verification | 실행 증거와 독립 리뷰로 AC 확인 | Verify + Review + Convergence PASS |
| 완료·학습 | 사람 승인으로 완료, 개선 후보 기록 | 사람 승인 → `done` |

## 배포 템플릿 만들기

GitHub Template 또는 향후 `ai-dev-standard init` / `apply` CLI가 소비할 배포물은 아래 명령으로
만든다. 출력 경로는 존재하지 않아야 하며, 기존 경로를 덮어쓰거나 삭제하지 않는다.

```bash
scripts/build-framework-template.sh --output /tmp/ai-dev-standard-template
```

빌드 결과에는 원본 Product Spec·Exec Plan 이력, 세션 캐시, Preflight 보고서, OpenCode 로컬
의존성, 원본 전용 회귀 테스트가 포함되지 않는다. 이 결과를 별도 GitHub Template 저장소 또는
Release 아카이브로 배포한다. 이 원본 저장소를 GitHub의 `Use this template` 대상으로 직접
사용하지 않는다.

## 새 프로젝트에 적용하기

1. GitHub Template로 만든 새 저장소를 사용하거나, 승인된 배포 템플릿을 프로젝트 루트에 적용
2. `.ai-dev-standard.env`에서 `AI_DEV_STANDARD_MODE=active`로 바꾸고 필수 검사를 선택
3. **PLACEHOLDER 검색** (`grep -rn PLACEHOLDER`) 후 스택에 맞게 수정:
   - `scripts/lint.sh` — 린터 (기본: ESLint/ruff 자동 감지)
   - `scripts/test.sh` — 테스트 러너 (기본: jest/pytest 자동 감지)
   - 의존성 설치는 프로젝트 스택의 표준 명령(npm ci, pip install 등)을
     README 또는 문서에 직접 안내한다
4. `scripts/verify.sh`를 실행해 모든 필수 검사가 실제로 실행되는지 확인
5. `docs/product-specs/`, `docs/exec-plans/`의 흐름을 프로젝트에 맞게 확인
6. 첫 커밋

새 작업은 `scripts/new-product-spec.sh <작업명> <사용자 요청 원문>`으로 제품 명세를 만들고,
사람이 승인한 뒤 `scripts/new-exec-plan.sh <명세파일>`로 실행 계획을 생성한다.

### 검증 모드: template / active

| 모드 | 의미 |
|---|---|
| `template` | 공통 골격만 있는 초기 상태. Plan은 가능하지만 실제 lint/test 명령을 추정하지 않으며 Coding을 차단할 수 있다 |
| `active` | 프로젝트의 실제 lint/typecheck/test 명령이 확인·연결된 상태. 구현 후 자동 검증과 수렴 판정이 가능하다 |

`template` 모드의 검증 결과는 템플릿 자체가 실행됨을 뜻할 뿐 `READY_FOR_REVIEW`를
의미하지 않는다. `active` 모드에서는 필수 lint/test와 선택한 typecheck가 실제로 실행되지
않으면 검증이 실패한다.

### 프레임워크 자체 회귀 테스트

이 프레임워크 원본 자체는 `bash scripts/test-framework.sh`로 Preflight·Plan 게이트·템플릿
회귀 테스트를 실행한다. 이 테스트 묶음은 적용 대상 프로젝트에 복사되지 않으며, 대상 프로젝트의
`scripts/test.sh`는 해당 프로젝트의 테스트 도구와 명령을 계속 사용한다.

## 기존 프로젝트에 적용하기 (온보딩)

에이전트는 프레임워크를 처음 적용하거나 구조 이상·사용자 재분석 요청이 있을 때만 다음을
실행한다. 일반 기능 요청마다 이 절차를 반복하지 않는다.

```bash
scripts/check-framework.sh                      # 골격 검사
scripts/bootstrap-framework.sh --analyze        # 읽기 전용 분석
```

기존 프로젝트라면 `docs/framework-manifest.md`를 기준으로
`scripts/plan-framework-apply.sh --project-dir <프로젝트경로>`로 대상 파일을
**생성·보존·병합 제안·제외**로 분류한다. 분석 결과와 변경 예정 파일을 사용자에게 제안하고,
**승인한 경우에만** 다음 명령으로 없는 골격만 생성한다. 기존 파일·소스·의존성은
덮어쓰지 않는다.

```bash
scripts/bootstrap-framework.sh --init
```

골격 생성 후에는 `project-bootstrap` 절차로 소스 분석 결과를 확인하고, 분석으로 알 수 없는
제품 목적·사용자 흐름·도메인·검증 수준만 질문한다. 자세한 내용은 `docs/framework-onboarding.md`와
`docs/project-bootstrap.md`를 따른다.

## 세션 시작 검사와 전역 자동화

세션 시작 시 에이전트가 `scripts/session-preflight.sh --start`를 한 번 실행한다. 이후 같은
세션의 사용자 요청에서는 `--status`로 캐시 유효성만 확인한다. 환경 판단 파일이 바뀌면 캐시가
무효화되어 다음 작업 전 재검사가 필요하다.

Codex·OpenCode·Claude Code에서 이 동작을 자동화하려면, 프레임워크 적용 후 한 번만
`scripts/install-global-session-hooks.sh`를 실행한다. 기존 전역 설정은 보존·백업되며, Codex는
`/hooks`에서 새 hook을 신뢰한 뒤 새 세션을 시작해야 한다. 자세한 범위는
`docs/global-session-hooks.md`를 따른다.

## 저장소 구조

```
├── AGENTS.md / CLAUDE.md      # 얇은 어댑터 (자동 로드)
├── CONTRIBUTING.md            # 사람용 기여 규칙
├── docs/
│   ├── product-specs/            # 사용자 요구사항·AC
│   ├── exec-plans/active/        # 승인된 구현·검증 계획
│   ├── exec-plans/completed/     # 완료된 계획·증거
│   ├── design-docs/              # 장기 설계 결정
│   ├── references/               # 외부 기술 참조
│   ├── generated/                # 재생성 가능한 문서
│   ├── agent-improvements/       # 개선 후보와 사람의 승인/기각 기록
│   ├── skill-contracts/          # Plan·Implement·Verify·Review·Improve 공통 실행 계약
│   ├── framework-distribution.md # 원본·배포 템플릿 경계
│   ├── development-workflow.md   # 표준 흐름 (SSOT)
│   ├── framework-onboarding.md   # 신규·기존 프로젝트 온보딩 절차
│   ├── framework-manifest.md     # 기존 프로젝트 적용 자산·승인 경계
│   ├── project-bootstrap.md      # 최초 적용 후 문맥 설정 절차
│   ├── project-preflight.md      # Plan 전 공통 준비 상태 검사
│   ├── session-preflight.md      # 세션 시작 검사·캐시·무효화 규칙
│   ├── project-constitution.md   # 프로젝트 품질·테스트·보안 원칙
│   ├── definition-of-done.md     # 완료 기준 + 기록 스키마
│   ├── testing-policy.md         # 테스트 정책
│   └── coding-standards.md       # 코드 규칙
├── scripts/
│   ├── lint.sh  test.sh  verify.sh  verify-plan.sh  review.sh
│   └── new-product-spec.sh  new-exec-plan.sh  complete-exec-plan.sh
│       new-improvement-candidate.sh  decide-improvement.sh
│       test-framework.sh             # 프레임워크 원본 전용 회귀 테스트
│       check-framework.sh  bootstrap-framework.sh  analyze-project.sh
│       plan-framework-apply.sh  prepare-project-context.sh  converge-plan.sh
│       project-preflight.sh  session-preflight.sh  validate-plan.sh
│       build-framework-template.sh  # 원본 전용 배포 템플릿 빌드
├── .opencode/skills/{onboard,implement,review,verify} + agents/reviewer
├── .claude/skills/{onboard,implement,review,verify} + settings + commands
└── .devcontainer/devcontainer.json
```

## 주요 명령어

```bash
# 세션 검사
scripts/session-preflight.sh --start
scripts/session-preflight.sh --status

# 공통 골격 검사
scripts/check-framework.sh

# 구현 전 / 구현 후 / 최종 수렴
scripts/validate-plan.sh docs/exec-plans/active/<plan>.md
scripts/verify-plan.sh docs/exec-plans/active/<plan>.md
scripts/converge-plan.sh docs/exec-plans/active/<plan>.md

# 프레임워크 회귀 검사
scripts/test-framework.sh

# GitHub Template용 배포물 생성
scripts/build-framework-template.sh --output /tmp/ai-dev-standard-template
```

## 도구 바인딩

| 도구 | 자동 로드 | 스킬 |
|---|---|---|
| Codex | `AGENTS.md` | 동일 docs 참조 + 동일 스크립트 실행 |
| OpenCode | `AGENTS.md` + `.opencode/skills` | 동일 docs 참조 + 동일 스크립트 실행 |
| Claude Code | `CLAUDE.md` + `.claude/skills` + `/verify`, `/task-record` | 동일 |

도구별 스킬은 규칙의 복사본이 아니다. 공통 계약(`docs/skill-contracts/`)을 읽고 공통
스크립트를 실행하는 진입점이다.

## 기여

기여 규칙은 [CONTRIBUTING.md](CONTRIBUTING.md)를 따른다.
