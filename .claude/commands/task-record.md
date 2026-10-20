---
description: 제품 명세와 실행 계획 생성/갱신
allowed-tools: Read(docs/**), Write(docs/product-specs/**), Write(docs/exec-plans/**), Edit(docs/product-specs/**), Edit(docs/exec-plans/**)
---

`docs/definition-of-done.md`의 제품 명세·실행 계획 스키마에 따라
`docs/product-specs/`, `docs/exec-plans/`의 파일을 생성하거나 갱신해라.

인자가 사용자 요청이면 제품 명세를 생성(상태 `draft`, 요청 원문·AC 골격)한다.
사람 승인 후 실행 계획을 생성(상태 `active`, 구현·검증·회귀 계획)한다.
기존 실행 계획 경로면 완료 기록 섹션을 갱신한다.

신규 명세는 `scripts/new-product-spec.sh <작업명> <사용자 요청 원문>`으로 생성한다.
실행 계획은 승인된 명세에 대해서만 `scripts/new-exec-plan.sh <명세파일>`로 생성한다.
