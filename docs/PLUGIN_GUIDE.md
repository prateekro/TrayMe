# Plugin Development Guide

## Overview

TrayMe Desktop OS supports a modular plugin architecture that allows extending functionality while maintaining security and stability.

## Plugin Types

### 1. Command Plugins
Add new Tauri commands to extend the RPC interface.

### 2. UI Plugins
Add new React components to the frontend.

### 3. Sidecar Plugins
Run external processes alongside the main application.

## Creating a Command Plugin

### Step 1: Create Plugin Structure

```
plugins/my-plugin/
├── Cargo.toml
├── src/
│   └── lib.rs
└── README.md
```

### Step 2: Define Plugin Trait

```rust
// src/lib.rs
use serde::{Deserialize, Serialize};
use tauri::{command, Runtime};

#[derive(Debug, Serialize, Deserialize)]
pub struct MyPluginConfig {
    pub enabled: bool,
    pub api_key: Option<String>,
}

#[command]
pub async fn my_plugin_command(config: MyPluginConfig) -> Result<String, String> {
    if !config.enabled {
        return Err("Plugin is not enabled".to_string());
    }
    
    Ok("Plugin executed successfully".to_string())
}

pub fn init<R: Runtime>() -> tauri::plugin::TauriPlugin<R> {
    tauri::plugin::Builder::new("my-plugin")
        .invoke_handler(tauri::generate_handler![my_plugin_command])
        .build()
}
```

### Step 3: Register Plugin

In `src-tauri/src/main.rs`:

```rust
use my_plugin::init as my_plugin_init;

fn main() {
    tauri::Builder::default()
        .plugin(my_plugin_init())
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
```

### Step 4: Use from Frontend

```typescript
import { invoke } from '@tauri-apps/api/core';

const result = await invoke('plugin:my-plugin|my_plugin_command', {
  config: {
    enabled: true,
    apiKey: 'your-key'
  }
});
```

## Creating a UI Plugin

### Step 1: Create React Component

```typescript
// plugins/my-ui-plugin/src/MyPlugin.tsx
import { useState } from 'react';
import { invoke } from '@tauri-apps/api/core';

export function MyPlugin() {
  const [result, setResult] = useState('');

  const handleAction = async () => {
    const res = await invoke('plugin:my-plugin|my_plugin_command', {
      config: { enabled: true }
    });
    setResult(res);
  };

  return (
    <div className="my-plugin">
      <h2>My Plugin</h2>
      <button onClick={handleAction}>Execute</button>
      <p>{result}</p>
    </div>
  );
}
```

### Step 2: Export Plugin

```typescript
// plugins/my-ui-plugin/src/index.ts
export { MyPlugin } from './MyPlugin';
```

### Step 3: Use in Main App

```typescript
// src/App.tsx
import { MyPlugin } from 'my-ui-plugin';

function App() {
  return (
    <div>
      <MyPlugin />
    </div>
  );
}
```

## Sidecar Plugins

Sidecar plugins run external binaries alongside the Tauri application.

### Step 1: Configure Sidecar

In `tauri.conf.json`:

```json
{
  "bundle": {
    "resources": {
      "sidecars": [
        "binaries/my-sidecar-x86_64-unknown-linux-gnu",
        "binaries/my-sidecar-x86_64-apple-darwin",
        "binaries/my-sidecar-x86_64-pc-windows-msvc.exe"
      ]
    }
  }
}
```

### Step 2: Start Sidecar from Rust

```rust
use tauri::api::process::{Command, CommandEvent};

#[command]
async fn start_my_sidecar() -> Result<(), String> {
    let (mut rx, _child) = Command::new_sidecar("my-sidecar")
        .map_err(|e| e.to_string())?
        .spawn()
        .map_err(|e| e.to_string())?;

    tauri::async_runtime::spawn(async move {
        while let Some(event) = rx.recv().await {
            match event {
                CommandEvent::Stdout(line) => {
                    tracing::info!("Sidecar stdout: {}", line);
                }
                CommandEvent::Stderr(line) => {
                    tracing::error!("Sidecar stderr: {}", line);
                }
                CommandEvent::Terminated(_) => {
                    tracing::info!("Sidecar terminated");
                }
                _ => {}
            }
        }
    });

    Ok(())
}
```

## Security Guidelines

### 1. Capability-Based Permissions

Define what your plugin can access:

```rust
#[derive(Debug, Serialize, Deserialize)]
pub struct PluginCapabilities {
    pub can_read_files: bool,
    pub can_write_files: bool,
    pub can_network: bool,
    pub can_execute: bool,
}
```

### 2. Input Validation

Always validate inputs:

```rust
#[command]
pub fn safe_command(input: String) -> Result<String, String> {
    // Validate input
    if input.is_empty() {
        return Err("Input cannot be empty".to_string());
    }
    
    if input.len() > 1000 {
        return Err("Input too long".to_string());
    }
    
    // Process safely
    Ok(format!("Processed: {}", input))
}
```

### 3. Error Handling

Never expose sensitive information in errors:

```rust
#[command]
pub fn secure_command() -> Result<String, String> {
    match risky_operation() {
        Ok(result) => Ok(result),
        Err(_) => Err("Operation failed".to_string()), // Don't leak details
    }
}
```

## Best Practices

### 1. Documentation

Document all public APIs:

```rust
/// Performs a complex operation
///
/// # Arguments
///
/// * `input` - The input data to process
/// * `config` - Configuration options
///
/// # Returns
///
/// The processed result as a String
///
/// # Errors
///
/// Returns an error if the operation fails
#[command]
pub fn my_command(input: String, config: Config) -> Result<String, String> {
    // Implementation
}
```

### 2. Testing

Write comprehensive tests:

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_my_command() {
        let result = my_command("test".to_string(), Config::default());
        assert!(result.is_ok());
    }
}
```

### 3. Async Operations

Use async for long-running operations:

```rust
#[command]
pub async fn long_operation() -> Result<String, String> {
    // Use tokio spawn for CPU-intensive work
    let result = tokio::task::spawn_blocking(|| {
        // Heavy computation
        expensive_operation()
    })
    .await
    .map_err(|e| e.to_string())?;
    
    Ok(result)
}
```

### 4. State Management

Use Tauri's state management for shared data:

```rust
pub struct PluginState {
    pub counter: Arc<RwLock<u32>>,
}

#[command]
pub async fn increment_counter(
    state: tauri::State<'_, PluginState>
) -> Result<u32, String> {
    let mut counter = state.counter.write().await;
    *counter += 1;
    Ok(*counter)
}
```

## Publishing Plugins

### 1. Package Structure

```
my-plugin/
├── Cargo.toml
├── package.json (for UI components)
├── README.md
├── LICENSE
├── src/
├── examples/
└── tests/
```

### 2. Versioning

Follow semantic versioning (semver):
- MAJOR: Breaking changes
- MINOR: New features (backward compatible)
- PATCH: Bug fixes

### 3. Documentation

Include:
- Installation instructions
- Configuration options
- Usage examples
- API reference
- Changelog

## Example Plugins

See the `plugins/` directory for example implementations:

- `example-integration/` - Integration plugin template
- `example-sidecar/` - Sidecar plugin template

## Future Plugin APIs

Planned for future releases:

- Plugin marketplace integration
- Automatic updates
- Dependency management
- Sandboxed execution environments
- Plugin analytics
