# FoundryIQ and Agent Framework Demo

A multi-agent orchestration demo using Microsoft Agent Framework SDK and Azure AI Foundry with FoundryIQ Knowledge Bases for grounded retrieval.

![Demo Screenshot](docs/demo-screenshot.png)

## Features

- **Multi-Agent Orchestration**: Intelligent routing of queries to specialized agents (HR, Products, Marketing)
- **Microsoft Agent Framework SDK**: Built on the official `agent-framework` Python SDK
- **FoundryIQ Knowledge Bases**: Agentic retrieval mode with gpt-4.1 for grounded responses
- **RBAC-Only Authentication**: No API keys - uses DefaultAzureCredential for all services
- **Fully Automated Deployment**: Infrastructure as Code with Bicep + setup scripts

## Architecture

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                              User Query                                       │
│                    "What is the PTO policy?"                                  │
└─────────────────────────────────┬────────────────────────────────────────────┘
                                  │
                                  ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│                         ORCHESTRATOR AGENT                                    │
│                                                                               │
│   • Analyzes user intent                                                      │
│   • Routes to appropriate specialist agent                                    │
│   • Returns grounded response with citations                                  │
└───────────┬─────────────────────┬─────────────────────┬──────────────────────┘
            │                     │                     │
            ▼                     ▼                     ▼
┌───────────────────┐  ┌───────────────────┐  ┌───────────────────┐
│    HR AGENT       │  │  MARKETING AGENT  │  │  PRODUCTS AGENT   │
│                   │  │                   │  │                   │
│ kb1-hr            │  │ kb2-marketing     │  │ kb3-products      │
│ • PTO policies    │  │ • Campaigns       │  │ • Product catalog │
│ • Benefits        │  │ • Brand guidelines│  │ • Specifications  │
│ • Handbook        │  │ • Analytics       │  │ • Pricing         │
└─────────┬─────────┘  └─────────┬─────────┘  └─────────┬─────────┘
          │                      │                      │
          ▼                      ▼                      ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│                         MICROSOFT FOUNDRY                                     │
│  ┌────────────────────────────────────────────────────────────────────────┐  │
│  │                    FOUNDRYIQ KNOWLEDGE BASES                            │  │
│  │                                                                         │  │
│  │  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐              │  │
│  │  │   kb1-hr     │    │ kb2-marketing│    │ kb3-products │              │  │
│  │  │  gpt-4.1     │    │  gpt-4.1     │    │  gpt-4.1     │              │  │
│  │  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘              │  │
│  │         ▼                   ▼                   ▼                      │  │
│  │  ┌───────────────────────────────────────────────────────────────┐     │  │
│  │  │                    KNOWLEDGE SOURCES                           │     │  │
│  │  │  HR:         ks-hr-sharepoint, ks-hr-aisearch, ks-hr-web      │     │  │
│  │  │  Marketing:  ks-marketing, ks-blob-marketing, ks-marketing-web│     │  │
│  │  │  Products:   ks-products, ks-products-onelake                 │     │  │
│  │  └───────────────────────────────────────────────────────────────┘     │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────────────┘
```

## Prerequisites

- Azure subscription with Owner or Contributor + User Access Administrator
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)
- [Azure Developer CLI (azd)](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd)
- [Python 3.11+](https://www.python.org/downloads/)

## Quick Start

### 1. Clone and Setup

```bash
git clone https://github.com/leyredelacalzada/FoundryIQ-and-Agent-Framework-demo.git
cd FoundryIQ-and-Agent-Framework-demo

# Create virtual environment
python -m venv .venv
source .venv/bin/activate

# Install dependencies
pip install -r requirements-dev.txt
```

### 2. Deploy Infrastructure

```bash
az login && azd auth login
azd up
```

### 3. Setup FoundryIQ Resources

```bash
./scripts/setup_indexes.sh
./scripts/upload_sample_data.sh
./scripts/setup_knowledge_sources.sh
./scripts/setup_knowledge_bases.sh
```

### 4. Configure Search RBAC (Manual)

In Azure Portal: Search service → Keys → Set to **"Both"** (API keys + RBAC)

### 5. Test the Orchestrator

```bash
python app/backend/agents/orchestrator.py
```

Try: "What is the PTO policy?" or "Tell me about the fitness watch"

## Project Structure

```
├── app/backend/agents/
│   ├── orchestrator.py      # Routes queries to specialists
│   ├── hr_agent.py          # HR specialist → kb1-hr
│   ├── products_agent.py    # Products specialist → kb3-products
│   └── marketing_agent.py   # Marketing specialist → kb2-marketing
├── infra/                   # Bicep IaC templates
├── scripts/                 # Setup and deployment scripts
└── docs/                    # Documentation
```

## Knowledge Base Mapping

| Agent | Knowledge Base | Content |
|-------|----------------|---------|
| HR | kb1-hr | PTO policies, benefits, handbook |
| Products | kb3-products | Product catalog, specs, pricing |
| Marketing | kb2-marketing | Campaigns, brand guidelines |

## Troubleshooting

| Issue | Fix |
|-------|-----|
| 403 Forbidden | Portal → Search → Keys → "Both" |
| Generic responses | Ensure context_provider passed to Agent |
| KB errors | Run ./scripts/setup_rbac.sh |

## License

MIT License
