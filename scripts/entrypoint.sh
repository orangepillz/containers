#!/usr/bin/env bash

set -euo pipefail

DEV_USER="${DEV_USER:-dev}"
DEV_HOME="${DEV_HOME:-/home/${DEV_USER}}"
DOCKER_HOST="${DOCKER_HOST:-unix:///var/run/docker.sock}"
DOCKERD_LOG="${DOCKERD_LOG:-/var/log/dockerd.log}"
SKELETON_DIR="/usr/local/share/dev-home-skel"

copy_if_missing() {
  local source_path="$1"
  local target_path="$2"

  if [[ ! -e "${target_path}" && -e "${source_path}" ]]; then
    cp "${source_path}" "${target_path}"
  fi
}

init_dev_home() {
  install -d -m 0755 -o "${DEV_USER}" -g "${DEV_USER}" "${DEV_HOME}"
  copy_if_missing "${SKELETON_DIR}/.bashrc" "${DEV_HOME}/.bashrc"
  copy_if_missing "${SKELETON_DIR}/.bash_profile" "${DEV_HOME}/.bash_profile"
  copy_if_missing "${SKELETON_DIR}/.profile" "${DEV_HOME}/.profile"
  chown "${DEV_USER}:${DEV_USER}" \
    "${DEV_HOME}" \
    "${DEV_HOME}/.bashrc" \
    "${DEV_HOME}/.bash_profile" \
    "${DEV_HOME}/.profile" 2>/dev/null || true
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
