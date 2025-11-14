#!/bin/bash

# Martillo Store CLI - Manage external store actions
# Usage: ./scripts/store-cli.sh [add|update|list] [options]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STORE_DIR="$PROJECT_ROOT/store"
LOCK_FILE="$PROJECT_ROOT/store.lock.json"
TEMP_DIR="$PROJECT_ROOT/.tmp-store"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
  echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
  echo -e "${GREEN}✓${NC} $1"
}

log_error() {
  echo -e "${RED}✗${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}⚠${NC} $1"
}

# Parse GitHub URL to extract repo and path
# Input: https://github.com/sjdonado/idonthavespotify/tree/master/extra/martillo
# Output: owner repo branch path
parse_github_url() {
  local url="$1"

  # Remove trailing slash
  url="${url%/}"

  # Extract components using regex
  if [[ $url =~ github\.com/([^/]+)/([^/]+)/tree/([^/]+)/(.+) ]]; then
    local owner="${BASH_REMATCH[1]}"
    local repo="${BASH_REMATCH[2]}"
    local branch="${BASH_REMATCH[3]}"
    local path="${BASH_REMATCH[4]}"

    echo "$owner|$repo|$branch|$path"
    return 0
  else
    log_error "Invalid GitHub URL format. Expected: https://github.com/owner/repo/tree/branch/path/to/martillo"
    return 1
  fi
}

# Extract action name from path
# Convention: Look for the martillo folder, use the repo name as action name
# Input: extra/martillo, path (repo name as fallback)
# Output: Action name (repo name)
get_action_name() {
  local path="$1"
  local repo="$2"

  # Always use repo name as the action name
  # The convention is that repos have a 'martillo' folder for the action
  echo "$repo"
}

# Initialize lock file if it doesn't exist
init_lock_file() {
  if [[ ! -f "$LOCK_FILE" ]]; then
    echo '{"actions":[]}' > "$LOCK_FILE"
    log_info "Created lock file: $LOCK_FILE"
  fi
}

# Add action to lock file
add_to_lock_file() {
  local name="$1"
  local url="$2"
  local owner="$3"
  local repo="$4"
  local branch="$5"
  local path="$6"
  local commit_hash="$7"

  local temp_file=$(mktemp)

  # Check if action already exists
  if jq -e ".actions[] | select(.name == \"$name\")" "$LOCK_FILE" > /dev/null 2>&1; then
    # Update existing entry
    jq ".actions |= map(if .name == \"$name\" then {
      \"name\": \"$name\",
      \"url\": \"$url\",
      \"owner\": \"$owner\",
      \"repo\": \"$repo\",
      \"branch\": \"$branch\",
      \"path\": \"$path\",
      \"commit\": \"$commit_hash\",
      \"updated_at\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"
    } else . end)" "$LOCK_FILE" > "$temp_file"
  else
    # Add new entry
    jq ".actions += [{
      \"name\": \"$name\",
      \"url\": \"$url\",
      \"owner\": \"$owner\",
      \"repo\": \"$repo\",
      \"branch\": \"$branch\",
      \"path\": \"$path\",
      \"commit\": \"$commit_hash\",
      \"installed_at\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"
    }]" "$LOCK_FILE" > "$temp_file"
  fi

  mv "$temp_file" "$LOCK_FILE"
}

# Remove action from lock file
remove_from_lock_file() {
  local name="$1"
  local temp_file=$(mktemp)

  jq ".actions |= map(select(.name != \"$name\"))" "$LOCK_FILE" > "$temp_file"
  mv "$temp_file" "$LOCK_FILE"
}

# Get action info from lock file
get_action_info() {
  local name="$1"
  jq -r ".actions[] | select(.name == \"$name\")" "$LOCK_FILE"
}

# Clone repository with sparse checkout for specific folder
sparse_clone_folder() {
  local owner="$1"
  local repo="$2"
  local branch="$3"
  local path="$4"
  local dest="$5"
  local repo_url="https://github.com/$owner/$repo.git"

  # Create temp directory
  mkdir -p "$TEMP_DIR"
  local temp_repo="$TEMP_DIR/$repo-$$"

  # Initialize empty repo
  git init "$temp_repo" > /dev/null 2>&1
  cd "$temp_repo"

  # Configure sparse checkout
  git config core.sparseCheckout true
  echo "$path/*" >> .git/info/sparse-checkout

  # Add remote and fetch
  git remote add origin "$repo_url"
  git fetch --depth=1 origin "$branch" > /dev/null 2>&1
  git checkout "$branch" > /dev/null 2>&1

  # Get current commit hash
  local commit_hash=$(git rev-parse HEAD)

  # Check if martillo folder exists in the path
  if [[ ! -d "$path" ]]; then
    log_error "Path '$path' not found in repository"
    cd "$PROJECT_ROOT"
    rm -rf "$temp_repo"
    return 1
  fi

  # Check if init.lua exists
  if [[ ! -f "$path/init.lua" ]]; then
    log_error "init.lua not found in '$path'. External actions must contain init.lua"
    cd "$PROJECT_ROOT"
    rm -rf "$temp_repo"
    return 1
  fi

  # Copy contents to destination
  mkdir -p "$dest"
  cp -r "$path"/* "$dest/"

  cd "$PROJECT_ROOT"
  rm -rf "$temp_repo"

  echo "$commit_hash"
}

# Command: add
cmd_add() {
  local url="$1"

  if [[ -z "$url" ]]; then
    log_error "URL is required"
    echo "Usage: $0 add <github-url>"
    echo "Example: $0 add https://github.com/sjdonado/idonthavespotify/tree/master/extra/martillo"
    exit 1
  fi

  # Parse URL
  local parsed=$(parse_github_url "$url")
  if [[ $? -ne 0 ]]; then
    exit 1
  fi

  IFS='|' read -r owner repo branch path <<< "$parsed"

  # Get action name
  local action_name=$(get_action_name "$path" "$repo")

  log_info "Adding action: $action_name"
  log_info "Repository: $owner/$repo"
  log_info "Branch: $branch"
  log_info "Path: $path"

  # Check if action already exists
  local dest_dir="$STORE_DIR/$action_name"
  if [[ -d "$dest_dir" ]]; then
    log_warn "Action '$action_name' already exists in store/"
    read -p "Do you want to overwrite it? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      log_info "Aborted"
      exit 0
    fi
    rm -rf "$dest_dir"
  fi

  # Clone with sparse checkout
  log_info "Cloning $owner/$repo..."
  local commit_hash=$(sparse_clone_folder "$owner" "$repo" "$branch" "$path" "$dest_dir")

  if [[ $? -ne 0 ]]; then
    exit 1
  fi

  # Add to lock file
  init_lock_file
  add_to_lock_file "$action_name" "$url" "$owner" "$repo" "$branch" "$path" "$commit_hash"

  log_success "Action '$action_name' added successfully!"
  log_info "Location: store/$action_name"
  log_info "Commit: $commit_hash"
}

# Command: update
cmd_update() {
  local action_name="$1"

  init_lock_file

  if [[ -z "$action_name" ]]; then
    # Update all actions
    log_info "Updating all actions..."

    local count=$(jq -r '.actions | length' "$LOCK_FILE")
    if [[ "$count" -eq 0 ]]; then
      log_warn "No actions found in lock file"
      exit 0
    fi

    local updated=0
    local failed=0

    for i in $(seq 0 $((count - 1))); do
      local name=$(jq -r ".actions[$i].name" "$LOCK_FILE")
      local owner=$(jq -r ".actions[$i].owner" "$LOCK_FILE")
      local repo=$(jq -r ".actions[$i].repo" "$LOCK_FILE")
      local branch=$(jq -r ".actions[$i].branch" "$LOCK_FILE")
      local path=$(jq -r ".actions[$i].path" "$LOCK_FILE")
      local current_commit=$(jq -r ".actions[$i].commit" "$LOCK_FILE")
      local url=$(jq -r ".actions[$i].url" "$LOCK_FILE")

      log_info "Checking '$name'..."

      # Check if directory exists
      if [[ ! -d "$STORE_DIR/$name" ]]; then
        log_warn "Directory store/$name not found, re-adding..."
      fi

      # Clone latest version
      local dest_dir="$STORE_DIR/$name"
      rm -rf "$dest_dir"
      local new_commit=$(sparse_clone_folder "$owner" "$repo" "$branch" "$path" "$dest_dir")

      if [[ $? -ne 0 ]]; then
        log_error "Failed to update '$name'"
        ((failed++))
        continue
      fi

      if [[ "$new_commit" != "$current_commit" ]]; then
        add_to_lock_file "$name" "$url" "$owner" "$repo" "$branch" "$path" "$new_commit"
        log_success "Updated '$name' ($current_commit -> $new_commit)"
        ((updated++))
      else
        log_info "'$name' is already up to date"
      fi
    done

    echo ""
    log_success "Update complete: $updated updated, $failed failed"
  else
    # Update specific action
    local action_info=$(get_action_info "$action_name")

    if [[ -z "$action_info" ]]; then
      log_error "Action '$action_name' not found in lock file"
      exit 1
    fi

    local owner=$(echo "$action_info" | jq -r '.owner')
    local repo=$(echo "$action_info" | jq -r '.repo')
    local branch=$(echo "$action_info" | jq -r '.branch')
    local path=$(echo "$action_info" | jq -r '.path')
    local current_commit=$(echo "$action_info" | jq -r '.commit')
    local url=$(echo "$action_info" | jq -r '.url')

    log_info "Updating action: $action_name"

    # Clone latest version
    local dest_dir="$STORE_DIR/$action_name"
    rm -rf "$dest_dir"
    local new_commit=$(sparse_clone_folder "$owner" "$repo" "$branch" "$path" "$dest_dir")

    if [[ $? -ne 0 ]]; then
      exit 1
    fi

    if [[ "$new_commit" != "$current_commit" ]]; then
      add_to_lock_file "$action_name" "$url" "$owner" "$repo" "$branch" "$path" "$new_commit"
      log_success "Updated '$action_name' ($current_commit -> $new_commit)"
    else
      log_info "'$action_name' is already up to date"
    fi
  fi
}

# Command: list
cmd_list() {
  init_lock_file

  local count=$(jq -r '.actions | length' "$LOCK_FILE")

  if [[ "$count" -eq 0 ]]; then
    log_info "No actions installed"
    exit 0
  fi

  echo ""
  echo "Installed actions ($count):"
  echo ""

  for i in $(seq 0 $((count - 1))); do
    local name=$(jq -r ".actions[$i].name" "$LOCK_FILE")
    local url=$(jq -r ".actions[$i].url" "$LOCK_FILE")
    local commit=$(jq -r ".actions[$i].commit" "$LOCK_FILE")
    local short_commit="${commit:0:7}"

    echo "  • $name"
    echo "    URL: $url"
    echo "    Commit: $short_commit"
    echo ""
  done
}

# Command: remove
cmd_remove() {
  local action_name="$1"

  if [[ -z "$action_name" ]]; then
    log_error "Action name is required"
    echo "Usage: $0 remove <action-name>"
    exit 1
  fi

  init_lock_file

  local action_info=$(get_action_info "$action_name")

  if [[ -z "$action_info" ]]; then
    log_error "Action '$action_name' not found in lock file"
    exit 1
  fi

  # Remove directory
  local dest_dir="$STORE_DIR/$action_name"
  if [[ -d "$dest_dir" ]]; then
    rm -rf "$dest_dir"
    log_success "Removed directory: store/$action_name"
  fi

  # Remove from lock file
  remove_from_lock_file "$action_name"
  log_success "Removed '$action_name' from lock file"
}

# Main
main() {
  local command="$1"
  shift

  case "$command" in
    add)
      cmd_add "$@"
      ;;
    update)
      cmd_update "$@"
      ;;
    list|ls)
      cmd_list
      ;;
    remove|rm)
      cmd_remove "$@"
      ;;
    *)
      echo "Martillo Store CLI - Manage external store actions"
      echo ""
      echo "Usage: $0 <command> [options]"
      echo ""
      echo "Commands:"
      echo "  add <url>           Add an action from a GitHub URL"
      echo "  update [name]       Update action(s) (updates all if no name provided)"
      echo "  list                List all installed actions"
      echo "  remove <name>       Remove an action"
      echo ""
      echo "Examples:"
      echo "  $0 add https://github.com/sjdonado/idonthavespotify/tree/master/extra/martillo"
      echo "  $0 update idonthavespotify"
      echo "  $0 update"
      echo "  $0 list"
      echo "  $0 remove idonthavespotify"
      exit 1
      ;;
  esac
}

main "$@"
