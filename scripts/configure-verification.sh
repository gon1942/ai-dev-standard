#!/usr/bin/env bash
# Node 엔진 shim — 승인된 Bootstrap 검증 프로필을 구성·실행한다.
exec node "$(cd "$(dirname "$0")" && pwd)/lib/cli.js" configure-verification "$@"
