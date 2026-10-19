# Copying the agent workflow

This agent workflow has been slightly edited to enable it to edit itself.
To copy it to another repo, the agent workflow will need to be slightly modified as follows:

1. In all of the Infisical steps, replace the project-slug with the commented out value next to them
2. The workflow asks Infisical for individual secrets by name (`secret-name`) instead of injecting the whole
   project/environment. If your secret names differ, update the `secret-name` inputs for
   `GITHUB_APP_AGENT_HELPER_CLIENT_ID`, `GITHUB_APP_AGENT_HELPER_PRIVATE_KEY`, `DEEPSEEK_API_KEY` and
   `EDENAI_API_KEY`. Add only the secrets the workflow actually needs.
3. Use a dedicated Infisical identity for this repository/workflow rather than reusing an identity that also
   has access to other projects (agents, publish, AWS, ...). That limits the blast radius if the identity is
   ever abused.
4. Private registry access is opt-in. If the repository pulls private crates from Shipyard, just uncomment
   the "Optional private crate registry access" steps in `workflows/agent.yml`, immediately before the
   "Address issue" step. They fetch `SHIPYARD_SSH_PRIVATE_KEY_CLIENT` and `SHIPYARD_KNOWN_HOST` only for
   that step. Use a **read-only** deploy key scoped to the registry (never a personal key).
   `invoke-pi` removes all other credentials, loads the deploy key into a short-lived ssh-agent and never
   writes it to disk, so the agent can use the key to fetch dependencies but cannot read or copy the
   private key. Do not set up a long-lived registry key in `~/.ssh` before the agent runs. If your secret
   names differ, update the `secret-name` values in the uncommented steps.
5. Keep third-party actions pinned by commit SHA (with the version in a comment) and update the pins
   deliberately. The workflow also installs exact versions of `pi-coding-agent` and the JSON-schema
   extension for the same reason.

The deploy workflow (`master.yml`) in repositories that use this agent should follow the same rule: do not
write the registry private key before `cargo lambda build`. A `build.rs`, procedural macro or compromised
dependency runs arbitrary code during the build and could exfiltrate it. Stage the key only for the step
that needs it (or use short-lived registry credentials), and remove it immediately afterwards.
