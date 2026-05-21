# Contributing to VolvoxGrid

Thanks for being here. Whether you're filing a bug, fixing one, or adding a feature, this doc walks you through what to expect.

For repo architecture, prerequisites, and the daily build commands, see [ARCHITECTURE.md](ARCHITECTURE.md) — this file stays focused on policy and review.

## Contributor License Agreement (CLA)

By submitting a pull request or patch to this repository, you agree to the following terms:

1. **License Grant**: You license your contribution under the Apache License 2.0, consistent with the project's LICENSE file.

2. **Original Work**: You represent that your contribution is your original work, or you have the necessary rights to submit it under these terms.

3. **No Warranty**: You provide your contribution "as is" without any warranty.

## How to report an issue

Before you open one, check the existing issue list — there's a good chance the bug or feature you're thinking about is already tracked.

When you do file, give us enough to reproduce. The shape we expect is:

- OS and version, Rust version, and the relevant SDK version (Flutter, JDK, .NET, Node, Go) for the path you hit the bug on
- Exact steps to reproduce
- The error message, log, and stack trace if there is one
- What you expected to happen, and what actually happened

For feature requests, lead with the use case — what you're trying to build and what's blocking you. That makes it much easier to design something that fits.

## How to submit code

1. Fork the repository.
2. Branch off `main` (`git checkout -b feature/your-feature`).
3. Make your change. Keep it scoped — one logical change per PR.
4. Run the relevant tests (`make test` at minimum; see [Testing](#testing) below).
5. Commit with a clear message (see the [Commit messages](#commit-messages) section).
6. Push to your fork and open a PR against `main`.
7. Make sure CI is green before requesting review.

If your change touches the public API, update the matching docs in the same PR. If it adds behavior, add a test.

## Code style

Each language follows its native conventions — don't fight the tooling.

- **Rust** — run `cargo fmt` and `cargo clippy` before submitting. Treat clippy warnings as errors unless you have a reason not to.
- **Flutter/Dart** — run `dart format .` in the Flutter directories.
- **Proto** — follow Google's protobuf style guide. Field numbers are forever, so think before you assign them.
- **Java/Kotlin** — match the surrounding file. Gradle wrappers are checked in.
- **C# / .NET** — `dotnet format` before pushing.
- **Go** — `gofmt`, `go vet`, and the usual.
- **TypeScript** — the `web/js/` package has its own lint/format setup; run it before pushing.

## Commit messages

The format is `component: short description`, with an optional body explaining the why (not the how — the code shows how).

```
component: short description

Longer explanation if needed. Explain what and why,
not how (the code shows how).
```

Real examples from the history:

- `engine: optimize cell rendering performance`
- `flutter: add support for custom cell editors`
- `web: fix wasm memory leak in grid disposal`
- `runtime: update ffi bindings for new proto fields`

Keep the subject under 72 characters. If you can't summarize the change in one line, the PR is probably doing too much.

## Local development quick links

The full prerequisites, mental model, and `make` targets live in [ARCHITECTURE.md](ARCHITECTURE.md). The short version:

```bash
# clone
git clone https://github.com/ivere27/volvoxgrid.git
cd volvoxgrid

# build the engine and native library
make build

# smoke-test the native library
make run

# run unit tests
make test

# pick the host you're working on
make web
make flutter-run
make java-desktop-run
make rust-gtk-run
make go-tui-run
make dotnet-tui-run
make java-tui-run
```

If you're changing `.proto` files, run `make codegen` before rebuilding anything.

## Project layout

```
volvoxgrid/
├── engine/           # Core grid logic (Rust)
├── runtime/          # Synurang FFI runtime wrapper and WASM targets (Rust)
├── proto/            # Protobuf definitions
├── codegen/          # Generated FFI bindings
├── flutter/          # Flutter runtime & example app
├── android/          # Android wrapper & example
├── java/             # Java desktop wrapper & TUI example
│   ├── common/
│   └── desktop/
├── dotnet/           # .NET wrapper (WinForms, client, TUI)
│   ├── src/
│   └── examples/
├── go/               # Go TUI host & client API
│   ├── pkg/
│   └── examples/
├── web/              # Browser package and demo
│   ├── js/           # JS/TS npm package and package-local WASM output
│   └── example/      # Vite browser demo and release-demo source
├── adapters/         # Compatibility layers
│   ├── aggrid/       # AG Grid API adapter (npm)
│   ├── bubbletea/    # Bubble Tea component for Go TUIs
│   ├── report/       # Report adapter
│   ├── sfdatagrid/   # SfDataGrid comparison tests
│   ├── sheet/        # Sheet API adapter (npm)
│   ├── vsflexgrid/   # ActiveX control (Windows)
│   └── xtragrid/     # XtraGrid adapter
├── rust/gtk/         # GTK4 library-host visual test harness (Rust)
├── cpp/              # Header-only C++ binding around the FFI
├── smoke-test/       # CLI smoke test
├── docker/           # Reproducible packaging
├── scripts/          # Build and utility scripts
├── dist/             # Packaged distribution artifacts
├── public/           # Static assets
└── testdata/         # Test fixture data
```

## Testing

Use the smallest loop that proves your change works.

- **Unit tests** — `make test` runs the Rust unit tests in the workspace.
- **Smoke test** — `make run` verifies the native library works end-to-end from a Rust host.
- **GTK harness** — `make rust-gtk-run` visually verifies the native FFI path on Linux.
- **Flutter** — `make flutter-run` against a connected device or emulator.
- **Web** — `make web` boots the Vite demo.
- **Terminal hosts** — `make go-tui-run`, `make dotnet-tui-run`, `make java-tui-run`.

Adapter tests (including visual comparisons against the original third-party APIs) live alongside each adapter under `adapters/`.

## Questions

- Open a GitHub Issue for bugs or feature requests.
- Open a GitHub Discussion for general questions or design conversations.

## License

By contributing, you agree that your contributions will be licensed under the Apache License 2.0.
