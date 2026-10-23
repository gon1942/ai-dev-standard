#!/usr/bin/env bash
# Node 엔진 shim — 명시적 사람 승인 직후 Bootstrap 문서 내용 지문을 기록한다.
exec node "$(cd "$(dirname "$0")" && pwd)/lib/cli.js" record-bootstrap-approval "$@"
