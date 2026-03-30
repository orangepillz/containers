#!/usr/bin/env bash

set -euo pipefail

DEV_HOME="${HOME:-/home/dev}"
SSH_DIR="${DEV_HOME}/.ssh"
KNOWN_HOSTS_PATH="${SSH_DIR}/known_hosts"
SSH_CONFIG_PATH="${SSH_DIR}/config"
GIT_SSH_HOST="${GIT_SSH_HOST:-github.com}"
FORCE_REPLACE=false

log() {
  printf '[setup-git-ssh] %s\n' "$*"
}

die() {
  printf '[setup-git-ssh] ERROR: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: setup-git-ssh [--force|--replace]

Guided Git SSH bootstrap for the guest container.

Options:
  --force, --replace   Replace an existing keypair for the selected key name
  -h, --help           Show this help message
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

sanitize_key_name() {
  local value="$1"

  if [[ ! "${value}" =~ ^[A-Za-z0-9._-]+$ ]]; then
    die "SSH key names may only contain letters, numbers, dots, underscores, and hyphens."
  fi
}

ensure_ssh_layout() {
  install -d -m 700 "${SSH_DIR}"
  touch "${KNOWN_HOSTS_PATH}" "${SSH_CONFIG_PATH}"
  chmod 600 "${KNOWN_HOSTS_PATH}" "${SSH_CONFIG_PATH}"
}

keyscan_host() {
  local git_host="$1"

  if ssh-keygen -F "${git_host}" -f "${KNOWN_HOSTS_PATH}" >/dev/null 2>&1; then
    return 0
  fi

  if ssh-keyscan -H -t rsa,ecdsa,ed25519 "${git_host}" >>"${KNOWN_HOSTS_PATH}" 2>/dev/null; then
    chmod 600 "${KNOWN_HOSTS_PATH}"
    return 0
  fi

  log "Unable to fetch host keys for ${git_host}; continuing with an empty known_hosts entry."
}

upsert_managed_host_block() {
  local git_host="$1"
  local identity_path="$2"
  local start_marker="# >>> dev-container setup-git-ssh ${git_host} >>>"
  local end_marker="# <<< dev-container setup-git-ssh ${git_host} <<<"
  local temp_path

  temp_path="$(mktemp)"

  if [[ -f "${SSH_CONFIG_PATH}" ]]; then
    awk -v start="${start_marker}" -v end="${end_marker}" '
      $0 == start { skipping = 1; next }
      $0 == end { skipping = 0; next }
      !skipping { print }
    ' "${SSH_CONFIG_PATH}" >"${temp_path}"
  fi

  {
    if [[ -s "${temp_path}" ]]; then
      printf '\n'
    fi
    printf '%s\n' "${start_marker}"
    printf 'Host %s\n' "${git_host}"
    printf '  HostName %s\n' "${git_host}"
    printf '  User git\n'
    printf '  IdentityFile %s\n' "${identity_path}"
    printf '  IdentitiesOnly yes\n'
    printf '  StrictHostKeyChecking yes\n'
    printf '%s\n' "${end_marker}"
  } >>"${temp_path}"

  mv "${temp_path}" "${SSH_CONFIG_PATH}"
  chmod 600 "${SSH_CONFIG_PATH}"
}

generate_or_reuse_keypair() {
  local git_email="$1"
  local key_path="$2"
  local pub_path="${key_path}.pub"

  if [[ -f "${key_path}" || -f "${pub_path}" ]]; then
    if [[ "${FORCE_REPLACE}" == "true" ]]; then
      log "Replacing existing keypair at ${key_path}"
      rm -f -- "${key_path}" "${pub_path}"
    else
      log "Reusing existing keypair at ${key_path}"
    fi
  fi

  if [[ ! -f "${key_path}" ]]; then
    log "Generating a new Ed25519 keypair at ${key_path}"
    ssh-keygen -q -t ed25519 -C "${git_email}" -f "${key_path}" -N ""
  fi

  chmod 600 "${key_path}"
  chmod 644 "${pub_path}"
}

main() {
  local git_user_name
  local git_email
  local ssh_key_name
  local git_host
  local default_name
  local default_email
  local default_key_name
  local host_slug
  local key_path
  local public_key_path

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --force|--replace)
        FORCE_REPLACE=true
        shift
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

  command -v git >/dev/null 2>&1 || die "git is required but was not found in PATH."
  command -v ssh-keygen >/dev/null 2>&1 || die "ssh-keygen is required but was not found in PATH."
  command -v ssh-keyscan >/dev/null 2>&1 || die "ssh-keyscan is required but was not found in PATH."

  default_name="$(git config --global --get user.name || true)"
  default_email="$(git config --global --get user.email || true)"
  git_host="${GIT_SSH_HOST}"
  host_slug="${git_host//[^A-Za-z0-9]/_}"
  default_key_name="id_ed25519_${host_slug}"

  prompt_with_default git_user_name "Git user name" "${default_name}"
  [[ -n "${git_user_name}" ]] || die "Git user name cannot be empty."

  prompt_with_default git_email "Git email" "${default_email}"
  [[ -n "${git_email}" ]] || die "Git email cannot be empty."

  prompt_with_default ssh_key_name "SSH key name" "${default_key_name}"
  [[ -n "${ssh_key_name}" ]] || die "SSH key name cannot be empty."
  sanitize_key_name "${ssh_key_name}"

  prompt_with_default git_host "Git SSH host" "${git_host}"
  [[ -n "${git_host}" ]] || die "Git SSH host cannot be empty."

  key_path="${SSH_DIR}/${ssh_key_name}"
  public_key_path="${key_path}.pub"

  ensure_ssh_layout
  keyscan_host "${git_host}"
  generate_or_reuse_keypair "${git_email}" "${key_path}"
  upsert_managed_host_block "${git_host}" "${key_path}"

  git config --global user.name "${git_user_name}"
  git config --global user.email "${git_email}"

  log "Git identity and SSH config are ready."
  printf '\nPublic key (%s):\n' "${public_key_path}"
  cat "${public_key_path}"
  printf '\nTest the connection with:\n  ssh -T git@%s\n' "${git_host}"
}

main "$@"
