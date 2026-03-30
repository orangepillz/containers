#!/usr/bin/env bash

set -euo pipefail

SYMPHONY_DIR="${SYMPHONY_DIR:-/home/dev/symphony}"
SYMPHONY_CONFIG_DIR="${SYMPHONY_CONFIG_DIR:-/home/dev/.config/symphony}"
SYMPHONY_WORKSPACE_ROOT="${SYMPHONY_WORKSPACE_ROOT:-/home/dev/code/symphony-workspaces}"
ERLANG_VERSION="${ERLANG_VERSION:-28}"
ELIXIR_VERSION="${ELIXIR_VERSION:-1.19.5-otp-28}"
SYMPHONY_UPSTREAM_URL="${SYMPHONY_UPSTREAM_URL:-https://github.com/openai/symphony.git}"
DEFAULT_CODEX_APP_SERVER_COMMAND='codex --config shell_environment_policy.inherit=all --config model_reasoning_effort=xhigh --model gpt-5.3-codex app-server'
CODEX_APP_SERVER_COMMAND="${CODEX_APP_SERVER_COMMAND:-${DEFAULT_CODEX_APP_SERVER_COMMAND}}"
TEMPLATE_ROOT="/usr/local/share/devbox/symphony"
WORKFLOW_TEMPLATE_PATH="${TEMPLATE_ROOT}/WORKFLOW.md.tmpl"
MISE_TEMPLATE_PATH="${TEMPLATE_ROOT}/mise.local.toml.tmpl"
SYMPHONY_ENV_PATH="${SYMPHONY_CONFIG_DIR}/env"
SYMPHONY_WORKFLOW_PATH="${SYMPHONY_CONFIG_DIR}/WORKFLOW.md"

log() {
  printf '[setup-symphony] %s\n' "$*"
}

die() {
  printf '[setup-symphony] ERROR: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: setup-symphony

Clone or update openai/symphony, install the Elixir runtime/toolchain,
and write guest-local Symphony config under ~/.config/symphony.
EOF
}

prompt_with_default() {
  local target_var="$1"
  local prompt_label="$2"
  local default_value="${3:-}"
  local reply

  if [[ -n "${default_value}" ]]; then
    read -r -p "${prompt_label} [${default_value}]: " reply
    reply="${reply:-${default_value}}"
  else
    read -r -p "${prompt_label}: " reply
  fi

  printf -v "${target_var}" '%s' "${reply}"
}

prompt_secret() {
  local target_var="$1"
  local prompt_label="$2"
  local existing_value="${3:-}"
  local reply

  if [[ -n "${existing_value}" ]]; then
    read -r -s -p "${prompt_label} [press enter to keep existing]: " reply
    printf '\n'
    reply="${reply:-${existing_value}}"
  else
    read -r -s -p "${prompt_label}: " reply
    printf '\n'
  fi

  printf -v "${target_var}" '%s' "${reply}"
}

escape_single_quotes() {
  printf "%s" "$1" | sed "s/'/'\"'\"'/g"
}

escape_sed_replacement() {
  printf '%s' "$1" | sed -e 's/[\/&]/\\&/g'
}

load_existing_config() {
  if [[ -f "${SYMPHONY_ENV_PATH}" ]]; then
    # shellcheck disable=SC1090
    . "${SYMPHONY_ENV_PATH}"
  fi
}

ensure_dependencies() {
  command -v git >/dev/null 2>&1 || die "git is required but was not found in PATH."
  command -v mise >/dev/null 2>&1 || die "mise is required but was not found in PATH."
  [[ -f "${WORKFLOW_TEMPLATE_PATH}" ]] || die "Missing workflow template at ${WORKFLOW_TEMPLATE_PATH}."
  [[ -f "${MISE_TEMPLATE_PATH}" ]] || die "Missing runtime template at ${MISE_TEMPLATE_PATH}."
}

clone_or_update_symphony() {
  if [[ -d "${SYMPHONY_DIR}/.git" ]]; then
    if ! git -C "${SYMPHONY_DIR}" diff --quiet || ! git -C "${SYMPHONY_DIR}" diff --cached --quiet; then
      log "Local changes detected in ${SYMPHONY_DIR}; skipping pull and using the existing checkout."
      return 0
    fi

    log "Updating ${SYMPHONY_DIR}"
    git -C "${SYMPHONY_DIR}" fetch --tags origin main
    if git -C "${SYMPHONY_DIR}" show-ref --verify --quiet refs/heads/main; then
      git -C "${SYMPHONY_DIR}" checkout main >/dev/null 2>&1
      git -C "${SYMPHONY_DIR}" pull --ff-only origin main
    else
      git -C "${SYMPHONY_DIR}" checkout -b main --track origin/main >/dev/null 2>&1
    fi
    return 0
  fi

  if [[ -e "${SYMPHONY_DIR}" ]]; then
    die "${SYMPHONY_DIR} exists but is not a git checkout."
  fi

  log "Cloning ${SYMPHONY_UPSTREAM_URL} into ${SYMPHONY_DIR}"
  git clone "${SYMPHONY_UPSTREAM_URL}" "${SYMPHONY_DIR}"
}

render_runtime_override() {
  local temp_path
  local target_path="${SYMPHONY_DIR}/elixir/mise.local.toml"

  temp_path="$(mktemp)"
  sed \
    -e "s/__ERLANG_VERSION__/$(escape_sed_replacement "${ERLANG_VERSION}")/g" \
    -e "s/__ELIXIR_VERSION__/$(escape_sed_replacement "${ELIXIR_VERSION}")/g" \
    "${MISE_TEMPLATE_PATH}" >"${temp_path}"

  mv "${temp_path}" "${target_path}"
  chmod 644 "${target_path}"
}

build_symphony() {
  local elixir_dir="${SYMPHONY_DIR}/elixir"

  [[ -d "${elixir_dir}" ]] || die "Expected ${elixir_dir} to exist after cloning Symphony."

  render_runtime_override

  log "Trusting and installing the Symphony Elixir runtime"
  mise -y trust "${elixir_dir}/mise.toml"
  mise -y trust "${elixir_dir}/mise.local.toml"

  (
    cd "${elixir_dir}"
    mise install
    mise exec -- mix setup
    mise exec -- mix build
  )

  [[ -x "${elixir_dir}/bin/symphony" ]] || die "Expected ${elixir_dir}/bin/symphony after mix build."
}

write_env_file() {
  local temp_path

  temp_path="$(mktemp)"
  {
    printf "LINEAR_API_KEY='%s'\n" "$(escape_single_quotes "${LINEAR_API_KEY}")"
    printf "LINEAR_PROJECT_SLUG='%s'\n" "$(escape_single_quotes "${LINEAR_PROJECT_SLUG}")"
    printf "SOURCE_REPO_URL='%s'\n" "$(escape_single_quotes "${SOURCE_REPO_URL}")"
    printf "SYMPHONY_DIR='%s'\n" "$(escape_single_quotes "${SYMPHONY_DIR}")"
    printf "SYMPHONY_CONFIG_DIR='%s'\n" "$(escape_single_quotes "${SYMPHONY_CONFIG_DIR}")"
    printf "SYMPHONY_WORKSPACE_ROOT='%s'\n" "$(escape_single_quotes "${SYMPHONY_WORKSPACE_ROOT}")"
    printf "CODEX_APP_SERVER_COMMAND='%s'\n" "$(escape_single_quotes "${CODEX_APP_SERVER_COMMAND}")"
  } >"${temp_path}"

  chmod 600 "${temp_path}"
  mv "${temp_path}" "${SYMPHONY_ENV_PATH}"
  chmod 600 "${SYMPHONY_ENV_PATH}"
}

write_workflow_file() {
  local temp_path

  temp_path="$(mktemp)"
  sed \
    -e "s/__LINEAR_PROJECT_SLUG__/$(escape_sed_replacement "${LINEAR_PROJECT_SLUG}")/g" \
    -e "s/__SOURCE_REPO_URL__/$(escape_sed_replacement "${SOURCE_REPO_URL}")/g" \
    -e "s/__SYMPHONY_WORKSPACE_ROOT__/$(escape_sed_replacement "${SYMPHONY_WORKSPACE_ROOT}")/g" \
    -e "s/__CODEX_APP_SERVER_COMMAND__/$(escape_sed_replacement "${CODEX_APP_SERVER_COMMAND}")/g" \
    "${WORKFLOW_TEMPLATE_PATH}" >"${temp_path}"

  install -m 644 "${temp_path}" "${SYMPHONY_WORKFLOW_PATH}"
  rm -f -- "${temp_path}"
}

main() {
  local linear_api_key_default=""
  local linear_project_slug_default=""
  local source_repo_url_default="${SOURCE_REPO_URL:-}"
  local workspace_root_default="${SYMPHONY_WORKSPACE_ROOT}"

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
  install -d -m 700 "${SYMPHONY_CONFIG_DIR}"
  install -d -m 755 "${SYMPHONY_WORKSPACE_ROOT}"

  load_existing_config

  linear_api_key_default="${LINEAR_API_KEY:-}"
  linear_project_slug_default="${LINEAR_PROJECT_SLUG:-}"
  source_repo_url_default="${SOURCE_REPO_URL:-${source_repo_url_default}}"
  workspace_root_default="${SYMPHONY_WORKSPACE_ROOT:-${workspace_root_default}}"
  CODEX_APP_SERVER_COMMAND="${CODEX_APP_SERVER_COMMAND:-${DEFAULT_CODEX_APP_SERVER_COMMAND}}"

  clone_or_update_symphony
  build_symphony

  prompt_secret LINEAR_API_KEY "Linear API key" "${linear_api_key_default}"
  [[ -n "${LINEAR_API_KEY}" ]] || die "Linear API key cannot be empty."

  prompt_with_default LINEAR_PROJECT_SLUG "Linear project slug" "${linear_project_slug_default}"
  [[ -n "${LINEAR_PROJECT_SLUG}" ]] || die "Linear project slug cannot be empty."

  prompt_with_default SOURCE_REPO_URL "Source repository URL" "${source_repo_url_default}"
  [[ -n "${SOURCE_REPO_URL}" ]] || die "Source repository URL cannot be empty."

  prompt_with_default SYMPHONY_WORKSPACE_ROOT "Workspace root" "${workspace_root_default}"
  [[ -n "${SYMPHONY_WORKSPACE_ROOT}" ]] || die "Workspace root cannot be empty."

  install -d -m 755 "${SYMPHONY_WORKSPACE_ROOT}"
  write_env_file
  write_workflow_file

  log "Wrote ${SYMPHONY_ENV_PATH} (0600) and ${SYMPHONY_WORKFLOW_PATH}."
  log "Symphony is ready to launch with run-symphony."
}

main "$@"
