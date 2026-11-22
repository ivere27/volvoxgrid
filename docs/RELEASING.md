# Releasing VolvoxGrid

VolvoxGrid uses a **transparent GitHub Actions build + local signing & publishing** pipeline:

1. **GitHub Actions ([`.github/workflows/build.yml`](../.github/workflows/build.yml))** runs the test suite, builds all platform binaries inside pinned Docker containers ([`Dockerfile.android`](../Dockerfile.android), [`Dockerfile.desktop`](../Dockerfile.desktop), [`Dockerfile.ios`](../Dockerfile.ios), [`Dockerfile.web`](../Dockerfile.web)), deep-verifies every archive via [`scripts/release.py`](../scripts/release.py), and publishes all **47 release artifacts + `SHA256SUMS`** to GitHub Releases.
2. **Zero external secrets or signing keys live on GitHub.** After the GitHub Release is published, the maintainer runs local `make publish_*_release` commands. [`scripts/release.py`](../scripts/release.py) downloads the verified assets from GitHub Releases, cross-checks every file against both `SHA256SUMS` and the GitHub API `sha256` digest, signs them locally (GPG for Maven Central, optional `.pfx` certificate for NuGet), and publishes them to Maven Central, npm, NuGet, pub.dev, and GitHub Pages.

---

## 1. Release Artifact & Registry Inventory

Every GitHub Release (`nightly`, pre-release `vX.Y.Z-rc.N`, or stable `vX.Y.Z`) carries **48 files** (`47` build artifacts + `SHA256SUMS`):

| Category | Count | GitHub Release Assets | Downstream Registry / Consumer |
|---|---:|---|---|
| **Maven (Android AARs)** | 16 | `volvoxgrid-android[-lite]-<ver>.{aar,pom}`, `-sources.jar`, `-javadoc.jar`<br>`volvoxgrid-android-compose[-lite]-<ver>.{aar,pom}`, `-sources.jar`, `-javadoc.jar` | Maven Central (`io.github.ivere27`) |
| **Maven (Java Desktop JARs)** | 8 | `volvoxgrid-desktop[-lite]-<ver>.{jar,pom}`, `-sources.jar`, `-javadoc.jar` (fat JARs embedding 8 OS/arch native libraries) | Maven Central (`io.github.ivere27`) |
| **NuGet (.NET)** | 2 | `VolvoxGrid.DotNet.<ver>.nupkg`, `VolvoxGrid.DotNet.Lite.<ver>.nupkg` (`net8.0` + `net40` + 6 native RIDs: `win-x64`, `win-x86`, `linux-x64`, `linux-arm64`, `osx-x64`, `osx-arm64`) | NuGet (`nuget.org`) |
| **Windows Desktop Extras** | 5 | `volvoxgrid-activex-<ver>.zip` (4 `.ocx` binaries)<br>`volvoxgrid-dotnet-winforms[-lite]-<ver>-{x64,x86}.zip` (4 bundles) | Direct download from GitHub Releases |
| **Apple / SwiftPM** | 2 | `VolvoxGrid.xcframework.zip`, `VolvoxGridLite.xcframework.zip` (`ios-arm64` + `ios-arm64_x86_64-simulator`) | SwiftPM ([`Package.swift`](../Package.swift)) & Flutter iOS podspec |
| **Web & GitHub Pages** | 3 | `volvoxgrid-web-<ver>.zip`, `volvoxgrid-web-lite-<ver>.zip`, `volvoxgrid-demo-<ver>.zip` | GitHub Pages ([`.github/workflows/pages.yml`](../.github/workflows/pages.yml)) |
| **npm Tarballs** | 4 | `volvoxgrid-<ver>.tgz`, `volvoxgrid-lite-<ver>.tgz`, `volvoxgrid-ag-grid-<ver>.tgz`, `volvoxgrid-sheet-<ver>.tgz` | npm (`volvoxgrid`, `volvoxgrid-lite`, `@volvoxgrid/ag-grid`, `@volvoxgrid/sheet`) |
| **Debug Symbols** | 7 | `volvoxgrid-{android,android-lite,desktop,desktop-lite,activex}-<ver>-debug-symbols.zip`, `VolvoxGrid{,Lite}-<ver>-debug-symbols.zip` | Direct download from GitHub Releases |
| **Checksum Manifest** | 1 | `SHA256SUMS` (SHA-256 digests for all 47 artifacts above) | Verified by `scripts/release.py` before local signing/publishing |

Additional source-tagged packages published from the same release commit:
- **Flutter (`pub.dev`)**: [`flutter/`](../flutter) (`volvoxgrid`), which resolves Android/Desktop native artifacts from Maven Central and iOS XCFrameworks from GitHub Releases.
- **Go modules (`proxy.golang.org`)**: `github.com/ivere27/volvoxgrid/go` (tag `go/vX.Y.Z`) and `github.com/ivere27/volvoxgrid/adapters/bubbletea` (tag `adapters/bubbletea/vX.Y.Z`). See [`go/PUBLISHING.md`](../go/PUBLISHING.md).

---

## 2. Local Prerequisites (For Signing & Publishing)

You do **not** need Docker, Android NDK, Mingw-w64, or Xcode installed locally to sign and publish a release built by GitHub Actions. You only need:

1. **GitHub CLI (`gh`)** authenticated with repo access (`gh auth status`).
2. **Python 3.10+** (standard library only).
3. **Maven Central credentials & GPG key**:
   - `gpg` with your Sonatype-registered signing key in your local keyring.
   - `.maven-settings.xml` at the repository root (gitignored) or `SONATYPE_USERNAME` / `SONATYPE_PASSWORD` environment variables:
     ```xml
     <settings>
       <servers>
         <server>
           <id>central</id>
           <username>YOUR_SONATYPE_TOKEN_USER</username>
           <password>YOUR_SONATYPE_TOKEN_PASSWORD</password>
         </server>
       </servers>
     </settings>
     ```
4. **npm CLI** authenticated via `npm login` (`npm whoami`).
5. **.NET SDK (`dotnet`)** and `NUGET_API_KEY` (either in the environment or in `~/.nuget-env`). Optional code-signing certificate via `NUGET_CERT_PATH=/path/to/codesign.pfx`.
6. **Flutter SDK (`flutter`)** authenticated with `pub.dev`.

---

## 3. Standard Stable Release Runbook (`vX.Y.Z`)

Because Swift Package Manager consumers read [`Package.swift`](../Package.swift) directly from the git tag `vX.Y.Z`—and `Package.swift` embeds the SHA-256 checksums of `VolvoxGrid.xcframework.zip` and `VolvoxGridLite.xcframework.zip`—stable releases use a **2-step staging flow** so that GitHub Actions builds the XCFrameworks first, their checksums are synced into `Package.swift`, and tag `vX.Y.Z` promotes the draft without rebuilding.

### Step 1: Bump Version & Push to `main`

Update [`VERSION`](../VERSION), all package manifests, lockfiles, installation snippets, and [`CHANGELOG.md`](../CHANGELOG.md) / [`flutter/CHANGELOG.md`](../flutter/CHANGELOG.md):

```bash
make bump-version NEW_VERSION=X.Y.Z
make check_versions test_release
git status
git commit -am "release: vX.Y.Z"
git push origin main
```

> **Note:** Pushing to `main` automatically starts the `build.yml` workflow for the `nightly` pre-release. If you want to stage the `vX.Y.Z` draft release right away, proceed to Step 2.

### Step 2: Stage the Draft Release on GitHub Actions

Trigger the `build.yml` workflow with `stage_release=true`:

```bash
make stage_release REF=main
```

Watch the run until it finishes:

```bash
gh run list --workflow build.yml
gh run watch
```

When `prepare-release` finishes, GitHub Actions will have built and verified all 47 artifacts + `SHA256SUMS` and created a **Draft GitHub Release `vX.Y.Z`** recording the source commit in `<!-- volvoxgrid-source-sha: <sha> -->`.

### Step 3: Sync `Package.swift` Checksums & Push Tag `vX.Y.Z`

Pull the verified `VolvoxGrid.xcframework.zip` and `VolvoxGridLite.xcframework.zip` SHA-256 checksums from the Draft Release into [`Package.swift`](../Package.swift):

```bash
make sync_swift_checksums TAG=vX.Y.Z
```

Commit `Package.swift`, create the annotated tag `vX.Y.Z`, and push both:

```bash
git commit -m "Package.swift vX.Y.Z" Package.swift
git tag -a vX.Y.Z -m "vX.Y.Z"
git push origin main
git push origin vX.Y.Z
```

**What happens on GitHub Actions when `vX.Y.Z` is pushed:**
- The `check-draft` job (running with `contents: write` on `refs/tags/v*` pushes after `preflight`) runs `python3 scripts/release.py check-reusable-draft --tag vX.Y.Z --sha $GITHUB_SHA`.
- It verifies that:
  1. `git diff --name-only <draft_sha> <tag_sha>` contains **only** `Package.swift`.
  2. All 48 files exist on the Draft Release and their GitHub API digests match `SHA256SUMS`.
  3. The URLs and checksums in `Package.swift` at `vX.Y.Z` match `VolvoxGrid.xcframework.zip` and `VolvoxGridLite.xcframework.zip` in `SHA256SUMS`.
- Because those checks pass, **all heavy build jobs (`test-core`, `build-android`, `build-desktop`, `build-ios`, `build-web`) are skipped**, and `finalize-release` immediately promotes the Draft Release to **Published**.

*(Fallback: If you push a tag `vX.Y.Z` directly without running `make stage_release` first, `prepare-release` will run the full build and save the verified artifacts into Draft Release `vX.Y.Z`, and `finalize-release` will fail with a workflow step summary containing instructions to run `make sync_swift_checksums TAG=vX.Y.Z` and re-tag. Note that if your repository has tag-protection rulesets blocking tag force-pushes, always use the `make stage_release` 2-step flow before creating the tag.)*

### Step 4: Dry-Run Local Signing & Publishing

Once GitHub Release `vX.Y.Z` is **Published**, verify all local publishing steps in dry-run mode:

```bash
make publish_release TAG=vX.Y.Z DRY_RUN=1
```

This downloads the release assets into a temporary directory, verifies every checksum and internal binary layout, and previews Maven Central, npm, NuGet, Flutter, and GitHub Pages publication without uploading anything.

### Step 5: Sign & Publish Locally to All Registries

You can run the unified target (which executes Maven Central, npm, NuGet, Flutter, and GitHub Pages in sequence), followed by the Go module tag targets:

```bash
make publish_release TAG=vX.Y.Z
make publish_go CONFIRM_PUBLISH_GO=1
make publish_go_bubbletea CONFIRM_PUBLISH_GO=1
```

Or run each registry step individually:

```bash
# 1. Maven Central (GPG-signs all 24 files locally, uploads atomic bundle, polls until PUBLISHED)
make publish_maven_release TAG=vX.Y.Z

# 2. npm (publishes volvoxgrid, volvoxgrid-lite, @volvoxgrid/ag-grid, @volvoxgrid/sheet)
#    Pass NPM_OTP=123456 if your npm account requires 2FA OTP on publish.
make publish_npm_release TAG=vX.Y.Z

# 3. NuGet (optionally signs with NUGET_CERT_PATH, then pushes VolvoxGrid.DotNet & VolvoxGrid.DotNet.Lite)
make publish_nuget_release TAG=vX.Y.Z

# 4. Flutter / pub.dev (verifies Maven Central + GitHub Release assets are live, then publishes clean git worktree)
make publish_flutter_release TAG=vX.Y.Z

# 5. GitHub Pages release demo (triggers .github/workflows/pages.yml with volvoxgrid-demo-X.Y.Z.zip)
make publish_pages TAG=vX.Y.Z

# 6. Go modules (tags and pushes go/vX.Y.Z and adapters/bubbletea/vX.Y.Z; see go/PUBLISHING.md)
make publish_go CONFIRM_PUBLISH_GO=1
make publish_go_bubbletea CONFIRM_PUBLISH_GO=1
```

---

## 4. Environment Variables & Make Overrides

| Variable | Used By | Default | Description |
|---|---|---|---|
| `TAG` | `publish_*_release`, `publish_release` | Required (no default) | GitHub Release tag to consume (`vX.Y.Z`) |
| `TAG` | `sync_swift_checksums`, `publish_pages` | `v$(VOLVOXGRID_VERSION)` | GitHub Release tag to consume (`vX.Y.Z`) |
| `REPO` | All GitHub Release targets | `ivere27/volvoxgrid` | GitHub `owner/repo` |
| `REF` | `stage_release`, `publish_pages` | `main` (`$(PAGES_REF)`) | Git branch to dispatch (`main`, `master`, or `release/*` for `stage_release`) |
| `DRY_RUN` | All `publish_*`, `stage_release`, `sync_swift_checksums` | `0` | Set `DRY_RUN=1` to validate and preview without mutating or uploading |
| `ALLOW_PRERELEASE` | `publish_*_release`, `publish_release`, `sync_swift_checksums` | `0` | Set `ALLOW_PRERELEASE=1` to allow publishing pre-release tags (`vX.Y.Z-rc.1`; `publish_release` skips `publish_pages` on pre-releases) |
| `ALLOW_DRAFT` | `publish_*_release`, `publish_pages` | `0` | Set `ALLOW_DRAFT=1` to test against a Draft GitHub Release (with `DRY_RUN=1`) |
| `MAVEN_SETTINGS` | `publish_maven`, `publish_maven_release` | `.maven-settings.xml` | Path to Maven settings XML containing `<server><id>central</id>` (falls back to a single `<server>` without `<id>`) |
| `MAVEN_SERVER_ID` | `publish_maven`, `publish_maven_release` | `central` | Server ID in `.maven-settings.xml` |
| `MAVEN_GPG_KEY` | `publish_maven`, `publish_maven_release` | default GPG key | Explicit GPG key ID/fingerprint (`--local-user`) |
| `MAVEN_GPG_PASSPHRASE` | `publish_maven`, `publish_maven_release` | `gpg-agent` | Optional passphrase (prefer `gpg-agent` pinentry caching) |
| `NPM_TAG` | `publish_npm_release` | `latest` (or prerelease label) | npm dist-tag (`--tag`) |
| `NPM_OTP` | `publish_npm_release` | — | 6-digit npm 2FA one-time password |
| `NUGET_API_KEY` | `publish_nuget_release` | `$NUGET_API_KEY` or `~/.nuget-env` | API key for `nuget.org` |
| `NUGET_SOURCE` | `publish_nuget_release` | `https://api.nuget.org/v3/index.json` | NuGet v3 source URL |
| `NUGET_CERT_PATH` | `publish_nuget_release` | — | Path to `.pfx` code-signing certificate for `dotnet nuget sign` |
| `NUGET_CERT_PASSWORD` | `publish_nuget_release` | — | Password for `NUGET_CERT_PATH` |
| `NUGET_TIMESTAMPER` | `publish_nuget_release` | `http://timestamp.digicert.com` | RFC 3161 timestamp server for `dotnet nuget sign` |
| `SKIP_UPSTREAM_CHECK` | `publish_flutter_release` | `0` | Set `SKIP_UPSTREAM_CHECK=1` to bypass upstream GitHub Release & Maven Central reachability checks (`DRY_RUN=1` automatically downgrades unpropagated Maven Central URLs to warnings) |
| `FLUTTER_UPSTREAM_POLL_INTERVAL` | `publish_flutter_release` | `10` (seconds) | Poll interval while waiting for Maven Central CDN propagation before publishing Flutter |
| `FLUTTER_UPSTREAM_POLL_TIMEOUT` | `publish_flutter_release` | `1200` (seconds) | Maximum wait time for Maven Central CDN propagation before publishing Flutter |

---

## 5. Nightly, Pre-Release, and Backport Flows

### Nightly Builds (`nightly`)
Every push to `main` builds all 47 artifacts + `SHA256SUMS` and atomically updates the rolling `nightly` GitHub pre-release. Nightly builds never publish to external package registries.

### Pre-Releases (`vX.Y.Z-rc.N`, `-alpha.N`, `-beta.N`, `-dev.N`)
When `VERSION` is set to a pre-release version and tagged `vX.Y.Z-rc.N`, GitHub Actions builds and verifies all artifacts and publishes the GitHub Release with `prerelease: true`. If you wish to publish a pre-release locally, pass `ALLOW_PRERELEASE=1` to individual `publish_*_release` targets or `make publish_release TAG=vX.Y.Z-rc.N ALLOW_PRERELEASE=1` (for npm, `scripts/release.py` automatically defaults `--tag` to the first pre-release identifier, such as `rc`, and refuses `--tag latest` on pre-releases; `publish_release` automatically skips `publish_pages` for pre-releases since GitHub Pages requires a stable release).

### Maintenance Backports (`release/*` & `VOLVOXGRID_ALLOW_OLDER_RELEASE`)
By default, `scripts/release.py release-ci` guards against accidentally tagging an older version than the highest published stable GitHub Release. To ship an intentional patch release on an older minor series (e.g., `v0.7.5` on branch `release/0.7` after `v0.8.12` is already published), set the GitHub Repository Variable `VOLVOXGRID_ALLOW_OLDER_RELEASE=1` and stage from the `release/*` branch (`make stage_release REF=release/0.7`).

---

## 6. Generated FFI Files & Git Tracking

To ensure clean checkouts in GitHub Actions and Docker containers build deterministically without requiring every build container to compile `protoc-gen-synurang-ffi-rs`, `protoc-gen-dart`, and `protoc-gen-go`, VolvoxGrid commits the per-language generated FFI bindings into git while keeping the scratch `codegen/` staging directory gitignored:

- **Android**: [`android/volvoxgrid-android/src/generated/volvoxgrid_ffi.java`](../android/volvoxgrid-android/src/generated/volvoxgrid_ffi.java)
- **Flutter**: [`flutter/lib/src/generated/`](../flutter/lib/src/generated)
- **Swift**: [`swift/Sources/VolvoxGrid/Generated/volvoxgrid_lite.swift`](../swift/Sources/VolvoxGrid/Generated/volvoxgrid_lite.swift)
- **.NET**: [`dotnet/src/common/Generated/volvoxgrid_lite.cs`](../dotnet/src/common/Generated/volvoxgrid_lite.cs)
- **C++**: [`cpp/include/generated/volvoxgrid_lite.hpp`](../cpp/include/generated/volvoxgrid_lite.hpp)
- **Web / TypeScript**: [`web/js/src/generated/`](../web/js/src/generated)
- **Go**: [`go/api/v1/`](../go/api/v1)
- **Rust Runtime / WASM / ActiveX**: [`runtime/src/volvoxgrid_ffi_runtime.rs`](../runtime/src/volvoxgrid_ffi_runtime.rs), [`runtime/src/wasm/volvoxgrid_wasm.rs`](../runtime/src/wasm/volvoxgrid_wasm.rs), [`adapters/vsflexgrid/crate/src/volvoxgrid_ffi_native.rs`](../adapters/vsflexgrid/crate/src/volvoxgrid_ffi_native.rs)

Whenever you modify [`proto/volvoxgrid.proto`](../proto/volvoxgrid.proto) or [`proto/volvoxtree.proto`](../proto/volvoxtree.proto), run `make codegen` locally and commit the updated generated files alongside your `.proto` change.
