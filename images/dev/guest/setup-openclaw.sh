#!/usr/bin/env bash

set -euo pipefail

OPENCLAW_DIR="${OPENCLAW_DIR:-/home/dev/openclaw}"
OPENCLAW_UPSTREAM_URL="${OPENCLAW_UPSTREAM_URL:-https://github.com/openclaw/openclaw.git}"
OPENCLAW_REF="${OPENCLAW_REF:-main}"

log() {
  printf '[setup-openclaw] %s\n' "$*"
}

die() {
  printf '[setup-openclaw] ERROR: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: setup-openclaw

Clone or update openclaw/openclaw in the guest, then run:
  pnpm install
  pnpm ui:build
  pnpm build
EOF
}

ensure_dependencies() {
  command -v git >/dev/null 2>&1 || die "git is required but was not found in PATH."
  command -v node >/dev/null 2>&1 || die "node is required but was not found in PATH."
  command -v pnpm >/dev/null 2>&1 || die "pnpm is required but was not found in PATH."
}

checkout_is_dirty() {
  [[ -n "$(git -C "${OPENCLAW_DIR}" status --porcelain --untracked-files=normal 2>/dev/null)" ]]
}

clone_or_update_openclaw() {
  if [[ -d "${OPENCLAW_DIR}/.git" ]]; then
    if checkout_is_dirty; then
      log "Local changes detected in ${OPENCLAW_DIR}; skipping pull and using the existing checkout."
      return 0
    fi

    log "Updating ${OPENCLAW_DIR} to ${OPENCLAW_REF}"
    git -C "${OPENCLAW_DIR}" fetch --tags origin

    if git -C "${OPENCLAW_DIR}" show-ref --verify --quiet "refs/remotes/origin/${OPENCLAW_REF}"; then
      if git -C "${OPENCLAW_DIR}" show-ref --verify --quiet "refs/heads/${OPENCLAW_REF}"; then
        git -C "${OPENCLAW_DIR}" checkout "${OPENCLAW_REF}" >/dev/null 2>&1
      else
        git -C "${OPENCLAW_DIR}" checkout -B "${OPENCLAW_REF}" "origin/${OPENCLAW_REF}" >/dev/null 2>&1
      fi
      git -C "${OPENCLAW_DIR}" pull --ff-only origin "${OPENCLAW_REF}"
    else
      git -C "${OPENCLAW_DIR}" checkout "${OPENCLAW_REF}" >/dev/null 2>&1
    fi
    return 0
  fi

  if [[ -e "${OPENCLAW_DIR}" ]]; then
    die "${OPENCLAW_DIR} exists but is not a git checkout."
  fi

  log "Cloning ${OPENCLAW_UPSTREAM_URL} into ${OPENCLAW_DIR}"
  git clone --branch "${OPENCLAW_REF}" --single-branch "${OPENCLAW_UPSTREAM_URL}" "${OPENCLAW_DIR}"
}

build_openclaw() {
  [[ -d "${OPENCLAW_DIR}" ]] || die "Expected ${OPENCLAW_DIR} to exist after cloning OpenClaw."

  (
    cd "${OPENCLAW_DIR}"
    pnpm install
    pnpm ui:build
    pnpm build
  )
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

  ensure_dependencies
  clone_or_update_openclaw
  build_openclaw

  log "OpenClaw is ready in ${OPENCLAW_DIR}."
}

main "$@"
