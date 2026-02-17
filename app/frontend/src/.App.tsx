import { useState } from "react";

const formatMarkdown = (text: string): string => {
  return text
    .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
    .replace(/\*(.+?)\*/g, '<em>$1</em>')
    .replace(/\n/g, '<br />');
};

interface SourceInfo {
  kb: string;
  title?: string;
  filepath?: string;
  url?: string;
}

interface Message {
  role: "user" | "assistant";
  content: string;
  agent?: string;
  sources?: SourceInfo[];
}

type WorkflowStep = "idle" | "routing" | "hr" | "marketing" | "products" | "complete";

interface TraceLog {
  timestamp: string;
  type: "info" | "route" | "query" | "response";
  message: string;
}

interface AgentInfo {
  id: string;
  name: string;
  icon: string;
  description: string;
  model: string;
  connectedKB: string | null;
  knowledgeSources: string[];
}

interface KBInfo {
  id: string;
  name: string;
  icon: string;
  description: string;
  retrievalMode: string;
  model: string;
  knowledgeSources: string[];
}

const agents: AgentInfo[] = [
  {
    id: "orchestrator",
    name: "Orchestrator",
    icon: "",
    description: "Routes user queries to the appropriate specialist agent based on intent analysis. Uses GPT-4.1 for intelligent routing decisions.",
    model: "gpt-4.1",
    connectedKB: null,
    knowledgeSources: [],
  },
  {
    id: "hr",
    name: "HR Agent",
    icon: "",
    description: "Handles all HR-related queries including PTO policies, benefits, employee handbook, and company policies.",
    model: "gpt-4.1",
    connectedKB: "kb1-hr",
    knowledgeSources: ["ks-hr-sharepoint", "ks-hr-aisearch", "ks-hr-web"],
  },
  {
    id: "marketing",
    name: "Marketing Agent",
    icon: "",
    description: "Specializes in marketing inquiries including brand guidelines, campaign information, and competitor analysis.",
    model: "gpt-4.1",
    connectedKB: "kb2-marketing",
    knowledgeSources: ["ks-marketing", "ks-blob-marketing", "ks-marketing-web"],
  },
  {
    id: "products",
    name: "Products Agent",
    icon: "",
    description: "Expert on product catalog, specifications, pricing, and feature information.",
    model: "gpt-4.1",
    connectedKB: "kb3-products",
    knowledgeSources: ["ks-products", "ks-products-onelake"],
  },
];

const knowledgeBases: KBInfo[] = [
  {
    id: "kb1-hr",
    name: "HR Knowledge Base",
    icon: "",
    description: "Contains HR policies, employee handbook, PTO guidelines, benefits information, and company procedures.",
    retrievalMode: "Agentic Retrieval",
    model: "text-embedding-3-large",
    knowledgeSources: ["ks-hr-sharepoint", "ks-hr-aisearch", "ks-hr-web"],
  },
  {
    id: "kb2-marketing",
    name: "Marketing Knowledge Base",
    icon: "",
    description: "Brand guidelines, marketing campaigns, customer segments, competitor analysis, and promotional materials.",
    retrievalMode: "Agentic Retrieval",
    model: "text-embedding-3-large",
    knowledgeSources: ["ks-marketing", "ks-blob-marketing", "ks-marketing-web"],
  },
  {
    id: "kb3-products",
    name: "Products Knowledge Base",
    icon: "",
    description: "Complete product catalog with specifications, pricing, features, and inventory information.",
    retrievalMode: "Agentic Retrieval",
    model: "text-embedding-3-large",
    knowledgeSources: ["ks-products", "ks-products-onelake"],
  },
];

const sourceLogos: Record<string, string> = {
  "hr-agent": "👥",
  "marketing-agent": "📣", 
  "products-agent": "📦",
  "kb1-hr": "📋",
  "kb2-marketing": "🎨",
  "kb3-products": "🏷️",
};

const predefinedQuestions = [
  { text: "What is the PTO policy at Zava?", agent: "HR" },
  { text: "What are Zava's brand colors?", agent: "Marketing" },
  { text: "What features does the Smart Fitness Watch have?", agent: "Products" },
];

function App() {
  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [workflowStep, setWorkflowStep] = useState<WorkflowStep>("idle");
  const [activeAgent, setActiveAgent] = useState<string | null>(null);
  const [selectedAgent, setSelectedAgent] = useState<AgentInfo | null>(null);
  const [selectedKB, setSelectedKB] = useState<KBInfo | null>(null);
  const [traceLogs, setTraceLogs] = useState<TraceLog[]>([]);

  const addLog = (type: TraceLog["type"], message: string) => {
    const timestamp = new Date().toLocaleTimeString("en-US", { hour12: false, hour: "2-digit", minute: "2-digit", second: "2-digit", fractionalSecondDigits: 3 });
    setTraceLogs((prev) => [...prev, { timestamp, type, message }]);
  };

  const handleAgentClick = (agent: AgentInfo) => {
    if (selectedAgent?.id === agent.id) {
      setSelectedAgent(null);
    } else {
      setSelectedAgent(agent);
      setSelectedKB(null);
    }
  };

  const handleKBClick = (kb: KBInfo) => {
    if (selectedKB?.id === kb.id) {
      setSelectedKB(null);
    } else {
      setSelectedKB(kb);
      setSelectedAgent(null);
    }
  };

  const sendMessage = async (messageText?: string) => {
    const text = messageText || input;
    if (!text.trim()) return;

    // Clear previous conversation and logs
    setMessages([]);
    setTraceLogs([]);

    const userMessage: Message = { role: "user", content: text };
    setMessages([userMessage]);
    setInput("");
    setIsLoading(true);
    setWorkflowStep("routing");
    
    addLog("info", `User query received: "${text}"`);
    addLog("route", "Orchestrator analyzing intent...");

    try {
      const response = await fetch("/chat", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ message: text }),
      });
      const data = await response.json();
      
      // Set workflow step based on agent
      const agentType = data.agent?.replace("-agent", "") || "hr";
      setWorkflowStep(agentType as WorkflowStep);
      setActiveAgent(data.agent || null);
      
      const kbMap: Record<string, string> = { hr: "kb1-hr", marketing: "kb2-marketing", products: "kb3-products" };
      addLog("route", `Routed to ${data.agent || "specialist"}`);
      addLog("query", `${data.agent} querying ${kbMap[agentType]} via agentic retrieval...`);
      
      // Log retrieved documents
      const sources = data.sources as SourceInfo[];
      if (sources && sources.length > 0) {
        const docNames = sources.map((s: SourceInfo) => s.title || s.filepath || "document").join(", ");
        addLog("response", `Retrieved from ${kbMap[agentType]}: ${docNames}`);
      } else {
        addLog("response", `Retrieved documents from ${kbMap[agentType]}`);
      }
      
      const assistantMessage: Message = {
        role: "assistant",
        content: data.message,
        agent: data.agent,
        sources: data.sources,
      };
      setMessages((prev) => [...prev, assistantMessage]);
      
      addLog("info", `Response generated (${data.message.length} chars)`);
      setTimeout(() => setWorkflowStep("complete"), 500);
    } catch (error) {
      console.error("Error:", error);
      setMessages((prev) => [
        ...prev,
        { role: "assistant", content: "Sorry, there was an error processing your request." },
      ]);
    } finally {
      setIsLoading(false);
      setTimeout(() => {
        setWorkflowStep("idle");
        setActiveAgent(null);
      }, 2000);
    }
  };

  const getNodeStatus = (node: string): "idle" | "active" | "complete" => {
    if (workflowStep === "idle") return "idle";
    if (workflowStep === "complete") return "complete";
    if (node === "input" && workflowStep !== "idle") return "complete";
    if (node === "orchestrator" && workflowStep === "routing") return "active";
    if (node === "orchestrator" && workflowStep !== "routing" && workflowStep !== "idle") return "complete";
    if (node === workflowStep) return "active";
    return "idle";
  };

  return (
    <div className="app">
      <header className="header">
        <div className="header-content">
          <div className="logo">
            <span className="logo-text">Zava</span>
          </div>
          
        </div>
      </header>

      <div className="main-layout">
        {/* Left Sidebar */}
        <aside className="sidebar">
          <div className="sidebar-section">
            <h3>Agents</h3>
            <div className="sidebar-items">
              {agents.map((agent) => (
                <div
                  key={agent.id}
                  className={`sidebar-item ${selectedAgent?.id === agent.id ? "selected" : ""}`}
                  onClick={() => handleAgentClick(agent)}
                >
                  <span>{agent.name}</span>
                </div>
              ))}
            </div>
          </div>
          <div className="sidebar-section">
            <h3>Knowledge Bases</h3>
            <div className="sidebar-items">
              {knowledgeBases.map((kb) => (
                <div
                  key={kb.id}
                  className={`sidebar-item ${selectedKB?.id === kb.id ? "selected" : ""}`}
                  onClick={() => handleKBClick(kb)}
                >
                  <span>{kb.id}</span>
                </div>
              ))}
            </div>
          </div>

          {/* Details Panel */}
          {(selectedAgent || selectedKB) && (
            <div className="details-panel">
              <div className="details-header">
                <span className="details-title">{selectedAgent?.name || selectedKB?.name}</span>
                <button className="details-close" onClick={() => { setSelectedAgent(null); setSelectedKB(null); }}>×</button>
              </div>
              <div className="details-content">
                <p className="details-description">{selectedAgent?.description || selectedKB?.description}</p>
                
                <div className="details-section">
                  <span className="details-label">Model</span>
                  <span className="details-value">{selectedAgent?.model || selectedKB?.model}</span>
                </div>

                {selectedAgent && selectedAgent.connectedKB && (
                  <div className="details-section">
                    <span className="details-label">Connected KB</span>
                    <span className="details-badge">{selectedAgent.connectedKB}</span>
                  </div>
                )}

                {selectedKB && (
                  <div className="details-section">
                    <span className="details-label">Retrieval Mode</span>
                    <span className="details-value">{selectedKB.retrievalMode}</span>
                  </div>
                )}

                <div className="details-section">
                  <span className="details-label">Knowledge Sources</span>
                  <div className="details-sources">
                    {(selectedAgent?.knowledgeSources || selectedKB?.knowledgeSources || []).map((ks) => (
                      <span key={ks} className="details-source-tag">{ks}</span>
                    ))}
                    {(selectedAgent?.knowledgeSources?.length === 0 && !selectedKB) && (
                      <span className="details-value">None (routing only)</span>
                    )}
                  </div>
                </div>
              </div>
            </div>
          )}
        </aside>

        {/* Workflow Canvas */}
        <main className="canvas">
          <div className="workflow-canvas">
            {/* Input Node */}
            <div className={`workflow-node input-node ${getNodeStatus("input")}`}>
              <div className="node-status"></div>
              <div className="node-content">
                <span className="node-title">User Input</span>
              </div>
              <div className="node-meta">Text query</div>
            </div>

            <div className="connector vertical"></div>

            {/* Orchestrator Node */}
            <div className={`workflow-node orchestrator-node ${getNodeStatus("orchestrator")}`}>
              <div className="node-status"></div>
              <div className="node-content">
                <span className="node-title">Orchestrator</span>
              </div>
              <div className="node-description">Routes to specialist agent</div>
              <div className="node-badge">gpt-4.1</div>
            </div>

            <div className="connector-branch">
              <div className="branch-line left"></div>
              <div className="branch-line center"></div>
              <div className="branch-line right"></div>
            </div>

            {/* Agent Nodes */}
            <div className="agent-row">
              <div className={`workflow-node agent-node hr ${getNodeStatus("hr")}`}>
                <div className="node-status"></div>
                <div className="node-content">
                  <span className="node-title">HR Agent</span>
                </div>
                <div className="node-kb">
                  <span className="kb-badge">kb1-hr</span>
                </div>
              </div>

              <div className={`workflow-node agent-node marketing ${getNodeStatus("marketing")}`}>
                <div className="node-status"></div>
                <div className="node-content">
                  <span className="node-title">Marketing Agent</span>
                </div>
                <div className="node-kb">
                  <span className="kb-badge">kb2-marketing</span>
                </div>
              </div>

              <div className={`workflow-node agent-node products ${getNodeStatus("products")}`}>
                <div className="node-status"></div>
                <div className="node-content">
                  <span className="node-title">Products Agent</span>
                </div>
                <div className="node-kb">
                  <span className="kb-badge">kb3-products</span>
                </div>
              </div>
            </div>

            <div className="connector-merge">
              <div className="merge-line left"></div>
              <div className="merge-line center"></div>
              <div className="merge-line right"></div>
            </div>

            {/* Output Node */}
            <div className={`workflow-node output-node ${workflowStep === "complete" ? "complete" : "idle"}`}>
              <div className="node-status"></div>
              <div className="node-content">
                <span className="node-title">Response</span>
              </div>
              <div className="node-meta">Grounded answer</div>
            </div>
          </div>

          {/* Trace Logs Panel */}
          <div className="trace-panel">
            <div className="trace-header">
              <span className="trace-title">Execution Trace</span>
              {traceLogs.length > 0 && (
                <button className="trace-clear" onClick={() => setTraceLogs([])}>Clear</button>
              )}
            </div>
            <div className="trace-logs">
              {traceLogs.length === 0 ? (
                <div className="trace-empty">Waiting for query execution...</div>
              ) : (
                traceLogs.map((log, i) => (
                  <div key={i} className={`trace-log ${log.type}`}>
                    <span className="trace-time">{log.timestamp}</span>
                    <span className={`trace-type ${log.type}`}>
                      {log.type === "info" ? "INFO" : log.type === "route" ? "ROUTE" : log.type === "query" ? "QUERY" : "RESP"}
                    </span>
                    <span className="trace-msg">{log.message}</span>
                  </div>
                ))
              )}
            </div>
          </div>
        </main>

        {/* Chat Panel */}
        <aside className="chat-panel">
          <div className="chat-header">
            <h2>Chat</h2>
            <div className="chat-status">
              {isLoading && <span className="status-dot pulse"></span>}
              <span>{isLoading ? "Processing..." : "Ready"}</span>
            </div>
          </div>

          <div className="quick-actions">
            {predefinedQuestions.map((q, i) => (
              <button
                key={i}
                className="quick-action-btn"
                onClick={() => sendMessage(q.text)}
                disabled={isLoading}
              >
                {q.text}
              </button>
            ))}
          </div>

          <div className="messages">
            {messages.length === 0 && (
              <div className="empty-state">
                <div className="empty-text">Start a conversation</div>
                <div className="empty-subtext">Ask a question or click a quick action above</div>
              </div>
            )}
            {messages.map((msg, i) => (
              <div key={i} className={`message ${msg.role}`}>
                {msg.agent && (
                  <div className="message-header">
                    <span className="agent-icon">{sourceLogos[msg.agent] || "🤖"}</span>
                    <span className="agent-name">{msg.agent}</span>
                  </div>
                )}
                <div className="message-content" dangerouslySetInnerHTML={{ __html: formatMarkdown(msg.content) }} />
                {msg.agent && (
                  <div className="message-sources">
                    <span className="source-label">Sources:</span>
                    <div className="source-list">
                      {msg.sources && msg.sources.length > 0 ? (
                        msg.sources.map((src, idx) => (
                          <span key={idx} className="source-doc">
                            <span className="source-doc-title">{src.title || src.filepath || "Document"}</span>
                            <span className="source-doc-kb">({src.kb})</span>
                          </span>
                        ))
                      ) : (
                        <span className="source-name">
                          {msg.agent.replace("-agent", "") === "hr" ? "kb1-hr" : msg.agent.replace("-agent", "") === "marketing" ? "kb2-marketing" : "kb3-products"}
                        </span>
                      )}
                    </div>
                  </div>
                )}
              </div>
            ))}
            {isLoading && (
              <div className="message assistant loading">
                <div className="loading-indicator">
                  <span></span><span></span><span></span>
                </div>
                <span className="loading-text">
                  {workflowStep === "routing" ? "Routing query..." : `${activeAgent} processing...`}
                </span>
              </div>
            )}
          </div>

          <div className="input-area">
            <input
              type="text"
              value={input}
              onChange={(e) => setInput(e.target.value)}
              onKeyPress={(e) => e.key === "Enter" && sendMessage()}
              placeholder="Ask a question..."
              disabled={isLoading}
            />
            <button onClick={() => sendMessage()} disabled={isLoading || !input.trim()}>
              Send
            </button>
          </div>
        </aside>
      </div>
    </div>
  );
}

export default App;
