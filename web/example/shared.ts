export type WasmModule = typeof import("./wasm/volvoxgrid_wasm.js");

export type DemoColumnSetup = {
  caption: string;
  key: string;
  width?: number;
  align?: number;
  dataType?: number;
  format?: string;
  progressColor?: number;
  dropdownItems?: string;
  interaction?: number;
  hidden?: boolean;
  span?: boolean;
};

export const DEFAULT_ROW_INDICATOR_WIDTH = 40;
export const DEFAULT_COL_INDICATOR_BAND_ROWS = 1;
export const DEFAULT_FLING_IMPULSE_GAIN = 220.0;
export const DEFAULT_FLING_FRICTION = 0.9;
export const PB_TEXT_DECODER = new TextDecoder();
