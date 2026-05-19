# Publishing the Go modules

This repo ships two independent Go modules: the core wrapper and the Bubble Tea adapter. They release on separate cadences so a core bump doesn't force adapter consumers to upgrade, and a new adapter version doesn't drag the core along. Because both modules sit in subdirectories of the same repo, you'll tag them with a directory-prefixed version — the Go proxy looks for `<subdir>/<semver>` tags whenever the module path includes a subdirectory, and plain `vX.Y.Z` tags aren't picked up.

This guide walks you through both release flows and how to verify them.

## Module map

Here's the layout you're working with:

| Path | Module | Tag prefix |
|---|---|---|
| `/go/` | `github.com/ivere27/volvoxgrid/go` (core wrapper) | `go/vX.Y.Z` |
| `/adapters/bubbletea/` | `github.com/ivere27/volvoxgrid/adapters/bubbletea` | `adapters/bubbletea/vX.Y.Z` |

The core module is intentionally minimal — only `synurang`, `grpc`, and `protobuf`. Adapters that pull in third-party UI frameworks live in their own modules so consumers of the core wrapper don't inherit those dependencies.

## Releasing the core

Cut a core release when you've changed anything under `/go/` that consumers will see. Tag and push:

```sh
git tag go/v0.8.9
git push origin go/v0.8.9
```

The first time someone runs `go get github.com/ivere27/volvoxgrid/go@v0.8.9`, the proxy pulls the tag, locates `/go/go.mod`, and caches the module. From that point on, the version is immutable on the proxy — so double-check the tag points at the commit you actually want to ship before pushing.

A typical consumer's imports look like this once the tag is live:

```go
import (
    "github.com/ivere27/volvoxgrid/go/pkg/volvoxgrid"
    pb "github.com/ivere27/volvoxgrid/go/api/v1"
)
```

## Releasing the adapter

The Bubble Tea adapter follows the same flow but with one extra step you can't skip.

In day-to-day development, `adapters/bubbletea/go.mod` carries a `replace` directive so the adapter compiles against the in-tree core checkout:

```
replace github.com/ivere27/volvoxgrid/go => ../../go
```

That's for local development only. **Drop the `replace` and pin a real `require github.com/ivere27/volvoxgrid/go vX.Y.Z` before tagging a public adapter release** — otherwise external consumers can't resolve the adapter, because the Go proxy ignores `replace` directives in published modules.

Once the `go.mod` is clean, tag and push:

```sh
git tag adapters/bubbletea/v0.1.0
git push origin adapters/bubbletea/v0.1.0
```

After verification (below), restore the `replace` directive in a follow-up commit so local development keeps working against the unpublished tip.

## Verifying after publish

It's worth confirming the tag is resolvable before you announce a release. From a clean directory outside this repo:

```sh
mkdir /tmp/vgcheck && cd /tmp/vgcheck
go mod init test
go get github.com/ivere27/volvoxgrid/go@v0.8.9
go get github.com/ivere27/volvoxgrid/adapters/bubbletea@v0.1.0
go list -m github.com/ivere27/volvoxgrid/go
go list -m github.com/ivere27/volvoxgrid/adapters/bubbletea
```

With the default `GOPROXY=https://proxy.golang.org,direct`, no manual proxy interaction is required — the public proxy will fetch and cache both modules on first request.

## Adding a new adapter

When you add a new third-party-framework adapter (Cobra, Wails, lipgloss-based widgets, etc.), repeat the pattern so the core stays small:

1. Create `adapters/<name>/` with its own `go.mod`.
2. Set the module path to `github.com/ivere27/volvoxgrid/adapters/<name>`.
3. Add `replace github.com/ivere27/volvoxgrid/go => ../../go` for local development.
4. Tag releases as `adapters/<name>/vX.Y.Z`, after dropping the `replace` and pinning a real core version.

Keep the core wrapper at `/go/` free of third-party UI and runtime dependencies. If a feature really belongs in the core, it should be expressible with just `synurang`, `grpc`, and `protobuf`.

## What's next

- [./README.md](./README.md) — usage walkthrough for the core wrapper and the Bubble Tea adapter.
- [../TUI.md](../TUI.md) — the thin-host architecture that the Go terminal host implements.
