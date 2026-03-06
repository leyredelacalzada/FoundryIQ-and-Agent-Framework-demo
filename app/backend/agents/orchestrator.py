import asyncio
import os
from azure.identity.aio import DefaultAzureCredential

from agent_framework import Agent, Message, Content
from agent_framework.azure import AzureAIAgentClient, AzureAISearchContextProvider

SEARCH_ENDPOINT = os.getenv("AZURE_SEARCH_ENDPOINT", "https://srch-g5mlw6gto4s6i.search.windows.net")
PROJECT_ENDPOINT = os.getenv(
    "AZURE_AI_PROJECT_ENDPOINT",
    "https://jusamano-2099-resource.services.ai.azure.com/api/projects/jusamano-2099",
)
MODEL = os.getenv("AZURE_OPENAI_DEPLOYMENT", "gpt-4.1")

HR_KB_NAME = "kb1-hr"
MKT_KB_NAME = "kb2-marketing"
PRD_KB_NAME = "kb3-products"

# ✅ IMPORTANT: provide source_id (prefer env vars)
HR_SOURCE_ID = os.getenv("KB1_HR_SOURCE_ID", HR_KB_NAME)
MKT_SOURCE_ID = os.getenv("KB2_MARKETING_SOURCE_ID", MKT_KB_NAME)
PRD_SOURCE_ID = os.getenv("KB3_PRODUCTS_SOURCE_ID", PRD_KB_NAME)

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
- "hr"
- "marketing"
- "products"

Just respond with the agent name, nothing else."""


def user_message(text: str) -> Message:
    return Message(role="user", contents=[Content.from_text(text)])


async def route_query(router: Agent, query: str) -> str:
    resp = await router.run(user_message(query))
    route = (resp.text or "").strip().lower()
    if "hr" in route:
        return "hr"
    if "marketing" in route or "brand" in route or "campaign" in route:
        return "marketing"
    if "product" in route:
        return "products"
    return "hr"


async def run_orchestrator():
    async with DefaultAzureCredential() as credential:
        async with (
            AzureAIAgentClient(
                project_endpoint=PROJECT_ENDPOINT,
                model_deployment_name=MODEL,
                credential=credential,
            ) as client,

            # ✅ FIX: pass source_id as FIRST argument
            AzureAISearchContextProvider(
                HR_SOURCE_ID,
                endpoint=SEARCH_ENDPOINT,
                knowledge_base_name=HR_KB_NAME,
                credential=credential,
                mode="agentic",
                knowledge_base_output_mode="answer_synthesis",
            ) as hr_kb,

            AzureAISearchContextProvider(
                MKT_SOURCE_ID,
                endpoint=SEARCH_ENDPOINT,
                knowledge_base_name=MKT_KB_NAME,
                credential=credential,
                mode="agentic",
                knowledge_base_output_mode="answer_synthesis",
            ) as marketing_kb,

            AzureAISearchContextProvider(
                PRD_SOURCE_ID,
                endpoint=SEARCH_ENDPOINT,
                knowledge_base_name=PRD_KB_NAME,
                credential=credential,
                mode="agentic",
                knowledge_base_output_mode="answer_synthesis",
            ) as products_kb,
        ):
            router = Agent(client=client, instructions=ROUTER_INSTRUCTIONS)

            specialists = {
                "hr": Agent(client=client, context_provider=hr_kb, instructions=HR_INSTRUCTIONS),
                "marketing": Agent(client=client, context_provider=marketing_kb, instructions=MARKETING_INSTRUCTIONS),
                "products": Agent(client=client, context_provider=products_kb, instructions=PRODUCTS_INSTRUCTIONS),
            }

            print("\n🤖 Multi-Agent Orchestrator with KB Grounding")
            print("=" * 55)
            print("Type 'quit' to exit\n")

            while True:
                query = input("❓ Question: ").strip()
                if not query:
                    continue
                if query.lower() in ["quit", "exit", "q"]:
                    print("\n👋 Goodbye!")
                    return

                route = await route_query(router, query)
                print(f"📍 Routing to: {route.upper()} agent")

                resp = await specialists[route].run(user_message(query))
                print(f"\n💬 Response:\n{resp.text}\n")
                print("-" * 55)


if __name__ == "__main__":
    asyncio.run(run_orchestrator())
