import { useState } from 'react';
import { invoke } from '@tauri-apps/api/core';
import '../styles/AIPanel.css';

interface LLMResponse {
  response: string;
  model: string;
}

function AIPanel() {
  const [query, setQuery] = useState('');
  const [response, setResponse] = useState<LLMResponse | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleQuery = async () => {
    if (!query.trim()) return;

    setLoading(true);
    setError(null);

    try {
      const result = await invoke<LLMResponse>('query_llm', {
        query: { prompt: query, context: null },
      });
      setResponse(result);
    } catch (err) {
      setError(err as string);
      console.error('Failed to query LLM:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleCaptureScreen = async () => {
    setLoading(true);
    setError(null);

    try {
      const imageData = await invoke<number[]>('capture_screen');
      const analysis = await invoke('analyze_screenshot', { imageData });
      console.log('Screenshot analysis:', analysis);
    } catch (err) {
      setError(err as string);
      console.error('Failed to capture screen:', err);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="ai-panel">
      <div className="ai-panel-header">
        <h2>AI Assistant</h2>
        <p className="ai-panel-subtitle">Local LLM powered by your device</p>
      </div>

      <div className="ai-actions">
        <button onClick={handleCaptureScreen} disabled={loading} className="capture-btn">
          📷 Capture & Analyze Screen
        </button>
      </div>

      <div className="ai-chat">
        <textarea
          className="ai-input"
          placeholder="Ask me anything..."
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          onKeyPress={(e) => {
            if (e.key === 'Enter' && !e.shiftKey) {
              e.preventDefault();
              handleQuery();
            }
          }}
          disabled={loading}
        />
        <button onClick={handleQuery} disabled={loading || !query.trim()} className="query-btn">
          {loading ? 'Thinking...' : 'Send'}
        </button>
      </div>

      {error && (
        <div className="ai-error">
          <strong>Error:</strong> {error}
        </div>
      )}

      {response && (
        <div className="ai-response">
          <div className="response-header">
            <strong>Response</strong>
            <span className="model-badge">{response.model}</span>
          </div>
          <div className="response-content">{response.response}</div>
        </div>
      )}

      <div className="ai-info">
        <p>
          <strong>Note:</strong> Local LLM integration is currently a placeholder.
          Future versions will include llama.cpp or Ollama integration for privacy-first AI.
        </p>
      </div>
    </div>
  );
}

export default AIPanel;
