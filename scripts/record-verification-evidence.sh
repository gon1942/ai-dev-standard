#!/usr/bin/env bash
# Node 엔진 shim — 검증 실행 증거를 활성 Exec Plan에 자동 기록한다.
exec node "$(cd "$(dirname "$0")" && pwd)/lib/cli.js" record-verification-evidence "$@"
