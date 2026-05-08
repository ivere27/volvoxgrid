# Publishing the Go modules

This repo ships **two** independent Go modules:

| Path                              | Module                                                   | Tag prefix             |
|-----------------------------------|----------------------------------------------------------|------------------------|
| `/go/`                            | `github.com/ivere27/volvoxgrid/go` (core wrapper)        | `go/vX.Y.Z`            |
| `/adapters/bubbletea/`            | `github.com/ivere27/volvoxgrid/adapters/bubbletea`       | `adapters/bubbletea/vX.Y.Z` |

The core module is intentionally minimal — only `synurang`, `grpc`, and
`protobuf`. Adapters that pull in third-party UI frameworks (Bubble Tea, etc.)
live in their own modules so consumers of the core wrapper do not inherit
those dependencies.

## Core: `github.com/ivere27/volvoxgrid/go`

```go
import (
    "github.com/ivere27/volvoxgrid/go/pkg/volvoxgrid"
    pb "github.com/ivere27/volvoxgrid/go/api/v1"
)
```

Because the module sits in the `/go/` subdirectory, version tags must be
**prefixed** with the directory name:

```
go/v0.8.7
go/v0.8.7
```

Plain `vX.Y.Z` tags (used by the rest of the project) are not picked up by the
Go proxy for a subdirectory module — the proxy looks for `<subdir>/<semver>`
when the module path includes a subdirectory.

### Cutting a release

```sh
git tag go/v0.8.7
git push origin go/v0.8.7
```

The first time `go get github.com/ivere27/volvoxgrid/go@v0.8.7` runs, the
proxy pulls the tag, locates `/go/go.mod`, and caches the module.

## Adapter: `github.com/ivere27/volvoxgrid/adapters/bubbletea`

```go
import "github.com/ivere27/volvoxgrid/adapters/bubbletea"
```

Same subdirectory rules apply — tags are prefixed with the full path:

```
adapters/bubbletea/v0.1.0
```

### Local development

`adapters/bubbletea/go.mod` ships with a `replace` directive pointing the core
dependency at the sibling `/go/` checkout:

```
replace github.com/ivere27/volvoxgrid/go => ../../go
```

This lets the adapter compile in this repo before the core module is
published. **Drop the `replace` and pin a real version** (`require
github.com/ivere27/volvoxgrid/go vX.Y.Z`) before tagging an adapter release;
otherwise the published adapter cannot be resolved by external consumers.

### Cutting a release

```sh
git tag adapters/bubbletea/v0.1.0
git push origin adapters/bubbletea/v0.1.0
```

## Verifying

From outside this repo:

```sh
mkdir /tmp/vgcheck && cd /tmp/vgcheck
go mod init test
go get github.com/ivere27/volvoxgrid/go@v0.8.7
go get github.com/ivere27/volvoxgrid/adapters/bubbletea@v0.1.0
go list -m github.com/ivere27/volvoxgrid/go
go list -m github.com/ivere27/volvoxgrid/adapters/bubbletea
```

With the default `GOPROXY=https://proxy.golang.org,direct`, no manual proxy
interaction is required.

## Adding new adapters

For each new third-party-framework adapter (Cobra, Wails, etc.), repeat the
pattern:

1. Create `adapters/<name>/` with its own `go.mod`.
2. Module path: `github.com/ivere27/volvoxgrid/adapters/<name>`.
3. `replace github.com/ivere27/volvoxgrid/go => ../../go` for local development.
4. Tag with `adapters/<name>/vX.Y.Z`.

Keep the core wrapper at `/go/` free of third-party UI/runtime dependencies.
