# Copying the agent workflow

This agent workflow has been slightly edited to enable it to edit itself.
To copy it to another repo, the agent workflow will need to be slightly modified as follows:

1. In all of the Infisical steps, replace the project-slug with the commented out value next to them
2. If the repository pulls private crates from Shipyard, uncomment the `shipyard-ssh-private-key` and
   `shipyard-known-host` inputs on the "Address issue" step in `workflows/agent.yml`. They use
   `SHIPYARD_SSH_PRIVATE_KEY_CLIENT` (a read-only deploy key) and `SHIPYARD_KNOWN_HOST`. `invoke-pi`
   loads the key into a short-lived ssh-agent and never writes it to disk, so the agent can fetch
   private dependencies but cannot read or copy the key itself. Do not add a step that writes the key
   to `~/.ssh` instead.
