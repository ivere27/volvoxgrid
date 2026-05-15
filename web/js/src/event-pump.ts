/**
 * On-demand event pump for the VolvoxGrid wasm runtime.
 *
 * The wasm runtime is synchronous: events queue inside it and are only
 * dispatched to JS when something on the JS side calls a drain function.
 * `EventPump` is the scheduler that decides *when* that drain happens.
 *
 * The pump knows nothing about event payloads or queue shapes — callers pass
 * in a `flush` callback that drains whatever it wants. The pump only
 * coordinates *when* to call it.
 *
 * Scheduling:
 *   - `schedule()` posts to a `MessageChannel`. The `onmessage` handler runs
 *     in the next task tick (~0.5ms in browsers) and calls `flush()`.
 *   - `schedule()` is idempotent within a tick: if a flush is already
 *     scheduled, subsequent calls collapse into the same one. So callers can
 *     spam it from every FFI call / DOM event without burning CPU.
 *   - When the page is hidden (`document.visibilityState === "hidden"`),
 *     `MessageChannel` doesn't auto-throttle the way `requestAnimationFrame`
 *     does, so the pump falls back to a 1Hz `setInterval` to avoid burning
 *     CPU on a background tab while still draining slowly.
 *
 * Idle cost: zero. No `schedule()` call → no `postMessage` → no flush.
 */

export interface EventPumpOptions {
  /**
   * Called when the pump decides it's time to drain. Should pull all queued
   * events out of the wasm runtime and dispatch them. Idempotent: must
   * tolerate being called with nothing pending.
   */
  flush: () => void;

  /**
   * If true (default), the pump installs a `visibilitychange` listener that
   * switches to a slow 1Hz `setInterval` while the document is hidden.
   * Set to false in non-browser hosts (Node, Worker without document).
   */
  visibilityAware?: boolean;
}

export class EventPump {
  private readonly flushFn: () => void;
  private readonly visibilityAware: boolean;
  private readonly channel: MessageChannel | null;
  private scheduled = false;
  private hiddenTimer: ReturnType<typeof setInterval> | null = null;
  private visibilityListener: (() => void) | null = null;
  private closed = false;

  constructor(options: EventPumpOptions) {
    this.flushFn = options.flush;
    this.visibilityAware = options.visibilityAware ?? true;

    this.channel = typeof MessageChannel === "function" ? new MessageChannel() : null;
    if (this.channel != null) {
      this.channel.port1.onmessage = () => {
        this.scheduled = false;
        if (this.closed) return;
        this.runFlush();
      };
    }

    if (this.visibilityAware && typeof document !== "undefined") {
      const listener = () => this.handleVisibilityChange();
      this.visibilityListener = listener;
      document.addEventListener("visibilitychange", listener);
      this.handleVisibilityChange();
    }
  }

  /**
   * Request a drain on the next task tick. Coalesces: multiple calls in the
   * same task produce at most one flush. Safe to call from anywhere
   * (constructors, FFI callbacks, DOM handlers, etc.).
   */
  schedule(): void {
    if (this.closed || this.scheduled) return;
    if (this.channel == null) {
      this.scheduled = true;
      queueMicrotask(() => {
        this.scheduled = false;
        if (this.closed) return;
        this.runFlush();
      });
      return;
    }
    this.scheduled = true;
    this.channel.port2.postMessage(null);
  }

  /** Drain synchronously, right now. Use after an FFI call you want events from before returning to caller. */
  flushNow(): void {
    if (this.closed) return;
    this.runFlush();
  }

  /** Tear down. Idempotent. */
  close(): void {
    if (this.closed) return;
    this.closed = true;
    if (this.channel != null) {
      this.channel.port1.onmessage = null;
      this.channel.port1.close();
      this.channel.port2.close();
    }
    if (this.hiddenTimer != null) {
      clearInterval(this.hiddenTimer);
      this.hiddenTimer = null;
    }
    if (this.visibilityListener != null && typeof document !== "undefined") {
      document.removeEventListener("visibilitychange", this.visibilityListener);
      this.visibilityListener = null;
    }
  }

  private runFlush(): void {
    try {
      this.flushFn();
    } catch (error) {
      console.error("VolvoxGrid EventPump flush failed", error);
    }
  }

  private handleVisibilityChange(): void {
    if (typeof document === "undefined") return;
    if (document.visibilityState === "hidden") {
      if (this.hiddenTimer == null) {
        this.hiddenTimer = setInterval(() => this.runFlush(), 1000);
      }
    } else if (this.hiddenTimer != null) {
      clearInterval(this.hiddenTimer);
      this.hiddenTimer = null;
    }
  }
}
