#!/usr/bin/env bash

set -euo pipefail

OPENCLAW_DIR="${OPENCLAW_DIR:-/home/dev/openclaw}"

die() {
  printf '[onboard-openclaw] ERROR: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: onboard-openclaw

Run interactive OpenClaw onboarding from the source checkout without
attempting daemon or service installation.
EOF
}

ensure_checkout_ready() {
  command -v pnpm >/dev/null 2>&1 || die "pnpm is required but was not found in PATH."
  [[ -d "${OPENCLAW_DIR}" ]] || die "OpenClaw is not checked out yet. Run setup-openclaw first."
  [[ -f "${OPENCLAW_DIR}/package.json" ]] || die "Missing package.json in ${OPENCLAW_DIR}. Run setup-openclaw first."
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "Unknown argument: $1"
        ;;
    esac
  done

  ensure_checkout_ready
  cd "${OPENCLAW_DIR}"
  exec pnpm openclaw onboard
}

main "$@"
