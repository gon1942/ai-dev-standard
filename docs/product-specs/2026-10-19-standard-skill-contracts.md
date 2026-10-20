# Product Spec: Standard Skill Contracts

- 상태: approved
- 생성: 2026-10-19
- 사용자 요청: Codex, OpenCode, Claude Code가 Plan, Implement, Verify, Review, Improve 단계에서 동일한 입력·출력·게이트를 따르도록 공통 스킬 계약을 구축한다.

## 확정 요구사항

- 공통 스킬 계약은 도구별 SKILL.md가 아닌 `docs/`에 둔다.
- Plan은 Product Spec 승인과 Exec Plan 승인을 분리하고, 승인된 계획만 Implement로 넘긴다.
- Verify FAIL/BLOCKED와 Review FAIL/WARN은 다음 단계로 통과하지 않고 적절한 선행 단계로 복귀한다.
- Improve는 후보 기록만 수행하며 사람 승인 전 규칙·스킬을 바꾸지 않는다.

## 완료 조건 (Acceptance Criteria)

| ID | 완료 조건 | 기대 결과 |
|---|---|---|
| AC-01 | 공통 계약 | 다섯 표준 단계의 입·출력·게이트가 docs에 정의된다. |
| AC-02 | Plan 게이트 | 승인된 Product Spec과 Exec Plan을 검사하는 진입점이 있다. |
| AC-03 | 도구 어댑터 | OpenCode·Claude의 다섯 스킬이 공통 계약만 참조한다. |
| AC-04 | Codex 경로 | AGENTS.md가 동일 계약을 참조한다. |
