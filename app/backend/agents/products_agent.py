"""Products Agent - Connected to kb3-products Knowledge Base."""

import asyncio
import os
from azure.identity.aio import DefaultAzureCredential
from agent_framework import ChatAgent, ChatMessage, Role
from agent_framework.azure import AzureAIAgentClient, AzureAISearchContextProvider

SEARCH_ENDPOINT = os.getenv("AZURE_SEARCH_ENDPOINT", "https://srch-fiq-maf-demo.search.windows.net")
PROJECT_ENDPOINT = os.getenv("AZURE_AI_PROJECT_ENDPOINT", "https://foundry-fiq-maf-demo.services.ai.azure.com/api/projects/proj1-fiq-maf-demo")
MODEL = os.getenv("AZURE_OPENAI_DEPLOYMENT", "gpt-4.1")

PRODUCTS_INSTRUCTIONS = """You are a Products Specialist Agent for Zava Corporation.
Answer questions about products, catalog, specifications, and pricing using the knowledge base.
Be specific and cite sources when possible."""


async def run_products_agent(query: str) -> str:
    """Run the Products agent with a query."""
    credential = DefaultAzureCredential()
    
    async with (
        AzureAIAgentClient(
            project_endpoint=PROJECT_ENDPOINT,
            model_deployment_name=MODEL,
            credential=credential,
        ) as client,
        AzureAISearchContextProvider(
            endpoint=SEARCH_ENDPOINT,
            knowledge_base_name="kb3-products",
            credential=credential,
            mode="agentic",
            knowledge_base_output_mode="answer_synthesis",
        ) as kb_context,
    ):
        agent = ChatAgent(
            chat_client=client,
            context_provider=kb_context,
            instructions=PRODUCTS_INSTRUCTIONS,
        )
        
        message = ChatMessage(role=Role.USER, text=query)
        response = await agent.run(message)
        return response.text
    
    await credential.close()


async def main():
    print("\n📦 Products Agent (kb3-products)")
    print("=" * 50)
    
    query = "What products do you offer?"
    print(f"\n❓ Query: {query}")
    
    response = await run_products_agent(query)
    print(f"\n💬 Response:\n{response}")


if __name__ == "__main__":
    asyncio.run(main())
