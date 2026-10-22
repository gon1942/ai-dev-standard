# Standard Implement Contract

## Entry conditions

- 승인된 Product Spec과 Exec Plan이 있다.
- `scripts/validate-plan.sh <계획>`이 통과한다.
- Session Preflight가 `can_code=true`다.

## Required actions

- 승인된 AC·범위 안에서만 최소 변경으로 구현한다.
- 구현 파일을 수정하기 전에 프로젝트의 Ponytail 스킬을 반드시 읽고 적용한다:
  - Codex: `.agents/skills/ponytail/SKILL.md`
  - Claude Code: `.claude/skills/ponytail/SKILL.md`
  - OpenCode: `.opencode/skills/ponytail/SKILL.md`
  해당 도구 경로에 스킬이 없으면 임의로 생략하지 말고 구현을 중단해 프레임워크 골격을 보완한다.
  Ponytail은 이 구현 단계에서만 활성화하며 Plan·Verify·Review 단계에 상시 적용하지 않는다.
  승인 범위, TDD, 보안·접근성·검증 의무는 Ponytail보다 우선하며 완화할 수 없다.
  기존 코드나 계획된 구현 방식과 다른 재사용 방안을 발견하면 파일을 수정하기 전에 Plan으로 돌아가 계획을 갱신한다.
- 기능 변경과 버그 수정은 테스트 우선 개발을 의무로 수행한다 —
  RED 확인·증거 기록·기존 구현 재사용 예외의 기준은 `docs/testing-policy.md` §2.2를 따른다.
  버그 유형은 같은 문서의 진단 루프(재현→최소화→가설→계측→최소 수정)를 따른다.
- E2E 프로필 구성은 승인된 Exec Plan의 `## E2E 프로필 제안`에 선택된 프로필과 정확히 일치할 때만
  실행한다. 승인 전 설치·브라우저 다운로드·설정 생성은 금지하며, 기존 유효 설정은 덮어쓰지 않는다.
- 계획 밖 변경이 필요하면 중단하고 Plan으로 돌아간다.
- 수정 파일과 구현 판단을 Exec Plan 완료 기록 초안에 남긴다.

## Outputs

- 소스·테스트 변경
- 구현 근거가 있는 Exec Plan

## Exit conditions / next stage

- 계획한 구현이 끝나면 `standard-verify`로 진행한다. 구현 자체가 PASS 판정은 아니다.
