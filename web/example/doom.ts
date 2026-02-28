import { VolvoxGrid } from "../js/src/volvoxgrid.js";

export const DOOM_RESOLUTIONS: Record<string, [number, number]> = {
  "50x80": [80, 50],
  "70x112": [112, 70],
  "100x160": [160, 100],
  "200x320": [320, 200],
};

export interface DoomAssetSource {
  id: "local" | "remote";
  bundlePath: string;
  emulatorsScriptPath: string;
  emulatorsPrefix: string;
}

const DOOM_ASSET_SOURCES: DoomAssetSource[] = [
  {
    id: "local",
    bundlePath: "/doom/vendor/doom.jsdos",
    emulatorsScriptPath: "/doom/emulators/emulators.js",
    emulatorsPrefix: "/doom/emulators/",
  },
  {
    id: "remote",
    bundlePath: "/doom/remote/vendor/doom.jsdos",
    emulatorsScriptPath: "/doom/remote/emulators/emulators.js",
    emulatorsPrefix: "/doom/remote/emulators/",
  },
];

export const DOOM_LOCAL_SOURCE = DOOM_ASSET_SOURCES[0];
const DOOM_EMULATORS_SCRIPT_ID = "volvoxgrid-doom-emulators-script";
export const DOOM_REMOTE_CONSENT_KEY = "volvoxgrid:doom-remote-consent-v1";

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

type MarkedScript = HTMLScriptElement & { __volvoxgridLoaded?: boolean };

// The public doom.jsdos bundle ships with key_up/key_down bound to W/S.
// Force classic arrow bindings at startup so ArrowUp/ArrowDown work.
const DOOM_DEFAULT_CFG = [
  "mouse_sensitivity\t\t5",
  "sfx_volume\t\t8",
  "music_volume\t\t8",
  "show_messages\t\t1",
  "key_right\t\t77",
  "key_left\t\t75",
  "key_up\t\t72",
  "key_down\t\t80",
  "key_strafeleft\t\t30",
  "key_straferight\t\t32",
  "key_fire\t\t29",
  "key_use\t\t57",
  "key_strafe\t\t56",
  "key_speed\t\t54",
  "use_mouse\t\t1",
  "mouseb_fire\t\t0",
  "mouseb_strafe\t\t1",
  "mouseb_forward\t\t2",
  "use_joystick\t\t0",
  "joyb_fire\t\t0",
  "joyb_strafe\t\t1",
  "joyb_use\t\t3",
  "joyb_speed\t\t2",
  "screenblocks\t\t10",
  "detaillevel\t\t0",
  "showmessages\t\t1",
  "comport\t\t1",
  "snd_channels\t\t3",
  "snd_musicdevice\t\t3",
  "snd_sfxdevice\t\t3",
  "snd_sbport\t\t544",
  "snd_sbirq\t\t7",
  "snd_sbdma\t\t1",
  "snd_mport\t\t-1",
  "usegamma\t\t0",
  "chatmacro0\t\t\"no macro\"",
  "chatmacro1\t\t\"no macro\"",
  "chatmacro2\t\t\"no macro\"",
  "chatmacro3\t\t\"no macro\"",
  "chatmacro4\t\t\"no macro\"",
  "chatmacro5\t\t\"no macro\"",
  "chatmacro6\t\t\"no macro\"",
  "chatmacro7\t\t\"no macro\"",
  "chatmacro8\t\t\"no macro\"",
  "chatmacro9\t\t\"no macro\"",
  "\t\t0",
].join("\n");

// e.code -> DOSBox (GLFW) keyCode mapping.
const CODE_TO_DOS: Record<string, number> = {
  Backspace: 259,
  Tab: 258,
  Enter: 257,
  Escape: 256,
  Space: 32,
  ShiftLeft: 340,
  ShiftRight: 344,
  ControlLeft: 341,
  ControlRight: 345,
  AltLeft: 342,
  AltRight: 346,
  Pause: 284,
  ArrowLeft: 263,
  ArrowUp: 265,
  ArrowRight: 262,
  ArrowDown: 264,
  PageUp: 266,
  PageDown: 267,
  Home: 268,
  End: 269,
  Insert: 260,
  Delete: 261,
  Digit0: 48,
  Digit1: 49,
  Digit2: 50,
  Digit3: 51,
  Digit4: 52,
  Digit5: 53,
  Digit6: 54,
  Digit7: 55,
  Digit8: 56,
  Digit9: 57,
  KeyA: 65,
  KeyB: 66,
  KeyC: 67,
  KeyD: 68,
  KeyE: 69,
  KeyF: 70,
  KeyG: 71,
  KeyH: 72,
  KeyI: 73,
  KeyJ: 74,
  KeyK: 75,
  KeyL: 76,
  KeyM: 77,
  KeyN: 78,
  KeyO: 79,
  KeyP: 80,
  KeyQ: 81,
  KeyR: 82,
  KeyS: 83,
  KeyT: 84,
  KeyU: 85,
  KeyV: 86,
  KeyW: 87,
  KeyX: 88,
  KeyY: 89,
  KeyZ: 90,
  F1: 290,
  F2: 291,
  F3: 292,
  F4: 293,
  F5: 294,
  F6: 295,
  F7: 296,
  F8: 297,
  F9: 298,
  F10: 299,
  F11: 300,
  F12: 301,
  Semicolon: 59,
  Minus: 45,
  Equal: 61,
  Backslash: 92,
  BracketLeft: 91,
  BracketRight: 93,
  Quote: 39,
  Period: 46,
  Comma: 44,
  Slash: 47,
  Backquote: 96,
};

const DOOM_STATUS_UPDATE_INTERVAL_MS = 1000;

export interface DoomAssetResolveResult {
  ok: boolean;
  source?: DoomAssetSource;
  message?: string;
}

function toAbsoluteUrl(path: string): string {
  return new URL(path, window.location.origin).toString();
}

function waitForDoomScript(script: MarkedScript, scriptPath: string): Promise<void> {
  if (script.__volvoxgridLoaded || (globalThis as { emulators?: unknown }).emulators) {
    return Promise.resolve();
  }

  return new Promise((resolve, reject) => {
    const onLoad = () => {
      script.__volvoxgridLoaded = true;
      resolve();
    };
    const onError = () => reject(new Error(`Failed to load ${scriptPath}`));
    script.addEventListener("load", onLoad, { once: true });
    script.addEventListener("error", onError, { once: true });
  });
}

async function ensureDoomEmulatorsScriptLoaded(source: DoomAssetSource): Promise<void> {
  if ((globalThis as { emulators?: unknown }).emulators) {
    return;
  }

  const expectedSrc = toAbsoluteUrl(source.emulatorsScriptPath);
  const existing = document.getElementById(DOOM_EMULATORS_SCRIPT_ID) as MarkedScript | null;
  if (existing && existing.src !== expectedSrc) {
    existing.remove();
  }

  const current = document.getElementById(DOOM_EMULATORS_SCRIPT_ID) as MarkedScript | null;
  if (current) {
    await waitForDoomScript(current, source.emulatorsScriptPath);
  } else {
    const script = document.createElement("script") as MarkedScript;
    script.id = DOOM_EMULATORS_SCRIPT_ID;
    script.src = source.emulatorsScriptPath;
    script.async = true;
    script.crossOrigin = "anonymous";
    document.head.appendChild(script);
    await waitForDoomScript(script, source.emulatorsScriptPath);
  }

  if (!(globalThis as { emulators?: unknown }).emulators) {
    throw new Error("DOOM emulators runtime did not initialize");
  }
}

async function initDoomEmulator(
  source: DoomAssetSource,
  onFrameSize: (w: number, h: number) => void,
  onFrame: (frame: Uint8Array) => void,
): Promise<DoomCommandInterface> {
  await ensureDoomEmulatorsScriptLoaded(source);

  const emu = (globalThis as { emulators?: DoomEmulatorsGlobal }).emulators;
  if (!emu || typeof emu.dosboxWorker !== "function") {
    throw new Error("DOOM emulators API is unavailable");
  }

  emu.pathPrefix = source.emulatorsPrefix;

  const resp = await fetch(source.bundlePath);
  if (!resp.ok) {
    throw new Error(`Failed to fetch DOOM bundle (${source.bundlePath}): ${resp.status}`);
  }
  const bundle = new Uint8Array(await resp.arrayBuffer());
  const cfg = new TextEncoder().encode(DOOM_DEFAULT_CFG);

  const ci = await emu.dosboxWorker([
    bundle,
    { path: "DEFAULT.CFG", contents: cfg },
  ]);

  ci.events().onFrameSize((w, h) => onFrameSize(w, h));
  ci.events().onFrame((rgb, rgba) => onFrame(rgba ?? rgb));

  return ci;
}

async function probeAsset(path: string): Promise<Response | null> {
  try {
    const resp = await fetch(path, { method: "HEAD", cache: "no-store" });
    if (resp.ok) return resp;
    if (resp.status === 405) {
      const getResp = await fetch(path, {
        method: "GET",
        cache: "no-store",
        headers: { Range: "bytes=0-0" },
      });
      if (getResp.ok) return getResp;
    }
  } catch {
    return null;
  }
  return null;
}

function isLikelyHtmlFallback(resp: Response): boolean {
  const contentType = (resp.headers.get("content-type") || "").toLowerCase();
  return contentType.includes("text/html");
}

async function fileExists(path: string): Promise<boolean> {
  const resp = await probeAsset(path);
  if (!resp) return false;
  if (isLikelyHtmlFallback(resp)) return false;
  return true;
}

export class DoomRuntime {
  private cols = 112;

  private rows = 70;

  private doomCi: DoomCommandInterface | null = null;

  private doomSourceInUse: DoomAssetSource | null = null;

  private doomFrameData: Uint8Array | null = null;

  private doomFrameWidth = 0;

  private doomFrameHeight = 0;

  private doomAnimId = 0;

  private doomLoopActive = false;

  private prevDoomColors: Uint32Array | null = null;

  private readonly pressedDosKeys = new Map<number, number>();

  private wallFrameCount = 0;

  private wallFpsLastTime = performance.now();

  private wallFpsValue = 0;

  private jsUpdateFrameCount = 0;

  private jsUpdateFpsLastTime = performance.now();

  private jsUpdateFpsValue = 0;

  getCols(): number {
    return this.cols;
  }

  getRows(): number {
    return this.rows;
  }

  setResolution(cols: number, rows: number): void {
    this.cols = Math.max(1, Math.trunc(cols));
    this.rows = Math.max(1, Math.trunc(rows));
    this.prevDoomColors = null;
  }

  hasSession(): boolean {
    return this.doomCi != null;
  }

  getSourceInUse(): DoomAssetSource | null {
    return this.doomSourceInUse;
  }

  async ensureEmulator(source: DoomAssetSource): Promise<void> {
    if (this.doomCi && this.doomSourceInUse?.id === source.id) {
      return;
    }

    this.doomCi = await initDoomEmulator(
      source,
      (w, h) => {
        this.doomFrameWidth = w;
        this.doomFrameHeight = h;
      },
      (frame) => {
        this.doomFrameData = frame;
      },
    );
    this.doomSourceInUse = source;
    this.prevDoomColors = null;
  }

  async resolveAssetSource(): Promise<DoomAssetResolveResult> {
    const checks = await Promise.all(
      DOOM_ASSET_SOURCES.map(async (source) => {
        const [bundleReady, emulatorsReady] = await Promise.all([
          fileExists(source.bundlePath),
          fileExists(source.emulatorsScriptPath),
        ]);
        return { source, bundleReady, emulatorsReady };
      }),
    );

    for (const source of DOOM_ASSET_SOURCES) {
      const check = checks.find((entry) => entry.source.id === source.id);
      if (check && check.bundleReady && check.emulatorsReady) {
        return { ok: true, source };
      }
    }

    const localCheck = checks.find((entry) => entry.source.id === DOOM_LOCAL_SOURCE.id);
    const localMissing: string[] = [];
    if (!localCheck?.bundleReady) localMissing.push("doom.jsdos bundle");
    if (!localCheck?.emulatorsReady) localMissing.push("emulators runtime");
    const localMissingText = localMissing.length > 0
      ? `missing ${localMissing.join(" and ")}`
      : "assets unavailable";

    return {
      ok: false,
      message: `DOOM mode is not ready: local ${localMissingText}. Remote fallback is unavailable. Run 'make doom-deps' or check network access, then reload.`,
    };
  }

  startRenderLoop(grid: VolvoxGrid, status: HTMLElement): void {
    this.prevDoomColors = null;
    this.stopRenderLoop();
    this.doomLoopActive = true;

    this.wallFrameCount = 0;
    this.wallFpsLastTime = performance.now();
    this.wallFpsValue = 0;
    this.jsUpdateFrameCount = 0;
    this.jsUpdateFpsLastTime = performance.now();
    this.jsUpdateFpsValue = 0;
    let lastStatusUpdateMs = 0;
    let cellUpdatesWindowCount = 0;
    let cellUpdatesWindowStartMs = performance.now();
    let cellUpdatesPerSecValue = 0;
    // Benchmark hack: reuse a single triplet buffer to avoid per-frame JS
    // allocation churn, so measurements are closer to engine-side costs.
    let colorUpdatesBuffer = new Uint32Array(Math.max(3, this.rows * this.cols * 3));

    const loop = () => {
      if (!this.doomLoopActive) {
        this.doomAnimId = 0;
        return;
      }
      const frameNow = performance.now();
      this.updateWallFps(frameNow);
      if (this.doomFrameData && this.doomFrameWidth > 0 && this.doomFrameHeight > 0) {
        const total = this.cols * this.rows;
        const isRgba = this.doomFrameData.length >= this.doomFrameWidth * this.doomFrameHeight * 4;
        const ch = isRgba ? 4 : 3;
        const blockW = this.doomFrameWidth / this.cols;
        const blockH = this.doomFrameHeight / this.rows;

        const newColors = new Uint32Array(total);
        let changed = 0;
        let colorUpdateLen = 0;

        for (let r = 0; r < this.rows; r += 1) {
          const srcY = Math.min((r * blockH + blockH * 0.5) | 0, this.doomFrameHeight - 1);
          const rowOff = srcY * this.doomFrameWidth;
          for (let c = 0; c < this.cols; c += 1) {
            const srcX = Math.min((c * blockW + blockW * 0.5) | 0, this.doomFrameWidth - 1);
            const idx = (rowOff + srcX) * ch;
            const color = ((0xFF << 24)
              | (this.doomFrameData[idx] << 16)
              | (this.doomFrameData[idx + 1] << 8)
              | this.doomFrameData[idx + 2]) >>> 0;

            const cellIdx = r * this.cols + c;
            newColors[cellIdx] = color;

            if (!this.prevDoomColors || this.prevDoomColors[cellIdx] !== color) {
              if (colorUpdateLen + 3 > colorUpdatesBuffer.length) {
                const grown = new Uint32Array(Math.max(colorUpdateLen + 3, colorUpdatesBuffer.length * 2));
                grown.set(colorUpdatesBuffer);
                colorUpdatesBuffer = grown;
              }
              colorUpdatesBuffer[colorUpdateLen] = r;
              colorUpdatesBuffer[colorUpdateLen + 1] = c;
              colorUpdatesBuffer[colorUpdateLen + 2] = color;
              colorUpdateLen += 3;
              changed += 1;
            }
          }
        }
        this.prevDoomColors = newColors;
        if (changed > 0) {
          grid.setCellBackColors(colorUpdatesBuffer.subarray(0, colorUpdateLen));
          grid.invalidate();
        }
        cellUpdatesWindowCount += changed;

        this.updateJsUpdateLoopFps(frameNow);
        if (lastStatusUpdateMs === 0 || frameNow - lastStatusUpdateMs >= DOOM_STATUS_UPDATE_INTERVAL_MS) {
          const elapsed = frameNow - cellUpdatesWindowStartMs;
          cellUpdatesPerSecValue = elapsed > 0
            ? Math.round((cellUpdatesWindowCount * 1000) / elapsed)
            : 0;
          cellUpdatesWindowCount = 0;
          cellUpdatesWindowStartMs = frameNow;
          status.textContent = `DOOM ${this.cols}x${this.rows} (${total.toLocaleString("en-US")} cells) wall ${this.wallFpsValue} fps | JS update-loop rate ${this.jsUpdateFpsValue} fps | cell updates ${cellUpdatesPerSecValue.toLocaleString("en-US")}/s - Arrows=move Ctrl=fire Space=use`;
          lastStatusUpdateMs = frameNow;
        }
      }

      this.doomAnimId = requestAnimationFrame(loop);
    };

    this.doomAnimId = requestAnimationFrame(loop);
  }

  stopRenderLoop(): void {
    this.doomLoopActive = false;
    if (this.doomAnimId) {
      cancelAnimationFrame(this.doomAnimId);
      this.doomAnimId = 0;
    }
  }

  handleKeyDown(code: string, repeat: boolean): boolean {
    if (!this.doomCi) return false;
    const dosKeys = this.dosKeysForCode(code);
    if (dosKeys.length === 0) return false;
    if (repeat) return true;
    for (const dosKey of dosKeys) {
      this.setDosKeyPressed(dosKey, true);
    }
    return true;
  }

  handleKeyUp(code: string): boolean {
    if (!this.doomCi) return false;
    const dosKeys = this.dosKeysForCode(code);
    if (dosKeys.length === 0) return false;
    for (const dosKey of dosKeys) {
      this.setDosKeyPressed(dosKey, false);
    }
    return true;
  }

  releaseAllDosKeys(): void {
    if (!this.doomCi) return;
    for (const dosKey of this.pressedDosKeys.keys()) {
      this.doomCi.sendKeyEvent(dosKey, false);
    }
    this.pressedDosKeys.clear();
  }

  private dosKeysForCode(code: string): number[] {
    const primary = CODE_TO_DOS[code];
    if (primary == null) return [];
    if (code === "ArrowUp") return [primary, 87];
    if (code === "ArrowDown") return [primary, 83];
    return [primary];
  }

  private setDosKeyPressed(dosKey: number, pressed: boolean): void {
    if (!this.doomCi) return;
    const count = this.pressedDosKeys.get(dosKey) ?? 0;
    if (pressed) {
      if (count === 0) this.doomCi.sendKeyEvent(dosKey, true);
      this.pressedDosKeys.set(dosKey, count + 1);
      return;
    }
    if (count <= 1) {
      this.pressedDosKeys.delete(dosKey);
      this.doomCi.sendKeyEvent(dosKey, false);
      return;
    }
    this.pressedDosKeys.set(dosKey, count - 1);
  }

  private updateWallFps(now: number): void {
    this.wallFrameCount += 1;
    const elapsed = now - this.wallFpsLastTime;
    if (elapsed >= 1000) {
      this.wallFpsValue = Math.round((this.wallFrameCount * 1000) / elapsed);
      this.wallFrameCount = 0;
      this.wallFpsLastTime = now;
    }
  }

  private updateJsUpdateLoopFps(now: number): void {
    this.jsUpdateFrameCount += 1;
    const elapsed = now - this.jsUpdateFpsLastTime;
    if (elapsed >= 1000) {
      this.jsUpdateFpsValue = Math.round((this.jsUpdateFrameCount * 1000) / elapsed);
      this.jsUpdateFrameCount = 0;
      this.jsUpdateFpsLastTime = now;
    }
  }
}
