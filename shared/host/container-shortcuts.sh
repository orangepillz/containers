#!/usr/bin/env bash

# Source this file from ~/.zshrc or ~/.bashrc:
#   source /Users/danieldresner/src/containers/shared/host/container-shortcuts.sh

CONTAINERS_ROOT="${CONTAINERS_ROOT:-/Users/danieldresner/src/containers}"

_container_shortcuts_wrapper() {
  local target="$1"
  case "${target}" in
    dev)
      printf '%s\n' "${CONTAINERS_ROOT}/images/dev/container.sh"
      ;;
    openclaw)
      printf '%s\n' "${CONTAINERS_ROOT}/images/openclaw/container.sh"
      ;;
    *)
      return 1
      ;;
  esac
}

_container_shortcuts_default_image() {
  local target="$1"
  case "${target}" in
    dev)
      printf '%s\n' "dev:latest"
      ;;
    openclaw)
      printf '%s\n' "openclaw-dev:latest"
      ;;
    *)
      return 1
      ;;
  esac
}

_container_shortcuts_prefix() {
  local target="$1"
  case "${target}" in
    dev)
      printf '%s\n' "DEV"
      ;;
    openclaw)
      printf '%s\n' "OPENCLAW"
      ;;
    *)
      return 1
      ;;
  esac
}

_container_shortcuts_default_name() {
  local target="$1"
  case "${target}" in
    dev)
      printf '%s\n' "dev"
      ;;
    openclaw)
      printf '%s\n' "openclaw-dev"
      ;;
    *)
      return 1
      ;;
  esac
}

_container_shortcuts_read_field() {
  local json="$1"
  local field="$2"

  printf '%s\n' "${json}" | sed -n "s/.*\"${field}\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" | head -n 1
}

_container_shortcuts_usage() {
  local target="$1"
  local noun default_name default_image

  case "${target}" in
    dev)
      noun="devbox"
      ;;
    openclaw)
      noun="openclawbox"
      ;;
    *)
      return 1
      ;;
  esac

  default_name="$(_container_shortcuts_default_name "${target}")"
  default_image="$(_container_shortcuts_default_image "${target}")"

  cat <<EOF
Usage: ${noun} <command> [options] [-- wrapper-args...]

Commands:
  build      Build the image
  create     Create the named container
  up         Create/start the named container
  shell      Open a shell in the named container
  status     Show wrapper/container status
  stop       Stop the named container
  destroy    Destroy the named container
  ls         List containers for the default image
  help       Show this help

Options:
  --name NAME              Container name (default: ${default_name})
  --image IMAGE            Image tag (default: ${default_image})
  --memory SIZE            Container memory, e.g. 8g
  --cpus COUNT             Container CPU count, e.g. 4
  --builder-memory SIZE    Builder memory
  --builder-cpus COUNT     Builder CPU count
  --home-volume NAME       Override /home/dev volume name
  --docker-volume NAME     Override /var/lib/docker volume name
  --home-size SIZE         Create /home/dev volume at this size on first create
  --docker-size SIZE       Create /var/lib/docker volume at this size on first create
  --ssh-mode MODE          import or agent
  --quiet                  With ls, only print container names

Examples:
  ${noun} up
  ${noun} up --name ${default_name}-a
  ${noun} up --name ${default_name}-b --memory 12g --cpus 6 --home-size 50G --docker-size 150G
  ${noun} shell --name ${default_name}-b
  ${noun} destroy --name ${default_name}-b --purge
EOF
}

_container_shortcuts_ids() {
  local include_all="${1:-false}"

  if [[ "${include_all}" == "true" ]]; then
    container list --all --quiet 2>/dev/null
  else
    container list --quiet 2>/dev/null
  fi
}

_container_shortcuts_list() {
  local target="$1"
  shift

  local quiet="false"
  local image_filter
  local name image status started json
  local -a names

  image_filter="$(_container_shortcuts_default_image "${target}")"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --quiet|-q)
        quiet="true"
        shift
        ;;
      --image)
        image_filter="$2"
        shift 2
        ;;
      *)
        printf 'Unknown ls option: %s\n' "$1" >&2
        return 1
        ;;
    esac
  done

  while IFS= read -r name; do
    [[ -n "${name}" ]] || continue
    names+=("${name}")
  done < <(_container_shortcuts_ids true)

  if [[ "${quiet}" != "true" ]]; then
    printf '%-20s %-12s %s\n' "NAME" "STATUS" "IMAGE"
  fi

  for name in "${names[@]}"; do
    json="$(container inspect "${name}" 2>/dev/null || true)"
    image="$(_container_shortcuts_read_field "${json}" reference)"
    [[ "${image}" == "${image_filter}" ]] || continue
    status="$(_container_shortcuts_read_field "${json}" status)"
    started="$(_container_shortcuts_read_field "${json}" startedDate)"

    if [[ "${quiet}" == "true" ]]; then
      printf '%s\n' "${name}"
    elif [[ -n "${started}" ]]; then
      printf '%-20s %-12s %s\n' "${name}" "${status}" "${image}"
    else
      printf '%-20s %-12s %s\n' "${name}" "${status:-unknown}" "${image}"
    fi
  done
}

boxps() {
  if [[ "${1:-}" == "--all" ]]; then
    shift
    container list --all "$@"
  else
    container list "$@"
  fi
}

boxconfigs() {
  local include_all="false"
  local name found="false"

  if [[ "${1:-}" == "--all" ]]; then
    include_all="true"
    shift
  fi

  while IFS= read -r name; do
    [[ -n "${name}" ]] || continue
    found="true"
    printf '=== %s ===\n' "${name}"
    container inspect "${name}"
    printf '\n'
  done < <(_container_shortcuts_ids "${include_all}")

  if [[ "${found}" != "true" ]]; then
    if [[ "${include_all}" == "true" ]]; then
      printf 'No containers found.\n'
    else
      printf 'No running containers found.\n'
    fi
  fi
}

_container_shortcuts_run() {
  local target="$1"
  shift

  local wrapper prefix command
  local name="" image="" memory="" cpus=""
  local builder_memory="" builder_cpus=""
  local home_volume="" docker_volume=""
  local home_size="" docker_size=""
  local ssh_mode=""
  local -a env_args wrapper_args

  wrapper="$(_container_shortcuts_wrapper "${target}")" || return 1
  prefix="$(_container_shortcuts_prefix "${target}")" || return 1

  if [[ ! -x "${wrapper}" ]]; then
    printf 'Missing wrapper: %s\n' "${wrapper}" >&2
    return 1
  fi

  command="${1:-help}"
  if [[ $# -gt 0 ]]; then
    shift
  fi

  case "${command}" in
    help|-h|--help)
      _container_shortcuts_usage "${target}"
      return 0
      ;;
    ls|list)
      _container_shortcuts_list "${target}" "$@"
      return $?
      ;;
  esac

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name)
        name="$2"
        shift 2
        ;;
      --image)
        image="$2"
        shift 2
        ;;
      --memory)
        memory="$2"
        shift 2
        ;;
      --cpus)
        cpus="$2"
        shift 2
        ;;
      --builder-memory)
        builder_memory="$2"
        shift 2
        ;;
      --builder-cpus)
        builder_cpus="$2"
        shift 2
        ;;
      --home-volume)
        home_volume="$2"
        shift 2
        ;;
      --docker-volume)
        docker_volume="$2"
        shift 2
        ;;
      --home-size)
        home_size="$2"
        shift 2
        ;;
      --docker-size)
        docker_size="$2"
        shift 2
        ;;
      --ssh-mode)
        ssh_mode="$2"
        shift 2
        ;;
      --)
        shift
        wrapper_args+=("$@")
        break
        ;;
      *)
        wrapper_args+=("$1")
        shift
        ;;
    esac
  done

  if [[ -n "${name}" ]]; then
    [[ -n "${home_volume}" ]] || home_volume="${name}-home"
    [[ -n "${docker_volume}" ]] || docker_volume="${name}-docker"
  fi

  [[ -n "${name}" ]] && env_args+=("${prefix}_NAME=${name}")
  [[ -n "${image}" ]] && env_args+=("${prefix}_IMAGE=${image}")
  [[ -n "${memory}" ]] && env_args+=("${prefix}_MEMORY=${memory}")
  [[ -n "${cpus}" ]] && env_args+=("${prefix}_CPUS=${cpus}")
  [[ -n "${builder_memory}" ]] && env_args+=("${prefix}_BUILDER_MEMORY=${builder_memory}")
  [[ -n "${builder_cpus}" ]] && env_args+=("${prefix}_BUILDER_CPUS=${builder_cpus}")
  [[ -n "${home_volume}" ]] && env_args+=("${prefix}_HOME_VOLUME=${home_volume}")
  [[ -n "${docker_volume}" ]] && env_args+=("${prefix}_DOCKER_VOLUME=${docker_volume}")
  [[ -n "${home_size}" ]] && env_args+=("${prefix}_HOME_VOLUME_SIZE=${home_size}")
  [[ -n "${docker_size}" ]] && env_args+=("${prefix}_DOCKER_VOLUME_SIZE=${docker_size}")
  [[ -n "${ssh_mode}" ]] && env_args+=("SSH_MODE=${ssh_mode}")

  env "${env_args[@]}" "${wrapper}" "${command}" "${wrapper_args[@]}"
}

devbox() {
  _container_shortcuts_run dev "$@"
}

openclawbox() {
  _container_shortcuts_run openclaw "$@"
}

alias dv='devbox'
alias ocb='openclawbox'
alias dvl='devbox ls'
alias ocl='openclawbox ls'
alias bps='boxps'
alias bcfg='boxconfigs'
