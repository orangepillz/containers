#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

MIN_CONTAINER_VERSION="0.10.0"
SUPPORTED_MACOS_MAJOR=26

DEV_NAME="${DEV_NAME:-codex-dev}"
DEV_IMAGE="${DEV_IMAGE:-${DEV_NAME}:latest}"
DEV_MEMORY="${DEV_MEMORY:-8g}"
DEV_CPUS="${DEV_CPUS:-4}"
DEV_BUILDER_MEMORY="${DEV_BUILDER_MEMORY:-8g}"
DEV_BUILDER_CPUS="${DEV_BUILDER_CPUS:-4}"
DEV_HOME_VOLUME="${DEV_HOME_VOLUME:-${DEV_NAME}-home}"
DEV_DOCKER_VOLUME="${DEV_DOCKER_VOLUME:-${DEV_NAME}-docker}"
GO_VERSION="${GO_VERSION:-1.24.2}"
NODE_MAJOR="${NODE_MAJOR:-22}"
SSH_MODE="${SSH_MODE:-import}"
DOCKERFILE_PATH="${DOCKERFILE_PATH:-${ROOT_DIR}/Dockerfile}"

log() {
  printf '[dev-container] %s\n' "$*"
}

die() {
  printf '[dev-container] ERROR: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<EOF
Usage: $(basename "$0") <command> [args]

Commands:
  build                 Build the dev image with apple/container
  create                Create named volumes and the stopped dev container
  up                    Start the dev container, creating it if needed
  shell                 Open a login shell as the dev user
  stop                  Stop the dev container if it is running
  destroy [--purge]     Remove the dev container; keep volumes unless --purge is set
  status                Show compatibility checks and container status
  import-ssh-key <src> [dest-name]
                        Copy a private SSH key into /home/dev/.ssh inside the container
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
  GO_VERSION=${GO_VERSION}
  NODE_MAJOR=${NODE_MAJOR}
  SSH_MODE=${SSH_MODE}   (valid: import, agent)
EOF
}

host_macos_version() {
  sw_vers -productVersion 2>/dev/null || echo "unknown"
}

version_component() {
  local version="$1"
  local index="$2"
  local part
  local part1 part2 part3 _rest

  IFS='.' read -r part1 part2 part3 _rest <<EOF
${version}
EOF

  case "${index}" in
    1) part="${part1:-0}" ;;
    2) part="${part2:-0}" ;;
    3) part="${part3:-0}" ;;
    *) part="0" ;;
  esac

  part="${part%%[^0-9]*}"
  if [[ -z "${part}" ]]; then
    part="0"
  fi

  printf '%s\n' "${part}"
}

version_gte() {
  local left="$1"
  local right="$2"
  local left_major left_minor left_patch
  local right_major right_minor right_patch

  left_major="$(version_component "${left}" 1)"
  left_minor="$(version_component "${left}" 2)"
  left_patch="$(version_component "${left}" 3)"
  right_major="$(version_component "${right}" 1)"
  right_minor="$(version_component "${right}" 2)"
  right_patch="$(version_component "${right}" 3)"

  if (( left_major > right_major )); then
    return 0
  fi
  if (( left_major < right_major )); then
    return 1
  fi
  if (( left_minor > right_minor )); then
    return 0
  fi
  if (( left_minor < right_minor )); then
    return 1
  fi
  if (( left_patch >= right_patch )); then
    return 0
  fi
  return 1
}

extract_container_version() {
  local raw

  raw="$(container --version 2>/dev/null || true)"
  if [[ "${raw}" =~ ([0-9]+\.[0-9]+\.[0-9]+) ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi

  printf '%s\n' ""
}

preflight() {
  local arch macos_version macos_major container_version
  local issues=()

  arch="$(uname -m)"
  macos_version="$(host_macos_version)"
  macos_major="$(version_component "${macos_version}" 1)"

  if [[ "${arch}" != "arm64" ]]; then
    issues+=("Apple \`container\` requires Apple silicon; current architecture is ${arch}.")
  fi

  if [[ "${macos_major}" == "0" ]]; then
    issues+=("Unable to determine the macOS version for this host.")
  elif (( macos_major < SUPPORTED_MACOS_MAJOR )); then
    issues+=("Apple documents \`container\` support on macOS ${SUPPORTED_MACOS_MAJOR}+; this host reports macOS ${macos_version}.")
  fi

  if ! command -v container >/dev/null 2>&1; then
    issues+=("The \`container\` CLI is not installed or not on PATH.")
  else
    container_version="$(extract_container_version)"
    if [[ -z "${container_version}" ]]; then
      issues+=("Unable to parse \`container --version\`.")
    elif ! version_gte "${container_version}" "${MIN_CONTAINER_VERSION}"; then
      issues+=("The installed \`container\` version is ${container_version}; need ${MIN_CONTAINER_VERSION} or newer.")
    fi
  fi

  if (( ${#issues[@]} > 0 )); then
    printf '[dev-container] Preflight failed:\n' >&2
    for issue in "${issues[@]}"; do
      printf '  - %s\n' "${issue}" >&2
    done
    return 1
  fi
}

require_supported_ssh_mode() {
  case "${SSH_MODE}" in
    import|agent)
      ;;
    *)
      die "SSH_MODE must be either 'import' or 'agent'; got '${SSH_MODE}'."
      ;;
  esac
}

ensure_container_system() {
  log "Starting apple/container system services"
  container system start --enable-kernel-install
}

configure_builder() {
  ensure_container_system
  log "Configuring builder resources (${DEV_BUILDER_CPUS} CPUs, ${DEV_BUILDER_MEMORY} RAM)"
  container builder stop >/dev/null 2>&1 || true
  container builder delete >/dev/null 2>&1 || true
  container builder start --cpus "${DEV_BUILDER_CPUS}" --memory "${DEV_BUILDER_MEMORY}"
}

image_exists() {
  container image inspect "${DEV_IMAGE}" >/dev/null 2>&1
}

container_exists() {
  container inspect "${DEV_NAME}" >/dev/null 2>&1
}

container_running() {
  local inspect_output

  inspect_output="$(container inspect "${DEV_NAME}" 2>/dev/null | tr -d '\n' || true)"
  [[ "${inspect_output}" =~ \"status\"[[:space:]]*:[[:space:]]*\"running\" ]]
}

ensure_image_exists() {
  if ! image_exists; then
    die "Image '${DEV_IMAGE}' does not exist yet. Run '$(basename "$0") build' first."
  fi
}

ensure_container_exists() {
  if ! container_exists; then
    create_container
  fi
}

wait_for_container_running() {
  local attempt

  for attempt in $(seq 1 30); do
    if container_running; then
      return 0
    fi
    sleep 1
  done

  die "Timed out waiting for '${DEV_NAME}' to reach the running state."
}

ensure_running() {
  ensure_container_exists

  if container_running; then
    return 0
  fi

  ensure_container_system
  log "Starting container '${DEV_NAME}'"
  container start "${DEV_NAME}" >/dev/null
  wait_for_container_running
}

create_named_volume() {
  local volume_name="$1"

  container volume create "${volume_name}" >/dev/null 2>&1 || true
}

build_image() {
  preflight
  configure_builder

  log "Building image '${DEV_IMAGE}'"
  container build \
    --platform linux/arm64 \
    --build-arg "GO_VERSION=${GO_VERSION}" \
    --build-arg "NODE_MAJOR=${NODE_MAJOR}" \
    --file "${DOCKERFILE_PATH}" \
    --tag "${DEV_IMAGE}" \
    "${ROOT_DIR}"
}

create_container() {
  local create_cmd

  preflight
  require_supported_ssh_mode
  ensure_container_system
  ensure_image_exists

  if container_exists; then
    log "Container '${DEV_NAME}' already exists"
    return 0
  fi

  log "Creating named volumes '${DEV_HOME_VOLUME}' and '${DEV_DOCKER_VOLUME}'"
  create_named_volume "${DEV_HOME_VOLUME}"
  create_named_volume "${DEV_DOCKER_VOLUME}"

  create_cmd=(
    container create
    --name "${DEV_NAME}"
    --init
    --memory "${DEV_MEMORY}"
    --cpus "${DEV_CPUS}"
    --mount "type=volume,source=${DEV_HOME_VOLUME},target=/home/dev"
    --mount "type=volume,source=${DEV_DOCKER_VOLUME},target=/var/lib/docker"
  )

  if [[ "${SSH_MODE}" == "agent" ]]; then
    create_cmd+=(--ssh)
  fi

  create_cmd+=("${DEV_IMAGE}")

  log "Creating container '${DEV_NAME}'"
  "${create_cmd[@]}"
}

up_container() {
  preflight
  ensure_running
  log "Container '${DEV_NAME}' is running"
}

shell_container() {
  local exec_cmd

  preflight
  ensure_running

  exec_cmd=(
    container exec
    --interactive
    --tty
    --user dev
    --workdir /home/dev
  )

  if [[ -n "${OPENAI_API_KEY:-}" ]]; then
    exec_cmd+=(--env "OPENAI_API_KEY=${OPENAI_API_KEY}")
  fi

  exec_cmd+=("${DEV_NAME}" bash -l)

  "${exec_cmd[@]}"
}

stop_container() {
  preflight
  ensure_container_system

  if ! container_exists; then
    log "Container '${DEV_NAME}' does not exist"
    return 0
  fi

  if ! container_running; then
    log "Container '${DEV_NAME}' is already stopped"
    return 0
  fi

  log "Stopping container '${DEV_NAME}'"
  container stop "${DEV_NAME}" >/dev/null
}

destroy_container() {
  local purge="${1:-false}"

  preflight
  ensure_container_system

  if container_exists; then
    if container_running; then
      log "Stopping container '${DEV_NAME}'"
      container stop "${DEV_NAME}" >/dev/null
    fi

    log "Deleting container '${DEV_NAME}'"
    container delete "${DEV_NAME}" >/dev/null
  else
    log "Container '${DEV_NAME}' does not exist"
  fi

  if [[ "${purge}" == "true" ]]; then
    log "Deleting named volumes '${DEV_HOME_VOLUME}' and '${DEV_DOCKER_VOLUME}'"
    container volume delete "${DEV_HOME_VOLUME}" >/dev/null 2>&1 || true
    container volume delete "${DEV_DOCKER_VOLUME}" >/dev/null 2>&1 || true
  fi
}

import_ssh_key() {
  local source_path="$1"
  local dest_name="${2:-$(basename "$1")}"
  local public_key="${source_path}.pub"
  local target_path
  local public_target_path

  preflight

  if [[ ! -f "${source_path}" ]]; then
    die "SSH key '${source_path}' does not exist."
  fi

  if [[ "${dest_name}" == *"/"* ]]; then
    die "Destination key name must be a basename, not a path."
  fi

  if [[ ! "${dest_name}" =~ ^[A-Za-z0-9._-]+$ ]]; then
    die "Destination key name '${dest_name}' may only contain letters, numbers, dots, underscores, and hyphens."
  fi

  target_path="/home/dev/.ssh/${dest_name}"
  public_target_path="${target_path}.pub"

  ensure_running

  log "Creating /home/dev/.ssh with strict permissions"
  container exec --user root "${DEV_NAME}" install -d -m 700 -o dev -g dev -- /home/dev/.ssh

  log "Copying private key to ${target_path}"
  container exec --interactive --user root "${DEV_NAME}" /bin/sh -c 'cat > "$1"' sh "${target_path}" < "${source_path}"
  container exec --user root "${DEV_NAME}" chown dev:dev -- "${target_path}"
  container exec --user root "${DEV_NAME}" chmod 600 -- "${target_path}"

  if [[ -f "${public_key}" ]]; then
    log "Copying public key to ${public_target_path}"
    container exec --interactive --user root "${DEV_NAME}" /bin/sh -c 'cat > "$1"' sh "${public_target_path}" < "${public_key}"
    container exec --user root "${DEV_NAME}" chown dev:dev -- "${public_target_path}"
    container exec --user root "${DEV_NAME}" chmod 644 -- "${public_target_path}"
  fi
}

status_container() {
  preflight
  ensure_container_system

  printf 'DEV_NAME=%s\n' "${DEV_NAME}"
  printf 'DEV_IMAGE=%s\n' "${DEV_IMAGE}"
  printf 'DEV_MEMORY=%s\n' "${DEV_MEMORY}"
  printf 'DEV_CPUS=%s\n' "${DEV_CPUS}"
  printf 'DEV_HOME_VOLUME=%s\n' "${DEV_HOME_VOLUME}"
  printf 'DEV_DOCKER_VOLUME=%s\n' "${DEV_DOCKER_VOLUME}"
  printf 'SSH_MODE=%s\n' "${SSH_MODE}"

  if ! container_exists; then
    log "Container '${DEV_NAME}' has not been created yet"
    return 0
  fi

  if container_running; then
    log "Container '${DEV_NAME}' is running"
  else
    log "Container '${DEV_NAME}' exists but is stopped"
  fi

  container inspect "${DEV_NAME}"
}

main() {
  local command="${1:-help}"

  case "${command}" in
    build)
      shift
      build_image "$@"
      ;;
    create)
      shift
      create_container "$@"
      ;;
    up)
      shift
      up_container "$@"
      ;;
    shell)
      shift
      shell_container "$@"
      ;;
    stop)
      shift
      stop_container "$@"
      ;;
    destroy)
      shift
      if [[ "${1:-}" == "--purge" ]]; then
        destroy_container true
      elif [[ $# -eq 0 ]]; then
        destroy_container false
      else
        die "Unsupported argument for destroy: '$1'"
      fi
      ;;
    status)
      shift
      status_container "$@"
      ;;
    import-ssh-key)
      shift
      if [[ $# -lt 1 || $# -gt 2 ]]; then
        die "Usage: $(basename "$0") import-ssh-key <src> [dest-name]"
      fi
      import_ssh_key "$@"
      ;;
    help|-h|--help)
      usage
      ;;
    *)
      die "Unknown command '${command}'. Run '$(basename "$0") help' for usage."
      ;;
  esac
}

main "$@"
