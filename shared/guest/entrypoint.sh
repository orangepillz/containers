#!/usr/bin/env bash

set -euo pipefail

DEV_USER="${DEV_USER:-dev}"
DEV_HOME="${DEV_HOME:-/home/${DEV_USER}}"
DOCKER_HOST="${DOCKER_HOST:-unix:///var/run/docker.sock}"
DOCKERD_LOG="${DOCKERD_LOG:-/var/log/dockerd.log}"
DEV_HOST_CONFIG_MOUNT="${DEV_HOST_CONFIG_MOUNT:-/host-config}"
DEV_CODEX_SKILLS_TARGET="${DEV_CODEX_SKILLS_TARGET:-${DEV_HOME}/.codex/skills}"
DEV_CODEX_SKILLS_DELETE_STALE="${DEV_CODEX_SKILLS_DELETE_STALE:-0}"
SKELETON_DIR="/usr/local/share/dev-home-skel"

copy_if_missing() {
  local source_path="$1"
  local target_path="$2"

  if [[ ! -e "${target_path}" && -e "${source_path}" ]]; then
    cp "${source_path}" "${target_path}"
  fi
}

ensure_block() {
  local target_path="$1"
  local marker="$2"
  shift 2

  touch "${target_path}"
  if ! grep -Fq "${marker}" "${target_path}"; then
    {
      printf '\n'
      printf '%s\n' "$@"
    } >> "${target_path}"
  fi
}

sync_host_zshrc() {
  local source_path="${DEV_HOST_CONFIG_MOUNT}/dotfiles/.zshrc"
  local target_path="${DEV_HOME}/.host.zshrc"

  if [[ -r "${source_path}" ]]; then
    cp "${source_path}" "${target_path}"
    chown "${DEV_USER}:${DEV_USER}" "${target_path}" 2>/dev/null || true
    chmod 0644 "${target_path}" 2>/dev/null || true
  fi
}

codex_skills_delete_stale_enabled() {
  [[ "${DEV_CODEX_SKILLS_DELETE_STALE}" == "1" || "${DEV_CODEX_SKILLS_DELETE_STALE}" == "true" || "${DEV_CODEX_SKILLS_DELETE_STALE}" == "yes" ]]
}

sync_host_codex_skills() {
  local source_path="${DEV_HOST_CONFIG_MOUNT}/codex/skills"
  local target_path="${DEV_CODEX_SKILLS_TARGET}"
  local -a rsync_args

  if [[ ! -d "${source_path}" ]]; then
    return 0
  fi

  install -d -m 0755 -o "${DEV_USER}" -g "${DEV_USER}" "$(dirname "${target_path}")" "${target_path}"
  if command -v rsync >/dev/null 2>&1; then
    rsync_args=(-a)
    if codex_skills_delete_stale_enabled; then
      rsync_args+=(--delete)
    fi
    rsync "${rsync_args[@]}" "${source_path}/" "${target_path}/"
  else
    cp -a "${source_path}/." "${target_path}/"
  fi
  chown -R "${DEV_USER}:${DEV_USER}" "${target_path}" 2>/dev/null || true
}

init_dev_home() {
  install -d -m 0755 -o "${DEV_USER}" -g "${DEV_USER}" "${DEV_HOME}"
  copy_if_missing "${SKELETON_DIR}/.bashrc" "${DEV_HOME}/.bashrc"
  copy_if_missing "${SKELETON_DIR}/.bash_profile" "${DEV_HOME}/.bash_profile"
  copy_if_missing "${SKELETON_DIR}/.profile" "${DEV_HOME}/.profile"
  copy_if_missing "${SKELETON_DIR}/.zshrc" "${DEV_HOME}/.zshrc"
  copy_if_missing "${SKELETON_DIR}/.zprofile" "${DEV_HOME}/.zprofile"
  ensure_block \
    "${DEV_HOME}/.zshrc" \
    "# >>> dev-container host zshrc >>>" \
    "# >>> dev-container host zshrc >>>" \
    'if [ -f "$HOME/.host.zshrc" ]; then' \
    '  source "$HOME/.host.zshrc"' \
    'fi' \
    "# <<< dev-container host zshrc <<<"
  sync_host_zshrc
  sync_host_codex_skills
  chown "${DEV_USER}:${DEV_USER}" \
    "${DEV_HOME}" \
    "${DEV_HOME}/.bashrc" \
    "${DEV_HOME}/.bash_profile" \
    "${DEV_HOME}/.profile" \
    "${DEV_HOME}/.zshrc" \
    "${DEV_HOME}/.zprofile" 2>/dev/null || true
}

cleanup() {
  if [[ -n "${DOCKERD_PID:-}" ]] && kill -0 "${DOCKERD_PID}" 2>/dev/null; then
    kill -TERM "${DOCKERD_PID}" 2>/dev/null || true
    wait "${DOCKERD_PID}" 2>/dev/null || true
  fi
}

trap cleanup EXIT INT TERM

install -d -m 0755 /var/log /var/run /run /var/lib/docker
rm -f /var/run/docker.pid

init_dev_home

touch "${DOCKERD_LOG}"

dockerd --host="${DOCKER_HOST}" --pidfile /var/run/docker.pid >"${DOCKERD_LOG}" 2>&1 &
DOCKERD_PID=$!

for _ in $(seq 1 60); do
  if docker version >/dev/null 2>&1; then
    wait "${DOCKERD_PID}"
    exit $?
  fi

  if ! kill -0 "${DOCKERD_PID}" 2>/dev/null; then
    echo "dockerd exited during startup" >&2
    tail -n 200 "${DOCKERD_LOG}" >&2 || true
    exit 1
  fi

  sleep 1
done

echo "Timed out waiting for dockerd to become ready" >&2
tail -n 200 "${DOCKERD_LOG}" >&2 || true
exit 1
