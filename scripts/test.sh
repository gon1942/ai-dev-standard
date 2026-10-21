#!/usr/bin/env bash
# 테스트 실행 — Node 엔진 shim (원본: scripts/reference/test.sh)
# 인자: unit | integration | regression | all (기본 all)
exec node "$(cd "$(dirname "$0")" && pwd)/lib/cli.js" test "$@"
