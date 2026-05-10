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
NODE_MAJOR="${NODE_MAJOR:-24}"
SWIFT_VERSION="${SWIFT_VERSION:-6.3.1}"
MISE_VERSION="${MISE_VERSION:-v2025.11.11}"
ERLANG_VERSION="${ERLANG_VERSION:-28}"
ELIXIR_VERSION="${ELIXIR_VERSION:-1.19.5-otp-28}"
SSH_MODE="${SSH_MODE:-import}"
SYMPHONY_DIR="${SYMPHONY_DIR:-/home/dev/symphony}"
SYMPHONY_CONFIG_DIR="${SYMPHONY_CONFIG_DIR:-/home/dev/.config/symphony}"
SYMPHONY_WORKSPACE_ROOT="${SYMPHONY_WORKSPACE_ROOT:-/home/dev/code/symphony-workspaces}"
OPENCLAW_DIR="${OPENCLAW_DIR:-/home/dev/openclaw}"
OPENCLAW_UPSTREAM_URL="${OPENCLAW_UPSTREAM_URL:-https://github.com/openclaw/openclaw.git}"
OPENCLAW_REF="${OPENCLAW_REF:-main}"
GIT_SSH_HOST="${GIT_SSH_HOST:-github.com}"
CODEX_APP_SERVER_COMMAND="${CODEX_APP_SERVER_COMMAND:-codex --config shell_environment_policy.inherit=all --config model_reasoning_effort=xhigh --model gpt-5.3-codex app-server}"
DOCKERFILE_PATH="${DOCKERFILE_PATH:-${SCRIPT_DIR}/Dockerfile}"
DEV_HOST_CONFIG_ENABLED="${DEV_HOST_CONFIG_ENABLED:-1}"
DEV_HOST_CONFIG_DIR="${DEV_HOST_CONFIG_DIR:-${HOME}/.dev-container/${DEV_NAME}/host-config}"
DEV_HOST_CONFIG_MOUNT="${DEV_HOST_CONFIG_MOUNT:-/host-config}"
DEV_HOST_ZSHRC_ENABLED="${DEV_HOST_ZSHRC_ENABLED:-1}"
DEV_HOST_ZSHRC_SOURCE="${DEV_HOST_ZSHRC_SOURCE:-${HOME}/.zshrc}"
DEV_CODEX_SKILLS_ENABLED="${DEV_CODEX_SKILLS_ENABLED:-1}"
DEV_CODEX_SKILLS_SOURCE="${DEV_CODEX_SKILLS_SOURCE:-${HOME}/.codex/skills}"
DEV_CODEX_SKILLS_TARGET="${DEV_CODEX_SKILLS_TARGET:-/home/dev/.codex/skills}"
DEV_CODEX_SKILLS_DELETE_STALE="${DEV_CODEX_SKILLS_DELETE_STALE:-0}"
XCODE_BRIDGE_ENABLED="${XCODE_BRIDGE_ENABLED:-1}"
XCODE_BRIDGE_HOST_DIR="${XCODE_BRIDGE_HOST_DIR:-${HOME}/.dev-container/${DEV_NAME}/xcode-bridge}"
XCODE_BRIDGE_MOUNT="${XCODE_BRIDGE_MOUNT:-/xcode-bridge}"
XCODE_BRIDGE_HOSTNAME="${XCODE_BRIDGE_HOSTNAME:-host.container.internal}"
XCODE_BRIDGE_LOCALHOST_IP="${XCODE_BRIDGE_LOCALHOST_IP:-203.0.113.113}"
XCODE_BRIDGE_BIND="${XCODE_BRIDGE_BIND:-127.0.0.1}"
XCODE_BRIDGE_PORT="${XCODE_BRIDGE_PORT:-8378}"
XCODE_BRIDGE_SERVER="${XCODE_BRIDGE_SERVER:-${ROOT_DIR}/shared/host/xcode-bridge-server.py}"
XCODE_BRIDGE_URL="${XCODE_BRIDGE_URL:-http://${XCODE_BRIDGE_HOSTNAME}:${XCODE_BRIDGE_PORT}}"
XCODE_BRIDGE_TOKEN_FILE="${XCODE_BRIDGE_TOKEN_FILE:-${XCODE_BRIDGE_MOUNT}/token}"

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
  "SWIFT_VERSION=${SWIFT_VERSION}"
  "MISE_VERSION=${MISE_VERSION}"
  "ERLANG_VERSION=${ERLANG_VERSION}"
  "ELIXIR_VERSION=${ELIXIR_VERSION}"
)
CONTAINER_EXTRA_CREATE_ARGS=()
if [[ "${DEV_HOST_CONFIG_ENABLED}" == "1" || "${DEV_HOST_CONFIG_ENABLED}" == "true" || "${DEV_HOST_CONFIG_ENABLED}" == "yes" ]]; then
  CONTAINER_EXTRA_CREATE_ARGS+=(
    --env "DEV_HOST_CONFIG_MOUNT=${DEV_HOST_CONFIG_MOUNT}"
    --env "DEV_CODEX_SKILLS_TARGET=${DEV_CODEX_SKILLS_TARGET}"
    --env "DEV_CODEX_SKILLS_DELETE_STALE=${DEV_CODEX_SKILLS_DELETE_STALE}"
    --volume "${DEV_HOST_CONFIG_DIR}:${DEV_HOST_CONFIG_MOUNT}"
  )
fi
if [[ "${XCODE_BRIDGE_ENABLED}" == "1" || "${XCODE_BRIDGE_ENABLED}" == "true" || "${XCODE_BRIDGE_ENABLED}" == "yes" ]]; then
  CONTAINER_EXTRA_CREATE_ARGS+=(
    --volume "${XCODE_BRIDGE_HOST_DIR}:${XCODE_BRIDGE_MOUNT}"
  )
fi
CONTAINER_SHELL_CMD=(
  bash
  -lc
  'if command -v zsh >/dev/null 2>&1; then exec zsh -l; else exec bash -l; fi'
)
CONTAINER_EXEC_ENV_VARS=(
  ERLANG_VERSION
  ELIXIR_VERSION
  MISE_VERSION
  SYMPHONY_DIR
  SYMPHONY_CONFIG_DIR
  SYMPHONY_WORKSPACE_ROOT
  OPENCLAW_DIR
  OPENCLAW_UPSTREAM_URL
  OPENCLAW_REF
  GIT_SSH_HOST
  CODEX_APP_SERVER_COMMAND
  DEV_HOST_CONFIG_MOUNT
  DEV_CODEX_SKILLS_TARGET
  DEV_CODEX_SKILLS_DELETE_STALE
  XCODE_BRIDGE_MOUNT
  XCODE_BRIDGE_URL
  XCODE_BRIDGE_TOKEN_FILE
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
  SWIFT_VERSION
  MISE_VERSION
  ERLANG_VERSION
  ELIXIR_VERSION
  SSH_MODE
  SYMPHONY_DIR
  SYMPHONY_CONFIG_DIR
  SYMPHONY_WORKSPACE_ROOT
  OPENCLAW_DIR
  OPENCLAW_UPSTREAM_URL
  OPENCLAW_REF
  GIT_SSH_HOST
  DEV_HOST_CONFIG_ENABLED
  DEV_HOST_CONFIG_DIR
  DEV_HOST_CONFIG_MOUNT
  DEV_HOST_ZSHRC_ENABLED
  DEV_HOST_ZSHRC_SOURCE
  DEV_CODEX_SKILLS_ENABLED
  DEV_CODEX_SKILLS_SOURCE
  DEV_CODEX_SKILLS_TARGET
  DEV_CODEX_SKILLS_DELETE_STALE
  XCODE_BRIDGE_ENABLED
  XCODE_BRIDGE_HOST_DIR
  XCODE_BRIDGE_MOUNT
  XCODE_BRIDGE_HOSTNAME
  XCODE_BRIDGE_LOCALHOST_IP
  XCODE_BRIDGE_BIND
  XCODE_BRIDGE_PORT
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
  setup-openclaw        Clone/update OpenClaw from source and build it with pnpm
  onboard-openclaw      Run interactive OpenClaw onboarding without daemon install
  run-openclaw [--port <port>]
                        Launch the OpenClaw gateway in the foreground
  xcode-status          Show host Xcode/Command Line Tools status
  xcodebuild [args...]  Run host xcodebuild with the provided arguments
  xcrun [args...]       Run host xcrun with the provided arguments
  simctl [args...]      Run host xcrun simctl with the provided arguments
  xcode-bridge-dns      Configure Apple container DNS for host loopback access
  xcode-bridge-start    Start the host Xcode bridge sidecar
  xcode-bridge-stop     Stop the host Xcode bridge sidecar
  xcode-bridge-status   Show host Xcode bridge sidecar status
  xcode-bridge [args...]
                        Run the guest xcode-bridge CLI inside the container
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
  SWIFT_VERSION=${SWIFT_VERSION}
  MISE_VERSION=${MISE_VERSION}
  ERLANG_VERSION=${ERLANG_VERSION}
  ELIXIR_VERSION=${ELIXIR_VERSION}
  SSH_MODE=${SSH_MODE}   (valid: import, agent)
  SYMPHONY_DIR=${SYMPHONY_DIR}
  SYMPHONY_CONFIG_DIR=${SYMPHONY_CONFIG_DIR}
  SYMPHONY_WORKSPACE_ROOT=${SYMPHONY_WORKSPACE_ROOT}
  OPENCLAW_DIR=${OPENCLAW_DIR}
  OPENCLAW_UPSTREAM_URL=${OPENCLAW_UPSTREAM_URL}
  OPENCLAW_REF=${OPENCLAW_REF}
  GIT_SSH_HOST=${GIT_SSH_HOST}
  DEV_HOST_CONFIG_ENABLED=${DEV_HOST_CONFIG_ENABLED}
  DEV_HOST_CONFIG_DIR=${DEV_HOST_CONFIG_DIR}
  DEV_HOST_CONFIG_MOUNT=${DEV_HOST_CONFIG_MOUNT}
  DEV_HOST_ZSHRC_ENABLED=${DEV_HOST_ZSHRC_ENABLED}
  DEV_HOST_ZSHRC_SOURCE=${DEV_HOST_ZSHRC_SOURCE}
  DEV_CODEX_SKILLS_ENABLED=${DEV_CODEX_SKILLS_ENABLED}
  DEV_CODEX_SKILLS_SOURCE=${DEV_CODEX_SKILLS_SOURCE}
  DEV_CODEX_SKILLS_TARGET=${DEV_CODEX_SKILLS_TARGET}
  DEV_CODEX_SKILLS_DELETE_STALE=${DEV_CODEX_SKILLS_DELETE_STALE}
  XCODE_BRIDGE_ENABLED=${XCODE_BRIDGE_ENABLED}
  XCODE_BRIDGE_HOST_DIR=${XCODE_BRIDGE_HOST_DIR}
  XCODE_BRIDGE_MOUNT=${XCODE_BRIDGE_MOUNT}
  XCODE_BRIDGE_HOSTNAME=${XCODE_BRIDGE_HOSTNAME}
  XCODE_BRIDGE_LOCALHOST_IP=${XCODE_BRIDGE_LOCALHOST_IP}
  XCODE_BRIDGE_BIND=${XCODE_BRIDGE_BIND}
  XCODE_BRIDGE_PORT=${XCODE_BRIDGE_PORT}

Examples:
  ./images/dev/container.sh up
  ./images/dev/container.sh xcode-bridge-dns
  ./images/dev/container.sh xcode-bridge-start
  ./images/dev/container.sh xcode-bridge simctl list devices
  DEV_NAME=dev-a ./images/dev/container.sh up
  DEV_NAME=dev-b DEV_MEMORY=12g DEV_CPUS=6 DEV_HOME_VOLUME_SIZE=50G DEV_DOCKER_VOLUME_SIZE=150G ./images/dev/container.sh up
  DEV_NAME=dev-b ./images/dev/container.sh destroy --purge
EOF
}

setup_git_ssh() {
  dev_runtime_prepare
  ac_exec_guest_command true true setup-git-ssh "$@"
}

setup_symphony() {
  dev_runtime_prepare
  ac_exec_guest_command true true setup-symphony "$@"
}

run_symphony() {
  dev_runtime_prepare
  ac_exec_guest_command true true run-symphony "$@"
}

setup_openclaw() {
  dev_runtime_prepare
  ac_exec_guest_command true true setup-openclaw "$@"
}

onboard_openclaw() {
  dev_runtime_prepare
  ac_exec_guest_command true true onboard-openclaw "$@"
}

run_openclaw() {
  dev_runtime_prepare
  ac_exec_guest_command true true run-openclaw "$@"
}

require_host_tool() {
  local tool="$1"

  if ! command -v "${tool}" >/dev/null 2>&1; then
    ac_die "Host tool '${tool}' is not installed or not on PATH. Install Xcode or Command Line Tools on macOS."
  fi
}

xcode_status() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    ac_die "Xcode tools are macOS-only; this command must run on the macOS host."
  fi

  if command -v xcode-select >/dev/null 2>&1; then
    printf 'xcode-select=%s\n' "$(xcode-select -p 2>/dev/null || printf 'not configured')"
  else
    printf 'xcode-select=not installed\n'
  fi

  if command -v xcodebuild >/dev/null 2>&1; then
    if ! xcodebuild -version; then
      printf 'xcodebuild=installed but unavailable\n'
    fi
  else
    printf 'xcodebuild=not installed\n'
  fi

  if command -v xcrun >/dev/null 2>&1; then
    printf 'xcrun=%s\n' "$(command -v xcrun)"
    printf 'macosx-sdk=%s\n' "$(xcrun --show-sdk-path --sdk macosx 2>/dev/null || printf 'not available')"
  else
    printf 'xcrun=not installed\n'
  fi
}

run_host_xcode_tool() {
  local tool="$1"
  shift

  if [[ "$(uname -s)" != "Darwin" ]]; then
    ac_die "Xcode tools are macOS-only; '${tool}' must run on the macOS host."
  fi

  require_host_tool "${tool}"
  "${tool}" "$@"
}

dev_host_config_is_enabled() {
  [[ "${DEV_HOST_CONFIG_ENABLED}" == "1" || "${DEV_HOST_CONFIG_ENABLED}" == "true" || "${DEV_HOST_CONFIG_ENABLED}" == "yes" ]]
}

dev_host_zshrc_is_enabled() {
  [[ "${DEV_HOST_ZSHRC_ENABLED}" == "1" || "${DEV_HOST_ZSHRC_ENABLED}" == "true" || "${DEV_HOST_ZSHRC_ENABLED}" == "yes" ]]
}

dev_codex_skills_is_enabled() {
  [[ "${DEV_CODEX_SKILLS_ENABLED}" == "1" || "${DEV_CODEX_SKILLS_ENABLED}" == "true" || "${DEV_CODEX_SKILLS_ENABLED}" == "yes" ]]
}

dev_copy_tree() {
  local source_dir="$1"
  local target_dir="$2"
  local tmp_dir

  install -d -m 0700 "$(dirname "${target_dir}")"
  if command -v rsync >/dev/null 2>&1; then
    install -d -m 0700 "${target_dir}"
    rsync -a --delete "${source_dir}/" "${target_dir}/"
    return 0
  fi

  tmp_dir="${target_dir}.tmp.$$"
  rm -rf "${tmp_dir}"
  install -d -m 0700 "${tmp_dir}"
  cp -Rp "${source_dir}/." "${tmp_dir}/"
  rm -rf "${target_dir}"
  mv "${tmp_dir}" "${target_dir}"
}

dev_host_config_prepare() {
  local codex_dir dotfiles_dir target_codex_skills target_zshrc

  dev_host_config_is_enabled || return 0

  codex_dir="${DEV_HOST_CONFIG_DIR}/codex"
  dotfiles_dir="${DEV_HOST_CONFIG_DIR}/dotfiles"
  target_codex_skills="${codex_dir}/skills"
  target_zshrc="${dotfiles_dir}/.zshrc"

  install -d -m 0700 "${DEV_HOST_CONFIG_DIR}" "${codex_dir}" "${dotfiles_dir}"
  if dev_host_zshrc_is_enabled && [[ -r "${DEV_HOST_ZSHRC_SOURCE}" ]]; then
    cp "${DEV_HOST_ZSHRC_SOURCE}" "${target_zshrc}"
    chmod 0600 "${target_zshrc}"
  elif [[ ! -e "${target_zshrc}" ]]; then
    : > "${target_zshrc}"
    chmod 0600 "${target_zshrc}"
  fi

  if dev_codex_skills_is_enabled && [[ -d "${DEV_CODEX_SKILLS_SOURCE}" ]]; then
    dev_copy_tree "${DEV_CODEX_SKILLS_SOURCE}" "${target_codex_skills}"
  elif [[ -d "${target_codex_skills}" ]]; then
    rm -rf "${target_codex_skills}"
  fi

  cat > "${DEV_HOST_CONFIG_DIR}/README.txt" <<EOF
This directory is managed by images/dev/container.sh.

dotfiles/.zshrc is copied from:
${DEV_HOST_ZSHRC_SOURCE}

codex/skills is copied from:
${DEV_CODEX_SKILLS_SOURCE}

The dev container copies it to /home/dev/.host.zshrc and sources it from /home/dev/.zshrc.
The dev container copies codex/skills into ${DEV_CODEX_SKILLS_TARGET}.
EOF
}

dev_runtime_prepare() {
  dev_host_config_prepare
  xcode_bridge_prepare_dir
}

xcode_bridge_is_enabled() {
  [[ "${XCODE_BRIDGE_ENABLED}" == "1" || "${XCODE_BRIDGE_ENABLED}" == "true" || "${XCODE_BRIDGE_ENABLED}" == "yes" ]]
}

xcode_bridge_require_host() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    ac_die "The Xcode bridge is macOS-only and must run on the macOS host."
  fi
}

xcode_bridge_pid_file() {
  printf '%s\n' "${XCODE_BRIDGE_HOST_DIR}/xcode-bridge.pid"
}

xcode_bridge_log_file() {
  printf '%s\n' "${XCODE_BRIDGE_HOST_DIR}/xcode-bridge.log"
}

xcode_bridge_host_token_file() {
  printf '%s\n' "${XCODE_BRIDGE_HOST_DIR}/token"
}

xcode_bridge_generate_token() {
  local first second

  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import secrets; print(secrets.token_hex(32))'
  elif command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 32
  else
    first="$(uuidgen | tr -d '-' | tr '[:upper:]' '[:lower:]')"
    second="$(uuidgen | tr -d '-' | tr '[:upper:]' '[:lower:]')"
    printf '%s%s\n' "${first}" "${second}"
  fi
}

xcode_bridge_prepare_dir() {
  local old_umask token_file

  xcode_bridge_is_enabled || return 0
  xcode_bridge_require_host

  token_file="$(xcode_bridge_host_token_file)"
  install -d -m 0700 "${XCODE_BRIDGE_HOST_DIR}"
  install -d -m 0755 "${XCODE_BRIDGE_HOST_DIR}/exchange/uploads" "${XCODE_BRIDGE_HOST_DIR}/exchange/downloads"

  if [[ ! -s "${token_file}" ]]; then
    old_umask="$(umask)"
    umask 077
    xcode_bridge_generate_token > "${token_file}"
    umask "${old_umask}"
  fi
  chmod 0600 "${token_file}"

  cat > "${XCODE_BRIDGE_HOST_DIR}/bridge.env" <<EOF
XCODE_BRIDGE_MOUNT=${XCODE_BRIDGE_MOUNT}
XCODE_BRIDGE_URL=${XCODE_BRIDGE_URL}
XCODE_BRIDGE_TOKEN_FILE=${XCODE_BRIDGE_TOKEN_FILE}
EOF
}

xcode_bridge_pid_running() {
  local pid_file pid

  pid_file="$(xcode_bridge_pid_file)"
  [[ -s "${pid_file}" ]] || return 1
  pid="$(<"${pid_file}")"
  [[ -n "${pid}" ]] || return 1
  kill -0 "${pid}" 2>/dev/null
}

xcode_bridge_start() {
  local pid_file log_file token_file

  xcode_bridge_is_enabled || ac_die "XCODE_BRIDGE_ENABLED is disabled."
  xcode_bridge_require_host
  require_host_tool python3
  require_host_tool xcrun
  xcode_bridge_prepare_dir

  pid_file="$(xcode_bridge_pid_file)"
  log_file="$(xcode_bridge_log_file)"
  token_file="$(xcode_bridge_host_token_file)"

  if xcode_bridge_pid_running; then
    ac_log "Xcode bridge is already running (pid $(<"${pid_file}"))"
    return 0
  fi

  ac_log "Starting Xcode bridge on ${XCODE_BRIDGE_BIND}:${XCODE_BRIDGE_PORT}"
  nohup python3 "${XCODE_BRIDGE_SERVER}" \
    --root "${XCODE_BRIDGE_HOST_DIR}" \
    --guest-mount "${XCODE_BRIDGE_MOUNT}" \
    --token-file "${token_file}" \
    --bind "${XCODE_BRIDGE_BIND}" \
    --port "${XCODE_BRIDGE_PORT}" \
    > "${log_file}" 2>&1 &
  printf '%s\n' "$!" > "${pid_file}"

  sleep 1
  if ! xcode_bridge_pid_running; then
    tail -n 80 "${log_file}" >&2 || true
    ac_die "Xcode bridge failed to start."
  fi

  ac_log "Xcode bridge is running (pid $(<"${pid_file}"))"
  ac_log "Guest URL: ${XCODE_BRIDGE_URL}"
}

xcode_bridge_stop() {
  local pid_file pid

  xcode_bridge_require_host
  pid_file="$(xcode_bridge_pid_file)"
  if ! xcode_bridge_pid_running; then
    ac_log "Xcode bridge is not running"
    rm -f "${pid_file}"
    return 0
  fi

  pid="$(<"${pid_file}")"
  ac_log "Stopping Xcode bridge (pid ${pid})"
  kill "${pid}" 2>/dev/null || true
  rm -f "${pid_file}"
}

xcode_bridge_status() {
  local pid_file log_file

  xcode_bridge_require_host
  xcode_bridge_prepare_dir
  pid_file="$(xcode_bridge_pid_file)"
  log_file="$(xcode_bridge_log_file)"

  printf 'enabled=%s\n' "${XCODE_BRIDGE_ENABLED}"
  printf 'host_dir=%s\n' "${XCODE_BRIDGE_HOST_DIR}"
  printf 'guest_mount=%s\n' "${XCODE_BRIDGE_MOUNT}"
  printf 'guest_url=%s\n' "${XCODE_BRIDGE_URL}"
  printf 'bind=%s\n' "${XCODE_BRIDGE_BIND}"
  printf 'port=%s\n' "${XCODE_BRIDGE_PORT}"
  printf 'dns_command=sudo container system dns create %s --localhost %s\n' "${XCODE_BRIDGE_HOSTNAME}" "${XCODE_BRIDGE_LOCALHOST_IP}"
  if xcode_bridge_pid_running; then
    printf 'running=true\n'
    printf 'pid=%s\n' "$(<"${pid_file}")"
  else
    printf 'running=false\n'
  fi
  printf 'log=%s\n' "${log_file}"
}

xcode_bridge_dns() {
  xcode_bridge_require_host
  ac_preflight
  ac_ensure_container_system
  if container system dns list 2>/dev/null | grep -Fq "${XCODE_BRIDGE_HOSTNAME}"; then
    ac_log "Host-loopback DNS '${XCODE_BRIDGE_HOSTNAME}' is already configured"
    return 0
  fi
  ac_log "Creating host-loopback DNS '${XCODE_BRIDGE_HOSTNAME}' at ${XCODE_BRIDGE_LOCALHOST_IP}"
  sudo container system dns create "${XCODE_BRIDGE_HOSTNAME}" --localhost "${XCODE_BRIDGE_LOCALHOST_IP}"
}

xcode_bridge_guest() {
  dev_host_config_prepare
  xcode_bridge_start
  ac_exec_guest_command false false xcode-bridge "$@"
}

main() {
  local command="${1:-help}"

  case "${command}" in
    build)
      shift
      [[ $# -eq 0 ]] || ac_die "Usage: $(basename "$0") build"
      dev_host_config_prepare
      ac_build_image
      ;;
    create)
      shift
      [[ $# -eq 0 ]] || ac_die "Usage: $(basename "$0") create"
      dev_runtime_prepare
      ac_create_container
      ;;
    up)
      shift
      [[ $# -eq 0 ]] || ac_die "Usage: $(basename "$0") up"
      dev_runtime_prepare
      ac_up_container
      ;;
    shell)
      shift
      [[ $# -eq 0 ]] || ac_die "Usage: $(basename "$0") shell"
      dev_runtime_prepare
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
    xcode-status)
      shift
      [[ $# -eq 0 ]] || ac_die "Usage: $(basename "$0") xcode-status"
      xcode_status
      ;;
    xcodebuild)
      shift
      run_host_xcode_tool xcodebuild "$@"
      ;;
    xcrun)
      shift
      run_host_xcode_tool xcrun "$@"
      ;;
    simctl)
      shift
      run_host_xcode_tool xcrun simctl "$@"
      ;;
    xcode-bridge-dns)
      shift
      [[ $# -eq 0 ]] || ac_die "Usage: $(basename "$0") xcode-bridge-dns"
      xcode_bridge_dns
      ;;
    xcode-bridge-start)
      shift
      [[ $# -eq 0 ]] || ac_die "Usage: $(basename "$0") xcode-bridge-start"
      xcode_bridge_start
      ;;
    xcode-bridge-stop)
      shift
      [[ $# -eq 0 ]] || ac_die "Usage: $(basename "$0") xcode-bridge-stop"
      xcode_bridge_stop
      ;;
    xcode-bridge-status)
      shift
      [[ $# -eq 0 ]] || ac_die "Usage: $(basename "$0") xcode-bridge-status"
      xcode_bridge_status
      ;;
    xcode-bridge)
      shift
      xcode_bridge_guest "$@"
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
