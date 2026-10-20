# Exec Plan: 프로젝트 부트스트랩과 최종 수렴 판정

- 상태: active
- 제품 명세: docs/product-specs/2026-10-19-project-bootstrap-and-convergence.md
- 생성: 2026-10-19, 담당: Codex

## 구현 계획

- 목적: 프레임워크 적용 후 기본 골격을 실제 프로젝트 문맥으로 발전시키고, 완료 선언 전 증거를 수렴 검사한다.
- 범위: 문서, 도구별 부트스트랩 스킬, 입력 초안/수렴 스크립트, 기존 워크플로우 연결.
- 제외: 외부 프로젝트 변경, 실제 애플리케이션 검증 명령 연결.
- 영향 파일 (예상): docs/, scripts/, .opencode/, .claude/, AGENTS.md, README.md

## 검증 계획

| AC | 검증 방법 | 기대 증거 |
|---|---|---|
| AC-01 | 부트스트랩 문서·두 어댑터 확인 | 동일 SSOT와 분석·질문 순서 참조 |
| AC-02 | 임시 신규 프로젝트에 입력 초안 생성 | 질문과 문서 초안 경로 출력 |
| AC-03 | 기존 지침 파일이 있는 임시 프로젝트 검토 | 보존·diff 승인 경계가 문서화됨 |
| AC-04 | 수렴 스크립트에 템플릿/누락 증거 계획 전달 | 안전하게 실패하고 이유를 출력 |

## 회귀 검증 대상

- scripts/check-framework.sh
- scripts/bootstrap-framework.sh --init
- scripts/verify-plan.sh
