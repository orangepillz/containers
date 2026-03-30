#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

MIN_CONTAINER_VERSION="0.10.0"
SUPPORTED_MACOS_MAJOR=26

DEV_NAME="${DEV_NAME:-dev}"
DEV_IMAGE="${DEV_IMAGE:-dev:latest}"
DEV_MEMORY="${DEV_MEMORY:-8g}"
DEV_CPUS="${DEV_CPUS:-4}"
DEV_BUILDER_MEMORY="${DEV_BUILDER_MEMORY:-8g}"
DEV_BUILDER_CPUS="${DEV_BUILDER_CPUS:-4}"
DEV_HOME_VOLUME="${DEV_HOME_VOLUME:-${DEV_NAME}-home}"
DEV_DOCKER_VOLUME="${DEV_DOCKER_VOLUME:-${DEV_NAME}-docker}"
DEV_HOME_VOLUME_SIZE="${DEV_HOME_VOLUME_SIZE:-}"
DEV_DOCKER_VOLUME_SIZE="${DEV_DOCKER_VOLUME_SIZE:-}"
GO_VERSION="${GO_VERSION:-1.24.2}"
NODE_MAJOR="${NODE_MAJOR:-22}"
MISE_VERSION="${MISE_VERSION:-v2025.11.11}"
ERLANG_VERSION="${ERLANG_VERSION:-28}"
ELIXIR_VERSION="${ELIXIR_VERSION:-1.19.5-otp-28}"
SSH_MODE="${SSH_MODE:-import}"
SYMPHONY_DIR="${SYMPHONY_DIR:-/home/dev/symphony}"
SYMPHONY_CONFIG_DIR="${SYMPHONY_CONFIG_DIR:-/home/dev/.config/symphony}"
SYMPHONY_WORKSPACE_ROOT="${SYMPHONY_WORKSPACE_ROOT:-/home/dev/code/symphony-workspaces}"
GIT_SSH_HOST="${GIT_SSH_HOST:-github.com}"
CODEX_APP_SERVER_COMMAND="${CODEX_APP_SERVER_COMMAND:-codex --config shell_environment_policy.inherit=all --config model_reasoning_effort=xhigh --model gpt-5.3-codex app-server}"
DOCKERFILE_PATH="${DOCKERFILE_PATH:-${SCRIPT_DIR}/Dockerfile}"

CONTAINER_LOG_PREFIX="dev-container"
CONTAINER_NAME="${DEV_NAME}"
CONTAINER_IMAGE="${DEV_IMAGE}"
CONTAINER_MEMORY="${DEV_MEMORY}"
CONTAINER_CPUS="${DEV_CPUS}"
CONTAINER_BUILDER_MEMORY="${DEV_BUILDER_MEMORY}"
CONTAINER_BUILDER_CPUS="${DEV_BUILDER_CPUS}"
CONTAINER_HOME_VOLUME="${DEV_HOME_VOLUME}"
CONTAINER_DOCKER_VOLUME="${DEV_DOCKER_VOLUME}"
CONTAINER_HOME_VOLUME_SIZE="${DEV_HOME_VOLUME_SIZE}"
CONTAINER_DOCKER_VOLUME_SIZE="${DEV_DOCKER_VOLUME_SIZE}"
CONTAINER_DOCKERFILE_PATH="${DOCKERFILE_PATH}"
CONTAINER_BUILD_CONTEXT="${ROOT_DIR}"
CONTAINER_SSH_MODE="${SSH_MODE}"
CONTAINER_BUILD_ARGS=(
  "GO_VERSION=${GO_VERSION}"
  "NODE_MAJOR=${NODE_MAJOR}"
  "MISE_VERSION=${MISE_VERSION}"
  "ERLANG_VERSION=${ERLANG_VERSION}"
  "ELIXIR_VERSION=${ELIXIR_VERSION}"
)
CONTAINER_EXEC_ENV_VARS=(
  ERLANG_VERSION
  ELIXIR_VERSION
  MISE_VERSION
  SYMPHONY_DIR
  SYMPHONY_CONFIG_DIR
  SYMPHONY_WORKSPACE_ROOT
  GIT_SSH_HOST
  CODEX_APP_SERVER_COMMAND
)
CONTAINER_STATUS_VARS=(
  DEV_NAME
  DEV_IMAGE
  DEV_MEMORY
  DEV_CPUS
  DEV_BUILDER_MEMORY
  DEV_BUILDER_CPUS
  DEV_HOME_VOLUME
  DEV_DOCKER_VOLUME
  DEV_HOME_VOLUME_SIZE
  DEV_DOCKER_VOLUME_SIZE
  GO_VERSION
  NODE_MAJOR
  MISE_VERSION
  ERLANG_VERSION
  ELIXIR_VERSION
  SSH_MODE
  SYMPHONY_DIR
  SYMPHONY_CONFIG_DIR
  SYMPHONY_WORKSPACE_ROOT
  GIT_SSH_HOST
)

source "${ROOT_DIR}/shared/host/apple-container-lib.sh"

usage() {
  cat <<EOF
Usage: $(basename "$0") <command> [args]

Commands:
  build                 Build the dev image with apple/container
  create                Create named volumes and the stopped dev container
  up                    Start the dev container, creating it if needed
  shell                 Open a login shell as the dev user
  setup-git-ssh [--force|--replace]
                        Guided Git SSH bootstrap inside the guest
  setup-symphony        Clone/update Symphony and write guest-local config
  run-symphony [--port <port>]
                        Launch Symphony with the generated workflow
  stop                  Stop the dev container if it is running
  destroy [--purge]     Remove the dev container; keep volumes unless --purge is set
  status                Show compatibility checks and container status
  help                  Show this help message

Environment:
  DEV_NAME=${DEV_NAME}
  DEV_IMAGE=${DEV_IMAGE}
  DEV_MEMORY=${DEV_MEMORY}
  DEV_CPUS=${DEV_CPUS}
  DEV_BUILDER_MEMORY=${DEV_BUILDER_MEMORY}
  DEV_BUILDER_CPUS=${DEV_BUILDER_CPUS}
  DEV_HOME_VOLUME=${DEV_HOME_VOLUME}
  DEV_DOCKER_VOLUME=${DEV_DOCKER_VOLUME}
  DEV_HOME_VOLUME_SIZE=${DEV_HOME_VOLUME_SIZE:-auto}
  DEV_DOCKER_VOLUME_SIZE=${DEV_DOCKER_VOLUME_SIZE:-auto}
  GO_VERSION=${GO_VERSION}
  NODE_MAJOR=${NODE_MAJOR}
  MISE_VERSION=${MISE_VERSION}
  ERLANG_VERSION=${ERLANG_VERSION}
  ELIXIR_VERSION=${ELIXIR_VERSION}
  SSH_MODE=${SSH_MODE}   (valid: import, agent)
  SYMPHONY_DIR=${SYMPHONY_DIR}
  SYMPHONY_CONFIG_DIR=${SYMPHONY_CONFIG_DIR}
  SYMPHONY_WORKSPACE_ROOT=${SYMPHONY_WORKSPACE_ROOT}
  GIT_SSH_HOST=${GIT_SSH_HOST}

Examples:
  ./images/dev/container.sh up
  DEV_NAME=dev-a ./images/dev/container.sh up
  DEV_NAME=dev-b DEV_MEMORY=12g DEV_CPUS=6 DEV_HOME_VOLUME_SIZE=50G DEV_DOCKER_VOLUME_SIZE=150G ./images/dev/container.sh up
  DEV_NAME=dev-b ./images/dev/container.sh destroy --purge
EOF
}

setup_git_ssh() {
  ac_exec_guest_command true true setup-git-ssh "$@"
}

setup_symphony() {
  ac_exec_guest_command true true setup-symphony "$@"
}

run_symphony() {
  ac_exec_guest_command true true run-symphony "$@"
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
    setup-symphony)
      shift
      setup_symphony "$@"
      ;;
    run-symphony)
      shift
      run_symphony "$@"
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
