---
name: project-bootstrap
description: 신규 또는 기존 프로젝트에 프레임워크를 처음 적용한 뒤, 분석·질문·승인으로 실제 프로젝트 문맥을 작성하는 절차
---

# 프로젝트 부트스트랩

`docs/project-bootstrap.md`를 따른다.

1. 대상 지침을 먼저 읽고 `analyze-project.sh`와 `prepare-project-context.sh --write`를 실행한다.
2. 분석으로 알 수 없는 정보만 질문한다.
3. 답변으로 아키텍처·프로젝트 문맥·프로젝트 원칙의 초안 또는 diff를 만든다.
4. 기존 파일 변경과 실제 검증 명령 연결은 승인 전 반영하지 않는다.
5. 적용 뒤 `check-framework.sh`로 확인한다.

일반 기능 요청에는 반복 실행하지 않는다.
