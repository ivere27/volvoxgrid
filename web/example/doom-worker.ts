/// <reference lib="WebWorker" />

interface DoomEvents {
  onFrameSize(handler: (w: number, h: number) => void): void;
  onFrame(handler: (rgb: Uint8Array, rgba?: Uint8Array) => void): void;
}

interface DoomCommandInterface {
  sendKeyEvent(code: number, pressed: boolean): void;
  events(): DoomEvents;
}

interface DoomEmulatorsGlobal {
  pathPrefix: string;
  dosboxWorker(payload: Array<Uint8Array | { path: string; contents: Uint8Array }>): Promise<DoomCommandInterface>;
}

interface DoomWorkerInitMessage {
  type: "init";
  bundlePath: string;
  emulatorsScriptPath: string;
  emulatorsPrefix: string;
  defaultCfg: string;
}

interface DoomWorkerKeyMessage {
  type: "key";
  code: number;
  pressed: boolean;
}

type DoomWorkerInputMessage = DoomWorkerInitMessage | DoomWorkerKeyMessage;

interface DoomWorkerReadyMessage {
  type: "ready";
}

interface DoomWorkerErrorMessage {
  type: "error";
  message: string;
}

interface DoomWorkerFrameSizeMessage {
  type: "frame-size";
  width: number;
  height: number;
}

interface DoomWorkerFrameMessage {
  type: "frame";
  data: ArrayBuffer;
  width: number;
  height: number;
}

type DoomWorkerOutputMessage =
  | DoomWorkerReadyMessage
  | DoomWorkerErrorMessage
  | DoomWorkerFrameSizeMessage
  | DoomWorkerFrameMessage;

const scope = self as DedicatedWorkerGlobalScope & typeof globalThis & { emulators?: DoomEmulatorsGlobal };

let doomCi: DoomCommandInterface | null = null;
let initStarted = false;
let frameWidth = 0;
let frameHeight = 0;
const pendingKeyEvents: DoomWorkerKeyMessage[] = [];

function toErrorMessage(err: unknown): string {
  if (err instanceof Error) return err.message;
  return String(err);
}

function postMessageToMain(msg: DoomWorkerOutputMessage, transfer?: Transferable[]): void {
  if (transfer && transfer.length > 0) {
    scope.postMessage(msg, transfer);
    return;
  }
  scope.postMessage(msg);
}

function postError(message: string): void {
  const msg: DoomWorkerErrorMessage = { type: "error", message };
  postMessageToMain(msg);
}

function postFrame(frame: Uint8Array): void {
  // Create a dedicated buffer for transfer so we don't detach emulator-owned memory.
  const copied = new Uint8Array(frame);
  const msg: DoomWorkerFrameMessage = {
    type: "frame",
    data: copied.buffer,
    width: frameWidth,
    height: frameHeight,
  };
  postMessageToMain(msg, [copied.buffer]);
}

function flushPendingKeyEvents(): void {
  if (!doomCi) return;
  for (const ev of pendingKeyEvents) {
    doomCi.sendKeyEvent(ev.code, ev.pressed);
  }
  pendingKeyEvents.length = 0;
}

async function loadScript(url: string): Promise<void> {
  try {
    // Fast path: same-origin scripts can use importScripts directly.
    scope.importScripts(url);
    return;
  } catch {
    // importScripts fails for cross-origin URLs — fall through to fetch+blob.
  }

  const resp = await fetch(url, { mode: "cors", credentials: "omit" });
  if (!resp.ok) {
    throw new Error(`Failed to fetch script (${url}): ${resp.status}`);
  }
  const text = await resp.text();
  const blob = new Blob([text], { type: "application/javascript" });
  const blobUrl = URL.createObjectURL(blob);
  try {
    scope.importScripts(blobUrl);
  } finally {
    URL.revokeObjectURL(blobUrl);
  }
}

async function initEmulator(msg: DoomWorkerInitMessage): Promise<void> {
  // The emulators CDN script references `window` which does not exist in a
  // Worker scope.  Alias the worker global so the library can initialise.
  if (typeof (globalThis as any).window === "undefined") {
    (globalThis as any).window = self;
  }

  await loadScript(msg.emulatorsScriptPath);

  const emu = scope.emulators;
  if (!emu || typeof emu.dosboxWorker !== "function") {
    throw new Error("DOOM emulators API is unavailable in worker");
  }
  emu.pathPrefix = msg.emulatorsPrefix;

  let resp: Response;
  try {
    resp = await fetch(msg.bundlePath);
  } catch (err) {
    throw new Error(`Failed to fetch DOOM bundle (${msg.bundlePath}): ${toErrorMessage(err)}`);
  }
  if (!resp.ok) {
    throw new Error(`Failed to fetch DOOM bundle (${msg.bundlePath}): ${resp.status}`);
  }
  const bundle = new Uint8Array(await resp.arrayBuffer());
  const cfg = new TextEncoder().encode(msg.defaultCfg);

  doomCi = await emu.dosboxWorker([
    bundle,
    { path: "DEFAULT.CFG", contents: cfg },
  ]);

  doomCi.events().onFrameSize((w, h) => {
    frameWidth = w;
    frameHeight = h;
    const frameSizeMsg: DoomWorkerFrameSizeMessage = { type: "frame-size", width: w, height: h };
    postMessageToMain(frameSizeMsg);
  });
  doomCi.events().onFrame((rgb, rgba) => {
    postFrame(rgba ?? rgb);
  });

  flushPendingKeyEvents();
  const ready: DoomWorkerReadyMessage = { type: "ready" };
  postMessageToMain(ready);
}

// Use addEventListener instead of setting onmessage directly, because the
// emulators library's Emscripten module (wdosbox.js) may overwrite
// self.onmessage when eval'd in this scope.
scope.addEventListener("message", (event: MessageEvent<DoomWorkerInputMessage>) => {
  const msg = event.data;
  if (!msg || typeof msg !== "object") return;

  if (msg.type === "init") {
    if (initStarted) return;
    initStarted = true;
    void initEmulator(msg).catch((err: unknown) => {
      postError(`DOOM worker init failed: ${toErrorMessage(err)}`);
    });
    return;
  }

  if (msg.type === "key") {
    if (!doomCi) {
      pendingKeyEvents.push(msg);
      return;
    }
    doomCi.sendKeyEvent(msg.code, msg.pressed);
  }
});
