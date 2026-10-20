---
name: verify
description: AC와 실제 실행 증거를 대조하는 표준 검증 어댑터
---

# Verify Adapter

규칙·입력·출력·게이트의 SSOT는 `docs/skill-contracts/standard-verify.md`다.
`scripts/verify-plan.sh <계획>`의 실제 종료 코드와 AC별 증거를 기록한다.
FAIL/BLOCKED/미검증은 Review로 넘기지 않는다.
