import { useState, useEffect } from 'react';
import { invoke } from '@tauri-apps/api/core';
import CommandPalette from './components/CommandPalette';
import WindowManager from './components/WindowManager';
import AIPanel from './components/AIPanel';
import './styles/App.css';

interface WindowInfo {
  id: string;
  title: string;
  app_name: string;
  workspace?: string;
}

function App() {
  const [windows, setWindows] = useState<WindowInfo[]>([]);
  const [showCommandPalette, setShowCommandPalette] = useState(false);
  const [activeView, setActiveView] = useState<'windows' | 'ai' | 'settings'>('windows');

  useEffect(() => {
    loadWindows();

    // Set up keyboard shortcut for command palette (Cmd/Ctrl + K)
    const handleKeyDown = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
        e.preventDefault();
        setShowCommandPalette(prev => !prev);
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, []);

  const loadWindows = async () => {
    try {
      const result = await invoke<WindowInfo[]>('list_windows');
      setWindows(result);
    } catch (error) {
      console.error('Failed to load windows:', error);
    }
  };

  const handleMinimizeToTray = async (title: string, appName: string) => {
    try {
      await invoke('minimize_to_tray', { title, appName });
      await loadWindows();
    } catch (error) {
      console.error('Failed to minimize to tray:', error);
    }
  };

  const handleRestoreWindow = async (id: string) => {
    try {
      await invoke('restore_from_tray', { id });
      await loadWindows();
    } catch (error) {
      console.error('Failed to restore window:', error);
    }
  };

  return (
    <div className="app-container">
      <header className="app-header">
        <h1>TrayMe Desktop OS</h1>
        <nav className="nav-tabs">
          <button
            className={activeView === 'windows' ? 'active' : ''}
            onClick={() => setActiveView('windows')}
          >
            Windows
          </button>
          <button
            className={activeView === 'ai' ? 'active' : ''}
            onClick={() => setActiveView('ai')}
          >
            AI Assistant
          </button>
          <button
            className={activeView === 'settings' ? 'active' : ''}
            onClick={() => setActiveView('settings')}
          >
            Settings
          </button>
        </nav>
        <button
          className="command-palette-btn"
          onClick={() => setShowCommandPalette(!showCommandPalette)}
          title="Command Palette (Cmd/Ctrl + K)"
        >
          ⌘ K
        </button>
      </header>

      <main className="app-main">
        {activeView === 'windows' && (
          <WindowManager
            windows={windows}
            onMinimize={handleMinimizeToTray}
            onRestore={handleRestoreWindow}
            onRefresh={loadWindows}
          />
        )}
        {activeView === 'ai' && <AIPanel />}
        {activeView === 'settings' && (
          <div className="settings-placeholder">
            <h2>Settings</h2>
            <p>Settings panel coming soon...</p>
          </div>
        )}
      </main>

      {showCommandPalette && (
        <CommandPalette
          windows={windows}
          onClose={() => setShowCommandPalette(false)}
          onSelectWindow={handleRestoreWindow}
        />
      )}
    </div>
  );
}

export default App;
