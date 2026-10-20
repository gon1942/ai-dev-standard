---
name: project-preflight
description: 기능·수정·버그 작업 전에 공통 프로젝트 준비 상태를 검사하고 Plan/Coding 진행 가능 여부를 판정한다
---

# Project Preflight

`docs/project-preflight.md`와 `docs/session-preflight.md`를 따른다. 세션 시작에 다음 공통 진입점을 실행한다.

```bash
scripts/session-preflight.sh --start
```

작업 요청에서는 전체 검사를 반복하지 않고 `scripts/session-preflight.sh --status`로 캐시를 확인한다.

1. `PASS`: 제품 명세와 실행 계획을 만든 뒤 Coding으로 진행할 수 있다.
2. `WARNING`: 보고서의 항목을 사용자에게 알리고 Plan은 진행한다. `can_code=false`이면 실제 명령을 확정해 active로 전환하기 전 Coding을 시작하지 않는다.
3. `BLOCK`: 원인·영향·해결 방법을 보고하고 Plan/Coding으로 진행하지 않는다.

`--repair`는 누락 골격만 생성한다. 기존 파일 내용·소스·의존성·CI/CD는 수정하지 않는다.
도구별 검사를 별도로 재구현하지 말고 JSON/Markdown 결과를 그대로 사용한다.
