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
| PASS | 골격·설정·유효성 검사가 정상이고 active 검증 구성이 확인됨 | Plan과 Coding 진행 가능 |
| WARNING | 선택 설정 누락, 기술 스택 미확정, template 모드 등 개발 전 확인 항목 존재 | Plan 진행 가능. Coding은 `can_code` 값으로 결정하며, active 검증 구성이 유효하면 WARNING이어도 진행 가능 |
| BLOCK | 필수 골격 복구 실패, 설정/구문 오류, active 검증 실패 | Plan·Coding 중단, 원인 해결 후 재검사 |

`template` 모드는 새 프로젝트의 안전한 초기 상태다. 이 상태에서는 문맥 설정과 Plan을 진행할 수 있지만,
실제 검증 명령을 승인·확인해 `active`로 전환하기 전에는 Coding 완료나 `READY_FOR_REVIEW`를 선언할 수 없다.

프레임워크 원본은 `scripts/test-framework.sh`를 실제 회귀 테스트 구성으로 사용할 수 있다. 이 파일은
원본 전용 자산이므로 bootstrap 대상에 복사하지 않으며, 일반 프로젝트는 기존 테스트 도구 신호를 기준으로
active 구성을 판정한다.

## 보호 원칙

- 자동 복구는 **없는 파일과 디렉터리만** 만든다.
- 기존 `AGENTS.md`, `CLAUDE.md`, 소스, 의존성, CI/CD, 배포 설정은 Preflight가 수정하지 않는다.
- 기존 파일의 유효성 오류는 원인·영향을 보고하며, 내용 수정은 별도 diff와 사용자 승인으로 진행한다.
- 보고서 생성은 내용이 달라질 때만 파일을 바꾸므로 반복 실행에 안전하다.
