import { useState, useEffect, useRef } from 'react';
import '../styles/CommandPalette.css';

interface WindowInfo {
  id: string;
  title: string;
  app_name: string;
  workspace?: string;
}

interface CommandPaletteProps {
  windows: WindowInfo[];
  onClose: () => void;
  onSelectWindow: (id: string) => void;
}

function CommandPalette({ windows, onClose, onSelectWindow }: CommandPaletteProps) {
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedIndex, setSelectedIndex] = useState(0);
  const inputRef = useRef<HTMLInputElement>(null);

  const filteredWindows = windows.filter(
    (w) =>
      w.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
      w.app_name.toLowerCase().includes(searchQuery.toLowerCase())
  );

  useEffect(() => {
    inputRef.current?.focus();

    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        onClose();
      } else if (e.key === 'ArrowDown') {
        e.preventDefault();
        setSelectedIndex((prev) => Math.min(prev + 1, filteredWindows.length - 1));
      } else if (e.key === 'ArrowUp') {
        e.preventDefault();
        setSelectedIndex((prev) => Math.max(prev - 1, 0));
      } else if (e.key === 'Enter' && filteredWindows[selectedIndex]) {
        e.preventDefault();
        onSelectWindow(filteredWindows[selectedIndex].id);
        onClose();
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [selectedIndex, filteredWindows, onClose, onSelectWindow]);

  return (
    <div className="command-palette-overlay" onClick={onClose}>
      <div className="command-palette" onClick={(e) => e.stopPropagation()}>
        <input
          ref={inputRef}
          type="text"
          className="command-palette-input"
          placeholder="Search windows..."
          value={searchQuery}
          onChange={(e) => {
            setSearchQuery(e.target.value);
            setSelectedIndex(0);
          }}
        />
        <div className="command-palette-results">
          {filteredWindows.length === 0 ? (
            <div className="no-results">No windows found</div>
          ) : (
            filteredWindows.map((window, index) => (
              <div
                key={window.id}
                className={`command-palette-item ${index === selectedIndex ? 'selected' : ''}`}
                onClick={() => {
                  onSelectWindow(window.id);
                  onClose();
                }}
              >
                <div className="item-icon">📱</div>
                <div className="item-content">
                  <div className="item-title">{window.title}</div>
                  <div className="item-subtitle">{window.app_name}</div>
                </div>
                {window.workspace && (
                  <div className="item-badge">{window.workspace}</div>
                )}
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  );
}

export default CommandPalette;
