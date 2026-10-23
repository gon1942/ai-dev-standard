# AI Dev Standard — 공통 개발 표준 프레임워크

> Codex · OpenCode · Claude Code — 서로 다른 AI 코딩 도구가 하나의 프로젝트에서
> **동일한 절차로 계획·구현·검증·기록**하게 만드는 공통 개발 표준

이 저장소는 프레임워크를 개발·검증하는 원본이다. 신규 프로젝트에는 원본을 그대로
복사하지 않고, 검증된 배포 템플릿을 사용한다. 기존 프로젝트에는 승인된 범위에서 골격만
안전하게 적용할 수 있다. 원본과 배포물의 경계는
[`docs/framework-distribution.md`](docs/framework-distribution.md)를 따른다.

## 빠른 시작 (CLI)

npm 게시 후에는 `npx`로 한 줄 적용할 수 있다.

```bash
# 신규 프로젝트 — 배포 템플릿 골격 생성 후 다음 단계 안내 출력
npx @gon1942/ai-dev-standard init my-project

# 기존 프로젝트 — 분석 → 생성/보존/병합제안/제외 제안 → 승인 후 골격만 생성
cd existing-project
npx @gon1942/ai-dev-standard apply

# 적용된 프로젝트의 누락 골격 보강 (기존 파일 유지)
npx @gon1942/ai-dev-standard update

# 골격 검사 + 프로젝트 준비 상태 검사
npx @gon1942/ai-dev-standard doctor
```

`apply`는 기존 파일을 절대 덮어쓰지 않는다. 분석 결과를 제안으로 보여주고
확인(또는 `--yes`)을 받은 뒤 없는 골격만 생성한다.

npm 게시 전 로컬에서는 저장소 루트에서 동일하게 동작한다:

```bash
node bin/ai-dev-standard.js init /path/to/my-project
```

### 필수 코드 영향 분석 도구

세션 시작 시 CRG(Code Review Graph)가 없으면 프레임워크 전용 bootstrap venv와 `pipx`로
`code-review-graph 2.3.9`를 준비한다. 사용자 Python 패키지는 변경하지 않으며, graph는
세션 시작에 만들지 않는다. 영향 범위 분석이 필요한 Plan·Verify·Review에서만 프로젝트별
`.code-review-graph/`을 build 또는 update한다.

npm 게시는 유지보수자가 수행한다 (npm에서 `@gon1942` 스코프 소유 필요):

```bash
npm run build:template   # 배포 템플릿 빌드 (prepublishOnly에서도 자동 실행)
npm publish --access public
```

CLI 없이 수동 적용하는 방법은 아래 "새 프로젝트에 적용하기"와
"기존 프로젝트에 적용하기" 절을 따른다.

## 왜 필요한가

AI 코딩 도구를 여러 개 쓰거나, 사람과 AI가 같은 프로젝트에서 작업할 때 발생하는 문제를
다음처럼 해결한다.

| 일반적인 AI 개발 문제 | AI Dev Standard의 대응 |
|---|---|
| 에이전트마다 작업 순서와 품질 기준이 다름 | `docs/`의 공통 계약과 동일한 Plan → Implement → Verification 흐름 |
| AI가 요청을 받은 즉시 코드를 수정함 | Product Spec과 Exec Plan을 먼저 만들고 사람 승인을 받음 |
| "테스트 통과"라는 말만 남고 무엇을 확인했는지 모름 | AC별 증거, 실제 명령, 종료 코드, 리뷰 결과를 Exec Plan에 기록 |
| AI가 기존 함수를 발견하지 못하고 중복 구현함 | verify 체인의 duplicate-check가 신규 중복 클론을 경고 |
| 세션이 바뀌면 이전 작업 상태를 모름 | work-status로 이전 작업 기록을 자동 복원 (전환 누락·승인 대기·진행 중 분류) |
| AI가 "테스트 먼저 썼다"고 말만 하고 실행은 안 함 | TDD 의무화 — RED 실행 증거(명령·종료 코드·실패 출력)를 기록 |
| 도구별 설정이 서로 어긋남 | 공통 규칙은 `docs/`에서 관리하고, 도구별 안내 파일은 해당 규칙 문서의 위치와 도구별 실행 방법을 안내 |
| 반복된 실수가 대화 기록에만 남음 | 개선 후보를 기록하고 사람이 승인/기각 |

## 핵심 설계 (5원칙)

1. **공통 규칙은 `docs/`에서 관리** — `AGENTS.md`, `CLAUDE.md`, 에이전트 스킬은 필요한 규칙 문서를 안내하고 도구별 실행 방법을 설명합니다. 같은 규칙을 여러 파일에 복사해 두지 않습니다.
2. **Node 엔진이 검증을 실행** — 22종 명령(`scripts/lib/cli.js`)이 실제 실행·종료 코드·
   증거 기록을 담당. bash 없는 환경(Windows)에서도 `node scripts/lib/cli.js <명령>`으로 동작
3. **AI 완료 선언 ≠ 기능 완료** — `READY_FOR_REVIEW`까지만 AI가 선언,
   `done`은 검증 증거 + 사람 승인
4. **제품 명세와 실행 계획이 1급 자산** — 기록 없는 완료 없음
5. **테스트 우선 개발 의무** — 구현 전에 기대 동작을 테스트로 확정(RED)하고,
   증거를 남긴 뒤 최소 구현(GREEN)한다 (`docs/testing-policy.md` §2.2)

## 하는 일 / 하지 않는 일

| 하는 일 | 하지 않는 일 |
|---|---|
| 프로젝트가 개발 준비 상태인지 세션 시작에 검사 | 사용자의 요구사항이나 제품 결정을 임의로 확정 |
| 요구사항을 Product Spec·AC·Exec Plan으로 기록 | 승인 없이 기존 코드·정책·의존성·CI/CD를 대규모 변경 |
| 구현 전 기대 동작을 테스트로 확정 (TDD 의무) | 테스트를 실행하지 않고 PASS라고 보고 |
| 구현 뒤 실제 검증·리뷰 증거를 수렴 | RED 증거 없이 "테스트 먼저 썼다"고 선언 |
| 신규 중복 클론을 자동 경고 (jscpd) | 기존 구현이 AC를 충족하는데 억지 RED를 강제 |
| 세션 시작 시 이전 작업 상태 복원 | 매 세션 전체 프로젝트 재분석 |
| 반복 문제를 개선 후보로 제안 | 사람 승인 없이 규칙·스킬·스크립트를 자동 수정 |

## 하나의 요청이 남기는 기록

모든 작업은 대화 기록이 아니라 **저장소의 공식 파일**로 남는다.

```text
사용자: "로그인 페이지를 만들어줘"

사용자 요청
  → docs/product-specs/<로그인>.md      요구사항, 범위, 제외 범위, AC
  → docs/exec-plans/active/<로그인>.md  구현 방법, AC별 검증 방법, RED/GREEN 증거, 리뷰 결과
  → 코드·테스트 변경
  → 사람 승인 후 docs/exec-plans/completed/<로그인>.md 로 보관
```

나중에 다른 사람이나 다른 AI가 봐도 "무엇을 요청했고, 어떤 기준으로 구현했고,
무엇으로 검증했는지"를 파일에서 확인할 수 있다.

## 표준 작업 흐름

```
세션 시작
  → Preflight (환경·골격·모드 검사)
  → work-status (이전 작업 상태 복원 — 전환 누락/승인 대기/진행 중 분류)
  → Git 상태 확인
  → 요청과 관련된 이전 작업만 상세 확인
      ↓
요청 → Product Spec(AC) + Exec Plan(검증 방법) 초안 → [통합 사전 승인 1회]
  → RED (기대 동작 실패 테스트 실행·증거 기록)
  → GREEN (최소 구현) → REFACTOR
  → Verification
      verify-plan (lint·typecheck·test 실제 실행)
      + duplicate-check (신규 중복 클론 경고)
      AC별 5단계 판별 (IDENTIFY→RUN→READ→VERIFY·3C→CLAIM)
      UAT 지정 AC → 실사용자 시나리오 루프
  → 독립 Review (최소 입력: 명세+diff+증거)
      Standards / Spec / Evidence 3관점
      + review --plan (목적·내용·검증 결과 3줄 요약)
  → converge-plan (AC 전원 PASS·증거·리뷰·재실행 확인)
  → record-verification-evidence (실행 증거 자동 기록)
      ↓
READY_FOR_REVIEW ← AI의 권한은 여기까지
  → [리뷰 후 완료 승인 1회] → complete-exec-plan → done · completed/ 보관
  → (선택) 회고 → 개선 후보 → 사람 승인 → 별도 작업
```

| 단계 | 목적 | 완료 기준 |
|---|---|---|
| 세션 준비 | 환경·이전 작업 상태 복원 | `session-preflight --start` + `work-status` |
| Plan | 요청을 승인 가능한 명세·계획으로 확정 | 통합 승인된 Spec + Plan + `validate-plan` PASS |
| RED | 기대 동작을 테스트로 확정·실행 | 실패 테스트 실행 + 증거 기록 (§2.2) |
| Implement | 최소 구현으로 GREEN 달성 | 테스트 통과 + 통과 상태 유지 |
| Verification | 실행 증거와 독립 리뷰로 AC 확인 | Verify + Review + Convergence PASS |
| 완료·학습 | 사람 승인으로 완료, 개선 후보 기록 | 사람 승인 → `done` |

## TDD (테스트 우선 개발) — 의무

기능 변경·버그 수정은 테스트 우선 개발을 의무로 한다 (`docs/testing-policy.md` §2.2).

| 절차 | 내용 | 증거 |
|---|---|---|
| **RED** | 구현 전 테스트 작성·**실행** → 기대한 이유로 실패 확인 | 실행 명령, 종료 코드, 실패 출력 요약, 해당 AC |
| **GREEN** | 최소 구현으로 동일 테스트 통과 | 동일 테스트의 PASS 결과 |
| **REFACTOR** | 필요시 구조 개선, 통과 상태 유지 | 리팩터 후 재실행 결과 |

**RED의 유효 조건**: 기대 동작이 충족되지 않아 실패한 것이어야 한다.
종료 코드만으로 RED로 인정하지 않으며, 환경·설정·문법 오류는 RED 증거로 불인정.

**예외**: 기존 구현이 AC를 이미 충족하면 억지 RED를 만들지 않는다 —
기존 테스트·실행 증거로 확인한다. 자동화 불가 AC는 사유와 UAT 절차를 기록한다.

## 배포 템플릿 만들기

GitHub Template 또는 `ai-dev-standard init` / `apply` CLI가 소비할 배포물은 아래 명령으로
만든다. 출력 경로는 존재하지 않아야 하며, 기존 경로를 덮어쓰거나 삭제하지 않는다.

```bash
scripts/build-framework-template.sh --output /tmp/ai-dev-standard-template
```

빌드 결과에는 원본 Product Spec·Exec Plan 이력, 세션 캐시, Preflight 보고서, OpenCode 로컬
의존성, 원본 전용 회귀 테스트가 포함되지 않는다.

## 새 프로젝트에 적용하기

> CLI로 한 줄 적용: `npx @gon1942/ai-dev-standard init my-project`
> (게시 전 로컬: 저장소 루트에서 `node bin/ai-dev-standard.js init <경로>`)

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

새 작업은 `scripts/new-product-spec.sh <작업명> <사용자 요청 원문>`으로 명세 초안을 만들고,
`scripts/new-exec-plan.sh <명세파일>`로 계획 초안을 생성한다. 두 문서를 함께 검토해 한 번
승인하며, 승인 기록은 두 문서 모두에 남긴다. 리뷰 후 완료 승인은 별도로 진행한다.

### 검증 모드: template / active

| 모드 | 의미 |
|---|---|
| `template` | 공통 골격만 있는 초기 상태. Plan은 가능하지만 실제 lint/test 명령을 추정하지 않으며 Coding을 차단할 수 있다 |
| `active` | 프로젝트의 실제 lint/typecheck/test 명령이 확인·연결된 상태. 구현 후 자동 검증과 수렴 판정이 가능하다 |

### 선택 검사 설정

| 환경 변수 | 기본 | 역할 |
|---|---|---|
| `AI_DEV_STANDARD_DUPLICATE_CHECK` | `true` | verify 실행 시 신규 중복 클론 경고 (jscpd) |
| `AI_DEV_STANDARD_JSCPD_FORMATS` | `javascript,typescript,python,bash` | 중복 검사 대상 언어 (프로젝트에 맞게 변경) |
| `AI_DEV_STANDARD_JSCPD_IGNORE` | `node_modules,dist,...` | 중복 검사 제외 경로 |

### 프레임워크 자체 회귀 테스트

이 프레임워크 원본 자체는 `bash scripts/test-framework.sh`로 Preflight·Plan 게이트·템플릿
회귀 테스트를 실행한다. 이 테스트 묶음은 적용 대상 프로젝트에 복사되지 않으며, 대상 프로젝트의
`scripts/test.sh`는 해당 프로젝트의 테스트 도구와 명령을 계속 사용한다.

## 기존 프로젝트에 적용하기 (온보딩)

> CLI로 적용 분석·승인·골격 생성을 한 번에: 대상 프로젝트 루트에서
> `npx @gon1942/ai-dev-standard apply` (게시 전 로컬: 저장소 루트에서
> `node bin/ai-dev-standard.js apply --project-dir <경로>`)

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

## 세션 시작 — 환경 검사와 작업 복원

세션 시작 시 에이전트가 두 가지를 확인한다:

**① 환경 준비 (session-preflight)**

```bash
scripts/session-preflight.sh --start    # 최초 1회 — 환경·골격·모드 검사
scripts/session-preflight.sh --status   # 이후 — 캐시 유효성만 확인
```

**② 이전 작업 상태 복원 (work-status)**

```bash
node scripts/lib/cli.js work-status
```

활성 계획을 3분류로 자동 요약한다:

| 분류 | 의미 | 다음 조치 |
|---|---|---|
| 전환 누락 | 수렴 증거는 완결이나 상태가 active | READY_FOR_REVIEW 기록 후 승인 대기 |
| 승인 대기 | READY_FOR_REVIEW | 사람 승인 → done |
| 진행 중 | 구현 또는 검증 진행 중 | 해당 계획을 이어서 작업 |

Git 변경 상태와 최근 완료(승인자 표시)도 함께 출력된다.

**증거 신선성**: 검증 PASS 이후 관련 소스가 변경됐다면 그 PASS는 최신 완료 증거가 아니다 — 재검증한다.

Codex·OpenCode·Claude Code에서 이 동작을 자동화하려면, 프레임워크 적용 후 한 번만
`scripts/install-global-session-hooks.sh`를 실행한다. 기존 전역 설정은 보존·백업되며, Codex는
`/hooks`에서 새 hook을 신뢰한 뒤 새 세션을 시작해야 한다. 자세한 범위는
`docs/global-session-hooks.md`를 따른다.

## 저장소 구조

```
├── AGENTS.md / CLAUDE.md      # 에이전트가 공통 규칙 문서와 시작 절차를 찾도록 안내 (자동 로드)
├── CONTRIBUTING.md            # 사람용 기여 규칙
├── docs/
│   ├── product-specs/            # 사용자 요구사항·AC
│   ├── exec-plans/active/        # 승인된 구현·검증 계획
│   ├── exec-plans/completed/     # 완료된 계획·증거
│   ├── design-docs/              # 장기 설계 결정
│   ├── references/               # 외부 기술 참조
│   ├── generated/                # 재생성 가능한 문서 (jscpd 기준선 포함)
│   ├── agent-improvements/       # 개선 후보와 사람의 승인/기각 기록
│   ├── skill-contracts/          # 7종 공통 실행 계약:
│   │     standard-plan·implement·verify·uat(선택)·
│   │     review·improve·human-decision
│   ├── framework-distribution.md # 원본·배포 템플릿 경계
│   ├── development-workflow.md   # 표준 흐름 (SSOT)
│   ├── testing-policy.md         # 테스트 정책 — §2.2 TDD 의무
│   ├── definition-of-done.md     # 완료 기준 + 기록 스키마
│   ├── project-constitution.md   # 프로젝트 품질·테스트·보안 원칙
│   └── coding-standards.md       # 코드 규칙
├── scripts/
│   ├── lib/                      # Node 엔진 (22종 명령)
│   │   ├── cli.js                   # 단일 진입점 (크로스플랫폼)
│   │   ├── util.js                  # 공통 유틸
│   │   ├── e2e.js·evidence.js       # E2E 판정·증거 기록
│   │   └── commands/                # 각 명령 구현 (22종)
│   ├── reference/                # 동치성 기준선 원본 (bash)
│   ├── *.sh                      # 유닉스 편의 shim
│   ├── lint.sh  test.sh  verify.sh  verify-plan.sh  review.sh
│   │   duplicate-check.sh  work-status (node)
│   ├── new-product-spec.sh  new-exec-plan.sh  complete-exec-plan.sh
│   │   record-verification-evidence.sh  record-e2e-evidence.sh
│   │   new-improvement-candidate.sh  decide-improvement.sh
│   ├── check-framework.sh  bootstrap-framework.sh  analyze-project.sh
│   │   plan-framework-apply.sh  prepare-project-context.sh  converge-plan.sh
│   │   project-preflight.sh  session-preflight.sh  validate-plan.sh
│   ├── build-framework-template.sh  # 원본 전용 배포 템플릿 빌드
│   └── test-framework.sh  test-parity.sh 등  # 원본 전용 회귀·동치성 시험
├── bin/
│   └── ai-dev-standard.js        # npm CLI 진입점 (init·apply·update·doctor)
├── global-hooks/                 # 선택형 전역 SessionStart 자동화
├── .opencode/skills/  .claude/skills/  # 도구별 어댑터
└── .devcontainer/devcontainer.json
```

## 주요 명령어

모든 엔진 명령은 **Node 런타임**으로 동작한다 (22종). bash가 없는 환경(Windows 등)에서는
`node scripts/lib/cli.js <명령>`으로 직접 실행한다. `scripts/*.sh`는 유닉스 편의용
얇은 shim이며 `scripts/reference/`는 동치성 기준선 원본이다.

```bash
# ── 세션 시작 ──
scripts/session-preflight.sh --start          # 환경·골격·모드 검사
scripts/session-preflight.sh --status         # 캐시 유효성 확인
node scripts/lib/cli.js work-status           # 이전 작업 상태 복원

# ── 작업 흐름 ──
scripts/new-product-spec.sh <작업명> <요청>    # 제품 명세 생성
scripts/new-exec-plan.sh <명세>               # 실행 계획 생성
scripts/validate-plan.sh <계획>               # Implement 진입 게이트
scripts/verify-plan.sh <계획>                 # lint·typecheck·test + 중복 검사 실행
scripts/review.sh [--plan <계획>] [base]      # 독립 리뷰 체크리스트 + 작업 요약
scripts/converge-plan.sh <계획>               # AC·증거·리뷰 수렴 판정
scripts/complete-exec-plan.sh <계획> <승인자>  # done 전환·completed/ 보관

# ── 검증 증거 ──
node scripts/lib/cli.js record-verification-evidence <계획>  # 실행 증거 자동 기록
node scripts/lib/cli.js record-e2e-evidence <계획>           # E2E 판정 기록

# ── 중복 검사 ──
node scripts/lib/cli.js duplicate-check        # 신규 중복 클론 경고 (jscpd)
node scripts/lib/cli.js duplicate-check --update-baseline  # 기준선 갱신

# ── 프레임워크 관리 ──
scripts/check-framework.sh                    # 골격 검사
scripts/test-framework.sh                     # 원본 전용 회귀 테스트
scripts/test-parity.sh                        # bash↔Node 동치성 시험 (48케이스)
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

## 라이선스

이 프로젝트는 [MIT License](LICENSE)로 배포된다. 적용 대상 프로젝트의 라이선스는
각 프로젝트가 독립적으로 선택한다.
