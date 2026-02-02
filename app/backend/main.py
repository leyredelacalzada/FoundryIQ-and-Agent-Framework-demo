"""
FoundryIQ and Agent Framework Demo Backend

Multi-agent orchestration using Microsoft Agent Framework and Azure AI Foundry.
Agents are defined declaratively in YAML configs and loaded at runtime.
"""

import os
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

from agent_loader import get_agent_loader, close_agent_loader


class ChatRequest(BaseModel):
    message: str
    session_id: str | None = None
    agent: str | None = None  # Optional: specify agent, otherwise orchestrator routes


class ChatResponse(BaseModel):
    message: str
    agent: str
    sources: list[str] = []


class HealthResponse(BaseModel):
    status: str
    version: str


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan handler."""
    # Startup - initialize agent loader
    print("Starting FoundryIQ Agent Framework Demo...")
    try:
        loader = await get_agent_loader()
        print(f"Loaded {len(loader.agent_configs)} agents from configuration")
        for name in loader.agent_configs:
            print(f"  - {name}")
    except Exception as e:
        print(f"Warning: Could not initialize agents: {e}")
    
    yield
    
    # Shutdown
    print("Shutting down...")
    await close_agent_loader()


app = FastAPI(
    title="FoundryIQ Agent Framework Demo",
    description="Multi-agent orchestration using Microsoft Agent Framework",
    version="0.1.0",
    lifespan=lifespan,
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health", response_model=HealthResponse)
async def health():
    """Health check endpoint."""
    return HealthResponse(status="healthy", version="0.1.0")


@app.post("/chat", response_model=ChatResponse)
async def chat(request: ChatRequest):
    """
    Chat with the multi-agent system.
    
    The orchestrator will route the request to the appropriate agent
    based on the query content, unless a specific agent is specified.
    """
    try:
        loader = await get_agent_loader()
        result = await loader.query(request.message, request.agent)
        
        return ChatResponse(
            message=result["message"],
            agent=result["agent"],
            sources=result.get("sources", []),
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/agents")
async def list_agents():
    """List available agents with their metadata."""
    try:
        loader = await get_agent_loader()
        return {"agents": loader.get_available_agents()}
    except Exception as e:
        # Fallback if loader not initialized
        return {
            "agents": [
                {
                    "id": "orchestrator",
                    "name": "Orchestrator",
                    "description": "Routes requests to specialized agents",
                },
                {
                    "id": "hr_agent",
                    "name": "HR Agent",
                    "description": "Handles HR-related queries",
                },
                {
                    "id": "marketing_agent",
                    "name": "Marketing Agent",
                    "description": "Handles marketing-related queries",
                },
                {
                    "id": "products_agent",
                    "name": "Products Agent",
                    "description": "Handles product-related queries",
                },
            ]
        }


# Mount static files for frontend
static_dir = os.path.join(os.path.dirname(__file__), "static")
if os.path.exists(static_dir):
    app.mount("/", StaticFiles(directory=static_dir, html=True), name="static")


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
