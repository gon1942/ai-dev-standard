#!/usr/bin/env bash
# 공통 프레임워크 원본의 핵심 회귀 테스트를 한 번에 실행한다.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

for suite in \
  scripts/test-framework-assets.sh \
  scripts/test-framework-template.sh \
  scripts/test-review.sh \
  scripts/test-project-preflight.sh \
  scripts/test-validate-plan.sh \
  scripts/test-plan-templates.sh \
  scripts/test-e2e-gate.sh \
  scripts/test-e2e-profile.sh \
  scripts/test-suggest-tools.sh \
  scripts/test-verification-evidence.sh; do
  echo "=== FRAMEWORK TEST: $suite ==="
  bash "$suite"
done

echo 'PASS: framework regression suite'
