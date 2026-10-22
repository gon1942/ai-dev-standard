#!/usr/bin/env bash
# Node 엔진 shim — E2E 또는 수동 UAT 증거를 활성 실행 계획에 기록·확인한다.
exec node "$(cd "$(dirname "$0")" && pwd)/lib/cli.js" record-e2e-evidence "$@"
