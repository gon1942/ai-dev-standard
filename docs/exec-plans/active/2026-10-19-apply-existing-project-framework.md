# Exec Plan: 기존 프로젝트 공통 프레임워크 적용

- 상태: active
- 제품 명세: docs/product-specs/2026-10-19-apply-existing-project-framework.md
- 생성: 2026-10-19, 담당: Codex

## 구현 계획

- 목적: 기존 프로젝트에 공통 프레임워크를 적용할 때 LLM이 일관되게 분석·제안·승인·반영하도록 한다.
- 범위: 매니페스트, 적용 계획 생성 스크립트, 도구별 얇은 스킬 어댑터, 온보딩/골격 문서 정합화.
- 제외: 외부 프로젝트의 실제 파일 변경과 자동 병합.
- 영향 파일 (예상): docs/, scripts/, AGENTS.md, README.md, .opencode/, .claude/

## 검증 계획

| AC | 검증 방법 | 기대 증거 |
|---|---|---|
| AC-01 | 매니페스트 내용 검토 | 필수 자산과 처리 규칙 표 존재 |
| AC-02 | 두 스킬 어댑터 확인 | 같은 매니페스트와 절차를 참조 |
| AC-03 | 임시 기존 프로젝트 대상으로 보고서 실행 | 생성·보존·병합 제안·제외 분류 출력 |
| AC-04 | 스크립트 문법/읽기 전용 실행 | 대상 파일 변경 없이 성공 |

## 회귀 검증 대상

- scripts/check-framework.sh
- scripts/bootstrap-framework.sh --analyze
- scripts/analyze-project.sh --write

## 완료 기록

| AC | 판정 | 증거 |
|---|---|---|
| AC-01 | PASS | `docs/framework-manifest.md`에 처리 상태, 관리 자산, 승인 경계를 기록했다. |
| AC-02 | PASS | `.opencode/skills/apply-existing-project/`와 `.claude/skills/apply-existing-project/`가 동일 SSOT를 참조한다. |
| AC-03 | PASS | 임시 기존 프로젝트에서 `scripts/plan-framework-apply.sh --project-dir <대상>`이 분류 보고서를 출력했다. |
| AC-04 | PASS | `bash -n scripts/*.sh`, 프레임워크/임시 대상 검사, 기존 `AGENTS.md` 보존을 확인했다. |

- 검증 결과: 구조 검증 통과. 이 저장소는 `template` 모드이므로 최종 상태는 `active`를 유지한다.
- 참고: 템플릿 모드에서는 애플리케이션 lint/typecheck/test가 실행되지 않아 `READY_FOR_REVIEW`를 선언할 수 없다.
