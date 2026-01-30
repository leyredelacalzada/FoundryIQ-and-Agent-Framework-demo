"""
FoundryIQ and Agent Framework Demo Backend

Multi-agent orchestration using Microsoft Agent Framework and Azure AI Foundry.
"""

import os
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel


class ChatRequest(BaseModel):
    message: str
    session_id: str | None = None


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
    # Startup
    print("Starting FoundryIQ Agent Framework Demo...")
    yield
    # Shutdown
    print("Shutting down...")


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
    
    The orchestrator will route the request to the appropriate agent.
    """
    # TODO: Implement agent orchestration
    # For now, return a placeholder response
    return ChatResponse(
        message=f"Echo: {request.message}",
        agent="orchestrator",
        sources=[],
    )


@app.get("/agents")
async def list_agents():
    """List available agents."""
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
        ]
    }


# Mount static files for frontend
static_dir = os.path.join(os.path.dirname(__file__), "static")
if os.path.exists(static_dir):
    app.mount("/", StaticFiles(directory=static_dir, html=True), name="static")


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
