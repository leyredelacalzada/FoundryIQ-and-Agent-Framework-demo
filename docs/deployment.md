# Deployment Guide

This guide covers deploying the FoundryIQ and Agent Framework Demo to Azure.

## Prerequisites

1. **Azure Subscription** with permissions to create resources
2. **Azure Developer CLI (azd)** v1.17.0 or later
3. **Python 3.11+** for local development
4. **Node.js 20+** for frontend development

## Quick Start

```bash
# Login to Azure
azd auth login

# Create environment
azd env new myenv

# Configure required settings
azd env set AZURE_LOCATION eastus
azd env set AZURE_OPENAI_LOCATION eastus

# Deploy everything
azd up
```

## Environment Variables

### Required

| Variable | Description |
|----------|-------------|
| `AZURE_LOCATION` | Primary Azure region |
| `AZURE_OPENAI_LOCATION` | Azure OpenAI region |

### Optional

| Variable | Default | Description |
|----------|---------|-------------|
| `AZURE_OPENAI_CHAT_MODEL` | `gpt-4o` | Chat model name |
| `AZURE_OPENAI_EMBEDDING_MODEL` | `text-embedding-3-large` | Embedding model |
| `USE_AI_FOUNDRY` | `true` | Use Azure AI Foundry |
| `AZURE_USE_AUTHENTICATION` | `false` | Enable Entra auth |

## Resources Created

The deployment creates:

- **Azure OpenAI** - GPT-4o and embedding models
- **Azure AI Search** - Vector search index
- **Azure Container Apps** - Backend hosting
- **Azure Container Registry** - Docker images
- **Azure Storage** - Document storage

## Post-Deployment

After `azd up` completes:

1. Access the app at the URL provided in the output
2. Configure agents in `agents/` directory as needed
3. Add documents to the knowledge base

## Updating

```bash
# Update infrastructure only
azd provision

# Update code only
azd deploy

# Full update
azd up
```

## Troubleshooting

### Deployment fails

1. Check Azure subscription quotas
2. Verify region supports required services
3. Review deployment logs: `azd deploy --debug`

### App not responding

1. Check container logs in Azure Portal
2. Verify environment variables are set
3. Test health endpoint: `curl <APP_URL>/health`
