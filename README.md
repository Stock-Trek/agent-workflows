# agent-workflows

A GitHub Actions workflow that runs an AI coding agent (via [pi](https://www.npmjs.com/package/@mariozechner/pi-coding-agent)) on issues and PR comments. When someone mentions `@agent`, the workflow classifies the request, asks for any missing information, and — when it can — fixes the issue in code, opens a PR and replies on the issue.

This repository is the canonical source for the workflow and is designed to be **copied into other repositories in the same organisation**. The `copying.md` file describes what to change when copying.

## How it works

```
issue / PR comment mentioning @agent
        │
        ▼
   ┌─ triage ──────────────────────────────────────────────┐
   │ 1. Authenticate (Infisical secrets + GitHub App token)│
   │ 2. React 👀 / clear old reactions                     │
   │ 3. Classify request type (schema-validated)           │
   └────────────┬──────────────────────────────────────────┘
                │
     ┌──────────┼──────────────┬───────────────┬───────────────┐
     ▼          ▼              ▼               ▼               ▼
   SPAM      OTHER         QUESTION/      CAN_IGNORE      BUG_FIX/
   (👍-1)   (🤔 + ask)    INVESTIGATION/  (nothing)       CHANGE_REQUEST/
                          FEATURE_REQUEST                 FEATURE_REQUEST
                          └──────────────┬───────────────────────┘
                                         ▼
                                   ┌─ respond ─────────────────────────────┐
                                   │ classify response                     │
                                   │  ├ ALREADY_ADDRESSED  → reply + diff  │
                                   │  ├ REQUIRES_HUMAN     → reply         │
                                   │  ├ REQUIRES_MORE_INFO → ask questions │
                                   │  └ CAN_ADDRESS_FULLY                 │
                                   │      ├ agent fixes code on branch     │
                                   │      ├ commit + push                  │
                                   │      └ open/reuse PR + reply          │
                                   └───────────────────────────────────────┘
                                        │
                                        ▼
                                 notify-failure (⚠️ on any failure)
```

Key design properties:

- **Serialised per issue** — a `concurrency` group per issue prevents two `@agent` mentions (or an edit re-trigger) from racing on the same branch.
- **Schema-validated model output** — every model call is constrained by a JSON schema, with a hard-coded fallback so users always get a visible reply instead of a silent no-op.
- **Re-runnable** — existing issue branches and open PRs are reused, and a failure comment tells the user to just mention `@agent` again.
- **PR comments are supported** — a comment on a PR is handled the same way as an issue comment (the PR is "addressed" rather than "closed").

## Repository layout

| Path | Purpose |
| --- | --- |
| `.github/workflows/agent.yml` | The main workflow (triage → respond → notify-failure) |
| `.github/workflows/lint.yml` | CI that validates the workflow/action YAML, JSON schemas and shell scripts |
| `.github/actions/authenticate/` | Infisical secrets + GitHub App token + checkout (shared by every job) |
| `.github/actions/checkout-branch/` | Checkout an issue branch, creating it if required |
| `.github/actions/emoji-react/`, `remove-emoji-reactions/` | Manage 👍/👀/🤔 reactions on issues/comments |
| `.github/actions/gather-issue-branches/` | Compute the `agent/issue-<n>` branch name |
| `.github/actions/set-up-deepseek-via-pi/` | Install pi and configure the DeepSeek provider |
| `.github/actions/question-pi/` | Ask pi a single question with a schema-validated JSON answer |
| `.github/actions/invoke-pi/` | Run pi as a coding agent to address the issue |
| `.github/prompts/` | The prompts used by pi for each classification/response |
| `.github/schemas/` | JSON schemas that constrain and validate model responses |
| `copying.md` | What to change when copying the workflow to another repository |

## Prerequisites

1. **A GitHub App** ("agent helper") installed on the repository, with permission to read/write issues, pull requests and contents, and to create comments/reactions.
2. **An Infisical project** with the following secrets:
   - `GITHUB_APP_AGENT_HELPER_CLIENT_ID` — GitHub App client ID
   - `GITHUB_APP_AGENT_HELPER_PRIVATE_KEY` — GitHub App private key
   - `DEEPSEEK_API_KEY` — DeepSeek API key
3. **An Infisical machine identity** configured for OIDC federation with GitHub Actions, with access to the project above.

## Configuration

The workflow runs without configuration in this repository. When copying it, everything organisation-specific is configurable via **repository variables** (no code edits required):

| Variable | Default | Purpose |
| --- | --- | --- |
| `INFISICAL_IDENTITY_ID` | `29578305-…` (this repo) | Infisical machine identity ID |
| `INFISICAL_PROJECT_SLUG` | `agent-editor` | Infisical project slug |
| `AGENT_GIT_USER_EMAIL` | `agent@stock-trek.com` | Git author email for agent commits |
| `AGENT_GIT_USER_NAME` | `Stock-Trek Agent` | Git author name for agent commits |

The Infisical identity and project only need to be configured **once**, in the shared `.github/actions/authenticate/` action, rather than in every job.

## Copying to a new repository

1. Copy the whole `.github/` directory and `copying.md` into the target repository.
2. Install the GitHub App and set up the Infisical identity/project as described in [Prerequisites](#prerequisites).
3. Set the repository variables listed in [Configuration](#configuration) to the target values (or leave the defaults if they match).
4. Push and mention `@agent` in an issue to smoke-test.

See `copying.md` for additional notes.

## Security notes

- **Secrets never appear in workflow inputs or logs.** The DeepSeek API key is read from the environment and written to the pi config with `jq`; it is never passed through a `with:` input or interpolated into a shell script.
- **Least-privilege tokens.** The default `GITHUB_TOKEN` is restricted to read-only at the top of the workflow; each job grants only the permissions it needs, and all repository mutations use the GitHub App token.
- **Script-injection hardening.** Event data (issue titles, etc.) is passed to shell scripts via environment variables, and multi-line model output is written with random heredoc delimiters so it cannot truncate or inject into the script.
- **Sensitive issue content is not logged.** The issue body/history is only passed to the model via base64; workflow logs (which can be public) never contain it.

## Development

Push any change and the `Lint` workflow validates it: `actionlint` (with shellcheck on every `run:` block) checks the workflow and local action usage, and all JSON/YAML files are parsed. Run the same checks locally:

```sh
# actionlint (downloads the latest binary)
bash <(curl https://raw.githubusercontent.com/rhysd/actionlint/main/scripts/download-actionlint.bash)
./actionlint -color .github/workflows/*.yml

# JSON validation
find . -name '*.json' -not -path './.git/*' -exec jq empty {} +

# YAML validation
ruby -ryaml -e 'Dir.glob(".github/**/*.{yml,yaml}").each { |f| YAML.load_file(f) }'
```

Dependabot keeps the third-party actions up to date weekly.

## Troubleshooting

- **"I'm sorry, something went wrong…"** — the workflow posts a comment listing the failed job and step; open the linked run logs. Common causes: Infisical identity/project misconfiguration, GitHub App not installed, or the DeepSeek API key missing/expired. Fix and mention `@agent` again.
- **Nothing happens when I mention `@agent`** — check the workflow ran at all (the `triage` job filters on `@agent` appearing in the issue title/body or comment body) and that the repository has the workflow enabled.
- **The agent says it cannot understand the issue** — it classified the request as `OTHER`; rephrase and explicitly say whether it is a bug fix, change request, feature request, investigation or question.
