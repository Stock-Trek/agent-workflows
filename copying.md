# Copying agent workflow

This agent workflow has been slightly edited to enable it to edit itself.

To copy it to another repo, the agent workflow will need to be slightly modified as follows:

1. Uncomment the shipyard ssh step (lines 396 - 407)
2. For all 4 "Get secrets" steps, replace the identity-id and project-slug with the commented out values next to them
