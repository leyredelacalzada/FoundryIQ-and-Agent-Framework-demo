import { useState } from "react";

interface Message {
  role: "user" | "assistant";
  content: string;
  agent?: string;
}

function App() {
  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput] = useState("");
  const [isLoading, setIsLoading] = useState(false);

  const sendMessage = async () => {
    if (!input.trim()) return;

    const userMessage: Message = { role: "user", content: input };
    setMessages((prev) => [...prev, userMessage]);
    setInput("");
    setIsLoading(true);

    try {
      const response = await fetch("/chat", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ message: input }),
      });
      const data = await response.json();
      const assistantMessage: Message = {
        role: "assistant",
        content: data.message,
        agent: data.agent,
      };
      setMessages((prev) => [...prev, assistantMessage]);
    } catch (error) {
      console.error("Error:", error);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="app">
      <header>
        <h1>FoundryIQ Agent Framework Demo</h1>
      </header>
      <main>
        <div className="messages">
          {messages.map((msg, i) => (
            <div key={i} className={`message ${msg.role}`}>
              {msg.agent && <span className="agent">{msg.agent}</span>}
              <p>{msg.content}</p>
            </div>
          ))}
          {isLoading && <div className="loading">Thinking...</div>}
        </div>
        <div className="input-area">
          <input
            type="text"
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyPress={(e) => e.key === "Enter" && sendMessage()}
            placeholder="Ask a question..."
          />
          <button onClick={sendMessage} disabled={isLoading}>
            Send
          </button>
        </div>
      </main>
    </div>
  );
}

export default App;
