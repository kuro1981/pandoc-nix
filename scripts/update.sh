#!/usr/bin/env bash
set -euo pipefail

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

readonly GITHUB_REPO="jgm/pandoc"
readonly RELEASE_API_BASE="repos/${GITHUB_REPO}/releases"

# Assets whose names follow a stable, version-parameterised pattern.
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
)

# Upstream has renamed the WebAssembly asset repeatedly
# (3.10: pandoc-3.10.wasm.zip, 3.10.1: pandoc-wasm.zip,
#  3.10.2: pandoc-wasm-3.10.2.zip), so it is resolved from the release
# listing by pattern instead of being hardcoded.
readonly WASM_ASSET_PATTERN='^pandoc.*wasm.*\.zip$'

# Populated by fetch_release_json(); holds the release payload so the assets
# are queried with a single API call.
RELEASE_JSON_FILE=""

log_info() { echo -e "${GREEN}[INFO]${NC} $1" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

cleanup() {
  [[ -n "$RELEASE_JSON_FILE" ]] && rm -f "$RELEASE_JSON_FILE"
}
trap cleanup EXIT

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

fetch_release_json() {
  local version="$1"
  RELEASE_JSON_FILE=$(mktemp)
  if ! gh api "${RELEASE_API_BASE}/tags/${version}" >"$RELEASE_JSON_FILE"; then
    log_error "Failed to fetch release ${version} from ${GITHUB_REPO}"
    return 1
  fi
}

get_asset_digest_hex() {
  local asset_name="$1"

  local digest
  digest=$(jq -r --arg name "$asset_name" \
    '[.assets[] | select(.name == $name) | .digest] | first // ""' "$RELEASE_JSON_FILE")
  if [[ -z "$digest" || "$digest" == "null" ]]; then
    log_error "Asset digest not found for ${asset_name}"
    return 1
  fi

  echo "${digest#sha256:}"
}

find_wasm_asset_name() {
  jq -r --arg re "$WASM_ASSET_PATTERN" \
    '[.assets[].name | select(test($re))] | first // ""' "$RELEASE_JSON_FILE"
}

get_current_wasm_key() {
  sed -n 's/^[[:space:]]*"\([^"]*wasm[^"]*\)" = {.*/\1/p' package.nix | head -1
}

# Asset keys in package.nix use Nix string interpolation ("${version}").
# Replace the version number in an asset name with the literal Nix template
# so the search key matches what is actually written in the source file.
to_nix_asset_key() {
  local asset_name="$1"
  local version="$2"
  local version_placeholder='${version}'
  echo "${asset_name/$version/$version_placeholder}"
}

update_package_version() {
  local version="$1"
  sed -i.bak "s/version = \".*\";/version = \"${version}\";/" package.nix
}

rename_asset_key() {
  local old_key="$1"
  local new_key="$2"

  [[ "$old_key" == "$new_key" ]] && return 0

  local temp_file
  temp_file=$(mktemp)

  awk -v old_key="\"${old_key}\" = {" -v new_key="\"${new_key}\" = {" '
    index($0, old_key) > 0 {
      sub(/"[^"]*" = \{/, new_key)
      renamed = 1
    }
    { print }
    END { exit(renamed ? 0 : 1) }
  ' package.nix >"$temp_file" || {
    rm -f "$temp_file"
    log_error "Could not rename asset key \"${old_key}\" in package.nix"
    return 1
  }

  mv "$temp_file" package.nix
  log_info "Renamed asset key \"${old_key}\" -> \"${new_key}\""
}

update_asset_hash() {
  local asset_name="$1"
  local hash_hex="$2"
  local temp_file
  temp_file=$(mktemp)

  local nix_key
  nix_key=$(to_nix_asset_key "$asset_name" "$(get_current_version)")

  awk -v search_key="\"${nix_key}\" = {" -v hash_hex="$hash_hex" '
    index($0, search_key) > 0 { in_asset = 1 }
    in_asset && /sha256 = "/ {
      sub(/sha256 = "[^"]*";/, "sha256 = \"" hash_hex "\";")
      in_asset = 0
      replaced = 1
    }
    { print }
    END { exit(replaced ? 0 : 1) }
  ' package.nix >"$temp_file" || {
    rm -f "$temp_file"
    log_error "Asset key \"${nix_key}\" not found in package.nix; hash not updated."
    return 1
  }

  mv "$temp_file" package.nix
}

sync_asset() {
  local asset_name="$1"

  log_info "Fetching digest for ${asset_name}"

  local digest_hex
  digest_hex=$(get_asset_digest_hex "$asset_name") || return 1
  update_asset_hash "$asset_name" "$digest_hex"
}

sync_wasm_asset() {
  local new_version="$1"

  local asset_name
  asset_name=$(find_wasm_asset_name)
  if [[ -z "$asset_name" ]]; then
    log_warn "Release ${new_version} ships no WebAssembly asset; leaving the existing entry unchanged."
    return 0
  fi

  local current_key new_key
  current_key=$(get_current_wasm_key)
  new_key=$(to_nix_asset_key "$asset_name" "$new_version")

  if [[ -z "$current_key" ]]; then
    log_warn "No WebAssembly entry found in package.nix; skipping ${asset_name}."
    return 0
  fi

  rename_asset_key "$current_key" "$new_key"
  sync_asset "$asset_name"
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

  fetch_release_json "$new_version"

  log_info "Updating package.nix to Pandoc ${new_version}"
  update_package_version "$new_version"

  local tmpl asset_name
  for tmpl in "${RELEASE_ASSETS[@]}"; do
    # shellcheck disable=SC2059
    asset_name=$(printf "$tmpl" "$new_version")
    sync_asset "$asset_name"
  done

  sync_wasm_asset "$new_version"

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
