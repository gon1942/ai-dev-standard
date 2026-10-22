#!/usr/bin/env bash
exec node "$(cd "$(dirname "$0")" && pwd)/lib/cli.js" suggest-tools "$@"
