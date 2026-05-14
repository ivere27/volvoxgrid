export interface BrowserFontFallbackOptions {
  fontFallbacksEnabled?: boolean;
  wasm?: {
    browser_font_fallback_families?: (locales: string[]) => unknown;
  } | null;
}

export function quoteFontFamily(fontName: string): string {
  return `"${fontName.replace(/\\/g, '\\\\').replace(/"/g, '\\"')}"`;
}

const CSS_GENERIC_FAMILIES = new Set([
  'serif',
  'sans-serif',
  'monospace',
  'cursive',
  'fantasy',
  'system-ui',
  'ui-serif',
  'ui-sans-serif',
  'ui-monospace',
  'ui-rounded',
  'emoji',
  'math',
  'fangsong',
  '-apple-system',
]);

const GENERIC_BROWSER_FALLBACK_FAMILIES = [
  'system-ui',
  '-apple-system',
  'Segoe UI',
  'Noto Sans',
  'Arial',
  'sans-serif',
];

let warnedMissingWasmFallbackApi = false;

function formatFontFamily(fontName: string): string {
  return CSS_GENERIC_FAMILIES.has(fontName) ? fontName : quoteFontFamily(fontName);
}

export function browserLocaleHints(): string[] {
  if (typeof navigator === 'undefined') {
    return [];
  }
  const locales = Array.isArray(navigator.languages) && navigator.languages.length > 0
    ? navigator.languages
    : [navigator.language];
  return locales
    .map((value) => value?.trim())
    .filter((value): value is string => typeof value === 'string' && value.length > 0);
}

function fallbackFamiliesFromWasm(
  wasm: BrowserFontFallbackOptions['wasm'],
  locales: string[],
): string[] | null {
  if (typeof wasm?.browser_font_fallback_families !== 'function') {
    if (wasm != null && !warnedMissingWasmFallbackApi) {
      warnedMissingWasmFallbackApi = true;
      console.warn('WASM browser font fallback API is unavailable; using generic CSS fallback stack');
    }
    return null;
  }
  try {
    return Array.from(wasm.browser_font_fallback_families(locales) as ArrayLike<unknown>)
      .map((family) => String(family).trim())
      .filter((family) => family.length > 0);
  } catch (err) {
    if (!warnedMissingWasmFallbackApi) {
      warnedMissingWasmFallbackApi = true;
      console.warn('Could not read browser font fallback families from WASM:', err);
    }
    return null;
  }
}

export function browserFontFallbackStack(options: BrowserFontFallbackOptions = {}): string {
  if (options.fontFallbacksEnabled === false) {
    return 'sans-serif';
  }
  const locales = browserLocaleHints();
  const families = fallbackFamiliesFromWasm(options.wasm, locales)
    ?? GENERIC_BROWSER_FALLBACK_FAMILIES;
  return families.map(formatFontFamily).join(', ');
}
