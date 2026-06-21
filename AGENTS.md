# Python Package Template — project instructions

Authoritative shared instructions for humans and coding agents. How each product loads this repo: [Coding agents & instruction files](#coding-agents--instruction-files).

## Project overview

Python package template. Tooling:

- **Package manager**: [uv](https://github.com/astral-sh/uv) (via `requirements.setup.txt`, not mise)
- **CLI toolchain**: [mise](https://mise.jdx.dev/) — Trunk, Trivy, OSV-Scanner, Grype, CodeQL (`mise.toml` [tasks], `mise.lock`, `minimum_release_age = "7d"`)
- **Build system**: [Hatchling](https://hatch.pypa.io/latest/)
- **Linting/formatting**: [Trunk](https://trunk.io/) (Ruff, Pyright, Pylint, Bandit, Semgrep; Ruff is the formatter; Black is not used)
- **Testing**: [pytest](https://docs.pytest.org/)
- **Python**: 3.10+ (see `.python-version` for the pinned version)

## Quick commands

```bash
make setup-tools  # mise: trunk, trivy, osv-scanner, grype, codeql (+ trunk install)
make setup        # setup-tools + Python venv (uv sync)
make setup-python # Python venv only (skip CLI toolchain)
make lint         # mise run lint (Trunk check)
make lint-python  # Same as `make lint`
make format       # mise run format-trunk + uv ssort
make dead-code    # Find unused code with Vulture (see pyproject [tool.vulture])
make vulture      # Same as make dead-code
make test         # Run pytest with coverage (pytest-cov); alias: `make coverage`
make codeql       # Run local CodeQL analysis
make build        # Build the package
make clean        # Clean build artifacts
```

## Mise toolchain (local vs CI)

- **Local / agents:** Install [mise](https://mise.jdx.dev/) on `PATH`, then `make setup-tools` or `make setup`. Commands use **`mise run <task>`** from `mise.toml`—there is **no** `dev/mise-exec.sh` or other shell wrapper to invoke mise.
- **CI:** [`.github/workflows/mise_toolchain.yml`](.github/workflows/mise_toolchain.yml) runs `jdx/mise-action` and `dev/test-mise-toolchain.sh`. Lint in PRs still uses [Trunk Action](.github/workflows/trunk_check.yml); Python tests use [uv](.github/workflows/test.yml).
- **`make setup-python`** works without mise (Python/uv only). **`make setup`** requires mise because it runs `setup-tools` first.

## Code style

- Follow the Google Python Style Guide (see `.pylintrc`)
- Use type hints for all public functions
- Imports sorted by Ruff (rule `I`)
- Max line length: 100 characters (Ruff)
- `snake_case` for functions and variables, `PascalCase` for classes

## Testing

- Tests live under `src/your_package/tests/` (colocated with the package)
- Test files must match `test_*.py`
- Run `make test` before commits
- Aim for meaningful coverage on critical paths

## Security

- **Static analysis**: Trunk runs Ruff, **Pyright** (types), Pylint, Bandit, Semgrep, and Trivy for quick feedback
- **Deep analysis**: [GitHub CodeQL](https://codeql.github.com/) path analysis (see `.github/workflows/codeql.yml`)
- **Dependencies**: OSV-Scanner, Trivy, and Grype (`make scan-vulnerabilities`; runs serially via mise; versions from mise)
- **Local CodeQL**: `make codeql` (CodeQL CLI via mise); on **Linux or macOS ARM64**, `make setup-tools` skips the CodeQL version check (x64 bundle in `mise.lock`)
- **`make scan-vulnerabilities`:** OSV-Scanner exits **1** when it reports vulnerabilities (expected); fix deps or document accepted risk.
- Use `trunk check` before pushing

## AI guardrails & code quality

- **Cyclomatic complexity**: max **10** per function (Ruff `C901`)
- **Maintainability**: CodeQL `security-and-quality` tracks long-term health
- If an edit pushes complexity over **10**, refactor into smaller functions before finishing

## Session postmortem (coding agents)

- **Purpose:** After a substantive session, run a retrospective so failures and inefficiencies surface as ranked **Must / Should / Consider** improvements. Template: [`.agents/skills/postmortem/references/postmortem-report-template.md`](.agents/skills/postmortem/references/postmortem-report-template.md).
- **Invocation:** Invoke the `postmortem` skill (e.g. **`/postmortem`** in Claude Code). Load from [`.claude/skills/postmortem/`](.claude/skills/postmortem/) or [`.agents/skills/postmortem/`](.agents/skills/postmortem/) depending on your tool. Keep output **in chat** unless the user asks to persist; the skill does not authorize editing `AGENTS.md`, `CLAUDE.md`, or skills without a separate request.
- **Skip:** Do **not** run after purely mechanical work with no learning signal (e.g. obvious typo, format-only pass, trivial dependency bump with no retries). If the session included debugging, ambiguity, or retries, run a postmortem anyway.

## Git workflow

- Branch from `main`
- Run `make lint && make test` before commits
- Conventional commits: `type(scope): description` (e.g. `feat(api): add user endpoint`)
- Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`
- For releases, record changes with the `manage-changelog` skill when [Changie](https://changie.dev/) is available (fragments, batch, merge into `CHANGELOG.md`)

## Architecture

- Package source: `src/your_package/` (rename when initializing a real project)
- Dev scripts: `dev/`
- CI/CD: `.github/workflows/`
- **Claude Code** automation: [`.claude/`](.claude/) — see [CLAUDE.md](CLAUDE.md) for how Claude loads this repo and the directory layout
- **Architecture decision records** (ADRs): `docs/adr/`. Use the `manage-adr` skill when the `adr` CLI is installed

## Common gotchas

- **Do not** add shell wrappers (e.g. `mise-exec.sh`) to call mise; use `mise.toml` `[tasks]` and `mise run`.
- After clone: run `mise trust`, then `mise install --locked` (or `make setup-tools` / `make setup`); workflows are `[tasks]` in `mise.toml` (`mise run lint`, `mise tasks`)
- Refresh the toolchain lock with `mise lock` and commit `mise.lock` when bumping CLI tools
- Keep mise scanner versions aligned with `.trunk/trunk.yaml` (Trivy, OSV-Scanner) when bumping either side
- Run Python tools with `uv run …` in the project virtualenv
- Trunk pins linter versions under `.trunk/`; `make setup-tools` runs `mise run trunk-install`
- Commit `uv.lock` and `mise.lock` (do not gitignore them)
- If `mise install --locked` fails locally, extra tools in `~/.config/mise/config.toml` may be missing from `mise.lock`; `make setup-tools` retries without `--locked`, or run `MISE_LOCKED=false mise install`

- If Trunk errors about a missing managed linter, run `mise run trunk-install` (via `make setup-tools`)

## Parallel or multi-step work (Claude Code)

- This repo does **not** ship a built-in parallel orchestration subagent. For concurrent work, use multiple Task invocations, your editor’s multi-agent features, or your own scripts.
- Pick the orchestrator by scope — do not mix template QA with ADK lifecycle work:

| Subagent           | Use when                                                                  |
| ------------------ | ------------------------------------------------------------------------- |
| `verifier`         | Template repo QA: build, lint, test, dependency CVE scan, CodeQL          |
| `agent-cli-master` | ADK agent lifecycle: scaffold → build → eval → deploy → publish → observe |

- After substantial or overlapping edits to **this template**, use **`verifier`** ([.claude/agents/verifier.md](.claude/agents/verifier.md)) — it delegates to `build-and-fix`, `lint-and-fix`, `test-and-fix`, `security-scan`, and `codeql-fix`.
- For **Google ADK / agents-cli** work, use **`agent-cli-master`** ([.claude/agents/agent-cli-master.md](.claude/agents/agent-cli-master.md)). It runs Phases 0–7 via preloaded `google-agents-cli-*` skills. Requires `agents-cli` on `PATH` (`uv tool install google-agents-cli`).

## Claude Code subagents

Invoked from Claude Code (Task tool or slash flows). Definitions: [`.claude/agents/*.md`](.claude/agents/)

- **`verifier`** — Five-phase verification via preload skills; see [.claude/agents/verifier.md](.claude/agents/verifier.md).
- **`agent-cli-master`** — ADK lifecycle orchestrator (Phases 0–7) via preloaded `google-agents-cli-*` skills; see [.claude/agents/agent-cli-master.md](.claude/agents/agent-cli-master.md).

## Claude Code skills

Slash-invoked skills live under [`.claude/skills/<name>/SKILL.md`](.claude/skills/). Use a skill when it matches the task; each `SKILL.md` lists prerequisites (some require a CLI on `PATH`). Skills cite this file and `Makefile` targets rather than linking peer-to-peer to other `SKILL.md` files.

| Skill                             | When to use                                                                  |
| --------------------------------- | ---------------------------------------------------------------------------- |
| `build-and-fix`                   | Build or packaging failures                                                  |
| `check-directory-structure`       | After bulk edits; audit layout; fix flat/misplaced files                     |
| `codeql-fix`                      | Local CodeQL (`make codeql`); requires CodeQL CLI                            |
| `lint-and-fix`                    | Trunk / linter failures                                                      |
| `test-and-fix`                    | Failing tests                                                                |
| `setup-dev-env`                   | First-time or broken environment                                             |
| `python-upgrade`                  | Dependency upgrades with uv                                                  |
| `security-scan`                   | Trivy / OSV / Grype (`make scan-vulnerabilities`)                            |
| `initialize-project`              | Renaming the template and bootstrapping                                      |
| `manage-adr`                      | ADRs in `docs/adr` (requires `adr` CLI)                                      |
| `postmortem`                      | Substantive session end; incidents; skip trivial chore-only sessions         |
| `problem-solving`                 | Single-pass XY-aware analysis and scored comparison (default 5 options)      |
| `deep-problem-solving`            | Same style of report after **ten** multiple-choice questions (one per turn)  |
| `google-agents-cli-workflow`      | ADK lifecycle entry point, Phase 0 spec, coding rules; requires `agents-cli` |
| `google-agents-cli-scaffold`      | `scaffold create` / `enhance` / `upgrade`; architecture and template flags   |
| `google-agents-cli-adk-code`      | Agent code: tools, callbacks, state, ADK Python API patterns                 |
| `google-agents-cli-eval`          | Eval datasets, metrics, eval-fix loop (**mandatory before deploy**)          |
| `google-agents-cli-deploy`        | Deploy targets, CI/CD, Terraform, production troubleshooting                 |
| `google-agents-cli-publish`       | Register with Gemini Enterprise (optional, post-deploy)                      |
| `google-agents-cli-observability` | Traces, logging, BigQuery analytics (post-deploy)                            |

**Google ADK skills** live under [`.claude/skills/agent-cli/`](.claude/skills/agent-cli/) (Claude Code) and [`.agents/skills/agent-cli/`](.agents/skills/agent-cli/) (Cursor and other tools). In Claude Code, prefer delegating full lifecycle work to **`agent-cli-master`** rather than loading skills ad hoc.

Some tools load mirrored skills under `.agents/skills/` instead of `.claude/`. Other repos may add `manage-changelog` when Changie is configured (see **Git workflow**).

## Coding agents & instruction files

| Product / channel                                   | How this repo is wired                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| --------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Cursor**                                          | Loads root [AGENTS.md](AGENTS.md) and root [CLAUDE.md](CLAUDE.md) for Agent chat (and optional `.cursor/rules/`). [Cursor: Rules](https://cursor.com/docs/rules)                                                                                                                                                                                                                                                                                                                                    |
| **OpenAI Codex**                                    | Merges `~/.codex/AGENTS.md` (or override) with repo [AGENTS.md](AGENTS.md) along the path; default size cap (often 32 KiB) applies to the combined project doc. Project overrides (e.g. `sandbox_mode`, `approval_policy`, `[sandbox_workspace_write]`) can live in [`.codex/config.toml`](.codex/config.toml) when the project is trusted. [Codex: AGENTS.md](https://developers.openai.com/codex/guides/agents-md/), [Codex: Sandboxing](https://developers.openai.com/codex/concepts/sandboxing) |
| **Claude Code**                                     | Reads [CLAUDE.md](CLAUDE.md) (which inlines this file) plus [`.claude/`](.claude/). [Anthropic: CLAUDE.md](https://docs.anthropic.com/en/docs/claude-code/claude-md), [Claude directory](https://code.claude.com/docs/en/claude-directory)                                                                                                                                                                                                                                                          |
| **Gemini CLI**                                      | Project [`.gemini/settings.json`](.gemini/settings.json) includes `AGENTS.md` in `context.fileName` with typical `GEMINI.md` handling. [Gemini: context](https://geminicli.com/docs/cli/gemini-md/)                                                                                                                                                                                                                                                                                                 |
| **GitHub Copilot** (Chat, code review, cloud agent) | Treats root `AGENTS.md` (and `CLAUDE.md` / `GEMINI.md` if present) as **agent instructions**; may also use `.github/copilot-instructions.md` and path-scoped files with defined precedence. [Custom instructions](https://docs.github.com/en/copilot/concepts/prompting/response-customization)                                                                                                                                                                                                     |

**Copilot / GitHub.com:** This repo does not add `.github/copilot-instructions.md`; build, test, and style narrative stay in this file. On GitHub.com, personal instructions override repository content, then path-scoped rules and `copilot-instructions.md` apply (see [Custom instructions](https://docs.github.com/en/copilot/concepts/prompting/response-customization)). **Edit policy:** shared rules here; Claude Code-only behavior, `@AGENTS.md` import, and `.claude/` details in [CLAUDE.md](CLAUDE.md).

### Where things live (quick map)

- **This file** — Stack, `make` targets, style, testing, security, git, ADR pointers, Claude subagent/skill tables
- **[CLAUDE.md](CLAUDE.md)** + **[`.claude/`](.claude/)** — Claude Code entrypoint and automation layout (see CLAUDE.md for directory breakdown and self-improvement rules)
- **`.claude/skills/agent-cli/`** — Google Agents CLI skills (`google-agents-cli-*`); mirrored under **`.agents/skills/agent-cli/`**
- **`.claude/agents/agent-cli-master.md`** — Claude Code subagent orchestrating those skills
- **`.agents/skills/`** — Skills for tools that do not read `.claude/` (e.g. `postmortem`); may mirror `.claude/skills/`
- **`.gemini/settings.json`** — Gemini CLI project context
- **`.cursor/rules/`** — Optional Cursor rules (e.g. Always Apply); see [Cursor: Rules](https://cursor.com/docs/rules)
- **[`.codex/config.toml`](.codex/config.toml)** — Optional Codex defaults (sandbox, approvals); links above under **OpenAI Codex**

## Learned User Preferences

- Delegate Google ADK / Agent Platform mesh work to **`agent-cli-master`** (Task tool); use **`verifier`** only for root template QA, not mesh deploy or governance.
- Prefer **spawning subagents** for specialized or parallel work (gateway research, redeploy, governance scripts) instead of doing everything inline in one session.
- Enterprise mesh delivery uses **`/loop` + `agent-cli-master`** until acceptance criteria in `docs/notes/ACCEPTANCE.md` are met.
- **Commit (and push when requested) after each completed TODO** on enterprise mesh milestones, not batched at the end.

## Learned Workspace Facts

- Enterprise **trip-planner A2A mesh** lives under `src/trip-planner`, `src/flight-researcher`, and `src/hotel-researcher`, deployed to Agent Platform in **`yexperiment` / `asia-northeast1`**.
- Orchestration uses ADK **`RemoteA2aAgent` sub-agents** with bundled AgentCards; **platform IAP, Agent Registry, and Agent Gateway** enforce governance (Python `mesh_auth` was removed in the A2A refactor).
- Deploy order is **flight-researcher → hotel-researcher → trip-planner** with **`--agent-identity`**; set **`GOOGLE_CLOUD_LOCATION=global`** on all three agents for **`gemini-3.1-flash-lite`**.
- Outbound A2A from trip-planner uses **`trip-planner-sa`** until **M3-2b** registry bindings exist (`AUTH_PROVIDER_BINDING` for OAuth auth provider).
- Mesh governance scripts: `terraform/scripts/apply_mesh_governance.sh`, `resolve_iap_policies.sh`, `setup_agent_gateway.sh`, and readiness gate **`check_mesh_gateway_status.sh`**; gateways **`mesh-egress-gateway`** and **`mesh-ingress-gateway`** exist in `yexperiment`.
- Registry **trip-planner→specialist bindings are skipped** until `AUTH_PROVIDER_BINDING` is set; IAP egress uses **`--resource-type=agent-registry`** with registry UIDs from `terraform/registry/mesh-agents.env`.
- Agent **unit tests run per package**: `cd src/<agent> && uv run pytest tests/unit/` (combined root-level pytest fails on import paths).
- Junior curriculum is layered in **`docs/guides/00-overview.md` through `05-gateway-policy-demo.md`**.
