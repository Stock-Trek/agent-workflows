# Copying the agent workflow

This agent workflow has been slightly edited to enable it to edit itself, and it
is designed to be copied into other repositories in the same organisation. The
full deployment guide is in the [README](README.md).

Copying to another repo:

1. Copy the entire `.github/` directory and this file.
2. Make sure the [prerequisites](README.md#prerequisites) are in place for the
   target repository (GitHub App, Infisical project + OIDC identity, DeepSeek
   API key).
3. Configure the organisation-specific values as **repository variables**
   (see the [configuration table](README.md#configuration)):

   | Variable | Default (this repo) |
   | --- | --- |
   | `INFISICAL_IDENTITY_ID` | `29578305-c46a-4ccd-a428-549edac4c3a2` |
   | `INFISICAL_PROJECT_SLUG` | `agent-editor` |
   | `AGENT_GIT_USER_EMAIL` | `agent@stock-trek.com` |
   | `AGENT_GIT_USER_NAME` | `Stock-Trek Agent` |

   Setting `INFISICAL_IDENTITY_ID` and `INFISICAL_PROJECT_SLUG` is all that is
   required; the git identity variables only matter if you want commits
   attributed differently.

4. (Optional) If the target environment authenticates git over the Shipyard SSH
   endpoint instead of using the GitHub App token, add a step that sets up the
   Shipyard SSH keys before the `Address issue` step in `agent.yml`.

No other edits are needed; hard-coded values in the workflow are only fallbacks
that make it work out of the box in this repository.
