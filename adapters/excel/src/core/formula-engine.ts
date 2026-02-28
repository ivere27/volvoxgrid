import { colToLetter, letterToCol } from "./cell-reference.js";

export interface FormulaEvalContext {
  getCellValue: (dataRow: number, dataCol: number) => string;
  maxRows: number;
  maxCols: number;
}

export type FormulaRefShift =
  | { kind: "insertRows"; index: number; count: number }
  | { kind: "deleteRows"; index: number; count: number }
  | { kind: "insertCols"; index: number; count: number }
  | { kind: "deleteCols"; index: number; count: number };

interface Token {
  type: "number" | "ref" | "op" | "lparen" | "rparen";
  value: string;
}

interface RectRange {
  start: { row: number; col: number };
  end: { row: number; col: number };
}

interface ParsedCellRef {
  dataRow: number;
  dataCol: number;
  absRow: boolean;
  absCol: boolean;
}

function parseCellRef(ref: string): ParsedCellRef | null {
  const match = ref.toUpperCase().match(/^(\$?)([A-Z]+)(\$?)(\d+)$/);
  if (!match) return null;
  const dataCol = letterToCol(match[2]);
  const dataRow = parseInt(match[4], 10) - 1;
  if (dataRow < 0 || dataCol < 0) return null;
  return {
    dataRow,
    dataCol,
    absCol: match[1] === "$",
    absRow: match[3] === "$",
  };
}

function formatCellRef(dataRow: number, dataCol: number, absRow: boolean, absCol: boolean): string {
  return `${absCol ? "$" : ""}${colToLetter(dataCol)}${absRow ? "$" : ""}${dataRow + 1}`;
}

function asNumber(value: string): number | null {
  const trimmed = value.trim();
  if (trimmed === "") return null;
  const n = Number(trimmed);
  return Number.isFinite(n) ? n : null;
}

function splitArgs(args: string): string[] {
  if (args.trim() === "") return [];
  const out: string[] = [];
  let depth = 0;
  let start = 0;
  let inString = false;
  for (let i = 0; i < args.length; i++) {
    const ch = args[i];
    if (ch === "\"") {
      if (inString && i + 1 < args.length && args[i + 1] === "\"") {
        i++;
        continue;
      }
      inString = !inString;
      continue;
    }
    if (inString) continue;
    if (ch === "(") depth++;
    if (ch === ")") depth = Math.max(0, depth - 1);
    if (ch === "," && depth === 0) {
      out.push(args.slice(start, i).trim());
      start = i + 1;
    }
  }
  out.push(args.slice(start).trim());
  return out;
}

function parseRange(
  arg: string,
  maxRows: number,
  maxCols: number,
): RectRange | null {
  const parts = arg.split(":");
  if (parts.length !== 2) return null;

  const left = parts[0].trim();
  const right = parts[1].trim();

  const aCell = parseCellRef(left);
  const bCell = parseCellRef(right);
  if (aCell && bCell) {
    return {
      start: { row: Math.min(aCell.dataRow, bCell.dataRow), col: Math.min(aCell.dataCol, bCell.dataCol) },
      end: { row: Math.max(aCell.dataRow, bCell.dataRow), col: Math.max(aCell.dataCol, bCell.dataCol) },
    };
  }

  const colMatchA = left.toUpperCase().match(/^\$?([A-Z]+)$/);
  const colMatchB = right.toUpperCase().match(/^\$?([A-Z]+)$/);
  if (colMatchA && colMatchB) {
    const colA = letterToCol(colMatchA[1]);
    const colB = letterToCol(colMatchB[1]);
    return {
      start: { row: 0, col: Math.min(colA, colB) },
      end: { row: Math.max(0, maxRows - 1), col: Math.max(colA, colB) },
    };
  }

  const rowMatchA = left.toUpperCase().match(/^\$?(\d+)$/);
  const rowMatchB = right.toUpperCase().match(/^\$?(\d+)$/);
  if (rowMatchA && rowMatchB) {
    const rowA = parseInt(rowMatchA[1], 10) - 1;
    const rowB = parseInt(rowMatchB[1], 10) - 1;
    return {
      start: { row: Math.min(rowA, rowB), col: 0 },
      end: { row: Math.max(rowA, rowB), col: Math.max(0, maxCols - 1) },
    };
  }

  return null;
}

function tokenize(expr: string): Token[] | null {
  const tokens: Token[] = [];
  let i = 0;
  while (i < expr.length) {
    const ch = expr[i];
    if (/\s/.test(ch)) {
      i++;
      continue;
    }
    if (ch === "(") {
      tokens.push({ type: "lparen", value: ch });
      i++;
      continue;
    }
    if (ch === ")") {
      tokens.push({ type: "rparen", value: ch });
      i++;
      continue;
    }
    if ("+-*/".includes(ch)) {
      tokens.push({ type: "op", value: ch });
      i++;
      continue;
    }

    const rest = expr.slice(i);
    const refMatch = rest.match(/^\$?[A-Za-z]+\$?[0-9]+/);
    if (refMatch) {
      tokens.push({ type: "ref", value: refMatch[0].toUpperCase() });
      i += refMatch[0].length;
      continue;
    }

    const numMatch = rest.match(/^\d+(\.\d+)?/);
    if (numMatch) {
      tokens.push({ type: "number", value: numMatch[0] });
      i += numMatch[0].length;
      continue;
    }

    return null;
  }
  return tokens;
}

class TokenCursor {
  private i = 0;
  constructor(private tokens: Token[]) {}
  peek(): Token | null { return this.tokens[this.i] ?? null; }
  next(): Token | null {
    const t = this.tokens[this.i] ?? null;
    if (t) this.i++;
    return t;
  }
}

export class FormulaEngine {
  static isFormula(text: string): boolean {
    return text.trim().startsWith("=");
  }

  private static hasReferenceBoundaryCollision(
    source: string,
    offset: number,
    wholeLength: number,
  ): boolean {
    const before = offset > 0 ? source[offset - 1] : "";
    const afterIndex = offset + wholeLength;
    const after = afterIndex < source.length ? source[afterIndex] : "";
    return Boolean(
      (before && /[A-Za-z0-9_]/.test(before))
      || (after && /[A-Za-z0-9_]/.test(after)),
    );
  }

  private static shiftReference(
    dataRow: number,
    dataCol: number,
    shift: FormulaRefShift,
  ): { dataRow: number; dataCol: number } | null {
    switch (shift.kind) {
      case "insertRows":
        if (dataRow >= shift.index) dataRow += shift.count;
        break;
      case "deleteRows":
        if (dataRow >= shift.index + shift.count) dataRow -= shift.count;
        else if (dataRow >= shift.index) return null;
        break;
      case "insertCols":
        if (dataCol >= shift.index) dataCol += shift.count;
        break;
      case "deleteCols":
        if (dataCol >= shift.index + shift.count) dataCol -= shift.count;
        else if (dataCol >= shift.index) return null;
        break;
    }
    return { dataRow, dataCol };
  }

  static rewriteReferences(formulaText: string, shift: FormulaRefShift): string {
    if (!FormulaEngine.isFormula(formulaText)) return formulaText;
    if (shift.count <= 0) return formulaText;

    return formulaText.replace(
      /\$?[A-Za-z]+\$?[0-9]+/g,
      (whole, offset: number, source: string) => {
        if (FormulaEngine.hasReferenceBoundaryCollision(source, offset, whole.length)) {
          return whole;
        }

        const parsed = parseCellRef(whole);
        if (!parsed) return whole;
        const shifted = FormulaEngine.shiftReference(parsed.dataRow, parsed.dataCol, shift);
        if (!shifted) return "#REF!";
        return formatCellRef(shifted.dataRow, shifted.dataCol, parsed.absRow, parsed.absCol);
      },
    );
  }

  static rewriteReferencesByOffset(formulaText: string, rowDelta: number, colDelta: number): string {
    if (!FormulaEngine.isFormula(formulaText)) return formulaText;
    if (rowDelta === 0 && colDelta === 0) return formulaText;

    return formulaText.replace(
      /\$?[A-Za-z]+\$?[0-9]+/g,
      (whole, offset: number, source: string) => {
        if (FormulaEngine.hasReferenceBoundaryCollision(source, offset, whole.length)) {
          return whole;
        }

        const parsed = parseCellRef(whole);
        if (!parsed) return whole;
        const nextRow = parsed.dataRow + (parsed.absRow ? 0 : rowDelta);
        const nextCol = parsed.dataCol + (parsed.absCol ? 0 : colDelta);
        if (nextRow < 0 || nextCol < 0) return "#REF!";
        return formatCellRef(nextRow, nextCol, parsed.absRow, parsed.absCol);
      },
    );
  }

  private static isError(value: string): boolean {
    return value.trim().startsWith("#");
  }

  private static parseQuotedString(text: string): string | null {
    const trimmed = text.trim();
    if (trimmed.length >= 2 && trimmed.startsWith("\"") && trimmed.endsWith("\"")) {
      return trimmed.slice(1, -1).replace(/""/g, "\"");
    }
    return null;
  }

  private static parseBooleanLiteral(text: string): "TRUE" | "FALSE" | null {
    const t = text.trim().toUpperCase();
    if (t === "TRUE") return "TRUE";
    if (t === "FALSE") return "FALSE";
    return null;
  }

  private static coerceToBoolean(value: string): boolean | null {
    const parsed = FormulaEngine.parseBooleanLiteral(value);
    if (parsed != null) return parsed === "TRUE";
    const n = asNumber(value.trim());
    if (n != null) return n !== 0;
    if (value.trim() === "") return false;
    return null;
  }

  private static findTopLevelComparator(expr: string): { left: string; op: string; right: string } | null {
    let depth = 0;
    let inString = false;
    for (let i = 0; i < expr.length; i++) {
      const ch = expr[i];
      if (ch === "\"") {
        inString = !inString;
        continue;
      }
      if (inString) continue;
      if (ch === "(") { depth++; continue; }
      if (ch === ")") { depth = Math.max(0, depth - 1); continue; }
      if (depth !== 0) continue;

      const two = expr.slice(i, i + 2);
      if (two === "<=" || two === ">=" || two === "<>") {
        return {
          left: expr.slice(0, i).trim(),
          op: two,
          right: expr.slice(i + 2).trim(),
        };
      }
      if (ch === "=" || ch === "<" || ch === ">") {
        return {
          left: expr.slice(0, i).trim(),
          op: ch,
          right: expr.slice(i + 1).trim(),
        };
      }
    }
    return null;
  }

  private static evaluateScalarExpression(expr: string, ctx: FormulaEvalContext): string {
    const t = expr.trim();
    if (t.length === 0) return "";
    const quoted = FormulaEngine.parseQuotedString(t);
    if (quoted != null) return quoted;
    const bool = FormulaEngine.parseBooleanLiteral(t);
    if (bool != null) return bool;
    if (FormulaEngine.isError(t)) return t;

    const ref = parseCellRef(t);
    if (ref) {
      if (ref.dataRow < 0 || ref.dataCol < 0 || ref.dataRow >= ctx.maxRows || ref.dataCol >= ctx.maxCols) {
        return "#REF!";
      }
      return ctx.getCellValue(ref.dataRow, ref.dataCol);
    }

    if (parseRange(t, ctx.maxRows, ctx.maxCols)) {
      return "#VALUE!";
    }

    const num = asNumber(t);
    if (num != null) return String(num);

    return FormulaEngine.evaluate(`=${t}`, ctx);
  }

  private static compareValues(left: string, right: string, op: string): string {
    const leftNum = asNumber(left.trim());
    const rightNum = asNumber(right.trim());

    let cmp = 0;
    if (leftNum != null && rightNum != null) {
      cmp = leftNum < rightNum ? -1 : leftNum > rightNum ? 1 : 0;
    } else {
      const l = left.toUpperCase();
      const r = right.toUpperCase();
      cmp = l < r ? -1 : l > r ? 1 : 0;
    }

    if (op === "=") return cmp === 0 ? "TRUE" : "FALSE";
    if (op === "<>") return cmp !== 0 ? "TRUE" : "FALSE";
    if (op === "<") return cmp < 0 ? "TRUE" : "FALSE";
    if (op === "<=") return cmp <= 0 ? "TRUE" : "FALSE";
    if (op === ">") return cmp > 0 ? "TRUE" : "FALSE";
    if (op === ">=") return cmp >= 0 ? "TRUE" : "FALSE";
    return "#VALUE!";
  }

  private static valueEquals(left: string, right: string): boolean {
    const leftNum = asNumber(left.trim());
    const rightNum = asNumber(right.trim());
    if (leftNum != null && rightNum != null) {
      return leftNum === rightNum;
    }
    return left.toUpperCase() === right.toUpperCase();
  }

  private static compareOrder(left: string, right: string): number {
    const leftNum = asNumber(left.trim());
    const rightNum = asNumber(right.trim());
    if (leftNum != null && rightNum != null) {
      return leftNum < rightNum ? -1 : leftNum > rightNum ? 1 : 0;
    }
    const l = left.toUpperCase();
    const r = right.toUpperCase();
    return l < r ? -1 : l > r ? 1 : 0;
  }

  private static parseCriteria(criteriaText: string): { op: string; right: string } {
    const trimmed = criteriaText.trim();
    const two = trimmed.slice(0, 2);
    if (two === "<=" || two === ">=" || two === "<>") {
      return { op: two, right: trimmed.slice(2).trim() };
    }
    const one = trimmed.slice(0, 1);
    if (one === "=" || one === "<" || one === ">") {
      return { op: one, right: trimmed.slice(1).trim() };
    }
    return { op: "=", right: trimmed };
  }

  private static hasWildcardPattern(pattern: string): boolean {
    for (let i = 0; i < pattern.length; i++) {
      const ch = pattern[i];
      if (ch === "~") {
        i += 1;
        continue;
      }
      if (ch === "*" || ch === "?") return true;
    }
    return false;
  }

  private static wildcardToRegex(pattern: string): RegExp {
    let out = "^";
    for (let i = 0; i < pattern.length; i++) {
      const ch = pattern[i];
      if (ch === "~" && i + 1 < pattern.length) {
        const next = pattern[i + 1];
        out += next.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
        i += 1;
        continue;
      }
      if (ch === "*") {
        out += ".*";
        continue;
      }
      if (ch === "?") {
        out += ".";
        continue;
      }
      out += ch.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    }
    out += "$";
    return new RegExp(out, "i");
  }

  private static criteriaMatches(value: string, criteriaText: string): boolean {
    const { op, right } = FormulaEngine.parseCriteria(criteriaText);
    const rightNum = asNumber(right.trim());
    if (op === "<" || op === "<=" || op === ">" || op === ">=") {
      if (rightNum != null) {
        const leftNum = asNumber(value.trim());
        if (leftNum == null) return false;
        if (op === "<") return leftNum < rightNum;
        if (op === "<=") return leftNum <= rightNum;
        if (op === ">") return leftNum > rightNum;
        return leftNum >= rightNum;
      }
    }
    const cmp = FormulaEngine.compareOrder(value, right);
    if (op === "=" || op === "<>") {
      if (FormulaEngine.hasWildcardPattern(right)) {
        const matched = FormulaEngine.wildcardToRegex(right).test(value);
        return op === "=" ? matched : !matched;
      }
      const eq = FormulaEngine.valueEquals(value, right);
      return op === "=" ? eq : !eq;
    }
    if (op === "<") return cmp < 0;
    if (op === "<=") return cmp <= 0;
    if (op === ">") return cmp > 0;
    if (op === ">=") return cmp >= 0;
    return false;
  }

  private static rangeShape(
    range: RectRange,
  ): { rows: number; cols: number } {
    return {
      rows: range.end.row - range.start.row + 1,
      cols: range.end.col - range.start.col + 1,
    };
  }

  private static sameRangeShape(
    a: RectRange,
    b: RectRange,
  ): boolean {
    const sa = FormulaEngine.rangeShape(a);
    const sb = FormulaEngine.rangeShape(b);
    return sa.rows === sb.rows && sa.cols === sb.cols;
  }

  private static parseLookupArray(range: RectRange, ctx: FormulaEvalContext): string[] | null {
    const rows = range.end.row - range.start.row + 1;
    const cols = range.end.col - range.start.col + 1;
    if (rows !== 1 && cols !== 1) return null;
    const out: string[] = [];
    if (rows === 1) {
      for (let c = range.start.col; c <= range.end.col; c++) {
        if (c < 0 || c >= ctx.maxCols || range.start.row < 0 || range.start.row >= ctx.maxRows) return null;
        out.push(ctx.getCellValue(range.start.row, c));
      }
    } else {
      for (let r = range.start.row; r <= range.end.row; r++) {
        if (r < 0 || r >= ctx.maxRows || range.start.col < 0 || range.start.col >= ctx.maxCols) return null;
        out.push(ctx.getCellValue(r, range.start.col));
      }
    }
    return out;
  }

  private static parseLookupMode(raw: string): -1 | 0 | 1 | 2 | null {
    const n = asNumber(raw.trim());
    if (n == null) return null;
    const t = Math.trunc(n);
    if (t === -1 || t === 0 || t === 1 || t === 2) return t;
    return null;
  }

  private static parseSearchMode(raw: string): -2 | -1 | 1 | 2 | null {
    const n = asNumber(raw.trim());
    if (n == null) return null;
    const t = Math.trunc(n);
    if (t === -2 || t === -1 || t === 1 || t === 2) return t;
    return null;
  }

  private static buildLookupOrder(length: number, searchMode: -2 | -1 | 1 | 2): number[] {
    const out: number[] = [];
    if (searchMode === -1 || searchMode === -2) {
      for (let i = length - 1; i >= 0; i--) out.push(i);
      return out;
    }
    for (let i = 0; i < length; i++) out.push(i);
    return out;
  }

  private static findLookupIndex(
    values: string[],
    lookup: string,
    matchMode: -1 | 0 | 1 | 2,
    searchMode: -2 | -1 | 1 | 2,
  ): number {
    const order = FormulaEngine.buildLookupOrder(values.length, searchMode);

    if (matchMode === 2) {
      const re = FormulaEngine.wildcardToRegex(lookup);
      for (const idx of order) {
        const v = values[idx];
        if (FormulaEngine.isError(v)) continue;
        if (re.test(v)) return idx;
      }
      return -1;
    }

    // Exact match first for mode 0/-1/1
    for (const idx of order) {
      const v = values[idx];
      if (FormulaEngine.isError(v)) continue;
      if (FormulaEngine.valueEquals(v, lookup)) return idx;
    }
    if (matchMode === 0) return -1;

    // Approximate candidate: nearest smaller (-1) or larger (1)
    let candidate = -1;
    for (let i = 0; i < values.length; i++) {
      const v = values[i];
      if (FormulaEngine.isError(v) || v.trim() === "") continue;
      const cmp = FormulaEngine.compareOrder(v, lookup);
      if (matchMode === -1 && cmp < 0) {
        if (candidate < 0 || FormulaEngine.compareOrder(values[candidate], v) < 0) {
          candidate = i;
        }
      } else if (matchMode === 1 && cmp > 0) {
        if (candidate < 0 || FormulaEngine.compareOrder(values[candidate], v) > 0) {
          candidate = i;
        }
      }
    }
    return candidate;
  }

  private static pad2(n: number): string {
    return String(n).padStart(2, "0");
  }

  private static formatDate(d: Date): string {
    const y = d.getFullYear();
    const m = FormulaEngine.pad2(d.getMonth() + 1);
    const day = FormulaEngine.pad2(d.getDate());
    return `${y}-${m}-${day}`;
  }

  private static formatDateTime(d: Date): string {
    const date = FormulaEngine.formatDate(d);
    const hh = FormulaEngine.pad2(d.getHours());
    const mm = FormulaEngine.pad2(d.getMinutes());
    const ss = FormulaEngine.pad2(d.getSeconds());
    return `${date} ${hh}:${mm}:${ss}`;
  }

  private static parseDateValue(value: string): Date | null {
    const trimmed = value.trim();
    if (trimmed === "") return null;
    const d = new Date(trimmed);
    if (Number.isNaN(d.getTime())) return null;
    return d;
  }

  private static evaluateComparisonExpression(expr: string, ctx: FormulaEvalContext): string | null {
    const cmp = FormulaEngine.findTopLevelComparator(expr);
    if (!cmp) return null;

    const left = FormulaEngine.evaluateScalarExpression(cmp.left, ctx);
    if (FormulaEngine.isError(left)) return left;
    const right = FormulaEngine.evaluateScalarExpression(cmp.right, ctx);
    if (FormulaEngine.isError(right)) return right;
    return FormulaEngine.compareValues(left, right, cmp.op);
  }

  private static evaluateIfCondition(expr: string, ctx: FormulaEvalContext): string {
    const comparison = FormulaEngine.evaluateComparisonExpression(expr, ctx);
    if (comparison != null) return comparison;

    const scalar = FormulaEngine.evaluateScalarExpression(expr, ctx);
    if (FormulaEngine.isError(scalar)) return scalar;
    const b = FormulaEngine.coerceToBoolean(scalar);
    if (b != null) return b ? "TRUE" : "FALSE";
    return "#VALUE!";
  }

  static evaluate(formulaText: string, ctx: FormulaEvalContext): string {
    const raw = formulaText.trim();
    if (!raw.startsWith("=")) return formulaText;
    const body = raw.slice(1).trim();
    if (body.length === 0) return "";

    const upperBody = body.toUpperCase();
    if (upperBody.includes("#REF!")) return "#REF!";
    const quotedTop = FormulaEngine.parseQuotedString(body);
    if (quotedTop != null) return quotedTop;
    const boolTop = FormulaEngine.parseBooleanLiteral(body);
    if (boolTop != null) return boolTop;
    const ref = parseCellRef(body);
    if (ref) {
      if (ref.dataRow < 0 || ref.dataCol < 0 || ref.dataRow >= ctx.maxRows || ref.dataCol >= ctx.maxCols) {
        return "#REF!";
      }
      return ctx.getCellValue(ref.dataRow, ref.dataCol);
    }

    const fnMatch = body.match(/^([A-Za-z][A-Za-z0-9_]*)\((.*)\)$/);
    if (fnMatch) {
      const fn = fnMatch[1].toUpperCase();
      const args = splitArgs(fnMatch[2]);
      const evalArg = (index: number): string => FormulaEngine.evaluateScalarExpression(args[index] ?? "", ctx);

      if (fn === "IF") {
        if (args.length < 2 || args.length > 3) return "#VALUE!";
        const cond = FormulaEngine.evaluateIfCondition(args[0], ctx);
        if (FormulaEngine.isError(cond)) return cond;
        if (cond === "TRUE") {
          return FormulaEngine.evaluateScalarExpression(args[1], ctx);
        }
        if (args.length >= 3) {
          return FormulaEngine.evaluateScalarExpression(args[2], ctx);
        }
        return "FALSE";
      }
      if (fn === "IFERROR") {
        if (args.length !== 2) return "#VALUE!";
        const value = evalArg(0);
        if (FormulaEngine.isError(value)) {
          return evalArg(1);
        }
        return value;
      }
      if (fn === "IFNA") {
        if (args.length !== 2) return "#VALUE!";
        const value = evalArg(0);
        if (value.trim().toUpperCase() === "#N/A") {
          return evalArg(1);
        }
        return value;
      }
      if (fn === "AND") {
        if (args.length < 1) return "#VALUE!";
        for (let i = 0; i < args.length; i++) {
          const v = evalArg(i);
          if (FormulaEngine.isError(v)) return v;
          const b = FormulaEngine.coerceToBoolean(v);
          if (b == null) return "#VALUE!";
          if (!b) return "FALSE";
        }
        return "TRUE";
      }
      if (fn === "OR") {
        if (args.length < 1) return "#VALUE!";
        for (let i = 0; i < args.length; i++) {
          const v = evalArg(i);
          if (FormulaEngine.isError(v)) return v;
          const b = FormulaEngine.coerceToBoolean(v);
          if (b == null) return "#VALUE!";
          if (b) return "TRUE";
        }
        return "FALSE";
      }
      if (fn === "NOT") {
        if (args.length !== 1) return "#VALUE!";
        const v = evalArg(0);
        if (FormulaEngine.isError(v)) return v;
        const b = FormulaEngine.coerceToBoolean(v);
        if (b == null) return "#VALUE!";
        return b ? "FALSE" : "TRUE";
      }
      if (fn === "ABS") {
        if (args.length !== 1) return "#VALUE!";
        const v = evalArg(0);
        if (FormulaEngine.isError(v)) return v;
        const n = asNumber(v.trim());
        if (n == null) return "#VALUE!";
        return String(Math.abs(n));
      }
      if (fn === "ROUND") {
        if (args.length < 1 || args.length > 2) return "#VALUE!";
        const value = evalArg(0);
        if (FormulaEngine.isError(value)) return value;
        const num = asNumber(value.trim());
        if (num == null) return "#VALUE!";

        let digits = 0;
        if (args.length === 2) {
          const d = evalArg(1);
          if (FormulaEngine.isError(d)) return d;
          const parsed = asNumber(d.trim());
          if (parsed == null) return "#VALUE!";
          digits = Math.trunc(parsed);
        }

        const factor = Math.pow(10, digits);
        const scaled = num * factor;
        const sign = scaled < 0 ? -1 : 1;
        const roundedAbs = Math.floor(Math.abs(scaled) + 0.5);
        return String((sign * roundedAbs) / factor);
      }
      if (fn === "LEN") {
        if (args.length !== 1) return "#VALUE!";
        const v = evalArg(0);
        if (FormulaEngine.isError(v)) return v;
        return String(v.length);
      }
      if (fn === "UPPER") {
        if (args.length !== 1) return "#VALUE!";
        const v = evalArg(0);
        if (FormulaEngine.isError(v)) return v;
        return v.toUpperCase();
      }
      if (fn === "LOWER") {
        if (args.length !== 1) return "#VALUE!";
        const v = evalArg(0);
        if (FormulaEngine.isError(v)) return v;
        return v.toLowerCase();
      }
      if (fn === "LEFT") {
        if (args.length < 1 || args.length > 2) return "#VALUE!";
        const text = evalArg(0);
        if (FormulaEngine.isError(text)) return text;
        let count = 1;
        if (args.length === 2) {
          const c = evalArg(1);
          if (FormulaEngine.isError(c)) return c;
          const parsed = asNumber(c.trim());
          if (parsed == null) return "#VALUE!";
          count = Math.trunc(parsed);
        }
        if (count < 0) return "#VALUE!";
        return text.substring(0, count);
      }
      if (fn === "RIGHT") {
        if (args.length < 1 || args.length > 2) return "#VALUE!";
        const text = evalArg(0);
        if (FormulaEngine.isError(text)) return text;
        let count = 1;
        if (args.length === 2) {
          const c = evalArg(1);
          if (FormulaEngine.isError(c)) return c;
          const parsed = asNumber(c.trim());
          if (parsed == null) return "#VALUE!";
          count = Math.trunc(parsed);
        }
        if (count < 0) return "#VALUE!";
        if (count === 0) return "";
        return text.slice(Math.max(0, text.length - count));
      }
      if (fn === "TRIM") {
        if (args.length !== 1) return "#VALUE!";
        const v = evalArg(0);
        if (FormulaEngine.isError(v)) return v;
        return v.trim().replace(/\s+/g, " ");
      }
      if (fn === "CONCATENATE") {
        if (args.length < 1) return "#VALUE!";
        const out: string[] = [];
        for (let i = 0; i < args.length; i++) {
          const v = evalArg(i);
          if (FormulaEngine.isError(v)) return v;
          out.push(v);
        }
        return out.join("");
      }
      if (fn === "CONCAT") {
        if (args.length < 1) return "#VALUE!";
        const out: string[] = [];
        for (let i = 0; i < args.length; i++) {
          const v = evalArg(i);
          if (FormulaEngine.isError(v)) return v;
          out.push(v);
        }
        return out.join("");
      }
      if (fn === "TEXTJOIN") {
        if (args.length < 3) return "#VALUE!";
        const delimiter = evalArg(0);
        if (FormulaEngine.isError(delimiter)) return delimiter;
        const ignoreRaw = evalArg(1);
        if (FormulaEngine.isError(ignoreRaw)) return ignoreRaw;
        const ignoreEmpty = FormulaEngine.coerceToBoolean(ignoreRaw);
        if (ignoreEmpty == null) return "#VALUE!";

        const out: string[] = [];
        for (let i = 2; i < args.length; i++) {
          const range = parseRange(args[i], ctx.maxRows, ctx.maxCols);
          if (range) {
            for (let r = range.start.row; r <= range.end.row; r++) {
              for (let c = range.start.col; c <= range.end.col; c++) {
                if (r < 0 || c < 0 || r >= ctx.maxRows || c >= ctx.maxCols) return "#REF!";
                const v = ctx.getCellValue(r, c);
                if (FormulaEngine.isError(v)) return v;
                if (ignoreEmpty && v === "") continue;
                out.push(v);
              }
            }
            continue;
          }
          const v = evalArg(i);
          if (FormulaEngine.isError(v)) return v;
          if (ignoreEmpty && v === "") continue;
          out.push(v);
        }
        return out.join(delimiter);
      }
      if (fn === "ISBLANK") {
        if (args.length !== 1) return "#VALUE!";
        const v = evalArg(0);
        if (FormulaEngine.isError(v)) return "FALSE";
        return v === "" ? "TRUE" : "FALSE";
      }
      if (fn === "ISNUMBER") {
        if (args.length !== 1) return "#VALUE!";
        const v = evalArg(0);
        if (FormulaEngine.isError(v)) return "FALSE";
        return asNumber(v.trim()) != null ? "TRUE" : "FALSE";
      }
      if (fn === "ISTEXT") {
        if (args.length !== 1) return "#VALUE!";
        const v = evalArg(0);
        if (FormulaEngine.isError(v)) return "FALSE";
        if (v === "") return "FALSE";
        return asNumber(v.trim()) == null ? "TRUE" : "FALSE";
      }
      if (fn === "ISERROR") {
        if (args.length !== 1) return "#VALUE!";
        const v = evalArg(0);
        return FormulaEngine.isError(v) ? "TRUE" : "FALSE";
      }
      if (fn === "TODAY") {
        if (args.length !== 0) return "#VALUE!";
        return FormulaEngine.formatDate(new Date());
      }
      if (fn === "NOW") {
        if (args.length !== 0) return "#VALUE!";
        return FormulaEngine.formatDateTime(new Date());
      }
      if (fn === "DATE") {
        if (args.length !== 3) return "#VALUE!";
        const yRaw = evalArg(0);
        const mRaw = evalArg(1);
        const dRaw = evalArg(2);
        if (FormulaEngine.isError(yRaw)) return yRaw;
        if (FormulaEngine.isError(mRaw)) return mRaw;
        if (FormulaEngine.isError(dRaw)) return dRaw;
        const y = asNumber(yRaw.trim());
        const m = asNumber(mRaw.trim());
        const d = asNumber(dRaw.trim());
        if (y == null || m == null || d == null) return "#VALUE!";
        const date = new Date(Math.trunc(y), Math.trunc(m) - 1, Math.trunc(d));
        if (Number.isNaN(date.getTime())) return "#VALUE!";
        return FormulaEngine.formatDate(date);
      }
      if (fn === "YEAR") {
        if (args.length !== 1) return "#VALUE!";
        const v = evalArg(0);
        if (FormulaEngine.isError(v)) return v;
        const d = FormulaEngine.parseDateValue(v);
        if (!d) return "#VALUE!";
        return String(d.getFullYear());
      }
      if (fn === "MONTH") {
        if (args.length !== 1) return "#VALUE!";
        const v = evalArg(0);
        if (FormulaEngine.isError(v)) return v;
        const d = FormulaEngine.parseDateValue(v);
        if (!d) return "#VALUE!";
        return String(d.getMonth() + 1);
      }
      if (fn === "DAY") {
        if (args.length !== 1) return "#VALUE!";
        const v = evalArg(0);
        if (FormulaEngine.isError(v)) return v;
        const d = FormulaEngine.parseDateValue(v);
        if (!d) return "#VALUE!";
        return String(d.getDate());
      }
      if (fn === "VLOOKUP") {
        if (args.length < 3 || args.length > 4) return "#VALUE!";
        const lookup = evalArg(0);
        if (FormulaEngine.isError(lookup)) return lookup;

        const table = parseRange(args[1], ctx.maxRows, ctx.maxCols);
        if (!table) return "#VALUE!";
        const width = table.end.col - table.start.col + 1;
        if (width <= 0) return "#REF!";

        const colIndexRaw = evalArg(2);
        if (FormulaEngine.isError(colIndexRaw)) return colIndexRaw;
        const colIndexNum = asNumber(colIndexRaw.trim());
        if (colIndexNum == null) return "#VALUE!";
        const colOffset = Math.trunc(colIndexNum) - 1;
        if (colOffset < 0 || colOffset >= width) return "#REF!";

        let exactMode = false;
        if (args.length === 4) {
          const mode = evalArg(3);
          if (FormulaEngine.isError(mode)) return mode;
          const asBool = FormulaEngine.coerceToBoolean(mode);
          if (asBool == null) return "#VALUE!";
          exactMode = !asBool;
        }

        const keyCol = table.start.col;
        const valueCol = table.start.col + colOffset;
        if (exactMode) {
          for (let r = table.start.row; r <= table.end.row; r++) {
            const key = ctx.getCellValue(r, keyCol);
            if (FormulaEngine.isError(key)) continue;
            if (FormulaEngine.valueEquals(key, lookup)) {
              return ctx.getCellValue(r, valueCol);
            }
          }
          return "#N/A";
        }

        // Approximate mode (default): largest key <= lookup in ascending key column.
        let candidateRow = -1;
        for (let r = table.start.row; r <= table.end.row; r++) {
          const key = ctx.getCellValue(r, keyCol);
          if (FormulaEngine.isError(key) || key.trim() === "") continue;
          const cmp = FormulaEngine.compareOrder(key, lookup);
          if (cmp === 0) return ctx.getCellValue(r, valueCol);
          if (cmp < 0) {
            candidateRow = r;
            continue;
          }
          break;
        }
        if (candidateRow >= 0) {
          return ctx.getCellValue(candidateRow, valueCol);
        }
        return "#N/A";
      }

      if (fn === "HLOOKUP") {
        if (args.length < 3 || args.length > 4) return "#VALUE!";
        const lookup = evalArg(0);
        if (FormulaEngine.isError(lookup)) return lookup;

        const table = parseRange(args[1], ctx.maxRows, ctx.maxCols);
        if (!table) return "#VALUE!";
        const height = table.end.row - table.start.row + 1;
        if (height <= 0) return "#REF!";

        const rowIndexRaw = evalArg(2);
        if (FormulaEngine.isError(rowIndexRaw)) return rowIndexRaw;
        const rowIndexNum = asNumber(rowIndexRaw.trim());
        if (rowIndexNum == null) return "#VALUE!";
        const rowOffset = Math.trunc(rowIndexNum) - 1;
        if (rowOffset < 0 || rowOffset >= height) return "#REF!";

        let exactMode = false;
        if (args.length === 4) {
          const mode = evalArg(3);
          if (FormulaEngine.isError(mode)) return mode;
          const asBool = FormulaEngine.coerceToBoolean(mode);
          if (asBool == null) return "#VALUE!";
          exactMode = !asBool;
        }

        const keyRow = table.start.row;
        const valueRow = table.start.row + rowOffset;
        if (exactMode) {
          for (let c = table.start.col; c <= table.end.col; c++) {
            const key = ctx.getCellValue(keyRow, c);
            if (FormulaEngine.isError(key)) continue;
            if (FormulaEngine.valueEquals(key, lookup)) {
              return ctx.getCellValue(valueRow, c);
            }
          }
          return "#N/A";
        }

        // Approximate mode (default): largest key <= lookup in ascending key row.
        let candidateCol = -1;
        for (let c = table.start.col; c <= table.end.col; c++) {
          const key = ctx.getCellValue(keyRow, c);
          if (FormulaEngine.isError(key) || key.trim() === "") continue;
          const cmp = FormulaEngine.compareOrder(key, lookup);
          if (cmp === 0) return ctx.getCellValue(valueRow, c);
          if (cmp < 0) {
            candidateCol = c;
            continue;
          }
          break;
        }
        if (candidateCol >= 0) {
          return ctx.getCellValue(valueRow, candidateCol);
        }
        return "#N/A";
      }

      if (fn === "XLOOKUP") {
        if (args.length < 3 || args.length > 6) return "#VALUE!";
        const lookup = evalArg(0);
        if (FormulaEngine.isError(lookup)) return lookup;

        const lookupRange = parseRange(args[1], ctx.maxRows, ctx.maxCols);
        const returnRange = parseRange(args[2], ctx.maxRows, ctx.maxCols);
        if (!lookupRange || !returnRange) return "#VALUE!";
        const lookupValues = FormulaEngine.parseLookupArray(lookupRange, ctx);
        const returnValues = FormulaEngine.parseLookupArray(returnRange, ctx);
        if (!lookupValues || !returnValues) return "#VALUE!";
        if (lookupValues.length !== returnValues.length) return "#VALUE!";

        let ifNotFound = "#N/A";
        if (args.length >= 4 && args[3] !== "") {
          const nf = evalArg(3);
          if (FormulaEngine.isError(nf)) return nf;
          ifNotFound = nf;
        }

        let matchMode: -1 | 0 | 1 | 2 = 0;
        if (args.length >= 5 && args[4] !== "") {
          const mm = evalArg(4);
          if (FormulaEngine.isError(mm)) return mm;
          const parsed = FormulaEngine.parseLookupMode(mm);
          if (parsed == null) return "#VALUE!";
          matchMode = parsed;
        }

        let searchMode: -2 | -1 | 1 | 2 = 1;
        if (args.length >= 6 && args[5] !== "") {
          const sm = evalArg(5);
          if (FormulaEngine.isError(sm)) return sm;
          const parsed = FormulaEngine.parseSearchMode(sm);
          if (parsed == null) return "#VALUE!";
          searchMode = parsed;
        }

        const idx = FormulaEngine.findLookupIndex(lookupValues, lookup, matchMode, searchMode);
        if (idx < 0) return ifNotFound;
        return returnValues[idx];
      }

      if (fn === "INDEX") {
        if (args.length < 2 || args.length > 3) return "#VALUE!";
        const range = parseRange(args[0], ctx.maxRows, ctx.maxCols);
        if (!range) return "#VALUE!";

        const rowRaw = evalArg(1);
        if (FormulaEngine.isError(rowRaw)) return rowRaw;
        const rowNum = asNumber(rowRaw.trim());
        if (rowNum == null) return "#VALUE!";
        const rowOffset = Math.trunc(rowNum) - 1;
        if (rowOffset < 0) return "#REF!";

        let colOffset = 0;
        if (args.length === 3) {
          const colRaw = evalArg(2);
          if (FormulaEngine.isError(colRaw)) return colRaw;
          const colNum = asNumber(colRaw.trim());
          if (colNum == null) return "#VALUE!";
          colOffset = Math.trunc(colNum) - 1;
        }
        if (colOffset < 0) return "#REF!";

        const rows = range.end.row - range.start.row + 1;
        const cols = range.end.col - range.start.col + 1;
        if (rowOffset >= rows || colOffset >= cols) return "#REF!";
        return ctx.getCellValue(range.start.row + rowOffset, range.start.col + colOffset);
      }

      if (fn === "MATCH") {
        if (args.length < 2 || args.length > 3) return "#VALUE!";
        const lookup = evalArg(0);
        if (FormulaEngine.isError(lookup)) return lookup;

        const range = parseRange(args[1], ctx.maxRows, ctx.maxCols);
        if (!range) return "#VALUE!";
        const rows = range.end.row - range.start.row + 1;
        const cols = range.end.col - range.start.col + 1;
        if (rows !== 1 && cols !== 1) return "#N/A";

        let matchType = 1;
        if (args.length === 3) {
          const modeRaw = evalArg(2);
          if (FormulaEngine.isError(modeRaw)) return modeRaw;
          const modeNum = asNumber(modeRaw.trim());
          if (modeNum == null) return "#VALUE!";
          matchType = modeNum > 0 ? 1 : modeNum < 0 ? -1 : 0;
        }

        const values: string[] = [];
        if (rows === 1) {
          for (let c = range.start.col; c <= range.end.col; c++) {
            values.push(ctx.getCellValue(range.start.row, c));
          }
        } else {
          for (let r = range.start.row; r <= range.end.row; r++) {
            values.push(ctx.getCellValue(r, range.start.col));
          }
        }

        if (matchType === 0) {
          for (let i = 0; i < values.length; i++) {
            const v = values[i];
            if (FormulaEngine.isError(v)) continue;
            if (FormulaEngine.valueEquals(v, lookup)) return String(i + 1);
          }
          return "#N/A";
        }

        if (matchType > 0) {
          let candidate = -1;
          for (let i = 0; i < values.length; i++) {
            const v = values[i];
            if (FormulaEngine.isError(v)) continue;
            const cmp = FormulaEngine.compareOrder(v, lookup);
            if (cmp === 0) return String(i + 1);
            if (cmp < 0) {
              candidate = i;
              continue;
            }
            break;
          }
          return candidate >= 0 ? String(candidate + 1) : "#N/A";
        }

        let candidate = -1;
        for (let i = 0; i < values.length; i++) {
          const v = values[i];
          if (FormulaEngine.isError(v)) continue;
          const cmp = FormulaEngine.compareOrder(v, lookup);
          if (cmp === 0) return String(i + 1);
          if (cmp > 0) {
            candidate = i;
            continue;
          }
          break;
        }
        return candidate >= 0 ? String(candidate + 1) : "#N/A";
      }

      if (fn === "XMATCH") {
        if (args.length < 2 || args.length > 4) return "#VALUE!";
        const lookup = evalArg(0);
        if (FormulaEngine.isError(lookup)) return lookup;

        const range = parseRange(args[1], ctx.maxRows, ctx.maxCols);
        if (!range) return "#VALUE!";
        const lookupValues = FormulaEngine.parseLookupArray(range, ctx);
        if (!lookupValues) return "#N/A";

        let matchMode: -1 | 0 | 1 | 2 = 0;
        if (args.length >= 3 && args[2] !== "") {
          const mm = evalArg(2);
          if (FormulaEngine.isError(mm)) return mm;
          const parsed = FormulaEngine.parseLookupMode(mm);
          if (parsed == null) return "#VALUE!";
          matchMode = parsed;
        }

        let searchMode: -2 | -1 | 1 | 2 = 1;
        if (args.length >= 4 && args[3] !== "") {
          const sm = evalArg(3);
          if (FormulaEngine.isError(sm)) return sm;
          const parsed = FormulaEngine.parseSearchMode(sm);
          if (parsed == null) return "#VALUE!";
          searchMode = parsed;
        }

        const idx = FormulaEngine.findLookupIndex(lookupValues, lookup, matchMode, searchMode);
        if (idx < 0) return "#N/A";
        return String(idx + 1);
      }

      if (fn === "COUNTA") {
        if (args.length < 1) return "#VALUE!";
        let count = 0;
        for (const arg of args) {
          const range = parseRange(arg, ctx.maxRows, ctx.maxCols);
          if (range) {
            for (let r = range.start.row; r <= range.end.row; r++) {
              for (let c = range.start.col; c <= range.end.col; c++) {
                if (r < 0 || c < 0 || r >= ctx.maxRows || c >= ctx.maxCols) return "#REF!";
                if (ctx.getCellValue(r, c) !== "") count++;
              }
            }
            continue;
          }

          const singleRef = parseCellRef(arg);
          if (singleRef) {
            if (singleRef.dataRow < 0 || singleRef.dataCol < 0
              || singleRef.dataRow >= ctx.maxRows || singleRef.dataCol >= ctx.maxCols) return "#REF!";
            if (ctx.getCellValue(singleRef.dataRow, singleRef.dataCol) !== "") count++;
            continue;
          }

          const scalar = FormulaEngine.evaluateScalarExpression(arg, ctx);
          if (FormulaEngine.isError(scalar)) return scalar;
          if (scalar !== "") count++;
        }
        return String(count);
      }

      if (fn === "COUNTIF") {
        if (args.length !== 2) return "#VALUE!";
        const range = parseRange(args[0], ctx.maxRows, ctx.maxCols);
        if (!range) return "#VALUE!";
        const criteria = evalArg(1);
        if (FormulaEngine.isError(criteria)) return criteria;

        let count = 0;
        for (let r = range.start.row; r <= range.end.row; r++) {
          for (let c = range.start.col; c <= range.end.col; c++) {
            if (r < 0 || c < 0 || r >= ctx.maxRows || c >= ctx.maxCols) return "#REF!";
            const value = ctx.getCellValue(r, c);
            if (FormulaEngine.criteriaMatches(value, criteria)) count++;
          }
        }
        return String(count);
      }

      if (fn === "SUMIF") {
        if (args.length < 2 || args.length > 3) return "#VALUE!";
        const range = parseRange(args[0], ctx.maxRows, ctx.maxCols);
        if (!range) return "#VALUE!";
        const criteria = evalArg(1);
        if (FormulaEngine.isError(criteria)) return criteria;

        const sumRange = args.length === 3
          ? parseRange(args[2], ctx.maxRows, ctx.maxCols)
          : range;
        if (!sumRange) return "#VALUE!";

        let sum = 0;
        for (let r = range.start.row; r <= range.end.row; r++) {
          for (let c = range.start.col; c <= range.end.col; c++) {
            if (r < 0 || c < 0 || r >= ctx.maxRows || c >= ctx.maxCols) return "#REF!";
            const sr = sumRange.start.row + (r - range.start.row);
            const sc = sumRange.start.col + (c - range.start.col);
            if (sr < 0 || sc < 0 || sr >= ctx.maxRows || sc >= ctx.maxCols) return "#REF!";
            if (sr > sumRange.end.row || sc > sumRange.end.col) return "#VALUE!";

            const value = ctx.getCellValue(r, c);
            if (!FormulaEngine.criteriaMatches(value, criteria)) continue;

            const sumCell = ctx.getCellValue(sr, sc).trim();
            if (sumCell.startsWith("#")) return sumCell;
            const n = asNumber(sumCell);
            if (n != null) sum += n;
          }
        }
        return String(sum);
      }

      if (fn === "AVERAGEIF") {
        if (args.length < 2 || args.length > 3) return "#VALUE!";
        const range = parseRange(args[0], ctx.maxRows, ctx.maxCols);
        if (!range) return "#VALUE!";
        const criteria = evalArg(1);
        if (FormulaEngine.isError(criteria)) return criteria;

        const avgRange = args.length === 3
          ? parseRange(args[2], ctx.maxRows, ctx.maxCols)
          : range;
        if (!avgRange) return "#VALUE!";

        let sum = 0;
        let count = 0;
        for (let r = range.start.row; r <= range.end.row; r++) {
          for (let c = range.start.col; c <= range.end.col; c++) {
            if (r < 0 || c < 0 || r >= ctx.maxRows || c >= ctx.maxCols) return "#REF!";
            const ar = avgRange.start.row + (r - range.start.row);
            const ac = avgRange.start.col + (c - range.start.col);
            if (ar < 0 || ac < 0 || ar >= ctx.maxRows || ac >= ctx.maxCols) return "#REF!";
            if (ar > avgRange.end.row || ac > avgRange.end.col) return "#VALUE!";

            const value = ctx.getCellValue(r, c);
            if (!FormulaEngine.criteriaMatches(value, criteria)) continue;

            const avgCell = ctx.getCellValue(ar, ac).trim();
            if (avgCell.startsWith("#")) return avgCell;
            const n = asNumber(avgCell);
            if (n != null) {
              sum += n;
              count++;
            }
          }
        }
        if (count === 0) return "#DIV/0!";
        return String(sum / count);
      }

      if (fn === "COUNTIFS") {
        if (args.length < 2 || args.length % 2 !== 0) return "#VALUE!";
        const pairs: Array<{
          range: { start: { row: number; col: number }; end: { row: number; col: number } };
          criteria: string;
        }> = [];
        let baseRange: { start: { row: number; col: number }; end: { row: number; col: number } } | null = null;

        for (let i = 0; i < args.length; i += 2) {
          const range = parseRange(args[i], ctx.maxRows, ctx.maxCols);
          if (!range) return "#VALUE!";
          const criteria = evalArg(i + 1);
          if (FormulaEngine.isError(criteria)) return criteria;
          if (baseRange == null) baseRange = range;
          else if (!FormulaEngine.sameRangeShape(baseRange, range)) return "#VALUE!";
          pairs.push({ range, criteria });
        }
        if (!baseRange) return "#VALUE!";

        const shape = FormulaEngine.rangeShape(baseRange);
        let count = 0;
        for (let dr = 0; dr < shape.rows; dr++) {
          for (let dc = 0; dc < shape.cols; dc++) {
            let matched = true;
            for (const pair of pairs) {
              const rr = pair.range.start.row + dr;
              const cc = pair.range.start.col + dc;
              if (rr < 0 || cc < 0 || rr >= ctx.maxRows || cc >= ctx.maxCols) return "#REF!";
              const value = ctx.getCellValue(rr, cc);
              if (!FormulaEngine.criteriaMatches(value, pair.criteria)) {
                matched = false;
                break;
              }
            }
            if (matched) count++;
          }
        }
        return String(count);
      }

      if (fn === "SUMIFS") {
        if (args.length < 3 || args.length % 2 === 0) return "#VALUE!";
        const sumRange = parseRange(args[0], ctx.maxRows, ctx.maxCols);
        if (!sumRange) return "#VALUE!";

        const pairs: Array<{
          range: { start: { row: number; col: number }; end: { row: number; col: number } };
          criteria: string;
        }> = [];
        for (let i = 1; i < args.length; i += 2) {
          const range = parseRange(args[i], ctx.maxRows, ctx.maxCols);
          if (!range) return "#VALUE!";
          if (!FormulaEngine.sameRangeShape(sumRange, range)) return "#VALUE!";
          const criteria = evalArg(i + 1);
          if (FormulaEngine.isError(criteria)) return criteria;
          pairs.push({ range, criteria });
        }

        const shape = FormulaEngine.rangeShape(sumRange);
        let sum = 0;
        for (let dr = 0; dr < shape.rows; dr++) {
          for (let dc = 0; dc < shape.cols; dc++) {
            const sr = sumRange.start.row + dr;
            const sc = sumRange.start.col + dc;
            if (sr < 0 || sc < 0 || sr >= ctx.maxRows || sc >= ctx.maxCols) return "#REF!";

            let matched = true;
            for (const pair of pairs) {
              const rr = pair.range.start.row + dr;
              const cc = pair.range.start.col + dc;
              if (rr < 0 || cc < 0 || rr >= ctx.maxRows || cc >= ctx.maxCols) return "#REF!";
              const value = ctx.getCellValue(rr, cc);
              if (!FormulaEngine.criteriaMatches(value, pair.criteria)) {
                matched = false;
                break;
              }
            }
            if (!matched) continue;

            const sumCell = ctx.getCellValue(sr, sc).trim();
            if (sumCell.startsWith("#")) return sumCell;
            const n = asNumber(sumCell);
            if (n != null) sum += n;
          }
        }
        return String(sum);
      }

      if (fn === "SUMPRODUCT") {
        if (args.length < 1) return "#VALUE!";
        const arrays: number[][] = [];
        let baseRows = 0;
        let baseCols = 0;

        for (const arg of args) {
          const range = parseRange(arg, ctx.maxRows, ctx.maxCols);
          if (range) {
            const rows = range.end.row - range.start.row + 1;
            const cols = range.end.col - range.start.col + 1;
            if (rows <= 0 || cols <= 0) return "#VALUE!";
            if (baseRows === 0 && baseCols === 0) {
              baseRows = rows;
              baseCols = cols;
            } else if (baseRows !== rows || baseCols !== cols) {
              return "#VALUE!";
            }

            const values: number[] = [];
            for (let r = range.start.row; r <= range.end.row; r++) {
              for (let c = range.start.col; c <= range.end.col; c++) {
                if (r < 0 || c < 0 || r >= ctx.maxRows || c >= ctx.maxCols) return "#REF!";
                const v = ctx.getCellValue(r, c).trim();
                if (v.startsWith("#")) return v;
                const n = asNumber(v);
                values.push(n != null ? n : 0);
              }
            }
            arrays.push(values);
            continue;
          }

          const singleRef = parseCellRef(arg);
          if (singleRef) {
            if (singleRef.dataRow < 0 || singleRef.dataCol < 0
              || singleRef.dataRow >= ctx.maxRows || singleRef.dataCol >= ctx.maxCols) return "#REF!";
            if (baseRows === 0 && baseCols === 0) {
              baseRows = 1;
              baseCols = 1;
            } else if (baseRows !== 1 || baseCols !== 1) {
              return "#VALUE!";
            }
            const v = ctx.getCellValue(singleRef.dataRow, singleRef.dataCol).trim();
            if (v.startsWith("#")) return v;
            const n = asNumber(v);
            arrays.push([n != null ? n : 0]);
            continue;
          }

          const scalar = FormulaEngine.evaluateScalarExpression(arg, ctx);
          if (FormulaEngine.isError(scalar)) return scalar;
          if (baseRows === 0 && baseCols === 0) {
            baseRows = 1;
            baseCols = 1;
          } else if (baseRows !== 1 || baseCols !== 1) {
            return "#VALUE!";
          }
          const n = asNumber(scalar.trim());
          arrays.push([n != null ? n : 0]);
        }

        const len = baseRows * baseCols;
        let sum = 0;
        for (let i = 0; i < len; i++) {
          let prod = 1;
          for (const arr of arrays) {
            prod *= arr[i] ?? 0;
          }
          sum += prod;
        }
        return String(sum);
      }

      const values: number[] = [];

      for (const arg of args) {
        const range = parseRange(arg, ctx.maxRows, ctx.maxCols);
        if (range) {
          for (let r = range.start.row; r <= range.end.row; r++) {
            for (let c = range.start.col; c <= range.end.col; c++) {
              if (r < 0 || c < 0 || r >= ctx.maxRows || c >= ctx.maxCols) return "#REF!";
              const cellValue = ctx.getCellValue(r, c).trim();
              if (cellValue.startsWith("#")) return cellValue;
              const n = asNumber(cellValue);
              if (n != null) values.push(n);
            }
          }
          continue;
        }

        const singleRef = parseCellRef(arg);
        if (singleRef) {
          if (singleRef.dataRow < 0 || singleRef.dataCol < 0
            || singleRef.dataRow >= ctx.maxRows || singleRef.dataCol >= ctx.maxCols) return "#REF!";
          const cellValue = ctx.getCellValue(singleRef.dataRow, singleRef.dataCol).trim();
          if (cellValue.startsWith("#")) return cellValue;
          const n = asNumber(cellValue);
          if (n != null) values.push(n);
          continue;
        }

        const n = asNumber(arg);
        if (n != null) {
          values.push(n);
          continue;
        }
        const evaluated = FormulaEngine.evaluateScalarExpression(arg, ctx);
        if (FormulaEngine.isError(evaluated)) return evaluated;
        const n2 = asNumber(evaluated.trim());
        if (n2 != null) {
          values.push(n2);
          continue;
        }
        return "#VALUE!";
      }

      if (fn === "SUM") {
        return String(values.reduce((acc, v) => acc + v, 0));
      }
      if (fn === "AVERAGE") {
        if (values.length === 0) return "0";
        return String(values.reduce((acc, v) => acc + v, 0) / values.length);
      }
      if (fn === "MIN") {
        if (values.length === 0) return "0";
        return String(Math.min(...values));
      }
      if (fn === "MAX") {
        if (values.length === 0) return "0";
        return String(Math.max(...values));
      }
      if (fn === "COUNT") {
        return String(values.length);
      }
      return "#NAME?";
    }

    const comparison = FormulaEngine.evaluateComparisonExpression(upperBody, ctx);
    if (comparison != null) {
      return comparison;
    }

    const tokens = tokenize(upperBody);
    if (!tokens || tokens.length === 0) {
      return "#VALUE!";
    }
    const cursor = new TokenCursor(tokens);

    const parseFactor = (): number | null => {
      const tok = cursor.peek();
      if (!tok) return null;
      if (tok.type === "op" && (tok.value === "+" || tok.value === "-")) {
        cursor.next();
        const v = parseFactor();
        if (v == null) return null;
        return tok.value === "-" ? -v : v;
      }
      if (tok.type === "number") {
        cursor.next();
        return Number(tok.value);
      }
      if (tok.type === "ref") {
        cursor.next();
        const parsed = parseCellRef(tok.value);
        if (!parsed) return null;
        if (parsed.dataRow < 0 || parsed.dataCol < 0
          || parsed.dataRow >= ctx.maxRows || parsed.dataCol >= ctx.maxCols) {
          throw new Error("#REF!");
        }
        const cellValue = ctx.getCellValue(parsed.dataRow, parsed.dataCol).trim();
        if (cellValue.startsWith("#")) {
          throw new Error(cellValue);
        }
        if (cellValue === "") return 0;
        const n = asNumber(cellValue);
        if (n != null) return n;
        throw new Error("#VALUE!");
      }
      if (tok.type === "lparen") {
        cursor.next();
        const inner = parseExpr();
        if (cursor.peek()?.type !== "rparen") return null;
        cursor.next();
        return inner;
      }
      return null;
    };

    const parseTerm = (): number | null => {
      let left = parseFactor();
      if (left == null) return null;
      while (true) {
        const op = cursor.peek();
        if (!op || op.type !== "op" || (op.value !== "*" && op.value !== "/")) break;
        cursor.next();
        const right = parseFactor();
        if (right == null) return null;
        if (op.value === "*") {
          left *= right;
        } else {
          if (right === 0) throw new Error("#DIV/0!");
          left /= right;
        }
      }
      return left;
    };

    const parseExpr = (): number | null => {
      let left = parseTerm();
      if (left == null) return null;
      while (true) {
        const op = cursor.peek();
        if (!op || op.type !== "op" || (op.value !== "+" && op.value !== "-")) break;
        cursor.next();
        const right = parseTerm();
        if (right == null) return null;
        if (op.value === "+") left += right;
        else left -= right;
      }
      return left;
    };

    try {
      const value = parseExpr();
      if (value == null || cursor.peek() != null || !Number.isFinite(value)) return "#VALUE!";
      return String(value);
    } catch (err) {
      if (err instanceof Error && err.message.startsWith("#")) {
        return err.message;
      }
      return "#VALUE!";
    }
  }
}
