# Tests

This directory contains integration and end-to-end tests for TrayMe Desktop OS.

## Test Structure

- `integration/` - Integration tests for backend-frontend communication
- `e2e/` - End-to-end tests for complete user workflows

## Running Tests

### Unit Tests (Rust)
```bash
cd src-tauri
cargo test
```

### Integration Tests
```bash
npm run test
```

### E2E Tests  
```bash
npm run test:e2e
```

## Writing Tests

### Unit Tests

Create tests in the same file as the code:

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_something() {
        // Test implementation
    }
}
```

### Integration Tests

Create test files in `src-tauri/tests/`:

```rust
// tests/my_integration_test.rs
use trayme_desktop_os::*;

#[test]
fn test_integration() {
    // Test implementation
}
```

## Test Coverage

Run with coverage reporting:

```bash
cargo install cargo-tarpaulin
cargo tarpaulin --out Html
```

## CI Integration

Tests run automatically on:
- Every push to main
- Every pull request
- Nightly builds

See `.github/workflows/test.yml` for CI configuration.
