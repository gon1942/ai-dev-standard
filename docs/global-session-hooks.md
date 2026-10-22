# Global Session Hooks

전역 SessionStart 연결은 **선택 기능**이다. 설치하면 Codex, OpenCode, Claude Code가 시작될 때
현재 Git 프로젝트가 ai-dev-standard를 이미 적용했는지 확인한다.

```bash
scripts/install-global-session-hooks.sh
```

설치 프로그램은 다음만 수행한다.

- `~/.ai-dev-standard/hooks/session-start.sh`에 공통 hook 복사
- Codex와 Claude 설정의 `SessionStart` 배열에 hook 하나를 병합
- OpenCode 전역 plugin 디렉터리에 session-created plugin 복사

기존 설정은 삭제하지 않는다. 기존 설정 파일을 처음 수정할 때는 같은 위치에
`.ai-dev-standard.bak` 백업을 한 번 남긴다. 다시 실행해도 동일 hook을 중복 추가하지 않는다.

설치기는 hook 명령에 `AI_DEV_STANDARD_ROOT`를 명시해 설치 시점의 지속 가능한 프레임워크
경로를 전달한다. 반대로 프로젝트에 포함된 `global-hooks/session-start.sh` 자체에는 개발자
로컬 절대 경로를 넣지 않는다. 환경 변수가 없으면 hook은 현재 프로젝트의
`scripts/session-preflight.sh`만 사용한다.

## 동작 범위

- 프레임워크가 적용된 프로젝트: `scripts/session-preflight.sh --start`를 한 번 실행해 로컬
  세션 상태를 갱신한 뒤, 대상 프로젝트의 `node scripts/lib/cli.js work-status`를 한 번 실행해
  작업 상태를 복원한다.
- 아직 적용되지 않은 프로젝트: 파일을 만들거나 고치지 않는다. 에이전트에게 적용 분석을
  제안하라는 정보만 전달한다.

Codex의 사용자 전역 hook은 설치 뒤 `/hooks`에서 검토·신뢰한 후 새 세션을 시작해야 한다.
OpenCode plugin은 OpenCode의 전역 plugin 로딩을 사용하므로, 설치 후 OpenCode를 재시작한다.
도구가 hook을 지원하지 않거나 hook 실행이 실패해도, 공통 규칙과
`scripts/session-preflight.sh --start`를 통한 수동 실행은 그대로 사용할 수 있다.

## 작업 요청 시

SessionStart가 정상 실행된 뒤에는 매 요청마다 전체 검사를 반복하지 않는다. 에이전트는
`scripts/session-preflight.sh --status`로 캐시와 지문만 확인하고, stale/BLOCK일 때만
`--start`를 다시 실행한다. 자세한 판정 기준은 `docs/session-preflight.md`가 진실 공급원이다.
