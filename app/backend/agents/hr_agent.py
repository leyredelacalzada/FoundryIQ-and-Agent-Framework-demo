"""HR Agent - Connected to kb1-hr Knowledge Base."""

import asyncio
import os
from azure.identity.aio import DefaultAzureCredential
from agent_framework import ChatAgent, ChatMessage, Role
from agent_framework.azure import AzureAIAgentClient, AzureAISearchContextProvider

SEARCH_ENDPOINT = os.getenv("AZURE_SEARCH_ENDPOINT", "https://srch-fiq-maf-demo.search.windows.net")
PROJECT_ENDPOINT = os.getenv("AZURE_AI_PROJECT_ENDPOINT", "https://foundry-fiq-maf-demo.services.ai.azure.com/api/projects/proj1-fiq-maf-demo")
MODEL = os.getenv("AZURE_OPENAI_DEPLOYMENT", "gpt-4.1")

HR_INSTRUCTIONS = """You are an HR Specialist Agent for Zava Corporation.
Answer questions about HR policies, PTO, benefits, and employee handbook using the knowledge base.
Be specific and cite sources when possible."""


async def run_hr_agent(query: str) -> str:
    """Run the HR agent with a query."""
    credential = DefaultAzureCredential()
    
    async with (
        AzureAIAgentClient(
            project_endpoint=PROJECT_ENDPOINT,
            model_deployment_name=MODEL,
            credential=credential,
        ) as client,
        AzureAISearchContextProvider(
            endpoint=SEARCH_ENDPOINT,
            knowledge_base_name="kb1-hr",
            credential=credential,
            mode="agentic",
            knowledge_base_output_mode="answer_synthesis",
        ) as kb_context,
    ):
        agent = ChatAgent(
            chat_client=client,
            context_provider=kb_context,
            instructions=HR_INSTRUCTIONS,
        )
        
        message = ChatMessage(role=Role.USER, text=query)
        response = await agent.run(message)
        return response.text
    
    await credential.close()


async def main():
    print("\n🧑‍💼 HR Agent (kb1-hr)")
    print("=" * 50)
    
    query = "What is the PTO policy?"
    print(f"\n❓ Query: {query}")
    
    response = await run_hr_agent(query)
    print(f"\n💬 Response:\n{response}")


if __name__ == "__main__":
    asyncio.run(main())
