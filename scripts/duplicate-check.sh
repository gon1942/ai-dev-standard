#!/usr/bin/env bash
# Node 엔진 shim — jscpd 기준선 기반 신규 중복 검사 (경고 방식).
exec node "$(cd "$(dirname "$0")" && pwd)/lib/cli.js" duplicate-check "$@"
