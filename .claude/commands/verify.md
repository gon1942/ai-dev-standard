---
description: 실행 계획 기반 표준 검증 실행·증거 기록
allowed-tools: Bash(node scripts/lib/cli.js record-verification-evidence*)
---

인자로 받은 활성 실행 계획 파일을 기준으로
`node scripts/lib/cli.js record-verification-evidence <실행계획파일>`을 실행하고 결과를 요약해라.

검증 계약 버전 2의 `## E2E 판정`이 `필요`이면, 자동 방식은 이어서
`node scripts/lib/cli.js record-e2e-evidence <실행계획파일>`을 실행한다. 수동 Browser UAT 방식은
실제 관찰 결과를 E2E 증거 형식으로 기록한 뒤 같은 명령으로 형식을 확인한다. E2E 증거가 없거나
FAIL/SKIP이면 Review로 진행하지 않는다.

- PASS면: "검증 통과 — 변경 사항 검토 진행 가능" + 실행 명령·종료 코드·결과 요약
- FAIL이면: 실패한 단계와 원인을 정리해 보고 (수정은 별도 지시 시에만)

명령이 추가한 자동 검증 증거 외에, AC의 의미적 판정과 UAT 결과는 에이전트가 같은 실행 계획의
완료 기록·AC 판정에 별도로 반영해야 한다. 검증 PASS만으로 `DONE` 또는 완료 승인을 표현하지 않는다. 변경 사항 검토와 수렴 뒤에는
Review 계약의 검토 결정 요청 형식을 따른다.
