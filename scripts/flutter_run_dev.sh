#!/usr/bin/env bash
# Run the app with local secrets from .env.local (gitignored).
#
# Setup:
#   cp .env.local.example .env.local
#   # paste your RevenueCat test key(s) into .env.local
#
# Usage:
#   ./scripts/flutter_run_dev.sh
#   ./scripts/flutter_run_dev.sh -d emulator-5554

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

ENV_FILE="$ROOT/.env.local"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing .env.local — copy from .env.local.example and add your keys."
  exit 1
fi

# shellcheck disable=SC1090
set -a
source "$ENV_FILE"
set +a

ARGS=()
if [[ -n "${REVENUECAT_API_KEY:-}" ]]; then
  ARGS+=(--dart-define="REVENUECAT_API_KEY=$REVENUECAT_API_KEY")
fi
if [[ -n "${REVENUECAT_ANDROID_KEY:-}" ]]; then
  ARGS+=(--dart-define="REVENUECAT_ANDROID_KEY=$REVENUECAT_ANDROID_KEY")
fi
if [[ -n "${REVENUECAT_IOS_KEY:-}" ]]; then
  ARGS+=(--dart-define="REVENUECAT_IOS_KEY=$REVENUECAT_IOS_KEY")
fi
if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
  ARGS+=(--dart-define="ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY")
fi

if [[ ${#ARGS[@]} -eq 0 ]]; then
  echo "No keys found in .env.local"
  exit 1
fi

echo "Running with dart-define from .env.local (${#ARGS[@]} secret(s))"
exec flutter run "${ARGS[@]}" "$@"
