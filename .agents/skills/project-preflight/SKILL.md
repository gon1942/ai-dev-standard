---
name: project-preflight
description: 기능·수정·버그 작업 전에 공통 프로젝트 준비 상태를 검사하고 Plan/Coding 진행 가능 여부를 판정한다
---

# Project Preflight

`docs/project-preflight.md`와 `docs/session-preflight.md`를 따른다. 세션 시작에 다음 공통 진입점을 실행한다.

```bash
scripts/session-preflight.sh --start
node scripts/lib/cli.js work-status
```

`work-status`는 사용자의 수동 요청 없이 매 새 세션에 실행하고, 아래 항목을 정확한 건수 또는
`없음`으로 사용자에게 보고한다. `승인 대기`는 `READY_FOR_REVIEW` 상태의 계획만 뜻하며,
다른 진행 중 계획을 승인 대기로 바꾸어 말하지 않는다.

- 활성 작업
- 전환 누락
- 승인 대기
- 진행 중
- 최근 완료
- Git 변경

작업 요청에서는 `scripts/session-preflight.sh --status`로 캐시를 확인한다.

- PASS: Plan과 Coding 진행 가능
- WARNING: `can_plan`, `can_initialize`, `can_code`를 분리해 따른다. 신규 프로젝트는 승인된 검증
  프로필을 initializing 상태에서 실행해 필수 검사가 통과한 후 active로 전환한다.
- BLOCK: 원인 해결과 재검사 전 Plan/Coding 중단

`verification_mode`가 `initializing`이면 `.ai-dev-standard/bootstrap-status.json`을 읽어 마지막
Bootstrap 단계, 진행/실패 작업, 완료된 setup 작업을 사용자에게 보고하고 해당 지점부터 안전하게
재개한다. 실패한 setup은 부분 변경 가능성을 먼저 확인한 뒤 재시도한다. 사용자가 설치를 거부한 경우
Bootstrap 실행 명령을 호출하지 않는다.

기존 파일·소스·의존성·CI/CD를 자동 수정하지 않는다. 도구별 로직을 만들지 말고 공통 결과를 사용한다.
