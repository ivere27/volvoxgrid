# Contributing to VolvoxGrid

Thank you for your interest in contributing to VolvoxGrid! This document provides guidelines and information for contributors.

## Contributor License Agreement (CLA)

By submitting a pull request or patch to this repository, you agree to the following terms:

1. **License Grant**: You license your contribution under the Apache License 2.0, consistent with the project's LICENSE file.

2. **Original Work**: You represent that your contribution is your original work, or you have the necessary rights to submit it under these terms.

3. **No Warranty**: You provide your contribution "as is" without any warranty.

## How to Contribute

### Reporting Issues

- Check existing issues before creating a new one.
- Include relevant details: OS, Rust version, Flutter version, steps to reproduce.
- Provide error messages, logs, and stack traces if applicable.

### Submitting Code

1. Fork the repository.
2. Create a feature branch (`git checkout -b feature/your-feature`).
3. Make your changes.
4. Ensure tests pass (`make test`).
5. Commit with clear messages.
6. Push to your fork.
7. Open a pull request.

### Code Style

- **Rust**: Follow standard Rust conventions. Run `cargo fmt` and `cargo clippy` before submitting.
- **Flutter/Dart**: Follow standard Dart conventions. Run `dart format .` in the Flutter directories.
- **Proto**: Follow Google's protobuf style guide.

### Commit Messages

Use clear, descriptive commit messages:

```
component: short description

Longer explanation if needed. Explain what and why,
not how (the code shows how).
```

Examples:
- `engine: optimize cell rendering performance`
- `flutter: add support for custom cell editors`
- `web: fix wasm memory leak in grid disposal`
- `plugin: update ffi bindings for new proto fields`

### Pull Request Guidelines

- Keep PRs focused on a single change.
- Update documentation if needed.
- Add tests for new functionality.
- Ensure CI passes before requesting review.

## Development Setup

### Prerequisites

- **Rust**: Latest stable version (via `rustup`).
- **Flutter**: Latest stable version (if working on Flutter components).
- **Protobuf Compiler**: `protoc` (if modifying `.proto` files).
- **Android SDK/NDK**: For Android/Flutter builds.
- **Node.js/npm**: For Web builds.

### Build & Run

```bash
# Clone the repository
git clone https://github.com/ivere27/volvoxgrid.git
cd volvoxgrid

# Build Engine & Plugin (Debug)
make build

# Run Smoke Test
make run

# Run Unit Tests
make test

# Build WASM & Start Web Dev Server
make web

# Run Flutter Example (Android)
# Requires connected Android device or emulator
make flutter-run

# Run GTK4 Plugin-Host Visual Test (Linux)
make gtk-test
```

## Project Structure

```
volvoxgrid/
├── engine/        # Core grid logic (Rust)
├── plugin/        # Synurang FFI plugin wrapper (Rust)
├── flutter/       # Flutter plugin & example app
├── web/           # WebAssembly crate & JS bindings
├── proto/         # Protobuf definitions
├── codegen/       # Generated FFI bindings
├── android/       # Android-specific build configurations
├── adapters/
│   └── vsflexgrid/ # ActiveX control (Windows)
├── gtk-test/      # GTK4 plugin-host visual test harness
├── smoke-test/    # CLI smoke test
└── scripts/       # Utility scripts
```

## Testing

- **Unit Tests**: Run `make test` to run Rust unit tests in the `engine` crate.
- **Smoke Test**: Run `make run` to verify the plugin works with the Rust host.
- **Integration**:
    - **Flutter**: Run the example app via `make flutter-run`.
    - **Web**: Run the web demo via `make web`.
    - **GTK**: Run the GTK plugin-host harness via `make gtk-test` to visually verify the native FFI path on Linux.

## Questions?

- Open a GitHub Issue for bugs or feature requests.
- Open a GitHub Discussion for general questions.

## License

By contributing, you agree that your contributions will be licensed under the Apache License 2.0.
