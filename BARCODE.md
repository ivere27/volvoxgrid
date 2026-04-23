# Barcode Support

VolvoxGrid can render QR codes and common 1D barcodes inside normal grid cells.
Barcode rendering is a cell extra: the cell still has an ordinary value for
sorting, editing, copy/paste, and data loading.

The public contract is in [proto/volvoxgrid.proto](proto/volvoxgrid.proto).

## User Behavior

- In `make web`, open the `Barcodes` demo to see QR, Code 128, Code 39, EAN,
  UPC, 2-of-5, and Codabar examples.
- In `make gtk-test`, open the `Barcodes` demo for the GTK/plugin-host version.
- The `Barcode` column stores the barcode payload as normal cell text. Editing
  the cell edits the payload, and sorting sorts by that payload.
- The visible barcode updates from the cell payload. If the payload is invalid
  for the selected symbology, the barcode is not drawn.
- TUI mode does not currently draw barcode graphics. It can still show and edit
  the payload text.

The shared fixture is [testdata/barcodes.json](testdata/barcodes.json). It is
plain data with `Symbology`, `Value`, `Label`, and `Notes`; wrappers map those
rows to `BarcodeData`.

## Developer Model

Attach a barcode with `CellUpdate.barcode`:

```proto
message CellUpdate {
  CellValue value = 3;
  optional BarcodeData barcode = 13;
}

message BarcodeData {
  BarcodeSymbology symbology = 1;
  string value = 2;
  BarcodeEncodingOptions encoding = 3;
  BarcodeRenderOptions render = 4;
  BarcodeCaptionOptions caption = 5;
}
```

Recommended pattern:

1. Put the payload in `CellUpdate.value`.
2. Leave `BarcodeData.value` empty.
3. Set `BarcodeData.symbology` and any render/caption options.

When `BarcodeData.value` is empty, the renderer uses the cell display text as
the payload. This keeps normal grid behavior working: sort, edit, search,
copy/paste, and TUI fallback all see the same payload.

Use `BarcodeData.value` only when you intentionally want the rendered payload to
be different from the cell value.

`CellUpdate.barcode` is a full replacement, not a sparse patch. Send the full
barcode spec each time. Send `BARCODE_NONE` to clear an existing barcode extra.

## Supported Symbologies

| Enum | Notes |
|---|---|
| `BARCODE_QR` | Text QR. Use `BARCODE_TEXT_UTF8` for Unicode payloads. `qr_ecc` controls error correction. |
| `BARCODE_CODE128` | Code 128. `BARCODE_TEXT_GS1` inserts FNC1 and is intended for GS1-style payloads. |
| `BARCODE_CODE39` | Uppercase Code 39 payloads. `CHECK_DIGIT_GENERATE` adds the optional check character. |
| `BARCODE_CODE93` | Code 93. Use ASCII payloads. |
| `BARCODE_CODE11` | Digits and dash. |
| `BARCODE_EAN13` | 12 or 13 numeric digits. A 12-digit value generates the check digit; 13 digits are validated. |
| `BARCODE_EAN8` | 7 or 8 numeric digits. A 7-digit value generates the check digit; 8 digits are validated. |
| `BARCODE_UPC_A` | UPC-A numeric payloads. |
| `BARCODE_UPC_E` | UPC-E numeric payloads accepted by the local UPC-E parser. |
| `BARCODE_EAN_SUPP` | 2-digit or 5-digit EAN supplement. |
| `BARCODE_ITF` | Numeric Interleaved 2 of 5. With `CHECK_DIGIT_NONE`, odd-length payloads are rejected. |
| `BARCODE_STF` | Numeric Standard 2 of 5. With `CHECK_DIGIT_NONE`, odd-length payloads are rejected. |
| `BARCODE_CODABAR` | Codabar with valid start/stop characters such as `A...B`, `C...D`. |

Payloads are text strings. Raw binary QR or Code 128 byte mode is not exposed.

## Options

### Encoding

```proto
message BarcodeEncodingOptions {
  BarcodeCheckDigitMode check_digit = 1;
  BarcodeTextEncoding text_encoding = 2;
  BarcodeQrErrorCorrection qr_ecc = 3;
}
```

- `check_digit`: common policy for optional check digits. Mandatory checksums
  required by a symbology are still handled by the encoder.
- `text_encoding`: `AUTO`, `ASCII`, `UTF8`, or `GS1`. `ASCII` rejects
  non-ASCII payloads; `GS1` currently affects Code 128.
- `qr_ecc`: QR-only error correction. `DEFAULT` maps to medium ECC.

### Rendering

```proto
message BarcodeRenderOptions {
  optional uint32 foreground = 1;
  optional uint32 background = 2;
  optional ImageAlignment alignment = 3;
  uint32 module_size = 4;
  uint32 quiet_zone = 5;
  uint32 bar_height = 10;
  uint32 narrow_bar_width = 11;
  optional bool show_size_warning = 12;
  optional uint32 size_warning_color = 13;
  optional bool use_full_rect = 14;
}
```

- `foreground` defaults to the cell foreground.
- `background` is transparent when unset.
- `alignment` defaults to stretch in the engine. Demos often use center for QR
  and stretch for linear barcodes.
- `module_size` uses `0` for automatic sizing; explicit values are clamped to
  `[1, 16]`.
- `quiet_zone` uses `0` for the symbology default; explicit values are clamped
  to `[0, 64]` for QR and `[0, 128]` for 1D symbologies.
- `bar_height` uses `0` for automatic 1D bar height.
- `narrow_bar_width` uses `0` for automatic 1D narrow-bar sizing; explicit
  values are clamped to `[1, 32]`.
- `show_size_warning` draws a warning mark when the cell is too small for a
  faithful minimum-size barcode.
- `use_full_rect` lets auto-sized symbols fill the whole barcode rectangle.

### Caption

```proto
message BarcodeCaptionOptions {
  optional BarcodeCaptionPosition position = 1;
  optional string text = 2;
  optional uint32 color = 3;
  optional float font_size = 4;
}
```

- Caption position defaults to `CAPTION_BOTTOM` for 1D barcodes and
  `CAPTION_NONE` for QR.
- Empty caption text uses the encoded payload.
- Caption color defaults to the barcode foreground.
- Empty or zero font size inherits the cell font size.

## Status And Validation

Readback can include a barcode encode probe:

```proto
message GetCellsRequest {
  bool include_barcode_status = 9;
}

message CellData {
  optional BarcodeData barcode = 7; // Readback counterpart of CellUpdate.barcode.
  optional BarcodeRenderStatus barcode_status = 8;
}
```

`barcode_status` is only populated when `include_barcode_status` is true. It is
off by default because probing requires an encode pass.

Statuses:

| Status | Meaning |
|---|---|
| `BARCODE_RENDER_STATUS_OK` | The payload can be encoded. |
| `BARCODE_RENDER_STATUS_EMPTY_PAYLOAD` | The barcode has no explicit value and the cell text is empty. |
| `BARCODE_RENDER_STATUS_INVALID_PAYLOAD` | The payload is not valid for the selected symbology or encoding option. |
| `BARCODE_RENDER_STATUS_UNSUPPORTED_SYMBOLOGY` | The symbology is unknown to this engine. |
| `BARCODE_RENDER_STATUS_UNSPECIFIED` | No barcode status is available. |

## Rendering Notes

- Pixel renderers draw barcodes in `RENDER_LAYER_BARCODES`.
- The barcode layer only does work when visible cells contain barcodes.
- The TUI renderer has no barcode drawing layer today. It renders the cell text
  only, so storing the payload in the cell value is important.
- Barcode rendering is useful for dedicated barcode columns or detail views.
  Avoid filling every visible cell of a large sheet with barcode extras unless
  you have measured the cost.

## Minimal Example

```text
CellUpdate {
  row: 1
  col: 3
  value { text: "ABC123" }
  barcode {
    symbology: BARCODE_CODE39
    encoding {
      check_digit: CHECK_DIGIT_GENERATE
      text_encoding: BARCODE_TEXT_ASCII
    }
    render {
      foreground: 0xFF111827
      background: 0xFFFFFFFF
      alignment: IMG_ALIGN_STRETCH
      quiet_zone: 8
      use_full_rect: true
    }
    caption {
      position: CAPTION_BOTTOM
      text: "Code 39"
    }
  }
}
```

The barcode payload is `ABC123` because `BarcodeData.value` is empty, so the
renderer falls back to the cell text.
