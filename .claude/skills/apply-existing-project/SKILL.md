---
name: apply-existing-project
description: 기존 프로젝트를 분석해 AI Dev Standard를 안전하게 적용하도록 계획·승인·반영하는 절차
---

# 기존 프로젝트 적용

`docs/framework-manifest.md`와 `docs/framework-onboarding.md`를 따른다.

1. 대상 경로와 대상 내부의 `AGENTS.md`·`CLAUDE.md`를 먼저 읽는다.
2. `scripts/analyze-project.sh --project-dir <대상>` 및
   `scripts/plan-framework-apply.sh --project-dir <대상>`으로 읽기 전용 분석을 한다.
3. 생성·보존·병합 제안·제외와 충돌을 사용자에게 제시한다.
4. 승인 전에는 기존 파일·소스·의존성·CI/CD·실제 검증 명령을 수정하지 않는다.
5. 승인된 범위만 반영하고 `scripts/check-framework.sh --project-dir <대상>`으로 결과를 확인한다.

사용자에게 수동 복사나 스크립트 실행을 요구하지 않는다. 일반 기능 작업에는 사용하지 않는다.
