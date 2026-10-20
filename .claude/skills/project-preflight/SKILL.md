---
name: project-preflight
description: 기능·수정·버그 작업 전에 공통 프로젝트 준비 상태를 검사하고 Plan/Coding 진행 가능 여부를 판정한다
---

# Project Preflight

`docs/project-preflight.md`와 `docs/session-preflight.md`를 따른다. 세션 시작에 다음 공통 진입점을 실행한다.

```bash
scripts/session-preflight.sh --start
```

작업 요청에서는 `scripts/session-preflight.sh --status`로 캐시를 확인한다.

- PASS: Plan과 Coding 진행 가능
- WARNING: Plan 가능, `can_code=false`이면 active 검증 구성 전 Coding 차단
- BLOCK: 원인 해결과 재검사 전 Plan/Coding 중단

기존 파일·소스·의존성·CI/CD를 자동 수정하지 않는다. 도구별 로직을 만들지 말고 공통 결과를 사용한다.
