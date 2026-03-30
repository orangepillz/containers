#!/usr/bin/env bash

set -euo pipefail

SYMPHONY_DIR="${SYMPHONY_DIR:-/home/dev/symphony}"
SYMPHONY_CONFIG_DIR="${SYMPHONY_CONFIG_DIR:-/home/dev/.config/symphony}"
SYMPHONY_ENV_PATH="${SYMPHONY_CONFIG_DIR}/env"
SYMPHONY_WORKFLOW_PATH="${SYMPHONY_CONFIG_DIR}/WORKFLOW.md"
SYMPHONY_BIN_PATH="${SYMPHONY_DIR}/elixir/bin/symphony"
ACKNOWLEDGEMENT_FLAG="--i-understand-that-this-will-be-running-without-the-usual-guardrails"

log() {
  printf '[run-symphony] %s\n' "$*"
}

die() {
  printf '[run-symphony] ERROR: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: run-symphony [--port <port>]

Launch the Symphony Elixir reference implementation using the guest-local
config written by setup-symphony.
EOF
}

main() {
  local dashboard_port=""
  local cmd=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --port)
        [[ $# -ge 2 ]] || die "--port requires a value."
        dashboard_port="$2"
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

  if [[ -n "${dashboard_port}" && ! "${dashboard_port}" =~ ^[0-9]+$ ]]; then
    die "Dashboard port must be an integer."
  fi

  [[ -f "${SYMPHONY_ENV_PATH}" ]] || die "Symphony is not configured yet. Run setup-symphony first."
  [[ -f "${SYMPHONY_WORKFLOW_PATH}" ]] || die "Missing workflow file at ${SYMPHONY_WORKFLOW_PATH}. Run setup-symphony first."
  [[ -x "${SYMPHONY_BIN_PATH}" ]] || die "Missing Symphony binary at ${SYMPHONY_BIN_PATH}. Run setup-symphony first."

  set -a
  # shellcheck disable=SC1090
  . "${SYMPHONY_ENV_PATH}"
  set +a

  SYMPHONY_WORKFLOW_PATH="${SYMPHONY_CONFIG_DIR}/WORKFLOW.md"
  SYMPHONY_BIN_PATH="${SYMPHONY_DIR}/elixir/bin/symphony"

  [[ -n "${LINEAR_API_KEY:-}" ]] || die "LINEAR_API_KEY is missing from ${SYMPHONY_ENV_PATH}. Re-run setup-symphony."
  [[ -f "${SYMPHONY_WORKFLOW_PATH}" ]] || die "Missing workflow file at ${SYMPHONY_WORKFLOW_PATH}. Run setup-symphony first."
  [[ -x "${SYMPHONY_BIN_PATH}" ]] || die "Missing Symphony binary at ${SYMPHONY_BIN_PATH}. Run setup-symphony first."

  cmd=("${SYMPHONY_BIN_PATH}" "${ACKNOWLEDGEMENT_FLAG}")
  if [[ -n "${dashboard_port}" ]]; then
    log "Starting Symphony with dashboard port ${dashboard_port}"
    cmd+=(--port "${dashboard_port}")
  else
    log "Starting Symphony without the optional dashboard port"
  fi
  cmd+=("${SYMPHONY_WORKFLOW_PATH}")

  cd "${SYMPHONY_DIR}/elixir"
  exec "${cmd[@]}"
}

main "$@"
