# agent-workflows

A GitHub Actions workflow that runs an AI coding agent (via [pi](https://www.npmjs.com/package/@mariozechner/pi-coding-agent)) on issues and PR comments.
When someone mentions `@agent`, the workflow classifies the request, asks for any missing information, and - when it can - fixes the issue in code, opens a PR and replies on the issue.
The model pi uses can be chosen per run by adding a `@model = "..."` tag to the same issue or comment that mentions `@agent`, e.g. `@agent @model = "pro"`. A model can be named by its full id, by the short key assigned to it in the setup actions under [`.github/actions`](./.github/actions), or by any unambiguous suffix of its id (e.g. the part after the last `/`), so long model names never need to be typed out. The configured models and their keys are:

| Key | Full model id |
| --- | --- |
| `flash` (default) | `deepseek-flash` |
| `pro` | `deepseek-v4-pro` |
| `glm` | `fireworks_ai/accounts/fireworks/models/glm-5p3-flash` |
| `hy3` | `deepinfra/tencent/Hy3` |

Matching is case-insensitive but must be unambiguous: an absent, unknown or ambiguous name silently falls back to the default model (`deepseek-flash`).

This repository is the canonical source for the workflow and is designed to be copied into other repositories in the same organisation with minimal changes.
The [`copying.md`](./copying.md) file describes what to change when copying.

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
- **Credentials are never readable by the agent** Provider API keys are stored only in short-lived files that pi's credential command deletes as soon as it reads them, and the agent runs with a scrubbed environment, so a prompt injection in issue text cannot read or exfiltrate them.
- **Schema-validated model output** Every model call is constrained by a JSON schema, with a hard-coded fallback so users always get a visible reply instead of a silent no-op.
- **Re-runnable** Existing issue branches and open PRs are reused, and a failure comment tells the user to mention `@agent` again.
- **PR comments are supported** A comment on a PR is handled the same way as an issue comment (the PR is "addressed" rather than "closed").

## Troubleshooting

- **Nothing happens when I mention `@agent`** Check the workflow ran at all (the `triage` job filters on `@agent` appearing in the issue title/body or comment body)
- **The agent says it cannot understand the issue** It classified the request as `OTHER`, rephrase and explicitly say whether it is a bug fix, change request, feature request, investigation or question
