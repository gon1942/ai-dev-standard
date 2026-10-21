#!/usr/bin/env bash
# Node 엔진 shim — 원본 bash 구현은 scripts/reference/complete-exec-plan.sh에 보존된다.
# 동치성 증거: scripts/test-parity.sh
exec node "$(cd "$(dirname "$0")" && pwd)/lib/cli.js" complete-exec-plan "$@"
