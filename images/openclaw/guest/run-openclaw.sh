#!/usr/bin/env bash

set -euo pipefail

OPENCLAW_DIR="${OPENCLAW_DIR:-/home/dev/openclaw}"

log() {
  printf '[run-openclaw] %s\n' "$*"
}

die() {
  printf '[run-openclaw] ERROR: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: run-openclaw [--port <port>]

Launch the OpenClaw gateway in the foreground from the source checkout.
EOF
}

ensure_checkout_ready() {
  command -v pnpm >/dev/null 2>&1 || die "pnpm is required but was not found in PATH."
  [[ -d "${OPENCLAW_DIR}" ]] || die "OpenClaw is not checked out yet. Run setup-openclaw first."
  [[ -f "${OPENCLAW_DIR}/package.json" ]] || die "Missing package.json in ${OPENCLAW_DIR}. Run setup-openclaw first."
}

main() {
  local gateway_port=""
  local -a cmd

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --port)
        [[ $# -ge 2 ]] || die "--port requires a value."
        gateway_port="$2"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "Unknown argument: $1"
        ;;
    esac
  done

  if [[ -n "${gateway_port}" && ! "${gateway_port}" =~ ^[0-9]+$ ]]; then
    die "Gateway port must be an integer."
  fi

  ensure_checkout_ready

  cmd=(pnpm openclaw gateway --verbose)
  if [[ -n "${gateway_port}" ]]; then
    log "Starting OpenClaw gateway on port ${gateway_port}"
    cmd+=(--port "${gateway_port}")
  else
    log "Starting OpenClaw gateway with the upstream default port"
  fi

  cd "${OPENCLAW_DIR}"
  exec "${cmd[@]}"
}

main "$@"
