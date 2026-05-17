#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
claude_skills_dir="${CLAUDE_CODE_SKILLS_DIR:-$HOME/.claude/skills}"

dry_run=0
copy_mode=0

usage() {
  printf '%s\n' \
    "Usage: ./install-to-claude-code.sh [--dry-run] [--copy]" \
    "" \
    "Installs all skills from this repo into Claude Code at:" \
    "  $claude_skills_dir/<skill-name>/" \
    "" \
    "Options:" \
    "  --dry-run   Show actions without changing files" \
    "  --copy      Copy files instead of creating symlinks (default: symlink)"
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

install_skill() {
  local skill_name="$1"
  local src="$repo_dir/skills/$skill_name"
  local dst="$claude_skills_dir/$skill_name"

  if [[ ! -d "$src" ]]; then
    printf 'ERROR: skill not found: %s\n' "$src" >&2
    return 1
  fi

  printf '\nInstalling skill: %s\n' "$skill_name"
  printf '  Source: %s\n' "$src"
  printf '  Target: %s\n' "$dst"

  ensure_dir "$(dirname "$dst")"

  # Remove existing symlink or directory if present
  if [[ -L "$dst" ]]; then
    local target
    target="$(readlink "$dst")"
    if [[ "$target" == "$src" ]]; then
      printf '  = already linked: %s -> %s\n' "$dst" "$src"
      return 0
    fi
    printf '  - removing old symlink: %s -> %s\n' "$dst" "$target"
    if [[ "$dry_run" -eq 0 ]]; then
      rm "$dst"
    fi
  elif [[ -d "$dst" ]]; then
    printf '  - removing old directory: %s\n' "$dst"
    if [[ "$dry_run" -eq 0 ]]; then
      rm -rf "$dst"
    fi
  fi

  if [[ "$copy_mode" -eq 1 ]]; then
    run cp -R "$src" "$dst"
  else
    run ln -s "$src" "$dst"
  fi
}

printf 'Installing skills to Claude Code\n'
printf 'Repo dir:       %s\n' "$repo_dir"
printf 'Claude skills:  %s\n' "$claude_skills_dir"
printf 'Mode:           %s\n' "$([[ "$copy_mode" -eq 1 ]] && echo 'copy' || echo 'symlink')"

if [[ -d "$repo_dir/skills" ]]; then
  for src in "$repo_dir"/skills/*; do
    [[ -d "$src" ]] || continue
    install_skill "$(basename "$src")"
  done
fi

printf '\nDone. Skills are now available in Claude Code.\n'
printf 'Restart Claude Code or start a new session to pick up the skill.\n'
printf 'You can invoke skills with slash commands in Claude Code.\n'
