# Exec Plan: Global Session Hooks

- 상태: active
- 제품 명세: docs/product-specs/2026-10-19-global-session-hooks.md
- 생성: 2026-10-19, 담당: Codex

## 구현 계획

- 전역 Codex/Claude SessionStart 명령과 OpenCode session-created plugin을 설치하는 idempotent installer를 제공한다.
- 전역 hook은 현재 Git 프로젝트에 `scripts/session-preflight.sh`가 있을 때만 실행한다.
- installer는 기존 JSON 설정을 병합하고 최초 변경 전 백업한다.
- 격리된 HOME에서 설치·재설치를 검사하고, 실제 사용자 설정에는 검증 후 한 번만 설치한다.

## 검증 계획

| AC | 검증 방법 | 기대 증거 |
|---|---|---|
| AC-01 | 임시 HOME 설치 | Codex/Claude hook 설정과 OpenCode plugin 생성 |
| AC-02 | 비적용 임시 Git 프로젝트에서 hook 실행 | 대상에 파일 변경 없이 안내 출력 |
| AC-03 | installer 두 번 실행 | JSON 유효, hook 수가 하나, 기존 hook 보존 |
| AC-04 | 문서·shell/node syntax 검사 | 설치/신뢰/수동 fallback 설명과 실행 가능성 |

## 회귀 검증 대상

- `scripts/bootstrap-framework.sh` — 신규·기존 프로젝트에 전역 hook 자산을 누락 없이 복사한다.
- `scripts/check-framework.sh` — 필수 골격과 전역 hook 자산을 함께 확인한다.
- `scripts/test-project-preflight.sh` — 기존 Project/Session Preflight 판정이 유지된다.

## 완료 기록

| AC | 판정 | 증거 |
|---|---|---|
| AC-01 | PASS | 임시 HOME에서 Codex/Claude JSON 설정과 OpenCode plugin, 공통 hook 파일이 생성됐다. 실제 사용자 전역 설치도 JSON 유효성과 각 hook 1개를 확인했다. 전역 원본을 템플릿 공급원으로 전달해 손상된 대상도 복구한다. |
| AC-02 | PASS | 프레임워크가 없는 임시 Git 프로젝트에서 hook은 안내만 출력했고, 전후 파일 목록이 동일했다. |
| AC-03 | PASS | 격리 HOME에서 installer를 두 번 실행해 기존 hook 1개 보존, framework hook 1개 유지, 최초 변경 전 백업 생성을 확인했다. |
| AC-04 | PASS | `bash -n`, `node --check`, `scripts/test-project-preflight.sh`, 골격 검사, 복제 골격 검사를 실행했다. `AGENTS.md`와 `docs/`를 삭제한 손상 fixture와 `ai-dev-standard_tmp2`에서 전역 hook 복구를 확인했다. Codex 신뢰 절차와 fallback은 문서화했다. |
