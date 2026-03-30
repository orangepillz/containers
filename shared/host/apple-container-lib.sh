#!/usr/bin/env bash

MIN_CONTAINER_VERSION="${MIN_CONTAINER_VERSION:-0.10.0}"
SUPPORTED_MACOS_MAJOR="${SUPPORTED_MACOS_MAJOR:-26}"
CONTAINER_EXEC_CMD=()

ac_log() {
  printf '[%s] %s\n' "${CONTAINER_LOG_PREFIX}" "$*"
}

ac_die() {
  printf '[%s] ERROR: %s\n' "${CONTAINER_LOG_PREFIX}" "$*" >&2
  exit 1
}

ac_host_macos_version() {
  sw_vers -productVersion 2>/dev/null || echo "unknown"
}

ac_version_component() {
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

ac_version_gte() {
  local left="$1"
  local right="$2"
  local left_major left_minor left_patch
  local right_major right_minor right_patch

  left_major="$(ac_version_component "${left}" 1)"
  left_minor="$(ac_version_component "${left}" 2)"
  left_patch="$(ac_version_component "${left}" 3)"
  right_major="$(ac_version_component "${right}" 1)"
  right_minor="$(ac_version_component "${right}" 2)"
  right_patch="$(ac_version_component "${right}" 3)"

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

ac_extract_container_version() {
  local raw

  raw="$(container --version 2>/dev/null || true)"
  if [[ "${raw}" =~ ([0-9]+\.[0-9]+\.[0-9]+) ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi

  printf '%s\n' ""
}

ac_preflight() {
  local arch macos_version macos_major container_version
  local -a issues=()

  arch="$(uname -m)"
  macos_version="$(ac_host_macos_version)"
  macos_major="$(ac_version_component "${macos_version}" 1)"

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
    container_version="$(ac_extract_container_version)"
    if [[ -z "${container_version}" ]]; then
      issues+=("Unable to parse \`container --version\`.")
    elif ! ac_version_gte "${container_version}" "${MIN_CONTAINER_VERSION}"; then
      issues+=("The installed \`container\` version is ${container_version}; need ${MIN_CONTAINER_VERSION} or newer.")
    fi
  fi

  if (( ${#issues[@]} > 0 )); then
    printf '[%s] Preflight failed:\n' "${CONTAINER_LOG_PREFIX}" >&2
    for issue in "${issues[@]}"; do
      printf '  - %s\n' "${issue}" >&2
    done
    return 1
  fi
}

ac_require_supported_ssh_mode() {
  case "${CONTAINER_SSH_MODE:-import}" in
    import|agent)
      ;;
    *)
      ac_die "SSH_MODE must be either 'import' or 'agent'; got '${CONTAINER_SSH_MODE}'."
      ;;
  esac
}

ac_ensure_container_system() {
  ac_log "Starting apple/container system services"
  container system start --enable-kernel-install
}

ac_configure_builder() {
  ac_ensure_container_system
  ac_log "Configuring builder resources (${CONTAINER_BUILDER_CPUS} CPUs, ${CONTAINER_BUILDER_MEMORY} RAM)"
  container builder stop >/dev/null 2>&1 || true
  container builder delete >/dev/null 2>&1 || true
  container builder start --cpus "${CONTAINER_BUILDER_CPUS}" --memory "${CONTAINER_BUILDER_MEMORY}"
}

ac_image_exists() {
  container image inspect "${CONTAINER_IMAGE}" >/dev/null 2>&1
}

ac_container_exists() {
  container inspect "${CONTAINER_NAME}" >/dev/null 2>&1
}

ac_container_running() {
  local inspect_output

  inspect_output="$(container inspect "${CONTAINER_NAME}" 2>/dev/null | tr -d '\n' || true)"
  [[ "${inspect_output}" =~ \"status\"[[:space:]]*:[[:space:]]*\"running\" ]]
}

ac_ensure_image_exists() {
  if ! ac_image_exists; then
    ac_die "Image '${CONTAINER_IMAGE}' does not exist yet. Run '$(basename "$0") build' first."
  fi
}

ac_build_container_exec_cmd() {
  local interactive="$1"
  local tty="$2"
  local env_name env_value

  CONTAINER_EXEC_CMD=(
    container exec
    --user "${CONTAINER_USER:-dev}"
    --workdir "${CONTAINER_WORKDIR:-/home/dev}"
  )

  if declare -p CONTAINER_EXEC_ENV_VARS >/dev/null 2>&1; then
    for env_name in "${CONTAINER_EXEC_ENV_VARS[@]}"; do
      env_value="${!env_name:-}"
      if [[ -n "${env_value}" ]]; then
        CONTAINER_EXEC_CMD+=(--env "${env_name}=${env_value}")
      fi
    done
  fi

  if [[ "${interactive}" == "true" ]]; then
    CONTAINER_EXEC_CMD+=(--interactive)
  fi

  if [[ "${tty}" == "true" ]]; then
    CONTAINER_EXEC_CMD+=(--tty)
  fi

  if [[ -n "${OPENAI_API_KEY:-}" ]]; then
    CONTAINER_EXEC_CMD+=(--env "OPENAI_API_KEY=${OPENAI_API_KEY}")
  fi
}

ac_ensure_container_exists() {
  if ! ac_container_exists; then
    ac_create_container
  fi
}

ac_wait_for_container_running() {
  local attempt

  for attempt in $(seq 1 30); do
    if ac_container_running; then
      return 0
    fi
    sleep 1
  done

  ac_die "Timed out waiting for '${CONTAINER_NAME}' to reach the running state."
}

ac_ensure_running() {
  ac_ensure_container_exists

  if ac_container_running; then
    return 0
  fi

  ac_ensure_container_system
  ac_log "Starting container '${CONTAINER_NAME}'"
  container start "${CONTAINER_NAME}" >/dev/null
  ac_wait_for_container_running
}

ac_create_named_volume() {
  local volume_name="$1"

  container volume create "${volume_name}" >/dev/null 2>&1 || true
}

ac_build_image() {
  local -a build_cmd
  local build_arg

  ac_preflight
  ac_configure_builder

  build_cmd=(
    container build
    --platform "${CONTAINER_BUILD_PLATFORM:-linux/arm64}"
  )

  if declare -p CONTAINER_BUILD_ARGS >/dev/null 2>&1; then
    for build_arg in "${CONTAINER_BUILD_ARGS[@]}"; do
      build_cmd+=(--build-arg "${build_arg}")
    done
  fi

  build_cmd+=(
    --file "${CONTAINER_DOCKERFILE_PATH}"
    --tag "${CONTAINER_IMAGE}"
    "${CONTAINER_BUILD_CONTEXT}"
  )

  ac_log "Building image '${CONTAINER_IMAGE}'"
  "${build_cmd[@]}"
}

ac_create_container() {
  local -a create_cmd

  ac_preflight
  ac_require_supported_ssh_mode
  ac_ensure_container_system
  ac_ensure_image_exists

  if ac_container_exists; then
    ac_log "Container '${CONTAINER_NAME}' already exists"
    return 0
  fi

  ac_log "Creating named volumes '${CONTAINER_HOME_VOLUME}' and '${CONTAINER_DOCKER_VOLUME}'"
  ac_create_named_volume "${CONTAINER_HOME_VOLUME}"
  ac_create_named_volume "${CONTAINER_DOCKER_VOLUME}"

  create_cmd=(
    container create
    --name "${CONTAINER_NAME}"
    --init
    --memory "${CONTAINER_MEMORY}"
    --cpus "${CONTAINER_CPUS}"
    --mount "type=volume,source=${CONTAINER_HOME_VOLUME},target=${CONTAINER_HOME_MOUNT:-/home/dev}"
    --mount "type=volume,source=${CONTAINER_DOCKER_VOLUME},target=${CONTAINER_DOCKER_MOUNT:-/var/lib/docker}"
  )

  if [[ "${CONTAINER_SSH_MODE:-import}" == "agent" ]]; then
    create_cmd+=(--ssh)
  fi

  if declare -p CONTAINER_EXTRA_CREATE_ARGS >/dev/null 2>&1; then
    create_cmd+=("${CONTAINER_EXTRA_CREATE_ARGS[@]}")
  fi

  create_cmd+=("${CONTAINER_IMAGE}")

  ac_log "Creating container '${CONTAINER_NAME}'"
  "${create_cmd[@]}"
}

ac_up_container() {
  ac_preflight
  ac_ensure_running
  ac_log "Container '${CONTAINER_NAME}' is running"
}

ac_shell_container() {
  local -a exec_cmd

  ac_preflight
  ac_ensure_running
  ac_build_container_exec_cmd true true

  exec_cmd=("${CONTAINER_EXEC_CMD[@]}")
  exec_cmd+=("${CONTAINER_NAME}" bash -l)
  "${exec_cmd[@]}"
}

ac_exec_guest_command() {
  local interactive="$1"
  local tty="$2"
  local -a exec_cmd

  shift 2

  ac_preflight
  ac_ensure_running
  ac_build_container_exec_cmd "${interactive}" "${tty}"

  exec_cmd=("${CONTAINER_EXEC_CMD[@]}")
  exec_cmd+=("${CONTAINER_NAME}" "$@")
  "${exec_cmd[@]}"
}

ac_stop_container() {
  ac_preflight
  ac_ensure_container_system

  if ! ac_container_exists; then
    ac_log "Container '${CONTAINER_NAME}' does not exist"
    return 0
  fi

  if ! ac_container_running; then
    ac_log "Container '${CONTAINER_NAME}' is already stopped"
    return 0
  fi

  ac_log "Stopping container '${CONTAINER_NAME}'"
  container stop "${CONTAINER_NAME}" >/dev/null
}

ac_destroy_container() {
  local purge="${1:-false}"

  ac_preflight
  ac_ensure_container_system

  if ac_container_exists; then
    if ac_container_running; then
      ac_log "Stopping container '${CONTAINER_NAME}'"
      container stop "${CONTAINER_NAME}" >/dev/null
    fi

    ac_log "Deleting container '${CONTAINER_NAME}'"
    container delete "${CONTAINER_NAME}" >/dev/null
  else
    ac_log "Container '${CONTAINER_NAME}' does not exist"
  fi

  if [[ "${purge}" == "true" ]]; then
    ac_log "Deleting named volumes '${CONTAINER_HOME_VOLUME}' and '${CONTAINER_DOCKER_VOLUME}'"
    container volume delete "${CONTAINER_HOME_VOLUME}" >/dev/null 2>&1 || true
    container volume delete "${CONTAINER_DOCKER_VOLUME}" >/dev/null 2>&1 || true
  fi
}

ac_status_container() {
  local status_var

  ac_preflight
  ac_ensure_container_system

  if declare -p CONTAINER_STATUS_VARS >/dev/null 2>&1; then
    for status_var in "${CONTAINER_STATUS_VARS[@]}"; do
      printf '%s=%s\n' "${status_var}" "${!status_var:-}"
    done
  fi

  if ! ac_container_exists; then
    ac_log "Container '${CONTAINER_NAME}' has not been created yet"
    return 0
  fi

  if ac_container_running; then
    ac_log "Container '${CONTAINER_NAME}' is running"
  else
    ac_log "Container '${CONTAINER_NAME}' exists but is stopped"
  fi

  container inspect "${CONTAINER_NAME}"
}
