/**
 * A1-style cell reference utilities.
 *
 * Column 0 → "A", column 25 → "Z", column 26 → "AA", etc.
 * Row 0 is the header row, so data rows start at 1 → displayed as "1".
 */

/** Convert a 0-based column index to a column letter (A, B, ..., Z, AA, AB, ...). */
export function colToLetter(col: number): string {
  let result = "";
  let c = col;
  while (c >= 0) {
    result = String.fromCharCode((c % 26) + 65) + result;
    c = Math.floor(c / 26) - 1;
  }
  return result;
}

/** Convert a column letter (A, AA, etc.) to a 0-based column index. */
export function letterToCol(letter: string): number {
  let col = 0;
  const upper = letter.toUpperCase();
  for (let i = 0; i < upper.length; i++) {
    col = col * 26 + (upper.charCodeAt(i) - 64);
  }
  return col - 1;
}

/**
 * Convert (row, col) in data space to an A1 reference.
 * dataRow is 0-based (data row 0 = display "1"), dataCol is 0-based.
 */
export function toA1(dataRow: number, dataCol: number): string {
  return colToLetter(dataCol) + (dataRow + 1);
}

/**
 * Parse an A1 reference into { dataRow, dataCol }.
 * Returns null if the reference is invalid.
 */
export function fromA1(ref: string): { dataRow: number; dataCol: number } | null {
  const match = ref.toUpperCase().match(/^(?:\$)?([A-Z]+)(?:\$)?(\d+)$/);
  if (!match) return null;
  const dataCol = letterToCol(match[1]);
  const dataRow = parseInt(match[2], 10) - 1;
  if (dataRow < 0 || dataCol < 0) return null;
  return { dataRow, dataCol };
}

/**
 * Generate column header labels: A, B, C, ..., Z, AA, AB, ...
 */
export function generateColumnHeaders(count: number): string[] {
  const headers: string[] = [];
  for (let i = 0; i < count; i++) {
    headers.push(colToLetter(i));
  }
  return headers;
}

/**
 * Generate row number labels: 1, 2, 3, ...
 */
export function generateRowNumbers(count: number): string[] {
  const labels: string[] = [];
  for (let i = 0; i < count; i++) {
    labels.push(String(i + 1));
  }
  return labels;
}
