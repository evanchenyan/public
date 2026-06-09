import React, { useState, useEffect } from 'react';

const API_BASE = import.meta.env.VITE_API_BASE || '';

function App() {
  const [goHealth, setGoHealth] = useState(null);
  const [javaHealth, setJavaHealth] = useState(null);

  const checkHealth = async (service, setter) => {
    try {
      const res = await fetch(`${API_BASE}/api/${service}/health`);
      const data = await res.json();
      setter(data);
    } catch {
      setter({ status: 'error' });
    }
  };

  useEffect(() => {
    checkHealth('go', setGoHealth);
    checkHealth('java', setJavaHealth);
  }, []);

  const refreshAll = () => {
    setGoHealth(null);
    setJavaHealth(null);
    checkHealth('go', setGoHealth);
    checkHealth('java', setJavaHealth);
  };

  return (
    <div className="container">
      <h1>Gitea CI Demo</h1>
      <p className="subtitle">前后端分离 · Kaniko 构建 · 自动部署</p>

      <div className="status-grid">
        <div className={`card ${goHealth?.status === 'ok' ? 'success' : ''}`}>
          <h3>
            <span className={`status-dot ${goHealth?.status === 'ok' ? 'dot-green' : 'dot-red'}`} />
            Go 后端
          </h3>
          <p>
            {goHealth
              ? `${goHealth.status} · v${goHealth.version || '?'}`
              : '检测中...'}
          </p>
        </div>

        <div className={`card ${javaHealth?.status === 'ok' ? 'success' : ''}`}>
          <h3>
            <span className={`status-dot ${javaHealth?.status === 'ok' ? 'dot-green' : 'dot-red'}`} />
            Java 后端
          </h3>
          <p>
            {javaHealth
              ? `${javaHealth.status} · v${javaHealth.version || '?'}`
              : '检测中...'}
          </p>
        </div>
      </div>

      <button className="btn" onClick={refreshAll}>
        刷新状态
      </button>
    </div>
  );
}

export default App;
