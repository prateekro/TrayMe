# TrayMe Desktop OS - Architecture Documentation

## Overview

TrayMe Desktop OS is a comprehensive cross-platform Desktop Operating Layer built with Tauri 2.0, combining a Rust backend with a React/TypeScript frontend. This architecture provides a foundation for building advanced desktop productivity tools with privacy-first AI integration.

## Technology Stack

### Backend (Rust)
- **Tauri 2.0**: Cross-platform application framework
- **SQLx**: Type-safe SQL database access (SQLite)
- **Tokio**: Async runtime for concurrent operations
- **Serde**: Serialization/deserialization framework
- **AES-GCM**: Military-grade encryption
- **Tracing**: Structured logging and diagnostics
- **Anyhow/Thiserror**: Error handling

### Frontend (TypeScript/React)
- **React 18**: Modern UI framework with hooks
- **TypeScript 5**: Type-safe JavaScript
- **Vite**: Lightning-fast build tool and dev server
- **CSS3**: Modern styling with custom properties

## Architecture Layers

### 1. Presentation Layer (React Frontend)

```
src/
├── components/          # Reusable UI components
│   ├── CommandPalette/  # Universal search and command interface
│   ├── WindowManager/   # Window tray management UI
│   ├── AIPanel/         # AI assistant interface
│   ├── Integrations/    # (Planned) Integration UIs
│   ├── SettingsPanel/   # (Planned) Settings UI
│   └── NotificationCenter/ # (Planned) Notifications
├── hooks/               # React hooks for business logic
│   ├── useAI.ts         # (Planned) AI interaction hook
│   ├── useIntegrations.ts # (Planned) Integrations hook
│   ├── useStorage.ts    # (Planned) Storage hook
│   └── useTauriState.ts # (Planned) State management hook
├── lib/                 # Utility libraries
│   ├── tauriCommands.ts # Tauri command wrappers
│   ├── crypto.ts        # (Planned) Client-side crypto
│   ├── storage.ts       # (Planned) IndexedDB wrapper
│   └── piiDetection.ts  # (Planned) PII detection
├── pages/               # Page components
│   ├── App.tsx          # Main app shell
│   ├── Dashboard.tsx    # (Planned) Overview/status
│   └── Settings.tsx     # (Planned) Settings page
└── styles/              # CSS stylesheets
    ├── index.css        # Global styles
    ├── App.css          # App-level styles
    ├── CommandPalette.css
    ├── WindowManager.css
    └── AIPanel.css
```

### 2. Application Layer (Tauri Commands)

Tauri commands provide a secure RPC bridge between frontend and backend:

```rust
// Window management
minimize_to_tray(title, app_name) -> id
restore_from_tray(id) -> WindowInfo
list_windows() -> Vec<WindowInfo>
get_window_preview(id) -> Option<Vec<u8>>

// Storage
initialize_database() -> String
save_workspace(id, name, description, data) -> ()
load_workspace(id) -> Option<WorkspaceInfo>

// AI (placeholder implementations)
query_llm(prompt, context) -> LLMResponse
capture_screen() -> Vec<u8>
analyze_screenshot(image) -> ScreenshotAnalysis

// Cryptography
encrypt_data(data, key) -> String
decrypt_data(encrypted, key) -> String
```

### 3. Business Logic Layer (Managers)

```
src-tauri/src/managers/
├── window_manager.rs      # Track and manage trayed windows
│   ├── TrayedWindow struct
│   ├── add_to_tray()
│   ├── remove_from_tray()
│   ├── list_trayed_windows()
│   └── update_window()
│
├── storage_manager.rs     # SQLite database operations
│   ├── Database initialization
│   ├── Schema migrations
│   ├── Workspace persistence
│   └── Settings storage
│
├── ai_manager.rs          # (Planned) LLM sidecar management
│   ├── Model loading
│   ├── Inference execution
│   ├── Context management
│   └── RAG integration
│
├── sync_manager.rs        # (Planned) E2EE sync
│   ├── Encryption/decryption
│   ├── Conflict resolution
│   ├── Remote sync
│   └── Local caching
│
├── integration_manager.rs # (Planned) API integrations
│   ├── OAuth flow
│   ├── API clients
│   ├── Rate limiting
│   └── Credential storage
│
└── plugin_manager.rs      # (Planned) Plugin lifecycle
    ├── Plugin loading
    ├── Permission checking
    ├── IPC coordination
    └── Plugin sandboxing
```

### 4. Data Layer

#### SQLite Database Schema

```sql
-- Workspaces: Save/restore window collections
CREATE TABLE workspaces (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  windows_data TEXT NOT NULL,  -- JSON array of window IDs
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

-- Settings: Application configuration
CREATE TABLE settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at INTEGER NOT NULL
);

-- Documents: RAG document storage (for AI)
CREATE TABLE documents (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  embedding BLOB,           -- Vector embeddings (future)
  metadata TEXT,            -- JSON metadata
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

-- Future tables
-- credentials: OAuth tokens and API keys (encrypted)
-- sync_state: Synchronization state tracking
-- plugins: Plugin metadata and state
-- analytics: Privacy-first usage metrics
```

#### File System Layout

```
~/.local/share/TrayMe Desktop OS/ (Linux)
~/Library/Application Support/TrayMe Desktop OS/ (macOS)
%APPDATA%/TrayMe Desktop OS/ (Windows)

├── trayme.db              # SQLite database
├── logs/                  # Application logs
│   ├── app.log
│   └── error.log
├── cache/                 # Temporary cache
│   ├── thumbnails/
│   └── previews/
├── plugins/               # (Planned) Installed plugins
│   └── plugin-id/
└── sidecars/              # (Planned) Sidecar binaries
    └── llama-cpp/
```

## Security Architecture

### 1. Capability-Based Access Control

```rust
// Commands explicitly registered
.invoke_handler(tauri::generate_handler![
    commands::window::minimize_to_tray,
    commands::window::restore_from_tray,
    // ... only registered commands can be invoked
])
```

Frontend cannot:
- Execute arbitrary Rust code
- Access filesystem directly
- Make network requests without permission
- Call unregistered functions

### 2. Data Encryption

**At Rest:**
- AES-256-GCM for sensitive data
- Encrypted before database storage
- Keys derived from user password + salt

**In Transit (Planned):**
- End-to-end encryption for sync
- TLS 1.3 for all network requests
- Certificate pinning for APIs

**Key Storage:**
- OS keychain integration (macOS Keychain, Windows Credential Manager, Linux Secret Service)
- Never stored in plaintext
- Automatic key rotation

### 3. Sandboxing (Planned)

**Plugin Isolation:**
```rust
pub struct PluginCapabilities {
    pub can_read_files: Vec<PathBuf>,    // Whitelisted paths only
    pub can_write_files: Vec<PathBuf>,   // Whitelisted paths only
    pub can_network: bool,                // Network access flag
    pub can_execute: Vec<String>,         // Whitelisted commands only
    pub max_memory_mb: u64,               // Memory limit
    pub max_cpu_percent: u8,              // CPU limit
}
```

Each plugin runs with:
- Limited file system access
- Controlled network access
- CPU/memory quotas
- Process isolation

### 4. Input Validation

All inputs validated at multiple layers:

```rust
#[command]
pub async fn safe_command(input: String) -> Result<String, String> {
    // 1. Type validation (Rust type system)
    if input.is_empty() {
        return Err("Input cannot be empty".to_string());
    }
    
    // 2. Length validation
    if input.len() > 10000 {
        return Err("Input too long".to_string());
    }
    
    // 3. Content validation (sanitize)
    let sanitized = sanitize_input(&input)?;
    
    // 4. Business logic validation
    validate_business_rules(&sanitized)?;
    
    // Process safely
    Ok(process(&sanitized))
}
```

## Component Communication

```
┌─────────────────────────────────────────────────────────┐
│                  React Frontend                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │  Command     │  │   Window     │  │   AI Panel   │ │
│  │  Palette     │  │   Manager    │  │              │ │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘ │
│         │                 │                  │          │
│         └─────────────────┴──────────────────┘          │
│                     Tauri Bridge (IPC)                  │
└───────────────────────────┼─────────────────────────────┘
                            │
┌───────────────────────────┼─────────────────────────────┐
│                    Tauri Commands                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │   Window     │  │   Storage    │  │     AI       │ │
│  │   Commands   │  │   Commands   │  │   Commands   │ │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘ │
│         │                 │                  │          │
│         └─────────────────┴──────────────────┘          │
│                     State Layer                         │
└───────────────────────────┼─────────────────────────────┘
                            │
┌───────────────────────────┼─────────────────────────────┐
│                      Managers                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │   Window     │  │   Storage    │  │     AI       │ │
│  │   Manager    │  │   Manager    │  │   Manager    │ │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘ │
│         │                 │                  │          │
│         └─────────────────┴──────────────────┘          │
│                  Business Logic                         │
└───────────────────────────┼─────────────────────────────┘
                            │
┌───────────────────────────┼─────────────────────────────┐
│                    Data Storage                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │   SQLite     │  │  File System │  │   Keychain   │ │
│  │   Database   │  │              │  │   (Planned)  │ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
└─────────────────────────────────────────────────────────┘
```

### IPC Flow Example

```typescript
// 1. Frontend initiates command
const windowId = await invoke('minimize_to_tray', {
  title: 'My Window',
  appName: 'TextEdit'
});

// 2. Tauri validates and routes
// 3. Command handler executes
#[command]
async fn minimize_to_tray(
    title: String,
    app_name: String,
    state: State<'_, AppState>,
) -> Result<String, String> {
    // 4. Manager processes request
    let window = TrayedWindow::new(title, app_name);
    let id = window.id.clone();
    
    let mut window_manager = state.window_manager.write().await;
    window_manager.add_to_tray(window);
    
    // 5. Return result
    Ok(id)
}

// 6. Frontend receives response
console.log('Window ID:', windowId);
```

## State Management

### Backend State (Rust)

```rust
pub struct AppState {
    pub app_handle: AppHandle,
    pub storage_manager: Arc<RwLock<StorageManager>>,
    pub window_manager: Arc<RwLock<WindowManager>>,
    // Planned:
    // pub ai_manager: Arc<RwLock<AIManager>>,
    // pub sync_manager: Arc<RwLock<SyncManager>>,
    // pub integration_manager: Arc<RwLock<IntegrationManager>>,
    // pub plugin_manager: Arc<RwLock<PluginManager>>,
}
```

- **Arc**: Atomic reference counting for shared ownership
- **RwLock**: Read-write lock for concurrent access
- Multiple readers OR single writer at a time
- Prevents data races at compile time

### Frontend State (React)

**Current:**
- Component-level with `useState`
- Props drilling for shared data

**Planned:**
- Zustand for global state
- React Context for theming
- IndexedDB for offline caching
- Local storage for preferences

## AI Integration Architecture (Planned)

### Local LLM Sidecar

```
┌─────────────────────┐
│  Tauri Main Process │
│  - Command routing  │
│  - State management │
└──────────┬──────────┘
           │
    ┌──────▼───────┐
    │  AI Manager  │
    │  - Model mgmt│
    │  - Queuing   │
    └──────┬───────┘
           │
    ┌──────▼──────────────────┐
    │ llama.cpp Sidecar       │
    │ - Hardware detection    │
    │ - CUDA/Metal/Vulkan     │
    │ - Model loading         │
    │ - Inference execution   │
    └─────────────────────────┘
```

**Model Selection:**
- Auto-detect hardware (NVIDIA GPU, Apple Silicon, CPU-only)
- Load appropriate quantized model (Q4, Q5, Q8)
- Support for GGUF format models
- Memory-efficient loading

### RAG Pipeline

```
1. Document Ingestion
   ├── PDF/DOCX extraction
   ├── Text cleaning
   └── Metadata extraction

2. Chunking
   ├── Semantic splitting
   ├── Context preservation
   └── Overlap handling

3. Embedding Generation
   ├── Local embedding model
   ├── Vector generation
   └── Batch processing

4. Storage
   ├── SQLite with pgvector
   ├── Vector indexing (HNSW)
   └── Metadata storage

5. Query Processing
   ├── Query embedding
   ├── Similarity search
   ├── Context retrieval
   └── LLM prompt construction

6. Response Generation
   ├── Context injection
   ├── LLM inference
   └── Citation extraction
```

## Plugin Architecture (Planned)

### Plugin Interface

```rust
pub trait Plugin {
    fn id(&self) -> &str;
    fn name(&self) -> &str;
    fn version(&self) -> &str;
    
    fn init(&mut self, context: PluginContext) -> Result<()>;
    fn commands(&self) -> Vec<Command>;
    fn permissions(&self) -> Permissions;
    
    fn on_load(&mut self) -> Result<()>;
    fn on_unload(&mut self) -> Result<()>;
}
```

### Plugin Lifecycle

```
1. Discovery
   ├── Scan plugins directory
   ├── Validate manifest
   └── Check dependencies

2. Loading
   ├── Load dynamic library
   ├── Verify signature
   ├── Check permissions
   └── Initialize plugin

3. Execution
   ├── Register commands
   ├── Mount UI components
   ├── Start sidecars
   └── Monitor resources

4. Unloading
   ├── Cleanup resources
   ├── Remove commands
   ├── Stop sidecars
   └── Unload library
```

## Performance Considerations

### Backend

**Async I/O:**
```rust
// All I/O operations use tokio async runtime
#[command]
async fn database_query() -> Result<Data, String> {
    let pool = state.storage_manager.read().await.pool();
    sqlx::query_as("SELECT * FROM data")
        .fetch_all(pool)
        .await
        .map_err(|e| e.to_string())
}
```

**Connection Pooling:**
- SQLite connection pool (5 connections)
- HTTP client connection reuse
- WebSocket connection pooling

**Resource Management:**
- Lazy loading of heavy resources
- Background workers for long tasks
- Memory-mapped file I/O
- Stream processing for large data

### Frontend

**Code Splitting:**
```typescript
// Lazy load components
const AIPanel = lazy(() => import('./components/AIPanel'));
const Settings = lazy(() => import('./pages/Settings'));
```

**Virtual Scrolling:**
- Render only visible items
- Windowing for large lists
- Progressive loading

**Debouncing:**
```typescript
const debouncedSearch = useMemo(
  () => debounce((query) => search(query), 300),
  []
);
```

## Error Handling

### Rust Error Types

```rust
#[derive(Error, Debug)]
pub enum AppError {
    #[error("Database error: {0}")]
    Database(#[from] sqlx::Error),
    
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
    
    #[error("Encryption error: {0}")]
    Encryption(String),
    
    #[error("Not found: {0}")]
    NotFound(String),
}
```

### Error Propagation

```rust
#[command]
async fn fallible_operation() -> Result<Data, String> {
    let result = risky_operation()
        .await
        .map_err(|e| format!("Operation failed: {}", e))?;
    
    Ok(result)
}
```

### Frontend Error Handling

```typescript
try {
  const result = await invoke('command');
} catch (error) {
  console.error('Command failed:', error);
  // Show user-friendly error message
  setError(formatError(error));
}
```

## Logging & Monitoring

### Structured Logging

```rust
tracing::info!(
    window_id = %id,
    action = "minimize_to_tray",
    "Window minimized to tray"
);
```

### Log Levels

- **ERROR**: Application errors requiring attention
- **WARN**: Warning conditions
- **INFO**: Informational messages
- **DEBUG**: Debugging information
- **TRACE**: Detailed trace information

### Log Rotation

- Daily rotation
- Max 100MB per file
- Keep 7 days of logs
- Compress old logs

## Testing Strategy

### Unit Tests (Rust)

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_window_manager() {
        let mut manager = WindowManager::new();
        let window = TrayedWindow::new("Test".to_string(), "App".to_string());
        let id = manager.add_to_tray(window);
        assert!(manager.get_trayed_window(&id).is_some());
    }
}
```

### Integration Tests

- Frontend-backend communication
- Database operations
- File system operations
- Encryption/decryption

### E2E Tests (Planned)

- User workflows
- Plugin loading
- Update mechanism
- Cross-platform compatibility

## Future Enhancements

1. **Computer Use API**: Anthropic integration for autonomous tasks
2. **Voice Control**: Whisper.cpp integration with wake-word detection
3. **Advanced RAG**: pgvector or LanceDB for vector search
4. **E2EE Sync**: Multi-device synchronization with zero-knowledge servers
5. **Plugin Marketplace**: Extension ecosystem with ratings and reviews
6. **Integration Hub**: Linear, Notion, GitHub, Slack connectors
7. **Social Publishing**: Multi-platform content distribution
8. **Mobile Companion**: iOS/Android apps for remote control

## References

- [Tauri Documentation](https://tauri.app)
- [React Documentation](https://react.dev)
- [SQLx Documentation](https://github.com/launchbadge/sqlx)
- [llama.cpp](https://github.com/ggerganov/llama.cpp)
- [Whisper.cpp](https://github.com/ggerganov/whisper.cpp)
