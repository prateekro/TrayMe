# TrayMe Desktop OS

> **Comprehensive Cross-Platform Desktop Operating Layer**

A privacy-first, AI-powered desktop productivity platform built with Tauri (Rust + React/TypeScript). Transform how you interact with your desktop through intelligent window management, local AI assistance, and seamless integrations.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Tauri](https://img.shields.io/badge/Tauri-2.0-blue)](https://tauri.app)
[![Rust](https://img.shields.io/badge/Rust-1.70+-orange)](https://www.rust-lang.org)
[![React](https://img.shields.io/badge/React-18-blue)](https://reactjs.org)

## 🎯 Vision

TrayMe Desktop OS evolves from a simple macOS tray application into a **comprehensive Desktop Operating Layer** that:

- 🪟 Manages windows intelligently with context-aware grouping
- 🤖 Integrates local AI for privacy-first assistance
- 🔐 Ensures end-to-end encryption for all data
- 🌐 Connects seamlessly with productivity tools
- 🎨 Empowers creators with unified publishing
- ♿ Provides accessibility-first features

## ✨ Features

### Current Implementation (v2.0)

#### ✅ Window Management
- **Minimize to Tray**: Keep windows accessible without cluttering your taskbar
- **Command Palette**: Universal search with `Cmd/Ctrl+K`
- **Window Tracking**: Persistent window state management
- **Workspace Persistence**: Save and restore window collections

#### ✅ Foundation
- **Cross-Platform**: Windows, macOS, Linux support via Tauri
- **Local-First Storage**: SQLite database for privacy
- **Secure Communication**: Type-safe Rust ↔ TypeScript bridge
- **Modern UI**: React 18 with responsive design

#### ✅ Security
- **AES-256-GCM Encryption**: Secure data at rest
- **Capability-Based Security**: Sandboxed command execution
- **No Telemetry**: 100% local, zero tracking

### Planned Features

#### 🔜 AI Core
- **Local LLM Sidecar**: llama.cpp/Ollama integration
- **Screen Intelligence**: Capture and analyze with vision models
- **RAG System**: Private document indexing and search
- **Computer Use API**: Autonomous task execution

#### 🔜 Integration Fabric
- Linear, Jira, GitHub, Notion
- Slack, Discord, Teams
- OAuth-based secure connections

#### 🔜 Creator Engine
- Multi-platform social media publishing
- AI content repurposing
- Privacy-first analytics

#### 🔜 Advanced Features
- Voice control (Whisper.cpp)
- Ghost windows (transparent overlay)
- Plugin marketplace
- E2EE multi-device sync

## 🚀 Quick Start

### Prerequisites

- **Rust** 1.70+ ([Install](https://rustup.rs/))
- **Node.js** 18+ ([Install](https://nodejs.org/))
- **npm** or **yarn**

### Installation

```bash
# Clone the repository
git clone https://github.com/prateekro/TrayMe.git
cd TrayMe

# Install dependencies
npm install

# Run in development mode
npm run tauri:dev
```

### Build for Production

```bash
# Build optimized app
npm run tauri:build

# Output: src-tauri/target/release/bundle/
```

## 📖 Documentation

- **[Architecture](docs/ARCHITECTURE.md)**: System design and components
- **[API Reference](docs/API.md)**: Command interface documentation
- **[Plugin Guide](docs/PLUGIN_GUIDE.md)**: Building extensions
- **[Deployment](docs/DEPLOYMENT.md)**: Production setup

## 🏗️ Project Structure

```
TrayMe/
├── src-tauri/              # Rust backend
│   ├── src/
│   │   ├── commands/      # Tauri RPC commands
│   │   ├── managers/      # Business logic
│   │   ├── models/        # Data structures
│   │   └── utils/         # Helpers
│   └── Cargo.toml
├── src/                    # React frontend
│   ├── components/        # UI components
│   ├── hooks/             # React hooks
│   ├── lib/               # Utilities
│   └── styles/            # CSS
├── docs/                   # Documentation
├── tests/                  # Test suite
└── package.json
```

## 🛠️ Development

### Available Scripts

```bash
npm run dev              # Start Vite dev server
npm run tauri:dev        # Run Tauri app in dev mode
npm run tauri:build      # Build production app
npm run test             # Run tests
npm run lint             # Lint code
```

### Technology Stack

**Backend (Rust)**
- Tauri 2.0 - Application framework
- SQLx - Database access
- Tokio - Async runtime
- Serde - Serialization
- AES-GCM - Encryption

**Frontend (TypeScript/React)**
- React 18 - UI framework
- TypeScript - Type safety
- Vite - Build tool
- CSS3 - Styling

## 🔒 Security & Privacy

### Privacy-First Design
- ✅ **Local-First**: All data processed on-device
- ✅ **Zero Telemetry**: No tracking or analytics
- ✅ **E2EE Ready**: End-to-end encryption architecture
- ✅ **Open Source**: Transparent and auditable

### Security Features
- AES-256-GCM encryption
- OS keychain integration (planned)
- Sandboxed plugin execution (planned)
- Capability-based access control

## 🗺️ Roadmap

### v2.0 (Current) - Foundation ✅
- [x] Tauri 2.0 migration
- [x] Window management system
- [x] SQLite storage
- [x] Command palette
- [x] Basic encryption

### v2.1 - AI Integration 🔜
- [ ] Local LLM sidecar (llama.cpp)
- [ ] Screenshot capture & analysis
- [ ] RAG with pgvector
- [ ] Voice control (Whisper.cpp)

### v2.2 - Integrations 🔜
- [ ] GitHub API integration
- [ ] Linear/Jira connectors
- [ ] Notion quick-capture
- [ ] Slack/Discord/Teams

### v2.3 - Creator Tools 🔜
- [ ] Social media publishing
- [ ] Content repurposing AI
- [ ] Analytics dashboard
- [ ] BYOK support

### v3.0 - Enterprise 🔮
- [ ] Team workspaces
- [ ] Plugin marketplace
- [ ] Cloud sync (E2EE)
- [ ] Mobile companion app

## 🤝 Contributing

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Inspired by [Unclutter](https://unclutterapp.com/)
- Built with [Tauri](https://tauri.app)
- Powered by [Rust](https://www.rust-lang.org) and [React](https://reactjs.org)

## 📧 Contact

- **Author**: TrayMe Team
- **Repository**: [github.com/prateekro/TrayMe](https://github.com/prateekro/TrayMe)
- **Issues**: [GitHub Issues](https://github.com/prateekro/TrayMe/issues)

---

**Built with ❤️ using Tauri, Rust, and React**
