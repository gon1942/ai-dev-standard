# Exec Plan: Standard Skill Contracts

- 상태: active
- 제품 명세: docs/product-specs/2026-10-19-standard-skill-contracts.md
- 생성: 2026-10-19, 담당: Codex

## 구현 계획

- `docs/skill-contracts/`에 Plan, Implement, Verify, Review, Improve 계약을 둔다.
- `validate-plan.sh`로 승인된 명세·계획·AC 검증 계획을 구현 전 검사한다.
- OpenCode/Claude의 스킬은 계약 경로만 참조하는 얇은 어댑터로 만든다.
- AGENTS/workflow/manifest/bootstrap을 계약과 새 스크립트에 연결한다.

## 검증 계획

| AC | 검증 방법 | 기대 증거 |
|---|---|---|
| AC-01 | 계약 파일 검사 | 다섯 계약에 entry/actions/outputs/exit/next 단계가 존재 |
| AC-02 | 임시 승인/미승인 계획 검사 | 승인 계획 PASS, 미승인·누락 AC 계획 FAIL |
| AC-03 | 어댑터 검사 | OpenCode/Claude 다섯 경로가 공통 계약을 참조 |
| AC-04 | AGENTS 검사 | Codex 공통 계약 경로 참조 |

## 회귀 검증 대상

- `scripts/verify-plan.sh`, `scripts/converge-plan.sh`
- `scripts/bootstrap-framework.sh`, `scripts/check-framework.sh`
- 기존 OpenCode/Claude implement·verify·review 어댑터

## 완료 기록

| AC | 판정 | 증거 |
|---|---|---|
| AC-01 | PASS | `docs/skill-contracts/standard-{plan,implement,verify,review,improve}.md`에 공통 계약을 정의했다. |
| AC-02 | PASS | `scripts/test-validate-plan.sh`에서 pending 계획과 검증 계획에 AC가 누락된 계획은 FAIL, 승인·완성 계획은 PASS를 확인했다. |
| AC-03 | PASS | OpenCode/Claude의 plan·implement·verify·review·improve 어댑터가 각 공통 계약만 참조하며, bootstrap 복제 검사를 통과했다. |
| AC-04 | PASS | `AGENTS.md`가 `docs/skill-contracts/`를 필수 문맥으로 지정했다. |
