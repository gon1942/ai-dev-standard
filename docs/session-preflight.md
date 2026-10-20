# Session Preflight

Project Preflight는 사용자 요청마다 반복하는 검사가 아니라 **AI 에이전트 세션 시작 게이트**다.

## 세션 시작

에이전트는 세션을 시작하면 한 번 실행한다.

```bash
scripts/session-preflight.sh --start
```

이 명령은 안전한 누락 골격만 보완하고, Preflight 보고서와 아래 로컬 상태 파일을 작성한다.

```text
.ai-dev-standard/session-preflight.json
```

이 파일은 세션 캐시이므로 Git으로 추적하지 않는다. 판정, Plan/Coding 가능 여부, 검사 시각,
환경 지문을 담는다.

## 작업 요청 시

사용자 요청을 받으면 전체 검사를 다시 실행하지 않고 상태만 확인한다.

```bash
scripts/session-preflight.sh --status
```

- 유효한 `PASS`: Plan과 Coding 진행 가능
- 유효한 `WARNING`: Plan 가능. `can_code=false`면 active 검증 구성을 확정하기 전 Coding 차단
- `BLOCK`, 캐시 없음, 지문 불일치: Plan/Coding 중단 후 `--start`로 재검사

## 무효화 기준

다음 파일의 내용 또는 존재 여부가 바뀌면 지문이 달라져 세션 상태가 무효가 된다.

- `AGENTS.md`, `CLAUDE.md`, `.ai-dev-standard.env`
- `package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`
- `docs/framework-runtime-assets.tsv` 및 그 안에 선언된 대상 배포 실행 자산
- `docs/development-workflow.md`, `docs/project-preflight.md`

새 세션, 프레임워크 적용/복구, 사용자의 명시적 재검사 요청도 `--start`를 실행한다.

## 도구 호환성

Codex, OpenCode, Claude Code의 시작 hook 지원 방식은 다르다. 따라서 hook은 편의 기능이며
특정 도구에만 동작하는 hook을 필수 조건으로 강제하지 않는다. 전역 hook 설치 및 안전 경계는
`docs/global-session-hooks.md`를 따른다.
