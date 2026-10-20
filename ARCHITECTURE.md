# Architecture Map

이 파일은 에이전트가 저장소 구조를 탐색하는 짧은 지도다. 실제 제품의 모듈·의존성 규칙은
프로젝트 적용 시 이 문서에 추가하고, 상세 설계 결정은 `docs/design-docs/`에 둔다.

## 작업 지식 흐름

```text
docs/product-specs/ → docs/exec-plans/active/ → 구현·검증 → docs/exec-plans/completed/
```

- Product Spec: 사용자가 원하는 것과 승인된 완료 조건
- Exec Plan: 승인된 명세를 구현·검증하는 방법
- Completed Plan: 구현·검증·리뷰 증거를 보존한 실행 계획

