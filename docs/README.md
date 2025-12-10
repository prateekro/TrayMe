# TrayMe Desktop OS - Architecture Documentation

## Overview

TrayMe Desktop OS is a comprehensive cross-platform Desktop Operating Layer built with Tauri 2.0, combining a Rust backend with a React/TypeScript frontend. This architecture provides a foundation for building advanced desktop productivity tools with privacy-first AI integration.

## Technology Stack

### Backend (Rust)
- **Tauri 2.0**: Cross-platform application framework
- **SQLx**: Type-safe SQL database access (SQLite)
- **Tokio**: Async runtime
- **Serde**: Serialization/deserialization
- **AES-GCM**: Encryption
- **Tracing**: Structured logging

### Frontend (TypeScript/React)
- **React 18**: UI framework
- **TypeScript**: Type-safe JavaScript
- **Vite**: Build tool and dev server
- **CSS3**: Modern styling

## Core Features Implemented

### ✅ Phase 1: Foundation
- Tauri 2.0 project structure
- Rust backend with modular architecture
- React/TypeScript frontend
- SQLite database integration
- Cross-platform compatibility

### ✅ Phase 2: Window Management
- Window tracking and tray system
- Add/remove windows from tray
- Window metadata storage
- Command palette for quick access

### ✅ Phase 3: Storage & Persistence
- SQLite database with schema migrations
- Workspace save/load functionality
- Settings persistence
- Document storage for RAG (prepared)

### ✅ Phase 4: Security
- AES-256-GCM encryption/decryption
- Secure credential handling
- Type-safe command interface

### 🔜 Future Phases
- AI integration (LLM sidecar, RAG, vision)
- E2EE synchronization
- Integration fabric (Linear, Notion, GitHub, etc.)
- Voice control and accessibility
- Plugin ecosystem

## Component Architecture

See [ARCHITECTURE.md](./ARCHITECTURE.md) for detailed architecture documentation.

## Getting Started

### Prerequisites
- Rust 1.70+
- Node.js 18+
- npm/yarn/pnpm

### Installation

```bash
# Install dependencies
npm install

# Run development server
npm run tauri:dev

# Build for production
npm run tauri:build
```

## Project Structure

```
trayme-desktop-os/
├── src-tauri/                  # Rust backend
│   ├── src/
│   │   ├── main.rs            # Application entry
│   │   ├── state.rs           # Global state
│   │   ├── commands/          # Tauri RPC commands
│   │   ├── managers/          # Business logic
│   │   ├── models/            # Data structures
│   │   └── utils/             # Helper functions
│   ├── Cargo.toml
│   └── tauri.conf.json
├── src/                        # React frontend
│   ├── components/            # UI components
│   ├── styles/                # CSS files
│   ├── App.tsx                # Main app
│   └── main.tsx               # Entry point
├── docs/                       # Documentation
├── tests/                      # Test suite
└── package.json
```

## License

MIT
