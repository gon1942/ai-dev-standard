---
name: project-bootstrap
description: 신규 또는 기존 프로젝트에 프레임워크를 처음 적용한 뒤, 분석·질문·승인으로 실제 프로젝트 문맥을 작성하는 절차
---

# 프로젝트 부트스트랩

`docs/project-bootstrap.md`를 따른다. 이 스킬은 최초 적용, 구조 복구, 사용자 명시적 재분석에만 사용하며
일반 기능 요청마다 실행하지 않는다.

1. 대상의 더 가까운 `AGENTS.md`·`CLAUDE.md`를 먼저 읽는다.
2. `scripts/analyze-project.sh --project-dir <대상>` 및
   `scripts/prepare-project-context.sh --project-dir <대상> --write`를 실행한다.
3. 소스에서 알 수 없는 질문만 사용자에게 제시한다. 이미 확인한 스택·명령·구조를 다시 묻지 않는다.
4. 답변을 근거로 `ARCHITECTURE.md`, `docs/design-docs/project-context.md`,
   `docs/project-constitution.md`의 초안 또는 최소 diff를 만든다.
5. 기존 파일 변경과 실제 검증 명령 연결은 diff를 제시하고 승인받은 뒤에만 반영한다.
6. `scripts/check-framework.sh --project-dir <대상>`으로 구조를 확인한다.

추측을 확정 사실로 기록하지 않는다. 미확정 항목은 문서에 그대로 남긴다.
