---
name: session-start
description: 세션 시작 시 반드시 실행하는 필수 절차 — 작업 상태·보조 도구 확인
---

# Session Start — 필수 절차

세션 시작 시 반드시 다음을 실행하고 결과를 사용자에게 요약 보고한다.

## 절차

```bash
# 1. 환경 검사
bash scripts/session-preflight.sh --start

# 2. 작업 상태 확인 (보조 도구 상태 포함)
node scripts/lib/cli.js work-status
```

## 보고 형식

```
세션 상태
- Preflight: PASS/WARNING/BLOCK
- 활성 작업: N개 (전환 누락/승인 대기/진행 중)
- 보조 도구: 미설치 항목 안내
- Git 상태: 변경 N건 또는 깨끗함
```

## 보조 도구 미설치 시

work-status 출력의 보조 도구 섹션에 미설치 도구가 있으면:
1. 사용자에게 설치를 안내
2. 승인 후 `node scripts/lib/cli.js suggest-tools --install` 실행
3. 설치는 사용자 확인 후에만 진행
