# Copying the agent workflow

This agent workflow has been slightly edited to enable it to edit itself.
To copy it to another repo, the agent workflow will need to be slightly modified as follows:

1. In all of the Infisical steps, replace the project-slug with the commented out value next to them
2. Remove the `permission-workflows: write` from the final `actions/create-github-app-token` step
3. The workflow asks Infisical for individual secrets by name (`secret-name`) instead of injecting the whole
   project/environment. If your secret names differ, update the `secret-name` inputs for
   `GITHUB_APP_AGENT_HELPER_CLIENT_ID`, `GITHUB_APP_AGENT_HELPER_PRIVATE_KEY`, `DEEPSEEK_API_KEY` and
   `EDENAI_API_KEY`. Add only the secrets the workflow actually needs.
4. Use a dedicated Infisical identity for this repository/workflow rather than reusing an identity that also
   has access to other projects (agents, publish, AWS, ...). That limits the blast radius if the identity is
   ever abused.
5. Private registry access is opt-in. If the repository pulls private crates from Shipyard, uncomment
   the "Optional private crate registry access" steps in `workflows/agent.yml`, immediately before the
   "Address issue" step. They fetch `SHIPYARD_CARGO_TOKEN_READONLY`, `SHIPYARD_SSH_PRIVATE_KEY_READONLY`
   and `SHIPYARD_KNOWN_HOST` only for that run, then the `prefetch-cargo-deps` action runs
   `cargo fetch --locked` in a trusted step. Use a dedicated read-only registry token with the shortest
   practical expiry (never a write token or personal key) and a read-only deploy key scoped to the
   registry (never a personal key).
   The token is passed to Cargo through the environment of that single step, so it is never written to
   `~/.cargo/credentials`, and the deploy key is loaded into a short-lived ssh-agent that is shut down
   again after the fetch. Both are then removed from the environment the rest of the job inherits, and
   the agent runs with `CARGO_NET_OFFLINE=true`, resolving dependencies from Cargo's local cache. A
   prompt injection in issue text therefore has no registry credential to use and cannot exfiltrate one.
   Do not set up a long-lived registry key in `~/.ssh` before the agent runs. If your secret names differ,
   update the `secret-name` values in the uncommented steps. Removing the token step is fine if your
   registry only needs the deploy key.

   Limitation: a new private dependency added during the agent run is not in the cache, so it needs
   another prefetch in a trusted step (for example re-running the workflow after committing the new
   dependency, or widening the prefetch step).
6. Keep third-party actions pinned by commit SHA (with the version in a comment) and update the pins
   deliberately. The workflow also installs exact versions of `pi-coding-agent` and the JSON-schema
   extension for the same reason.

The deploy workflow (`master.yml`) in repositories that use this agent should follow the same rule: do not
write the registry private key before `cargo lambda build`. A `build.rs`, procedural macro or compromised
dependency runs arbitrary code during the build and could exfiltrate it. Prefer a short-lived read-only
registry token passed through the environment; otherwise load a read-only deploy key into a temporary
ssh-agent only for the build step, run `cargo fetch --locked` first if you can, and remove both
immediately afterwards (`ssh-agent -k`).
