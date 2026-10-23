---
name: review
description: Standards Review와 Spec Review를 수행하는 표준 리뷰 어댑터
---

# Review Adapter

규칙·입력·출력·게이트의 SSOT는 `docs/skill-contracts/standard-review.md`다.
Verify 필수 검사와 모든 AC가 PASS면 사용자에게 멈춰 묻지 않고 즉시 이 스킬을 실행한다.
`scripts/review.sh --plan <계획>`으로 Packet을 만들고, 구현자와 분리된 리뷰어 1명에게만
명세·계획·변경 범위·검증 증거를 전달한다. 리뷰어를 지원하지 않는 환경이면 새 세션 또는
사람 리뷰로 이어가고, 구현자가 자기 리뷰를 독립 리뷰로 기록하지 않는다.
Packet 준비나 Review에서 테스트를 다시 실행하지 않는다. 최신 소스 지문을 재사용하고,
소스 변경·증거 오류가 발견된 경우에만 Verify로 돌아간다.
Standards / Spec / Evidence 판정과 근거를 Exec Plan에 기록한 뒤 Converge를 실행한다.
사람의 완료 처리·추가 개선·보류 결정은 `docs/skill-contracts/standard-human-decision.md`를 따른다.
