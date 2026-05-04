#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
config_dir="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}"
backup_dir="$config_dir/backups/$(date +%Y%m%d-%H%M%S)"

dry_run=0
copy_mode=0

usage() {
  printf '%s\n' \
    "Usage: ./setup.sh [--dry-run] [--copy]" \
    "" \
    "Installs this repo's OpenCode config into: $config_dir" \
    "" \
    "Options:" \
    "  --dry-run   Show actions without changing files" \
    "  --copy      Copy files instead of creating symlinks"
}

while (($#)); do
  case "$1" in
    --dry-run)
      dry_run=1
      ;;
    --copy)
      copy_mode=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

run() {
  local cmd=("$@")
  printf '+ %q' "${cmd[0]}"
  for arg in "${cmd[@]:1}"; do
    printf ' %q' "$arg"
  done
  printf '\n'
  if [[ "$dry_run" -eq 0 ]]; then
    "${cmd[@]}"
  fi
}

ensure_dir() {
  local dir="$1"
  if [[ "$dry_run" -eq 1 ]]; then
    printf '+ mkdir -p %q\n' "$dir"
  else
    mkdir -p "$dir"
  fi
}

backup_path() {
  local path="$1"
  [[ -e "$path" || -L "$path" ]] || return 0
  local rel="${path#$config_dir/}"
  ensure_dir "$backup_dir/$(dirname "$rel")"
  if [[ "$dry_run" -eq 1 ]]; then
    printf '+ mv %q %q\n' "$path" "$backup_dir/$rel"
  else
    mv "$path" "$backup_dir/$rel"
  fi
}

install_path() {
  local src="$1"
  local dst="$2"

  ensure_dir "$(dirname "$dst")"

  if [[ -L "$dst" ]]; then
    local target
    target="$(readlink "$dst")"
    if [[ "$target" == "$src" ]]; then
      printf '= already linked: %s -> %s\n' "$dst" "$src"
      return 0
    fi
  fi

  backup_path "$dst"

  if [[ "$copy_mode" -eq 1 ]]; then
    if [[ -d "$src" ]]; then
      if [[ "$dry_run" -eq 1 ]]; then
        printf '+ cp -R %q %q\n' "$src" "$dst"
      else
        cp -R "$src" "$dst"
      fi
    else
      run cp "$src" "$dst"
    fi
  else
    run ln -s "$src" "$dst"
  fi
}

write_opencode_json() {
  local dst="$config_dir/opencode.json"
  ensure_dir "$config_dir"
  backup_path "$dst"

  if [[ "$dry_run" -eq 1 ]]; then
    printf '+ write %q\n' "$dst"
    return 0
  fi

  cat > "$dst" <<JSON
{
  "\$schema": "https://opencode.ai/config.json",
  "instructions": [
    "$config_dir/instructions/global-chinese.md"
  ]
}
JSON
}

printf 'Installing OpenCode config from: %s\n' "$repo_dir"
printf 'Target OpenCode config dir: %s\n' "$config_dir"

ensure_dir "$config_dir"
ensure_dir "$config_dir/instructions"
ensure_dir "$config_dir/skills"

install_path "$repo_dir/global-chinese.md" "$config_dir/instructions/global-chinese.md"

if [[ -d "$repo_dir/skills" ]]; then
  for src in "$repo_dir"/skills/*; do
    [[ -d "$src" ]] || continue
    install_path "$src" "$config_dir/skills/$(basename "$src")"
  done
fi

write_opencode_json

printf '\nOpenCode config setup complete.\n'
printf 'Restart OpenCode to pick up skill changes.\n'
printf 'Try the split-task skill via slash in OpenCode.\n'

if [[ -d "$backup_dir" ]]; then
  printf 'Backups written to: %s\n' "$backup_dir"
fi
