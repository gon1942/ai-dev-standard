---
name: verify
description: AC와 실제 실행 증거를 대조하는 표준 검증 어댑터
---

# Verify Adapter

규칙·입력·출력·게이트의 SSOT는 `docs/skill-contracts/standard-verify.md`다.
`node scripts/lib/cli.js record-verification-evidence <계획>`으로 실제 검증을 실행해 기계적 실행 증거를
기록하고, AC별 의미 판정은 별도로 기록한다.
검증 방법이 UAT로 지정된 AC는 `docs/skill-contracts/standard-uat.md` 계약을 함께 따른다.
검증 계약 버전 2 Plan에서 E2E가 `필요`이면 자동 방식은
`node scripts/lib/cli.js record-e2e-evidence <계획>`으로 별도 실행 증거를 남긴다. 수동 Browser UAT는
관찰 결과를 기록한 뒤 같은 명령으로 형식을 확인한다.
FAIL/BLOCKED/미검증은 Review로 넘기지 않는다.
