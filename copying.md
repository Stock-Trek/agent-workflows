# Copying the agent workflow

This agent workflow has been slightly edited to enable it to edit itself.
To copy it to another repo, the agent workflow will need to be slightly modified as follows:

1. In the authenticate action.yml, replace the identity-id and project-slug with the commented out values next to them
2. Uncomment the shipyard ssh step in workflows/agent.yml
