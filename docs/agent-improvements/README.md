# Agent Improvements

작업 중 발견한 프레임워크 개선 기회를 통제된 방식으로 축적한다.

```text
completed exec plan → candidates/ → 사람 결정 → approved/ 또는 rejected/
                                       │
                                       └→ 승인된 후보는 별도 Product Spec·Exec Plan으로 구현
```

## 규칙

- 작업 완료 후 후보를 검토한다. 반복된 실패, 검증 누락, 명확한 도구·문서 공백처럼 근거가 있는 경우에만 만든다.
- 후보 파일에는 문제, 근거, 제안, 영향 범위, 위험, 출처 실행 계획을 모두 적는다.
- 후보 작성은 공통 규칙·스킬·스크립트의 자동 수정 권한을 주지 않는다.
- 사람만 `scripts/decide-improvement.sh`로 `approved` 또는 `rejected` 결정을 내린다.
- 승인된 후보도 별도 제품 명세와 실행 계획을 거쳐 구현한다.

`AGENTS.md`, `ARCHITECTURE.md`, 완료 기준, 보안 규칙, 검증 스크립트는 후보 상태에서
절대 수정하지 않는다.

## 명령

```bash
# 후보 기록만 생성한다. 이 명령은 프레임워크 규칙을 바꾸지 않는다.
scripts/new-improvement-candidate.sh "제목" "문제" "근거" "출처-실행계획"

# 사람만 실행한다. 승인 자체가 구현 승인은 아니다.
scripts/decide-improvement.sh approve docs/agent-improvements/candidates/<후보>.md "결정자" "승인 사유"
```

승인된 파일은 개선의 근거일 뿐이다. 실제 변경은 새 제품 명세를 승인하고 새 실행 계획을
만든 뒤에만 시작한다. 이 개선 작업에서만 필요한 `AGENTS.md`, 문서, 스킬, 스크립트를 갱신하고
검증한다.
