---
description: 실행 계획 기반 표준 검증 실행
allowed-tools: Bash(scripts/verify-plan.sh)
---

인자로 받은 활성 실행 계획 파일을 기준으로
`scripts/verify-plan.sh <실행계획파일>`을 실행하고 결과를 요약해라.

- PASS면: "READY_FOR_REVIEW 가능" + 결과 요약
- FAIL이면: 실패한 단계와 원인을 정리해 보고 (수정은 별도 지시 시에만)

결과는 같은 실행 계획 파일의 완료 기록과 AC 판정에 증거로 반영해야 한다.
