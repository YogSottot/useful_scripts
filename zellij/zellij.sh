#!/usr/bin/env bash
set -Eeuo pipefail

# use
# bash <(curl -sL https://raw.githubusercontent.com/YogSottot/useful_scripts/master/zellij/zellij.sh)

SCRIPT_NAME="${0##*/}"
DRY_RUN=0
FORCE=0

pkg_manager=""
release=""
release_version=""
arch=""
rpm_arch=""
distro_id="unknown"
distro_like=""

APT_KEYRING="/etc/apt/keyrings/yogsottot.asc"
APT_LIST="/etc/apt/sources.list.d/yogsottot.list"
RPM_REPO="/etc/yum.repos.d/yogsottot.repo"
ZELLIJ_CONFIG_DIR="${HOME}/.config/zellij"
ZELLIJ_CONFIG_FILE="config.kdl"

usage() {
  cat <<EOF
Usage:
  $SCRIPT_NAME [options]

Options:
  -n, --dry-run   Показать, что будет сделано, без изменений в системе
  -f, --force     Перезаписать repo/keyring файлы, даже если они уже существуют
  -h, --help      Показать эту справку

Examples:
  $SCRIPT_NAME
  $SCRIPT_NAME --dry-run
  $SCRIPT_NAME --force
  $SCRIPT_NAME -n -f
EOF
}

log() {
  printf '[INFO] %s\n' "$*"
}

warn() {
  printf '[WARN] %s\n' "$*" >&2
}

err() {
  printf '[ERROR] %s\n' "$*" >&2
}

on_error() {
  local exit_code=$?
  err "Сбой на строке ${1:-unknown}, код выхода ${exit_code}"
  exit "$exit_code"
}

trap 'on_error $LINENO' ERR

run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '[DRY-RUN] '
    printf '%q ' "$@"
    printf '\n'
  else
    "$@"
  fi
}

require_root() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    return 0
  fi

  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    err "Скрипт нужно запускать от root"
    exit 1
  fi
}

require_command() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    err "Не найдена обязательная команда: $cmd"
    exit 1
  fi
}

file_exists_and_not_force() {
  local path="$1"
  [[ -e "$path" && "$FORCE" -ne 1 ]]
}

write_file() {
  local path="$1"
  local content="$2"
  local mode="${3:-0644}"
  local dir

  dir="$(dirname "$path")"

  if file_exists_and_not_force "$path"; then
    err "Файл уже существует: $path"
    err "Используй --force для перезаписи"
    exit 1
  fi

  run mkdir -p "$dir"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '[DRY-RUN] cat > %q <<'\''EOF'\''\n%s\nEOF\n' "$path" "$content"
    printf '[DRY-RUN] chmod %s %q\n' "$mode" "$path"
  else
    cat > "$path" <<<"$content"
    chmod "$mode" "$path"
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -n|--dry-run)
        DRY_RUN=1
        ;;
      -f|--force)
        FORCE=1
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        err "Неизвестная опция: $1"
        usage
        exit 1
        ;;
    esac
    shift
  done
}

detect_arch() {
  local machine_arch dpkg_detected rpm_detected
  machine_arch="$(uname -m)"

  case "$machine_arch" in
    x86_64|amd64)
      arch="amd64"
      rpm_arch="x86_64"
      ;;
    *)
      err "Неподдерживаемая архитектура: $machine_arch"
      err "Поддерживается только amd64/x86_64"
      exit 1
      ;;
  esac

  if command -v dpkg >/dev/null 2>&1; then
    dpkg_detected="$(dpkg --print-architecture 2>/dev/null || true)"
    if [[ -n "$dpkg_detected" && "$dpkg_detected" != "amd64" ]]; then
      err "dpkg сообщает архитектуру '$dpkg_detected', требуется amd64"
      exit 1
    fi
  fi

  if command -v rpm >/dev/null 2>&1; then
    rpm_detected="$(rpm --eval '%{_arch}' 2>/dev/null || true)"
    if [[ -n "$rpm_detected" && "$rpm_detected" != "x86_64" ]]; then
      err "rpm сообщает архитектуру '$rpm_detected', требуется x86_64"
      exit 1
    fi
  fi
}

detect_pkg_manager() {
  if command -v apt >/dev/null 2>&1; then
    pkg_manager="apt"
  elif command -v dnf >/dev/null 2>&1; then
    pkg_manager="dnf"
  elif command -v yum >/dev/null 2>&1; then
    pkg_manager="yum"
  else
    err "Не удалось определить пакетный менеджер: apt, dnf или yum"
    exit 1
  fi
}

detect_release_info() {
  local os_release="/etc/os-release"
  release=""
  release_version=""

  if [[ -f "$os_release" ]]; then
    # shellcheck disable=SC1091
    source "$os_release"
    release="${VERSION_CODENAME:-}"
    release_version="${VERSION_ID:-}"
    distro_id="${ID:-unknown}"
    distro_like="${ID_LIKE:-}"
  fi

  if [[ -z "$release" ]] && command -v lsb_release >/dev/null 2>&1; then
    release="$(lsb_release -sc 2>/dev/null || true)"
  fi

  if [[ -z "$release_version" ]] && command -v lsb_release >/dev/null 2>&1; then
    release_version="$(lsb_release -sr 2>/dev/null || true)"
  fi

  if [[ -z "$release" ]]; then
    case "$distro_id" in
      ubuntu)
        case "${release_version:-}" in
          24.04) release="noble" ;;
          22.04) release="jammy" ;;
        esac
        ;;
      debian)
        case "${release_version:-}" in
          13) release="trixie" ;;
          12) release="bookworm" ;;
        esac
        ;;
    esac
  fi

  if [[ -z "$release" && -f /etc/debian_version ]]; then
    local deb_ver
    deb_ver="$(cut -d/ -f1 /etc/debian_version | cut -d. -f1 2>/dev/null || true)"
    case "$deb_ver" in
      13) release="trixie" ;;
      12) release="bookworm" ;;
    esac
    [[ -z "$release_version" ]] && release_version="$deb_ver"
  fi

  if [[ -z "$release_version" ]]; then
    release_version="unknown"
  fi

  if [[ "$pkg_manager" == "apt" && -z "$release" ]]; then
    err "Не удалось определить codename Debian/Ubuntu"
    exit 1
  fi
}

preflight() {
  require_root
  require_command uname
  require_command mkdir
  require_command chmod

  detect_arch
  detect_pkg_manager
  detect_release_info

  case "$pkg_manager" in
    apt)
      require_command apt
      require_command curl
      ;;
    dnf)
      require_command dnf
      ;;
    yum)
      require_command yum
      ;;
  esac
}

setup_deb_repo() {
  local repo_content

  repo_content="deb [arch=amd64 signed-by=/etc/apt/keyrings/yogsottot.asc] https://yogsottot.github.io/ppa/debian ${release} main"

  log "Настройка APT-репозитория"
  log "release=${release}"
  log "release_version=${release_version}"

  run mkdir -p /etc/apt/keyrings

  if file_exists_and_not_force "$APT_KEYRING"; then
    err "Файл уже существует: $APT_KEYRING"
    err "Используй --force для перезаписи"
    exit 1
  fi

  run curl -fSsL --retry 3 --retry-delay 2 -o "$APT_KEYRING" https://yogsottot.github.io/ppa/yogsottot.asc
  run chmod 0644 "$APT_KEYRING"

  write_file "$APT_LIST" "$repo_content" 0644

  run apt update
  run apt install -y zellij
}

setup_rpm_repo() {
  local repo_content

  repo_content='[yogsottot]
name=YogSottot RPM Repository
baseurl=https://yogsottot.github.io/ppa/redhat/repo/x86_64/
enabled=1

gpgcheck=1
repo_gpgcheck=1

gpgkey=https://yogsottot.github.io/ppa/yogsottot.asc'

  log "Настройка RPM-репозитория"
  log "release=${release:-n/a}"
  log "release_version=${release_version}"

  write_file "$RPM_REPO" "$repo_content" 0644

  run "$pkg_manager" -y install zellij
}

setup_config() {
  local config_path="${ZELLIJ_CONFIG_DIR}/${ZELLIJ_CONFIG_FILE}"

  if file_exists_and_not_force "$config_path"; then
    err "Файл уже существует: $config_path"
    err "Используй --force для перезаписи"
    exit 1
  fi

  run mkdir -p "$ZELLIJ_CONFIG_DIR"
  run curl -fSsL --retry 3 --retry-delay 2 -o "$config_path" \
    https://raw.githubusercontent.com/YogSottot/useful_scripts/master/zellij/config.kdl
}

print_summary() {
  log "script=${SCRIPT_NAME}"
  log "dry_run=${DRY_RUN}"
  log "force=${FORCE}"
  log "pkg_manager=${pkg_manager}"
  log "arch=${arch}"
  log "release=${release:-n/a}"
  log "release_version=${release_version}"
}

main() {
  parse_args "$@"
  preflight
  print_summary
  setup_config

  case "$pkg_manager" in
    apt)
      setup_deb_repo
      ;;
    dnf|yum)
      setup_rpm_repo
      ;;
    *)
      err "Неподдерживаемый пакетный менеджер: $pkg_manager"
      exit 1
      ;;
  esac

  
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "Dry-run завершён, изменения не применялись"
  else
    log "zellij успешно установлен"
  fi
}

main "$@"
