> Codex용 — 규칙의 진실 공급원은 `docs/framework-onboarding.md`다.

---
name: onboard
description: 공통 프레임워크를 최초 적용하거나 구조 이상을 복구하는 온보딩 절차
---

# 온보딩 (onboard)

신규·기존 프로젝트에 공통 프레임워크를 처음 적용하거나, 필수 구조 이상 또는 사용자의 재분석
요청이 있을 때만 사용한다.

1. `scripts/check-framework.sh`를 실행하고 결과를 읽는다.
2. 누락 항목이 있으면 `scripts/bootstrap-framework.sh --analyze`로 읽기 전용 분석을 수행한다.
3. `scripts/analyze-project.sh --write`로 재생성 가능한 프로젝트 현황을 기록한다.
4. 신규 프로젝트면 목적·흐름·스택·데이터·검증 방식을 질문하고, 기존 프로젝트면 소스와 문서를 비교한다.
5. 프로젝트 문서가 없으면 생성하고, 기존 구조 문서의 사실 갱신은 diff로 제안한다.
6. 사용자 승인 후에만 `scripts/bootstrap-framework.sh --init` 또는 문서 갱신을 실행한다.
7. 공통 정책·보안·검증 규칙 변경은 별도 개선 후보와 사람 승인 뒤 제품 명세·실행 계획으로 진행한다.

일반 기능 요청마다 이 스킬을 반복 실행하지 않는다.
