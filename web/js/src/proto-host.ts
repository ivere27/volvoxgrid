/**
 * WASM-backed implementation of the synurang FFI `PluginHost` interface.
 *
 * Routes unary RPCs through `<prefix>_<rpc_snake>_pb(bytes) -> Uint8Array`
 * exports and streaming RPCs through the matching
 * `<prefix>_stream_{open,send,recv,close_send,close}` exports.
 */
import type { PluginHost, PluginStream } from "./generated/volvoxgrid_ffi.js";

export { PluginHost, PluginStream };

export const STREAM_STATUS_DATA = 0;
export const STREAM_STATUS_EOF = 1;
export const STREAM_STATUS_ERROR = 2;
export const STREAM_STATUS_PENDING = 3;

type StreamHandle = bigint;

interface WasmStreamApi {
  open: (method: string) => bigint | number;
  send: (handle: StreamHandle, data: Uint8Array) => bigint | number;
  recv: (handle: StreamHandle) => Uint8Array;
  closeSend: (handle: StreamHandle) => void;
  close: (handle: StreamHandle) => void;
  lastError: () => string;
}

function snakeCase(camel: string): string {
  return camel.replace(/([A-Z])/g, (_, c: string, i: number) =>
    i === 0 ? c.toLowerCase() : `_${c.toLowerCase()}`,
  );
}

function methodNameFromPath(methodPath: string): string {
  const i = methodPath.lastIndexOf("/");
  return i < 0 ? methodPath : methodPath.slice(i + 1);
}

export interface WasmPluginHostOptions {
  /** Native prefix used by the wasm exports (defaults to `"volvox_grid"`). */
  nativePrefix?: string;
}

export class WasmPluginHost implements PluginHost {
  private readonly prefix: string;

  constructor(private readonly wasm: Record<string, unknown>, options: WasmPluginHostOptions = {}) {
    this.prefix = options.nativePrefix ?? "volvox_grid";
  }

  invoke(_serviceName: string, methodName: string, data: Uint8Array): Uint8Array {
    const exportName = this.unaryExportName(methodName);
    const fn = this.wasm[exportName];
    if (typeof fn !== "function") {
      throw new Error(`WasmPluginHost: export '${exportName}' not found`);
    }
    const result = (fn as (req: Uint8Array) => unknown)(data);
    if (!(result instanceof Uint8Array)) {
      throw new Error(`WasmPluginHost: '${exportName}' did not return Uint8Array`);
    }
    if (result.length === 0) {
      const err = this.lastError();
      if (err !== "") {
        throw new Error(`${methodName}: ${err}`);
      }
    }
    return result;
  }

  openStream(_serviceName: string, methodName: string): PluginStream {
    const api = this.streamApi();
    const handle = BigInt(api.open(methodName));
    if (handle === -1n) {
      throw new Error(`${methodName}: ${api.lastError() || "openStream failed"}`);
    }

    let sendClosed = false;
    let closed = false;
    return {
      send(data: Uint8Array): void {
        if (closed) {
          throw new Error(`${methodName}: stream is closed`);
        }
        const status = Number(api.send(handle, data));
        if (status < 0) {
          throw new Error(`${methodName}: ${api.lastError() || "send failed"}`);
        }
      },
      recv(): Uint8Array | null {
        if (closed) {
          return null;
        }
        const frame = api.recv(handle);
        if (!(frame instanceof Uint8Array) || frame.length < 1) {
          throw new Error(`${methodName}: stream recv returned malformed frame`);
        }
        const status = frame[0];
        if (status === STREAM_STATUS_DATA) {
          return frame.subarray(1);
        }
        if (status === STREAM_STATUS_EOF) {
          return null;
        }
        if (status === STREAM_STATUS_ERROR) {
          throw new Error(`${methodName}: ${api.lastError() || "stream error"}`);
        }
        // PENDING: caller is expected to retry. In a fully sync wasm runtime
        // after closeSend, this shouldn't happen — treat it as EOF to keep
        // the consumer loop from spinning forever.
        return null;
      },
      closeSend(): void {
        if (closed || sendClosed) return;
        sendClosed = true;
        api.closeSend(handle);
      },
      close(): void {
        if (closed) return;
        closed = true;
        api.close(handle);
      },
    };
  }

  private unaryExportName(methodPath: string): string {
    return `${this.prefix}_${snakeCase(methodNameFromPath(methodPath))}_pb`;
  }

  private streamApi(): WasmStreamApi {
    const wasm = this.wasm;
    const prefix = this.prefix;
    const open = wasm[`${prefix}_stream_open`];
    const send = wasm[`${prefix}_stream_send`];
    const recv = wasm[`${prefix}_stream_recv`];
    const closeSend = wasm[`${prefix}_stream_close_send`];
    const close = wasm[`${prefix}_stream_close`];
    if (
      typeof open !== "function"
      || typeof send !== "function"
      || typeof recv !== "function"
      || typeof closeSend !== "function"
      || typeof close !== "function"
    ) {
      throw new Error(`WasmPluginHost: streaming exports not available for prefix '${prefix}'`);
    }
    return {
      open: open as WasmStreamApi["open"],
      send: send as WasmStreamApi["send"],
      recv: recv as WasmStreamApi["recv"],
      closeSend: closeSend as WasmStreamApi["closeSend"],
      close: close as WasmStreamApi["close"],
      lastError: () => this.lastError(),
    };
  }

  private lastError(): string {
    const fn = this.wasm[`${this.prefix}_last_error`];
    return typeof fn === "function" ? String((fn as () => unknown)() ?? "") : "";
  }
}
