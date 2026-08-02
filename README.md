# agent-workflows

A GitHub Actions workflow that runs an AI coding agent (via [pi](https://www.npmjs.com/package/@mariozechner/pi-coding-agent)) on issues and PR comments. When someone mentions `@agent`, the workflow classifies the request, asks for any missing information, and - when it can - fixes the issue in code, opens a PR and replies on the issue.

This repository is the canonical source for the workflow and is designed to be **copied into other repositories in the same organisation**. The [`copying.md`](./copying.md) file describes what to change when copying.

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
