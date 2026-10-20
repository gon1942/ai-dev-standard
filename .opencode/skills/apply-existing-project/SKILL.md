---
name: apply-existing-project
description: 기존 프로젝트를 분석해 AI Dev Standard를 안전하게 적용하도록 계획·승인·반영하는 절차
---

# 기존 프로젝트 적용

기존 프로젝트에 공통 프레임워크를 적용해 달라는 요청에서 사용한다. 규칙의 SSOT는
`docs/framework-manifest.md`와 `docs/framework-onboarding.md`다.

1. 대상 경로와 대상 내부의 `AGENTS.md`·`CLAUDE.md`를 확인한다. 더 가까운 지침이 우선이다.
2. 프레임워크의 `docs/framework-manifest.md`를 읽고,
   `scripts/analyze-project.sh --project-dir <대상>` 및
   `scripts/plan-framework-apply.sh --project-dir <대상>`을 실행한다.
3. 결과를 생성·보존·병합 제안·제외로 요약하고, 충돌과 결정이 필요한 항목을 사용자에게 제시한다.
4. 승인 전에는 대상의 기존 파일, 소스, 의존성, CI/CD, 실제 검증 명령을 수정하지 않는다.
5. 승인된 범위에서만 누락 골격을 생성하고, 기존 파일은 제안한 diff만 병합한다.
6. 적용 뒤 골격을 검사한다. 검증 명령 연결과 `active` 전환은 별도 제품 명세·실행 계획으로 진행한다.

사용자에게 수동 복사나 스크립트 실행을 요구하지 않는다. 이 스킬은 일반 기능 작업이나 이미 적용된
프로젝트의 매 요청마다 실행하지 않는다.
