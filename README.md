# FoundryIQ and Agent Framework Demo

A multi-agent orchestration demo using Microsoft Agent Framework and Azure AI Foundry.

## Features

- **Multi-Agent Orchestration**: Coordinate multiple specialized agents to handle complex tasks
- **Microsoft Agent Framework**: Built on the official Microsoft agent framework SDK
- **Azure AI Foundry Integration**: Leverage Azure AI services for agent capabilities
- **Modular Agent Design**: Easy to add, remove, or modify agents
- **Fully Automated Deployment**: One-command deployment with `azd up`

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    User Interface                           │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   Orchestrator Agent                         │
│         (Routes requests to specialized agents)              │
└─────────────────────────────────────────────────────────────┘
            │              │              │
            ▼              ▼              ▼
     ┌──────────┐   ┌──────────┐   ┌──────────┐
     │ HR Agent │   │ IT Agent │   │ Finance  │
     │          │   │          │   │  Agent   │
     └──────────┘   └──────────┘   └──────────┘
            │              │              │
            ▼              ▼              ▼
     ┌──────────┐   ┌──────────┐   ┌──────────┐
     │   HR     │   │   IT     │   │ Finance  │
     │Knowledge │   │Knowledge │   │Knowledge │
     │  Base    │   │  Base    │   │  Base    │
     └──────────┘   └──────────┘   └──────────┘
```

## Prerequisites

- Azure subscription with permissions to create resources
- [Azure Developer CLI (azd)](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd)
- [Python 3.11+](https://www.python.org/downloads/)
- [Node.js 20+](https://nodejs.org/)
- [Docker](https://www.docker.com/products/docker-desktop/) (for local development)

## Quick Start

### Using Dev Container (Recommended)

1. Open in VS Code with Dev Containers extension
2. Click "Reopen in Container" when prompted
3. Configure and deploy:

```bash
# Login to Azure
azd auth login

# Configure environment
azd env new myenv
azd env set AZURE_LOCATION eastus
azd env set AZURE_OPENAI_LOCATION eastus

# Deploy
azd up
```

### Manual Setup

```bash
# Clone the repository
git clone https://github.com/your-org/FoundryIQ-and-Agent-Framework-demo.git
cd FoundryIQ-and-Agent-Framework-demo

# Create virtual environment
python -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate

# Install dependencies
pip install -r requirements-dev.txt
cd app/frontend && npm install && cd ../..

# Login and deploy
azd auth login
azd up
```

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `AZURE_LOCATION` | Azure region for resources | Required |
| `AZURE_OPENAI_LOCATION` | Region for Azure OpenAI | Required |
| `AZURE_USE_AUTHENTICATION` | Enable Entra authentication | `false` |
| `USE_AGENTIC_KNOWLEDGEBASE` | Enable agentic retrieval | `true` |

### Adding New Agents

1. Create agent definition in `agents/` directory
2. Register agent in the orchestrator configuration
3. Add knowledge base configuration if needed
4. Deploy with `azd deploy`

## Development

### Local Development

```bash
# Start backend
cd app/backend
python -m uvicorn main:app --reload --port 8000

# Start frontend (in another terminal)
cd app/frontend
npm run dev
```

### Running Tests

```bash
pytest tests/
```

## Deployment

### First Deployment

```bash
azd up
```

### Update Deployment

```bash
# Re-provision infrastructure only
azd provision

# Re-deploy application code only
azd deploy
```

## Project Structure

```
├── .devcontainer/       # Dev container configuration
├── agents/              # Agent definitions and configurations
│   ├── hr_agent/        # HR specialized agent
│   ├── it_agent/        # IT specialized agent
│   └── orchestrator/    # Main orchestrator agent
├── app/
│   ├── backend/         # Python backend (FastAPI/Quart)
│   └── frontend/        # React frontend
├── docs/                # Documentation
├── infra/               # Bicep IaC templates
├── scripts/             # Deployment and utility scripts
└── tests/               # Test files
```

## License

MIT License - see [LICENSE](LICENSE) for details.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines.
