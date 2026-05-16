import {
  Align,
  BarcodeCaptionPosition,
  BarcodeCheckDigitMode,
  BarcodeQrErrorCorrection,
  BarcodeSymbology,
  BarcodeTextEncoding,
  BorderStyle,
  ColIndicatorCellMode,
  GroupTotalPosition,
  ImageAlignment,
  LoadDataStatus,
  RowIndicatorSlotKind,
  SelectionMode,
  ThemePreset,
  TreeIndicatorStyle,
  type VolvoxGrid,
  type VolvoxGridBarcode,
  type VolvoxGridCellStyle,
  type VolvoxGridCellUpdate,
} from "../js/src/index.js";
import {
  DEFAULT_COL_INDICATOR_BAND_ROWS,
  DEFAULT_FLING_FRICTION,
  DEFAULT_FLING_IMPULSE_GAIN,
  DEFAULT_ROW_INDICATOR_WIDTH,
  PB_TEXT_DECODER,
  type DemoColumnSetup,
} from "./shared.js";

export const BARCODE_COLS = 6;

const BARCODE_HEADER_ROW_HEIGHT = 28;

const BARCODE_COLUMN_SETUP = [
  { caption: "Symbology", key: "Symbology", align: Align.ALIGN_CENTER_CENTER },
  { caption: "Payload", key: "Value" },
  { caption: "TextEncoding", key: "TextEncoding", align: Align.ALIGN_CENTER_CENTER },
  { caption: "Settings", key: "Label" },
  { caption: "Barcode", key: "Barcode", align: Align.ALIGN_CENTER_CENTER },
  { caption: "Notes", key: "Notes" },
] satisfies readonly DemoColumnSetup[];

type BarcodeJsonRow = {
  Symbology: string;
  Value: string;
  TextEncoding?: string;
  QrEcc?: string;
  Label: string;
  Notes: string;
};

type BarcodeDemoPlan = {
  symbology: number;
  checkDigit: number;
  textEncoding: number;
  qrEcc: number;
  foreground: number;
  background: number;
  alignment: number;
  moduleSize: number;
  quietZone: number;
  barHeight: number;
  narrowBarWidth: number;
  captionPosition: number;
  captionColor: number;
  rowHeight: number;
  optionsText: string;
};

function barcodeKey(value: string): string {
  return value.replace(/[^0-9a-z]/gi, "").toUpperCase();
}

function barcodeTextEncodingFromRecord(record: BarcodeJsonRow, fallback: number): number {
  switch (barcodeKey(record.TextEncoding ?? "")) {
    case "UTF8":
      return BarcodeTextEncoding.BARCODE_TEXT_UTF8;
    case "GS1":
      return BarcodeTextEncoding.BARCODE_TEXT_GS1;
    case "AUTO":
      return BarcodeTextEncoding.BARCODE_TEXT_AUTO;
    default:
      return fallback;
  }
}

function barcodeTextEncodingLabel(textEncoding: number): string {
  switch (textEncoding) {
    case BarcodeTextEncoding.BARCODE_TEXT_UTF8:
      return "UTF8";
    case BarcodeTextEncoding.BARCODE_TEXT_GS1:
      return "GS1";
    default:
      return "AUTO";
  }
}

function barcodeTextEncodingDisplay(record: BarcodeJsonRow): string {
  if (!record.TextEncoding) {
    return "";
  }
  return barcodeTextEncodingLabel(barcodeTextEncodingFromRecord(record, BarcodeTextEncoding.BARCODE_TEXT_AUTO));
}

function barcodeQrEccFromRecord(record: BarcodeJsonRow, fallback: number): number {
  switch (barcodeKey(record.QrEcc ?? "")) {
    case "LOW":
      return BarcodeQrErrorCorrection.QR_ECC_LOW;
    case "MEDIUM":
      return BarcodeQrErrorCorrection.QR_ECC_MEDIUM;
    case "QUARTILE":
      return BarcodeQrErrorCorrection.QR_ECC_QUARTILE;
    case "HIGH":
      return BarcodeQrErrorCorrection.QR_ECC_HIGH;
    case "DEFAULT":
      return BarcodeQrErrorCorrection.QR_ECC_DEFAULT;
    default:
      return fallback;
  }
}

function barcodeQrEccLabel(qrEcc: number): string {
  switch (qrEcc) {
    case BarcodeQrErrorCorrection.QR_ECC_LOW:
      return "LOW";
    case BarcodeQrErrorCorrection.QR_ECC_MEDIUM:
      return "MEDIUM";
    case BarcodeQrErrorCorrection.QR_ECC_QUARTILE:
      return "QUARTILE";
    case BarcodeQrErrorCorrection.QR_ECC_HIGH:
      return "HIGH";
    default:
      return "DEFAULT";
  }
}

function barcodeDemoPlan(record: BarcodeJsonRow): BarcodeDemoPlan {
  const plan: BarcodeDemoPlan = {
    symbology: BarcodeSymbology.BARCODE_NONE,
    checkDigit: BarcodeCheckDigitMode.CHECK_DIGIT_DEFAULT,
    textEncoding: BarcodeTextEncoding.BARCODE_TEXT_AUTO,
    qrEcc: BarcodeQrErrorCorrection.QR_ECC_DEFAULT,
    foreground: 0xFF111827,
    background: 0xFFFFFFFF,
    alignment: ImageAlignment.IMG_ALIGN_CENTER_CENTER,
    moduleSize: 0,
    quietZone: 0,
    barHeight: 0,
    narrowBarWidth: 0,
    captionPosition: BarcodeCaptionPosition.CAPTION_BOTTOM,
    captionColor: 0xFF334155,
    rowHeight: 96,
    optionsText: "auto",
  };

  switch (barcodeKey(record.Symbology)) {
    case "QR":
    case "QRCODE":
      plan.symbology = BarcodeSymbology.BARCODE_QR;
      plan.textEncoding = barcodeTextEncodingFromRecord(record, BarcodeTextEncoding.BARCODE_TEXT_AUTO);
      plan.qrEcc = barcodeQrEccFromRecord(record, BarcodeQrErrorCorrection.QR_ECC_DEFAULT);
      plan.background = 0xFFF8FAFC;
      plan.alignment = ImageAlignment.IMG_ALIGN_CENTER_CENTER;
      plan.quietZone = 3;
      plan.rowHeight = 150;
      plan.captionColor = 0xFF1D4ED8;
      plan.optionsText = `text=${barcodeTextEncodingLabel(plan.textEncoding)}, qr_ecc=${barcodeQrEccLabel(plan.qrEcc)}, quiet=3, size=auto`;
      break;
    case "CODE128": {
      plan.symbology = BarcodeSymbology.BARCODE_CODE128;
      plan.textEncoding = barcodeTextEncodingFromRecord(record, BarcodeTextEncoding.BARCODE_TEXT_AUTO);
      plan.background = 0xFFECFDF5;
      plan.alignment = ImageAlignment.IMG_ALIGN_STRETCH;
      plan.quietZone = 10;
      plan.captionColor = 0xFF047857;
      plan.optionsText = `text=${barcodeTextEncodingLabel(plan.textEncoding)}, check=AUTO, quiet=10, size=auto`;
      break;
    }
    case "CODE39":
      plan.symbology = BarcodeSymbology.BARCODE_CODE39;
      plan.checkDigit = BarcodeCheckDigitMode.CHECK_DIGIT_GENERATE;
      plan.foreground = 0xFF7C2D12;
      plan.background = 0xFFFFF7ED;
      plan.quietZone = 8;
      plan.captionPosition = BarcodeCaptionPosition.CAPTION_TOP;
      plan.captionColor = 0xFFC2410C;
      plan.optionsText = "check=GENERATE, quiet=8, size=auto, caption=TOP";
      break;
    case "CODE93":
      plan.symbology = BarcodeSymbology.BARCODE_CODE93;
      plan.foreground = 0xFF312E81;
      plan.background = 0xFFEEF2FF;
      plan.quietZone = 8;
      plan.optionsText = "quiet=8, size=auto";
      break;
    case "CODE11":
      plan.symbology = BarcodeSymbology.BARCODE_CODE11;
      plan.foreground = 0xFF3F3F46;
      plan.background = 0xFFF4F4F5;
      plan.alignment = ImageAlignment.IMG_ALIGN_STRETCH;
      plan.quietZone = 10;
      plan.optionsText = "quiet=10, size=auto";
      break;
    case "EAN13":
      plan.symbology = BarcodeSymbology.BARCODE_EAN13;
      plan.foreground = 0xFF1F2937;
      plan.quietZone = 12;
      plan.optionsText = "check=AUTO, quiet=12, size=auto";
      break;
    case "EAN8":
      plan.symbology = BarcodeSymbology.BARCODE_EAN8;
      plan.foreground = 0xFF164E63;
      plan.background = 0xFFECFEFF;
      plan.quietZone = 10;
      plan.optionsText = "check=AUTO, quiet=10, size=auto";
      break;
    case "UPCA":
      plan.symbology = BarcodeSymbology.BARCODE_UPC_A;
      plan.foreground = 0xFF365314;
      plan.background = 0xFFF7FEE7;
      plan.quietZone = 12;
      plan.optionsText = "check=AUTO, quiet=12, size=auto";
      break;
    case "UPCE":
      plan.symbology = BarcodeSymbology.BARCODE_UPC_E;
      plan.foreground = 0xFF7F1D1D;
      plan.background = 0xFFFEF2F2;
      plan.quietZone = 10;
      plan.optionsText = "check=AUTO, quiet=10, size=auto";
      break;
    case "EANSUPP":
    case "EANSUPPLEMENT":
    case "EANSUPPLEMENTAL":
      plan.symbology = BarcodeSymbology.BARCODE_EAN_SUPP;
      plan.foreground = 0xFF581C87;
      plan.background = 0xFFFAF5FF;
      plan.quietZone = 8;
      plan.optionsText = "quiet=8, size=auto";
      break;
    case "ITF":
      plan.symbology = BarcodeSymbology.BARCODE_ITF;
      plan.checkDigit = BarcodeCheckDigitMode.CHECK_DIGIT_NONE;
      plan.foreground = 0xFF0F766E;
      plan.background = 0xFFF0FDFA;
      plan.alignment = ImageAlignment.IMG_ALIGN_STRETCH;
      plan.quietZone = 12;
      plan.optionsText = "check=NONE, quiet=12, size=auto";
      break;
    case "STF":
      plan.symbology = BarcodeSymbology.BARCODE_STF;
      plan.foreground = 0xFF854D0E;
      plan.background = 0xFFFEFCE8;
      plan.alignment = ImageAlignment.IMG_ALIGN_STRETCH;
      plan.quietZone = 10;
      plan.optionsText = "quiet=10, size=auto";
      break;
    case "CODABAR":
      plan.symbology = BarcodeSymbology.BARCODE_CODABAR;
      plan.foreground = 0xFFBE123C;
      plan.background = 0xFFFFF1F2;
      plan.quietZone = 10;
      plan.captionPosition = BarcodeCaptionPosition.CAPTION_NONE;
      plan.optionsText = "quiet=10, size=auto, caption=NONE";
      break;
    default:
      throw new Error(`unknown barcode symbology: ${record.Symbology}`);
  }

  return plan;
}

function barcodeFromPlan(record: BarcodeJsonRow, plan: BarcodeDemoPlan): VolvoxGridBarcode {
  return {
    symbology: plan.symbology,
    encoding: {
      checkDigit: plan.checkDigit !== BarcodeCheckDigitMode.CHECK_DIGIT_DEFAULT ? plan.checkDigit : undefined,
      textEncoding: plan.textEncoding !== BarcodeTextEncoding.BARCODE_TEXT_AUTO ? plan.textEncoding : undefined,
      qrEcc: plan.qrEcc !== BarcodeQrErrorCorrection.QR_ECC_DEFAULT ? plan.qrEcc : undefined,
    },
    render: {
      foreground: plan.foreground !== 0 ? plan.foreground : undefined,
      background: plan.background !== 0 ? plan.background : undefined,
      alignment: plan.alignment !== ImageAlignment.IMG_ALIGN_STRETCH ? plan.alignment : undefined,
      moduleSize: plan.moduleSize !== 0 ? plan.moduleSize : undefined,
      quietZone: plan.quietZone !== 0 ? plan.quietZone : undefined,
      barHeight: plan.barHeight !== 0 ? plan.barHeight : undefined,
      narrowBarWidth: plan.narrowBarWidth !== 0 ? plan.narrowBarWidth : undefined,
      showSizeWarning: true,
      useFullRect: true,
    },
    caption: {
      position: plan.captionPosition,
      text: record.Label,
      color: plan.captionColor,
    },
  };
}

function applyBarcodeDemoChrome(grid: VolvoxGrid): void {
  grid.themePreset = ThemePreset.THEME_LIGHT;
  grid.setOutlineConfig({
    treeIndicator: TreeIndicatorStyle.TREE_INDICATOR_NONE,
    groupTotalPosition: GroupTotalPosition.GROUP_TOTAL_BELOW,
    multiTotals: true,
  });
  grid.setRowIndicatorStartConfig({
    visible: true,
    width: DEFAULT_ROW_INDICATOR_WIDTH,
    slots: [{
      kind: RowIndicatorSlotKind.ROW_INDICATOR_SLOT_NUMBERS,
      width: DEFAULT_ROW_INDICATOR_WIDTH,
      visible: true,
    }],
  });
  grid.setColumnIndicatorTopConfig({
    visible: true,
    defaultRowHeight: BARCODE_HEADER_ROW_HEIGHT,
    bandRows: DEFAULT_COL_INDICATOR_BAND_ROWS,
    cellModes: [
      ColIndicatorCellMode.COL_INDICATOR_CELL_HEADER_TEXT,
      ColIndicatorCellMode.COL_INDICATOR_CELL_SORT_GLYPH,
    ],
  });
}

export function setupBarcodesJsonDemo(grid: VolvoxGrid, id: number): void {
  const prevId = grid.id;
  if (id !== prevId) {
    grid.useGrid(id);
  }

  try {
    const barcodeData = grid.getDemoData("barcodes");
    if (barcodeData.length === 0) {
      throw new Error("embedded barcodes demo data is empty");
    }
    const records = JSON.parse(PB_TEXT_DECODER.decode(barcodeData)) as BarcodeJsonRow[];
    const plans = records.map((record) => barcodeDemoPlan(record));

    grid.colCount = BARCODE_COLS;
    grid.defineColumns(BARCODE_COLUMN_SETUP);
    const result = grid.loadData(barcodeData, {
      autoCreateColumns: false,
    });
    if (result.status === LoadDataStatus.LOAD_FAILED) {
      throw new Error("LoadData failed for embedded barcodes demo");
    }
    grid.defineColumns(BARCODE_COLUMN_SETUP);
    applyBarcodeDemoChrome(grid);
    grid.defineRows(plans.map((plan) => ({ height: plan.rowHeight })));

    const smallTextStyle: VolvoxGridCellStyle = {
      foreground: 0xFF475569,
    };
    const cells: VolvoxGridCellUpdate[] = [];
    records.forEach((record, index) => {
      const plan = plans[index];
      cells.push({
        row: index,
        col: 2,
        text: barcodeTextEncodingDisplay(record),
        style: {
          foreground: 0xFF475569,
          align: Align.ALIGN_CENTER_CENTER,
        },
      });
      cells.push({
        row: index,
        col: 3,
        text: `${record.Label}\n${plan.optionsText}`,
        style: smallTextStyle,
      });
      cells.push({
        row: index,
        col: 4,
        text: record.Value,
        style: {
          background: plan.background,
          align: Align.ALIGN_CENTER_CENTER,
          padding: { left: 4, top: 4, right: 4, bottom: 4 },
          borders: {
            all: {
              style: BorderStyle.BORDER_THIN,
              colorArgb: 0xFFD1D5DB,
            },
          },
        },
        barcode: barcodeFromPlan(record, plan),
      });
      cells.push({
        row: index,
        col: 5,
        text: record.Notes,
        style: smallTextStyle,
      });
    });

    grid.updateCells(cells, { atomic: true });

    grid.selectionMode = SelectionMode.SELECTION_FREE;
    grid.setHeaderFeatures({ sort: true, reorder: true, chooser: false });
    grid.flingImpulseGain = DEFAULT_FLING_IMPULSE_GAIN;
    grid.flingFriction = DEFAULT_FLING_FRICTION;
    grid.invalidate();
  } finally {
    if (id !== prevId) {
      grid.useGrid(prevId);
    }
  }
}
