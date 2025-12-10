# TrayMe Desktop OS - API Reference

## Tauri Commands

Tauri commands provide a secure RPC interface between the frontend (TypeScript) and backend (Rust).

### Window Management

#### `minimize_to_tray`

Minimize a window to the tray.

**Parameters:**
- `title: string` - The window title
- `app_name: string` - The application name

**Returns:** `string` - The unique window ID

**Example:**
```typescript
import { invoke } from '@tauri-apps/api/core';

const windowId = await invoke<string>('minimize_to_tray', {
  title: 'My Document',
  appName: 'TextEdit'
});
```

#### `restore_from_tray`

Restore a window from the tray.

**Parameters:**
- `id: string` - The window ID

**Returns:** `WindowInfo` - Window information

**Example:**
```typescript
const windowInfo = await invoke<WindowInfo>('restore_from_tray', {
  id: 'window-id-here'
});
```

#### `list_windows`

List all windows in the tray.

**Returns:** `WindowInfo[]` - Array of window information

**Example:**
```typescript
const windows = await invoke<WindowInfo[]>('list_windows');
```

#### `get_window_preview`

Get a preview image for a window (placeholder - returns None).

**Parameters:**
- `id: string` - The window ID

**Returns:** `number[] | null` - Preview image data (RGBA bytes) or null

**Example:**
```typescript
const preview = await invoke<number[] | null>('get_window_preview', {
  id: 'window-id-here'
});
```

### Storage

#### `initialize_database`

Initialize the SQLite database.

**Returns:** `string` - Database file path

**Example:**
```typescript
const dbPath = await invoke<string>('initialize_database');
console.log('Database at:', dbPath);
```

#### `save_workspace`

Save a workspace configuration.

**Parameters:**
- `id: string` - Workspace ID
- `name: string` - Workspace name
- `description: string | null` - Optional description
- `windows_data: string` - JSON string of window IDs

**Returns:** `void`

**Example:**
```typescript
await invoke('save_workspace', {
  id: 'workspace-1',
  name: 'Development',
  description: 'My dev workspace',
  windowsData: JSON.stringify(['window-1', 'window-2'])
});
```

#### `load_workspace`

Load a workspace configuration.

**Parameters:**
- `id: string` - Workspace ID

**Returns:** `WorkspaceInfo | null` - Workspace data or null if not found

**Example:**
```typescript
const workspace = await invoke<WorkspaceInfo | null>('load_workspace', {
  id: 'workspace-1'
});
```

### AI (Placeholder)

#### `query_llm`

Query the local LLM (currently returns placeholder response).

**Parameters:**
- `query: LLMQuery` - Query object with prompt and optional context

**Returns:** `LLMResponse` - LLM response

**Example:**
```typescript
const response = await invoke<LLMResponse>('query_llm', {
  query: {
    prompt: 'Explain this code',
    context: 'function hello() { ... }'
  }
});
```

#### `capture_screen`

Capture the current screen (currently returns empty array).

**Returns:** `number[]` - Screenshot image data

**Example:**
```typescript
const imageData = await invoke<number[]>('capture_screen');
```

#### `analyze_screenshot`

Analyze a screenshot with a vision model (currently returns placeholder).

**Parameters:**
- `image_data: number[]` - Image data bytes

**Returns:** `ScreenshotAnalysis` - Analysis results

**Example:**
```typescript
const analysis = await invoke<ScreenshotAnalysis>('analyze_screenshot', {
  imageData: [/* image bytes */]
});
```

### Cryptography

#### `encrypt_data`

Encrypt data using AES-256-GCM.

**Parameters:**
- `data: string` - Data to encrypt
- `key: string` - Base64-encoded 32-byte encryption key

**Returns:** `string` - Base64-encoded encrypted data (nonce + ciphertext)

**Example:**
```typescript
const encrypted = await invoke<string>('encrypt_data', {
  data: 'Secret message',
  key: 'base64-encoded-32-byte-key'
});
```

#### `decrypt_data`

Decrypt data using AES-256-GCM.

**Parameters:**
- `encrypted_data: string` - Base64-encoded encrypted data
- `key: string` - Base64-encoded 32-byte encryption key

**Returns:** `string` - Decrypted plaintext

**Example:**
```typescript
const plaintext = await invoke<string>('decrypt_data', {
  encryptedData: 'base64-encrypted-data',
  key: 'base64-encoded-32-byte-key'
});
```

## Type Definitions

### WindowInfo

```typescript
interface WindowInfo {
  id: string;
  title: string;
  app_name: string;
  workspace?: string;
}
```

### WorkspaceInfo

```typescript
interface WorkspaceInfo {
  id: string;
  name: string;
  description?: string;
  windows: string[];
}
```

### LLMQuery

```typescript
interface LLMQuery {
  prompt: string;
  context?: string;
}
```

### LLMResponse

```typescript
interface LLMResponse {
  response: string;
  model: string;
}
```

### ScreenshotAnalysis

```typescript
interface ScreenshotAnalysis {
  description: string;
  elements: string[];
  suggestions: string[];
}
```

## Error Handling

All commands return `Promise<T>` which may reject with an error string. Always use try-catch:

```typescript
try {
  const result = await invoke('some_command', { args });
} catch (error) {
  console.error('Command failed:', error);
}
```

## Security Notes

1. **Encryption Keys**: Always use 32-byte (256-bit) keys encoded in base64
2. **Input Validation**: All inputs are validated on the Rust side
3. **Capability Control**: Commands must be explicitly registered in `main.rs`
4. **No XSS**: Tauri's architecture prevents XSS attacks from commands

## Future APIs

These APIs are planned for future releases:

- **Voice Control**: `start_voice_recognition`, `stop_voice_recognition`
- **Screen Recording**: `start_recording`, `stop_recording`
- **Integrations**: `connect_github`, `connect_linear`, `connect_notion`
- **Sync**: `start_sync`, `stop_sync`, `sync_status`
- **Plugins**: `load_plugin`, `unload_plugin`, `list_plugins`
