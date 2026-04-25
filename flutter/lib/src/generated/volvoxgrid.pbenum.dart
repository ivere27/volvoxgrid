// This is a generated file - do not edit.
//
// Generated from volvoxgrid.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class BorderStyle extends $pb.ProtobufEnum {
  static const BorderStyle BORDER_NONE =
      BorderStyle._(0, _omitEnumNames ? '' : 'BORDER_NONE');
  static const BorderStyle BORDER_THIN =
      BorderStyle._(1, _omitEnumNames ? '' : 'BORDER_THIN');
  static const BorderStyle BORDER_THICK =
      BorderStyle._(2, _omitEnumNames ? '' : 'BORDER_THICK');
  static const BorderStyle BORDER_DOTTED =
      BorderStyle._(3, _omitEnumNames ? '' : 'BORDER_DOTTED');
  static const BorderStyle BORDER_DASHED =
      BorderStyle._(4, _omitEnumNames ? '' : 'BORDER_DASHED');
  static const BorderStyle BORDER_DOUBLE =
      BorderStyle._(5, _omitEnumNames ? '' : 'BORDER_DOUBLE');

  static const $core.List<BorderStyle> values = <BorderStyle>[
    BORDER_NONE,
    BORDER_THIN,
    BORDER_THICK,
    BORDER_DOTTED,
    BORDER_DASHED,
    BORDER_DOUBLE,
  ];

  static final $core.List<BorderStyle?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 5);
  static BorderStyle? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const BorderStyle._(super.value, super.name);
}

class GridLineStyle extends $pb.ProtobufEnum {
  static const GridLineStyle GRIDLINE_NONE =
      GridLineStyle._(0, _omitEnumNames ? '' : 'GRIDLINE_NONE');
  static const GridLineStyle GRIDLINE_SOLID =
      GridLineStyle._(1, _omitEnumNames ? '' : 'GRIDLINE_SOLID');
  static const GridLineStyle GRIDLINE_INSET =
      GridLineStyle._(2, _omitEnumNames ? '' : 'GRIDLINE_INSET');
  static const GridLineStyle GRIDLINE_RAISED =
      GridLineStyle._(3, _omitEnumNames ? '' : 'GRIDLINE_RAISED');

  static const $core.List<GridLineStyle> values = <GridLineStyle>[
    GRIDLINE_NONE,
    GRIDLINE_SOLID,
    GRIDLINE_INSET,
    GRIDLINE_RAISED,
  ];

  static final $core.List<GridLineStyle?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static GridLineStyle? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const GridLineStyle._(super.value, super.name);
}

class GridLineDirection extends $pb.ProtobufEnum {
  static const GridLineDirection GRIDLINE_BOTH =
      GridLineDirection._(0, _omitEnumNames ? '' : 'GRIDLINE_BOTH');
  static const GridLineDirection GRIDLINE_HORIZONTAL =
      GridLineDirection._(1, _omitEnumNames ? '' : 'GRIDLINE_HORIZONTAL');
  static const GridLineDirection GRIDLINE_VERTICAL =
      GridLineDirection._(2, _omitEnumNames ? '' : 'GRIDLINE_VERTICAL');

  static const $core.List<GridLineDirection> values = <GridLineDirection>[
    GRIDLINE_BOTH,
    GRIDLINE_HORIZONTAL,
    GRIDLINE_VERTICAL,
  ];

  static final $core.List<GridLineDirection?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static GridLineDirection? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const GridLineDirection._(super.value, super.name);
}

class BorderAppearance extends $pb.ProtobufEnum {
  static const BorderAppearance BORDER_APPEARANCE_FLAT =
      BorderAppearance._(0, _omitEnumNames ? '' : 'BORDER_APPEARANCE_FLAT');
  static const BorderAppearance BORDER_APPEARANCE_RAISED =
      BorderAppearance._(1, _omitEnumNames ? '' : 'BORDER_APPEARANCE_RAISED');
  static const BorderAppearance BORDER_APPEARANCE_SUBTLE =
      BorderAppearance._(2, _omitEnumNames ? '' : 'BORDER_APPEARANCE_SUBTLE');

  static const $core.List<BorderAppearance> values = <BorderAppearance>[
    BORDER_APPEARANCE_FLAT,
    BORDER_APPEARANCE_RAISED,
    BORDER_APPEARANCE_SUBTLE,
  ];

  static final $core.List<BorderAppearance?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static BorderAppearance? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const BorderAppearance._(super.value, super.name);
}

class TextEffect extends $pb.ProtobufEnum {
  static const TextEffect TEXT_EFFECT_NONE =
      TextEffect._(0, _omitEnumNames ? '' : 'TEXT_EFFECT_NONE');
  static const TextEffect TEXT_EFFECT_EMBOSS =
      TextEffect._(1, _omitEnumNames ? '' : 'TEXT_EFFECT_EMBOSS');
  static const TextEffect TEXT_EFFECT_ENGRAVE =
      TextEffect._(2, _omitEnumNames ? '' : 'TEXT_EFFECT_ENGRAVE');
  static const TextEffect TEXT_EFFECT_EMBOSS_LIGHT =
      TextEffect._(3, _omitEnumNames ? '' : 'TEXT_EFFECT_EMBOSS_LIGHT');
  static const TextEffect TEXT_EFFECT_ENGRAVE_LIGHT =
      TextEffect._(4, _omitEnumNames ? '' : 'TEXT_EFFECT_ENGRAVE_LIGHT');

  static const $core.List<TextEffect> values = <TextEffect>[
    TEXT_EFFECT_NONE,
    TEXT_EFFECT_EMBOSS,
    TEXT_EFFECT_ENGRAVE,
    TEXT_EFFECT_EMBOSS_LIGHT,
    TEXT_EFFECT_ENGRAVE_LIGHT,
  ];

  static final $core.List<TextEffect?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static TextEffect? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const TextEffect._(super.value, super.name);
}

class TextRenderMode extends $pb.ProtobufEnum {
  static const TextRenderMode TEXT_RENDER_AUTO =
      TextRenderMode._(0, _omitEnumNames ? '' : 'TEXT_RENDER_AUTO');
  static const TextRenderMode TEXT_RENDER_GRAYSCALE =
      TextRenderMode._(1, _omitEnumNames ? '' : 'TEXT_RENDER_GRAYSCALE');
  static const TextRenderMode TEXT_RENDER_SUBPIXEL =
      TextRenderMode._(2, _omitEnumNames ? '' : 'TEXT_RENDER_SUBPIXEL');
  static const TextRenderMode TEXT_RENDER_MONO =
      TextRenderMode._(3, _omitEnumNames ? '' : 'TEXT_RENDER_MONO');

  static const $core.List<TextRenderMode> values = <TextRenderMode>[
    TEXT_RENDER_AUTO,
    TEXT_RENDER_GRAYSCALE,
    TEXT_RENDER_SUBPIXEL,
    TEXT_RENDER_MONO,
  ];

  static final $core.List<TextRenderMode?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static TextRenderMode? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const TextRenderMode._(super.value, super.name);
}

class TextHintingMode extends $pb.ProtobufEnum {
  static const TextHintingMode TEXT_HINT_AUTO =
      TextHintingMode._(0, _omitEnumNames ? '' : 'TEXT_HINT_AUTO');
  static const TextHintingMode TEXT_HINT_NONE =
      TextHintingMode._(1, _omitEnumNames ? '' : 'TEXT_HINT_NONE');
  static const TextHintingMode TEXT_HINT_SLIGHT =
      TextHintingMode._(2, _omitEnumNames ? '' : 'TEXT_HINT_SLIGHT');
  static const TextHintingMode TEXT_HINT_FULL =
      TextHintingMode._(3, _omitEnumNames ? '' : 'TEXT_HINT_FULL');

  static const $core.List<TextHintingMode> values = <TextHintingMode>[
    TEXT_HINT_AUTO,
    TEXT_HINT_NONE,
    TEXT_HINT_SLIGHT,
    TEXT_HINT_FULL,
  ];

  static final $core.List<TextHintingMode?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static TextHintingMode? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const TextHintingMode._(super.value, super.name);
}

/// Cell text alignment: "horizontal_vertical".
/// ALIGN_GENERAL (9) is the engine default for data cells. It renders as
/// left-center for text and right-center for numeric-looking values.
/// The engine uses a heuristic (canvas.rs text_looks_numeric()) to decide
/// at render time whether the cell content looks numeric.
class Align extends $pb.ProtobufEnum {
  static const Align ALIGN_LEFT_TOP =
      Align._(0, _omitEnumNames ? '' : 'ALIGN_LEFT_TOP');
  static const Align ALIGN_LEFT_CENTER =
      Align._(1, _omitEnumNames ? '' : 'ALIGN_LEFT_CENTER');
  static const Align ALIGN_LEFT_BOTTOM =
      Align._(2, _omitEnumNames ? '' : 'ALIGN_LEFT_BOTTOM');
  static const Align ALIGN_CENTER_TOP =
      Align._(3, _omitEnumNames ? '' : 'ALIGN_CENTER_TOP');
  static const Align ALIGN_CENTER_CENTER =
      Align._(4, _omitEnumNames ? '' : 'ALIGN_CENTER_CENTER');
  static const Align ALIGN_CENTER_BOTTOM =
      Align._(5, _omitEnumNames ? '' : 'ALIGN_CENTER_BOTTOM');
  static const Align ALIGN_RIGHT_TOP =
      Align._(6, _omitEnumNames ? '' : 'ALIGN_RIGHT_TOP');
  static const Align ALIGN_RIGHT_CENTER =
      Align._(7, _omitEnumNames ? '' : 'ALIGN_RIGHT_CENTER');
  static const Align ALIGN_RIGHT_BOTTOM =
      Align._(8, _omitEnumNames ? '' : 'ALIGN_RIGHT_BOTTOM');
  static const Align ALIGN_GENERAL =
      Align._(9, _omitEnumNames ? '' : 'ALIGN_GENERAL');

  static const $core.List<Align> values = <Align>[
    ALIGN_LEFT_TOP,
    ALIGN_LEFT_CENTER,
    ALIGN_LEFT_BOTTOM,
    ALIGN_CENTER_TOP,
    ALIGN_CENTER_CENTER,
    ALIGN_CENTER_BOTTOM,
    ALIGN_RIGHT_TOP,
    ALIGN_RIGHT_CENTER,
    ALIGN_RIGHT_BOTTOM,
    ALIGN_GENERAL,
  ];

  static final $core.List<Align?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 9);
  static Align? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Align._(super.value, super.name);
}

class ImageAlignment extends $pb.ProtobufEnum {
  static const ImageAlignment IMG_ALIGN_LEFT_TOP =
      ImageAlignment._(0, _omitEnumNames ? '' : 'IMG_ALIGN_LEFT_TOP');
  static const ImageAlignment IMG_ALIGN_LEFT_CENTER =
      ImageAlignment._(1, _omitEnumNames ? '' : 'IMG_ALIGN_LEFT_CENTER');
  static const ImageAlignment IMG_ALIGN_LEFT_BOTTOM =
      ImageAlignment._(2, _omitEnumNames ? '' : 'IMG_ALIGN_LEFT_BOTTOM');
  static const ImageAlignment IMG_ALIGN_CENTER_TOP =
      ImageAlignment._(3, _omitEnumNames ? '' : 'IMG_ALIGN_CENTER_TOP');
  static const ImageAlignment IMG_ALIGN_CENTER_CENTER =
      ImageAlignment._(4, _omitEnumNames ? '' : 'IMG_ALIGN_CENTER_CENTER');
  static const ImageAlignment IMG_ALIGN_CENTER_BOTTOM =
      ImageAlignment._(5, _omitEnumNames ? '' : 'IMG_ALIGN_CENTER_BOTTOM');
  static const ImageAlignment IMG_ALIGN_RIGHT_TOP =
      ImageAlignment._(6, _omitEnumNames ? '' : 'IMG_ALIGN_RIGHT_TOP');
  static const ImageAlignment IMG_ALIGN_RIGHT_CENTER =
      ImageAlignment._(7, _omitEnumNames ? '' : 'IMG_ALIGN_RIGHT_CENTER');
  static const ImageAlignment IMG_ALIGN_RIGHT_BOTTOM =
      ImageAlignment._(8, _omitEnumNames ? '' : 'IMG_ALIGN_RIGHT_BOTTOM');
  static const ImageAlignment IMG_ALIGN_STRETCH =
      ImageAlignment._(9, _omitEnumNames ? '' : 'IMG_ALIGN_STRETCH');
  static const ImageAlignment IMG_ALIGN_TILE =
      ImageAlignment._(10, _omitEnumNames ? '' : 'IMG_ALIGN_TILE');

  static const $core.List<ImageAlignment> values = <ImageAlignment>[
    IMG_ALIGN_LEFT_TOP,
    IMG_ALIGN_LEFT_CENTER,
    IMG_ALIGN_LEFT_BOTTOM,
    IMG_ALIGN_CENTER_TOP,
    IMG_ALIGN_CENTER_CENTER,
    IMG_ALIGN_CENTER_BOTTOM,
    IMG_ALIGN_RIGHT_TOP,
    IMG_ALIGN_RIGHT_CENTER,
    IMG_ALIGN_RIGHT_BOTTOM,
    IMG_ALIGN_STRETCH,
    IMG_ALIGN_TILE,
  ];

  static final $core.List<ImageAlignment?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 10);
  static ImageAlignment? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ImageAlignment._(super.value, super.name);
}

class BarcodeSymbology extends $pb.ProtobufEnum {
  static const BarcodeSymbology BARCODE_NONE =
      BarcodeSymbology._(0, _omitEnumNames ? '' : 'BARCODE_NONE');
  static const BarcodeSymbology BARCODE_QR =
      BarcodeSymbology._(1, _omitEnumNames ? '' : 'BARCODE_QR');
  static const BarcodeSymbology BARCODE_CODE128 =
      BarcodeSymbology._(10, _omitEnumNames ? '' : 'BARCODE_CODE128');
  static const BarcodeSymbology BARCODE_CODE39 =
      BarcodeSymbology._(11, _omitEnumNames ? '' : 'BARCODE_CODE39');
  static const BarcodeSymbology BARCODE_CODE93 =
      BarcodeSymbology._(12, _omitEnumNames ? '' : 'BARCODE_CODE93');
  static const BarcodeSymbology BARCODE_CODE11 =
      BarcodeSymbology._(13, _omitEnumNames ? '' : 'BARCODE_CODE11');
  static const BarcodeSymbology BARCODE_EAN13 =
      BarcodeSymbology._(20, _omitEnumNames ? '' : 'BARCODE_EAN13');
  static const BarcodeSymbology BARCODE_EAN8 =
      BarcodeSymbology._(21, _omitEnumNames ? '' : 'BARCODE_EAN8');
  static const BarcodeSymbology BARCODE_UPC_A =
      BarcodeSymbology._(22, _omitEnumNames ? '' : 'BARCODE_UPC_A');
  static const BarcodeSymbology BARCODE_UPC_E =
      BarcodeSymbology._(23, _omitEnumNames ? '' : 'BARCODE_UPC_E');
  static const BarcodeSymbology BARCODE_EAN_SUPP =
      BarcodeSymbology._(24, _omitEnumNames ? '' : 'BARCODE_EAN_SUPP');
  static const BarcodeSymbology BARCODE_ITF =
      BarcodeSymbology._(30, _omitEnumNames ? '' : 'BARCODE_ITF');
  static const BarcodeSymbology BARCODE_STF =
      BarcodeSymbology._(31, _omitEnumNames ? '' : 'BARCODE_STF');
  static const BarcodeSymbology BARCODE_CODABAR =
      BarcodeSymbology._(32, _omitEnumNames ? '' : 'BARCODE_CODABAR');

  static const $core.List<BarcodeSymbology> values = <BarcodeSymbology>[
    BARCODE_NONE,
    BARCODE_QR,
    BARCODE_CODE128,
    BARCODE_CODE39,
    BARCODE_CODE93,
    BARCODE_CODE11,
    BARCODE_EAN13,
    BARCODE_EAN8,
    BARCODE_UPC_A,
    BARCODE_UPC_E,
    BARCODE_EAN_SUPP,
    BARCODE_ITF,
    BARCODE_STF,
    BARCODE_CODABAR,
  ];

  static final $core.Map<$core.int, BarcodeSymbology> _byValue =
      $pb.ProtobufEnum.initByValue(values);
  static BarcodeSymbology? valueOf($core.int value) => _byValue[value];

  const BarcodeSymbology._(super.value, super.name);
}

class BarcodeCaptionPosition extends $pb.ProtobufEnum {
  static const BarcodeCaptionPosition CAPTION_NONE =
      BarcodeCaptionPosition._(0, _omitEnumNames ? '' : 'CAPTION_NONE');
  static const BarcodeCaptionPosition CAPTION_BOTTOM =
      BarcodeCaptionPosition._(1, _omitEnumNames ? '' : 'CAPTION_BOTTOM');
  static const BarcodeCaptionPosition CAPTION_TOP =
      BarcodeCaptionPosition._(2, _omitEnumNames ? '' : 'CAPTION_TOP');

  static const $core.List<BarcodeCaptionPosition> values =
      <BarcodeCaptionPosition>[
    CAPTION_NONE,
    CAPTION_BOTTOM,
    CAPTION_TOP,
  ];

  static final $core.List<BarcodeCaptionPosition?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static BarcodeCaptionPosition? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const BarcodeCaptionPosition._(super.value, super.name);
}

class BarcodeCheckDigitMode extends $pb.ProtobufEnum {
  /// Symbology default. Mandatory checks are handled by the encoder; optional
  /// check digits are not added unless CHECK_DIGIT_GENERATE is set.
  static const BarcodeCheckDigitMode CHECK_DIGIT_DEFAULT =
      BarcodeCheckDigitMode._(0, _omitEnumNames ? '' : 'CHECK_DIGIT_DEFAULT');
  static const BarcodeCheckDigitMode CHECK_DIGIT_NONE =
      BarcodeCheckDigitMode._(1, _omitEnumNames ? '' : 'CHECK_DIGIT_NONE');
  static const BarcodeCheckDigitMode CHECK_DIGIT_GENERATE =
      BarcodeCheckDigitMode._(2, _omitEnumNames ? '' : 'CHECK_DIGIT_GENERATE');

  static const $core.List<BarcodeCheckDigitMode> values =
      <BarcodeCheckDigitMode>[
    CHECK_DIGIT_DEFAULT,
    CHECK_DIGIT_NONE,
    CHECK_DIGIT_GENERATE,
  ];

  static final $core.List<BarcodeCheckDigitMode?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static BarcodeCheckDigitMode? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const BarcodeCheckDigitMode._(super.value, super.name);
}

class BarcodeTextEncoding extends $pb.ProtobufEnum {
  static const BarcodeTextEncoding BARCODE_TEXT_AUTO =
      BarcodeTextEncoding._(0, _omitEnumNames ? '' : 'BARCODE_TEXT_AUTO');
  static const BarcodeTextEncoding BARCODE_TEXT_ASCII =
      BarcodeTextEncoding._(1, _omitEnumNames ? '' : 'BARCODE_TEXT_ASCII');
  static const BarcodeTextEncoding BARCODE_TEXT_UTF8 =
      BarcodeTextEncoding._(2, _omitEnumNames ? '' : 'BARCODE_TEXT_UTF8');
  static const BarcodeTextEncoding BARCODE_TEXT_GS1 =
      BarcodeTextEncoding._(3, _omitEnumNames ? '' : 'BARCODE_TEXT_GS1');

  static const $core.List<BarcodeTextEncoding> values = <BarcodeTextEncoding>[
    BARCODE_TEXT_AUTO,
    BARCODE_TEXT_ASCII,
    BARCODE_TEXT_UTF8,
    BARCODE_TEXT_GS1,
  ];

  static final $core.List<BarcodeTextEncoding?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static BarcodeTextEncoding? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const BarcodeTextEncoding._(super.value, super.name);
}

class BarcodeQrErrorCorrection extends $pb.ProtobufEnum {
  static const BarcodeQrErrorCorrection QR_ECC_DEFAULT =
      BarcodeQrErrorCorrection._(0, _omitEnumNames ? '' : 'QR_ECC_DEFAULT');
  static const BarcodeQrErrorCorrection QR_ECC_LOW =
      BarcodeQrErrorCorrection._(1, _omitEnumNames ? '' : 'QR_ECC_LOW');
  static const BarcodeQrErrorCorrection QR_ECC_MEDIUM =
      BarcodeQrErrorCorrection._(2, _omitEnumNames ? '' : 'QR_ECC_MEDIUM');
  static const BarcodeQrErrorCorrection QR_ECC_QUARTILE =
      BarcodeQrErrorCorrection._(3, _omitEnumNames ? '' : 'QR_ECC_QUARTILE');
  static const BarcodeQrErrorCorrection QR_ECC_HIGH =
      BarcodeQrErrorCorrection._(4, _omitEnumNames ? '' : 'QR_ECC_HIGH');

  static const $core.List<BarcodeQrErrorCorrection> values =
      <BarcodeQrErrorCorrection>[
    QR_ECC_DEFAULT,
    QR_ECC_LOW,
    QR_ECC_MEDIUM,
    QR_ECC_QUARTILE,
    QR_ECC_HIGH,
  ];

  static final $core.List<BarcodeQrErrorCorrection?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static BarcodeQrErrorCorrection? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const BarcodeQrErrorCorrection._(super.value, super.name);
}

class BarcodeRenderStatus extends $pb.ProtobufEnum {
  static const BarcodeRenderStatus BARCODE_RENDER_STATUS_UNSPECIFIED =
      BarcodeRenderStatus._(
          0, _omitEnumNames ? '' : 'BARCODE_RENDER_STATUS_UNSPECIFIED');
  static const BarcodeRenderStatus BARCODE_RENDER_STATUS_OK =
      BarcodeRenderStatus._(
          1, _omitEnumNames ? '' : 'BARCODE_RENDER_STATUS_OK');
  static const BarcodeRenderStatus BARCODE_RENDER_STATUS_EMPTY_PAYLOAD =
      BarcodeRenderStatus._(
          2, _omitEnumNames ? '' : 'BARCODE_RENDER_STATUS_EMPTY_PAYLOAD');
  static const BarcodeRenderStatus BARCODE_RENDER_STATUS_INVALID_PAYLOAD =
      BarcodeRenderStatus._(
          3, _omitEnumNames ? '' : 'BARCODE_RENDER_STATUS_INVALID_PAYLOAD');
  static const BarcodeRenderStatus BARCODE_RENDER_STATUS_UNSUPPORTED_SYMBOLOGY =
      BarcodeRenderStatus._(4,
          _omitEnumNames ? '' : 'BARCODE_RENDER_STATUS_UNSUPPORTED_SYMBOLOGY');

  static const $core.List<BarcodeRenderStatus> values = <BarcodeRenderStatus>[
    BARCODE_RENDER_STATUS_UNSPECIFIED,
    BARCODE_RENDER_STATUS_OK,
    BARCODE_RENDER_STATUS_EMPTY_PAYLOAD,
    BARCODE_RENDER_STATUS_INVALID_PAYLOAD,
    BARCODE_RENDER_STATUS_UNSUPPORTED_SYMBOLOGY,
  ];

  static final $core.List<BarcodeRenderStatus?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static BarcodeRenderStatus? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const BarcodeRenderStatus._(super.value, super.name);
}

class CheckedState extends $pb.ProtobufEnum {
  static const CheckedState CHECKED_UNCHECKED =
      CheckedState._(0, _omitEnumNames ? '' : 'CHECKED_UNCHECKED');
  static const CheckedState CHECKED_CHECKED =
      CheckedState._(1, _omitEnumNames ? '' : 'CHECKED_CHECKED');
  static const CheckedState CHECKED_GRAYED =
      CheckedState._(2, _omitEnumNames ? '' : 'CHECKED_GRAYED');

  static const $core.List<CheckedState> values = <CheckedState>[
    CHECKED_UNCHECKED,
    CHECKED_CHECKED,
    CHECKED_GRAYED,
  ];

  static final $core.List<CheckedState?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static CheckedState? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const CheckedState._(super.value, super.name);
}

class FillHandlePosition extends $pb.ProtobufEnum {
  static const FillHandlePosition FILL_HANDLE_NONE =
      FillHandlePosition._(0, _omitEnumNames ? '' : 'FILL_HANDLE_NONE');
  static const FillHandlePosition FILL_HANDLE_BOTTOM_RIGHT =
      FillHandlePosition._(1, _omitEnumNames ? '' : 'FILL_HANDLE_BOTTOM_RIGHT');
  static const FillHandlePosition FILL_HANDLE_BOTTOM_LEFT =
      FillHandlePosition._(2, _omitEnumNames ? '' : 'FILL_HANDLE_BOTTOM_LEFT');
  static const FillHandlePosition FILL_HANDLE_TOP_RIGHT =
      FillHandlePosition._(3, _omitEnumNames ? '' : 'FILL_HANDLE_TOP_RIGHT');
  static const FillHandlePosition FILL_HANDLE_TOP_LEFT =
      FillHandlePosition._(4, _omitEnumNames ? '' : 'FILL_HANDLE_TOP_LEFT');
  static const FillHandlePosition FILL_HANDLE_ALL_CORNERS =
      FillHandlePosition._(5, _omitEnumNames ? '' : 'FILL_HANDLE_ALL_CORNERS');

  static const $core.List<FillHandlePosition> values = <FillHandlePosition>[
    FILL_HANDLE_NONE,
    FILL_HANDLE_BOTTOM_RIGHT,
    FILL_HANDLE_BOTTOM_LEFT,
    FILL_HANDLE_TOP_RIGHT,
    FILL_HANDLE_TOP_LEFT,
    FILL_HANDLE_ALL_CORNERS,
  ];

  static final $core.List<FillHandlePosition?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 5);
  static FillHandlePosition? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const FillHandlePosition._(super.value, super.name);
}

class ColumnDataType extends $pb.ProtobufEnum {
  static const ColumnDataType COLUMN_DATA_STRING =
      ColumnDataType._(0, _omitEnumNames ? '' : 'COLUMN_DATA_STRING');
  static const ColumnDataType COLUMN_DATA_NUMBER =
      ColumnDataType._(1, _omitEnumNames ? '' : 'COLUMN_DATA_NUMBER');
  static const ColumnDataType COLUMN_DATA_DATE =
      ColumnDataType._(2, _omitEnumNames ? '' : 'COLUMN_DATA_DATE');
  static const ColumnDataType COLUMN_DATA_BOOLEAN =
      ColumnDataType._(3, _omitEnumNames ? '' : 'COLUMN_DATA_BOOLEAN');
  static const ColumnDataType COLUMN_DATA_CURRENCY =
      ColumnDataType._(4, _omitEnumNames ? '' : 'COLUMN_DATA_CURRENCY');

  static const $core.List<ColumnDataType> values = <ColumnDataType>[
    COLUMN_DATA_STRING,
    COLUMN_DATA_NUMBER,
    COLUMN_DATA_DATE,
    COLUMN_DATA_BOOLEAN,
    COLUMN_DATA_CURRENCY,
  ];

  static final $core.List<ColumnDataType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static ColumnDataType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ColumnDataType._(super.value, super.name);
}

/// Type coercion strategy during cell writes and data loading.
///   STRICT (1):   Rejects if type doesn't match column's declared type.
///   FLEXIBLE (2): Attempts conversion (e.g. "123" → Number 123).
///   PARSE_ONLY (3): Parses but doesn't convert (stores original text).
class CoercionMode extends $pb.ProtobufEnum {
  static const CoercionMode COERCION_UNSPECIFIED =
      CoercionMode._(0, _omitEnumNames ? '' : 'COERCION_UNSPECIFIED');
  static const CoercionMode COERCION_STRICT =
      CoercionMode._(1, _omitEnumNames ? '' : 'COERCION_STRICT');
  static const CoercionMode COERCION_FLEXIBLE =
      CoercionMode._(2, _omitEnumNames ? '' : 'COERCION_FLEXIBLE');
  static const CoercionMode COERCION_PARSE_ONLY =
      CoercionMode._(3, _omitEnumNames ? '' : 'COERCION_PARSE_ONLY');

  static const $core.List<CoercionMode> values = <CoercionMode>[
    COERCION_UNSPECIFIED,
    COERCION_STRICT,
    COERCION_FLEXIBLE,
    COERCION_PARSE_ONLY,
  ];

  static final $core.List<CoercionMode?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static CoercionMode? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const CoercionMode._(super.value, super.name);
}

/// What happens when a cell write fails type validation.
///   REJECT (1):   Cell not written; reported in WriteResult.violations.
///   SET_NULL (2): Clears cell value.
///   SKIP (3):     Keeps old value, no error report.
class WriteErrorMode extends $pb.ProtobufEnum {
  static const WriteErrorMode WRITE_ERROR_UNSPECIFIED =
      WriteErrorMode._(0, _omitEnumNames ? '' : 'WRITE_ERROR_UNSPECIFIED');
  static const WriteErrorMode WRITE_ERROR_REJECT =
      WriteErrorMode._(1, _omitEnumNames ? '' : 'WRITE_ERROR_REJECT');
  static const WriteErrorMode WRITE_ERROR_SET_NULL =
      WriteErrorMode._(2, _omitEnumNames ? '' : 'WRITE_ERROR_SET_NULL');
  static const WriteErrorMode WRITE_ERROR_SKIP =
      WriteErrorMode._(3, _omitEnumNames ? '' : 'WRITE_ERROR_SKIP');

  static const $core.List<WriteErrorMode> values = <WriteErrorMode>[
    WRITE_ERROR_UNSPECIFIED,
    WRITE_ERROR_REJECT,
    WRITE_ERROR_SET_NULL,
    WRITE_ERROR_SKIP,
  ];

  static final $core.List<WriteErrorMode?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static WriteErrorMode? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const WriteErrorMode._(super.value, super.name);
}

class CellInteraction extends $pb.ProtobufEnum {
  static const CellInteraction CELL_INTERACTION_UNSPECIFIED = CellInteraction._(
      0, _omitEnumNames ? '' : 'CELL_INTERACTION_UNSPECIFIED');
  static const CellInteraction CELL_INTERACTION_NONE =
      CellInteraction._(1, _omitEnumNames ? '' : 'CELL_INTERACTION_NONE');
  static const CellInteraction CELL_INTERACTION_TEXT_LINK =
      CellInteraction._(2, _omitEnumNames ? '' : 'CELL_INTERACTION_TEXT_LINK');
  static const CellInteraction CELL_INTERACTION_BUTTON =
      CellInteraction._(3, _omitEnumNames ? '' : 'CELL_INTERACTION_BUTTON');

  static const $core.List<CellInteraction> values = <CellInteraction>[
    CELL_INTERACTION_UNSPECIFIED,
    CELL_INTERACTION_NONE,
    CELL_INTERACTION_TEXT_LINK,
    CELL_INTERACTION_BUTTON,
  ];

  static final $core.List<CellInteraction?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static CellInteraction? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const CellInteraction._(super.value, super.name);
}

/// How the first row of loaded data is interpreted.
///   AUTO (0):      JSON objects use keys as headers; CSV tries to detect.
///   NONE (1):      No headers — uses generic column names (Column 1, 2, …).
///   FIRST_ROW (2): Unconditionally treats first row as column headers.
class HeaderPolicy extends $pb.ProtobufEnum {
  static const HeaderPolicy HEADER_AUTO =
      HeaderPolicy._(0, _omitEnumNames ? '' : 'HEADER_AUTO');
  static const HeaderPolicy HEADER_NONE =
      HeaderPolicy._(1, _omitEnumNames ? '' : 'HEADER_NONE');
  static const HeaderPolicy HEADER_FIRST_ROW =
      HeaderPolicy._(2, _omitEnumNames ? '' : 'HEADER_FIRST_ROW');

  static const $core.List<HeaderPolicy> values = <HeaderPolicy>[
    HEADER_AUTO,
    HEADER_NONE,
    HEADER_FIRST_ROW,
  ];

  static final $core.List<HeaderPolicy?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static HeaderPolicy? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const HeaderPolicy._(super.value, super.name);
}

/// Column type inference strategy during data loading.
///   AUTO_DETECT (0): Scans values to infer type — all numbers → Number,
///                    all true/false → Boolean, all dates → Date, else String.
///   ALL_STRING (1):  Everything stays as text.
///   FROM_SCHEMA (2): Uses existing column data types from grid.
class TypePolicy extends $pb.ProtobufEnum {
  static const TypePolicy TYPE_AUTO_DETECT =
      TypePolicy._(0, _omitEnumNames ? '' : 'TYPE_AUTO_DETECT');
  static const TypePolicy TYPE_ALL_STRING =
      TypePolicy._(1, _omitEnumNames ? '' : 'TYPE_ALL_STRING');
  static const TypePolicy TYPE_FROM_SCHEMA =
      TypePolicy._(2, _omitEnumNames ? '' : 'TYPE_FROM_SCHEMA');

  static const $core.List<TypePolicy> values = <TypePolicy>[
    TYPE_AUTO_DETECT,
    TYPE_ALL_STRING,
    TYPE_FROM_SCHEMA,
  ];

  static final $core.List<TypePolicy?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static TypePolicy? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const TypePolicy._(super.value, super.name);
}

/// Data loading mode.
///   UNSPECIFIED (0): Invalid in LoadDataOptions.mode.
///   REPLACE (1):     Clears all cells and resets to new dimensions.
///   APPEND (2):      Inserts data after existing rows; preserves current schema.
class LoadMode extends $pb.ProtobufEnum {
  static const LoadMode LOAD_MODE_UNSPECIFIED =
      LoadMode._(0, _omitEnumNames ? '' : 'LOAD_MODE_UNSPECIFIED');
  static const LoadMode LOAD_REPLACE =
      LoadMode._(1, _omitEnumNames ? '' : 'LOAD_REPLACE');
  static const LoadMode LOAD_APPEND =
      LoadMode._(2, _omitEnumNames ? '' : 'LOAD_APPEND');

  static const $core.List<LoadMode> values = <LoadMode>[
    LOAD_MODE_UNSPECIFIED,
    LOAD_REPLACE,
    LOAD_APPEND,
  ];

  static final $core.List<LoadMode?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static LoadMode? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const LoadMode._(super.value, super.name);
}

class LoadDataStatus extends $pb.ProtobufEnum {
  static const LoadDataStatus LOAD_OK =
      LoadDataStatus._(0, _omitEnumNames ? '' : 'LOAD_OK');
  static const LoadDataStatus LOAD_PARTIAL =
      LoadDataStatus._(1, _omitEnumNames ? '' : 'LOAD_PARTIAL');
  static const LoadDataStatus LOAD_FAILED =
      LoadDataStatus._(2, _omitEnumNames ? '' : 'LOAD_FAILED');

  static const $core.List<LoadDataStatus> values = <LoadDataStatus>[
    LOAD_OK,
    LOAD_PARTIAL,
    LOAD_FAILED,
  ];

  static final $core.List<LoadDataStatus?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static LoadDataStatus? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const LoadDataStatus._(super.value, super.name);
}

/// How user selection is interpreted. See engine/src/selection.rs.
///
/// FREE (0):        Standard rectangular cell-range selection.
///                  Single contiguous range (row, col, row_end, col_end).
/// BY_ROW (1):      Any click selects the entire row. Internally the
///                  selection range spans col 0..i32::MAX.
/// BY_COLUMN (2):   Any click selects the entire column. Range spans
///                  row 0..i32::MAX.
/// LISTBOX (3):     Row-based toggle selection. Tracks selected rows in a
///                  HashSet<i32>. Plain click selects one row, Ctrl+Click
///                  toggles, Shift+Click extends from anchor.
/// MULTI_RANGE (4): Multiple independent rectangular ranges. The primary
///                  range plus extra_ranges: Vec<(i32,i32,i32,i32)>.
class SelectionMode extends $pb.ProtobufEnum {
  static const SelectionMode SELECTION_FREE =
      SelectionMode._(0, _omitEnumNames ? '' : 'SELECTION_FREE');
  static const SelectionMode SELECTION_BY_ROW =
      SelectionMode._(1, _omitEnumNames ? '' : 'SELECTION_BY_ROW');
  static const SelectionMode SELECTION_BY_COLUMN =
      SelectionMode._(2, _omitEnumNames ? '' : 'SELECTION_BY_COLUMN');
  static const SelectionMode SELECTION_LISTBOX =
      SelectionMode._(3, _omitEnumNames ? '' : 'SELECTION_LISTBOX');
  static const SelectionMode SELECTION_MULTI_RANGE =
      SelectionMode._(4, _omitEnumNames ? '' : 'SELECTION_MULTI_RANGE');

  static const $core.List<SelectionMode> values = <SelectionMode>[
    SELECTION_FREE,
    SELECTION_BY_ROW,
    SELECTION_BY_COLUMN,
    SELECTION_LISTBOX,
    SELECTION_MULTI_RANGE,
  ];

  static final $core.List<SelectionMode?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static SelectionMode? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const SelectionMode._(super.value, super.name);
}

class FocusBorderStyle extends $pb.ProtobufEnum {
  static const FocusBorderStyle FOCUS_BORDER_NONE =
      FocusBorderStyle._(0, _omitEnumNames ? '' : 'FOCUS_BORDER_NONE');
  static const FocusBorderStyle FOCUS_BORDER_THIN =
      FocusBorderStyle._(1, _omitEnumNames ? '' : 'FOCUS_BORDER_THIN');
  static const FocusBorderStyle FOCUS_BORDER_THICK =
      FocusBorderStyle._(2, _omitEnumNames ? '' : 'FOCUS_BORDER_THICK');
  static const FocusBorderStyle FOCUS_BORDER_INSET =
      FocusBorderStyle._(3, _omitEnumNames ? '' : 'FOCUS_BORDER_INSET');
  static const FocusBorderStyle FOCUS_BORDER_RAISED =
      FocusBorderStyle._(4, _omitEnumNames ? '' : 'FOCUS_BORDER_RAISED');

  static const $core.List<FocusBorderStyle> values = <FocusBorderStyle>[
    FOCUS_BORDER_NONE,
    FOCUS_BORDER_THIN,
    FOCUS_BORDER_THICK,
    FOCUS_BORDER_INSET,
    FOCUS_BORDER_RAISED,
  ];

  static final $core.List<FocusBorderStyle?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static FocusBorderStyle? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const FocusBorderStyle._(super.value, super.name);
}

class SelectionVisibility extends $pb.ProtobufEnum {
  static const SelectionVisibility SELECTION_VIS_NONE =
      SelectionVisibility._(0, _omitEnumNames ? '' : 'SELECTION_VIS_NONE');
  static const SelectionVisibility SELECTION_VIS_ALWAYS =
      SelectionVisibility._(1, _omitEnumNames ? '' : 'SELECTION_VIS_ALWAYS');
  static const SelectionVisibility SELECTION_VIS_WHEN_FOCUSED =
      SelectionVisibility._(
          2, _omitEnumNames ? '' : 'SELECTION_VIS_WHEN_FOCUSED');

  static const $core.List<SelectionVisibility> values = <SelectionVisibility>[
    SELECTION_VIS_NONE,
    SELECTION_VIS_ALWAYS,
    SELECTION_VIS_WHEN_FOCUSED,
  ];

  static final $core.List<SelectionVisibility?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static SelectionVisibility? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const SelectionVisibility._(super.value, super.name);
}

/// Controls how cell editing is activated. See engine/src/input.rs.
///   NONE (0):      Editing disabled.
///   KEY (1):       Enter/F2 starts editing. Character keys auto-start.
///   KEY_CLICK (2): Same as KEY, plus double-click and dropdown click
///                  also start editing.
class EditTrigger extends $pb.ProtobufEnum {
  static const EditTrigger EDIT_TRIGGER_NONE =
      EditTrigger._(0, _omitEnumNames ? '' : 'EDIT_TRIGGER_NONE');
  static const EditTrigger EDIT_TRIGGER_KEY =
      EditTrigger._(1, _omitEnumNames ? '' : 'EDIT_TRIGGER_KEY');
  static const EditTrigger EDIT_TRIGGER_KEY_CLICK =
      EditTrigger._(2, _omitEnumNames ? '' : 'EDIT_TRIGGER_KEY_CLICK');

  static const $core.List<EditTrigger> values = <EditTrigger>[
    EDIT_TRIGGER_NONE,
    EDIT_TRIGGER_KEY,
    EDIT_TRIGGER_KEY_CLICK,
  ];

  static final $core.List<EditTrigger?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static EditTrigger? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const EditTrigger._(super.value, super.name);
}

class DropdownTrigger extends $pb.ProtobufEnum {
  static const DropdownTrigger DROPDOWN_NEVER =
      DropdownTrigger._(0, _omitEnumNames ? '' : 'DROPDOWN_NEVER');
  static const DropdownTrigger DROPDOWN_ALWAYS =
      DropdownTrigger._(1, _omitEnumNames ? '' : 'DROPDOWN_ALWAYS');
  static const DropdownTrigger DROPDOWN_ON_EDIT =
      DropdownTrigger._(2, _omitEnumNames ? '' : 'DROPDOWN_ON_EDIT');

  static const $core.List<DropdownTrigger> values = <DropdownTrigger>[
    DROPDOWN_NEVER,
    DROPDOWN_ALWAYS,
    DROPDOWN_ON_EDIT,
  ];

  static final $core.List<DropdownTrigger?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static DropdownTrigger? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const DropdownTrigger._(super.value, super.name);
}

class TabBehavior extends $pb.ProtobufEnum {
  static const TabBehavior TAB_CONTROLS =
      TabBehavior._(0, _omitEnumNames ? '' : 'TAB_CONTROLS');
  static const TabBehavior TAB_CELLS =
      TabBehavior._(1, _omitEnumNames ? '' : 'TAB_CELLS');

  static const $core.List<TabBehavior> values = <TabBehavior>[
    TAB_CONTROLS,
    TAB_CELLS,
  ];

  static final $core.List<TabBehavior?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 1);
  static TabBehavior? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const TabBehavior._(super.value, super.name);
}

class SortOrder extends $pb.ProtobufEnum {
  static const SortOrder SORT_NONE =
      SortOrder._(0, _omitEnumNames ? '' : 'SORT_NONE');
  static const SortOrder SORT_ASCENDING =
      SortOrder._(1, _omitEnumNames ? '' : 'SORT_ASCENDING');
  static const SortOrder SORT_DESCENDING =
      SortOrder._(2, _omitEnumNames ? '' : 'SORT_DESCENDING');

  static const $core.List<SortOrder> values = <SortOrder>[
    SORT_NONE,
    SORT_ASCENDING,
    SORT_DESCENDING,
  ];

  static final $core.List<SortOrder?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static SortOrder? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const SortOrder._(super.value, super.name);
}

/// Comparison strategy for sorting.
///   AUTO (0):           Tries date, then number, then case-insensitive string.
///   NUMERIC (1):        Parses as f64; non-numeric values sort to the end.
///   STRING (2):         Lexicographic, case-sensitive.
///   STRING_NO_CASE (3): Lexicographic, case-insensitive.
///   CUSTOM (4):         Engine emits CompareEvent on EventStream; host
///                       replies with CompareResponse on RenderSession input
///                       (-1/0/1). Falls back to the generic/date path if no
///                       EventStream subscriber is active or the host does
///                       not reply within 250 ms.
class SortType extends $pb.ProtobufEnum {
  static const SortType SORT_TYPE_AUTO =
      SortType._(0, _omitEnumNames ? '' : 'SORT_TYPE_AUTO');
  static const SortType SORT_TYPE_NUMERIC =
      SortType._(1, _omitEnumNames ? '' : 'SORT_TYPE_NUMERIC');
  static const SortType SORT_TYPE_STRING =
      SortType._(2, _omitEnumNames ? '' : 'SORT_TYPE_STRING');
  static const SortType SORT_TYPE_STRING_NO_CASE =
      SortType._(3, _omitEnumNames ? '' : 'SORT_TYPE_STRING_NO_CASE');
  static const SortType SORT_TYPE_CUSTOM =
      SortType._(4, _omitEnumNames ? '' : 'SORT_TYPE_CUSTOM');

  static const $core.List<SortType> values = <SortType>[
    SORT_TYPE_AUTO,
    SORT_TYPE_NUMERIC,
    SORT_TYPE_STRING,
    SORT_TYPE_STRING_NO_CASE,
    SORT_TYPE_CUSTOM,
  ];

  static final $core.List<SortType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static SortType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const SortType._(super.value, super.name);
}

class TreeIndicatorStyle extends $pb.ProtobufEnum {
  static const TreeIndicatorStyle TREE_INDICATOR_NONE =
      TreeIndicatorStyle._(0, _omitEnumNames ? '' : 'TREE_INDICATOR_NONE');
  static const TreeIndicatorStyle TREE_INDICATOR_ARROWS =
      TreeIndicatorStyle._(1, _omitEnumNames ? '' : 'TREE_INDICATOR_ARROWS');
  static const TreeIndicatorStyle TREE_INDICATOR_ARROWS_LEAF =
      TreeIndicatorStyle._(
          2, _omitEnumNames ? '' : 'TREE_INDICATOR_ARROWS_LEAF');
  static const TreeIndicatorStyle TREE_INDICATOR_CONNECTORS =
      TreeIndicatorStyle._(
          3, _omitEnumNames ? '' : 'TREE_INDICATOR_CONNECTORS');
  static const TreeIndicatorStyle TREE_INDICATOR_CONNECTORS_LEAF =
      TreeIndicatorStyle._(
          4, _omitEnumNames ? '' : 'TREE_INDICATOR_CONNECTORS_LEAF');

  static const $core.List<TreeIndicatorStyle> values = <TreeIndicatorStyle>[
    TREE_INDICATOR_NONE,
    TREE_INDICATOR_ARROWS,
    TREE_INDICATOR_ARROWS_LEAF,
    TREE_INDICATOR_CONNECTORS,
    TREE_INDICATOR_CONNECTORS_LEAF,
  ];

  static final $core.List<TreeIndicatorStyle?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static TreeIndicatorStyle? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const TreeIndicatorStyle._(super.value, super.name);
}

class GroupTotalPosition extends $pb.ProtobufEnum {
  static const GroupTotalPosition GROUP_TOTAL_ABOVE =
      GroupTotalPosition._(0, _omitEnumNames ? '' : 'GROUP_TOTAL_ABOVE');
  static const GroupTotalPosition GROUP_TOTAL_BELOW =
      GroupTotalPosition._(1, _omitEnumNames ? '' : 'GROUP_TOTAL_BELOW');

  static const $core.List<GroupTotalPosition> values = <GroupTotalPosition>[
    GROUP_TOTAL_ABOVE,
    GROUP_TOTAL_BELOW,
  ];

  static final $core.List<GroupTotalPosition?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 1);
  static GroupTotalPosition? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const GroupTotalPosition._(super.value, super.name);
}

/// Aggregate functions for Subtotal() and Aggregate() RPCs.
/// Numeric parsing strips $, commas, and spaces before computing.
///   NONE (0):    No-op.
///   CLEAR (1):   Removes all existing subtotal rows.
///   SUM (2):     Sum of numeric values.
///   PERCENT (3): 100.0 if sum ≠ 0, else 0.0.
///   COUNT (4):   Count of numeric cells.
///   AVERAGE (5): Arithmetic mean.
///   MAX (6):     Maximum value.
///   MIN (7):     Minimum value.
///   STD_DEV (8): Sample standard deviation (N−1 denominator).
///   VAR (9):     Sample variance (N−1 denominator).
class AggregateType extends $pb.ProtobufEnum {
  static const AggregateType AGG_NONE =
      AggregateType._(0, _omitEnumNames ? '' : 'AGG_NONE');
  static const AggregateType AGG_CLEAR =
      AggregateType._(1, _omitEnumNames ? '' : 'AGG_CLEAR');
  static const AggregateType AGG_SUM =
      AggregateType._(2, _omitEnumNames ? '' : 'AGG_SUM');
  static const AggregateType AGG_PERCENT =
      AggregateType._(3, _omitEnumNames ? '' : 'AGG_PERCENT');
  static const AggregateType AGG_COUNT =
      AggregateType._(4, _omitEnumNames ? '' : 'AGG_COUNT');
  static const AggregateType AGG_AVERAGE =
      AggregateType._(5, _omitEnumNames ? '' : 'AGG_AVERAGE');
  static const AggregateType AGG_MAX =
      AggregateType._(6, _omitEnumNames ? '' : 'AGG_MAX');
  static const AggregateType AGG_MIN =
      AggregateType._(7, _omitEnumNames ? '' : 'AGG_MIN');
  static const AggregateType AGG_STD_DEV =
      AggregateType._(8, _omitEnumNames ? '' : 'AGG_STD_DEV');
  static const AggregateType AGG_VAR =
      AggregateType._(9, _omitEnumNames ? '' : 'AGG_VAR');

  static const $core.List<AggregateType> values = <AggregateType>[
    AGG_NONE,
    AGG_CLEAR,
    AGG_SUM,
    AGG_PERCENT,
    AGG_COUNT,
    AGG_AVERAGE,
    AGG_MAX,
    AGG_MIN,
    AGG_STD_DEV,
    AGG_VAR,
  ];

  static final $core.List<AggregateType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 9);
  static AggregateType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const AggregateType._(super.value, super.name);
}

/// Content-based cell merging. The engine compares adjacent cell values
/// and visually merges cells with identical content. See engine/src/span.rs.
/// Spans never cross fixed/frozen/pinned boundaries or subtotal rows.
///
///   NONE (0):        No spanning.
///   FREE (1):        Expand in all directions (up/down/left/right).
///   BY_ROW (2):      Vertical spanning only. Left-column dependency:
///                    adjacent left cells must also match.
///   BY_COLUMN (3):   Horizontal spanning only. No above-cell dependency.
///   ADJACENT (4):    Either row OR column spanning (whichever matches).
///   HEADER_ONLY (5): Only span in fixed/frozen cells, not data cells.
///   SPILL (6):       Text spills right into empty adjacent cells.
///   GROUP (7):       Like SPILL but only on subtotal rows.
class CellSpanMode extends $pb.ProtobufEnum {
  static const CellSpanMode CELL_SPAN_NONE =
      CellSpanMode._(0, _omitEnumNames ? '' : 'CELL_SPAN_NONE');
  static const CellSpanMode CELL_SPAN_FREE =
      CellSpanMode._(1, _omitEnumNames ? '' : 'CELL_SPAN_FREE');
  static const CellSpanMode CELL_SPAN_BY_ROW =
      CellSpanMode._(2, _omitEnumNames ? '' : 'CELL_SPAN_BY_ROW');
  static const CellSpanMode CELL_SPAN_BY_COLUMN =
      CellSpanMode._(3, _omitEnumNames ? '' : 'CELL_SPAN_BY_COLUMN');
  static const CellSpanMode CELL_SPAN_ADJACENT =
      CellSpanMode._(4, _omitEnumNames ? '' : 'CELL_SPAN_ADJACENT');
  static const CellSpanMode CELL_SPAN_HEADER_ONLY =
      CellSpanMode._(5, _omitEnumNames ? '' : 'CELL_SPAN_HEADER_ONLY');
  static const CellSpanMode CELL_SPAN_SPILL =
      CellSpanMode._(6, _omitEnumNames ? '' : 'CELL_SPAN_SPILL');
  static const CellSpanMode CELL_SPAN_GROUP =
      CellSpanMode._(7, _omitEnumNames ? '' : 'CELL_SPAN_GROUP');

  static const $core.List<CellSpanMode> values = <CellSpanMode>[
    CELL_SPAN_NONE,
    CELL_SPAN_FREE,
    CELL_SPAN_BY_ROW,
    CELL_SPAN_BY_COLUMN,
    CELL_SPAN_ADJACENT,
    CELL_SPAN_HEADER_ONLY,
    CELL_SPAN_SPILL,
    CELL_SPAN_GROUP,
  ];

  static final $core.List<CellSpanMode?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 7);
  static CellSpanMode? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const CellSpanMode._(super.value, super.name);
}

/// Text normalization used when comparing cells for content-based spans
/// and subtotal/group keys.
class SpanCompareMode extends $pb.ProtobufEnum {
  static const SpanCompareMode SPAN_COMPARE_EXACT =
      SpanCompareMode._(0, _omitEnumNames ? '' : 'SPAN_COMPARE_EXACT');
  static const SpanCompareMode SPAN_COMPARE_NO_CASE =
      SpanCompareMode._(1, _omitEnumNames ? '' : 'SPAN_COMPARE_NO_CASE');
  static const SpanCompareMode SPAN_COMPARE_TRIM_NO_CASE =
      SpanCompareMode._(2, _omitEnumNames ? '' : 'SPAN_COMPARE_TRIM_NO_CASE');
  static const SpanCompareMode SPAN_COMPARE_INCLUDE_NULLS =
      SpanCompareMode._(3, _omitEnumNames ? '' : 'SPAN_COMPARE_INCLUDE_NULLS');

  static const $core.List<SpanCompareMode> values = <SpanCompareMode>[
    SPAN_COMPARE_EXACT,
    SPAN_COMPARE_NO_CASE,
    SPAN_COMPARE_TRIM_NO_CASE,
    SPAN_COMPARE_INCLUDE_NULLS,
  ];

  static final $core.List<SpanCompareMode?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static SpanCompareMode? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const SpanCompareMode._(super.value, super.name);
}

class ScrollBarsMode extends $pb.ProtobufEnum {
  static const ScrollBarsMode SCROLLBAR_NONE =
      ScrollBarsMode._(0, _omitEnumNames ? '' : 'SCROLLBAR_NONE');
  static const ScrollBarsMode SCROLLBAR_HORIZONTAL =
      ScrollBarsMode._(1, _omitEnumNames ? '' : 'SCROLLBAR_HORIZONTAL');
  static const ScrollBarsMode SCROLLBAR_VERTICAL =
      ScrollBarsMode._(2, _omitEnumNames ? '' : 'SCROLLBAR_VERTICAL');
  static const ScrollBarsMode SCROLLBAR_BOTH =
      ScrollBarsMode._(3, _omitEnumNames ? '' : 'SCROLLBAR_BOTH');

  static const $core.List<ScrollBarsMode> values = <ScrollBarsMode>[
    SCROLLBAR_NONE,
    SCROLLBAR_HORIZONTAL,
    SCROLLBAR_VERTICAL,
    SCROLLBAR_BOTH,
  ];

  static final $core.List<ScrollBarsMode?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static ScrollBarsMode? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ScrollBarsMode._(super.value, super.name);
}

class ScrollBarMode extends $pb.ProtobufEnum {
  static const ScrollBarMode SCROLLBAR_MODE_AUTO =
      ScrollBarMode._(0, _omitEnumNames ? '' : 'SCROLLBAR_MODE_AUTO');
  static const ScrollBarMode SCROLLBAR_MODE_ALWAYS =
      ScrollBarMode._(1, _omitEnumNames ? '' : 'SCROLLBAR_MODE_ALWAYS');
  static const ScrollBarMode SCROLLBAR_MODE_NEVER =
      ScrollBarMode._(2, _omitEnumNames ? '' : 'SCROLLBAR_MODE_NEVER');

  static const $core.List<ScrollBarMode> values = <ScrollBarMode>[
    SCROLLBAR_MODE_AUTO,
    SCROLLBAR_MODE_ALWAYS,
    SCROLLBAR_MODE_NEVER,
  ];

  static final $core.List<ScrollBarMode?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static ScrollBarMode? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ScrollBarMode._(super.value, super.name);
}

class ScrollBarAppearance extends $pb.ProtobufEnum {
  static const ScrollBarAppearance SCROLLBAR_APPEARANCE_CLASSIC =
      ScrollBarAppearance._(
          0, _omitEnumNames ? '' : 'SCROLLBAR_APPEARANCE_CLASSIC');
  static const ScrollBarAppearance SCROLLBAR_APPEARANCE_FLAT =
      ScrollBarAppearance._(
          1, _omitEnumNames ? '' : 'SCROLLBAR_APPEARANCE_FLAT');
  static const ScrollBarAppearance SCROLLBAR_APPEARANCE_MODERN =
      ScrollBarAppearance._(
          2, _omitEnumNames ? '' : 'SCROLLBAR_APPEARANCE_MODERN');
  static const ScrollBarAppearance SCROLLBAR_APPEARANCE_OVERLAY =
      ScrollBarAppearance._(
          3, _omitEnumNames ? '' : 'SCROLLBAR_APPEARANCE_OVERLAY');

  static const $core.List<ScrollBarAppearance> values = <ScrollBarAppearance>[
    SCROLLBAR_APPEARANCE_CLASSIC,
    SCROLLBAR_APPEARANCE_FLAT,
    SCROLLBAR_APPEARANCE_MODERN,
    SCROLLBAR_APPEARANCE_OVERLAY,
  ];

  static final $core.List<ScrollBarAppearance?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static ScrollBarAppearance? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ScrollBarAppearance._(super.value, super.name);
}

class PinPosition extends $pb.ProtobufEnum {
  static const PinPosition PIN_NONE =
      PinPosition._(0, _omitEnumNames ? '' : 'PIN_NONE');
  static const PinPosition PIN_TOP =
      PinPosition._(1, _omitEnumNames ? '' : 'PIN_TOP');
  static const PinPosition PIN_BOTTOM =
      PinPosition._(2, _omitEnumNames ? '' : 'PIN_BOTTOM');

  static const $core.List<PinPosition> values = <PinPosition>[
    PIN_NONE,
    PIN_TOP,
    PIN_BOTTOM,
  ];

  static final $core.List<PinPosition?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static PinPosition? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const PinPosition._(super.value, super.name);
}

class StickyEdge extends $pb.ProtobufEnum {
  static const StickyEdge STICKY_NONE =
      StickyEdge._(0, _omitEnumNames ? '' : 'STICKY_NONE');
  static const StickyEdge STICKY_TOP =
      StickyEdge._(1, _omitEnumNames ? '' : 'STICKY_TOP');
  static const StickyEdge STICKY_BOTTOM =
      StickyEdge._(2, _omitEnumNames ? '' : 'STICKY_BOTTOM');
  static const StickyEdge STICKY_LEFT =
      StickyEdge._(3, _omitEnumNames ? '' : 'STICKY_LEFT');
  static const StickyEdge STICKY_RIGHT =
      StickyEdge._(4, _omitEnumNames ? '' : 'STICKY_RIGHT');
  static const StickyEdge STICKY_BOTH =
      StickyEdge._(5, _omitEnumNames ? '' : 'STICKY_BOTH');

  static const $core.List<StickyEdge> values = <StickyEdge>[
    STICKY_NONE,
    STICKY_TOP,
    STICKY_BOTTOM,
    STICKY_LEFT,
    STICKY_RIGHT,
    STICKY_BOTH,
  ];

  static final $core.List<StickyEdge?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 5);
  static StickyEdge? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const StickyEdge._(super.value, super.name);
}

/// Type-ahead (incremental search) mode. See engine/src/search.rs.
/// The engine buffers keystrokes and searches for matching cell text.
///   NONE (0):        Disabled.
///   FROM_START (1):  Search from the first data row.
///   FROM_CURSOR (2): Search from the current cursor row.
/// Default type_ahead_delay: 2000 ms.
class TypeAheadMode extends $pb.ProtobufEnum {
  static const TypeAheadMode TYPE_AHEAD_NONE =
      TypeAheadMode._(0, _omitEnumNames ? '' : 'TYPE_AHEAD_NONE');
  static const TypeAheadMode TYPE_AHEAD_FROM_START =
      TypeAheadMode._(1, _omitEnumNames ? '' : 'TYPE_AHEAD_FROM_START');
  static const TypeAheadMode TYPE_AHEAD_FROM_CURSOR =
      TypeAheadMode._(2, _omitEnumNames ? '' : 'TYPE_AHEAD_FROM_CURSOR');

  static const $core.List<TypeAheadMode> values = <TypeAheadMode>[
    TYPE_AHEAD_NONE,
    TYPE_AHEAD_FROM_START,
    TYPE_AHEAD_FROM_CURSOR,
  ];

  static final $core.List<TypeAheadMode?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static TypeAheadMode? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const TypeAheadMode._(super.value, super.name);
}

class AutoSizeMode extends $pb.ProtobufEnum {
  static const AutoSizeMode AUTOSIZE_BOTH =
      AutoSizeMode._(0, _omitEnumNames ? '' : 'AUTOSIZE_BOTH');
  static const AutoSizeMode AUTOSIZE_COL_WIDTH =
      AutoSizeMode._(1, _omitEnumNames ? '' : 'AUTOSIZE_COL_WIDTH');
  static const AutoSizeMode AUTOSIZE_ROW_HEIGHT =
      AutoSizeMode._(2, _omitEnumNames ? '' : 'AUTOSIZE_ROW_HEIGHT');

  static const $core.List<AutoSizeMode> values = <AutoSizeMode>[
    AUTOSIZE_BOTH,
    AUTOSIZE_COL_WIDTH,
    AUTOSIZE_ROW_HEIGHT,
  ];

  static final $core.List<AutoSizeMode?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static AutoSizeMode? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const AutoSizeMode._(super.value, super.name);
}

class DragMode extends $pb.ProtobufEnum {
  static const DragMode DRAG_NONE =
      DragMode._(0, _omitEnumNames ? '' : 'DRAG_NONE');
  static const DragMode DRAG_MANUAL =
      DragMode._(1, _omitEnumNames ? '' : 'DRAG_MANUAL');
  static const DragMode DRAG_AUTOMATIC =
      DragMode._(2, _omitEnumNames ? '' : 'DRAG_AUTOMATIC');

  static const $core.List<DragMode> values = <DragMode>[
    DRAG_NONE,
    DRAG_MANUAL,
    DRAG_AUTOMATIC,
  ];

  static final $core.List<DragMode?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static DragMode? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const DragMode._(super.value, super.name);
}

class DropMode extends $pb.ProtobufEnum {
  static const DropMode DROP_NONE =
      DropMode._(0, _omitEnumNames ? '' : 'DROP_NONE');
  static const DropMode DROP_MANUAL =
      DropMode._(1, _omitEnumNames ? '' : 'DROP_MANUAL');
  static const DropMode DROP_AUTOMATIC =
      DropMode._(2, _omitEnumNames ? '' : 'DROP_AUTOMATIC');

  static const $core.List<DropMode> values = <DropMode>[
    DROP_NONE,
    DROP_MANUAL,
    DROP_AUTOMATIC,
  ];

  static final $core.List<DropMode?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static DropMode? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const DropMode._(super.value, super.name);
}

class CustomRenderMode extends $pb.ProtobufEnum {
  static const CustomRenderMode CUSTOM_RENDER_NONE =
      CustomRenderMode._(0, _omitEnumNames ? '' : 'CUSTOM_RENDER_NONE');
  static const CustomRenderMode CUSTOM_RENDER_CELL =
      CustomRenderMode._(1, _omitEnumNames ? '' : 'CUSTOM_RENDER_CELL');
  static const CustomRenderMode CUSTOM_RENDER_ROW =
      CustomRenderMode._(2, _omitEnumNames ? '' : 'CUSTOM_RENDER_ROW');

  static const $core.List<CustomRenderMode> values = <CustomRenderMode>[
    CUSTOM_RENDER_NONE,
    CUSTOM_RENDER_CELL,
    CUSTOM_RENDER_ROW,
  ];

  static final $core.List<CustomRenderMode?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static CustomRenderMode? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const CustomRenderMode._(super.value, super.name);
}

class ApplyScope extends $pb.ProtobufEnum {
  static const ApplyScope APPLY_SINGLE =
      ApplyScope._(0, _omitEnumNames ? '' : 'APPLY_SINGLE');
  static const ApplyScope APPLY_SELECTION =
      ApplyScope._(1, _omitEnumNames ? '' : 'APPLY_SELECTION');

  static const $core.List<ApplyScope> values = <ApplyScope>[
    APPLY_SINGLE,
    APPLY_SELECTION,
  ];

  static final $core.List<ApplyScope?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 1);
  static ApplyScope? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ApplyScope._(super.value, super.name);
}

/// Rendering backend selection. See GUI.md and TUI.md.
///   AUTO (0): Engine picks CPU or GPU based on host capabilities.
///   CPU (1):  Renders into a host-owned RGBA buffer (most portable).
///   GPU (2):  Renders via wgpu to a host-provided native surface.
///   TUI (5):  Terminal mode — renders ANSI escape sequences.
/// If GPU initialization fails, the engine falls back to CPU silently.
class RendererMode extends $pb.ProtobufEnum {
  static const RendererMode RENDERER_AUTO =
      RendererMode._(0, _omitEnumNames ? '' : 'RENDERER_AUTO');
  static const RendererMode RENDERER_CPU =
      RendererMode._(1, _omitEnumNames ? '' : 'RENDERER_CPU');
  static const RendererMode RENDERER_GPU =
      RendererMode._(2, _omitEnumNames ? '' : 'RENDERER_GPU');
  static const RendererMode RENDERER_GPU_VULKAN =
      RendererMode._(3, _omitEnumNames ? '' : 'RENDERER_GPU_VULKAN');
  static const RendererMode RENDERER_GPU_GLES =
      RendererMode._(4, _omitEnumNames ? '' : 'RENDERER_GPU_GLES');
  static const RendererMode RENDERER_TUI =
      RendererMode._(5, _omitEnumNames ? '' : 'RENDERER_TUI');

  static const $core.List<RendererMode> values = <RendererMode>[
    RENDERER_AUTO,
    RENDERER_CPU,
    RENDERER_GPU,
    RENDERER_GPU_VULKAN,
    RENDERER_GPU_GLES,
    RENDERER_TUI,
  ];

  static final $core.List<RendererMode?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 5);
  static RendererMode? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const RendererMode._(super.value, super.name);
}

class PresentMode extends $pb.ProtobufEnum {
  static const PresentMode PRESENT_AUTO =
      PresentMode._(0, _omitEnumNames ? '' : 'PRESENT_AUTO');
  static const PresentMode PRESENT_FIFO =
      PresentMode._(1, _omitEnumNames ? '' : 'PRESENT_FIFO');
  static const PresentMode PRESENT_MAILBOX =
      PresentMode._(2, _omitEnumNames ? '' : 'PRESENT_MAILBOX');
  static const PresentMode PRESENT_IMMEDIATE =
      PresentMode._(3, _omitEnumNames ? '' : 'PRESENT_IMMEDIATE');

  static const $core.List<PresentMode> values = <PresentMode>[
    PRESENT_AUTO,
    PRESENT_FIFO,
    PRESENT_MAILBOX,
    PRESENT_IMMEDIATE,
  ];

  static final $core.List<PresentMode?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static PresentMode? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const PresentMode._(super.value, super.name);
}

class FramePacingMode extends $pb.ProtobufEnum {
  static const FramePacingMode FRAME_PACING_MODE_AUTO =
      FramePacingMode._(0, _omitEnumNames ? '' : 'FRAME_PACING_MODE_AUTO');
  static const FramePacingMode FRAME_PACING_MODE_PLATFORM =
      FramePacingMode._(1, _omitEnumNames ? '' : 'FRAME_PACING_MODE_PLATFORM');
  static const FramePacingMode FRAME_PACING_MODE_UNLIMITED =
      FramePacingMode._(2, _omitEnumNames ? '' : 'FRAME_PACING_MODE_UNLIMITED');
  static const FramePacingMode FRAME_PACING_MODE_FIXED =
      FramePacingMode._(3, _omitEnumNames ? '' : 'FRAME_PACING_MODE_FIXED');

  static const $core.List<FramePacingMode> values = <FramePacingMode>[
    FRAME_PACING_MODE_AUTO,
    FRAME_PACING_MODE_PLATFORM,
    FRAME_PACING_MODE_UNLIMITED,
    FRAME_PACING_MODE_FIXED,
  ];

  static final $core.List<FramePacingMode?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static FramePacingMode? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const FramePacingMode._(super.value, super.name);
}

class ClearScope extends $pb.ProtobufEnum {
  static const ClearScope CLEAR_SCOPE_UNSPECIFIED =
      ClearScope._(0, _omitEnumNames ? '' : 'CLEAR_SCOPE_UNSPECIFIED');
  static const ClearScope CLEAR_EVERYTHING =
      ClearScope._(1, _omitEnumNames ? '' : 'CLEAR_EVERYTHING');
  static const ClearScope CLEAR_FORMATTING =
      ClearScope._(2, _omitEnumNames ? '' : 'CLEAR_FORMATTING');
  static const ClearScope CLEAR_DATA =
      ClearScope._(3, _omitEnumNames ? '' : 'CLEAR_DATA');
  static const ClearScope CLEAR_SELECTION =
      ClearScope._(4, _omitEnumNames ? '' : 'CLEAR_SELECTION');

  static const $core.List<ClearScope> values = <ClearScope>[
    CLEAR_SCOPE_UNSPECIFIED,
    CLEAR_EVERYTHING,
    CLEAR_FORMATTING,
    CLEAR_DATA,
    CLEAR_SELECTION,
  ];

  static final $core.List<ClearScope?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static ClearScope? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ClearScope._(super.value, super.name);
}

class ClearRegion extends $pb.ProtobufEnum {
  static const ClearRegion CLEAR_SCROLLABLE =
      ClearRegion._(0, _omitEnumNames ? '' : 'CLEAR_SCROLLABLE');
  static const ClearRegion CLEAR_FIXED_ROWS =
      ClearRegion._(1, _omitEnumNames ? '' : 'CLEAR_FIXED_ROWS');
  static const ClearRegion CLEAR_FIXED_COLS =
      ClearRegion._(2, _omitEnumNames ? '' : 'CLEAR_FIXED_COLS');
  static const ClearRegion CLEAR_FIXED_BOTH =
      ClearRegion._(3, _omitEnumNames ? '' : 'CLEAR_FIXED_BOTH');
  static const ClearRegion CLEAR_ALL_ROWS =
      ClearRegion._(4, _omitEnumNames ? '' : 'CLEAR_ALL_ROWS');
  static const ClearRegion CLEAR_ALL_COLS =
      ClearRegion._(5, _omitEnumNames ? '' : 'CLEAR_ALL_COLS');
  static const ClearRegion CLEAR_ALL_BOTH =
      ClearRegion._(6, _omitEnumNames ? '' : 'CLEAR_ALL_BOTH');

  static const $core.List<ClearRegion> values = <ClearRegion>[
    CLEAR_SCROLLABLE,
    CLEAR_FIXED_ROWS,
    CLEAR_FIXED_COLS,
    CLEAR_FIXED_BOTH,
    CLEAR_ALL_ROWS,
    CLEAR_ALL_COLS,
    CLEAR_ALL_BOTH,
  ];

  static final $core.List<ClearRegion?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 6);
  static ClearRegion? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ClearRegion._(super.value, super.name);
}

/// Export formats. See engine/src/save.rs.
///   UNSPECIFIED (0): Invalid in ExportRequest.format.
///   BINARY (1):    FXGD binary — header "FXGD" + dimensions + cell data +
///                  styles + column/row properties. Preserves full fidelity.
///   TSV (2):       Tab-separated values. Text only.
///   CSV (3):       Comma-separated values. Quotes cells containing
///                  separator, newline, or quote characters.
///   DELIMITED (4): Uses the grid's clip_col_separator (default "\t").
///   XLSX (5):      SpreadsheetML XML (Excel 2003 .xml format). Applies
///                  bold to fixed rows, auto-detects numeric cells.
class ExportFormat extends $pb.ProtobufEnum {
  static const ExportFormat EXPORT_FORMAT_UNSPECIFIED =
      ExportFormat._(0, _omitEnumNames ? '' : 'EXPORT_FORMAT_UNSPECIFIED');
  static const ExportFormat EXPORT_BINARY =
      ExportFormat._(1, _omitEnumNames ? '' : 'EXPORT_BINARY');
  static const ExportFormat EXPORT_TSV =
      ExportFormat._(2, _omitEnumNames ? '' : 'EXPORT_TSV');
  static const ExportFormat EXPORT_CSV =
      ExportFormat._(3, _omitEnumNames ? '' : 'EXPORT_CSV');
  static const ExportFormat EXPORT_DELIMITED =
      ExportFormat._(4, _omitEnumNames ? '' : 'EXPORT_DELIMITED');
  static const ExportFormat EXPORT_XLSX =
      ExportFormat._(5, _omitEnumNames ? '' : 'EXPORT_XLSX');

  static const $core.List<ExportFormat> values = <ExportFormat>[
    EXPORT_FORMAT_UNSPECIFIED,
    EXPORT_BINARY,
    EXPORT_TSV,
    EXPORT_CSV,
    EXPORT_DELIMITED,
    EXPORT_XLSX,
  ];

  static final $core.List<ExportFormat?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 5);
  static ExportFormat? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ExportFormat._(super.value, super.name);
}

class ExportScope extends $pb.ProtobufEnum {
  static const ExportScope EXPORT_SCOPE_UNSPECIFIED =
      ExportScope._(0, _omitEnumNames ? '' : 'EXPORT_SCOPE_UNSPECIFIED');
  static const ExportScope EXPORT_ALL =
      ExportScope._(1, _omitEnumNames ? '' : 'EXPORT_ALL');
  static const ExportScope EXPORT_DATA_ONLY =
      ExportScope._(2, _omitEnumNames ? '' : 'EXPORT_DATA_ONLY');
  static const ExportScope EXPORT_FORMAT_ONLY =
      ExportScope._(3, _omitEnumNames ? '' : 'EXPORT_FORMAT_ONLY');

  static const $core.List<ExportScope> values = <ExportScope>[
    EXPORT_SCOPE_UNSPECIFIED,
    EXPORT_ALL,
    EXPORT_DATA_ONLY,
    EXPORT_FORMAT_ONLY,
  ];

  static final $core.List<ExportScope?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static ExportScope? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ExportScope._(super.value, super.name);
}

class PrintOrientation extends $pb.ProtobufEnum {
  static const PrintOrientation PRINT_PORTRAIT =
      PrintOrientation._(0, _omitEnumNames ? '' : 'PRINT_PORTRAIT');
  static const PrintOrientation PRINT_LANDSCAPE =
      PrintOrientation._(1, _omitEnumNames ? '' : 'PRINT_LANDSCAPE');

  static const $core.List<PrintOrientation> values = <PrintOrientation>[
    PRINT_PORTRAIT,
    PRINT_LANDSCAPE,
  ];

  static final $core.List<PrintOrientation?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 1);
  static PrintOrientation? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const PrintOrientation._(super.value, super.name);
}

class NodeRelation extends $pb.ProtobufEnum {
  static const NodeRelation NODE_PARENT =
      NodeRelation._(0, _omitEnumNames ? '' : 'NODE_PARENT');
  static const NodeRelation NODE_FIRST_CHILD =
      NodeRelation._(1, _omitEnumNames ? '' : 'NODE_FIRST_CHILD');
  static const NodeRelation NODE_LAST_CHILD =
      NodeRelation._(2, _omitEnumNames ? '' : 'NODE_LAST_CHILD');
  static const NodeRelation NODE_NEXT_SIBLING =
      NodeRelation._(3, _omitEnumNames ? '' : 'NODE_NEXT_SIBLING');
  static const NodeRelation NODE_PREV_SIBLING =
      NodeRelation._(4, _omitEnumNames ? '' : 'NODE_PREV_SIBLING');

  static const $core.List<NodeRelation> values = <NodeRelation>[
    NODE_PARENT,
    NODE_FIRST_CHILD,
    NODE_LAST_CHILD,
    NODE_NEXT_SIBLING,
    NODE_PREV_SIBLING,
  ];

  static final $core.List<NodeRelation?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static NodeRelation? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const NodeRelation._(super.value, super.name);
}

class IconAlign extends $pb.ProtobufEnum {
  static const IconAlign ICON_ALIGN_INLINE_END =
      IconAlign._(0, _omitEnumNames ? '' : 'ICON_ALIGN_INLINE_END');
  static const IconAlign ICON_ALIGN_INLINE_START =
      IconAlign._(1, _omitEnumNames ? '' : 'ICON_ALIGN_INLINE_START');
  static const IconAlign ICON_ALIGN_START =
      IconAlign._(2, _omitEnumNames ? '' : 'ICON_ALIGN_START');
  static const IconAlign ICON_ALIGN_END =
      IconAlign._(3, _omitEnumNames ? '' : 'ICON_ALIGN_END');
  static const IconAlign ICON_ALIGN_CENTER =
      IconAlign._(4, _omitEnumNames ? '' : 'ICON_ALIGN_CENTER');

  static const $core.List<IconAlign> values = <IconAlign>[
    ICON_ALIGN_INLINE_END,
    ICON_ALIGN_INLINE_START,
    ICON_ALIGN_START,
    ICON_ALIGN_END,
    ICON_ALIGN_CENTER,
  ];

  static final $core.List<IconAlign?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static IconAlign? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const IconAlign._(super.value, super.name);
}

/// Which sub-element of a cell was hit. Used in ClickEvent to tell the
/// host what the user actually clicked on. Maps to HitArea variants in
/// engine/src/input.rs.
class CellHitArea extends $pb.ProtobufEnum {
  static const CellHitArea HIT_CELL =
      CellHitArea._(0, _omitEnumNames ? '' : 'HIT_CELL');
  static const CellHitArea HIT_TEXT =
      CellHitArea._(1, _omitEnumNames ? '' : 'HIT_TEXT');
  static const CellHitArea HIT_PICTURE =
      CellHitArea._(2, _omitEnumNames ? '' : 'HIT_PICTURE');
  static const CellHitArea HIT_BUTTON =
      CellHitArea._(3, _omitEnumNames ? '' : 'HIT_BUTTON');
  static const CellHitArea HIT_CHECKBOX =
      CellHitArea._(4, _omitEnumNames ? '' : 'HIT_CHECKBOX');
  static const CellHitArea HIT_DROPDOWN =
      CellHitArea._(5, _omitEnumNames ? '' : 'HIT_DROPDOWN');

  static const $core.List<CellHitArea> values = <CellHitArea>[
    HIT_CELL,
    HIT_TEXT,
    HIT_PICTURE,
    HIT_BUTTON,
    HIT_CHECKBOX,
    HIT_DROPDOWN,
  ];

  static final $core.List<CellHitArea?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 5);
  static CellHitArea? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const CellHitArea._(super.value, super.name);
}

/// ── Scrolling ──
class PullToRefreshTheme extends $pb.ProtobufEnum {
  static const PullToRefreshTheme PULL_TO_REFRESH_THEME_UNSPECIFIED =
      PullToRefreshTheme._(
          0, _omitEnumNames ? '' : 'PULL_TO_REFRESH_THEME_UNSPECIFIED');
  static const PullToRefreshTheme PULL_TO_REFRESH_THEME_TOP_BAND =
      PullToRefreshTheme._(
          1, _omitEnumNames ? '' : 'PULL_TO_REFRESH_THEME_TOP_BAND');
  static const PullToRefreshTheme PULL_TO_REFRESH_THEME_MATERIAL =
      PullToRefreshTheme._(
          2, _omitEnumNames ? '' : 'PULL_TO_REFRESH_THEME_MATERIAL');

  static const $core.List<PullToRefreshTheme> values = <PullToRefreshTheme>[
    PULL_TO_REFRESH_THEME_UNSPECIFIED,
    PULL_TO_REFRESH_THEME_TOP_BAND,
    PULL_TO_REFRESH_THEME_MATERIAL,
  ];

  static final $core.List<PullToRefreshTheme?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static PullToRefreshTheme? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const PullToRefreshTheme._(super.value, super.name);
}

/// ── Render layer bit positions (for render_layer_mask bitmask) ──
/// The engine renders through 28 independent layers (engine/src/canvas.rs
/// layer module). Each layer is guarded by its bit in render_layer_mask.
/// Setting bit i enables layer i. Set all bits (-1) to render everything.
class RenderLayerBit extends $pb.ProtobufEnum {
  static const RenderLayerBit RENDER_LAYER_OVERLAY_BANDS =
      RenderLayerBit._(0, _omitEnumNames ? '' : 'RENDER_LAYER_OVERLAY_BANDS');
  static const RenderLayerBit RENDER_LAYER_INDICATORS =
      RenderLayerBit._(1, _omitEnumNames ? '' : 'RENDER_LAYER_INDICATORS');
  static const RenderLayerBit RENDER_LAYER_BACKGROUNDS =
      RenderLayerBit._(2, _omitEnumNames ? '' : 'RENDER_LAYER_BACKGROUNDS');
  static const RenderLayerBit RENDER_LAYER_PROGRESS_BARS =
      RenderLayerBit._(3, _omitEnumNames ? '' : 'RENDER_LAYER_PROGRESS_BARS');
  static const RenderLayerBit RENDER_LAYER_GRID_LINES =
      RenderLayerBit._(4, _omitEnumNames ? '' : 'RENDER_LAYER_GRID_LINES');
  static const RenderLayerBit RENDER_LAYER_HEADER_MARKS =
      RenderLayerBit._(5, _omitEnumNames ? '' : 'RENDER_LAYER_HEADER_MARKS');
  static const RenderLayerBit RENDER_LAYER_BACKGROUND_IMAGE = RenderLayerBit._(
      6, _omitEnumNames ? '' : 'RENDER_LAYER_BACKGROUND_IMAGE');
  static const RenderLayerBit RENDER_LAYER_CELL_BORDERS =
      RenderLayerBit._(7, _omitEnumNames ? '' : 'RENDER_LAYER_CELL_BORDERS');
  static const RenderLayerBit RENDER_LAYER_CELL_TEXT =
      RenderLayerBit._(8, _omitEnumNames ? '' : 'RENDER_LAYER_CELL_TEXT');
  static const RenderLayerBit RENDER_LAYER_CELL_PICTURES =
      RenderLayerBit._(9, _omitEnumNames ? '' : 'RENDER_LAYER_CELL_PICTURES');
  static const RenderLayerBit RENDER_LAYER_SORT_GLYPHS =
      RenderLayerBit._(10, _omitEnumNames ? '' : 'RENDER_LAYER_SORT_GLYPHS');
  static const RenderLayerBit RENDER_LAYER_COL_DRAG_MARKER = RenderLayerBit._(
      11, _omitEnumNames ? '' : 'RENDER_LAYER_COL_DRAG_MARKER');
  static const RenderLayerBit RENDER_LAYER_CHECKBOXES =
      RenderLayerBit._(12, _omitEnumNames ? '' : 'RENDER_LAYER_CHECKBOXES');
  static const RenderLayerBit RENDER_LAYER_DROPDOWN_BUTTONS = RenderLayerBit._(
      13, _omitEnumNames ? '' : 'RENDER_LAYER_DROPDOWN_BUTTONS');
  static const RenderLayerBit RENDER_LAYER_SELECTION =
      RenderLayerBit._(14, _omitEnumNames ? '' : 'RENDER_LAYER_SELECTION');
  static const RenderLayerBit RENDER_LAYER_HOVER_HIGHLIGHT = RenderLayerBit._(
      15, _omitEnumNames ? '' : 'RENDER_LAYER_HOVER_HIGHLIGHT');
  static const RenderLayerBit RENDER_LAYER_EDIT_HIGHLIGHTS = RenderLayerBit._(
      16, _omitEnumNames ? '' : 'RENDER_LAYER_EDIT_HIGHLIGHTS');
  static const RenderLayerBit RENDER_LAYER_FOCUS_RECT =
      RenderLayerBit._(17, _omitEnumNames ? '' : 'RENDER_LAYER_FOCUS_RECT');
  static const RenderLayerBit RENDER_LAYER_FILL_HANDLE =
      RenderLayerBit._(18, _omitEnumNames ? '' : 'RENDER_LAYER_FILL_HANDLE');
  static const RenderLayerBit RENDER_LAYER_OUTLINE =
      RenderLayerBit._(19, _omitEnumNames ? '' : 'RENDER_LAYER_OUTLINE');
  static const RenderLayerBit RENDER_LAYER_FROZEN_BORDERS =
      RenderLayerBit._(20, _omitEnumNames ? '' : 'RENDER_LAYER_FROZEN_BORDERS');
  static const RenderLayerBit RENDER_LAYER_ACTIVE_EDITOR =
      RenderLayerBit._(21, _omitEnumNames ? '' : 'RENDER_LAYER_ACTIVE_EDITOR');
  static const RenderLayerBit RENDER_LAYER_ACTIVE_DROPDOWN = RenderLayerBit._(
      22, _omitEnumNames ? '' : 'RENDER_LAYER_ACTIVE_DROPDOWN');
  static const RenderLayerBit RENDER_LAYER_SCROLL_BARS =
      RenderLayerBit._(23, _omitEnumNames ? '' : 'RENDER_LAYER_SCROLL_BARS');
  static const RenderLayerBit RENDER_LAYER_FAST_SCROLL =
      RenderLayerBit._(24, _omitEnumNames ? '' : 'RENDER_LAYER_FAST_SCROLL');
  static const RenderLayerBit RENDER_LAYER_PULL_TO_REFRESH = RenderLayerBit._(
      25, _omitEnumNames ? '' : 'RENDER_LAYER_PULL_TO_REFRESH');
  static const RenderLayerBit RENDER_LAYER_DEBUG_OVERLAY =
      RenderLayerBit._(26, _omitEnumNames ? '' : 'RENDER_LAYER_DEBUG_OVERLAY');
  static const RenderLayerBit RENDER_LAYER_BARCODES =
      RenderLayerBit._(27, _omitEnumNames ? '' : 'RENDER_LAYER_BARCODES');

  static const $core.List<RenderLayerBit> values = <RenderLayerBit>[
    RENDER_LAYER_OVERLAY_BANDS,
    RENDER_LAYER_INDICATORS,
    RENDER_LAYER_BACKGROUNDS,
    RENDER_LAYER_PROGRESS_BARS,
    RENDER_LAYER_GRID_LINES,
    RENDER_LAYER_HEADER_MARKS,
    RENDER_LAYER_BACKGROUND_IMAGE,
    RENDER_LAYER_CELL_BORDERS,
    RENDER_LAYER_CELL_TEXT,
    RENDER_LAYER_CELL_PICTURES,
    RENDER_LAYER_SORT_GLYPHS,
    RENDER_LAYER_COL_DRAG_MARKER,
    RENDER_LAYER_CHECKBOXES,
    RENDER_LAYER_DROPDOWN_BUTTONS,
    RENDER_LAYER_SELECTION,
    RENDER_LAYER_HOVER_HIGHLIGHT,
    RENDER_LAYER_EDIT_HIGHLIGHTS,
    RENDER_LAYER_FOCUS_RECT,
    RENDER_LAYER_FILL_HANDLE,
    RENDER_LAYER_OUTLINE,
    RENDER_LAYER_FROZEN_BORDERS,
    RENDER_LAYER_ACTIVE_EDITOR,
    RENDER_LAYER_ACTIVE_DROPDOWN,
    RENDER_LAYER_SCROLL_BARS,
    RENDER_LAYER_FAST_SCROLL,
    RENDER_LAYER_PULL_TO_REFRESH,
    RENDER_LAYER_DEBUG_OVERLAY,
    RENDER_LAYER_BARCODES,
  ];

  static final $core.List<RenderLayerBit?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 27);
  static RenderLayerBit? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const RenderLayerBit._(super.value, super.name);
}

class RowIndicatorSlotKind extends $pb.ProtobufEnum {
  static const RowIndicatorSlotKind ROW_INDICATOR_SLOT_NONE =
      RowIndicatorSlotKind._(
          0, _omitEnumNames ? '' : 'ROW_INDICATOR_SLOT_NONE');
  static const RowIndicatorSlotKind ROW_INDICATOR_SLOT_NUMBERS =
      RowIndicatorSlotKind._(
          1, _omitEnumNames ? '' : 'ROW_INDICATOR_SLOT_NUMBERS');
  static const RowIndicatorSlotKind ROW_INDICATOR_SLOT_CURRENT =
      RowIndicatorSlotKind._(
          2, _omitEnumNames ? '' : 'ROW_INDICATOR_SLOT_CURRENT');
  static const RowIndicatorSlotKind ROW_INDICATOR_SLOT_SELECTION =
      RowIndicatorSlotKind._(
          3, _omitEnumNames ? '' : 'ROW_INDICATOR_SLOT_SELECTION');
  static const RowIndicatorSlotKind ROW_INDICATOR_SLOT_CHECKBOX =
      RowIndicatorSlotKind._(
          4, _omitEnumNames ? '' : 'ROW_INDICATOR_SLOT_CHECKBOX');
  static const RowIndicatorSlotKind ROW_INDICATOR_SLOT_HANDLE =
      RowIndicatorSlotKind._(
          5, _omitEnumNames ? '' : 'ROW_INDICATOR_SLOT_HANDLE');
  static const RowIndicatorSlotKind ROW_INDICATOR_SLOT_EDITING =
      RowIndicatorSlotKind._(
          6, _omitEnumNames ? '' : 'ROW_INDICATOR_SLOT_EDITING');
  static const RowIndicatorSlotKind ROW_INDICATOR_SLOT_MODIFIED =
      RowIndicatorSlotKind._(
          7, _omitEnumNames ? '' : 'ROW_INDICATOR_SLOT_MODIFIED');
  static const RowIndicatorSlotKind ROW_INDICATOR_SLOT_ERROR =
      RowIndicatorSlotKind._(
          8, _omitEnumNames ? '' : 'ROW_INDICATOR_SLOT_ERROR');
  static const RowIndicatorSlotKind ROW_INDICATOR_SLOT_NEW_ROW =
      RowIndicatorSlotKind._(
          9, _omitEnumNames ? '' : 'ROW_INDICATOR_SLOT_NEW_ROW');
  static const RowIndicatorSlotKind ROW_INDICATOR_SLOT_EXPANDER =
      RowIndicatorSlotKind._(
          10, _omitEnumNames ? '' : 'ROW_INDICATOR_SLOT_EXPANDER');
  static const RowIndicatorSlotKind ROW_INDICATOR_SLOT_RESIZE =
      RowIndicatorSlotKind._(
          11, _omitEnumNames ? '' : 'ROW_INDICATOR_SLOT_RESIZE');
  static const RowIndicatorSlotKind ROW_INDICATOR_SLOT_ACTION =
      RowIndicatorSlotKind._(
          12, _omitEnumNames ? '' : 'ROW_INDICATOR_SLOT_ACTION');
  static const RowIndicatorSlotKind ROW_INDICATOR_SLOT_STATUS_ICON =
      RowIndicatorSlotKind._(
          13, _omitEnumNames ? '' : 'ROW_INDICATOR_SLOT_STATUS_ICON');
  static const RowIndicatorSlotKind ROW_INDICATOR_SLOT_CUSTOM =
      RowIndicatorSlotKind._(
          14, _omitEnumNames ? '' : 'ROW_INDICATOR_SLOT_CUSTOM');

  static const $core.List<RowIndicatorSlotKind> values = <RowIndicatorSlotKind>[
    ROW_INDICATOR_SLOT_NONE,
    ROW_INDICATOR_SLOT_NUMBERS,
    ROW_INDICATOR_SLOT_CURRENT,
    ROW_INDICATOR_SLOT_SELECTION,
    ROW_INDICATOR_SLOT_CHECKBOX,
    ROW_INDICATOR_SLOT_HANDLE,
    ROW_INDICATOR_SLOT_EDITING,
    ROW_INDICATOR_SLOT_MODIFIED,
    ROW_INDICATOR_SLOT_ERROR,
    ROW_INDICATOR_SLOT_NEW_ROW,
    ROW_INDICATOR_SLOT_EXPANDER,
    ROW_INDICATOR_SLOT_RESIZE,
    ROW_INDICATOR_SLOT_ACTION,
    ROW_INDICATOR_SLOT_STATUS_ICON,
    ROW_INDICATOR_SLOT_CUSTOM,
  ];

  static final $core.List<RowIndicatorSlotKind?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 14);
  static RowIndicatorSlotKind? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const RowIndicatorSlotKind._(super.value, super.name);
}

class RowIndicatorMode extends $pb.ProtobufEnum {
  static const RowIndicatorMode ROW_INDICATOR_NONE =
      RowIndicatorMode._(0, _omitEnumNames ? '' : 'ROW_INDICATOR_NONE');
  static const RowIndicatorMode ROW_INDICATOR_NUMBERS =
      RowIndicatorMode._(1, _omitEnumNames ? '' : 'ROW_INDICATOR_NUMBERS');
  static const RowIndicatorMode ROW_INDICATOR_CURRENT =
      RowIndicatorMode._(2, _omitEnumNames ? '' : 'ROW_INDICATOR_CURRENT');
  static const RowIndicatorMode ROW_INDICATOR_SELECTION =
      RowIndicatorMode._(4, _omitEnumNames ? '' : 'ROW_INDICATOR_SELECTION');
  static const RowIndicatorMode ROW_INDICATOR_CHECKBOX =
      RowIndicatorMode._(8, _omitEnumNames ? '' : 'ROW_INDICATOR_CHECKBOX');
  static const RowIndicatorMode ROW_INDICATOR_HANDLE =
      RowIndicatorMode._(16, _omitEnumNames ? '' : 'ROW_INDICATOR_HANDLE');
  static const RowIndicatorMode ROW_INDICATOR_EDITING =
      RowIndicatorMode._(32, _omitEnumNames ? '' : 'ROW_INDICATOR_EDITING');
  static const RowIndicatorMode ROW_INDICATOR_MODIFIED =
      RowIndicatorMode._(64, _omitEnumNames ? '' : 'ROW_INDICATOR_MODIFIED');
  static const RowIndicatorMode ROW_INDICATOR_ERROR =
      RowIndicatorMode._(128, _omitEnumNames ? '' : 'ROW_INDICATOR_ERROR');
  static const RowIndicatorMode ROW_INDICATOR_NEW_ROW =
      RowIndicatorMode._(256, _omitEnumNames ? '' : 'ROW_INDICATOR_NEW_ROW');
  static const RowIndicatorMode ROW_INDICATOR_EXPANDER =
      RowIndicatorMode._(512, _omitEnumNames ? '' : 'ROW_INDICATOR_EXPANDER');
  static const RowIndicatorMode ROW_INDICATOR_RESIZE =
      RowIndicatorMode._(1024, _omitEnumNames ? '' : 'ROW_INDICATOR_RESIZE');
  static const RowIndicatorMode ROW_INDICATOR_ACTION =
      RowIndicatorMode._(2048, _omitEnumNames ? '' : 'ROW_INDICATOR_ACTION');
  static const RowIndicatorMode ROW_INDICATOR_STATUS_ICON = RowIndicatorMode._(
      4096, _omitEnumNames ? '' : 'ROW_INDICATOR_STATUS_ICON');
  static const RowIndicatorMode ROW_INDICATOR_CUSTOM =
      RowIndicatorMode._(8192, _omitEnumNames ? '' : 'ROW_INDICATOR_CUSTOM');

  static const $core.List<RowIndicatorMode> values = <RowIndicatorMode>[
    ROW_INDICATOR_NONE,
    ROW_INDICATOR_NUMBERS,
    ROW_INDICATOR_CURRENT,
    ROW_INDICATOR_SELECTION,
    ROW_INDICATOR_CHECKBOX,
    ROW_INDICATOR_HANDLE,
    ROW_INDICATOR_EDITING,
    ROW_INDICATOR_MODIFIED,
    ROW_INDICATOR_ERROR,
    ROW_INDICATOR_NEW_ROW,
    ROW_INDICATOR_EXPANDER,
    ROW_INDICATOR_RESIZE,
    ROW_INDICATOR_ACTION,
    ROW_INDICATOR_STATUS_ICON,
    ROW_INDICATOR_CUSTOM,
  ];

  static final $core.Map<$core.int, RowIndicatorMode> _byValue =
      $pb.ProtobufEnum.initByValue(values);
  static RowIndicatorMode? valueOf($core.int value) => _byValue[value];

  const RowIndicatorMode._(super.value, super.name);
}

class ColIndicatorCellMode extends $pb.ProtobufEnum {
  static const ColIndicatorCellMode COL_INDICATOR_CELL_NONE =
      ColIndicatorCellMode._(
          0, _omitEnumNames ? '' : 'COL_INDICATOR_CELL_NONE');
  static const ColIndicatorCellMode COL_INDICATOR_CELL_HEADER_TEXT =
      ColIndicatorCellMode._(
          1, _omitEnumNames ? '' : 'COL_INDICATOR_CELL_HEADER_TEXT');
  static const ColIndicatorCellMode COL_INDICATOR_CELL_SORT_GLYPH =
      ColIndicatorCellMode._(
          2, _omitEnumNames ? '' : 'COL_INDICATOR_CELL_SORT_GLYPH');
  static const ColIndicatorCellMode COL_INDICATOR_CELL_SORT_PRIORITY =
      ColIndicatorCellMode._(
          4, _omitEnumNames ? '' : 'COL_INDICATOR_CELL_SORT_PRIORITY');
  static const ColIndicatorCellMode COL_INDICATOR_CELL_FILTER_BUTTON =
      ColIndicatorCellMode._(
          8, _omitEnumNames ? '' : 'COL_INDICATOR_CELL_FILTER_BUTTON');
  static const ColIndicatorCellMode COL_INDICATOR_CELL_FILTER_STATE =
      ColIndicatorCellMode._(
          16, _omitEnumNames ? '' : 'COL_INDICATOR_CELL_FILTER_STATE');
  static const ColIndicatorCellMode COL_INDICATOR_CELL_MENU_BUTTON =
      ColIndicatorCellMode._(
          32, _omitEnumNames ? '' : 'COL_INDICATOR_CELL_MENU_BUTTON');
  static const ColIndicatorCellMode COL_INDICATOR_CELL_CHOOSER =
      ColIndicatorCellMode._(
          64, _omitEnumNames ? '' : 'COL_INDICATOR_CELL_CHOOSER');
  static const ColIndicatorCellMode COL_INDICATOR_CELL_DRAG_REORDER =
      ColIndicatorCellMode._(
          128, _omitEnumNames ? '' : 'COL_INDICATOR_CELL_DRAG_REORDER');
  static const ColIndicatorCellMode COL_INDICATOR_CELL_HIDDEN_MARKER =
      ColIndicatorCellMode._(
          256, _omitEnumNames ? '' : 'COL_INDICATOR_CELL_HIDDEN_MARKER');
  static const ColIndicatorCellMode COL_INDICATOR_CELL_RESIZE_HANDLE =
      ColIndicatorCellMode._(
          512, _omitEnumNames ? '' : 'COL_INDICATOR_CELL_RESIZE_HANDLE');
  static const ColIndicatorCellMode COL_INDICATOR_CELL_SELECT_ALL =
      ColIndicatorCellMode._(
          1024, _omitEnumNames ? '' : 'COL_INDICATOR_CELL_SELECT_ALL');
  static const ColIndicatorCellMode COL_INDICATOR_CELL_STATUS_ICON =
      ColIndicatorCellMode._(
          2048, _omitEnumNames ? '' : 'COL_INDICATOR_CELL_STATUS_ICON');
  static const ColIndicatorCellMode COL_INDICATOR_CELL_CUSTOM =
      ColIndicatorCellMode._(
          4096, _omitEnumNames ? '' : 'COL_INDICATOR_CELL_CUSTOM');

  static const $core.List<ColIndicatorCellMode> values = <ColIndicatorCellMode>[
    COL_INDICATOR_CELL_NONE,
    COL_INDICATOR_CELL_HEADER_TEXT,
    COL_INDICATOR_CELL_SORT_GLYPH,
    COL_INDICATOR_CELL_SORT_PRIORITY,
    COL_INDICATOR_CELL_FILTER_BUTTON,
    COL_INDICATOR_CELL_FILTER_STATE,
    COL_INDICATOR_CELL_MENU_BUTTON,
    COL_INDICATOR_CELL_CHOOSER,
    COL_INDICATOR_CELL_DRAG_REORDER,
    COL_INDICATOR_CELL_HIDDEN_MARKER,
    COL_INDICATOR_CELL_RESIZE_HANDLE,
    COL_INDICATOR_CELL_SELECT_ALL,
    COL_INDICATOR_CELL_STATUS_ICON,
    COL_INDICATOR_CELL_CUSTOM,
  ];

  static final $core.Map<$core.int, ColIndicatorCellMode> _byValue =
      $pb.ProtobufEnum.initByValue(values);
  static ColIndicatorCellMode? valueOf($core.int value) => _byValue[value];

  const ColIndicatorCellMode._(super.value, super.name);
}

class ComposeMethod extends $pb.ProtobufEnum {
  static const ComposeMethod COMPOSE_METHOD_NONE =
      ComposeMethod._(0, _omitEnumNames ? '' : 'COMPOSE_METHOD_NONE');
  static const ComposeMethod COMPOSE_METHOD_HANGUL =
      ComposeMethod._(1, _omitEnumNames ? '' : 'COMPOSE_METHOD_HANGUL');
  static const ComposeMethod COMPOSE_METHOD_DEAD_KEY =
      ComposeMethod._(2, _omitEnumNames ? '' : 'COMPOSE_METHOD_DEAD_KEY');
  static const ComposeMethod COMPOSE_METHOD_TELEX =
      ComposeMethod._(3, _omitEnumNames ? '' : 'COMPOSE_METHOD_TELEX');

  static const $core.List<ComposeMethod> values = <ComposeMethod>[
    COMPOSE_METHOD_NONE,
    COMPOSE_METHOD_HANGUL,
    COMPOSE_METHOD_DEAD_KEY,
    COMPOSE_METHOD_TELEX,
  ];

  static final $core.List<ComposeMethod?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static ComposeMethod? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ComposeMethod._(super.value, super.name);
}

/// Edit UI mode. See engine/src/edit.rs EditUiMode.
///   ENTER (0): Spreadsheet-style. Enter commits and moves cursor down.
///              Character keys replace cell content. Up/Down commit and move.
///   EDIT (1):  F2 mode. Caret placed at end of existing text.
///              Escape cancels and restores original value.
///              Arrow keys move caret within text, not the grid cursor.
class EditUiMode extends $pb.ProtobufEnum {
  static const EditUiMode EDIT_UI_MODE_ENTER =
      EditUiMode._(0, _omitEnumNames ? '' : 'EDIT_UI_MODE_ENTER');
  static const EditUiMode EDIT_UI_MODE_EDIT =
      EditUiMode._(1, _omitEnumNames ? '' : 'EDIT_UI_MODE_EDIT');

  static const $core.List<EditUiMode> values = <EditUiMode>[
    EDIT_UI_MODE_ENTER,
    EDIT_UI_MODE_EDIT,
  ];

  static final $core.List<EditUiMode?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 1);
  static EditUiMode? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const EditUiMode._(super.value, super.name);
}

class ErrorCode extends $pb.ProtobufEnum {
  static const ErrorCode ERROR_UNKNOWN =
      ErrorCode._(0, _omitEnumNames ? '' : 'ERROR_UNKNOWN');
  static const ErrorCode ERROR_INVALID_ARGUMENT =
      ErrorCode._(1, _omitEnumNames ? '' : 'ERROR_INVALID_ARGUMENT');
  static const ErrorCode ERROR_NOT_FOUND =
      ErrorCode._(2, _omitEnumNames ? '' : 'ERROR_NOT_FOUND');
  static const ErrorCode ERROR_INVALID_STATE =
      ErrorCode._(3, _omitEnumNames ? '' : 'ERROR_INVALID_STATE');
  static const ErrorCode ERROR_TYPE_VIOLATION =
      ErrorCode._(4, _omitEnumNames ? '' : 'ERROR_TYPE_VIOLATION');
  static const ErrorCode ERROR_DECODE_FAILED =
      ErrorCode._(5, _omitEnumNames ? '' : 'ERROR_DECODE_FAILED');
  static const ErrorCode ERROR_ENCODE_FAILED =
      ErrorCode._(6, _omitEnumNames ? '' : 'ERROR_ENCODE_FAILED');
  static const ErrorCode ERROR_NOT_IMPLEMENTED =
      ErrorCode._(7, _omitEnumNames ? '' : 'ERROR_NOT_IMPLEMENTED');
  static const ErrorCode ERROR_INTERNAL =
      ErrorCode._(8, _omitEnumNames ? '' : 'ERROR_INTERNAL');

  static const $core.List<ErrorCode> values = <ErrorCode>[
    ERROR_UNKNOWN,
    ERROR_INVALID_ARGUMENT,
    ERROR_NOT_FOUND,
    ERROR_INVALID_STATE,
    ERROR_TYPE_VIOLATION,
    ERROR_DECODE_FAILED,
    ERROR_ENCODE_FAILED,
    ERROR_NOT_IMPLEMENTED,
    ERROR_INTERNAL,
  ];

  static final $core.List<ErrorCode?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 8);
  static ErrorCode? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ErrorCode._(super.value, super.name);
}

class DemoDataFormat extends $pb.ProtobufEnum {
  static const DemoDataFormat DEMO_DATA_FORMAT_UNSPECIFIED =
      DemoDataFormat._(0, _omitEnumNames ? '' : 'DEMO_DATA_FORMAT_UNSPECIFIED');
  static const DemoDataFormat DEMO_DATA_FORMAT_JSON =
      DemoDataFormat._(1, _omitEnumNames ? '' : 'DEMO_DATA_FORMAT_JSON');

  static const $core.List<DemoDataFormat> values = <DemoDataFormat>[
    DEMO_DATA_FORMAT_UNSPECIFIED,
    DEMO_DATA_FORMAT_JSON,
  ];

  static final $core.List<DemoDataFormat?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 1);
  static DemoDataFormat? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const DemoDataFormat._(super.value, super.name);
}

class TerminalColorLevel extends $pb.ProtobufEnum {
  static const TerminalColorLevel TERMINAL_COLOR_LEVEL_AUTO =
      TerminalColorLevel._(
          0, _omitEnumNames ? '' : 'TERMINAL_COLOR_LEVEL_AUTO');
  static const TerminalColorLevel TERMINAL_COLOR_LEVEL_TRUECOLOR =
      TerminalColorLevel._(
          1, _omitEnumNames ? '' : 'TERMINAL_COLOR_LEVEL_TRUECOLOR');
  static const TerminalColorLevel TERMINAL_COLOR_LEVEL_256 =
      TerminalColorLevel._(2, _omitEnumNames ? '' : 'TERMINAL_COLOR_LEVEL_256');
  static const TerminalColorLevel TERMINAL_COLOR_LEVEL_16 =
      TerminalColorLevel._(3, _omitEnumNames ? '' : 'TERMINAL_COLOR_LEVEL_16');

  static const $core.List<TerminalColorLevel> values = <TerminalColorLevel>[
    TERMINAL_COLOR_LEVEL_AUTO,
    TERMINAL_COLOR_LEVEL_TRUECOLOR,
    TERMINAL_COLOR_LEVEL_256,
    TERMINAL_COLOR_LEVEL_16,
  ];

  static final $core.List<TerminalColorLevel?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static TerminalColorLevel? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const TerminalColorLevel._(super.value, super.name);
}

class FrameKind extends $pb.ProtobufEnum {
  static const FrameKind FRAME_KIND_FRAME =
      FrameKind._(0, _omitEnumNames ? '' : 'FRAME_KIND_FRAME');
  static const FrameKind FRAME_KIND_SESSION_START =
      FrameKind._(1, _omitEnumNames ? '' : 'FRAME_KIND_SESSION_START');
  static const FrameKind FRAME_KIND_SESSION_END =
      FrameKind._(2, _omitEnumNames ? '' : 'FRAME_KIND_SESSION_END');

  static const $core.List<FrameKind> values = <FrameKind>[
    FRAME_KIND_FRAME,
    FRAME_KIND_SESSION_START,
    FRAME_KIND_SESSION_END,
  ];

  static final $core.List<FrameKind?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static FrameKind? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const FrameKind._(super.value, super.name);
}

class ArchiveRequest_Action extends $pb.ProtobufEnum {
  static const ArchiveRequest_Action ACTION_UNSPECIFIED =
      ArchiveRequest_Action._(0, _omitEnumNames ? '' : 'ACTION_UNSPECIFIED');
  static const ArchiveRequest_Action SAVE =
      ArchiveRequest_Action._(1, _omitEnumNames ? '' : 'SAVE');
  static const ArchiveRequest_Action LOAD =
      ArchiveRequest_Action._(2, _omitEnumNames ? '' : 'LOAD');
  static const ArchiveRequest_Action DELETE =
      ArchiveRequest_Action._(3, _omitEnumNames ? '' : 'DELETE');
  static const ArchiveRequest_Action LIST =
      ArchiveRequest_Action._(4, _omitEnumNames ? '' : 'LIST');

  static const $core.List<ArchiveRequest_Action> values =
      <ArchiveRequest_Action>[
    ACTION_UNSPECIFIED,
    SAVE,
    LOAD,
    DELETE,
    LIST,
  ];

  static final $core.List<ArchiveRequest_Action?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static ArchiveRequest_Action? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ArchiveRequest_Action._(super.value, super.name);
}

class PointerEvent_Type extends $pb.ProtobufEnum {
  static const PointerEvent_Type TYPE_UNSPECIFIED =
      PointerEvent_Type._(0, _omitEnumNames ? '' : 'TYPE_UNSPECIFIED');
  static const PointerEvent_Type DOWN =
      PointerEvent_Type._(1, _omitEnumNames ? '' : 'DOWN');
  static const PointerEvent_Type UP =
      PointerEvent_Type._(2, _omitEnumNames ? '' : 'UP');
  static const PointerEvent_Type MOVE =
      PointerEvent_Type._(3, _omitEnumNames ? '' : 'MOVE');

  static const $core.List<PointerEvent_Type> values = <PointerEvent_Type>[
    TYPE_UNSPECIFIED,
    DOWN,
    UP,
    MOVE,
  ];

  static final $core.List<PointerEvent_Type?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static PointerEvent_Type? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const PointerEvent_Type._(super.value, super.name);
}

class ZoomEvent_Phase extends $pb.ProtobufEnum {
  static const ZoomEvent_Phase ZOOM_PHASE_UNSPECIFIED =
      ZoomEvent_Phase._(0, _omitEnumNames ? '' : 'ZOOM_PHASE_UNSPECIFIED');
  static const ZoomEvent_Phase ZOOM_BEGIN =
      ZoomEvent_Phase._(1, _omitEnumNames ? '' : 'ZOOM_BEGIN');
  static const ZoomEvent_Phase ZOOM_UPDATE =
      ZoomEvent_Phase._(2, _omitEnumNames ? '' : 'ZOOM_UPDATE');
  static const ZoomEvent_Phase ZOOM_END =
      ZoomEvent_Phase._(3, _omitEnumNames ? '' : 'ZOOM_END');

  static const $core.List<ZoomEvent_Phase> values = <ZoomEvent_Phase>[
    ZOOM_PHASE_UNSPECIFIED,
    ZOOM_BEGIN,
    ZOOM_UPDATE,
    ZOOM_END,
  ];

  static final $core.List<ZoomEvent_Phase?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static ZoomEvent_Phase? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ZoomEvent_Phase._(super.value, super.name);
}

class KeyEvent_Type extends $pb.ProtobufEnum {
  static const KeyEvent_Type KEY_TYPE_UNSPECIFIED =
      KeyEvent_Type._(0, _omitEnumNames ? '' : 'KEY_TYPE_UNSPECIFIED');
  static const KeyEvent_Type KEY_DOWN =
      KeyEvent_Type._(1, _omitEnumNames ? '' : 'KEY_DOWN');
  static const KeyEvent_Type KEY_UP =
      KeyEvent_Type._(2, _omitEnumNames ? '' : 'KEY_UP');
  static const KeyEvent_Type KEY_PRESS =
      KeyEvent_Type._(3, _omitEnumNames ? '' : 'KEY_PRESS');

  static const $core.List<KeyEvent_Type> values = <KeyEvent_Type>[
    KEY_TYPE_UNSPECIFIED,
    KEY_DOWN,
    KEY_UP,
    KEY_PRESS,
  ];

  static final $core.List<KeyEvent_Type?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static KeyEvent_Type? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const KeyEvent_Type._(super.value, super.name);
}

class TerminalCommand_Kind extends $pb.ProtobufEnum {
  static const TerminalCommand_Kind TERMINAL_COMMAND_NONE =
      TerminalCommand_Kind._(0, _omitEnumNames ? '' : 'TERMINAL_COMMAND_NONE');
  static const TerminalCommand_Kind TERMINAL_COMMAND_EXIT =
      TerminalCommand_Kind._(1, _omitEnumNames ? '' : 'TERMINAL_COMMAND_EXIT');

  static const $core.List<TerminalCommand_Kind> values = <TerminalCommand_Kind>[
    TERMINAL_COMMAND_NONE,
    TERMINAL_COMMAND_EXIT,
  ];

  static final $core.List<TerminalCommand_Kind?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 1);
  static TerminalCommand_Kind? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const TerminalCommand_Kind._(super.value, super.name);
}

class CursorChange_CursorType extends $pb.ProtobufEnum {
  static const CursorChange_CursorType DEFAULT =
      CursorChange_CursorType._(0, _omitEnumNames ? '' : 'DEFAULT');
  static const CursorChange_CursorType RESIZE_COL =
      CursorChange_CursorType._(1, _omitEnumNames ? '' : 'RESIZE_COL');
  static const CursorChange_CursorType RESIZE_ROW =
      CursorChange_CursorType._(2, _omitEnumNames ? '' : 'RESIZE_ROW');
  static const CursorChange_CursorType MOVE_COL =
      CursorChange_CursorType._(3, _omitEnumNames ? '' : 'MOVE_COL');
  static const CursorChange_CursorType TEXT =
      CursorChange_CursorType._(4, _omitEnumNames ? '' : 'TEXT');
  static const CursorChange_CursorType HAND =
      CursorChange_CursorType._(5, _omitEnumNames ? '' : 'HAND');

  static const $core.List<CursorChange_CursorType> values =
      <CursorChange_CursorType>[
    DEFAULT,
    RESIZE_COL,
    RESIZE_ROW,
    MOVE_COL,
    TEXT,
    HAND,
  ];

  static final $core.List<CursorChange_CursorType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 5);
  static CursorChange_CursorType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const CursorChange_CursorType._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
