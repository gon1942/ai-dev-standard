# 경쟁 저장소 비교 분석 — AI 개발 표준 프레임워크

- 조사일: 2026-10-20
- 성격: 비규범 참조 자료 (계약·규칙을 변경하지 않는다)
- 대상: ai-dev-standard와 유사 목적의 공개 저장소

## 조사 대상 (규모순)

| 저장소 | 스타 | 핵심 정체성 |
|---|---|---|
| Fission-AI/OpenSpec | 72k★ | 스펙 주도 개발(SDD), 슬래시 명령, 30+ 도구 지원 |
| open-gsd/gsd-core (구 get-shit-done) | 64k★ | 컨텍스트 엔지니어링 — "context rot" 해결 |
| buildermethods/agent-os | 5.5k★ | 코드베이스에서 표준 자동 추출·주입 |
| Pimzino/spec-workflow-mcp | 4.3k★ | MCP 기반 구조화 SDD |
| sanjeed5/awesome-cursor-rules-mdc 등 | ~3.6k★ | 룰 컬렉션 (프레임워크 아님) |
| (참고) github/spec-kit | – | GitHub 공식 SDD, 무거운 게이트 방식 |

## 기능 비교

| 기능 | OpenSpec | GSD Core | agent-os | ai-dev-standard (조사 시점) |
|---|---|---|---|---|
| 스펙→계획→구현 흐름 | ✓ | ✓ (5단계 루프) | ✓ | ✓ |
| 실행 증거 기반 검증 | 약함 | 보통 | ✗ | 강함 (verify-plan·converge + 종료코드) |
| 사람 승인 경계 | 부분 | 부분 | ✗ | 강함 (READY_FOR_REVIEW ≠ done) |
| 슬래시 명령 UX | 강함 (/opsx:*) | ✓ (/gsd-*) | ✗ | 약함 (/verify, /task-record 2개) |
| 서브에이전트 컨텍스트 관리 | ✗ | 강함 (fresh-context 분산) | ✗ | ✗ (메인 세션 단일) |
| 세션 간 공유 메모리 | ✗ | ✓ (STATE.md/CONTEXT.md) | ✗ | 부분 (preflight 캐시=환경만) |
| 코드베이스 표준 자동 추출 | ✗ | ✗ | 강함 | 부분 (analyze-project=인벤토리만) |
| brownfield 적용 | ✓ | ✓ | ✓ | ✓ (안전 분류+승인 — 강점) |
| npx 배포 | ✓ | ✓ | ✓ | ✓ (2026-10-20 게시 완료) |
| 개선 후보 루프 | ✗ | ✗ | ✗ | 유일 (사람 승인형 회고) |

## OpenSpec 핵심 관찰

- 철학: "fluid not rigid, iterative not waterfall, brownfield 중심"
- 변경 폴더 구조: proposal.md + specs/(요구·시나리오) + design.md + tasks.md
- 아카이브 시 스펙 기준선 갱신 (living specs)
- Stores(베타): 별도 저장소에서 크로스리포 기획 공유
- 30+ 도구 통합, Homebrew 배포, 커뮤니티 스키마

## GSD Core 핵심 관찰

- 해결 문제: context rot — 컨텍스트 창이 차면서 품질이 저하되는 현상
- 해결: 무거운 연구·계획·실행을 fresh-context 서브에이전트에서 수행, 메인 세션은 경량 유지
- 5단계 루프: Discuss → Plan → Execute(병렬 웨이브) → Verify → Ship
- STATE.md / CONTEXT.md로 세션 경계 생존 (재개 가능)
- 다국어 README (한국어 포함)

## agent-os 핵심 관찰

- Discover Standards: 코드베이스에서 패턴·관례를 문서화된 표준으로 추출
- Deploy Standards: 작업 맥락에 맞는 표준만 지능적 주입
- Index Standards: 표준 조직·검색

## 반영 후보 (논의 수렴 결과)

후보 등록은 실제 마찰이 관측된 완료 작업을 출처로 진행한다 (규칙 준수).

| 우선순위 | 후보 | 근거 | 상태 |
|---|---|---|---|
| 1 | 작업별 상태 파일 (docs/exec-plans/active/<작업>-state.md) | 세션 단절 시 재개 정확도. 전역 STATE.md 대신 작업별 — 동시 작업 충돌·오래된 상태 누적 회피. gitignore 정책과 정합(로컬 유지) | 합의됨 |
| 2 | Plan·Implement fresh-context 운영 계약 | 리뷰 분리는 이미 존재(standard-review 9-10줄). 갭은 Plan·Implement. 언제 분리하고 최소 문맥 무엇을 전달할지 명확화 | 합의됨 |
| 보류 | 슬래시 명령 어댑터 | 에이전트 주도 운영에서 진입은 계약이 담당 — 필요성 낮음. "특정 단계 강제 진입" 마찰 관측 시 재검토. 대안: README에 "이렇게 말하면 됩니다" 표 | 강등됨 |

## 검증 엔진 관련 후속

검증 엔진 재구성(스킬 판단 + Node CLI 실행)은 별도 조사로 발전:
`docs/references/2026-10-21-verification-engine-research.md`,
설계는 `docs/design-docs/verification-rearchitecture.md` 참조.
