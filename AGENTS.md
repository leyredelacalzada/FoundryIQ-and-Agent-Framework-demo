# Instructions for Coding Agents

This file contains instructions for developers and AI coding agents working on the FoundryIQ and Agent Framework demo.

## Overall Code Layout

* agents/: Contains agent definitions and configurations
  * agents/orchestrator/: Main orchestrator agent that routes requests
  * agents/hr_agent/: HR specialized agent with HR knowledge base
  * agents/it_agent/: IT specialized agent with IT knowledge base
* app/: Contains the main application code
  * app/backend/: Python backend using FastAPI
  * app/frontend/: React frontend with TypeScript
* infra/: Contains Bicep templates for Azure resources
* scripts/: Contains deployment and utility scripts
* tests/: Contains test files
* docs/: Contains documentation

## Adding a New Agent

1. Create a new folder in `agents/` with the agent name
2. Add agent configuration file `agent.yaml`
3. Add agent prompts in `prompts/` subfolder
4. Register the agent in `agents/orchestrator/config.yaml`
5. Add knowledge base configuration if needed

## Environment Variables

Environment variables are managed through:
1. `infra/main.parameters.json`: Define parameter with azd env variable mapping
2. `infra/main.bicep`: Add parameter and include in appEnvVariables
3. `.azdo/pipelines/azure-dev.yml`: Add for Azure DevOps CI/CD
4. `.github/workflows/azure-dev.yml`: Add for GitHub Actions CI/CD

## Running Tests

```bash
source .venv/bin/activate
pytest tests/
```

## Deploying

```bash
azd up  # Full deployment
azd provision  # Infrastructure only
azd deploy  # Code only
```
