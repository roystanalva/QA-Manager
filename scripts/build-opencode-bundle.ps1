#!/usr/bin/env pwsh
# Build the opencode bundle of qa-manager into a project's `.opencode/` directory.
#
# Used by /qa-setup (the engine-clone update path and project wiring): the repo's skills
# live under ./skills for development, but a consuming project loads them from
# `.opencode/skills/`. This script assembles that layout:
#
#   .opencode/skills/qa|qa-setup|qa-day   <- ./skills (SKILL.md, references, templates, scripts)
#   .opencode/agents/                     <- ./agents (mirrored; the validator also checks these)
#   .opencode/commands/                   <- static (./.opencode/commands)
#   .opencode/plugins/rename-session.js   <- static (./.opencode/plugins)
#   .opencode/engine.json                 <- version + upstream metadata for /qa-setup
#   .opencode/opencode.json              <- the engine's own defaults (skills.paths)
#   .opencode/PROFILE-CONTRACT.md         <- the contract, read by /qa and /qa-setup
#
# Usage: scripts\build-opencode-bundle.ps1 [<project root or path to .opencode dir>]
#   no argument -> the current directory's .opencode/
param(
    [string]$Project = (Get-Location)
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$target = $Project
if (-not (Test-Path -LiteralPath $target)) {
    throw "Project root not found: $target"
}
if ((Split-Path -Leaf $target) -eq ".opencode") {
    $dot = $target
} else {
    $dot = Join-Path $target ".opencode"
}
New-Item -ItemType Directory -Force -Path $dot | Out-Null

$sources = @{
    "skills"   = "skills"
    "agents"   = "agents"
    "commands" = ".opencode\commands"
    "plugins"  = ".opencode\plugins"
}

foreach ($sub in "skills", "agents", "commands", "plugins") {
    $src = Join-Path $root $sources[$sub]
    if (-not (Test-Path -LiteralPath $src)) { continue }
    $resolvedSrc = [System.IO.Path]::GetFullPath($src)
    $dst = Join-Path $dot $sub
    $resolvedDst = [System.IO.Path]::GetFullPath($dst)
    if ($resolvedSrc -eq $resolvedDst) { continue }  # running from the repo itself
    if (Test-Path -LiteralPath $dst) { Remove-Item -LiteralPath $dst -Recurse -Force }
    Copy-Item -LiteralPath $src -Destination $dst -Recurse
}

foreach ($file in "engine.json", "opencode.json", "PROFILE-CONTRACT.md") {
    $src = Join-Path $root $file
    if (Test-Path -LiteralPath $src) {
        Copy-Item -LiteralPath $src -Destination (Join-Path $dot $file) -Force
    }
}

Write-Host ("qa-manager bundle written to {0}" -f $dot)