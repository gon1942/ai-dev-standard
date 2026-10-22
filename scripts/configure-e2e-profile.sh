#!/usr/bin/env bash
# Node 엔진 shim — 원본 bash 구현은 scripts/reference/configure-e2e-profile.sh에 보존된다.
exec node "$(cd "$(dirname "$0")" && pwd)/lib/cli.js" configure-e2e-profile "$@"
