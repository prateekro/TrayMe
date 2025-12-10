# Deployment Guide

## Overview

This guide covers deploying TrayMe Desktop OS to production across Windows, macOS, and Linux.

## Prerequisites

- Rust 1.70+
- Node.js 18+
- Platform-specific build tools

### Platform-Specific Requirements

#### macOS
```bash
xcode-select --install
```

#### Windows
```powershell
# Install Visual Studio Build Tools
winget install Microsoft.VisualStudio.2022.BuildTools
```

#### Linux (Ubuntu/Debian)
```bash
sudo apt update
sudo apt install libwebkit2gtk-4.1-dev \
    build-essential \
    curl \
    wget \
    file \
    libssl-dev \
    libgtk-3-dev \
    libayatana-appindicator3-dev \
    librsvg2-dev \
    patchelf
```

## Building for Production

### 1. Install Dependencies

```bash
npm install
```

### 2. Build the Application

```bash
npm run tauri:build
```

### 3. Output Locations

#### macOS
- **DMG**: `src-tauri/target/release/bundle/dmg/`
- **App Bundle**: `src-tauri/target/release/bundle/macos/`

#### Windows
- **MSI**: `src-tauri/target/release/bundle/msi/`
- **NSIS**: `src-tauri/target/release/bundle/nsis/`

#### Linux
- **Deb**: `src-tauri/target/release/bundle/deb/`
- **AppImage**: `src-tauri/target/release/bundle/appimage/`

## Code Signing

### macOS

1. **Get a Developer Certificate**
   - Join Apple Developer Program
   - Create a Developer ID Application certificate

2. **Configure Signing**

In `src-tauri/tauri.conf.json`:

```json
{
  "bundle": {
    "macOS": {
      "signingIdentity": "Developer ID Application: Your Name (TEAM_ID)",
      "entitlements": "Info.plist"
    }
  }
}
```

3. **Sign the App**

```bash
codesign --deep --force --verify --verbose \
  --sign "Developer ID Application: Your Name (TEAM_ID)" \
  "src-tauri/target/release/bundle/macos/TrayMe Desktop OS.app"
```

4. **Notarize**

```bash
xcrun notarytool submit \
  "src-tauri/target/release/bundle/dmg/TrayMe Desktop OS_2.0.0_aarch64.dmg" \
  --apple-id "your-email@example.com" \
  --team-id "TEAM_ID" \
  --password "app-specific-password" \
  --wait
```

### Windows

1. **Get a Code Signing Certificate**
   - Purchase from a trusted CA (DigiCert, Sectigo, etc.)

2. **Configure Signing**

In `src-tauri/tauri.conf.json`:

```json
{
  "bundle": {
    "windows": {
      "certificateThumbprint": "YOUR_CERT_THUMBPRINT",
      "digestAlgorithm": "sha256",
      "timestampUrl": "http://timestamp.digicert.com"
    }
  }
}
```

3. **Sign the Installer**

```powershell
signtool sign /tr http://timestamp.digicert.com /td sha256 `
  /fd sha256 /f cert.pfx /p password `
  "src-tauri/target/release/bundle/msi/TrayMe Desktop OS_2.0.0_x64_en-US.msi"
```

## Auto-Updates

### 1. Configure Update Server

In `src-tauri/tauri.conf.json`:

```json
{
  "app": {
    "updater": {
      "active": true,
      "endpoints": [
        "https://releases.trayme.app/{{target}}/{{current_version}}"
      ],
      "dialog": true,
      "pubkey": "YOUR_PUBLIC_KEY"
    }
  }
}
```

### 2. Generate Update Keys

```bash
npm run tauri signer generate -- -w ~/.tauri/trayme.key
```

This generates:
- Private key: `~/.tauri/trayme.key`
- Public key: Printed to console (add to config)

### 3. Sign Updates

```bash
npm run tauri signer sign -- \
  "src-tauri/target/release/bundle/macos/TrayMe Desktop OS.app.tar.gz"
```

### 4. Create Update Manifest

```json
{
  "version": "2.0.0",
  "date": "2024-12-10T00:00:00Z",
  "platforms": {
    "darwin-aarch64": {
      "url": "https://releases.trayme.app/macos/v2.0.0/trayme.app.tar.gz",
      "signature": "SIGNATURE_HERE"
    },
    "darwin-x86_64": {
      "url": "https://releases.trayme.app/macos/v2.0.0/trayme-x86_64.app.tar.gz",
      "signature": "SIGNATURE_HERE"
    },
    "windows-x86_64": {
      "url": "https://releases.trayme.app/windows/v2.0.0/trayme.msi",
      "signature": "SIGNATURE_HERE"
    },
    "linux-x86_64": {
      "url": "https://releases.trayme.app/linux/v2.0.0/trayme.AppImage",
      "signature": "SIGNATURE_HERE"
    }
  }
}
```

## Continuous Integration

### GitHub Actions

Create `.github/workflows/build.yml`:

```yaml
name: Build and Release

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    strategy:
      matrix:
        platform: [macos-latest, ubuntu-latest, windows-latest]
    runs-on: ${{ matrix.platform }}

    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node
        uses: actions/setup-node@v3
        with:
          node-version: 18
      
      - name: Setup Rust
        uses: actions-rs/toolchain@v1
        with:
          toolchain: stable
      
      - name: Install dependencies (Ubuntu)
        if: matrix.platform == 'ubuntu-latest'
        run: |
          sudo apt-get update
          sudo apt-get install -y libwebkit2gtk-4.1-dev \
            libappindicator3-dev librsvg2-dev patchelf
      
      - name: Install Node dependencies
        run: npm install
      
      - name: Build app
        run: npm run tauri:build
      
      - name: Upload artifacts
        uses: actions/upload-artifact@v3
        with:
          name: ${{ matrix.platform }}
          path: src-tauri/target/release/bundle/
```

## Distribution

### macOS

#### App Store
1. Create App Store Connect listing
2. Configure App Sandbox entitlements
3. Build with `--target universal-apple-darwin`
4. Upload with Transporter

#### Direct Download
1. Sign and notarize DMG
2. Host on CDN
3. Provide download link

### Windows

#### Microsoft Store
1. Create Partner Center listing
2. Convert to MSIX package
3. Submit for certification

#### Direct Download
1. Sign MSI installer
2. Host on CDN
3. Provide download link

### Linux

#### Package Repositories

**Debian/Ubuntu (APT)**
```bash
# Create repository structure
mkdir -p repo/pool/main
cp trayme_2.0.0_amd64.deb repo/pool/main/

# Generate Packages file
cd repo
dpkg-scanpackages pool /dev/null | gzip -9c > dists/stable/main/binary-amd64/Packages.gz
```

**Arch (AUR)**
Create PKGBUILD and submit to AUR

**Flatpak**
```bash
flatpak-builder --repo=repo build-dir com.trayme.DesktopOS.yml
flatpak build-bundle repo trayme.flatpak com.trayme.DesktopOS
```

## Monitoring & Analytics

### Error Reporting

Integrate Sentry:

```rust
// src-tauri/src/main.rs
use sentry::ClientOptions;

fn main() {
    let _guard = sentry::init((
        "https://your-dsn@sentry.io/project-id",
        ClientOptions {
            release: sentry::release_name!(),
            ..Default::default()
        },
    ));
    
    // Rest of main
}
```

### Usage Analytics

Use privacy-respecting analytics (self-hosted):

```rust
#[command]
async fn track_event(event: String, properties: HashMap<String, String>) {
    // Send to self-hosted analytics server
}
```

## Performance Optimization

### 1. Build Optimization

In `src-tauri/Cargo.toml`:

```toml
[profile.release]
opt-level = "z"     # Optimize for size
lto = true          # Link-time optimization
codegen-units = 1   # Better optimization
strip = true        # Remove debug symbols
panic = "abort"     # Smaller binary
```

### 2. Frontend Optimization

```bash
# Enable tree-shaking
npm run build -- --minify esbuild
```

### 3. Asset Optimization

- Compress images
- Minify icons
- Use WebP format
- Lazy load resources

## Security Checklist

- [ ] Code signed on all platforms
- [ ] HTTPS for all network requests
- [ ] Auto-updates configured
- [ ] Error reporting configured
- [ ] Secrets stored securely (not in code)
- [ ] Dependencies audited
- [ ] CSP configured
- [ ] Input validation on all commands

## Rollback Strategy

1. **Keep Previous Versions**
   ```bash
   mv releases/v2.0.0 releases/v2.0.0-backup
   ```

2. **Update Manifest to Previous Version**
   ```json
   {
     "version": "1.9.0",
     "platforms": { /* previous urls */ }
   }
   ```

3. **Notify Users**
   - Send in-app notification
   - Post on status page
   - Update download links

## Support

- Documentation: https://docs.trayme.app
- Issues: https://github.com/prateekro/TrayMe/issues
- Email: support@trayme.app
