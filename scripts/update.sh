#!/usr/bin/env bash
set -euo pipefail

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

readonly GITHUB_REPO="jgm/pandoc"
readonly RELEASE_API_BASE="repos/${GITHUB_REPO}/releases"

readonly RELEASE_ASSETS=(
  "pandoc-%s-1-amd64.deb"
  "pandoc-%s-1-arm64.deb"
  "pandoc-%s-arm64-macOS.pkg"
  "pandoc-%s-arm64-macOS.zip"
  "pandoc-%s-linux-amd64.tar.gz"
  "pandoc-%s-linux-arm64.tar.gz"
  "pandoc-%s-windows-x86_64.msi"
  "pandoc-%s-windows-x86_64.zip"
  "pandoc-%s-x86_64-macOS.pkg"
  "pandoc-%s-x86_64-macOS.zip"
  "pandoc-%s.wasm.zip"
)

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

ensure_in_repository_root() {
  if [[ ! -f "flake.nix" || ! -f "package.nix" ]]; then
    log_error "flake.nix or package.nix not found. Run this script from repo root."
    exit 1
  fi
}

ensure_required_tools_installed() {
  command -v gh >/dev/null 2>&1 || {
    log_error "gh (GitHub CLI) is required but not installed."
    exit 1
  }
  command -v jq >/dev/null 2>&1 || {
    log_error "jq is required but not installed."
    exit 1
  }
  command -v nix >/dev/null 2>&1 || {
    log_error "nix is required but not installed."
    exit 1
  }
}

get_current_version() {
  sed -n 's/.*version = "\([^"]*\)".*/\1/p' package.nix | head -1 || echo "unknown"
}

get_latest_version() {
  local tag
  tag=$(gh release view --repo "$GITHUB_REPO" --json tagName -q '.tagName' 2>/dev/null || true)
  if [[ -z "$tag" ]]; then
    log_error "Failed to fetch latest release tag from ${GITHUB_REPO}"
    exit 1
  fi
  echo "$tag"
}

release_json() {
  local version="$1"
  gh api "${RELEASE_API_BASE}/tags/${version}"
}

get_asset_digest_hex() {
  local version="$1"
  local asset_name="$2"

  local digest
  digest=$(release_json "$version" | jq -r --arg name "$asset_name" '.assets[] | select(.name == $name) | .digest' | head -1)
  if [[ -z "$digest" || "$digest" == "null" ]]; then
    log_error "Asset digest not found for ${asset_name}"
    return 1
  fi

  echo "${digest#sha256:}"
}

update_package_version() {
  local version="$1"
  sed -i.bak "s/version = \".*\";/version = \"${version}\";/" package.nix
}

update_asset_hash() {
  local asset_name="$1"
  local hash_hex="$2"
  local temp_file
  temp_file=$(mktemp)

  awk -v asset_name="$asset_name" -v hash_hex="$hash_hex" '
    $0 ~ "\"" asset_name "\" = \\{" { in_asset = 1 }
    in_asset && $0 ~ /sha256 = "/ {
      sub(/sha256 = "[^"]*";/, "sha256 = \"" hash_hex "\";")
      in_asset = 0
    }
    { print }
  ' package.nix > "$temp_file"

  mv "$temp_file" package.nix
}

cleanup_backup_files() {
  rm -f package.nix.bak
}

update_flake_lock() {
  log_info "Updating flake.lock..."
  nix flake update
}

verify_build() {
  log_info "Verifying package build..."
  nix build .#pandoc >/dev/null
  ./result/bin/pandoc --version >/dev/null
  log_info "Build verification passed."
}

show_changes() {
  echo
  log_info "Changes made:"
  git diff --stat package.nix flake.lock 2>/dev/null || true
}

print_usage() {
  echo "Usage: $0 [OPTIONS]"
  echo
  echo "Options:"
  echo "  --version VERSION  Update to specific version"
  echo "  --check            Only check for updates"
  echo "  --help             Show this help"
}

parse_arguments() {
  local target_version=""
  local check_only="false"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --version)
        target_version="$2"
        shift 2
        ;;
      --check)
        check_only="true"
        shift
        ;;
      --help)
        print_usage
        exit 0
        ;;
      *)
        log_error "Unknown option: $1"
        print_usage
        exit 1
        ;;
    esac
  done

  echo "${target_version}|${check_only}"
}

update_to_version() {
  local new_version="$1"

  log_info "Updating package.nix to Pandoc ${new_version}"
  update_package_version "$new_version"

  local tmpl
  for tmpl in "${RELEASE_ASSETS[@]}"; do
    local asset_name
    asset_name=$(printf "$tmpl" "$new_version")
    log_info "Fetching digest for ${asset_name}"

    local digest_hex
    digest_hex=$(get_asset_digest_hex "$new_version" "$asset_name")
    update_asset_hash "$asset_name" "$digest_hex"
  done

  cleanup_backup_files
  update_flake_lock
  verify_build
}

main() {
  ensure_in_repository_root
  ensure_required_tools_installed

  local args
  args=$(parse_arguments "$@")

  local target_version
  target_version=$(echo "$args" | cut -d'|' -f1)
  local check_only
  check_only=$(echo "$args" | cut -d'|' -f2)

  local current_version
  current_version=$(get_current_version)
  local latest_version
  latest_version=$(get_latest_version)

  if [[ -n "$target_version" ]]; then
    latest_version="$target_version"
  fi

  log_info "Current version: ${current_version}"
  log_info "Latest version: ${latest_version}"

  if [[ "$current_version" == "$latest_version" ]]; then
    log_info "Already up to date."
    exit 0
  fi

  if [[ "$check_only" == "true" ]]; then
    log_warn "Update available: ${current_version} -> ${latest_version}"
    exit 1
  fi

  update_to_version "$latest_version"
  show_changes
  log_info "Successfully updated Pandoc from ${current_version} to ${latest_version}"
}

main "$@"