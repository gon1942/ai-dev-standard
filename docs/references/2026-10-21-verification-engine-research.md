# GitHub 공개 프로젝트의 AI 개발 검증 방식 조사

- 조사일: 2026-10-21
- 성격: 비규범 참조 자료 (계약·규칙을 변경하지 않는다)
- 초점: 일반 테스트 프레임워크가 아니라, AI 에이전트가 코딩을 완료한 뒤 **어떤 절차로 기능을 검증하는가**. 그리고 그 검증을 `.sh` 스크립트 없이 스킬·지침으로 수행할 수 있는가

## 확인된 중요한 사실

GitHub에는 Markdown 기반 스킬과 워크플로 지침으로 검증 절차를 구현한 프로젝트가 실재한다.
이 중 세 접근이 ai-dev-standard에 참고 가치가 높다:

- obra/superpowers — 테스트 실행 증거 없이는 완료 선언 금지
- open-gsd/gsd-core — 개발 결과를 실제 사용자 관점에서 검증, 실패 시 수정 계획 생성
- GitHub Spec Kit — 명세·계획·작업·구현 결과의 일치 여부 검증

## 1. 검증 방식 비교

| 프로젝트 | 검증 구현 방식 | 스킬 중심 가능성 | 주요 특징 |
|---|---|---|---|
| Superpowers | SKILL.md | 매우 높음 | 실행 결과 기반 완료 선언 |
| GSD Core | Markdown 명령·워크플로 + 도구 | 높음 | UAT, 오류 진단, 수정 반복 |
| GitHub Spec Kit | Agent Skills + CLI | 높음 | 명세 일치성과 수렴 |
| skill-validator | CLI + 리뷰 스킬 | 혼합 | 스킬 자체의 정적·동적 품질 검사 |

## 2. Superpowers — 스킬 기반 검증의 대표 사례

- 저장소: https://github.com/obra/superpowers
- 핵심 스킬: verification-before-completion
  https://github.com/obra/superpowers/blob/main/skills/verification-before-completion/SKILL.md
- 완료 선언 전 반드시 실제 검증 명령을 실행하도록 지시

검증 절차 5단계:

1. IDENTIFY — 완료를 증명할 명령 결정
2. RUN — 검증 명령을 새로 실행
3. READ — 출력 전체·종료 코드·실패 수 확인
4. VERIFY — 실행 결과가 성공 주장을 뒷받침하는지 확인
5. CLAIM — 증거가 있을 때만 완료 선언

단순 테스트 통과와 요구사항 충족을 구분한다 ("lint 통과가 빌드 성공을 증명하지 못한다").

ai-dev-standard 적용: verify.sh의 실행 의도 중 상당 부분을 standard-verify 계약으로 옮길 수 있다.
다만 **스킬 자체가 실행 기록의 무결성이나 지침 준수를 강제하지는 못한다** — Superpowers도
완료 주장 전 새 검증 명령 실행과 출력·종료 코드 확인을 요구할 뿐, 스킬만으로 완결되지 않는다.

## 3. OpenSpec — 구현과 명세를 비교하는 검증 스킬

- 저장소: https://github.com/Fission-AI/OpenSpec
- 핵심 파일: openspec-verify-change/SKILL.md
  https://github.com/Fission-AI/OpenSpec/blob/main/skills/openspec-verify-change/SKILL.md
- 명령: /opsx:verify

검증 기준 3영역:

| 검증 영역 | 내용 | ai-dev-standard 대응 |
|---|---|---|
| Completeness | 모든 작업과 요구사항이 구현됐는가 | AC 커버리지 |
| Correctness | 구현이 명세 의도와 일치하는가 | AC 기능 검증 |
| Coherence | 설계와 코드 구조가 일관적인가 | Standards Review |

검증 결과는 CRITICAL / WARNING / SUGGESTION으로 분류한다.
219줄 SKILL.md에 절차가 정의되어 있으나 **OpenSpec CLI가 필수** — 순수 Markdown만으로
완결되지 않는다. 두 사례 모두 Markdown이 실행 엔진을 없애지 않는다는 반증.

## 4. GSD Core — 사용자 관점 기능 검증

- 저장소: https://github.com/open-gsd/gsd-core
- 참조: verify-and-ship
  https://github.com/open-gsd/gsd-core/blob/next/docs/how-to/verify-and-ship.md
- 명령: /gsd-verify-work

흐름: 구현 완료·SUMMARY.md 생성 → 검증할 기능 추출 → UAT 실행 →
PASS: UAT 결과 기록 / FAIL: 원인 분석·수정 계획 → 수정 → 재검증

- 검증 결과는 UAT.md에 저장 — 세션 중단 시 이어서 진행 가능 (재개 가능 기록)
- 자동 테스트로 입증된 항목과 사람 판단이 필요한 항목을 구분
- 브라우저 기반 검증을 위한 MCP 도구 지원

ai-dev-standard 적용: "실제 기능 검증 → 오류 재현 → 수정 → 재검증" 루프의 참고 자료.
재개 체크포인트 설계와도 연결된다.

## 5. Superpowers — 독립 코드 리뷰 스킬

- 참조: requesting-code-review/SKILL.md
  https://github.com/obra/superpowers/blob/main/skills/requesting-code-review/SKILL.md

구현 에이전트가 스스로 코드만 평가하는 대신 별도 리뷰 에이전트를 활용:

1. 구현 전후 Git 변경 범위 파악
2. 요구사항과 구현 내용을 리뷰 에이전트에 전달 — **불필요한 구현 세션 이력은 넘기지 않음**
3. 리뷰 에이전트가 코드와 요구사항 비교
4. Critical·Important 문제는 다음 단계 전 수정

주의: 도구별 하위 에이전트 인터페이스 차이로 Codex에서 리뷰 에이전트 호출이 불가능한
사례가 보고되어 있다 — 다중 에이전트 공통 지원 프레임워크는 우회 경로가 필요하다.

## 6. Agent OS와 GitHub Spec Kit

- agent-os: 백엔드·프런트엔드 전문 검증 에이전트와 최종 구현 검증 단계 구분
- spec-kit: spec → plan → tasks → implement → converge 흐름, 명세 누락·문서 불일치 분석
  스킬 제공. Windows·macOS·Linux 지원, 다중 에이전트 통합

## 7. ai-dev-standard 적용 방안 (조사 결론)

28개 스크립트 전부 변환은 불필요하다. 다음 조합을 권장한다:

| 공통 스킬 | 참고 프로젝트 | 역할 |
|---|---|---|
| standard-verify | Superpowers | 테스트 선정·실행·증거 확인 |
| standard-spec-verify | OpenSpec | 요구사항·AC·구현 일치성 검증 |
| standard-uat | GSD Core | UI·API·실제 사용자 기능 검증 |
| standard-review | Superpowers, Agent OS | 독립 코드 리뷰·표준 준수 확인 |

필수 제약: 스킬 준수만으로 증거 신뢰성을 보장할 수 없으므로, converge-plan의 승인 게이트처럼
**증거 누락과 상태 전환을 강제하는 작은 기계적 검증 장치는 유지**해야 한다.

## 8. 우선 참조 소스 4개

1. Superpowers — verification-before-completion
2. OpenSpec — openspec-verify-change
3. GSD Core — verify-and-ship
4. Superpowers — requesting-code-review

## 최종 판단 (조사 원문)

가장 잘 맞는 조합: Superpowers의 증거 기반 검증 + OpenSpec의 명세 검증 + GSD의 실제 기능 검증.

설계 차이: 현재 28개 스크립트는 "정해진 검증 절차를 실행"하는 구조인 반면, 스킬 중심 구조는
"사용자 요청을 분석해 무엇을 어떻게 검증할지 결정하고 실행"하는 구조로 발전시킬 수 있다.
단, 실제 테스트와 독립 리뷰를 실행할 수 있는 에이전트 권한·도구 지원이 전제되어야 한다.
