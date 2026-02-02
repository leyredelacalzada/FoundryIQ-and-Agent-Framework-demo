"""
Multi-Agent Orchestrator with KB Grounding.

Routes queries to specialized agents:
- HR Agent → kb1-hr (policies, PTO, benefits)
- Marketing Agent → kb2-marketing (campaigns, brand, analytics)
- Products Agent → kb3-products (catalog, specs, pricing)
"""

import asyncio
import os
from azure.identity.aio import DefaultAzureCredential
from agent_framework import ChatAgent, ChatMessage, Role
from agent_framework.azure import AzureAIAgentClient, AzureAISearchContextProvider

# Configuration
SEARCH_ENDPOINT = os.getenv("AZURE_SEARCH_ENDPOINT", "https://srch-fiq-maf-demo.search.windows.net")
PROJECT_ENDPOINT = os.getenv("AZURE_AI_PROJECT_ENDPOINT", "https://foundry-fiq-maf-demo.services.ai.azure.com/api/projects/proj1-fiq-maf-demo")
MODEL = os.getenv("AZURE_OPENAI_DEPLOYMENT", "gpt-4.1")

# Agent instructions
HR_INSTRUCTIONS = """You are an HR Specialist Agent for Zava Corporation.
Answer questions about HR policies, PTO, benefits, and employee handbook using the knowledge base.
Be specific and cite sources when possible."""

MARKETING_INSTRUCTIONS = """You are a Marketing Specialist Agent for Zava Corporation.
Answer questions about marketing campaigns, brand guidelines, and marketing strategies using the knowledge base.
Be specific and cite sources when possible."""

PRODUCTS_INSTRUCTIONS = """You are a Products Specialist Agent for Zava Corporation.
Answer questions about products, catalog, specifications, and pricing using the knowledge base.
Be specific and cite sources when possible."""

ROUTER_INSTRUCTIONS = """You are a routing agent. Analyze the user query and determine which specialist should handle it.

Respond with ONLY one of these agent names:
- "hr" - for HR policies, PTO, benefits, employee handbook, leave, performance reviews
- "marketing" - for marketing campaigns, brand guidelines, advertising, customer segments, sales
- "products" - for product catalog, specifications, pricing, features, inventory

Just respond with the agent name, nothing else."""


async def route_query(client: ChatAgent, query: str) -> str:
    """Route a query to the appropriate specialist."""
    message = ChatMessage(role=Role.USER, text=query)
    response = await client.run(message)
    route = response.text.strip().lower()
    
    # Normalize routing
    if "hr" in route:
        return "hr"
    elif "marketing" in route or "brand" in route or "campaign" in route:
        return "marketing"
    elif "product" in route:
        return "products"
    else:
        return "hr"  # Default


async def run_orchestrator():
    """Run the multi-agent orchestrator."""
    
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
        ) as hr_kb,
        AzureAISearchContextProvider(
            endpoint=SEARCH_ENDPOINT,
            knowledge_base_name="kb2-marketing",
            credential=credential,
            mode="agentic",
            knowledge_base_output_mode="answer_synthesis",
        ) as marketing_kb,
        AzureAISearchContextProvider(
            endpoint=SEARCH_ENDPOINT,
            knowledge_base_name="kb3-products",
            credential=credential,
            mode="agentic",
            knowledge_base_output_mode="answer_synthesis",
        ) as products_kb,
    ):
        # Create router agent (no KB, just for routing decisions)
        router = ChatAgent(
            chat_client=client,
            instructions=ROUTER_INSTRUCTIONS,
        )
        
        # Create specialist agents with KB grounding
        hr_agent = ChatAgent(
            chat_client=client,
            context_provider=hr_kb,
            instructions=HR_INSTRUCTIONS,
        )
        
        marketing_agent = ChatAgent(
            chat_client=client,
            context_provider=marketing_kb,
            instructions=MARKETING_INSTRUCTIONS,
        )
        
        products_agent = ChatAgent(
            chat_client=client,
            context_provider=products_kb,
            instructions=PRODUCTS_INSTRUCTIONS,
        )
        
        specialists = {
            "hr": hr_agent,
            "marketing": marketing_agent,
            "products": products_agent,
        }
        
        print("\n🤖 Multi-Agent Orchestrator with KB Grounding")
        print("=" * 55)
        print("Specialists: HR (kb1-hr), Marketing (kb2-marketing), Products (kb3-products)")
        print("Type 'quit' to exit\n")
        
        while True:
            try:
                query = input("❓ Question: ").strip()
                if not query:
                    continue
                if query.lower() in ["quit", "exit", "q"]:
                    print("\n👋 Goodbye!")
                    break
                
                # Route the query
                route = await route_query(router, query)
                print(f"📍 Routing to: {route.upper()} agent")
                
                # Get specialist response
                agent = specialists[route]
                message = ChatMessage(role=Role.USER, text=query)
                response = await agent.run(message)
                
                print(f"\n💬 Response:\n{response.text}\n")
                print("-" * 55)
                
            except KeyboardInterrupt:
                print("\n\n👋 Goodbye!")
                break
            except Exception as e:
                print(f"\n❌ Error: {e}\n")
    
    await credential.close()


async def run_single_query(query: str) -> tuple[str, str]:
    """Run a single query and return (route, response)."""
    
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
        ) as hr_kb,
        AzureAISearchContextProvider(
            endpoint=SEARCH_ENDPOINT,
            knowledge_base_name="kb2-marketing",
            credential=credential,
            mode="agentic",
            knowledge_base_output_mode="answer_synthesis",
        ) as marketing_kb,
        AzureAISearchContextProvider(
            endpoint=SEARCH_ENDPOINT,
            knowledge_base_name="kb3-products",
            credential=credential,
            mode="agentic",
            knowledge_base_output_mode="answer_synthesis",
        ) as products_kb,
    ):
        router = ChatAgent(chat_client=client, instructions=ROUTER_INSTRUCTIONS)
        
        specialists = {
            "hr": ChatAgent(chat_client=client, context_provider=hr_kb, instructions=HR_INSTRUCTIONS),
            "marketing": ChatAgent(chat_client=client, context_provider=marketing_kb, instructions=MARKETING_INSTRUCTIONS),
            "products": ChatAgent(chat_client=client, context_provider=products_kb, instructions=PRODUCTS_INSTRUCTIONS),
        }
        
        route = await route_query(router, query)
        agent = specialists[route]
        message = ChatMessage(role=Role.USER, text=query)
        response = await agent.run(message)
        
        return route, response.text
    
    await credential.close()


if __name__ == "__main__":
    asyncio.run(run_orchestrator())
