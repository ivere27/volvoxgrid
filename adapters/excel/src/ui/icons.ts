/**
 * Material Icons icon helper.
 *
 * Uses the bundled .ttf font declared via @font-face in volvox-excel.css.
 * Icons are rendered as ligature text: the span's textContent is the
 * Material Icons ligature name (e.g. "undo", "format_bold").
 */

/** Create a Material Icons icon <span> element. */
export function iconEl(name: string, size = 18): HTMLSpanElement {
  const span = document.createElement("span");
  span.className = "vx-icon";
  span.textContent = name;
  if (size !== 18) {
    span.style.fontSize = `${size}px`;
  }
  return span;
}

/** Return an HTML string for a Material Icons icon (for innerHTML use). */
export function iconHtml(name: string, size = 18): string {
  const style = size !== 18 ? ` style="font-size:${size}px"` : "";
  return `<span class="vx-icon"${style}>${name}</span>`;
}
