# Instructions for Coding Agents

This file contains instructions for developers and AI coding agents working on the FoundryIQ and Agent Framework demo.

## Overall Code Layout

* **app/backend/agents/**: Python agents using Microsoft Agent Framework
  * `orchestrator.py`: Main orchestrator that routes requests to specialist agents
  * `hr_agent.py`: HR specialist agent (grounded to `index-hr`)
  * `products_agent.py`: Products specialist agent (grounded to `index-products`)
  * `marketing_agent.py`: Marketing specialist agent (grounded to `index-marketing`)
* **app/frontend/**: React frontend with TypeScript
* **infra/**: Bicep templates for Azure resources
* **scripts/**: Deployment and utility scripts
  * `setup_rbac.sh`: RBAC role assignments (required permissions)
  * `setup_openai_deployments.sh`: Model deployments (gpt-4o)
  * `setup_indexes.sh`: Create search indexes
  * `setup_knowledge_bases.sh`: Create Knowledge Bases
* **docs/**: Documentation

## Architecture

```
User Query
    ↓
Orchestrator (orchestrator.py)
    ↓ (routes based on query type)
    ├── HR Agent (hr_agent.py) → index-hr
    ├── Products Agent (products_agent.py) → index-products
    └── Marketing Agent (marketing_agent.py) → index-marketing
    ↓
Response
```

## Adding a New Agent

1. **Create agent file** in `app/backend/agents/`:
   ```python
   # new_agent.py
   from agent_framework import Agent, ChatMessage, Executor, WorkflowContext, handler
   
   NEW_AGENT_INSTRUCTIONS = """Your instructions here..."""
   
   class NewAgentExecutor(Executor):
       agent: Agent
       
       def __init__(self, agent: Agent, id: str = "new-agent"):
           self.agent = agent
           super().__init__(id=id)
       
       @handler
       async def handle_routed_message(self, routing_data: tuple[str, ChatMessage], ctx):
           agent_id, message = routing_data
           if agent_id == "new-agent":
               response = await self.agent.run([message])
               await ctx.yield_output(response.text)
   ```

2. **Create search index** for the agent's Knowledge Base:
   - Use Azure Portal or modify `scripts/setup_indexes.sh`
   - Ensure semantic configuration is enabled
   - Index name format: `index-{domain}`

3. **Register in orchestrator.py**:
   - Import the agent's instructions
   - Add context provider with `index_name`
   - Add to specialists dictionary
   - Update orchestrator instructions with new routing rule

4. **Add `__main__` for testing** (see existing agents for pattern)

## Running Agents

Each agent can be run directly for testing:

```bash
# Activate virtual environment
source .venv/bin/activate

# Run individual agents
python -m app.backend.agents.hr_agent
python -m app.backend.agents.products_agent
python -m app.backend.agents.marketing_agent

# Run full orchestrated workflow
python -m app.backend.agents.orchestrator
```

## Configuration

Agents use environment variables with defaults:

| Variable | Default | Description |
|----------|---------|-------------|
| `AZURE_SEARCH_ENDPOINT` | `https://srch-fiq-maf-demo.search.windows.net` | Search service |
| `AZURE_AI_PROJECT_ENDPOINT` | `https://foundry-fiq-maf-demo.services.ai.azure.com/api/projects/proj1-fiq-maf-demo` | Foundry project |
| `AZURE_OPENAI_ENDPOINT` | `https://foundry-fiq-maf-demo.cognitiveservices.azure.com/` | OpenAI endpoint |
| `AZURE_OPENAI_DEPLOYMENT` | `gpt-4o` | Model deployment |
| `RETRIEVAL_MODE` | `agentic` | FoundryIQ mode |

## Key Concepts

### AzureAISearchContextProvider with `index_name`
Using `index_name` auto-creates a Knowledge Base from the search index:
```python
AzureAISearchContextProvider(
    endpoint=SEARCH_ENDPOINT,
    index_name="index-hr",  # Auto-creates KB from index
    mode="agentic",
    retrieval_reasoning_effort="medium",
)
```

### RBAC Requirements
Run `scripts/setup_rbac.sh` to assign required roles:
- `Cognitive Services User` on OpenAI resource
- `Search Index Data Reader` on Search service
- `Azure AI Developer` on Foundry project

## Deploying

```bash
azd up  # Full deployment
```
