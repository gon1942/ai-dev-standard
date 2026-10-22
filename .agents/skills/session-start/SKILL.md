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
근거: `npx init` 또는 `apply` 시점에 도구 설치가 이미 승인된 것이다.
(Playwright는 제외 — 승인된 E2E 프로필로만 설치)

## 4. 결과 보고

```
세션 상태
- Preflight: PASS/WARNING/BLOCK
- 활성 작업: N개
- 필수 구성 도구: 모두 설치됨 (또는 설치 진행)
- Git 상태
```
