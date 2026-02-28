#!/usr/bin/env bash
# Zig CC linker wrapper for macOS cross-compilation.
# Invoked by Cargo as the linker for x86_64-apple-darwin / aarch64-apple-darwin targets.
# The script name determines the target: zig-cc-x86_64-macos.sh or zig-cc-aarch64-macos.sh.
#
# Filters out linker flags that zig cc / lld don't support on macOS targets,
# and uses -undefined dynamic_lookup so missing macOS system libs (iconv, System,
# CoreFoundation, etc.) are resolved at load time on the real macOS host.

SCRIPT_NAME="$(basename "$0")"

case "${SCRIPT_NAME}" in
  *x86_64*)  ZIG_TARGET="x86_64-macos"  ;;
  *aarch64*) ZIG_TARGET="aarch64-macos" ;;
  *)
    echo "Error: cannot determine zig target from script name: ${SCRIPT_NAME}" >&2
    exit 1
    ;;
esac

# Filter unsupported linker args and macOS system libs unavailable in Docker.
FILTERED_ARGS=()
SKIP_NEXT=false
for arg in "$@"; do
  if $SKIP_NEXT; then
    SKIP_NEXT=false
    continue
  fi
  case "$arg" in
    # -exported_symbols_list not supported by zig/lld
    -Wl,-exported_symbols_list)
      SKIP_NEXT=true
      continue
      ;;
    -Wl,-exported_symbols_list,*)
      continue
      ;;
    # macOS system libs not available in Docker cross-compile environment
    -liconv|-lSystem|-lc|-lm)
      continue
      ;;
    # macOS frameworks not available
    -framework)
      SKIP_NEXT=true
      continue
      ;;
    *)
      FILTERED_ARGS+=("$arg")
      ;;
  esac
done

exec zig cc -target "${ZIG_TARGET}" -Wl,-undefined,dynamic_lookup "${FILTERED_ARGS[@]}"
