# Port notes — qa-manager from Claude Code plugin to opencode engine

This file records how the exact copy was produced and where the non-obvious decisions
live. It is not part of the engine's runtime payload; it exists for whoever revisits the
port. Read it next to `README.md`, `CONTRIBUTING.md` and `skills/qa/SKILL.md`.

## What was ported and what was kept

`qa-manager` is the opencode port of the upstream Claude Code plugin (version 0.16.28),
delivered from `roystanalva/QA-Manager`, made to run as an opencode engine. **Behavior and
content are the port; the mechanism is the change.** The rules
an agent follows (profile contract, session file scheme, pipeline, retros, evals) are byte-for-
byte upstream except the mechanical renames below. The wiring that made it a Claude plugin is
replaced by opencode wiring.

The repo is the engine's source of truth. A project consumes it one of two ways:

- `opencode --skills <clone>/skills` — the repo's own development layout;
- the bundle — `scripts/build-opencode-bundle.{ps1,sh}` assembles `.opencode/skills/`,
  `.opencode/engine.json` and `.opencode/PROFILE-CONTRACT.md` into a project, which is what
  `/qa-setup`'s update/reconcile steps and the engine-clone flow operate on
  (`<engine-clone>` → pull → re-run `/qa-setup`).

## The mapping, file for file

| Claude Code side | opencode side | Notes |
|---|---|---|
| `.claude-plugin/plugin.json` | `engine.json` (repo root) | version is the single source; skill files reference it as `../../engine.json` |
| `.claude-plugin/marketplace.json` | — | the repo is now the delivery channel; version-compare/issue links point at `roystanalva/QA-Manager` |
| `.claude/skills/…` | `skills/…` in the repo, `.opencode/skills/…` in a project | scripts invoked as `.opencode/skills/qa/scripts/check_session.py` |
| `.claude/settings*.json` | `opencode.json` | skills.paths → ./skills (dev); a project overrides with its own opencode.json |
| `.claude/qa-profile.md` | `.opencode/qa-profile.md` | the profile contract (PROFILE-CONTRACT.md) agreement itself is unchanged |
| `~/.claude/plugins/` | the project's `.opencode/` | there is no separate install cache; the installed copy IS the project's `.opencode/` |
| `CLAUDE.md` | `AGENTS.md` | the thin-file rule moves verbatim |
| `hooks/` (Claude Code hooks.json + rename-session.sh) | `.opencode/plugins/rename-session.js` | see «The rename hook» below |
| `agents/*.md` | `agents/*.md` (source) + `.opencode/agents/*.md` (mirror) | opencode resolves `subagent_type` against `.opencode/agents/` |

## The rename hook

The upstream renamed a session to the task number via a Claude Code hook with two launch
paths: the `/qa …` slash command (UserPromptSubmit) and the `Skill` tool (PreToolUse). Its
opencode replacement lives at `.opencode/plugins/rename-session.js` and listens on the two
opencode equivalents:

- the `command.executed` **event** for the `qa` / `qa-manager:qa` commands
  (`properties.name`, `properties.sessionID`, `properties.arguments`);
- the `tool.execute.before` **hook** for the `skill` tool (`input.tool`,
  `input.sessionID`, `output.args`).

Two deliberate differences, both worth knowing when the plugin is edited:

- opencode's Skill tool takes only `{ name }` — there is no free-text task argument in the
  tool call, so the skill-tool path reads the number from `output.args.arguments`
  (`arguments` first, then `args` — the shape differs between versions of the SDK);
- `stageN` is dropped before the number is read («ACME-449 on stage3» must rename to task
  449, not task 3), and the last number wins over the first (a URL's first number is
  often the group id).

The session is renamed via `client.session.update`: `{ path: { id: sessionID }, body:
{ title: "Task <num>" } }`.

## Versioning

- `engine.json` version: 0.16.28 (carried over unchanged from upstream — no engine
  behavior changed, so no bump).
- The version-compare fetch in `/qa` and `/qa-setup` reads
  `https://raw.githubusercontent.com/roystanalva/QA-Manager/main/engine.json`.
- Release tags must equal the `version` in `engine.json` (enforced by
  `.github/workflows/release.yml`); `/qa-setup` reads `engine.json`, never a tag.

## Sweeps done mechanically

A single targeted pass over the whole tree replaced:

- `CLAUDE_PLUGIN_ROOT` references → `.opencode` (script invocations became
  `.opencode/skills/…`);
- `.claude/qa-profile.md` → `.opencode/qa-profile.md`; `.claude/qa-profile/` →
  `.opencode/qa-profile/`; `.claude/skills/` → `.opencode/skills/`;
- `.claude/settings*.json`/`.claude/settings.json` → `opencode.json`;
- `.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json` → `engine.json`;
- `~/.claude/plugins/` → `.opencode/`;
- `.claude` (loose) → `.opencode`;
- `CLAUDE.md` → `AGENTS.md`.

Then `python3 .github/scripts/validate-engine.py` (ex-`validate-plugin.py`) was hand-ported:
the plugin.json/marketplace.json/hooks checks became the `.opencode` wiring checks
(commands, plugins, agents), and `subagent_type` values are validated against the
`.opencode/agents/` mirror. `validate-engine.py` now reads files as utf-8 everywhere so it
runs on Windows too.

A separate pass rebranded the engine to `qa-manager` (product name,
`engine.json` `name`, README, CONTRIBUTING, CHANGELOG, skill/command prose, validator and
script output strings, release zip names, and the plugin's and hook's namespaced command
form). The `engine.json` `homepage`/`repository` fields now point at the delivery repo
`roystanalva/QA-Manager`; the version stayed 0.16.28 because no behavior changed.

## Files touched after the mechanical pass (hand review)

- `README.md` — install flow, structure tree, engine-clone semantics, star/issue links all
  re-pointed at opencode and `roystanalva/QA-Manager`.
- `skills/qa-setup/SKILL.md` — updates flow (git pull + `/qa-setup` instead of plugin
  updates), `opencode mcp list/add`, `question` tool for `AskUserQuestion`, the
  engine-clone guard reads `.opencode/`.
- `skills/qa/SKILL.md` — retro step-7 engine-address block, degradation table, the version
  check, `engine-feedback.md` header.
- `CHANGELOG.md` — a head entry for 0.16.28 documents the port; older entries are history
  and keep their original wording.
- `CONTRIBUTING.md` — edit/release mechanics for the new install model; evals are run by
  hand in opencode.
- `evals/README.md` and the case fixtures — `.opencode/qa-profile.md`, engine-clone paths,
  and a hand-run eval flow (no `claude plugin eval` equivalent exists; each case is a real
  opencode session graded against `case.yaml`).
- `.github/workflows/{validate,release}.yml`, `.github/ISSUE_TEMPLATE/bug_report.yml` —
  `engine.json` paths, no `claude plugin …` in prose.
- `tests/test_check_session.py` — the corpus also walks `.opencode/agents` and
  `.opencode/commands`.
- `hooks/hooks.json` — **kept byte-for-byte upstream** (Claude Code form) as a reference,
  since opencode does not read it; the active mechanism is the plugin.
- `hooks/rename-session.sh` — kept as reference; the command namespace inside matches the
  rebranded plugin (`qa-manager:qa`).
- `.gitignore` — `CLAUDE.md` → `AGENTS.md`; added `__pycache__/` (mechanical, so test runs
  do not dirty the tree).

## Verified

- `python3 .github/scripts/validate-engine.py` → `✔ qa-manager 0.16.28: 3 skill(s), 3
  agent(s), 3 command(s), 1 plugin(s), structure is consistent`.
- `python3 -m unittest discover -s tests` → 66 tests, OK.
- `python3 .github/scripts/check_identifiers.py` over engine files, commit-message texts and
  the ci workflows — clean.
- `scripts/build-opencode-bundle.ps1` end-to-end: assembles `.opencode/` exactly as
  `/qa-setup` expects.

## What was not verified

Runtime behavior in a live opencode session: the `opencode` CLI is not installed on the
working machine, so the plugin (event shape, hook shape, `session.update` call) is verified
against the published opencode SDK types and docs, not against a running session. The
first `/qa-setup` run in a real project is the acceptance test.

## The QA Web Analyzer exe (unrelated to this port)

`qa-analyzer.exe` is a packaged build of the QA Web Analyzer app (Node 18 win-x64 via
`pkg`), fully smoke-tested: `admin/admin123` login, projects API, index page, CSV export
(`text/csv; charset=utf-8`), XLSX export (15 777 bytes), sqlite DB initialization, no stderr
output, and it persists `data/` + `uploads/` next to the exe. Runtime dirs are gitignored.