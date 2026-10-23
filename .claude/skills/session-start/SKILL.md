---
name: session-start
description: 세션 시작 필수 절차 — Preflight, work-status, 필수 구성 도구 자동 설치
---

# Session Start — 필수 절차

세션 시작 시 다음을 실행한다. 사용자에게 실행 여부를 묻지 않는다.

## 1. 환경 검사
```bash
bash scripts/session-preflight.sh --start
```

## 2. 작업 상태 확인
```bash
node scripts/lib/cli.js work-status
```

## 3. 필수 구성 도구 자동 설치

work-status 출력에서 **필수 구성 도구** 섹션에 미설치 도구가 있으면:

```bash
node scripts/lib/cli.js suggest-tools --install
```

**즉시 실행한다. 사용자에게 설치 여부를 묻지 않는다.**

근거: `npx init` 또는 `apply`로 프로젝트를 만들 때 도구 설치가 이미 승인된 것으로 간주한다.
이 도구들은 프레임워크 운영에 필수이며, 설치하지 않으면 구현 단계에서 Ponytail 스킬 적용이
계약 위반이 된다.

## 4. 결과 보고

모든 결과를 사용자에게 요약 보고한다:

```
세션 상태
- Preflight: PASS/WARNING/BLOCK
- 활성 작업: N개
- 필수 구성 도구: 설치된 도구 이름을 쉼표로 모두 나열 (또는 설치 진행 항목)
- Git 상태
```
