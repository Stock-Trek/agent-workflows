# agent-workflows

> A self-hosted GitHub Actions workflow that runs an AI coding agent on issues and pull request comments, so contributors can delegate bug fixes, change requests and investigations to an automated agent by simply mentioning `@agent`.

**agent-workflows** is a GitHub Actions workflow that runs an AI coding agent (via [pi](https://www.npmjs.com/package/@mariozechner/pi-coding-agent)) on issues and PR comments.
When someone mentions `@agent`, the workflow classifies the request, asks for any missing information, and - when it can - fixes the issue in code, opens a PR and replies on the issue.
The model pi uses can be chosen per run by adding a `@model = "model-id"` tag to the same issue or comment that mentions `@agent`, e.g. `@agent @model = "deepseek-v4-pro"`. The id must be one of the models configured in the setup actions under [`.github/actions`](./.github/actions); an absent or unknown id silently falls back to the default model (`deepseek-v4-flash`).

This repository is the canonical source for the workflow and is designed to be copied into other repositories in the same organisation with minimal changes.
The [`copying.md`](./copying.md) file describes what to change when copying.

## What's in this repo

- `.github/workflows/agent.yml` - the orchestrating workflow that triggers on issues/comments mentioning `@agent`, triages the request, and either replies, asks for more information, or has the agent address the issue and open a PR.
- `.github/actions/` - reusable composite actions: setting up pi and its models, checking out the per-issue branch, invoking pi, asking pi a schema-validated question, and managing emoji reactions.
- `.github/prompts/` - the prompt templates used to classify requests, classify responses, decide what extra information is required, and instruct the agent how to address an issue.
- `.github/schemas/` - JSON schemas that constrain the model's classified output (request type, response type, and the list of missing information) so the workflow can rely on its shape.
- `README.md` - this description of the repository.
- `copying.md` - instructions for adapting the workflow when copying it into another repository.

## Features

- **Runs an AI coding agent from a comment** - mention `@agent` on an issue or PR comment to have the agent investigate and fix the code.
- **Per-run model selection** - choose the model with `@model = "model-id"`; unknown or missing ids fall back to a sensible default.
- **Safe, schema-validated classification** - every model decision is validated against a JSON schema with safe fallbacks, so users always get a visible reply instead of a silent failure.
- **Re-runnable and re-usable** - per-issue branches and open PRs are reused, and a failure comment invites the user to try again.
- **Spam/other handling** - spam is down-voted, unclassifiable requests get a helpful reply asking the user to clarify.
- **Copy-to-adopt** - the repo is the canonical source and is designed to be copied into other repositories with only a few documented changes.

## How it works

```txt
issue / PR comment mentioning @agent
        │
        ▼
   ┌─ triage ──────────────────────────────────────────────┐
   │ 1. Authenticate (Infisical secrets + GitHub App token)│
   │ 2. React 👀 / clear old reactions                     │
   │ 3. Classify request type (schema-validated)           │
   └──────────────┬────────────────────────────────────────┘
                  │
      ┌───────────┼─────┬────────┬───────────┐
      ▼                 ▼        ▼           ▼
   BUG_FIX/             SPAM     OTHER       CAN_IGNORE
   CHANGE_REQUEST/      (👎-1)   (🤔 + ask)  (do nothing)
   FEATURE_REQUEST/
   INVESTIGATION/
   QUESTION
      |
      ▼
   ┌─ respond ─────────────────────────────┐
   │ classify response                     │
   │  ├ ALREADY_ADDRESSED  → reply + diff  │
   │  ├ REQUIRES_HUMAN     → reply         │
   │  ├ REQUIRES_MORE_INFO → ask questions │
   │  └ CAN_ADDRESS_FULLY                  │
   │      ├ agent fixes code on branch     │
   │      ├ commit + push                  │
   │      └ open/reuse PR + reply          │
   └───────────────────────────────────────┘
      │
      ▼
      notify-failure
      (⚠️ reply on any failure)
```

Key design properties:

- **Serialised per issue** A `concurrency` group per issue prevents two `@agent` mentions (or an edit re-trigger) from racing on the same branch.
- **Schema-validated model output** Every model call is constrained by a JSON schema, with a hard-coded fallback so users always get a visible reply instead of a silent no-op.
- **Re-runnable** Existing issue branches and open PRs are reused, and a failure comment tells the user to mention `@agent` again.
- **PR comments are supported** A comment on a PR is handled the same way as an issue comment (the PR is "addressed" rather than "closed").

## Troubleshooting

- **Nothing happens when I mention `@agent`** Check the workflow ran at all (the `triage` job filters on `@agent` appearing in the issue title/body or comment body)
- **The agent says it cannot understand the issue** It classified the request as `OTHER`, rephrase and explicitly say whether it is a bug fix, change request, feature request, investigation or question
