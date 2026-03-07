import React, { useState, useEffect, useRef } from 'react';
import Editor from '@monaco-editor/react';
import jsYaml from 'js-yaml';
import { VolvoxGrid } from 'volvoxgrid';
import { FileText, Download, Layers } from 'lucide-react';

type CanonicalVolvoxGrid = VolvoxGrid & {
  rowCount: number;
  colCount: number;
  frozenRowCount: number;
  frozenColCount: number;
  setCellText(row: number, col: number, text: string): void;
};

const FONT_FETCH_TIMEOUT_MS = 3000;
const FONT_URL_CANDIDATES = [
  "https://cdn.jsdelivr.net/gh/googlefonts/roboto-2@main/src/hinted/Roboto-Regular.ttf",
  "https://fonts.gstatic.com/s/roboto/v30/KFOmCnqEu92Fr1Mu4mxP.ttf",
];

const INITIAL_YAML = `name: "Sales Report Prototype"
page:
  size: "A4"
  margins: [30, 30, 30, 30]
bands:
  - type: "header"
    height: 40
    style: { back_color: "#2c3e50", fore_color: "#ffffff", bold: true }
    cells:
      - { text: "PRODUCT", width: 300 }
      - { text: "QTY", width: 100, align: "right" }
      - { text: "UNIT PRICE", width: 150, align: "right" }
      - { text: "TOTAL", width: 150, align: "right" }
  - type: "detail"
    height: 30
    count: 5
    cells:
      - { text: "Volvox Engine Pro {i}", width: 300 }
      - { text: "{i*10}", width: 100, align: "right" }
      - { text: "499.00", width: 150, align: "right" }
      - { text: "4990.00", width: 150, align: "right" }
`;

async function fetchFontWithTimeout(url: string): Promise<Uint8Array | null> {
  const ctrl = new AbortController();
  const timer = window.setTimeout(() => ctrl.abort(), FONT_FETCH_TIMEOUT_MS);
  try {
    const resp = await fetch(url, { signal: ctrl.signal });
    if (!resp.ok) {
      return null;
    }
    return new Uint8Array(await resp.arrayBuffer());
  } catch {
    return null;
  } finally {
    window.clearTimeout(timer);
  }
}

async function loadEngineFont(wasmModule: any): Promise<boolean> {
  if (typeof wasmModule.load_font !== "function") {
    return false;
  }

  for (const fontUrl of FONT_URL_CANDIDATES) {
    const fontData = await fetchFontWithTimeout(fontUrl);
    if (!fontData || fontData.length === 0) {
      continue;
    }
    wasmModule.load_font(fontData);
    return true;
  }
  return false;
}

function getPngDimensions(bytes: Uint8Array): { width: number; height: number } | null {
  // PNG header + IHDR chunk width/height fields.
  if (bytes.length < 24) {
    return null;
  }
  const pngSignature = [137, 80, 78, 71, 13, 10, 26, 10];
  for (let i = 0; i < pngSignature.length; i++) {
    if (bytes[i] !== pngSignature[i]) {
      return null;
    }
  }
  if (
    bytes[12] !== 73 || // I
    bytes[13] !== 72 || // H
    bytes[14] !== 68 || // D
    bytes[15] !== 82 // R
  ) {
    return null;
  }
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const width = view.getUint32(16, false);
  const height = view.getUint32(20, false);
  return { width, height };
}

const HIDDEN_CANVAS_STYLE: React.CSSProperties = {
  position: 'absolute',
  left: '-10000px',
  top: '-10000px',
  width: '1024px',
  height: '1024px',
  opacity: 0,
  pointerEvents: 'none',
};

export default function App() {
  const [yaml, setYaml] = useState(INITIAL_YAML);
  const gridRef = useRef<CanonicalVolvoxGrid | null>(null);
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [lastExport, setLastExport] = useState<string | null>(null);
  const [isReady, setIsReady] = useState(false);
  const setExportImage = (imageData: Uint8Array) => {
    const bytes = new Uint8Array(imageData.byteLength);
    bytes.set(imageData);
    const blob = new Blob([bytes], { type: 'image/png' });
    const nextUrl = URL.createObjectURL(blob);
    setLastExport((prev) => {
      if (prev) URL.revokeObjectURL(prev);
      return nextUrl;
    });
  };

  // Initialize WASM and VolvoxGrid manually
  useEffect(() => {
    let destroyed = false;
    async function init() {
      if (!canvasRef.current) return;
      try {
        console.log("Waiting for WASM from index.html...");
        
        // Wait for index.html script to load WASM
        let attempts = 0;
        while (!(window as any).volvoxWasm && attempts < 50) {
          await new Promise(r => setTimeout(r, 100));
          attempts++;
        }

        const wasmInit = (window as any).volvoxWasmInit;
        const wasmModule = (window as any).volvoxWasm;

        if (!wasmInit || !wasmModule) {
          throw new Error("WASM not loaded from index.html");
        }

        await wasmInit();
        
        if (destroyed) return;

        const fontLoaded = await loadEngineFont(wasmModule);
        if (!fontLoaded) {
          console.warn("Could not load a report font. Text may be missing in output.");
        }
        if (destroyed) return;

        if (typeof wasmModule.init_v1_plugin === "function") {
          wasmModule.init_v1_plugin();
        }

        const grid = new VolvoxGrid(canvasRef.current, wasmModule, 100, 10) as CanonicalVolvoxGrid;
        if (fontLoaded && typeof (grid as any).setFontName === "function") {
          (grid as any).setFontName("Roboto");
        }
        gridRef.current = grid;
        setIsReady(true);
        console.log("VolvoxGrid Ready");
      } catch (e) {
        console.error("WASM Init Failed:", e);
        setError("Failed to load Volvox Engine: " + e);
      }
    }
    init();
    
    return () => {
      destroyed = true;
      if (gridRef.current) {
        gridRef.current.destroy();
        gridRef.current = null;
      }
    };
  }, []);

  useEffect(() => {
    return () => {
      if (lastExport) URL.revokeObjectURL(lastExport);
    };
  }, [lastExport]);

  // Apply YAML to Grid and Auto-Export
  const applyReport = async (yamlText: string) => {
    const grid = gridRef.current;
    if (!grid) return;

    try {
      const config = jsYaml.load(yamlText) as any;
      setError(null);

      grid.setRedraw(false);
      grid.rowCount = 0;
      grid.rowCount = 100;
      
      let currentRow = 0;
      for (const band of config.bands || []) {
        const count = band.count || 1;
        for (let i = 0; i < count; i++) {
          if (currentRow >= 100) break;
          grid.setRowHeight(currentRow, band.height || 30);
          let currentCol = 0;
          for (const cell of band.cells || []) {
            let text = (cell.text || "").replace("{i}", (i + 1).toString());
            grid.setCellText(currentRow, currentCol, text);
            if (cell.width) grid.setColWidth(currentCol, cell.width);
            
            if (band.style || cell.style) {
              const s = { ...(band.style || {}), ...(cell.style || {}) };
              grid.setCellStyleOverride(currentRow, currentCol, {
                backColor: s.back_color ? parseInt(s.back_color.replace("#", "0xFF"), 16) : undefined,
                foreColor: s.fore_color ? parseInt(s.fore_color.replace("#", "0xFF"), 16) : undefined,
                fontBold: s.bold,
                alignment: s.align === "right" ? 2 : (s.align === "center" ? 1 : 0),
              });
            }
            currentCol++;
          }
          currentRow++;
        }
      }
      grid.setRedraw(true);
      grid.refresh();
      (grid as any).ensureLayout();

      console.log("Grid state for print:", {
        rowCount: grid.rowCount,
        colCount: grid.colCount,
        frozenRowCount: grid.frozenRowCount,
        frozenColCount: grid.frozenColCount,
      });

      // AUTO-EXPORT (prefer print pipeline; fallback to viewport capture)
      let exported = false;
      if (typeof (grid as any).printGrid === "function") {
        console.log("Calling printGrid...");
        const pages = await (grid as any).printGrid({
          header: config.page?.header || "",
          footer: config.page?.footer || "",
          showPageNumbers: true
        });

        console.log("printGrid returned:", pages?.length, "pages");

        if (pages && pages.length > 0 && pages[0]?.imageData instanceof Uint8Array && pages[0].imageData.length > 0) {
          setExportImage(pages[0].imageData);
          exported = true;
        } else {
          console.warn("No pages returned from engine. Check if grid has data/rows.");
        }
      }

      if (!exported && typeof (grid as any).getPicture === "function") {
        const image = (grid as any).getPicture() as Uint8Array;
        if (image instanceof Uint8Array && image.length > 0) {
          const dims = getPngDimensions(image);
          if (!dims || (dims.width > 1 && dims.height > 1)) {
            setExportImage(image);
            exported = true;
          } else {
            console.warn("Skipping tiny viewport capture from getPicture:", dims);
          }
        }
      }

      if (!exported) {
        console.warn("Auto-export did not produce image output.");
      }
    } catch (e: any) {
      setError(e.message);
    }
  };

  useEffect(() => {
    if (!isReady) return;
    const timer = setTimeout(() => applyReport(yaml), 500);
    return () => clearTimeout(timer);
  }, [yaml, isReady]);

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100vh', background: '#1e1e1e', color: '#e1e1e1' }}>
      <div style={{ 
        height: '48px', background: '#333', borderBottom: '1px solid #444', 
        display: 'flex', alignItems: 'center', padding: '0 16px', gap: '20px' 
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px', fontWeight: 'bold' }}>
          <Layers size={20} color="#007acc" />
          <span>VolvoxReport Designer</span>
        </div>
        <div style={{ flex: 1 }} />
        <button style={btnStyle} onClick={() => lastExport && window.open(lastExport)}><Download size={16} /> Download Output</button>
      </div>

      <div style={{ display: 'flex', flex: 1, overflow: 'hidden' }}>
        <div style={{ width: '40%', borderRight: '1px solid #444', display: 'flex', flexDirection: 'column' }}>
          <div style={{ background: '#252526', padding: '4px 12px', fontSize: '12px', color: '#888' }}>
             REPORT DEFINITION (YAML) {error && <span style={{ color: '#f44336', marginLeft: 10 }}>Error: {error}</span>}
          </div>
          <Editor
            height="100%"
            defaultLanguage="yaml"
            theme="vs-dark"
            value={yaml}
            onChange={(v) => setYaml(v || '')}
            options={{ minimap: { enabled: false }, fontSize: 14 }}
          />
        </div>

        <div style={{ flex: 1, background: '#1e1e1e', display: 'flex', flexDirection: 'column' }}>
          <div style={{ background: '#333', padding: '4px 12px', fontSize: '12px', color: '#aaa', display: 'flex', justifyContent: 'space-between' }}>
            <span>LIVE PREVIEW & AUTOMATIC OUTPUT GENERATION</span>
            <span>{isReady ? (lastExport ? "✓ Output Generated" : "Generating...") : "Engine Initializing..."}</span>
          </div>
          
          <canvas ref={canvasRef} width="1024" height="1024" style={HIDDEN_CANVAS_STYLE} />

          <div style={{ flex: 1, overflow: 'auto', padding: '40px', display: 'flex', justifyContent: 'center', alignItems: 'flex-start' }}>
            {lastExport ? (
              <img src={lastExport} style={{ boxShadow: '0 0 20px rgba(0,0,0,0.5)', background: 'white', maxWidth: '100%' }} alt="Report Preview" />
            ) : (
              <div style={{ color: '#666' }}>
                  {!isReady ? "Initializing Volvox Engine..." : "Rendering Report Preview..."}
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

const btnStyle: React.CSSProperties = {
  background: '#444',
  border: 'none',
  color: 'white',
  padding: '6px 12px',
  borderRadius: '4px',
  cursor: 'pointer',
  display: 'flex',
  alignItems: 'center',
  gap: '6px',
  fontSize: '13px'
};
