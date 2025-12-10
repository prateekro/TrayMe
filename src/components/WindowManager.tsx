import { useState } from 'react';
import '../styles/WindowManager.css';

interface WindowInfo {
  id: string;
  title: string;
  app_name: string;
  workspace?: string;
}

interface WindowManagerProps {
  windows: WindowInfo[];
  onMinimize: (title: string, appName: string) => void;
  onRestore: (id: string) => void;
  onRefresh: () => void;
}

function WindowManager({ windows, onMinimize, onRestore, onRefresh }: WindowManagerProps) {
  const [newWindowTitle, setNewWindowTitle] = useState('');
  const [newWindowApp, setNewWindowApp] = useState('');

  const handleAddWindow = () => {
    if (newWindowTitle && newWindowApp) {
      onMinimize(newWindowTitle, newWindowApp);
      setNewWindowTitle('');
      setNewWindowApp('');
    }
  };

  return (
    <div className="window-manager">
      <div className="window-manager-header">
        <h2>Trayed Windows ({windows.length})</h2>
        <button onClick={onRefresh} className="refresh-btn">
          ↻ Refresh
        </button>
      </div>

      <div className="add-window-form">
        <h3>Add Window to Tray</h3>
        <div className="form-row">
          <input
            type="text"
            placeholder="Window title"
            value={newWindowTitle}
            onChange={(e) => setNewWindowTitle(e.target.value)}
            onKeyPress={(e) => e.key === 'Enter' && handleAddWindow()}
          />
          <input
            type="text"
            placeholder="App name"
            value={newWindowApp}
            onChange={(e) => setNewWindowApp(e.target.value)}
            onKeyPress={(e) => e.key === 'Enter' && handleAddWindow()}
          />
          <button onClick={handleAddWindow} className="add-btn">
            Add to Tray
          </button>
        </div>
      </div>

      <div className="windows-grid">
        {windows.length === 0 ? (
          <div className="empty-state">
            <p>No windows in tray</p>
            <p className="empty-state-hint">
              Add windows above to get started
            </p>
          </div>
        ) : (
          windows.map((window) => (
            <div key={window.id} className="window-card">
              <div className="window-card-header">
                <div className="window-icon">📱</div>
                <div className="window-info">
                  <h4>{window.title}</h4>
                  <p>{window.app_name}</p>
                </div>
              </div>
              {window.workspace && (
                <div className="window-workspace">
                  Workspace: {window.workspace}
                </div>
              )}
              <div className="window-card-actions">
                <button
                  onClick={() => onRestore(window.id)}
                  className="restore-btn"
                >
                  Restore
                </button>
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
}

export default WindowManager;
