#!/usr/bin/env bash
# Build the opencode bundle of qa-manager into a project's `.opencode/` directory.
#
# Used by /qa-setup (the engine update path and project wiring): the repo's skills
# live under ./skills for development, but a consuming project loads them from
# `.opencode/skills/`. This script assembles that layout:
#
#   .opencode/skills/qa|qa-setup|qa-day   <- ./skills (SKILL.md, references, templates, scripts)
#   .opencode/agents/                     <- ./agents (mirrored; the validator also checks these)
#   .opencode/commands/                   <- static
#   .opencode/plugins/rename-session.js   <- static
#   .opencode/engine.json                 <- version + upstream metadata for /qa-setup
#   .opencode/opencode.json               <- the engine's own defaults (skills.paths)
#   .opencode/PROFILE-CONTRACT.md         <- the contract, read by /qa and /qa-setup
#
# Usage: scripts/build-opencode-bundle.sh [<project root or path to .opencode dir>]
#   no argument -> the current directory's .opencode/
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
target="${1:-$(pwd)}"

if [[ "$(basename "$target")" == ".opencode" ]]; then
  dot="$target"
else
  dot="$target/.opencode"
fi
mkdir -p "$dot"

for sub in skills agents commands plugins; do
  case "$sub" in
    skills)  src="$root/skills";;
    agents)  src="$root/agents";;
    commands) src="$root/.opencode/commands";;
    plugins) src="$root/.opencode/plugins";;
  esac
  if [[ ! -d "$src" ]]; then continue; fi
  rm -rf "$dot/$sub"
  cp -R "$src" "$dot/$sub"
done

for file in engine.json opencode.json PROFILE-CONTRACT.md; do
  if [[ -f "$root/$file" ]]; then
    cp -f "$root/$file" "$dot/$file"
  fi
done

echo "qa-manager bundle written to $dot"