# Contributing to TrayMe Desktop OS

Thank you for your interest in contributing to TrayMe Desktop OS! This document provides guidelines for contributing to the project.

## Code of Conduct

Be respectful, inclusive, and professional in all interactions.

## Getting Started

### Prerequisites

- Rust 1.70+
- Node.js 18+
- Git

### Setup Development Environment

```bash
# Clone the repository
git clone https://github.com/prateekro/TrayMe.git
cd TrayMe

# Install dependencies
npm install

# Run in development mode
npm run tauri:dev
```

## Development Workflow

### 1. Create a Feature Branch

```bash
git checkout -b feature/your-feature-name
```

### 2. Make Changes

- Follow the existing code style
- Write tests for new features
- Update documentation as needed

### 3. Test Your Changes

```bash
# Run Rust tests
cd src-tauri && cargo test

# Run TypeScript checks
npm run build

# Manual testing
npm run tauri:dev
```

### 4. Commit Your Changes

```bash
git add .
git commit -m "feat: add new feature"
```

Use conventional commit messages:
- `feat:` - New features
- `fix:` - Bug fixes
- `docs:` - Documentation changes
- `style:` - Code style changes
- `refactor:` - Code refactoring
- `test:` - Test changes
- `chore:` - Build/tooling changes

### 5. Push and Create Pull Request

```bash
git push origin feature/your-feature-name
```

Then create a pull request on GitHub.

## Code Style

### Rust

Follow Rust standard style:

```bash
cargo fmt
cargo clippy
```

### TypeScript/React

```bash
npm run lint
npm run format
```

## Testing

### Unit Tests (Rust)

```rust
#[cfg(test)]
mod tests {
    #[test]
    fn test_something() {
        assert_eq!(2 + 2, 4);
    }
}
```

### Integration Tests

See `tests/` directory for examples.

## Documentation

- Update README.md for user-facing changes
- Update docs/ for architectural changes
- Add inline comments for complex logic
- Update API.md for new commands

## Pull Request Process

1. Ensure all tests pass
2. Update documentation
3. Add yourself to CONTRIBUTORS.md
4. Request review from maintainers

## Review Process

- All PRs require at least one approval
- CI checks must pass
- Documentation must be updated
- Tests must be included

## Areas for Contribution

### High Priority

- [ ] AI integration (llama.cpp/Ollama)
- [ ] E2EE synchronization
- [ ] Integration connectors
- [ ] Voice control
- [ ] Plugin system

### Medium Priority

- [ ] Additional window management features
- [ ] Advanced RAG capabilities
- [ ] Performance optimizations
- [ ] Cross-platform testing

### Good First Issues

- Documentation improvements
- Bug fixes
- UI/UX enhancements
- Test coverage

## Questions?

- Open an issue on GitHub
- Check existing documentation
- Ask in pull request comments

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

## Thank You!

Your contributions help make TrayMe Desktop OS better for everyone!
