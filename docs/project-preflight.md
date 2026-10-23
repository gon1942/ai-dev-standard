# Project Preflight

Project Preflight는 AI 에이전트 **세션 시작**에 수행하는 공통 준비 상태 판정이다. 검사 엔진은
`scripts/project-preflight.sh` 하나이며 Codex, OpenCode, Claude Code는 같은 결과를 사용한다.
세션 캐시와 작업 요청 시 상태 확인은 `docs/session-preflight.md`를 따른다.

## 실행

세션 시작에서 `scripts/session-preflight.sh --start`가 내부적으로 다음을 실행한다.

```bash
scripts/project-preflight.sh --repair --write-report
```

- `--repair`: 없는 공통 골격만 `bootstrap-framework --init`으로 생성한다. 기존 파일은 덮어쓰지 않는다.
- `--write-report`: `docs/generated/project-preflight.md`와 `.json`에 사람이 읽는 보고서와 구조화 결과를 기록한다.
- `--run-checks`: active 모드에서 `verify.sh`를 실제 실행한다. 세션 시작에서는 기본 검사만 하며, 전체 실행은 구현 후 Verification 단계에서 수행한다.
- `--format json`: 자동화·도구 어댑터가 읽는 JSON 결과를 stdout으로 출력한다.

다른 프로젝트를 적용할 때는 프레임워크 원본에서 다음처럼 실행한다.

```bash
scripts/project-preflight.sh --project-dir <대상경로> --repair --write-report
```

## 검사 범위

- 기술 스택·패키지 관리자·프레임워크 신호
- 공통 프레임워크의 필수 문서·기록 디렉터리와 `docs/framework-runtime-assets.tsv`에 선언된 실행 자산
- `.ai-dev-standard.env`의 모드 값, `package.json` JSON, `pyproject.toml` 파싱 가능성
- 선언된 shell 실행 자산의 셸 문법
- 감지된 에이전트 지침·설정 경로

프로젝트에 적용되지 않는 언어, 패키지 관리자, 에이전트 도구는 필수 조건으로 만들지 않는다.
기술 스택을 판별할 근거가 없으면 추정 파일을 생성하지 않고 WARNING으로 기록한다.
실행 자산 목록에 `scripts/`·`global-hooks/` 밖의 경로나 상위 경로가 있으면 외부 파일을 검사하지 않고
BLOCK으로 판정한다.

## 판정과 게이트

| 판정 | 의미 | 후속 단계 |
|---|---|---|
| PASS | 골격·설정·유효성 검사가 정상 | Plan 진행 가능. Coding은 `can_code` 값으로 결정 |
| WARNING | 선택 설정 누락, 기술 스택 미확정, template/initializing 모드 등 준비 항목 존재 | `can_plan`, `can_initialize`, `can_code`를 각각 따른다 |
| BLOCK | 필수 골격 복구 실패, 설정/구문 오류, active 검증 실패 | Plan·Coding 중단, 원인 해결 후 재검사 |

`template`은 새 프로젝트의 안전한 초기 상태다. 여기서는 Plan과 승인된 초기 검증 환경 구성을 진행할 수
있지만 기능 구현은 차단한다. 신규 프로젝트는 `template → initializing → active` 순으로 전환한다.
`initializing`은 승인된 검증 프로필의 필수 검사 실행만 허용하고 기능 Coding은 차단한다. 모두 통과하면
검증 준비 지문을 기록하고 `active`로 전환한다. ESLint 설치를 보편 요구하지 않으며, 언어·프로젝트에
맞는 명령은 승인된 검증 프로필에 선언한다. 기존 프로필 없는 프로젝트는 기존 Preflight 규칙을 유지한다.

Bootstrap Plan은 사용자 승인 후 `record-bootstrap-approval`로 Product Spec/Exec Plan 내용 지문을
기록해야 한다. 초기화 실행 때 지문이 다르면 계획 변경으로 간주해 차단하고 재승인을 요구한다.
프로필의 `setup`은 승인된 설치·설정 명령만 `shell:false`로 실행하며 Verify에서는 다시 실행하지 않는다.

Preflight JSON은 별도 권한인 `can_plan`, `can_initialize`, `can_code`, `verification_ready`를 제공한다.
`active`라도 검증 준비 지문이 오래된 경우 기능 코드는 진행할 수 있지만, 다음 검증/완료 Gate는 현재
프로필과 실행 환경을 다시 검증해야 한다.

프레임워크 원본은 `scripts/test-framework.sh`를 실제 회귀 테스트 구성으로 사용할 수 있다. 이 파일은
원본 전용 자산이므로 bootstrap 대상에 복사하지 않으며, 일반 프로젝트는 기존 테스트 도구 신호를 기준으로
active 구성을 판정한다.

## 보호 원칙

- 자동 복구는 **없는 파일과 디렉터리만** 만든다.
- 기존 `AGENTS.md`, `CLAUDE.md`, 소스, 의존성, CI/CD, 배포 설정은 Preflight가 수정하지 않는다.
- 기존 파일의 유효성 오류는 원인·영향을 보고하며, 내용 수정은 별도 diff와 사용자 승인으로 진행한다.
- 보고서 생성은 내용이 달라질 때만 파일을 바꾸므로 반복 실행에 안전하다.
