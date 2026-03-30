#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

MIN_CONTAINER_VERSION="0.10.0"
SUPPORTED_MACOS_MAJOR=26

OPENCLAW_NAME="${OPENCLAW_NAME:-openclaw-dev}"
OPENCLAW_IMAGE="${OPENCLAW_IMAGE:-${OPENCLAW_NAME}:latest}"
OPENCLAW_MEMORY="${OPENCLAW_MEMORY:-8g}"
OPENCLAW_CPUS="${OPENCLAW_CPUS:-4}"
OPENCLAW_BUILDER_MEMORY="${OPENCLAW_BUILDER_MEMORY:-8g}"
OPENCLAW_BUILDER_CPUS="${OPENCLAW_BUILDER_CPUS:-4}"
OPENCLAW_HOME_VOLUME="${OPENCLAW_HOME_VOLUME:-${OPENCLAW_NAME}-home}"
OPENCLAW_DOCKER_VOLUME="${OPENCLAW_DOCKER_VOLUME:-${OPENCLAW_NAME}-docker}"
OPENCLAW_NODE_MAJOR="${OPENCLAW_NODE_MAJOR:-24}"
OPENCLAW_DIR="${OPENCLAW_DIR:-/home/dev/openclaw}"
OPENCLAW_UPSTREAM_URL="${OPENCLAW_UPSTREAM_URL:-https://github.com/openclaw/openclaw.git}"
OPENCLAW_REF="${OPENCLAW_REF:-main}"
GIT_SSH_HOST="${GIT_SSH_HOST:-github.com}"
SSH_MODE="${SSH_MODE:-import}"
DOCKERFILE_PATH="${DOCKERFILE_PATH:-${SCRIPT_DIR}/Dockerfile}"

CONTAINER_LOG_PREFIX="openclaw-container"
CONTAINER_NAME="${OPENCLAW_NAME}"
CONTAINER_IMAGE="${OPENCLAW_IMAGE}"
CONTAINER_MEMORY="${OPENCLAW_MEMORY}"
CONTAINER_CPUS="${OPENCLAW_CPUS}"
CONTAINER_BUILDER_MEMORY="${OPENCLAW_BUILDER_MEMORY}"
CONTAINER_BUILDER_CPUS="${OPENCLAW_BUILDER_CPUS}"
CONTAINER_HOME_VOLUME="${OPENCLAW_HOME_VOLUME}"
CONTAINER_DOCKER_VOLUME="${OPENCLAW_DOCKER_VOLUME}"
CONTAINER_DOCKERFILE_PATH="${DOCKERFILE_PATH}"
CONTAINER_BUILD_CONTEXT="${ROOT_DIR}"
CONTAINER_SSH_MODE="${SSH_MODE}"
CONTAINER_BUILD_ARGS=(
  "NODE_MAJOR=${OPENCLAW_NODE_MAJOR}"
)
CONTAINER_EXEC_ENV_VARS=(
  OPENCLAW_DIR
  OPENCLAW_UPSTREAM_URL
  OPENCLAW_REF
  GIT_SSH_HOST
)
CONTAINER_STATUS_VARS=(
  OPENCLAW_NAME
  OPENCLAW_IMAGE
  OPENCLAW_MEMORY
  OPENCLAW_CPUS
  OPENCLAW_BUILDER_MEMORY
  OPENCLAW_BUILDER_CPUS
  OPENCLAW_HOME_VOLUME
  OPENCLAW_DOCKER_VOLUME
  OPENCLAW_NODE_MAJOR
  OPENCLAW_DIR
  OPENCLAW_UPSTREAM_URL
  OPENCLAW_REF
  GIT_SSH_HOST
  SSH_MODE
)

source "${ROOT_DIR}/shared/host/apple-container-lib.sh"

usage() {
  cat <<EOF
Usage: $(basename "$0") <command> [args]

Commands:
  build                   Build the OpenClaw image with apple/container
  create                  Create named volumes and the stopped OpenClaw container
  up                      Start the OpenClaw container, creating it if needed
  shell                   Open a login shell as the dev user
  setup-git-ssh [--force|--replace]
                          Guided Git SSH bootstrap inside the guest
  setup-openclaw          Clone/update OpenClaw from source and build it with pnpm
  onboard-openclaw        Run interactive OpenClaw onboarding without daemon install
  run-openclaw [--port <port>]
                          Launch the OpenClaw gateway in the foreground
  stop                    Stop the OpenClaw container if it is running
  destroy [--purge]       Remove the OpenClaw container; keep volumes unless --purge is set
  status                  Show compatibility checks and container status
  help                    Show this help message

Environment:
  OPENCLAW_NAME=${OPENCLAW_NAME}
  OPENCLAW_IMAGE=${OPENCLAW_IMAGE}
  OPENCLAW_HOME_VOLUME=${OPENCLAW_HOME_VOLUME}
  OPENCLAW_DOCKER_VOLUME=${OPENCLAW_DOCKER_VOLUME}
  OPENCLAW_NODE_MAJOR=${OPENCLAW_NODE_MAJOR}
  OPENCLAW_DIR=${OPENCLAW_DIR}
  OPENCLAW_UPSTREAM_URL=${OPENCLAW_UPSTREAM_URL}
  OPENCLAW_REF=${OPENCLAW_REF}
EOF
}

setup_git_ssh() {
  ac_exec_guest_command true true setup-git-ssh "$@"
}

setup_openclaw() {
  ac_exec_guest_command true true setup-openclaw "$@"
}

onboard_openclaw() {
  ac_exec_guest_command true true onboard-openclaw "$@"
}

run_openclaw() {
  ac_exec_guest_command true true run-openclaw "$@"
}

main() {
  local command="${1:-help}"

  case "${command}" in
    build)
      shift
      [[ $# -eq 0 ]] || ac_die "Usage: $(basename "$0") build"
      ac_build_image
      ;;
    create)
      shift
      [[ $# -eq 0 ]] || ac_die "Usage: $(basename "$0") create"
      ac_create_container
      ;;
    up)
      shift
      [[ $# -eq 0 ]] || ac_die "Usage: $(basename "$0") up"
      ac_up_container
      ;;
    shell)
      shift
      [[ $# -eq 0 ]] || ac_die "Usage: $(basename "$0") shell"
      ac_shell_container
      ;;
    setup-git-ssh)
      shift
      setup_git_ssh "$@"
      ;;
    setup-openclaw)
      shift
      setup_openclaw "$@"
      ;;
    onboard-openclaw)
      shift
      onboard_openclaw "$@"
      ;;
    run-openclaw)
      shift
      run_openclaw "$@"
      ;;
    stop)
      shift
      [[ $# -eq 0 ]] || ac_die "Usage: $(basename "$0") stop"
      ac_stop_container
      ;;
    destroy)
      shift
      if [[ "${1:-}" == "--purge" ]]; then
        [[ $# -eq 1 ]] || ac_die "Usage: $(basename "$0") destroy [--purge]"
        ac_destroy_container true
      elif [[ $# -eq 0 ]]; then
        ac_destroy_container false
      else
        ac_die "Usage: $(basename "$0") destroy [--purge]"
      fi
      ;;
    status)
      shift
      [[ $# -eq 0 ]] || ac_die "Usage: $(basename "$0") status"
      ac_status_container
      ;;
    help|-h|--help)
      usage
      ;;
    *)
      ac_die "Unknown command '${command}'. Run '$(basename "$0") help' for usage."
      ;;
  esac
}

main "$@"
