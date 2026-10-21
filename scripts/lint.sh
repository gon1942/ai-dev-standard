#!/usr/bin/env bash
# 린트/정적 검사 — Node 엔진 shim (원본: scripts/reference/lint.sh)
# exit 0=PASS, 1=FAIL, 3=SKIP(실행한 검사 없음). PLACEHOLDER 교체 정책은 계약 문서 참조.
exec node "$(cd "$(dirname "$0")" && pwd)/lib/cli.js" lint "$@"
