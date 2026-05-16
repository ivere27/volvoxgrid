import type { VolvoxGrid } from "../js/src/index.js";

export const STRESS_ROWS = 1_000_000;
export const STRESS_COLS = 12;

export function setupStressDemo(grid: VolvoxGrid, gridId: number): void {
  grid.rawWasm.demo_setup_stress_grid(gridId);
}
