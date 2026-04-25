// This is a generated file - do not edit.
//
// Generated from volvoxgrid.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use borderStyleDescriptor instead')
const BorderStyle$json = {
  '1': 'BorderStyle',
  '2': [
    {'1': 'BORDER_NONE', '2': 0},
    {'1': 'BORDER_THIN', '2': 1},
    {'1': 'BORDER_THICK', '2': 2},
    {'1': 'BORDER_DOTTED', '2': 3},
    {'1': 'BORDER_DASHED', '2': 4},
    {'1': 'BORDER_DOUBLE', '2': 5},
  ],
};

/// Descriptor for `BorderStyle`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List borderStyleDescriptor = $convert.base64Decode(
    'CgtCb3JkZXJTdHlsZRIPCgtCT1JERVJfTk9ORRAAEg8KC0JPUkRFUl9USElOEAESEAoMQk9SRE'
    'VSX1RISUNLEAISEQoNQk9SREVSX0RPVFRFRBADEhEKDUJPUkRFUl9EQVNIRUQQBBIRCg1CT1JE'
    'RVJfRE9VQkxFEAU=');

@$core.Deprecated('Use gridLineStyleDescriptor instead')
const GridLineStyle$json = {
  '1': 'GridLineStyle',
  '2': [
    {'1': 'GRIDLINE_NONE', '2': 0},
    {'1': 'GRIDLINE_SOLID', '2': 1},
    {'1': 'GRIDLINE_INSET', '2': 2},
    {'1': 'GRIDLINE_RAISED', '2': 3},
  ],
};

/// Descriptor for `GridLineStyle`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List gridLineStyleDescriptor = $convert.base64Decode(
    'Cg1HcmlkTGluZVN0eWxlEhEKDUdSSURMSU5FX05PTkUQABISCg5HUklETElORV9TT0xJRBABEh'
    'IKDkdSSURMSU5FX0lOU0VUEAISEwoPR1JJRExJTkVfUkFJU0VEEAM=');

@$core.Deprecated('Use gridLineDirectionDescriptor instead')
const GridLineDirection$json = {
  '1': 'GridLineDirection',
  '2': [
    {'1': 'GRIDLINE_BOTH', '2': 0},
    {'1': 'GRIDLINE_HORIZONTAL', '2': 1},
    {'1': 'GRIDLINE_VERTICAL', '2': 2},
  ],
};

/// Descriptor for `GridLineDirection`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List gridLineDirectionDescriptor = $convert.base64Decode(
    'ChFHcmlkTGluZURpcmVjdGlvbhIRCg1HUklETElORV9CT1RIEAASFwoTR1JJRExJTkVfSE9SSV'
    'pPTlRBTBABEhUKEUdSSURMSU5FX1ZFUlRJQ0FMEAI=');

@$core.Deprecated('Use borderAppearanceDescriptor instead')
const BorderAppearance$json = {
  '1': 'BorderAppearance',
  '2': [
    {'1': 'BORDER_APPEARANCE_FLAT', '2': 0},
    {'1': 'BORDER_APPEARANCE_RAISED', '2': 1},
    {'1': 'BORDER_APPEARANCE_SUBTLE', '2': 2},
  ],
};

/// Descriptor for `BorderAppearance`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List borderAppearanceDescriptor = $convert.base64Decode(
    'ChBCb3JkZXJBcHBlYXJhbmNlEhoKFkJPUkRFUl9BUFBFQVJBTkNFX0ZMQVQQABIcChhCT1JERV'
    'JfQVBQRUFSQU5DRV9SQUlTRUQQARIcChhCT1JERVJfQVBQRUFSQU5DRV9TVUJUTEUQAg==');

@$core.Deprecated('Use textEffectDescriptor instead')
const TextEffect$json = {
  '1': 'TextEffect',
  '2': [
    {'1': 'TEXT_EFFECT_NONE', '2': 0},
    {'1': 'TEXT_EFFECT_EMBOSS', '2': 1},
    {'1': 'TEXT_EFFECT_ENGRAVE', '2': 2},
    {'1': 'TEXT_EFFECT_EMBOSS_LIGHT', '2': 3},
    {'1': 'TEXT_EFFECT_ENGRAVE_LIGHT', '2': 4},
  ],
};

/// Descriptor for `TextEffect`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List textEffectDescriptor = $convert.base64Decode(
    'CgpUZXh0RWZmZWN0EhQKEFRFWFRfRUZGRUNUX05PTkUQABIWChJURVhUX0VGRkVDVF9FTUJPU1'
    'MQARIXChNURVhUX0VGRkVDVF9FTkdSQVZFEAISHAoYVEVYVF9FRkZFQ1RfRU1CT1NTX0xJR0hU'
    'EAMSHQoZVEVYVF9FRkZFQ1RfRU5HUkFWRV9MSUdIVBAE');

@$core.Deprecated('Use textRenderModeDescriptor instead')
const TextRenderMode$json = {
  '1': 'TextRenderMode',
  '2': [
    {'1': 'TEXT_RENDER_AUTO', '2': 0},
    {'1': 'TEXT_RENDER_GRAYSCALE', '2': 1},
    {'1': 'TEXT_RENDER_SUBPIXEL', '2': 2},
    {'1': 'TEXT_RENDER_MONO', '2': 3},
  ],
};

/// Descriptor for `TextRenderMode`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List textRenderModeDescriptor = $convert.base64Decode(
    'Cg5UZXh0UmVuZGVyTW9kZRIUChBURVhUX1JFTkRFUl9BVVRPEAASGQoVVEVYVF9SRU5ERVJfR1'
    'JBWVNDQUxFEAESGAoUVEVYVF9SRU5ERVJfU1VCUElYRUwQAhIUChBURVhUX1JFTkRFUl9NT05P'
    'EAM=');

@$core.Deprecated('Use textHintingModeDescriptor instead')
const TextHintingMode$json = {
  '1': 'TextHintingMode',
  '2': [
    {'1': 'TEXT_HINT_AUTO', '2': 0},
    {'1': 'TEXT_HINT_NONE', '2': 1},
    {'1': 'TEXT_HINT_SLIGHT', '2': 2},
    {'1': 'TEXT_HINT_FULL', '2': 3},
  ],
};

/// Descriptor for `TextHintingMode`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List textHintingModeDescriptor = $convert.base64Decode(
    'Cg9UZXh0SGludGluZ01vZGUSEgoOVEVYVF9ISU5UX0FVVE8QABISCg5URVhUX0hJTlRfTk9ORR'
    'ABEhQKEFRFWFRfSElOVF9TTElHSFQQAhISCg5URVhUX0hJTlRfRlVMTBAD');

@$core.Deprecated('Use alignDescriptor instead')
const Align$json = {
  '1': 'Align',
  '2': [
    {'1': 'ALIGN_LEFT_TOP', '2': 0},
    {'1': 'ALIGN_LEFT_CENTER', '2': 1},
    {'1': 'ALIGN_LEFT_BOTTOM', '2': 2},
    {'1': 'ALIGN_CENTER_TOP', '2': 3},
    {'1': 'ALIGN_CENTER_CENTER', '2': 4},
    {'1': 'ALIGN_CENTER_BOTTOM', '2': 5},
    {'1': 'ALIGN_RIGHT_TOP', '2': 6},
    {'1': 'ALIGN_RIGHT_CENTER', '2': 7},
    {'1': 'ALIGN_RIGHT_BOTTOM', '2': 8},
    {'1': 'ALIGN_GENERAL', '2': 9},
  ],
};

/// Descriptor for `Align`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List alignDescriptor = $convert.base64Decode(
    'CgVBbGlnbhISCg5BTElHTl9MRUZUX1RPUBAAEhUKEUFMSUdOX0xFRlRfQ0VOVEVSEAESFQoRQU'
    'xJR05fTEVGVF9CT1RUT00QAhIUChBBTElHTl9DRU5URVJfVE9QEAMSFwoTQUxJR05fQ0VOVEVS'
    'X0NFTlRFUhAEEhcKE0FMSUdOX0NFTlRFUl9CT1RUT00QBRITCg9BTElHTl9SSUdIVF9UT1AQBh'
    'IWChJBTElHTl9SSUdIVF9DRU5URVIQBxIWChJBTElHTl9SSUdIVF9CT1RUT00QCBIRCg1BTElH'
    'Tl9HRU5FUkFMEAk=');

@$core.Deprecated('Use imageAlignmentDescriptor instead')
const ImageAlignment$json = {
  '1': 'ImageAlignment',
  '2': [
    {'1': 'IMG_ALIGN_LEFT_TOP', '2': 0},
    {'1': 'IMG_ALIGN_LEFT_CENTER', '2': 1},
    {'1': 'IMG_ALIGN_LEFT_BOTTOM', '2': 2},
    {'1': 'IMG_ALIGN_CENTER_TOP', '2': 3},
    {'1': 'IMG_ALIGN_CENTER_CENTER', '2': 4},
    {'1': 'IMG_ALIGN_CENTER_BOTTOM', '2': 5},
    {'1': 'IMG_ALIGN_RIGHT_TOP', '2': 6},
    {'1': 'IMG_ALIGN_RIGHT_CENTER', '2': 7},
    {'1': 'IMG_ALIGN_RIGHT_BOTTOM', '2': 8},
    {'1': 'IMG_ALIGN_STRETCH', '2': 9},
    {'1': 'IMG_ALIGN_TILE', '2': 10},
  ],
};

/// Descriptor for `ImageAlignment`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List imageAlignmentDescriptor = $convert.base64Decode(
    'Cg5JbWFnZUFsaWdubWVudBIWChJJTUdfQUxJR05fTEVGVF9UT1AQABIZChVJTUdfQUxJR05fTE'
    'VGVF9DRU5URVIQARIZChVJTUdfQUxJR05fTEVGVF9CT1RUT00QAhIYChRJTUdfQUxJR05fQ0VO'
    'VEVSX1RPUBADEhsKF0lNR19BTElHTl9DRU5URVJfQ0VOVEVSEAQSGwoXSU1HX0FMSUdOX0NFTl'
    'RFUl9CT1RUT00QBRIXChNJTUdfQUxJR05fUklHSFRfVE9QEAYSGgoWSU1HX0FMSUdOX1JJR0hU'
    'X0NFTlRFUhAHEhoKFklNR19BTElHTl9SSUdIVF9CT1RUT00QCBIVChFJTUdfQUxJR05fU1RSRV'
    'RDSBAJEhIKDklNR19BTElHTl9USUxFEAo=');

@$core.Deprecated('Use barcodeSymbologyDescriptor instead')
const BarcodeSymbology$json = {
  '1': 'BarcodeSymbology',
  '2': [
    {'1': 'BARCODE_NONE', '2': 0},
    {'1': 'BARCODE_QR', '2': 1},
    {'1': 'BARCODE_CODE128', '2': 10},
    {'1': 'BARCODE_CODE39', '2': 11},
    {'1': 'BARCODE_CODE93', '2': 12},
    {'1': 'BARCODE_CODE11', '2': 13},
    {'1': 'BARCODE_EAN13', '2': 20},
    {'1': 'BARCODE_EAN8', '2': 21},
    {'1': 'BARCODE_UPC_A', '2': 22},
    {'1': 'BARCODE_UPC_E', '2': 23},
    {'1': 'BARCODE_EAN_SUPP', '2': 24},
    {'1': 'BARCODE_ITF', '2': 30},
    {'1': 'BARCODE_STF', '2': 31},
    {'1': 'BARCODE_CODABAR', '2': 32},
  ],
};

/// Descriptor for `BarcodeSymbology`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List barcodeSymbologyDescriptor = $convert.base64Decode(
    'ChBCYXJjb2RlU3ltYm9sb2d5EhAKDEJBUkNPREVfTk9ORRAAEg4KCkJBUkNPREVfUVIQARITCg'
    '9CQVJDT0RFX0NPREUxMjgQChISCg5CQVJDT0RFX0NPREUzORALEhIKDkJBUkNPREVfQ09ERTkz'
    'EAwSEgoOQkFSQ09ERV9DT0RFMTEQDRIRCg1CQVJDT0RFX0VBTjEzEBQSEAoMQkFSQ09ERV9FQU'
    '44EBUSEQoNQkFSQ09ERV9VUENfQRAWEhEKDUJBUkNPREVfVVBDX0UQFxIUChBCQVJDT0RFX0VB'
    'Tl9TVVBQEBgSDwoLQkFSQ09ERV9JVEYQHhIPCgtCQVJDT0RFX1NURhAfEhMKD0JBUkNPREVfQ0'
    '9EQUJBUhAg');

@$core.Deprecated('Use barcodeCaptionPositionDescriptor instead')
const BarcodeCaptionPosition$json = {
  '1': 'BarcodeCaptionPosition',
  '2': [
    {'1': 'CAPTION_NONE', '2': 0},
    {'1': 'CAPTION_BOTTOM', '2': 1},
    {'1': 'CAPTION_TOP', '2': 2},
  ],
};

/// Descriptor for `BarcodeCaptionPosition`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List barcodeCaptionPositionDescriptor =
    $convert.base64Decode(
        'ChZCYXJjb2RlQ2FwdGlvblBvc2l0aW9uEhAKDENBUFRJT05fTk9ORRAAEhIKDkNBUFRJT05fQk'
        '9UVE9NEAESDwoLQ0FQVElPTl9UT1AQAg==');

@$core.Deprecated('Use barcodeCheckDigitModeDescriptor instead')
const BarcodeCheckDigitMode$json = {
  '1': 'BarcodeCheckDigitMode',
  '2': [
    {'1': 'CHECK_DIGIT_DEFAULT', '2': 0},
    {'1': 'CHECK_DIGIT_NONE', '2': 1},
    {'1': 'CHECK_DIGIT_GENERATE', '2': 2},
  ],
};

/// Descriptor for `BarcodeCheckDigitMode`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List barcodeCheckDigitModeDescriptor = $convert.base64Decode(
    'ChVCYXJjb2RlQ2hlY2tEaWdpdE1vZGUSFwoTQ0hFQ0tfRElHSVRfREVGQVVMVBAAEhQKEENIRU'
    'NLX0RJR0lUX05PTkUQARIYChRDSEVDS19ESUdJVF9HRU5FUkFURRAC');

@$core.Deprecated('Use barcodeTextEncodingDescriptor instead')
const BarcodeTextEncoding$json = {
  '1': 'BarcodeTextEncoding',
  '2': [
    {'1': 'BARCODE_TEXT_AUTO', '2': 0},
    {'1': 'BARCODE_TEXT_ASCII', '2': 1},
    {'1': 'BARCODE_TEXT_UTF8', '2': 2},
    {'1': 'BARCODE_TEXT_GS1', '2': 3},
  ],
};

/// Descriptor for `BarcodeTextEncoding`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List barcodeTextEncodingDescriptor = $convert.base64Decode(
    'ChNCYXJjb2RlVGV4dEVuY29kaW5nEhUKEUJBUkNPREVfVEVYVF9BVVRPEAASFgoSQkFSQ09ERV'
    '9URVhUX0FTQ0lJEAESFQoRQkFSQ09ERV9URVhUX1VURjgQAhIUChBCQVJDT0RFX1RFWFRfR1Mx'
    'EAM=');

@$core.Deprecated('Use barcodeQrErrorCorrectionDescriptor instead')
const BarcodeQrErrorCorrection$json = {
  '1': 'BarcodeQrErrorCorrection',
  '2': [
    {'1': 'QR_ECC_DEFAULT', '2': 0},
    {'1': 'QR_ECC_LOW', '2': 1},
    {'1': 'QR_ECC_MEDIUM', '2': 2},
    {'1': 'QR_ECC_QUARTILE', '2': 3},
    {'1': 'QR_ECC_HIGH', '2': 4},
  ],
};

/// Descriptor for `BarcodeQrErrorCorrection`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List barcodeQrErrorCorrectionDescriptor = $convert.base64Decode(
    'ChhCYXJjb2RlUXJFcnJvckNvcnJlY3Rpb24SEgoOUVJfRUNDX0RFRkFVTFQQABIOCgpRUl9FQ0'
    'NfTE9XEAESEQoNUVJfRUNDX01FRElVTRACEhMKD1FSX0VDQ19RVUFSVElMRRADEg8KC1FSX0VD'
    'Q19ISUdIEAQ=');

@$core.Deprecated('Use barcodeRenderStatusDescriptor instead')
const BarcodeRenderStatus$json = {
  '1': 'BarcodeRenderStatus',
  '2': [
    {'1': 'BARCODE_RENDER_STATUS_UNSPECIFIED', '2': 0},
    {'1': 'BARCODE_RENDER_STATUS_OK', '2': 1},
    {'1': 'BARCODE_RENDER_STATUS_EMPTY_PAYLOAD', '2': 2},
    {'1': 'BARCODE_RENDER_STATUS_INVALID_PAYLOAD', '2': 3},
    {'1': 'BARCODE_RENDER_STATUS_UNSUPPORTED_SYMBOLOGY', '2': 4},
  ],
};

/// Descriptor for `BarcodeRenderStatus`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List barcodeRenderStatusDescriptor = $convert.base64Decode(
    'ChNCYXJjb2RlUmVuZGVyU3RhdHVzEiUKIUJBUkNPREVfUkVOREVSX1NUQVRVU19VTlNQRUNJRk'
    'lFRBAAEhwKGEJBUkNPREVfUkVOREVSX1NUQVRVU19PSxABEicKI0JBUkNPREVfUkVOREVSX1NU'
    'QVRVU19FTVBUWV9QQVlMT0FEEAISKQolQkFSQ09ERV9SRU5ERVJfU1RBVFVTX0lOVkFMSURfUE'
    'FZTE9BRBADEi8KK0JBUkNPREVfUkVOREVSX1NUQVRVU19VTlNVUFBPUlRFRF9TWU1CT0xPR1kQ'
    'BA==');

@$core.Deprecated('Use checkedStateDescriptor instead')
const CheckedState$json = {
  '1': 'CheckedState',
  '2': [
    {'1': 'CHECKED_UNCHECKED', '2': 0},
    {'1': 'CHECKED_CHECKED', '2': 1},
    {'1': 'CHECKED_GRAYED', '2': 2},
  ],
};

/// Descriptor for `CheckedState`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List checkedStateDescriptor = $convert.base64Decode(
    'CgxDaGVja2VkU3RhdGUSFQoRQ0hFQ0tFRF9VTkNIRUNLRUQQABITCg9DSEVDS0VEX0NIRUNLRU'
    'QQARISCg5DSEVDS0VEX0dSQVlFRBAC');

@$core.Deprecated('Use fillHandlePositionDescriptor instead')
const FillHandlePosition$json = {
  '1': 'FillHandlePosition',
  '2': [
    {'1': 'FILL_HANDLE_NONE', '2': 0},
    {'1': 'FILL_HANDLE_BOTTOM_RIGHT', '2': 1},
    {'1': 'FILL_HANDLE_BOTTOM_LEFT', '2': 2},
    {'1': 'FILL_HANDLE_TOP_RIGHT', '2': 3},
    {'1': 'FILL_HANDLE_TOP_LEFT', '2': 4},
    {'1': 'FILL_HANDLE_ALL_CORNERS', '2': 5},
  ],
};

/// Descriptor for `FillHandlePosition`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List fillHandlePositionDescriptor = $convert.base64Decode(
    'ChJGaWxsSGFuZGxlUG9zaXRpb24SFAoQRklMTF9IQU5ETEVfTk9ORRAAEhwKGEZJTExfSEFORE'
    'xFX0JPVFRPTV9SSUdIVBABEhsKF0ZJTExfSEFORExFX0JPVFRPTV9MRUZUEAISGQoVRklMTF9I'
    'QU5ETEVfVE9QX1JJR0hUEAMSGAoURklMTF9IQU5ETEVfVE9QX0xFRlQQBBIbChdGSUxMX0hBTk'
    'RMRV9BTExfQ09STkVSUxAF');

@$core.Deprecated('Use columnDataTypeDescriptor instead')
const ColumnDataType$json = {
  '1': 'ColumnDataType',
  '2': [
    {'1': 'COLUMN_DATA_STRING', '2': 0},
    {'1': 'COLUMN_DATA_NUMBER', '2': 1},
    {'1': 'COLUMN_DATA_DATE', '2': 2},
    {'1': 'COLUMN_DATA_BOOLEAN', '2': 3},
    {'1': 'COLUMN_DATA_CURRENCY', '2': 4},
  ],
};

/// Descriptor for `ColumnDataType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List columnDataTypeDescriptor = $convert.base64Decode(
    'Cg5Db2x1bW5EYXRhVHlwZRIWChJDT0xVTU5fREFUQV9TVFJJTkcQABIWChJDT0xVTU5fREFUQV'
    '9OVU1CRVIQARIUChBDT0xVTU5fREFUQV9EQVRFEAISFwoTQ09MVU1OX0RBVEFfQk9PTEVBThAD'
    'EhgKFENPTFVNTl9EQVRBX0NVUlJFTkNZEAQ=');

@$core.Deprecated('Use coercionModeDescriptor instead')
const CoercionMode$json = {
  '1': 'CoercionMode',
  '2': [
    {'1': 'COERCION_UNSPECIFIED', '2': 0},
    {'1': 'COERCION_STRICT', '2': 1},
    {'1': 'COERCION_FLEXIBLE', '2': 2},
    {'1': 'COERCION_PARSE_ONLY', '2': 3},
  ],
};

/// Descriptor for `CoercionMode`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List coercionModeDescriptor = $convert.base64Decode(
    'CgxDb2VyY2lvbk1vZGUSGAoUQ09FUkNJT05fVU5TUEVDSUZJRUQQABITCg9DT0VSQ0lPTl9TVF'
    'JJQ1QQARIVChFDT0VSQ0lPTl9GTEVYSUJMRRACEhcKE0NPRVJDSU9OX1BBUlNFX09OTFkQAw==');

@$core.Deprecated('Use writeErrorModeDescriptor instead')
const WriteErrorMode$json = {
  '1': 'WriteErrorMode',
  '2': [
    {'1': 'WRITE_ERROR_UNSPECIFIED', '2': 0},
    {'1': 'WRITE_ERROR_REJECT', '2': 1},
    {'1': 'WRITE_ERROR_SET_NULL', '2': 2},
    {'1': 'WRITE_ERROR_SKIP', '2': 3},
  ],
};

/// Descriptor for `WriteErrorMode`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List writeErrorModeDescriptor = $convert.base64Decode(
    'Cg5Xcml0ZUVycm9yTW9kZRIbChdXUklURV9FUlJPUl9VTlNQRUNJRklFRBAAEhYKEldSSVRFX0'
    'VSUk9SX1JFSkVDVBABEhgKFFdSSVRFX0VSUk9SX1NFVF9OVUxMEAISFAoQV1JJVEVfRVJST1Jf'
    'U0tJUBAD');

@$core.Deprecated('Use cellInteractionDescriptor instead')
const CellInteraction$json = {
  '1': 'CellInteraction',
  '2': [
    {'1': 'CELL_INTERACTION_UNSPECIFIED', '2': 0},
    {'1': 'CELL_INTERACTION_NONE', '2': 1},
    {'1': 'CELL_INTERACTION_TEXT_LINK', '2': 2},
    {'1': 'CELL_INTERACTION_BUTTON', '2': 3},
  ],
};

/// Descriptor for `CellInteraction`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List cellInteractionDescriptor = $convert.base64Decode(
    'Cg9DZWxsSW50ZXJhY3Rpb24SIAocQ0VMTF9JTlRFUkFDVElPTl9VTlNQRUNJRklFRBAAEhkKFU'
    'NFTExfSU5URVJBQ1RJT05fTk9ORRABEh4KGkNFTExfSU5URVJBQ1RJT05fVEVYVF9MSU5LEAIS'
    'GwoXQ0VMTF9JTlRFUkFDVElPTl9CVVRUT04QAw==');

@$core.Deprecated('Use headerPolicyDescriptor instead')
const HeaderPolicy$json = {
  '1': 'HeaderPolicy',
  '2': [
    {'1': 'HEADER_AUTO', '2': 0},
    {'1': 'HEADER_NONE', '2': 1},
    {'1': 'HEADER_FIRST_ROW', '2': 2},
  ],
};

/// Descriptor for `HeaderPolicy`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List headerPolicyDescriptor = $convert.base64Decode(
    'CgxIZWFkZXJQb2xpY3kSDwoLSEVBREVSX0FVVE8QABIPCgtIRUFERVJfTk9ORRABEhQKEEhFQU'
    'RFUl9GSVJTVF9ST1cQAg==');

@$core.Deprecated('Use typePolicyDescriptor instead')
const TypePolicy$json = {
  '1': 'TypePolicy',
  '2': [
    {'1': 'TYPE_AUTO_DETECT', '2': 0},
    {'1': 'TYPE_ALL_STRING', '2': 1},
    {'1': 'TYPE_FROM_SCHEMA', '2': 2},
  ],
};

/// Descriptor for `TypePolicy`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List typePolicyDescriptor = $convert.base64Decode(
    'CgpUeXBlUG9saWN5EhQKEFRZUEVfQVVUT19ERVRFQ1QQABITCg9UWVBFX0FMTF9TVFJJTkcQAR'
    'IUChBUWVBFX0ZST01fU0NIRU1BEAI=');

@$core.Deprecated('Use loadModeDescriptor instead')
const LoadMode$json = {
  '1': 'LoadMode',
  '2': [
    {'1': 'LOAD_MODE_UNSPECIFIED', '2': 0},
    {'1': 'LOAD_REPLACE', '2': 1},
    {'1': 'LOAD_APPEND', '2': 2},
  ],
};

/// Descriptor for `LoadMode`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List loadModeDescriptor = $convert.base64Decode(
    'CghMb2FkTW9kZRIZChVMT0FEX01PREVfVU5TUEVDSUZJRUQQABIQCgxMT0FEX1JFUExBQ0UQAR'
    'IPCgtMT0FEX0FQUEVORBAC');

@$core.Deprecated('Use loadDataStatusDescriptor instead')
const LoadDataStatus$json = {
  '1': 'LoadDataStatus',
  '2': [
    {'1': 'LOAD_OK', '2': 0},
    {'1': 'LOAD_PARTIAL', '2': 1},
    {'1': 'LOAD_FAILED', '2': 2},
  ],
};

/// Descriptor for `LoadDataStatus`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List loadDataStatusDescriptor = $convert.base64Decode(
    'Cg5Mb2FkRGF0YVN0YXR1cxILCgdMT0FEX09LEAASEAoMTE9BRF9QQVJUSUFMEAESDwoLTE9BRF'
    '9GQUlMRUQQAg==');

@$core.Deprecated('Use selectionModeDescriptor instead')
const SelectionMode$json = {
  '1': 'SelectionMode',
  '2': [
    {'1': 'SELECTION_FREE', '2': 0},
    {'1': 'SELECTION_BY_ROW', '2': 1},
    {'1': 'SELECTION_BY_COLUMN', '2': 2},
    {'1': 'SELECTION_LISTBOX', '2': 3},
    {'1': 'SELECTION_MULTI_RANGE', '2': 4},
  ],
};

/// Descriptor for `SelectionMode`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List selectionModeDescriptor = $convert.base64Decode(
    'Cg1TZWxlY3Rpb25Nb2RlEhIKDlNFTEVDVElPTl9GUkVFEAASFAoQU0VMRUNUSU9OX0JZX1JPVx'
    'ABEhcKE1NFTEVDVElPTl9CWV9DT0xVTU4QAhIVChFTRUxFQ1RJT05fTElTVEJPWBADEhkKFVNF'
    'TEVDVElPTl9NVUxUSV9SQU5HRRAE');

@$core.Deprecated('Use focusBorderStyleDescriptor instead')
const FocusBorderStyle$json = {
  '1': 'FocusBorderStyle',
  '2': [
    {'1': 'FOCUS_BORDER_NONE', '2': 0},
    {'1': 'FOCUS_BORDER_THIN', '2': 1},
    {'1': 'FOCUS_BORDER_THICK', '2': 2},
    {'1': 'FOCUS_BORDER_INSET', '2': 3},
    {'1': 'FOCUS_BORDER_RAISED', '2': 4},
  ],
};

/// Descriptor for `FocusBorderStyle`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List focusBorderStyleDescriptor = $convert.base64Decode(
    'ChBGb2N1c0JvcmRlclN0eWxlEhUKEUZPQ1VTX0JPUkRFUl9OT05FEAASFQoRRk9DVVNfQk9SRE'
    'VSX1RISU4QARIWChJGT0NVU19CT1JERVJfVEhJQ0sQAhIWChJGT0NVU19CT1JERVJfSU5TRVQQ'
    'AxIXChNGT0NVU19CT1JERVJfUkFJU0VEEAQ=');

@$core.Deprecated('Use selectionVisibilityDescriptor instead')
const SelectionVisibility$json = {
  '1': 'SelectionVisibility',
  '2': [
    {'1': 'SELECTION_VIS_NONE', '2': 0},
    {'1': 'SELECTION_VIS_ALWAYS', '2': 1},
    {'1': 'SELECTION_VIS_WHEN_FOCUSED', '2': 2},
  ],
};

/// Descriptor for `SelectionVisibility`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List selectionVisibilityDescriptor = $convert.base64Decode(
    'ChNTZWxlY3Rpb25WaXNpYmlsaXR5EhYKElNFTEVDVElPTl9WSVNfTk9ORRAAEhgKFFNFTEVDVE'
    'lPTl9WSVNfQUxXQVlTEAESHgoaU0VMRUNUSU9OX1ZJU19XSEVOX0ZPQ1VTRUQQAg==');

@$core.Deprecated('Use editTriggerDescriptor instead')
const EditTrigger$json = {
  '1': 'EditTrigger',
  '2': [
    {'1': 'EDIT_TRIGGER_NONE', '2': 0},
    {'1': 'EDIT_TRIGGER_KEY', '2': 1},
    {'1': 'EDIT_TRIGGER_KEY_CLICK', '2': 2},
  ],
};

/// Descriptor for `EditTrigger`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List editTriggerDescriptor = $convert.base64Decode(
    'CgtFZGl0VHJpZ2dlchIVChFFRElUX1RSSUdHRVJfTk9ORRAAEhQKEEVESVRfVFJJR0dFUl9LRV'
    'kQARIaChZFRElUX1RSSUdHRVJfS0VZX0NMSUNLEAI=');

@$core.Deprecated('Use dropdownTriggerDescriptor instead')
const DropdownTrigger$json = {
  '1': 'DropdownTrigger',
  '2': [
    {'1': 'DROPDOWN_NEVER', '2': 0},
    {'1': 'DROPDOWN_ALWAYS', '2': 1},
    {'1': 'DROPDOWN_ON_EDIT', '2': 2},
  ],
};

/// Descriptor for `DropdownTrigger`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List dropdownTriggerDescriptor = $convert.base64Decode(
    'Cg9Ecm9wZG93blRyaWdnZXISEgoORFJPUERPV05fTkVWRVIQABITCg9EUk9QRE9XTl9BTFdBWV'
    'MQARIUChBEUk9QRE9XTl9PTl9FRElUEAI=');

@$core.Deprecated('Use dropdownItemLayoutDescriptor instead')
const DropdownItemLayout$json = {
  '1': 'DropdownItemLayout',
  '2': [
    {'1': 'DROPDOWN_ITEM_AUTO', '2': 0},
    {'1': 'DROPDOWN_ITEM_LABEL', '2': 1},
    {'1': 'DROPDOWN_ITEM_VALUE_LABEL', '2': 2},
    {'1': 'DROPDOWN_ITEM_LABEL_DETAILS', '2': 3},
  ],
};

/// Descriptor for `DropdownItemLayout`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List dropdownItemLayoutDescriptor = $convert.base64Decode(
    'ChJEcm9wZG93bkl0ZW1MYXlvdXQSFgoSRFJPUERPV05fSVRFTV9BVVRPEAASFwoTRFJPUERPV0'
    '5fSVRFTV9MQUJFTBABEh0KGURST1BET1dOX0lURU1fVkFMVUVfTEFCRUwQAhIfChtEUk9QRE9X'
    'Tl9JVEVNX0xBQkVMX0RFVEFJTFMQAw==');

@$core.Deprecated('Use tabBehaviorDescriptor instead')
const TabBehavior$json = {
  '1': 'TabBehavior',
  '2': [
    {'1': 'TAB_CONTROLS', '2': 0},
    {'1': 'TAB_CELLS', '2': 1},
  ],
};

/// Descriptor for `TabBehavior`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List tabBehaviorDescriptor = $convert.base64Decode(
    'CgtUYWJCZWhhdmlvchIQCgxUQUJfQ09OVFJPTFMQABINCglUQUJfQ0VMTFMQAQ==');

@$core.Deprecated('Use sortOrderDescriptor instead')
const SortOrder$json = {
  '1': 'SortOrder',
  '2': [
    {'1': 'SORT_NONE', '2': 0},
    {'1': 'SORT_ASCENDING', '2': 1},
    {'1': 'SORT_DESCENDING', '2': 2},
  ],
};

/// Descriptor for `SortOrder`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List sortOrderDescriptor = $convert.base64Decode(
    'CglTb3J0T3JkZXISDQoJU09SVF9OT05FEAASEgoOU09SVF9BU0NFTkRJTkcQARITCg9TT1JUX0'
    'RFU0NFTkRJTkcQAg==');

@$core.Deprecated('Use sortTypeDescriptor instead')
const SortType$json = {
  '1': 'SortType',
  '2': [
    {'1': 'SORT_TYPE_AUTO', '2': 0},
    {'1': 'SORT_TYPE_NUMERIC', '2': 1},
    {'1': 'SORT_TYPE_STRING', '2': 2},
    {'1': 'SORT_TYPE_STRING_NO_CASE', '2': 3},
    {'1': 'SORT_TYPE_CUSTOM', '2': 4},
  ],
};

/// Descriptor for `SortType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List sortTypeDescriptor = $convert.base64Decode(
    'CghTb3J0VHlwZRISCg5TT1JUX1RZUEVfQVVUTxAAEhUKEVNPUlRfVFlQRV9OVU1FUklDEAESFA'
    'oQU09SVF9UWVBFX1NUUklORxACEhwKGFNPUlRfVFlQRV9TVFJJTkdfTk9fQ0FTRRADEhQKEFNP'
    'UlRfVFlQRV9DVVNUT00QBA==');

@$core.Deprecated('Use treeIndicatorStyleDescriptor instead')
const TreeIndicatorStyle$json = {
  '1': 'TreeIndicatorStyle',
  '2': [
    {'1': 'TREE_INDICATOR_NONE', '2': 0},
    {'1': 'TREE_INDICATOR_ARROWS', '2': 1},
    {'1': 'TREE_INDICATOR_ARROWS_LEAF', '2': 2},
    {'1': 'TREE_INDICATOR_CONNECTORS', '2': 3},
    {'1': 'TREE_INDICATOR_CONNECTORS_LEAF', '2': 4},
  ],
};

/// Descriptor for `TreeIndicatorStyle`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List treeIndicatorStyleDescriptor = $convert.base64Decode(
    'ChJUcmVlSW5kaWNhdG9yU3R5bGUSFwoTVFJFRV9JTkRJQ0FUT1JfTk9ORRAAEhkKFVRSRUVfSU'
    '5ESUNBVE9SX0FSUk9XUxABEh4KGlRSRUVfSU5ESUNBVE9SX0FSUk9XU19MRUFGEAISHQoZVFJF'
    'RV9JTkRJQ0FUT1JfQ09OTkVDVE9SUxADEiIKHlRSRUVfSU5ESUNBVE9SX0NPTk5FQ1RPUlNfTE'
    'VBRhAE');

@$core.Deprecated('Use groupTotalPositionDescriptor instead')
const GroupTotalPosition$json = {
  '1': 'GroupTotalPosition',
  '2': [
    {'1': 'GROUP_TOTAL_ABOVE', '2': 0},
    {'1': 'GROUP_TOTAL_BELOW', '2': 1},
  ],
};

/// Descriptor for `GroupTotalPosition`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List groupTotalPositionDescriptor = $convert.base64Decode(
    'ChJHcm91cFRvdGFsUG9zaXRpb24SFQoRR1JPVVBfVE9UQUxfQUJPVkUQABIVChFHUk9VUF9UT1'
    'RBTF9CRUxPVxAB');

@$core.Deprecated('Use aggregateTypeDescriptor instead')
const AggregateType$json = {
  '1': 'AggregateType',
  '2': [
    {'1': 'AGG_NONE', '2': 0},
    {'1': 'AGG_CLEAR', '2': 1},
    {'1': 'AGG_SUM', '2': 2},
    {'1': 'AGG_PERCENT', '2': 3},
    {'1': 'AGG_COUNT', '2': 4},
    {'1': 'AGG_AVERAGE', '2': 5},
    {'1': 'AGG_MAX', '2': 6},
    {'1': 'AGG_MIN', '2': 7},
    {'1': 'AGG_STD_DEV', '2': 8},
    {'1': 'AGG_VAR', '2': 9},
  ],
};

/// Descriptor for `AggregateType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List aggregateTypeDescriptor = $convert.base64Decode(
    'Cg1BZ2dyZWdhdGVUeXBlEgwKCEFHR19OT05FEAASDQoJQUdHX0NMRUFSEAESCwoHQUdHX1NVTR'
    'ACEg8KC0FHR19QRVJDRU5UEAMSDQoJQUdHX0NPVU5UEAQSDwoLQUdHX0FWRVJBR0UQBRILCgdB'
    'R0dfTUFYEAYSCwoHQUdHX01JThAHEg8KC0FHR19TVERfREVWEAgSCwoHQUdHX1ZBUhAJ');

@$core.Deprecated('Use cellSpanModeDescriptor instead')
const CellSpanMode$json = {
  '1': 'CellSpanMode',
  '2': [
    {'1': 'CELL_SPAN_NONE', '2': 0},
    {'1': 'CELL_SPAN_FREE', '2': 1},
    {'1': 'CELL_SPAN_BY_ROW', '2': 2},
    {'1': 'CELL_SPAN_BY_COLUMN', '2': 3},
    {'1': 'CELL_SPAN_ADJACENT', '2': 4},
    {'1': 'CELL_SPAN_HEADER_ONLY', '2': 5},
    {'1': 'CELL_SPAN_SPILL', '2': 6},
    {'1': 'CELL_SPAN_GROUP', '2': 7},
  ],
};

/// Descriptor for `CellSpanMode`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List cellSpanModeDescriptor = $convert.base64Decode(
    'CgxDZWxsU3Bhbk1vZGUSEgoOQ0VMTF9TUEFOX05PTkUQABISCg5DRUxMX1NQQU5fRlJFRRABEh'
    'QKEENFTExfU1BBTl9CWV9ST1cQAhIXChNDRUxMX1NQQU5fQllfQ09MVU1OEAMSFgoSQ0VMTF9T'
    'UEFOX0FESkFDRU5UEAQSGQoVQ0VMTF9TUEFOX0hFQURFUl9PTkxZEAUSEwoPQ0VMTF9TUEFOX1'
    'NQSUxMEAYSEwoPQ0VMTF9TUEFOX0dST1VQEAc=');

@$core.Deprecated('Use spanCompareModeDescriptor instead')
const SpanCompareMode$json = {
  '1': 'SpanCompareMode',
  '2': [
    {'1': 'SPAN_COMPARE_EXACT', '2': 0},
    {'1': 'SPAN_COMPARE_NO_CASE', '2': 1},
    {'1': 'SPAN_COMPARE_TRIM_NO_CASE', '2': 2},
    {'1': 'SPAN_COMPARE_INCLUDE_NULLS', '2': 3},
  ],
};

/// Descriptor for `SpanCompareMode`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List spanCompareModeDescriptor = $convert.base64Decode(
    'Cg9TcGFuQ29tcGFyZU1vZGUSFgoSU1BBTl9DT01QQVJFX0VYQUNUEAASGAoUU1BBTl9DT01QQV'
    'JFX05PX0NBU0UQARIdChlTUEFOX0NPTVBBUkVfVFJJTV9OT19DQVNFEAISHgoaU1BBTl9DT01Q'
    'QVJFX0lOQ0xVREVfTlVMTFMQAw==');

@$core.Deprecated('Use scrollBarsModeDescriptor instead')
const ScrollBarsMode$json = {
  '1': 'ScrollBarsMode',
  '2': [
    {'1': 'SCROLLBAR_NONE', '2': 0},
    {'1': 'SCROLLBAR_HORIZONTAL', '2': 1},
    {'1': 'SCROLLBAR_VERTICAL', '2': 2},
    {'1': 'SCROLLBAR_BOTH', '2': 3},
  ],
};

/// Descriptor for `ScrollBarsMode`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List scrollBarsModeDescriptor = $convert.base64Decode(
    'Cg5TY3JvbGxCYXJzTW9kZRISCg5TQ1JPTExCQVJfTk9ORRAAEhgKFFNDUk9MTEJBUl9IT1JJWk'
    '9OVEFMEAESFgoSU0NST0xMQkFSX1ZFUlRJQ0FMEAISEgoOU0NST0xMQkFSX0JPVEgQAw==');

@$core.Deprecated('Use scrollBarModeDescriptor instead')
const ScrollBarMode$json = {
  '1': 'ScrollBarMode',
  '2': [
    {'1': 'SCROLLBAR_MODE_AUTO', '2': 0},
    {'1': 'SCROLLBAR_MODE_ALWAYS', '2': 1},
    {'1': 'SCROLLBAR_MODE_NEVER', '2': 2},
  ],
};

/// Descriptor for `ScrollBarMode`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List scrollBarModeDescriptor = $convert.base64Decode(
    'Cg1TY3JvbGxCYXJNb2RlEhcKE1NDUk9MTEJBUl9NT0RFX0FVVE8QABIZChVTQ1JPTExCQVJfTU'
    '9ERV9BTFdBWVMQARIYChRTQ1JPTExCQVJfTU9ERV9ORVZFUhAC');

@$core.Deprecated('Use scrollBarAppearanceDescriptor instead')
const ScrollBarAppearance$json = {
  '1': 'ScrollBarAppearance',
  '2': [
    {'1': 'SCROLLBAR_APPEARANCE_CLASSIC', '2': 0},
    {'1': 'SCROLLBAR_APPEARANCE_FLAT', '2': 1},
    {'1': 'SCROLLBAR_APPEARANCE_MODERN', '2': 2},
    {'1': 'SCROLLBAR_APPEARANCE_OVERLAY', '2': 3},
  ],
};

/// Descriptor for `ScrollBarAppearance`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List scrollBarAppearanceDescriptor = $convert.base64Decode(
    'ChNTY3JvbGxCYXJBcHBlYXJhbmNlEiAKHFNDUk9MTEJBUl9BUFBFQVJBTkNFX0NMQVNTSUMQAB'
    'IdChlTQ1JPTExCQVJfQVBQRUFSQU5DRV9GTEFUEAESHwobU0NST0xMQkFSX0FQUEVBUkFOQ0Vf'
    'TU9ERVJOEAISIAocU0NST0xMQkFSX0FQUEVBUkFOQ0VfT1ZFUkxBWRAD');

@$core.Deprecated('Use pinPositionDescriptor instead')
const PinPosition$json = {
  '1': 'PinPosition',
  '2': [
    {'1': 'PIN_NONE', '2': 0},
    {'1': 'PIN_TOP', '2': 1},
    {'1': 'PIN_BOTTOM', '2': 2},
  ],
};

/// Descriptor for `PinPosition`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List pinPositionDescriptor = $convert.base64Decode(
    'CgtQaW5Qb3NpdGlvbhIMCghQSU5fTk9ORRAAEgsKB1BJTl9UT1AQARIOCgpQSU5fQk9UVE9NEA'
    'I=');

@$core.Deprecated('Use stickyEdgeDescriptor instead')
const StickyEdge$json = {
  '1': 'StickyEdge',
  '2': [
    {'1': 'STICKY_NONE', '2': 0},
    {'1': 'STICKY_TOP', '2': 1},
    {'1': 'STICKY_BOTTOM', '2': 2},
    {'1': 'STICKY_LEFT', '2': 3},
    {'1': 'STICKY_RIGHT', '2': 4},
    {'1': 'STICKY_BOTH', '2': 5},
  ],
};

/// Descriptor for `StickyEdge`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List stickyEdgeDescriptor = $convert.base64Decode(
    'CgpTdGlja3lFZGdlEg8KC1NUSUNLWV9OT05FEAASDgoKU1RJQ0tZX1RPUBABEhEKDVNUSUNLWV'
    '9CT1RUT00QAhIPCgtTVElDS1lfTEVGVBADEhAKDFNUSUNLWV9SSUdIVBAEEg8KC1NUSUNLWV9C'
    'T1RIEAU=');

@$core.Deprecated('Use typeAheadModeDescriptor instead')
const TypeAheadMode$json = {
  '1': 'TypeAheadMode',
  '2': [
    {'1': 'TYPE_AHEAD_NONE', '2': 0},
    {'1': 'TYPE_AHEAD_FROM_START', '2': 1},
    {'1': 'TYPE_AHEAD_FROM_CURSOR', '2': 2},
  ],
};

/// Descriptor for `TypeAheadMode`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List typeAheadModeDescriptor = $convert.base64Decode(
    'Cg1UeXBlQWhlYWRNb2RlEhMKD1RZUEVfQUhFQURfTk9ORRAAEhkKFVRZUEVfQUhFQURfRlJPTV'
    '9TVEFSVBABEhoKFlRZUEVfQUhFQURfRlJPTV9DVVJTT1IQAg==');

@$core.Deprecated('Use autoSizeModeDescriptor instead')
const AutoSizeMode$json = {
  '1': 'AutoSizeMode',
  '2': [
    {'1': 'AUTOSIZE_BOTH', '2': 0},
    {'1': 'AUTOSIZE_COL_WIDTH', '2': 1},
    {'1': 'AUTOSIZE_ROW_HEIGHT', '2': 2},
  ],
};

/// Descriptor for `AutoSizeMode`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List autoSizeModeDescriptor = $convert.base64Decode(
    'CgxBdXRvU2l6ZU1vZGUSEQoNQVVUT1NJWkVfQk9USBAAEhYKEkFVVE9TSVpFX0NPTF9XSURUSB'
    'ABEhcKE0FVVE9TSVpFX1JPV19IRUlHSFQQAg==');

@$core.Deprecated('Use dragModeDescriptor instead')
const DragMode$json = {
  '1': 'DragMode',
  '2': [
    {'1': 'DRAG_NONE', '2': 0},
    {'1': 'DRAG_MANUAL', '2': 1},
    {'1': 'DRAG_AUTOMATIC', '2': 2},
  ],
};

/// Descriptor for `DragMode`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List dragModeDescriptor = $convert.base64Decode(
    'CghEcmFnTW9kZRINCglEUkFHX05PTkUQABIPCgtEUkFHX01BTlVBTBABEhIKDkRSQUdfQVVUT0'
    '1BVElDEAI=');

@$core.Deprecated('Use dropModeDescriptor instead')
const DropMode$json = {
  '1': 'DropMode',
  '2': [
    {'1': 'DROP_NONE', '2': 0},
    {'1': 'DROP_MANUAL', '2': 1},
    {'1': 'DROP_AUTOMATIC', '2': 2},
  ],
};

/// Descriptor for `DropMode`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List dropModeDescriptor = $convert.base64Decode(
    'CghEcm9wTW9kZRINCglEUk9QX05PTkUQABIPCgtEUk9QX01BTlVBTBABEhIKDkRST1BfQVVUT0'
    '1BVElDEAI=');

@$core.Deprecated('Use customRenderModeDescriptor instead')
const CustomRenderMode$json = {
  '1': 'CustomRenderMode',
  '2': [
    {'1': 'CUSTOM_RENDER_NONE', '2': 0},
    {'1': 'CUSTOM_RENDER_CELL', '2': 1},
    {'1': 'CUSTOM_RENDER_ROW', '2': 2},
  ],
};

/// Descriptor for `CustomRenderMode`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List customRenderModeDescriptor = $convert.base64Decode(
    'ChBDdXN0b21SZW5kZXJNb2RlEhYKEkNVU1RPTV9SRU5ERVJfTk9ORRAAEhYKEkNVU1RPTV9SRU'
    '5ERVJfQ0VMTBABEhUKEUNVU1RPTV9SRU5ERVJfUk9XEAI=');

@$core.Deprecated('Use applyScopeDescriptor instead')
const ApplyScope$json = {
  '1': 'ApplyScope',
  '2': [
    {'1': 'APPLY_SINGLE', '2': 0},
    {'1': 'APPLY_SELECTION', '2': 1},
  ],
};

/// Descriptor for `ApplyScope`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List applyScopeDescriptor = $convert.base64Decode(
    'CgpBcHBseVNjb3BlEhAKDEFQUExZX1NJTkdMRRAAEhMKD0FQUExZX1NFTEVDVElPThAB');

@$core.Deprecated('Use rendererModeDescriptor instead')
const RendererMode$json = {
  '1': 'RendererMode',
  '2': [
    {'1': 'RENDERER_AUTO', '2': 0},
    {'1': 'RENDERER_CPU', '2': 1},
    {'1': 'RENDERER_GPU', '2': 2},
    {'1': 'RENDERER_GPU_VULKAN', '2': 3},
    {'1': 'RENDERER_GPU_GLES', '2': 4},
    {'1': 'RENDERER_TUI', '2': 5},
  ],
};

/// Descriptor for `RendererMode`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List rendererModeDescriptor = $convert.base64Decode(
    'CgxSZW5kZXJlck1vZGUSEQoNUkVOREVSRVJfQVVUTxAAEhAKDFJFTkRFUkVSX0NQVRABEhAKDF'
    'JFTkRFUkVSX0dQVRACEhcKE1JFTkRFUkVSX0dQVV9WVUxLQU4QAxIVChFSRU5ERVJFUl9HUFVf'
    'R0xFUxAEEhAKDFJFTkRFUkVSX1RVSRAF');

@$core.Deprecated('Use presentModeDescriptor instead')
const PresentMode$json = {
  '1': 'PresentMode',
  '2': [
    {'1': 'PRESENT_AUTO', '2': 0},
    {'1': 'PRESENT_FIFO', '2': 1},
    {'1': 'PRESENT_MAILBOX', '2': 2},
    {'1': 'PRESENT_IMMEDIATE', '2': 3},
  ],
};

/// Descriptor for `PresentMode`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List presentModeDescriptor = $convert.base64Decode(
    'CgtQcmVzZW50TW9kZRIQCgxQUkVTRU5UX0FVVE8QABIQCgxQUkVTRU5UX0ZJRk8QARITCg9QUk'
    'VTRU5UX01BSUxCT1gQAhIVChFQUkVTRU5UX0lNTUVESUFURRAD');

@$core.Deprecated('Use framePacingModeDescriptor instead')
const FramePacingMode$json = {
  '1': 'FramePacingMode',
  '2': [
    {'1': 'FRAME_PACING_MODE_AUTO', '2': 0},
    {'1': 'FRAME_PACING_MODE_PLATFORM', '2': 1},
    {'1': 'FRAME_PACING_MODE_UNLIMITED', '2': 2},
    {'1': 'FRAME_PACING_MODE_FIXED', '2': 3},
  ],
};

/// Descriptor for `FramePacingMode`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List framePacingModeDescriptor = $convert.base64Decode(
    'Cg9GcmFtZVBhY2luZ01vZGUSGgoWRlJBTUVfUEFDSU5HX01PREVfQVVUTxAAEh4KGkZSQU1FX1'
    'BBQ0lOR19NT0RFX1BMQVRGT1JNEAESHwobRlJBTUVfUEFDSU5HX01PREVfVU5MSU1JVEVEEAIS'
    'GwoXRlJBTUVfUEFDSU5HX01PREVfRklYRUQQAw==');

@$core.Deprecated('Use clearScopeDescriptor instead')
const ClearScope$json = {
  '1': 'ClearScope',
  '2': [
    {'1': 'CLEAR_SCOPE_UNSPECIFIED', '2': 0},
    {'1': 'CLEAR_EVERYTHING', '2': 1},
    {'1': 'CLEAR_FORMATTING', '2': 2},
    {'1': 'CLEAR_DATA', '2': 3},
    {'1': 'CLEAR_SELECTION', '2': 4},
  ],
};

/// Descriptor for `ClearScope`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List clearScopeDescriptor = $convert.base64Decode(
    'CgpDbGVhclNjb3BlEhsKF0NMRUFSX1NDT1BFX1VOU1BFQ0lGSUVEEAASFAoQQ0xFQVJfRVZFUl'
    'lUSElORxABEhQKEENMRUFSX0ZPUk1BVFRJTkcQAhIOCgpDTEVBUl9EQVRBEAMSEwoPQ0xFQVJf'
    'U0VMRUNUSU9OEAQ=');

@$core.Deprecated('Use clearRegionDescriptor instead')
const ClearRegion$json = {
  '1': 'ClearRegion',
  '2': [
    {'1': 'CLEAR_SCROLLABLE', '2': 0},
    {'1': 'CLEAR_FIXED_ROWS', '2': 1},
    {'1': 'CLEAR_FIXED_COLS', '2': 2},
    {'1': 'CLEAR_FIXED_BOTH', '2': 3},
    {'1': 'CLEAR_ALL_ROWS', '2': 4},
    {'1': 'CLEAR_ALL_COLS', '2': 5},
    {'1': 'CLEAR_ALL_BOTH', '2': 6},
  ],
};

/// Descriptor for `ClearRegion`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List clearRegionDescriptor = $convert.base64Decode(
    'CgtDbGVhclJlZ2lvbhIUChBDTEVBUl9TQ1JPTExBQkxFEAASFAoQQ0xFQVJfRklYRURfUk9XUx'
    'ABEhQKEENMRUFSX0ZJWEVEX0NPTFMQAhIUChBDTEVBUl9GSVhFRF9CT1RIEAMSEgoOQ0xFQVJf'
    'QUxMX1JPV1MQBBISCg5DTEVBUl9BTExfQ09MUxAFEhIKDkNMRUFSX0FMTF9CT1RIEAY=');

@$core.Deprecated('Use exportFormatDescriptor instead')
const ExportFormat$json = {
  '1': 'ExportFormat',
  '2': [
    {'1': 'EXPORT_FORMAT_UNSPECIFIED', '2': 0},
    {'1': 'EXPORT_BINARY', '2': 1},
    {'1': 'EXPORT_TSV', '2': 2},
    {'1': 'EXPORT_CSV', '2': 3},
    {'1': 'EXPORT_DELIMITED', '2': 4},
    {'1': 'EXPORT_XLSX', '2': 5},
  ],
};

/// Descriptor for `ExportFormat`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List exportFormatDescriptor = $convert.base64Decode(
    'CgxFeHBvcnRGb3JtYXQSHQoZRVhQT1JUX0ZPUk1BVF9VTlNQRUNJRklFRBAAEhEKDUVYUE9SVF'
    '9CSU5BUlkQARIOCgpFWFBPUlRfVFNWEAISDgoKRVhQT1JUX0NTVhADEhQKEEVYUE9SVF9ERUxJ'
    'TUlURUQQBBIPCgtFWFBPUlRfWExTWBAF');

@$core.Deprecated('Use exportScopeDescriptor instead')
const ExportScope$json = {
  '1': 'ExportScope',
  '2': [
    {'1': 'EXPORT_SCOPE_UNSPECIFIED', '2': 0},
    {'1': 'EXPORT_ALL', '2': 1},
    {'1': 'EXPORT_DATA_ONLY', '2': 2},
    {'1': 'EXPORT_FORMAT_ONLY', '2': 3},
  ],
};

/// Descriptor for `ExportScope`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List exportScopeDescriptor = $convert.base64Decode(
    'CgtFeHBvcnRTY29wZRIcChhFWFBPUlRfU0NPUEVfVU5TUEVDSUZJRUQQABIOCgpFWFBPUlRfQU'
    'xMEAESFAoQRVhQT1JUX0RBVEFfT05MWRACEhYKEkVYUE9SVF9GT1JNQVRfT05MWRAD');

@$core.Deprecated('Use printOrientationDescriptor instead')
const PrintOrientation$json = {
  '1': 'PrintOrientation',
  '2': [
    {'1': 'PRINT_PORTRAIT', '2': 0},
    {'1': 'PRINT_LANDSCAPE', '2': 1},
  ],
};

/// Descriptor for `PrintOrientation`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List printOrientationDescriptor = $convert.base64Decode(
    'ChBQcmludE9yaWVudGF0aW9uEhIKDlBSSU5UX1BPUlRSQUlUEAASEwoPUFJJTlRfTEFORFNDQV'
    'BFEAE=');

@$core.Deprecated('Use nodeRelationDescriptor instead')
const NodeRelation$json = {
  '1': 'NodeRelation',
  '2': [
    {'1': 'NODE_PARENT', '2': 0},
    {'1': 'NODE_FIRST_CHILD', '2': 1},
    {'1': 'NODE_LAST_CHILD', '2': 2},
    {'1': 'NODE_NEXT_SIBLING', '2': 3},
    {'1': 'NODE_PREV_SIBLING', '2': 4},
  ],
};

/// Descriptor for `NodeRelation`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List nodeRelationDescriptor = $convert.base64Decode(
    'CgxOb2RlUmVsYXRpb24SDwoLTk9ERV9QQVJFTlQQABIUChBOT0RFX0ZJUlNUX0NISUxEEAESEw'
    'oPTk9ERV9MQVNUX0NISUxEEAISFQoRTk9ERV9ORVhUX1NJQkxJTkcQAxIVChFOT0RFX1BSRVZf'
    'U0lCTElORxAE');

@$core.Deprecated('Use iconAlignDescriptor instead')
const IconAlign$json = {
  '1': 'IconAlign',
  '2': [
    {'1': 'ICON_ALIGN_INLINE_END', '2': 0},
    {'1': 'ICON_ALIGN_INLINE_START', '2': 1},
    {'1': 'ICON_ALIGN_START', '2': 2},
    {'1': 'ICON_ALIGN_END', '2': 3},
    {'1': 'ICON_ALIGN_CENTER', '2': 4},
  ],
};

/// Descriptor for `IconAlign`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List iconAlignDescriptor = $convert.base64Decode(
    'CglJY29uQWxpZ24SGQoVSUNPTl9BTElHTl9JTkxJTkVfRU5EEAASGwoXSUNPTl9BTElHTl9JTk'
    'xJTkVfU1RBUlQQARIUChBJQ09OX0FMSUdOX1NUQVJUEAISEgoOSUNPTl9BTElHTl9FTkQQAxIV'
    'ChFJQ09OX0FMSUdOX0NFTlRFUhAE');

@$core.Deprecated('Use cellHitAreaDescriptor instead')
const CellHitArea$json = {
  '1': 'CellHitArea',
  '2': [
    {'1': 'HIT_CELL', '2': 0},
    {'1': 'HIT_TEXT', '2': 1},
    {'1': 'HIT_PICTURE', '2': 2},
    {'1': 'HIT_BUTTON', '2': 3},
    {'1': 'HIT_CHECKBOX', '2': 4},
    {'1': 'HIT_DROPDOWN', '2': 5},
  ],
};

/// Descriptor for `CellHitArea`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List cellHitAreaDescriptor = $convert.base64Decode(
    'CgtDZWxsSGl0QXJlYRIMCghISVRfQ0VMTBAAEgwKCEhJVF9URVhUEAESDwoLSElUX1BJQ1RVUk'
    'UQAhIOCgpISVRfQlVUVE9OEAMSEAoMSElUX0NIRUNLQk9YEAQSEAoMSElUX0RST1BET1dOEAU=');

@$core.Deprecated('Use pullToRefreshThemeDescriptor instead')
const PullToRefreshTheme$json = {
  '1': 'PullToRefreshTheme',
  '2': [
    {'1': 'PULL_TO_REFRESH_THEME_UNSPECIFIED', '2': 0},
    {'1': 'PULL_TO_REFRESH_THEME_TOP_BAND', '2': 1},
    {'1': 'PULL_TO_REFRESH_THEME_MATERIAL', '2': 2},
  ],
};

/// Descriptor for `PullToRefreshTheme`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List pullToRefreshThemeDescriptor = $convert.base64Decode(
    'ChJQdWxsVG9SZWZyZXNoVGhlbWUSJQohUFVMTF9UT19SRUZSRVNIX1RIRU1FX1VOU1BFQ0lGSU'
    'VEEAASIgoeUFVMTF9UT19SRUZSRVNIX1RIRU1FX1RPUF9CQU5EEAESIgoeUFVMTF9UT19SRUZS'
    'RVNIX1RIRU1FX01BVEVSSUFMEAI=');

@$core.Deprecated('Use renderLayerBitDescriptor instead')
const RenderLayerBit$json = {
  '1': 'RenderLayerBit',
  '2': [
    {'1': 'RENDER_LAYER_OVERLAY_BANDS', '2': 0},
    {'1': 'RENDER_LAYER_INDICATORS', '2': 1},
    {'1': 'RENDER_LAYER_BACKGROUNDS', '2': 2},
    {'1': 'RENDER_LAYER_PROGRESS_BARS', '2': 3},
    {'1': 'RENDER_LAYER_GRID_LINES', '2': 4},
    {'1': 'RENDER_LAYER_HEADER_MARKS', '2': 5},
    {'1': 'RENDER_LAYER_BACKGROUND_IMAGE', '2': 6},
    {'1': 'RENDER_LAYER_CELL_BORDERS', '2': 7},
    {'1': 'RENDER_LAYER_CELL_TEXT', '2': 8},
    {'1': 'RENDER_LAYER_CELL_PICTURES', '2': 9},
    {'1': 'RENDER_LAYER_SORT_GLYPHS', '2': 10},
    {'1': 'RENDER_LAYER_COL_DRAG_MARKER', '2': 11},
    {'1': 'RENDER_LAYER_CHECKBOXES', '2': 12},
    {'1': 'RENDER_LAYER_DROPDOWN_BUTTONS', '2': 13},
    {'1': 'RENDER_LAYER_SELECTION', '2': 14},
    {'1': 'RENDER_LAYER_HOVER_HIGHLIGHT', '2': 15},
    {'1': 'RENDER_LAYER_EDIT_HIGHLIGHTS', '2': 16},
    {'1': 'RENDER_LAYER_FOCUS_RECT', '2': 17},
    {'1': 'RENDER_LAYER_FILL_HANDLE', '2': 18},
    {'1': 'RENDER_LAYER_OUTLINE', '2': 19},
    {'1': 'RENDER_LAYER_FROZEN_BORDERS', '2': 20},
    {'1': 'RENDER_LAYER_ACTIVE_EDITOR', '2': 21},
    {'1': 'RENDER_LAYER_ACTIVE_DROPDOWN', '2': 22},
    {'1': 'RENDER_LAYER_SCROLL_BARS', '2': 23},
    {'1': 'RENDER_LAYER_FAST_SCROLL', '2': 24},
    {'1': 'RENDER_LAYER_PULL_TO_REFRESH', '2': 25},
    {'1': 'RENDER_LAYER_DEBUG_OVERLAY', '2': 26},
    {'1': 'RENDER_LAYER_BARCODES', '2': 27},
  ],
};

/// Descriptor for `RenderLayerBit`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List renderLayerBitDescriptor = $convert.base64Decode(
    'Cg5SZW5kZXJMYXllckJpdBIeChpSRU5ERVJfTEFZRVJfT1ZFUkxBWV9CQU5EUxAAEhsKF1JFTk'
    'RFUl9MQVlFUl9JTkRJQ0FUT1JTEAESHAoYUkVOREVSX0xBWUVSX0JBQ0tHUk9VTkRTEAISHgoa'
    'UkVOREVSX0xBWUVSX1BST0dSRVNTX0JBUlMQAxIbChdSRU5ERVJfTEFZRVJfR1JJRF9MSU5FUx'
    'AEEh0KGVJFTkRFUl9MQVlFUl9IRUFERVJfTUFSS1MQBRIhCh1SRU5ERVJfTEFZRVJfQkFDS0dS'
    'T1VORF9JTUFHRRAGEh0KGVJFTkRFUl9MQVlFUl9DRUxMX0JPUkRFUlMQBxIaChZSRU5ERVJfTE'
    'FZRVJfQ0VMTF9URVhUEAgSHgoaUkVOREVSX0xBWUVSX0NFTExfUElDVFVSRVMQCRIcChhSRU5E'
    'RVJfTEFZRVJfU09SVF9HTFlQSFMQChIgChxSRU5ERVJfTEFZRVJfQ09MX0RSQUdfTUFSS0VSEA'
    'sSGwoXUkVOREVSX0xBWUVSX0NIRUNLQk9YRVMQDBIhCh1SRU5ERVJfTEFZRVJfRFJPUERPV05f'
    'QlVUVE9OUxANEhoKFlJFTkRFUl9MQVlFUl9TRUxFQ1RJT04QDhIgChxSRU5ERVJfTEFZRVJfSE'
    '9WRVJfSElHSExJR0hUEA8SIAocUkVOREVSX0xBWUVSX0VESVRfSElHSExJR0hUUxAQEhsKF1JF'
    'TkRFUl9MQVlFUl9GT0NVU19SRUNUEBESHAoYUkVOREVSX0xBWUVSX0ZJTExfSEFORExFEBISGA'
    'oUUkVOREVSX0xBWUVSX09VVExJTkUQExIfChtSRU5ERVJfTEFZRVJfRlJPWkVOX0JPUkRFUlMQ'
    'FBIeChpSRU5ERVJfTEFZRVJfQUNUSVZFX0VESVRPUhAVEiAKHFJFTkRFUl9MQVlFUl9BQ1RJVk'
    'VfRFJPUERPV04QFhIcChhSRU5ERVJfTEFZRVJfU0NST0xMX0JBUlMQFxIcChhSRU5ERVJfTEFZ'
    'RVJfRkFTVF9TQ1JPTEwQGBIgChxSRU5ERVJfTEFZRVJfUFVMTF9UT19SRUZSRVNIEBkSHgoaUk'
    'VOREVSX0xBWUVSX0RFQlVHX09WRVJMQVkQGhIZChVSRU5ERVJfTEFZRVJfQkFSQ09ERVMQGw==');

@$core.Deprecated('Use rowIndicatorSlotKindDescriptor instead')
const RowIndicatorSlotKind$json = {
  '1': 'RowIndicatorSlotKind',
  '2': [
    {'1': 'ROW_INDICATOR_SLOT_NONE', '2': 0},
    {'1': 'ROW_INDICATOR_SLOT_NUMBERS', '2': 1},
    {'1': 'ROW_INDICATOR_SLOT_CURRENT', '2': 2},
    {'1': 'ROW_INDICATOR_SLOT_SELECTION', '2': 3},
    {'1': 'ROW_INDICATOR_SLOT_CHECKBOX', '2': 4},
    {'1': 'ROW_INDICATOR_SLOT_HANDLE', '2': 5},
    {'1': 'ROW_INDICATOR_SLOT_EDITING', '2': 6},
    {'1': 'ROW_INDICATOR_SLOT_MODIFIED', '2': 7},
    {'1': 'ROW_INDICATOR_SLOT_ERROR', '2': 8},
    {'1': 'ROW_INDICATOR_SLOT_NEW_ROW', '2': 9},
    {'1': 'ROW_INDICATOR_SLOT_EXPANDER', '2': 10},
    {'1': 'ROW_INDICATOR_SLOT_RESIZE', '2': 11},
    {'1': 'ROW_INDICATOR_SLOT_ACTION', '2': 12},
    {'1': 'ROW_INDICATOR_SLOT_STATUS_ICON', '2': 13},
    {'1': 'ROW_INDICATOR_SLOT_CUSTOM', '2': 14},
  ],
};

/// Descriptor for `RowIndicatorSlotKind`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List rowIndicatorSlotKindDescriptor = $convert.base64Decode(
    'ChRSb3dJbmRpY2F0b3JTbG90S2luZBIbChdST1dfSU5ESUNBVE9SX1NMT1RfTk9ORRAAEh4KGl'
    'JPV19JTkRJQ0FUT1JfU0xPVF9OVU1CRVJTEAESHgoaUk9XX0lORElDQVRPUl9TTE9UX0NVUlJF'
    'TlQQAhIgChxST1dfSU5ESUNBVE9SX1NMT1RfU0VMRUNUSU9OEAMSHwobUk9XX0lORElDQVRPUl'
    '9TTE9UX0NIRUNLQk9YEAQSHQoZUk9XX0lORElDQVRPUl9TTE9UX0hBTkRMRRAFEh4KGlJPV19J'
    'TkRJQ0FUT1JfU0xPVF9FRElUSU5HEAYSHwobUk9XX0lORElDQVRPUl9TTE9UX01PRElGSUVEEA'
    'cSHAoYUk9XX0lORElDQVRPUl9TTE9UX0VSUk9SEAgSHgoaUk9XX0lORElDQVRPUl9TTE9UX05F'
    'V19ST1cQCRIfChtST1dfSU5ESUNBVE9SX1NMT1RfRVhQQU5ERVIQChIdChlST1dfSU5ESUNBVE'
    '9SX1NMT1RfUkVTSVpFEAsSHQoZUk9XX0lORElDQVRPUl9TTE9UX0FDVElPThAMEiIKHlJPV19J'
    'TkRJQ0FUT1JfU0xPVF9TVEFUVVNfSUNPThANEh0KGVJPV19JTkRJQ0FUT1JfU0xPVF9DVVNUT0'
    '0QDg==');

@$core.Deprecated('Use rowIndicatorModeDescriptor instead')
const RowIndicatorMode$json = {
  '1': 'RowIndicatorMode',
  '2': [
    {'1': 'ROW_INDICATOR_NONE', '2': 0},
    {'1': 'ROW_INDICATOR_NUMBERS', '2': 1},
    {'1': 'ROW_INDICATOR_CURRENT', '2': 2},
    {'1': 'ROW_INDICATOR_SELECTION', '2': 4},
    {'1': 'ROW_INDICATOR_CHECKBOX', '2': 8},
    {'1': 'ROW_INDICATOR_HANDLE', '2': 16},
    {'1': 'ROW_INDICATOR_EDITING', '2': 32},
    {'1': 'ROW_INDICATOR_MODIFIED', '2': 64},
    {'1': 'ROW_INDICATOR_ERROR', '2': 128},
    {'1': 'ROW_INDICATOR_NEW_ROW', '2': 256},
    {'1': 'ROW_INDICATOR_EXPANDER', '2': 512},
    {'1': 'ROW_INDICATOR_RESIZE', '2': 1024},
    {'1': 'ROW_INDICATOR_ACTION', '2': 2048},
    {'1': 'ROW_INDICATOR_STATUS_ICON', '2': 4096},
    {'1': 'ROW_INDICATOR_CUSTOM', '2': 8192},
  ],
};

/// Descriptor for `RowIndicatorMode`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List rowIndicatorModeDescriptor = $convert.base64Decode(
    'ChBSb3dJbmRpY2F0b3JNb2RlEhYKElJPV19JTkRJQ0FUT1JfTk9ORRAAEhkKFVJPV19JTkRJQ0'
    'FUT1JfTlVNQkVSUxABEhkKFVJPV19JTkRJQ0FUT1JfQ1VSUkVOVBACEhsKF1JPV19JTkRJQ0FU'
    'T1JfU0VMRUNUSU9OEAQSGgoWUk9XX0lORElDQVRPUl9DSEVDS0JPWBAIEhgKFFJPV19JTkRJQ0'
    'FUT1JfSEFORExFEBASGQoVUk9XX0lORElDQVRPUl9FRElUSU5HECASGgoWUk9XX0lORElDQVRP'
    'Ul9NT0RJRklFRBBAEhgKE1JPV19JTkRJQ0FUT1JfRVJST1IQgAESGgoVUk9XX0lORElDQVRPUl'
    '9ORVdfUk9XEIACEhsKFlJPV19JTkRJQ0FUT1JfRVhQQU5ERVIQgAQSGQoUUk9XX0lORElDQVRP'
    'Ul9SRVNJWkUQgAgSGQoUUk9XX0lORElDQVRPUl9BQ1RJT04QgBASHgoZUk9XX0lORElDQVRPUl'
    '9TVEFUVVNfSUNPThCAIBIZChRST1dfSU5ESUNBVE9SX0NVU1RPTRCAQA==');

@$core.Deprecated('Use colIndicatorCellModeDescriptor instead')
const ColIndicatorCellMode$json = {
  '1': 'ColIndicatorCellMode',
  '2': [
    {'1': 'COL_INDICATOR_CELL_NONE', '2': 0},
    {'1': 'COL_INDICATOR_CELL_HEADER_TEXT', '2': 1},
    {'1': 'COL_INDICATOR_CELL_SORT_GLYPH', '2': 2},
    {'1': 'COL_INDICATOR_CELL_SORT_PRIORITY', '2': 4},
    {'1': 'COL_INDICATOR_CELL_FILTER_BUTTON', '2': 8},
    {'1': 'COL_INDICATOR_CELL_FILTER_STATE', '2': 16},
    {'1': 'COL_INDICATOR_CELL_MENU_BUTTON', '2': 32},
    {'1': 'COL_INDICATOR_CELL_CHOOSER', '2': 64},
    {'1': 'COL_INDICATOR_CELL_DRAG_REORDER', '2': 128},
    {'1': 'COL_INDICATOR_CELL_HIDDEN_MARKER', '2': 256},
    {'1': 'COL_INDICATOR_CELL_RESIZE_HANDLE', '2': 512},
    {'1': 'COL_INDICATOR_CELL_SELECT_ALL', '2': 1024},
    {'1': 'COL_INDICATOR_CELL_STATUS_ICON', '2': 2048},
    {'1': 'COL_INDICATOR_CELL_CUSTOM', '2': 4096},
  ],
};

/// Descriptor for `ColIndicatorCellMode`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List colIndicatorCellModeDescriptor = $convert.base64Decode(
    'ChRDb2xJbmRpY2F0b3JDZWxsTW9kZRIbChdDT0xfSU5ESUNBVE9SX0NFTExfTk9ORRAAEiIKHk'
    'NPTF9JTkRJQ0FUT1JfQ0VMTF9IRUFERVJfVEVYVBABEiEKHUNPTF9JTkRJQ0FUT1JfQ0VMTF9T'
    'T1JUX0dMWVBIEAISJAogQ09MX0lORElDQVRPUl9DRUxMX1NPUlRfUFJJT1JJVFkQBBIkCiBDT0'
    'xfSU5ESUNBVE9SX0NFTExfRklMVEVSX0JVVFRPThAIEiMKH0NPTF9JTkRJQ0FUT1JfQ0VMTF9G'
    'SUxURVJfU1RBVEUQEBIiCh5DT0xfSU5ESUNBVE9SX0NFTExfTUVOVV9CVVRUT04QIBIeChpDT0'
    'xfSU5ESUNBVE9SX0NFTExfQ0hPT1NFUhBAEiQKH0NPTF9JTkRJQ0FUT1JfQ0VMTF9EUkFHX1JF'
    'T1JERVIQgAESJQogQ09MX0lORElDQVRPUl9DRUxMX0hJRERFTl9NQVJLRVIQgAISJQogQ09MX0'
    'lORElDQVRPUl9DRUxMX1JFU0laRV9IQU5ETEUQgAQSIgodQ09MX0lORElDQVRPUl9DRUxMX1NF'
    'TEVDVF9BTEwQgAgSIwoeQ09MX0lORElDQVRPUl9DRUxMX1NUQVRVU19JQ09OEIAQEh4KGUNPTF'
    '9JTkRJQ0FUT1JfQ0VMTF9DVVNUT00QgCA=');

@$core.Deprecated('Use composeMethodDescriptor instead')
const ComposeMethod$json = {
  '1': 'ComposeMethod',
  '2': [
    {'1': 'COMPOSE_METHOD_NONE', '2': 0},
    {'1': 'COMPOSE_METHOD_HANGUL', '2': 1},
    {'1': 'COMPOSE_METHOD_DEAD_KEY', '2': 2},
    {'1': 'COMPOSE_METHOD_TELEX', '2': 3},
  ],
};

/// Descriptor for `ComposeMethod`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List composeMethodDescriptor = $convert.base64Decode(
    'Cg1Db21wb3NlTWV0aG9kEhcKE0NPTVBPU0VfTUVUSE9EX05PTkUQABIZChVDT01QT1NFX01FVE'
    'hPRF9IQU5HVUwQARIbChdDT01QT1NFX01FVEhPRF9ERUFEX0tFWRACEhgKFENPTVBPU0VfTUVU'
    'SE9EX1RFTEVYEAM=');

@$core.Deprecated('Use editUiModeDescriptor instead')
const EditUiMode$json = {
  '1': 'EditUiMode',
  '2': [
    {'1': 'EDIT_UI_MODE_ENTER', '2': 0},
    {'1': 'EDIT_UI_MODE_EDIT', '2': 1},
  ],
};

/// Descriptor for `EditUiMode`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List editUiModeDescriptor = $convert.base64Decode(
    'CgpFZGl0VWlNb2RlEhYKEkVESVRfVUlfTU9ERV9FTlRFUhAAEhUKEUVESVRfVUlfTU9ERV9FRE'
    'lUEAE=');

@$core.Deprecated('Use errorCodeDescriptor instead')
const ErrorCode$json = {
  '1': 'ErrorCode',
  '2': [
    {'1': 'ERROR_UNKNOWN', '2': 0},
    {'1': 'ERROR_INVALID_ARGUMENT', '2': 1},
    {'1': 'ERROR_NOT_FOUND', '2': 2},
    {'1': 'ERROR_INVALID_STATE', '2': 3},
    {'1': 'ERROR_TYPE_VIOLATION', '2': 4},
    {'1': 'ERROR_DECODE_FAILED', '2': 5},
    {'1': 'ERROR_ENCODE_FAILED', '2': 6},
    {'1': 'ERROR_NOT_IMPLEMENTED', '2': 7},
    {'1': 'ERROR_INTERNAL', '2': 8},
  ],
};

/// Descriptor for `ErrorCode`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List errorCodeDescriptor = $convert.base64Decode(
    'CglFcnJvckNvZGUSEQoNRVJST1JfVU5LTk9XThAAEhoKFkVSUk9SX0lOVkFMSURfQVJHVU1FTl'
    'QQARITCg9FUlJPUl9OT1RfRk9VTkQQAhIXChNFUlJPUl9JTlZBTElEX1NUQVRFEAMSGAoURVJS'
    'T1JfVFlQRV9WSU9MQVRJT04QBBIXChNFUlJPUl9ERUNPREVfRkFJTEVEEAUSFwoTRVJST1JfRU'
    '5DT0RFX0ZBSUxFRBAGEhkKFUVSUk9SX05PVF9JTVBMRU1FTlRFRBAHEhIKDkVSUk9SX0lOVEVS'
    'TkFMEAg=');

@$core.Deprecated('Use demoDataFormatDescriptor instead')
const DemoDataFormat$json = {
  '1': 'DemoDataFormat',
  '2': [
    {'1': 'DEMO_DATA_FORMAT_UNSPECIFIED', '2': 0},
    {'1': 'DEMO_DATA_FORMAT_JSON', '2': 1},
  ],
};

/// Descriptor for `DemoDataFormat`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List demoDataFormatDescriptor = $convert.base64Decode(
    'Cg5EZW1vRGF0YUZvcm1hdBIgChxERU1PX0RBVEFfRk9STUFUX1VOU1BFQ0lGSUVEEAASGQoVRE'
    'VNT19EQVRBX0ZPUk1BVF9KU09OEAE=');

@$core.Deprecated('Use terminalColorLevelDescriptor instead')
const TerminalColorLevel$json = {
  '1': 'TerminalColorLevel',
  '2': [
    {'1': 'TERMINAL_COLOR_LEVEL_AUTO', '2': 0},
    {'1': 'TERMINAL_COLOR_LEVEL_TRUECOLOR', '2': 1},
    {'1': 'TERMINAL_COLOR_LEVEL_256', '2': 2},
    {'1': 'TERMINAL_COLOR_LEVEL_16', '2': 3},
  ],
};

/// Descriptor for `TerminalColorLevel`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List terminalColorLevelDescriptor = $convert.base64Decode(
    'ChJUZXJtaW5hbENvbG9yTGV2ZWwSHQoZVEVSTUlOQUxfQ09MT1JfTEVWRUxfQVVUTxAAEiIKHl'
    'RFUk1JTkFMX0NPTE9SX0xFVkVMX1RSVUVDT0xPUhABEhwKGFRFUk1JTkFMX0NPTE9SX0xFVkVM'
    'XzI1NhACEhsKF1RFUk1JTkFMX0NPTE9SX0xFVkVMXzE2EAM=');

@$core.Deprecated('Use frameKindDescriptor instead')
const FrameKind$json = {
  '1': 'FrameKind',
  '2': [
    {'1': 'FRAME_KIND_FRAME', '2': 0},
    {'1': 'FRAME_KIND_SESSION_START', '2': 1},
    {'1': 'FRAME_KIND_SESSION_END', '2': 2},
  ],
};

/// Descriptor for `FrameKind`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List frameKindDescriptor = $convert.base64Decode(
    'CglGcmFtZUtpbmQSFAoQRlJBTUVfS0lORF9GUkFNRRAAEhwKGEZSQU1FX0tJTkRfU0VTU0lPTl'
    '9TVEFSVBABEhoKFkZSQU1FX0tJTkRfU0VTU0lPTl9FTkQQAg==');

@$core.Deprecated('Use fontDescriptor instead')
const Font$json = {
  '1': 'Font',
  '2': [
    {'1': 'family', '3': 1, '4': 1, '5': 9, '9': 0, '10': 'family', '17': true},
    {'1': 'families', '3': 2, '4': 3, '5': 9, '10': 'families'},
    {'1': 'size', '3': 3, '4': 1, '5': 2, '9': 1, '10': 'size', '17': true},
    {'1': 'bold', '3': 4, '4': 1, '5': 8, '9': 2, '10': 'bold', '17': true},
    {'1': 'italic', '3': 5, '4': 1, '5': 8, '9': 3, '10': 'italic', '17': true},
    {
      '1': 'underline',
      '3': 6,
      '4': 1,
      '5': 8,
      '9': 4,
      '10': 'underline',
      '17': true
    },
    {
      '1': 'strikethrough',
      '3': 7,
      '4': 1,
      '5': 8,
      '9': 5,
      '10': 'strikethrough',
      '17': true
    },
    {
      '1': 'stretch',
      '3': 8,
      '4': 1,
      '5': 2,
      '9': 6,
      '10': 'stretch',
      '17': true
    },
  ],
  '8': [
    {'1': '_family'},
    {'1': '_size'},
    {'1': '_bold'},
    {'1': '_italic'},
    {'1': '_underline'},
    {'1': '_strikethrough'},
    {'1': '_stretch'},
  ],
};

/// Descriptor for `Font`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List fontDescriptor = $convert.base64Decode(
    'CgRGb250EhsKBmZhbWlseRgBIAEoCUgAUgZmYW1pbHmIAQESGgoIZmFtaWxpZXMYAiADKAlSCG'
    'ZhbWlsaWVzEhcKBHNpemUYAyABKAJIAVIEc2l6ZYgBARIXCgRib2xkGAQgASgISAJSBGJvbGSI'
    'AQESGwoGaXRhbGljGAUgASgISANSBml0YWxpY4gBARIhCgl1bmRlcmxpbmUYBiABKAhIBFIJdW'
    '5kZXJsaW5liAEBEikKDXN0cmlrZXRocm91Z2gYByABKAhIBVINc3RyaWtldGhyb3VnaIgBARId'
    'CgdzdHJldGNoGAggASgCSAZSB3N0cmV0Y2iIAQFCCQoHX2ZhbWlseUIHCgVfc2l6ZUIHCgVfYm'
    '9sZEIJCgdfaXRhbGljQgwKCl91bmRlcmxpbmVCEAoOX3N0cmlrZXRocm91Z2hCCgoIX3N0cmV0'
    'Y2g=');

@$core.Deprecated('Use paddingDescriptor instead')
const Padding$json = {
  '1': 'Padding',
  '2': [
    {'1': 'left', '3': 1, '4': 1, '5': 5, '9': 0, '10': 'left', '17': true},
    {'1': 'top', '3': 2, '4': 1, '5': 5, '9': 1, '10': 'top', '17': true},
    {'1': 'right', '3': 3, '4': 1, '5': 5, '9': 2, '10': 'right', '17': true},
    {'1': 'bottom', '3': 4, '4': 1, '5': 5, '9': 3, '10': 'bottom', '17': true},
  ],
  '8': [
    {'1': '_left'},
    {'1': '_top'},
    {'1': '_right'},
    {'1': '_bottom'},
  ],
};

/// Descriptor for `Padding`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List paddingDescriptor = $convert.base64Decode(
    'CgdQYWRkaW5nEhcKBGxlZnQYASABKAVIAFIEbGVmdIgBARIVCgN0b3AYAiABKAVIAVIDdG9wiA'
    'EBEhkKBXJpZ2h0GAMgASgFSAJSBXJpZ2h0iAEBEhsKBmJvdHRvbRgEIAEoBUgDUgZib3R0b22I'
    'AQFCBwoFX2xlZnRCBgoEX3RvcEIICgZfcmlnaHRCCQoHX2JvdHRvbQ==');

@$core.Deprecated('Use borderDescriptor instead')
const Border$json = {
  '1': 'Border',
  '2': [
    {
      '1': 'style',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.BorderStyle',
      '9': 0,
      '10': 'style',
      '17': true
    },
    {'1': 'color', '3': 2, '4': 1, '5': 13, '9': 1, '10': 'color', '17': true},
  ],
  '8': [
    {'1': '_style'},
    {'1': '_color'},
  ],
};

/// Descriptor for `Border`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List borderDescriptor = $convert.base64Decode(
    'CgZCb3JkZXISNQoFc3R5bGUYASABKA4yGi52b2x2b3hncmlkLnYxLkJvcmRlclN0eWxlSABSBX'
    'N0eWxliAEBEhkKBWNvbG9yGAIgASgNSAFSBWNvbG9yiAEBQggKBl9zdHlsZUIICgZfY29sb3I=');

@$core.Deprecated('Use bordersDescriptor instead')
const Borders$json = {
  '1': 'Borders',
  '2': [
    {
      '1': 'all',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.Border',
      '10': 'all'
    },
    {
      '1': 'top',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.Border',
      '10': 'top'
    },
    {
      '1': 'right',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.Border',
      '10': 'right'
    },
    {
      '1': 'bottom',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.Border',
      '10': 'bottom'
    },
    {
      '1': 'left',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.Border',
      '10': 'left'
    },
  ],
};

/// Descriptor for `Borders`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List bordersDescriptor = $convert.base64Decode(
    'CgdCb3JkZXJzEicKA2FsbBgBIAEoCzIVLnZvbHZveGdyaWQudjEuQm9yZGVyUgNhbGwSJwoDdG'
    '9wGAIgASgLMhUudm9sdm94Z3JpZC52MS5Cb3JkZXJSA3RvcBIrCgVyaWdodBgDIAEoCzIVLnZv'
    'bHZveGdyaWQudjEuQm9yZGVyUgVyaWdodBItCgZib3R0b20YBCABKAsyFS52b2x2b3hncmlkLn'
    'YxLkJvcmRlclIGYm90dG9tEikKBGxlZnQYBSABKAsyFS52b2x2b3hncmlkLnYxLkJvcmRlclIE'
    'bGVmdA==');

@$core.Deprecated('Use gridLinesDescriptor instead')
const GridLines$json = {
  '1': 'GridLines',
  '2': [
    {
      '1': 'style',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.GridLineStyle',
      '9': 0,
      '10': 'style',
      '17': true
    },
    {
      '1': 'direction',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.GridLineDirection',
      '9': 1,
      '10': 'direction',
      '17': true
    },
    {'1': 'color', '3': 3, '4': 1, '5': 13, '9': 2, '10': 'color', '17': true},
    {'1': 'width', '3': 4, '4': 1, '5': 5, '9': 3, '10': 'width', '17': true},
  ],
  '8': [
    {'1': '_style'},
    {'1': '_direction'},
    {'1': '_color'},
    {'1': '_width'},
  ],
};

/// Descriptor for `GridLines`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List gridLinesDescriptor = $convert.base64Decode(
    'CglHcmlkTGluZXMSNwoFc3R5bGUYASABKA4yHC52b2x2b3hncmlkLnYxLkdyaWRMaW5lU3R5bG'
    'VIAFIFc3R5bGWIAQESQwoJZGlyZWN0aW9uGAIgASgOMiAudm9sdm94Z3JpZC52MS5HcmlkTGlu'
    'ZURpcmVjdGlvbkgBUglkaXJlY3Rpb26IAQESGQoFY29sb3IYAyABKA1IAlIFY29sb3KIAQESGQ'
    'oFd2lkdGgYBCABKAVIA1IFd2lkdGiIAQFCCAoGX3N0eWxlQgwKCl9kaXJlY3Rpb25CCAoGX2Nv'
    'bG9yQggKBl93aWR0aA==');

@$core.Deprecated('Use separatorDescriptor instead')
const Separator$json = {
  '1': 'Separator',
  '2': [
    {
      '1': 'visible',
      '3': 1,
      '4': 1,
      '5': 8,
      '9': 0,
      '10': 'visible',
      '17': true
    },
    {'1': 'color', '3': 2, '4': 1, '5': 13, '9': 1, '10': 'color', '17': true},
    {'1': 'width', '3': 3, '4': 1, '5': 5, '9': 2, '10': 'width', '17': true},
  ],
  '8': [
    {'1': '_visible'},
    {'1': '_color'},
    {'1': '_width'},
  ],
};

/// Descriptor for `Separator`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List separatorDescriptor = $convert.base64Decode(
    'CglTZXBhcmF0b3ISHQoHdmlzaWJsZRgBIAEoCEgAUgd2aXNpYmxliAEBEhkKBWNvbG9yGAIgAS'
    'gNSAFSBWNvbG9yiAEBEhkKBXdpZHRoGAMgASgFSAJSBXdpZHRoiAEBQgoKCF92aXNpYmxlQggK'
    'Bl9jb2xvckIICgZfd2lkdGg=');

@$core.Deprecated('Use textRenderingDescriptor instead')
const TextRendering$json = {
  '1': 'TextRendering',
  '2': [
    {
      '1': 'mode',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.TextRenderMode',
      '9': 0,
      '10': 'mode',
      '17': true
    },
    {
      '1': 'hinting',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.TextHintingMode',
      '9': 1,
      '10': 'hinting',
      '17': true
    },
    {
      '1': 'pixel_snap',
      '3': 3,
      '4': 1,
      '5': 8,
      '9': 2,
      '10': 'pixelSnap',
      '17': true
    },
  ],
  '8': [
    {'1': '_mode'},
    {'1': '_hinting'},
    {'1': '_pixel_snap'},
  ],
};

/// Descriptor for `TextRendering`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List textRenderingDescriptor = $convert.base64Decode(
    'Cg1UZXh0UmVuZGVyaW5nEjYKBG1vZGUYASABKA4yHS52b2x2b3hncmlkLnYxLlRleHRSZW5kZX'
    'JNb2RlSABSBG1vZGWIAQESPQoHaGludGluZxgCIAEoDjIeLnZvbHZveGdyaWQudjEuVGV4dEhp'
    'bnRpbmdNb2RlSAFSB2hpbnRpbmeIAQESIgoKcGl4ZWxfc25hcBgDIAEoCEgCUglwaXhlbFNuYX'
    'CIAQFCBwoFX21vZGVCCgoIX2hpbnRpbmdCDQoLX3BpeGVsX3NuYXA=');

@$core.Deprecated('Use imageDataDescriptor instead')
const ImageData$json = {
  '1': 'ImageData',
  '2': [
    {'1': 'data', '3': 1, '4': 1, '5': 12, '10': 'data'},
    {'1': 'format', '3': 2, '4': 1, '5': 9, '10': 'format'},
  ],
};

/// Descriptor for `ImageData`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List imageDataDescriptor = $convert.base64Decode(
    'CglJbWFnZURhdGESEgoEZGF0YRgBIAEoDFIEZGF0YRIWCgZmb3JtYXQYAiABKAlSBmZvcm1hdA'
    '==');

@$core.Deprecated('Use barcodeEncodingOptionsDescriptor instead')
const BarcodeEncodingOptions$json = {
  '1': 'BarcodeEncodingOptions',
  '2': [
    {
      '1': 'check_digit',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.BarcodeCheckDigitMode',
      '10': 'checkDigit'
    },
    {
      '1': 'text_encoding',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.BarcodeTextEncoding',
      '10': 'textEncoding'
    },
    {
      '1': 'qr_ecc',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.BarcodeQrErrorCorrection',
      '10': 'qrEcc'
    },
  ],
};

/// Descriptor for `BarcodeEncodingOptions`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List barcodeEncodingOptionsDescriptor = $convert.base64Decode(
    'ChZCYXJjb2RlRW5jb2RpbmdPcHRpb25zEkUKC2NoZWNrX2RpZ2l0GAEgASgOMiQudm9sdm94Z3'
    'JpZC52MS5CYXJjb2RlQ2hlY2tEaWdpdE1vZGVSCmNoZWNrRGlnaXQSRwoNdGV4dF9lbmNvZGlu'
    'ZxgCIAEoDjIiLnZvbHZveGdyaWQudjEuQmFyY29kZVRleHRFbmNvZGluZ1IMdGV4dEVuY29kaW'
    '5nEj4KBnFyX2VjYxgDIAEoDjInLnZvbHZveGdyaWQudjEuQmFyY29kZVFyRXJyb3JDb3JyZWN0'
    'aW9uUgVxckVjYw==');

@$core.Deprecated('Use barcodeRenderOptionsDescriptor instead')
const BarcodeRenderOptions$json = {
  '1': 'BarcodeRenderOptions',
  '2': [
    {
      '1': 'foreground',
      '3': 1,
      '4': 1,
      '5': 13,
      '9': 0,
      '10': 'foreground',
      '17': true
    },
    {
      '1': 'background',
      '3': 2,
      '4': 1,
      '5': 13,
      '9': 1,
      '10': 'background',
      '17': true
    },
    {
      '1': 'alignment',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.ImageAlignment',
      '9': 2,
      '10': 'alignment',
      '17': true
    },
    {'1': 'module_size', '3': 4, '4': 1, '5': 13, '10': 'moduleSize'},
    {'1': 'quiet_zone', '3': 5, '4': 1, '5': 13, '10': 'quietZone'},
    {'1': 'bar_height', '3': 10, '4': 1, '5': 13, '10': 'barHeight'},
    {'1': 'narrow_bar_width', '3': 11, '4': 1, '5': 13, '10': 'narrowBarWidth'},
    {
      '1': 'show_size_warning',
      '3': 12,
      '4': 1,
      '5': 8,
      '9': 3,
      '10': 'showSizeWarning',
      '17': true
    },
    {
      '1': 'size_warning_color',
      '3': 13,
      '4': 1,
      '5': 13,
      '9': 4,
      '10': 'sizeWarningColor',
      '17': true
    },
    {
      '1': 'use_full_rect',
      '3': 14,
      '4': 1,
      '5': 8,
      '9': 5,
      '10': 'useFullRect',
      '17': true
    },
  ],
  '8': [
    {'1': '_foreground'},
    {'1': '_background'},
    {'1': '_alignment'},
    {'1': '_show_size_warning'},
    {'1': '_size_warning_color'},
    {'1': '_use_full_rect'},
  ],
};

/// Descriptor for `BarcodeRenderOptions`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List barcodeRenderOptionsDescriptor = $convert.base64Decode(
    'ChRCYXJjb2RlUmVuZGVyT3B0aW9ucxIjCgpmb3JlZ3JvdW5kGAEgASgNSABSCmZvcmVncm91bm'
    'SIAQESIwoKYmFja2dyb3VuZBgCIAEoDUgBUgpiYWNrZ3JvdW5kiAEBEkAKCWFsaWdubWVudBgD'
    'IAEoDjIdLnZvbHZveGdyaWQudjEuSW1hZ2VBbGlnbm1lbnRIAlIJYWxpZ25tZW50iAEBEh8KC2'
    '1vZHVsZV9zaXplGAQgASgNUgptb2R1bGVTaXplEh0KCnF1aWV0X3pvbmUYBSABKA1SCXF1aWV0'
    'Wm9uZRIdCgpiYXJfaGVpZ2h0GAogASgNUgliYXJIZWlnaHQSKAoQbmFycm93X2Jhcl93aWR0aB'
    'gLIAEoDVIObmFycm93QmFyV2lkdGgSLwoRc2hvd19zaXplX3dhcm5pbmcYDCABKAhIA1IPc2hv'
    'd1NpemVXYXJuaW5niAEBEjEKEnNpemVfd2FybmluZ19jb2xvchgNIAEoDUgEUhBzaXplV2Fybm'
    'luZ0NvbG9yiAEBEicKDXVzZV9mdWxsX3JlY3QYDiABKAhIBVILdXNlRnVsbFJlY3SIAQFCDQoL'
    'X2ZvcmVncm91bmRCDQoLX2JhY2tncm91bmRCDAoKX2FsaWdubWVudEIUChJfc2hvd19zaXplX3'
    'dhcm5pbmdCFQoTX3NpemVfd2FybmluZ19jb2xvckIQCg5fdXNlX2Z1bGxfcmVjdA==');

@$core.Deprecated('Use barcodeCaptionOptionsDescriptor instead')
const BarcodeCaptionOptions$json = {
  '1': 'BarcodeCaptionOptions',
  '2': [
    {
      '1': 'position',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.BarcodeCaptionPosition',
      '9': 0,
      '10': 'position',
      '17': true
    },
    {'1': 'text', '3': 2, '4': 1, '5': 9, '9': 1, '10': 'text', '17': true},
    {'1': 'color', '3': 3, '4': 1, '5': 13, '9': 2, '10': 'color', '17': true},
    {
      '1': 'font_size',
      '3': 4,
      '4': 1,
      '5': 2,
      '9': 3,
      '10': 'fontSize',
      '17': true
    },
  ],
  '8': [
    {'1': '_position'},
    {'1': '_text'},
    {'1': '_color'},
    {'1': '_font_size'},
  ],
};

/// Descriptor for `BarcodeCaptionOptions`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List barcodeCaptionOptionsDescriptor = $convert.base64Decode(
    'ChVCYXJjb2RlQ2FwdGlvbk9wdGlvbnMSRgoIcG9zaXRpb24YASABKA4yJS52b2x2b3hncmlkLn'
    'YxLkJhcmNvZGVDYXB0aW9uUG9zaXRpb25IAFIIcG9zaXRpb26IAQESFwoEdGV4dBgCIAEoCUgB'
    'UgR0ZXh0iAEBEhkKBWNvbG9yGAMgASgNSAJSBWNvbG9yiAEBEiAKCWZvbnRfc2l6ZRgEIAEoAk'
    'gDUghmb250U2l6ZYgBAUILCglfcG9zaXRpb25CBwoFX3RleHRCCAoGX2NvbG9yQgwKCl9mb250'
    'X3NpemU=');

@$core.Deprecated('Use barcodeDataDescriptor instead')
const BarcodeData$json = {
  '1': 'BarcodeData',
  '2': [
    {
      '1': 'symbology',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.BarcodeSymbology',
      '10': 'symbology'
    },
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
    {
      '1': 'encoding',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.BarcodeEncodingOptions',
      '10': 'encoding'
    },
    {
      '1': 'render',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.BarcodeRenderOptions',
      '10': 'render'
    },
    {
      '1': 'caption',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.BarcodeCaptionOptions',
      '10': 'caption'
    },
  ],
};

/// Descriptor for `BarcodeData`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List barcodeDataDescriptor = $convert.base64Decode(
    'CgtCYXJjb2RlRGF0YRI9CglzeW1ib2xvZ3kYASABKA4yHy52b2x2b3hncmlkLnYxLkJhcmNvZG'
    'VTeW1ib2xvZ3lSCXN5bWJvbG9neRIUCgV2YWx1ZRgCIAEoCVIFdmFsdWUSQQoIZW5jb2RpbmcY'
    'AyABKAsyJS52b2x2b3hncmlkLnYxLkJhcmNvZGVFbmNvZGluZ09wdGlvbnNSCGVuY29kaW5nEj'
    'sKBnJlbmRlchgEIAEoCzIjLnZvbHZveGdyaWQudjEuQmFyY29kZVJlbmRlck9wdGlvbnNSBnJl'
    'bmRlchI+CgdjYXB0aW9uGAUgASgLMiQudm9sdm94Z3JpZC52MS5CYXJjb2RlQ2FwdGlvbk9wdG'
    'lvbnNSB2NhcHRpb24=');

@$core.Deprecated('Use cellRangeDescriptor instead')
const CellRange$json = {
  '1': 'CellRange',
  '2': [
    {'1': 'row1', '3': 1, '4': 1, '5': 5, '10': 'row1'},
    {'1': 'col1', '3': 2, '4': 1, '5': 5, '10': 'col1'},
    {'1': 'row2', '3': 3, '4': 1, '5': 5, '10': 'row2'},
    {'1': 'col2', '3': 4, '4': 1, '5': 5, '10': 'col2'},
  ],
};

/// Descriptor for `CellRange`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cellRangeDescriptor = $convert.base64Decode(
    'CglDZWxsUmFuZ2USEgoEcm93MRgBIAEoBVIEcm93MRISCgRjb2wxGAIgASgFUgRjb2wxEhIKBH'
    'JvdzIYAyABKAVSBHJvdzISEgoEY29sMhgEIAEoBVIEY29sMg==');

@$core.Deprecated('Use cellValueDescriptor instead')
const CellValue$json = {
  '1': 'CellValue',
  '2': [
    {'1': 'text', '3': 1, '4': 1, '5': 9, '9': 0, '10': 'text'},
    {'1': 'number', '3': 2, '4': 1, '5': 1, '9': 0, '10': 'number'},
    {'1': 'flag', '3': 3, '4': 1, '5': 8, '9': 0, '10': 'flag'},
    {'1': 'raw', '3': 4, '4': 1, '5': 12, '9': 0, '10': 'raw'},
    {'1': 'timestamp', '3': 5, '4': 1, '5': 3, '9': 0, '10': 'timestamp'},
  ],
  '8': [
    {'1': 'value'},
  ],
};

/// Descriptor for `CellValue`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cellValueDescriptor = $convert.base64Decode(
    'CglDZWxsVmFsdWUSFAoEdGV4dBgBIAEoCUgAUgR0ZXh0EhgKBm51bWJlchgCIAEoAUgAUgZudW'
    '1iZXISFAoEZmxhZxgDIAEoCEgAUgRmbGFnEhIKA3JhdxgEIAEoDEgAUgNyYXcSHgoJdGltZXN0'
    'YW1wGAUgASgDSABSCXRpbWVzdGFtcEIHCgV2YWx1ZQ==');

@$core.Deprecated('Use dropdownDescriptor instead')
const Dropdown$json = {
  '1': 'Dropdown',
  '2': [
    {
      '1': 'items',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.volvoxgrid.v1.DropdownItem',
      '10': 'items'
    },
    {
      '1': 'allow_custom_value',
      '3': 2,
      '4': 1,
      '5': 8,
      '10': 'allowCustomValue'
    },
    {
      '1': 'item_layout',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.DropdownItemLayout',
      '10': 'itemLayout'
    },
    {
      '1': 'searchable',
      '3': 4,
      '4': 1,
      '5': 8,
      '9': 0,
      '10': 'searchable',
      '17': true
    },
  ],
  '8': [
    {'1': '_searchable'},
  ],
};

/// Descriptor for `Dropdown`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dropdownDescriptor = $convert.base64Decode(
    'CghEcm9wZG93bhIxCgVpdGVtcxgBIAMoCzIbLnZvbHZveGdyaWQudjEuRHJvcGRvd25JdGVtUg'
    'VpdGVtcxIsChJhbGxvd19jdXN0b21fdmFsdWUYAiABKAhSEGFsbG93Q3VzdG9tVmFsdWUSQgoL'
    'aXRlbV9sYXlvdXQYAyABKA4yIS52b2x2b3hncmlkLnYxLkRyb3Bkb3duSXRlbUxheW91dFIKaX'
    'RlbUxheW91dBIjCgpzZWFyY2hhYmxlGAQgASgISABSCnNlYXJjaGFibGWIAQFCDQoLX3NlYXJj'
    'aGFibGU=');

@$core.Deprecated('Use dropdownItemDescriptor instead')
const DropdownItem$json = {
  '1': 'DropdownItem',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 9, '9': 0, '10': 'value', '17': true},
    {'1': 'label', '3': 2, '4': 1, '5': 9, '9': 1, '10': 'label', '17': true},
    {'1': 'details', '3': 3, '4': 3, '5': 9, '10': 'details'},
    {'1': 'disabled', '3': 4, '4': 1, '5': 8, '10': 'disabled'},
  ],
  '8': [
    {'1': '_value'},
    {'1': '_label'},
  ],
};

/// Descriptor for `DropdownItem`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dropdownItemDescriptor = $convert.base64Decode(
    'CgxEcm9wZG93bkl0ZW0SGQoFdmFsdWUYASABKAlIAFIFdmFsdWWIAQESGQoFbGFiZWwYAiABKA'
    'lIAVIFbGFiZWyIAQESGAoHZGV0YWlscxgDIAMoCVIHZGV0YWlscxIaCghkaXNhYmxlZBgEIAEo'
    'CFIIZGlzYWJsZWRCCAoGX3ZhbHVlQggKBl9sYWJlbA==');

@$core.Deprecated('Use scrollBarColorsDescriptor instead')
const ScrollBarColors$json = {
  '1': 'ScrollBarColors',
  '2': [
    {'1': 'thumb', '3': 1, '4': 1, '5': 13, '9': 0, '10': 'thumb', '17': true},
    {
      '1': 'thumb_hover',
      '3': 2,
      '4': 1,
      '5': 13,
      '9': 1,
      '10': 'thumbHover',
      '17': true
    },
    {
      '1': 'thumb_active',
      '3': 3,
      '4': 1,
      '5': 13,
      '9': 2,
      '10': 'thumbActive',
      '17': true
    },
    {'1': 'track', '3': 4, '4': 1, '5': 13, '9': 3, '10': 'track', '17': true},
    {'1': 'arrow', '3': 5, '4': 1, '5': 13, '9': 4, '10': 'arrow', '17': true},
    {
      '1': 'border',
      '3': 6,
      '4': 1,
      '5': 13,
      '9': 5,
      '10': 'border',
      '17': true
    },
  ],
  '8': [
    {'1': '_thumb'},
    {'1': '_thumb_hover'},
    {'1': '_thumb_active'},
    {'1': '_track'},
    {'1': '_arrow'},
    {'1': '_border'},
  ],
};

/// Descriptor for `ScrollBarColors`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List scrollBarColorsDescriptor = $convert.base64Decode(
    'Cg9TY3JvbGxCYXJDb2xvcnMSGQoFdGh1bWIYASABKA1IAFIFdGh1bWKIAQESJAoLdGh1bWJfaG'
    '92ZXIYAiABKA1IAVIKdGh1bWJIb3ZlcogBARImCgx0aHVtYl9hY3RpdmUYAyABKA1IAlILdGh1'
    'bWJBY3RpdmWIAQESGQoFdHJhY2sYBCABKA1IA1IFdHJhY2uIAQESGQoFYXJyb3cYBSABKA1IBF'
    'IFYXJyb3eIAQESGwoGYm9yZGVyGAYgASgNSAVSBmJvcmRlcogBAUIICgZfdGh1bWJCDgoMX3Ro'
    'dW1iX2hvdmVyQg8KDV90aHVtYl9hY3RpdmVCCAoGX3RyYWNrQggKBl9hcnJvd0IJCgdfYm9yZG'
    'Vy');

@$core.Deprecated('Use scrollBarConfigDescriptor instead')
const ScrollBarConfig$json = {
  '1': 'ScrollBarConfig',
  '2': [
    {
      '1': 'show_h',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.ScrollBarMode',
      '9': 0,
      '10': 'showH',
      '17': true
    },
    {
      '1': 'show_v',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.ScrollBarMode',
      '9': 1,
      '10': 'showV',
      '17': true
    },
    {
      '1': 'appearance',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.ScrollBarAppearance',
      '9': 2,
      '10': 'appearance',
      '17': true
    },
    {'1': 'size', '3': 4, '4': 1, '5': 5, '9': 3, '10': 'size', '17': true},
    {
      '1': 'min_thumb',
      '3': 5,
      '4': 1,
      '5': 5,
      '9': 4,
      '10': 'minThumb',
      '17': true
    },
    {
      '1': 'corner_radius',
      '3': 6,
      '4': 1,
      '5': 5,
      '9': 5,
      '10': 'cornerRadius',
      '17': true
    },
    {
      '1': 'colors',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.ScrollBarColors',
      '10': 'colors'
    },
    {
      '1': 'fade_delay_ms',
      '3': 8,
      '4': 1,
      '5': 5,
      '9': 6,
      '10': 'fadeDelayMs',
      '17': true
    },
    {
      '1': 'fade_duration_ms',
      '3': 9,
      '4': 1,
      '5': 5,
      '9': 7,
      '10': 'fadeDurationMs',
      '17': true
    },
    {
      '1': 'margin',
      '3': 10,
      '4': 1,
      '5': 5,
      '9': 8,
      '10': 'margin',
      '17': true
    },
  ],
  '8': [
    {'1': '_show_h'},
    {'1': '_show_v'},
    {'1': '_appearance'},
    {'1': '_size'},
    {'1': '_min_thumb'},
    {'1': '_corner_radius'},
    {'1': '_fade_delay_ms'},
    {'1': '_fade_duration_ms'},
    {'1': '_margin'},
  ],
};

/// Descriptor for `ScrollBarConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List scrollBarConfigDescriptor = $convert.base64Decode(
    'Cg9TY3JvbGxCYXJDb25maWcSOAoGc2hvd19oGAEgASgOMhwudm9sdm94Z3JpZC52MS5TY3JvbG'
    'xCYXJNb2RlSABSBXNob3dIiAEBEjgKBnNob3dfdhgCIAEoDjIcLnZvbHZveGdyaWQudjEuU2Ny'
    'b2xsQmFyTW9kZUgBUgVzaG93VogBARJHCgphcHBlYXJhbmNlGAMgASgOMiIudm9sdm94Z3JpZC'
    '52MS5TY3JvbGxCYXJBcHBlYXJhbmNlSAJSCmFwcGVhcmFuY2WIAQESFwoEc2l6ZRgEIAEoBUgD'
    'UgRzaXpliAEBEiAKCW1pbl90aHVtYhgFIAEoBUgEUghtaW5UaHVtYogBARIoCg1jb3JuZXJfcm'
    'FkaXVzGAYgASgFSAVSDGNvcm5lclJhZGl1c4gBARI2CgZjb2xvcnMYByABKAsyHi52b2x2b3hn'
    'cmlkLnYxLlNjcm9sbEJhckNvbG9yc1IGY29sb3JzEicKDWZhZGVfZGVsYXlfbXMYCCABKAVIBl'
    'ILZmFkZURlbGF5TXOIAQESLQoQZmFkZV9kdXJhdGlvbl9tcxgJIAEoBUgHUg5mYWRlRHVyYXRp'
    'b25Nc4gBARIbCgZtYXJnaW4YCiABKAVICFIGbWFyZ2luiAEBQgkKB19zaG93X2hCCQoHX3Nob3'
    'dfdkINCgtfYXBwZWFyYW5jZUIHCgVfc2l6ZUIMCgpfbWluX3RodW1iQhAKDl9jb3JuZXJfcmFk'
    'aXVzQhAKDl9mYWRlX2RlbGF5X21zQhMKEV9mYWRlX2R1cmF0aW9uX21zQgkKB19tYXJnaW4=');

@$core.Deprecated('Use regionStyleDescriptor instead')
const RegionStyle$json = {
  '1': 'RegionStyle',
  '2': [
    {
      '1': 'background',
      '3': 1,
      '4': 1,
      '5': 13,
      '9': 0,
      '10': 'background',
      '17': true
    },
    {
      '1': 'foreground',
      '3': 2,
      '4': 1,
      '5': 13,
      '9': 1,
      '10': 'foreground',
      '17': true
    },
    {
      '1': 'font',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.Font',
      '10': 'font'
    },
    {
      '1': 'grid_lines',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.GridLines',
      '10': 'gridLines'
    },
    {
      '1': 'text_effect',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.TextEffect',
      '9': 2,
      '10': 'textEffect',
      '17': true
    },
    {
      '1': 'separator',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.Separator',
      '10': 'separator'
    },
    {
      '1': 'cell_padding',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.Padding',
      '10': 'cellPadding'
    },
  ],
  '8': [
    {'1': '_background'},
    {'1': '_foreground'},
    {'1': '_text_effect'},
  ],
};

/// Descriptor for `RegionStyle`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List regionStyleDescriptor = $convert.base64Decode(
    'CgtSZWdpb25TdHlsZRIjCgpiYWNrZ3JvdW5kGAEgASgNSABSCmJhY2tncm91bmSIAQESIwoKZm'
    '9yZWdyb3VuZBgCIAEoDUgBUgpmb3JlZ3JvdW5kiAEBEicKBGZvbnQYAyABKAsyEy52b2x2b3hn'
    'cmlkLnYxLkZvbnRSBGZvbnQSNwoKZ3JpZF9saW5lcxgEIAEoCzIYLnZvbHZveGdyaWQudjEuR3'
    'JpZExpbmVzUglncmlkTGluZXMSPwoLdGV4dF9lZmZlY3QYBSABKA4yGS52b2x2b3hncmlkLnYx'
    'LlRleHRFZmZlY3RIAlIKdGV4dEVmZmVjdIgBARI2CglzZXBhcmF0b3IYBiABKAsyGC52b2x2b3'
    'hncmlkLnYxLlNlcGFyYXRvclIJc2VwYXJhdG9yEjkKDGNlbGxfcGFkZGluZxgHIAEoCzIWLnZv'
    'bHZveGdyaWQudjEuUGFkZGluZ1ILY2VsbFBhZGRpbmdCDQoLX2JhY2tncm91bmRCDQoLX2Zvcm'
    'Vncm91bmRCDgoMX3RleHRfZWZmZWN0');

@$core.Deprecated('Use cellStyleDescriptor instead')
const CellStyle$json = {
  '1': 'CellStyle',
  '2': [
    {
      '1': 'background',
      '3': 1,
      '4': 1,
      '5': 13,
      '9': 0,
      '10': 'background',
      '17': true
    },
    {
      '1': 'foreground',
      '3': 2,
      '4': 1,
      '5': 13,
      '9': 1,
      '10': 'foreground',
      '17': true
    },
    {
      '1': 'align',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.Align',
      '9': 2,
      '10': 'align',
      '17': true
    },
    {
      '1': 'font',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.Font',
      '10': 'font'
    },
    {
      '1': 'padding',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.Padding',
      '10': 'padding'
    },
    {
      '1': 'borders',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.Borders',
      '10': 'borders'
    },
    {
      '1': 'text_effect',
      '3': 7,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.TextEffect',
      '9': 3,
      '10': 'textEffect',
      '17': true
    },
    {
      '1': 'progress',
      '3': 8,
      '4': 1,
      '5': 2,
      '9': 4,
      '10': 'progress',
      '17': true
    },
    {
      '1': 'progress_color',
      '3': 9,
      '4': 1,
      '5': 13,
      '9': 5,
      '10': 'progressColor',
      '17': true
    },
    {
      '1': 'shrink_to_fit',
      '3': 10,
      '4': 1,
      '5': 8,
      '9': 6,
      '10': 'shrinkToFit',
      '17': true
    },
  ],
  '8': [
    {'1': '_background'},
    {'1': '_foreground'},
    {'1': '_align'},
    {'1': '_text_effect'},
    {'1': '_progress'},
    {'1': '_progress_color'},
    {'1': '_shrink_to_fit'},
  ],
};

/// Descriptor for `CellStyle`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cellStyleDescriptor = $convert.base64Decode(
    'CglDZWxsU3R5bGUSIwoKYmFja2dyb3VuZBgBIAEoDUgAUgpiYWNrZ3JvdW5kiAEBEiMKCmZvcm'
    'Vncm91bmQYAiABKA1IAVIKZm9yZWdyb3VuZIgBARIvCgVhbGlnbhgDIAEoDjIULnZvbHZveGdy'
    'aWQudjEuQWxpZ25IAlIFYWxpZ26IAQESJwoEZm9udBgEIAEoCzITLnZvbHZveGdyaWQudjEuRm'
    '9udFIEZm9udBIwCgdwYWRkaW5nGAUgASgLMhYudm9sdm94Z3JpZC52MS5QYWRkaW5nUgdwYWRk'
    'aW5nEjAKB2JvcmRlcnMYBiABKAsyFi52b2x2b3hncmlkLnYxLkJvcmRlcnNSB2JvcmRlcnMSPw'
    'oLdGV4dF9lZmZlY3QYByABKA4yGS52b2x2b3hncmlkLnYxLlRleHRFZmZlY3RIA1IKdGV4dEVm'
    'ZmVjdIgBARIfCghwcm9ncmVzcxgIIAEoAkgEUghwcm9ncmVzc4gBARIqCg5wcm9ncmVzc19jb2'
    'xvchgJIAEoDUgFUg1wcm9ncmVzc0NvbG9yiAEBEicKDXNocmlua190b19maXQYCiABKAhIBlIL'
    'c2hyaW5rVG9GaXSIAQFCDQoLX2JhY2tncm91bmRCDQoLX2ZvcmVncm91bmRCCAoGX2FsaWduQg'
    '4KDF90ZXh0X2VmZmVjdEILCglfcHJvZ3Jlc3NCEQoPX3Byb2dyZXNzX2NvbG9yQhAKDl9zaHJp'
    'bmtfdG9fZml0');

@$core.Deprecated('Use highlightStyleDescriptor instead')
const HighlightStyle$json = {
  '1': 'HighlightStyle',
  '2': [
    {
      '1': 'background',
      '3': 1,
      '4': 1,
      '5': 13,
      '9': 0,
      '10': 'background',
      '17': true
    },
    {
      '1': 'foreground',
      '3': 2,
      '4': 1,
      '5': 13,
      '9': 1,
      '10': 'foreground',
      '17': true
    },
    {
      '1': 'borders',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.Borders',
      '10': 'borders'
    },
    {
      '1': 'fill_handle',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.FillHandlePosition',
      '9': 2,
      '10': 'fillHandle',
      '17': true
    },
    {
      '1': 'fill_handle_color',
      '3': 5,
      '4': 1,
      '5': 13,
      '9': 3,
      '10': 'fillHandleColor',
      '17': true
    },
  ],
  '8': [
    {'1': '_background'},
    {'1': '_foreground'},
    {'1': '_fill_handle'},
    {'1': '_fill_handle_color'},
  ],
};

/// Descriptor for `HighlightStyle`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List highlightStyleDescriptor = $convert.base64Decode(
    'Cg5IaWdobGlnaHRTdHlsZRIjCgpiYWNrZ3JvdW5kGAEgASgNSABSCmJhY2tncm91bmSIAQESIw'
    'oKZm9yZWdyb3VuZBgCIAEoDUgBUgpmb3JlZ3JvdW5kiAEBEjAKB2JvcmRlcnMYAyABKAsyFi52'
    'b2x2b3hncmlkLnYxLkJvcmRlcnNSB2JvcmRlcnMSRwoLZmlsbF9oYW5kbGUYBCABKA4yIS52b2'
    'x2b3hncmlkLnYxLkZpbGxIYW5kbGVQb3NpdGlvbkgCUgpmaWxsSGFuZGxliAEBEi8KEWZpbGxf'
    'aGFuZGxlX2NvbG9yGAUgASgNSANSD2ZpbGxIYW5kbGVDb2xvcogBAUINCgtfYmFja2dyb3VuZE'
    'INCgtfZm9yZWdyb3VuZEIOCgxfZmlsbF9oYW5kbGVCFAoSX2ZpbGxfaGFuZGxlX2NvbG9y');

@$core.Deprecated('Use headerMarkSizeDescriptor instead')
const HeaderMarkSize$json = {
  '1': 'HeaderMarkSize',
  '2': [
    {'1': 'ratio', '3': 1, '4': 1, '5': 2, '9': 0, '10': 'ratio'},
    {'1': 'px', '3': 2, '4': 1, '5': 5, '9': 0, '10': 'px'},
  ],
  '8': [
    {'1': 'value'},
  ],
};

/// Descriptor for `HeaderMarkSize`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List headerMarkSizeDescriptor = $convert.base64Decode(
    'Cg5IZWFkZXJNYXJrU2l6ZRIWCgVyYXRpbxgBIAEoAkgAUgVyYXRpbxIQCgJweBgCIAEoBUgAUg'
    'JweEIHCgV2YWx1ZQ==');

@$core.Deprecated('Use headerSeparatorDescriptor instead')
const HeaderSeparator$json = {
  '1': 'HeaderSeparator',
  '2': [
    {
      '1': 'enabled',
      '3': 1,
      '4': 1,
      '5': 8,
      '9': 0,
      '10': 'enabled',
      '17': true
    },
    {'1': 'color', '3': 2, '4': 1, '5': 13, '9': 1, '10': 'color', '17': true},
    {'1': 'width', '3': 3, '4': 1, '5': 5, '9': 2, '10': 'width', '17': true},
    {
      '1': 'height',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.HeaderMarkSize',
      '10': 'height'
    },
    {
      '1': 'skip_merged',
      '3': 5,
      '4': 1,
      '5': 8,
      '9': 3,
      '10': 'skipMerged',
      '17': true
    },
  ],
  '8': [
    {'1': '_enabled'},
    {'1': '_color'},
    {'1': '_width'},
    {'1': '_skip_merged'},
  ],
};

/// Descriptor for `HeaderSeparator`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List headerSeparatorDescriptor = $convert.base64Decode(
    'Cg9IZWFkZXJTZXBhcmF0b3ISHQoHZW5hYmxlZBgBIAEoCEgAUgdlbmFibGVkiAEBEhkKBWNvbG'
    '9yGAIgASgNSAFSBWNvbG9yiAEBEhkKBXdpZHRoGAMgASgFSAJSBXdpZHRoiAEBEjUKBmhlaWdo'
    'dBgEIAEoCzIdLnZvbHZveGdyaWQudjEuSGVhZGVyTWFya1NpemVSBmhlaWdodBIkCgtza2lwX2'
    '1lcmdlZBgFIAEoCEgDUgpza2lwTWVyZ2VkiAEBQgoKCF9lbmFibGVkQggKBl9jb2xvckIICgZf'
    'd2lkdGhCDgoMX3NraXBfbWVyZ2Vk');

@$core.Deprecated('Use headerResizeHandleDescriptor instead')
const HeaderResizeHandle$json = {
  '1': 'HeaderResizeHandle',
  '2': [
    {
      '1': 'enabled',
      '3': 1,
      '4': 1,
      '5': 8,
      '9': 0,
      '10': 'enabled',
      '17': true
    },
    {'1': 'color', '3': 2, '4': 1, '5': 13, '9': 1, '10': 'color', '17': true},
    {'1': 'width', '3': 3, '4': 1, '5': 5, '9': 2, '10': 'width', '17': true},
    {
      '1': 'height',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.HeaderMarkSize',
      '10': 'height'
    },
    {
      '1': 'hit_width',
      '3': 5,
      '4': 1,
      '5': 5,
      '9': 3,
      '10': 'hitWidth',
      '17': true
    },
    {
      '1': 'show_only_when_resizable',
      '3': 6,
      '4': 1,
      '5': 8,
      '9': 4,
      '10': 'showOnlyWhenResizable',
      '17': true
    },
  ],
  '8': [
    {'1': '_enabled'},
    {'1': '_color'},
    {'1': '_width'},
    {'1': '_hit_width'},
    {'1': '_show_only_when_resizable'},
  ],
};

/// Descriptor for `HeaderResizeHandle`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List headerResizeHandleDescriptor = $convert.base64Decode(
    'ChJIZWFkZXJSZXNpemVIYW5kbGUSHQoHZW5hYmxlZBgBIAEoCEgAUgdlbmFibGVkiAEBEhkKBW'
    'NvbG9yGAIgASgNSAFSBWNvbG9yiAEBEhkKBXdpZHRoGAMgASgFSAJSBXdpZHRoiAEBEjUKBmhl'
    'aWdodBgEIAEoCzIdLnZvbHZveGdyaWQudjEuSGVhZGVyTWFya1NpemVSBmhlaWdodBIgCgloaX'
    'Rfd2lkdGgYBSABKAVIA1IIaGl0V2lkdGiIAQESPAoYc2hvd19vbmx5X3doZW5fcmVzaXphYmxl'
    'GAYgASgISARSFXNob3dPbmx5V2hlblJlc2l6YWJsZYgBAUIKCghfZW5hYmxlZEIICgZfY29sb3'
    'JCCAoGX3dpZHRoQgwKCl9oaXRfd2lkdGhCGwoZX3Nob3dfb25seV93aGVuX3Jlc2l6YWJsZQ==');

@$core.Deprecated('Use headerStyleDescriptor instead')
const HeaderStyle$json = {
  '1': 'HeaderStyle',
  '2': [
    {
      '1': 'separator',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.HeaderSeparator',
      '10': 'separator'
    },
    {
      '1': 'resize_handle',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.HeaderResizeHandle',
      '10': 'resizeHandle'
    },
  ],
};

/// Descriptor for `HeaderStyle`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List headerStyleDescriptor = $convert.base64Decode(
    'CgtIZWFkZXJTdHlsZRI8CglzZXBhcmF0b3IYASABKAsyHi52b2x2b3hncmlkLnYxLkhlYWRlcl'
    'NlcGFyYXRvclIJc2VwYXJhdG9yEkYKDXJlc2l6ZV9oYW5kbGUYAiABKAsyIS52b2x2b3hncmlk'
    'LnYxLkhlYWRlclJlc2l6ZUhhbmRsZVIMcmVzaXplSGFuZGxl');

@$core.Deprecated('Use iconSlotsDescriptor instead')
const IconSlots$json = {
  '1': 'IconSlots',
  '2': [
    {
      '1': 'sort_ascending',
      '3': 1,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'sortAscending',
      '17': true
    },
    {
      '1': 'sort_descending',
      '3': 2,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'sortDescending',
      '17': true
    },
    {
      '1': 'sort_none',
      '3': 3,
      '4': 1,
      '5': 9,
      '9': 2,
      '10': 'sortNone',
      '17': true
    },
    {
      '1': 'tree_expanded',
      '3': 4,
      '4': 1,
      '5': 9,
      '9': 3,
      '10': 'treeExpanded',
      '17': true
    },
    {
      '1': 'tree_collapsed',
      '3': 5,
      '4': 1,
      '5': 9,
      '9': 4,
      '10': 'treeCollapsed',
      '17': true
    },
    {'1': 'menu', '3': 6, '4': 1, '5': 9, '9': 5, '10': 'menu', '17': true},
    {'1': 'filter', '3': 7, '4': 1, '5': 9, '9': 6, '10': 'filter', '17': true},
    {
      '1': 'filter_active',
      '3': 8,
      '4': 1,
      '5': 9,
      '9': 7,
      '10': 'filterActive',
      '17': true
    },
    {
      '1': 'columns',
      '3': 9,
      '4': 1,
      '5': 9,
      '9': 8,
      '10': 'columns',
      '17': true
    },
    {
      '1': 'drag_handle',
      '3': 10,
      '4': 1,
      '5': 9,
      '9': 9,
      '10': 'dragHandle',
      '17': true
    },
    {
      '1': 'checkbox_checked',
      '3': 11,
      '4': 1,
      '5': 9,
      '9': 10,
      '10': 'checkboxChecked',
      '17': true
    },
    {
      '1': 'checkbox_unchecked',
      '3': 12,
      '4': 1,
      '5': 9,
      '9': 11,
      '10': 'checkboxUnchecked',
      '17': true
    },
    {
      '1': 'checkbox_indeterminate',
      '3': 13,
      '4': 1,
      '5': 9,
      '9': 12,
      '10': 'checkboxIndeterminate',
      '17': true
    },
  ],
  '8': [
    {'1': '_sort_ascending'},
    {'1': '_sort_descending'},
    {'1': '_sort_none'},
    {'1': '_tree_expanded'},
    {'1': '_tree_collapsed'},
    {'1': '_menu'},
    {'1': '_filter'},
    {'1': '_filter_active'},
    {'1': '_columns'},
    {'1': '_drag_handle'},
    {'1': '_checkbox_checked'},
    {'1': '_checkbox_unchecked'},
    {'1': '_checkbox_indeterminate'},
  ],
};

/// Descriptor for `IconSlots`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List iconSlotsDescriptor = $convert.base64Decode(
    'CglJY29uU2xvdHMSKgoOc29ydF9hc2NlbmRpbmcYASABKAlIAFINc29ydEFzY2VuZGluZ4gBAR'
    'IsCg9zb3J0X2Rlc2NlbmRpbmcYAiABKAlIAVIOc29ydERlc2NlbmRpbmeIAQESIAoJc29ydF9u'
    'b25lGAMgASgJSAJSCHNvcnROb25liAEBEigKDXRyZWVfZXhwYW5kZWQYBCABKAlIA1IMdHJlZU'
    'V4cGFuZGVkiAEBEioKDnRyZWVfY29sbGFwc2VkGAUgASgJSARSDXRyZWVDb2xsYXBzZWSIAQES'
    'FwoEbWVudRgGIAEoCUgFUgRtZW51iAEBEhsKBmZpbHRlchgHIAEoCUgGUgZmaWx0ZXKIAQESKA'
    'oNZmlsdGVyX2FjdGl2ZRgIIAEoCUgHUgxmaWx0ZXJBY3RpdmWIAQESHQoHY29sdW1ucxgJIAEo'
    'CUgIUgdjb2x1bW5ziAEBEiQKC2RyYWdfaGFuZGxlGAogASgJSAlSCmRyYWdIYW5kbGWIAQESLg'
    'oQY2hlY2tib3hfY2hlY2tlZBgLIAEoCUgKUg9jaGVja2JveENoZWNrZWSIAQESMgoSY2hlY2ti'
    'b3hfdW5jaGVja2VkGAwgASgJSAtSEWNoZWNrYm94VW5jaGVja2VkiAEBEjoKFmNoZWNrYm94X2'
    'luZGV0ZXJtaW5hdGUYDSABKAlIDFIVY2hlY2tib3hJbmRldGVybWluYXRliAEBQhEKD19zb3J0'
    'X2FzY2VuZGluZ0ISChBfc29ydF9kZXNjZW5kaW5nQgwKCl9zb3J0X25vbmVCEAoOX3RyZWVfZX'
    'hwYW5kZWRCEQoPX3RyZWVfY29sbGFwc2VkQgcKBV9tZW51QgkKB19maWx0ZXJCEAoOX2ZpbHRl'
    'cl9hY3RpdmVCCgoIX2NvbHVtbnNCDgoMX2RyYWdfaGFuZGxlQhMKEV9jaGVja2JveF9jaGVja2'
    'VkQhUKE19jaGVja2JveF91bmNoZWNrZWRCGQoXX2NoZWNrYm94X2luZGV0ZXJtaW5hdGU=');

@$core.Deprecated('Use iconStyleDescriptor instead')
const IconStyle$json = {
  '1': 'IconStyle',
  '2': [
    {
      '1': 'font',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.Font',
      '10': 'font'
    },
    {'1': 'color', '3': 2, '4': 1, '5': 13, '9': 0, '10': 'color', '17': true},
    {
      '1': 'align',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.IconAlign',
      '9': 1,
      '10': 'align',
      '17': true
    },
    {'1': 'gap', '3': 4, '4': 1, '5': 5, '9': 2, '10': 'gap', '17': true},
  ],
  '8': [
    {'1': '_color'},
    {'1': '_align'},
    {'1': '_gap'},
  ],
};

/// Descriptor for `IconStyle`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List iconStyleDescriptor = $convert.base64Decode(
    'CglJY29uU3R5bGUSJwoEZm9udBgBIAEoCzITLnZvbHZveGdyaWQudjEuRm9udFIEZm9udBIZCg'
    'Vjb2xvchgCIAEoDUgAUgVjb2xvcogBARIzCgVhbGlnbhgDIAEoDjIYLnZvbHZveGdyaWQudjEu'
    'SWNvbkFsaWduSAFSBWFsaWduiAEBEhUKA2dhcBgEIAEoBUgCUgNnYXCIAQFCCAoGX2NvbG9yQg'
    'gKBl9hbGlnbkIGCgRfZ2Fw');

@$core.Deprecated('Use iconSlotStylesDescriptor instead')
const IconSlotStyles$json = {
  '1': 'IconSlotStyles',
  '2': [
    {
      '1': 'sort_ascending',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.IconStyle',
      '10': 'sortAscending'
    },
    {
      '1': 'sort_descending',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.IconStyle',
      '10': 'sortDescending'
    },
    {
      '1': 'sort_none',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.IconStyle',
      '10': 'sortNone'
    },
    {
      '1': 'tree_expanded',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.IconStyle',
      '10': 'treeExpanded'
    },
    {
      '1': 'tree_collapsed',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.IconStyle',
      '10': 'treeCollapsed'
    },
    {
      '1': 'menu',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.IconStyle',
      '10': 'menu'
    },
    {
      '1': 'filter',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.IconStyle',
      '10': 'filter'
    },
    {
      '1': 'filter_active',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.IconStyle',
      '10': 'filterActive'
    },
    {
      '1': 'columns',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.IconStyle',
      '10': 'columns'
    },
    {
      '1': 'drag_handle',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.IconStyle',
      '10': 'dragHandle'
    },
    {
      '1': 'checkbox_checked',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.IconStyle',
      '10': 'checkboxChecked'
    },
    {
      '1': 'checkbox_unchecked',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.IconStyle',
      '10': 'checkboxUnchecked'
    },
    {
      '1': 'checkbox_indeterminate',
      '3': 13,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.IconStyle',
      '10': 'checkboxIndeterminate'
    },
  ],
};

/// Descriptor for `IconSlotStyles`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List iconSlotStylesDescriptor = $convert.base64Decode(
    'Cg5JY29uU2xvdFN0eWxlcxI/Cg5zb3J0X2FzY2VuZGluZxgBIAEoCzIYLnZvbHZveGdyaWQudj'
    'EuSWNvblN0eWxlUg1zb3J0QXNjZW5kaW5nEkEKD3NvcnRfZGVzY2VuZGluZxgCIAEoCzIYLnZv'
    'bHZveGdyaWQudjEuSWNvblN0eWxlUg5zb3J0RGVzY2VuZGluZxI1Cglzb3J0X25vbmUYAyABKA'
    'syGC52b2x2b3hncmlkLnYxLkljb25TdHlsZVIIc29ydE5vbmUSPQoNdHJlZV9leHBhbmRlZBgE'
    'IAEoCzIYLnZvbHZveGdyaWQudjEuSWNvblN0eWxlUgx0cmVlRXhwYW5kZWQSPwoOdHJlZV9jb2'
    'xsYXBzZWQYBSABKAsyGC52b2x2b3hncmlkLnYxLkljb25TdHlsZVINdHJlZUNvbGxhcHNlZBIs'
    'CgRtZW51GAYgASgLMhgudm9sdm94Z3JpZC52MS5JY29uU3R5bGVSBG1lbnUSMAoGZmlsdGVyGA'
    'cgASgLMhgudm9sdm94Z3JpZC52MS5JY29uU3R5bGVSBmZpbHRlchI9Cg1maWx0ZXJfYWN0aXZl'
    'GAggASgLMhgudm9sdm94Z3JpZC52MS5JY29uU3R5bGVSDGZpbHRlckFjdGl2ZRIyCgdjb2x1bW'
    '5zGAkgASgLMhgudm9sdm94Z3JpZC52MS5JY29uU3R5bGVSB2NvbHVtbnMSOQoLZHJhZ19oYW5k'
    'bGUYCiABKAsyGC52b2x2b3hncmlkLnYxLkljb25TdHlsZVIKZHJhZ0hhbmRsZRJDChBjaGVja2'
    'JveF9jaGVja2VkGAsgASgLMhgudm9sdm94Z3JpZC52MS5JY29uU3R5bGVSD2NoZWNrYm94Q2hl'
    'Y2tlZBJHChJjaGVja2JveF91bmNoZWNrZWQYDCABKAsyGC52b2x2b3hncmlkLnYxLkljb25TdH'
    'lsZVIRY2hlY2tib3hVbmNoZWNrZWQSTwoWY2hlY2tib3hfaW5kZXRlcm1pbmF0ZRgNIAEoCzIY'
    'LnZvbHZveGdyaWQudjEuSWNvblN0eWxlUhVjaGVja2JveEluZGV0ZXJtaW5hdGU=');

@$core.Deprecated('Use iconPicturesDescriptor instead')
const IconPictures$json = {
  '1': 'IconPictures',
  '2': [
    {
      '1': 'sort_ascending',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.ImageData',
      '10': 'sortAscending'
    },
    {
      '1': 'sort_descending',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.ImageData',
      '10': 'sortDescending'
    },
    {
      '1': 'node_open',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.ImageData',
      '10': 'nodeOpen'
    },
    {
      '1': 'node_closed',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.ImageData',
      '10': 'nodeClosed'
    },
    {
      '1': 'checkbox_checked',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.ImageData',
      '10': 'checkboxChecked'
    },
    {
      '1': 'checkbox_unchecked',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.ImageData',
      '10': 'checkboxUnchecked'
    },
    {
      '1': 'checkbox_indeterminate',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.ImageData',
      '10': 'checkboxIndeterminate'
    },
  ],
};

/// Descriptor for `IconPictures`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List iconPicturesDescriptor = $convert.base64Decode(
    'CgxJY29uUGljdHVyZXMSPwoOc29ydF9hc2NlbmRpbmcYASABKAsyGC52b2x2b3hncmlkLnYxLk'
    'ltYWdlRGF0YVINc29ydEFzY2VuZGluZxJBCg9zb3J0X2Rlc2NlbmRpbmcYAiABKAsyGC52b2x2'
    'b3hncmlkLnYxLkltYWdlRGF0YVIOc29ydERlc2NlbmRpbmcSNQoJbm9kZV9vcGVuGAMgASgLMh'
    'gudm9sdm94Z3JpZC52MS5JbWFnZURhdGFSCG5vZGVPcGVuEjkKC25vZGVfY2xvc2VkGAQgASgL'
    'Mhgudm9sdm94Z3JpZC52MS5JbWFnZURhdGFSCm5vZGVDbG9zZWQSQwoQY2hlY2tib3hfY2hlY2'
    'tlZBgFIAEoCzIYLnZvbHZveGdyaWQudjEuSW1hZ2VEYXRhUg9jaGVja2JveENoZWNrZWQSRwoS'
    'Y2hlY2tib3hfdW5jaGVja2VkGAYgASgLMhgudm9sdm94Z3JpZC52MS5JbWFnZURhdGFSEWNoZW'
    'NrYm94VW5jaGVja2VkEk8KFmNoZWNrYm94X2luZGV0ZXJtaW5hdGUYByABKAsyGC52b2x2b3hn'
    'cmlkLnYxLkltYWdlRGF0YVIVY2hlY2tib3hJbmRldGVybWluYXRl');

@$core.Deprecated('Use iconThemeDescriptor instead')
const IconTheme$json = {
  '1': 'IconTheme',
  '2': [
    {
      '1': 'slots',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.IconSlots',
      '10': 'slots'
    },
    {
      '1': 'defaults',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.IconStyle',
      '10': 'defaults'
    },
    {
      '1': 'overrides',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.IconSlotStyles',
      '10': 'overrides'
    },
    {
      '1': 'pictures',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.IconPictures',
      '10': 'pictures'
    },
  ],
};

/// Descriptor for `IconTheme`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List iconThemeDescriptor = $convert.base64Decode(
    'CglJY29uVGhlbWUSLgoFc2xvdHMYASABKAsyGC52b2x2b3hncmlkLnYxLkljb25TbG90c1IFc2'
    'xvdHMSNAoIZGVmYXVsdHMYAiABKAsyGC52b2x2b3hncmlkLnYxLkljb25TdHlsZVIIZGVmYXVs'
    'dHMSOwoJb3ZlcnJpZGVzGAMgASgLMh0udm9sdm94Z3JpZC52MS5JY29uU2xvdFN0eWxlc1IJb3'
    'ZlcnJpZGVzEjcKCHBpY3R1cmVzGAQgASgLMhsudm9sdm94Z3JpZC52MS5JY29uUGljdHVyZXNS'
    'CHBpY3R1cmVz');

@$core.Deprecated('Use hoverConfigDescriptor instead')
const HoverConfig$json = {
  '1': 'HoverConfig',
  '2': [
    {'1': 'row', '3': 1, '4': 1, '5': 8, '9': 0, '10': 'row', '17': true},
    {'1': 'column', '3': 2, '4': 1, '5': 8, '9': 1, '10': 'column', '17': true},
    {'1': 'cell', '3': 3, '4': 1, '5': 8, '9': 2, '10': 'cell', '17': true},
    {
      '1': 'row_style',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.HighlightStyle',
      '10': 'rowStyle'
    },
    {
      '1': 'column_style',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.HighlightStyle',
      '10': 'columnStyle'
    },
    {
      '1': 'cell_style',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.HighlightStyle',
      '10': 'cellStyle'
    },
  ],
  '8': [
    {'1': '_row'},
    {'1': '_column'},
    {'1': '_cell'},
  ],
};

/// Descriptor for `HoverConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List hoverConfigDescriptor = $convert.base64Decode(
    'CgtIb3ZlckNvbmZpZxIVCgNyb3cYASABKAhIAFIDcm93iAEBEhsKBmNvbHVtbhgCIAEoCEgBUg'
    'Zjb2x1bW6IAQESFwoEY2VsbBgDIAEoCEgCUgRjZWxsiAEBEjoKCXJvd19zdHlsZRgEIAEoCzId'
    'LnZvbHZveGdyaWQudjEuSGlnaGxpZ2h0U3R5bGVSCHJvd1N0eWxlEkAKDGNvbHVtbl9zdHlsZR'
    'gFIAEoCzIdLnZvbHZveGdyaWQudjEuSGlnaGxpZ2h0U3R5bGVSC2NvbHVtblN0eWxlEjwKCmNl'
    'bGxfc3R5bGUYBiABKAsyHS52b2x2b3hncmlkLnYxLkhpZ2hsaWdodFN0eWxlUgljZWxsU3R5bG'
    'VCBgoEX3Jvd0IJCgdfY29sdW1uQgcKBV9jZWxs');

@$core.Deprecated('Use resizePolicyDescriptor instead')
const ResizePolicy$json = {
  '1': 'ResizePolicy',
  '2': [
    {
      '1': 'columns',
      '3': 1,
      '4': 1,
      '5': 8,
      '9': 0,
      '10': 'columns',
      '17': true
    },
    {'1': 'rows', '3': 2, '4': 1, '5': 8, '9': 1, '10': 'rows', '17': true},
    {
      '1': 'uniform',
      '3': 3,
      '4': 1,
      '5': 8,
      '9': 2,
      '10': 'uniform',
      '17': true
    },
  ],
  '8': [
    {'1': '_columns'},
    {'1': '_rows'},
    {'1': '_uniform'},
  ],
};

/// Descriptor for `ResizePolicy`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List resizePolicyDescriptor = $convert.base64Decode(
    'CgxSZXNpemVQb2xpY3kSHQoHY29sdW1ucxgBIAEoCEgAUgdjb2x1bW5ziAEBEhcKBHJvd3MYAi'
    'ABKAhIAVIEcm93c4gBARIdCgd1bmlmb3JtGAMgASgISAJSB3VuaWZvcm2IAQFCCgoIX2NvbHVt'
    'bnNCBwoFX3Jvd3NCCgoIX3VuaWZvcm0=');

@$core.Deprecated('Use freezePolicyDescriptor instead')
const FreezePolicy$json = {
  '1': 'FreezePolicy',
  '2': [
    {
      '1': 'columns',
      '3': 1,
      '4': 1,
      '5': 8,
      '9': 0,
      '10': 'columns',
      '17': true
    },
    {'1': 'rows', '3': 2, '4': 1, '5': 8, '9': 1, '10': 'rows', '17': true},
  ],
  '8': [
    {'1': '_columns'},
    {'1': '_rows'},
  ],
};

/// Descriptor for `FreezePolicy`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List freezePolicyDescriptor = $convert.base64Decode(
    'CgxGcmVlemVQb2xpY3kSHQoHY29sdW1ucxgBIAEoCEgAUgdjb2x1bW5ziAEBEhcKBHJvd3MYAi'
    'ABKAhIAVIEcm93c4gBAUIKCghfY29sdW1uc0IHCgVfcm93cw==');

@$core.Deprecated('Use headerFeaturesDescriptor instead')
const HeaderFeatures$json = {
  '1': 'HeaderFeatures',
  '2': [
    {'1': 'sort', '3': 1, '4': 1, '5': 8, '9': 0, '10': 'sort', '17': true},
    {
      '1': 'reorder',
      '3': 2,
      '4': 1,
      '5': 8,
      '9': 1,
      '10': 'reorder',
      '17': true
    },
    {
      '1': 'chooser',
      '3': 3,
      '4': 1,
      '5': 8,
      '9': 2,
      '10': 'chooser',
      '17': true
    },
  ],
  '8': [
    {'1': '_sort'},
    {'1': '_reorder'},
    {'1': '_chooser'},
  ],
};

/// Descriptor for `HeaderFeatures`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List headerFeaturesDescriptor = $convert.base64Decode(
    'Cg5IZWFkZXJGZWF0dXJlcxIXCgRzb3J0GAEgASgISABSBHNvcnSIAQESHQoHcmVvcmRlchgCIA'
    'EoCEgBUgdyZW9yZGVyiAEBEh0KB2Nob29zZXIYAyABKAhIAlIHY2hvb3NlcogBAUIHCgVfc29y'
    'dEIKCghfcmVvcmRlckIKCghfY2hvb3Nlcg==');

@$core.Deprecated('Use gridConfigDescriptor instead')
const GridConfig$json = {
  '1': 'GridConfig',
  '2': [
    {
      '1': 'layout',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.LayoutConfig',
      '10': 'layout'
    },
    {
      '1': 'style',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.StyleConfig',
      '10': 'style'
    },
    {
      '1': 'selection',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.SelectionConfig',
      '10': 'selection'
    },
    {
      '1': 'editing',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.EditConfig',
      '10': 'editing'
    },
    {
      '1': 'scrolling',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.ScrollConfig',
      '10': 'scrolling'
    },
    {
      '1': 'outline',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.OutlineConfig',
      '10': 'outline'
    },
    {
      '1': 'span',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.SpanConfig',
      '10': 'span'
    },
    {
      '1': 'interaction',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.InteractionConfig',
      '10': 'interaction'
    },
    {
      '1': 'rendering',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.RenderConfig',
      '10': 'rendering'
    },
    {'1': 'version', '3': 10, '4': 1, '5': 9, '10': 'version'},
    {
      '1': 'indicators',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.IndicatorsConfig',
      '10': 'indicators'
    },
  ],
};

/// Descriptor for `GridConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List gridConfigDescriptor = $convert.base64Decode(
    'CgpHcmlkQ29uZmlnEjMKBmxheW91dBgBIAEoCzIbLnZvbHZveGdyaWQudjEuTGF5b3V0Q29uZm'
    'lnUgZsYXlvdXQSMAoFc3R5bGUYAiABKAsyGi52b2x2b3hncmlkLnYxLlN0eWxlQ29uZmlnUgVz'
    'dHlsZRI8CglzZWxlY3Rpb24YAyABKAsyHi52b2x2b3hncmlkLnYxLlNlbGVjdGlvbkNvbmZpZ1'
    'IJc2VsZWN0aW9uEjMKB2VkaXRpbmcYBCABKAsyGS52b2x2b3hncmlkLnYxLkVkaXRDb25maWdS'
    'B2VkaXRpbmcSOQoJc2Nyb2xsaW5nGAUgASgLMhsudm9sdm94Z3JpZC52MS5TY3JvbGxDb25maW'
    'dSCXNjcm9sbGluZxI2CgdvdXRsaW5lGAYgASgLMhwudm9sdm94Z3JpZC52MS5PdXRsaW5lQ29u'
    'ZmlnUgdvdXRsaW5lEi0KBHNwYW4YByABKAsyGS52b2x2b3hncmlkLnYxLlNwYW5Db25maWdSBH'
    'NwYW4SQgoLaW50ZXJhY3Rpb24YCCABKAsyIC52b2x2b3hncmlkLnYxLkludGVyYWN0aW9uQ29u'
    'ZmlnUgtpbnRlcmFjdGlvbhI5CglyZW5kZXJpbmcYCSABKAsyGy52b2x2b3hncmlkLnYxLlJlbm'
    'RlckNvbmZpZ1IJcmVuZGVyaW5nEhgKB3ZlcnNpb24YCiABKAlSB3ZlcnNpb24SPwoKaW5kaWNh'
    'dG9ycxgLIAEoCzIfLnZvbHZveGdyaWQudjEuSW5kaWNhdG9yc0NvbmZpZ1IKaW5kaWNhdG9ycw'
    '==');

@$core.Deprecated('Use layoutConfigDescriptor instead')
const LayoutConfig$json = {
  '1': 'LayoutConfig',
  '2': [
    {'1': 'rows', '3': 1, '4': 1, '5': 5, '9': 0, '10': 'rows', '17': true},
    {'1': 'cols', '3': 2, '4': 1, '5': 5, '9': 1, '10': 'cols', '17': true},
    {
      '1': 'fixed_rows',
      '3': 3,
      '4': 1,
      '5': 5,
      '9': 2,
      '10': 'fixedRows',
      '17': true
    },
    {
      '1': 'fixed_cols',
      '3': 4,
      '4': 1,
      '5': 5,
      '9': 3,
      '10': 'fixedCols',
      '17': true
    },
    {
      '1': 'frozen_rows',
      '3': 5,
      '4': 1,
      '5': 5,
      '9': 4,
      '10': 'frozenRows',
      '17': true
    },
    {
      '1': 'frozen_cols',
      '3': 6,
      '4': 1,
      '5': 5,
      '9': 5,
      '10': 'frozenCols',
      '17': true
    },
    {
      '1': 'default_row_height',
      '3': 7,
      '4': 1,
      '5': 5,
      '9': 6,
      '10': 'defaultRowHeight',
      '17': true
    },
    {
      '1': 'default_col_width',
      '3': 8,
      '4': 1,
      '5': 5,
      '9': 7,
      '10': 'defaultColWidth',
      '17': true
    },
    {
      '1': 'right_to_left',
      '3': 9,
      '4': 1,
      '5': 8,
      '9': 8,
      '10': 'rightToLeft',
      '17': true
    },
    {
      '1': 'extend_last_col',
      '3': 10,
      '4': 1,
      '5': 8,
      '9': 9,
      '10': 'extendLastCol',
      '17': true
    },
  ],
  '8': [
    {'1': '_rows'},
    {'1': '_cols'},
    {'1': '_fixed_rows'},
    {'1': '_fixed_cols'},
    {'1': '_frozen_rows'},
    {'1': '_frozen_cols'},
    {'1': '_default_row_height'},
    {'1': '_default_col_width'},
    {'1': '_right_to_left'},
    {'1': '_extend_last_col'},
  ],
};

/// Descriptor for `LayoutConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List layoutConfigDescriptor = $convert.base64Decode(
    'CgxMYXlvdXRDb25maWcSFwoEcm93cxgBIAEoBUgAUgRyb3dziAEBEhcKBGNvbHMYAiABKAVIAV'
    'IEY29sc4gBARIiCgpmaXhlZF9yb3dzGAMgASgFSAJSCWZpeGVkUm93c4gBARIiCgpmaXhlZF9j'
    'b2xzGAQgASgFSANSCWZpeGVkQ29sc4gBARIkCgtmcm96ZW5fcm93cxgFIAEoBUgEUgpmcm96ZW'
    '5Sb3dziAEBEiQKC2Zyb3plbl9jb2xzGAYgASgFSAVSCmZyb3plbkNvbHOIAQESMQoSZGVmYXVs'
    'dF9yb3dfaGVpZ2h0GAcgASgFSAZSEGRlZmF1bHRSb3dIZWlnaHSIAQESLwoRZGVmYXVsdF9jb2'
    'xfd2lkdGgYCCABKAVIB1IPZGVmYXVsdENvbFdpZHRoiAEBEicKDXJpZ2h0X3RvX2xlZnQYCSAB'
    'KAhICFILcmlnaHRUb0xlZnSIAQESKwoPZXh0ZW5kX2xhc3RfY29sGAogASgISAlSDWV4dGVuZE'
    'xhc3RDb2yIAQFCBwoFX3Jvd3NCBwoFX2NvbHNCDQoLX2ZpeGVkX3Jvd3NCDQoLX2ZpeGVkX2Nv'
    'bHNCDgoMX2Zyb3plbl9yb3dzQg4KDF9mcm96ZW5fY29sc0IVChNfZGVmYXVsdF9yb3dfaGVpZ2'
    'h0QhQKEl9kZWZhdWx0X2NvbF93aWR0aEIQCg5fcmlnaHRfdG9fbGVmdEISChBfZXh0ZW5kX2xh'
    'c3RfY29s');

@$core.Deprecated('Use styleConfigDescriptor instead')
const StyleConfig$json = {
  '1': 'StyleConfig',
  '2': [
    {
      '1': 'background',
      '3': 1,
      '4': 1,
      '5': 13,
      '9': 0,
      '10': 'background',
      '17': true
    },
    {
      '1': 'foreground',
      '3': 2,
      '4': 1,
      '5': 13,
      '9': 1,
      '10': 'foreground',
      '17': true
    },
    {
      '1': 'alternate_background',
      '3': 3,
      '4': 1,
      '5': 13,
      '9': 2,
      '10': 'alternateBackground',
      '17': true
    },
    {
      '1': 'font',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.Font',
      '10': 'font'
    },
    {
      '1': 'cell_padding',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.Padding',
      '10': 'cellPadding'
    },
    {
      '1': 'text_effect',
      '3': 6,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.TextEffect',
      '9': 3,
      '10': 'textEffect',
      '17': true
    },
    {
      '1': 'progress_color',
      '3': 7,
      '4': 1,
      '5': 13,
      '9': 4,
      '10': 'progressColor',
      '17': true
    },
    {
      '1': 'grid_lines',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.GridLines',
      '10': 'gridLines'
    },
    {
      '1': 'fixed',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.RegionStyle',
      '10': 'fixed'
    },
    {
      '1': 'frozen',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.RegionStyle',
      '10': 'frozen'
    },
    {
      '1': 'header',
      '3': 13,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.HeaderStyle',
      '10': 'header'
    },
    {
      '1': 'sheet_background',
      '3': 20,
      '4': 1,
      '5': 13,
      '9': 5,
      '10': 'sheetBackground',
      '17': true
    },
    {
      '1': 'sheet_border',
      '3': 21,
      '4': 1,
      '5': 13,
      '9': 6,
      '10': 'sheetBorder',
      '17': true
    },
    {
      '1': 'appearance',
      '3': 22,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.BorderAppearance',
      '9': 7,
      '10': 'appearance',
      '17': true
    },
    {
      '1': 'background_image',
      '3': 23,
      '4': 1,
      '5': 12,
      '9': 8,
      '10': 'backgroundImage',
      '17': true
    },
    {
      '1': 'background_image_align',
      '3': 24,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.ImageAlignment',
      '9': 9,
      '10': 'backgroundImageAlign',
      '17': true
    },
    {
      '1': 'text_rendering',
      '3': 25,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.TextRendering',
      '10': 'textRendering'
    },
    {
      '1': 'icons',
      '3': 30,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.IconTheme',
      '10': 'icons'
    },
    {
      '1': 'image_over_text',
      '3': 31,
      '4': 1,
      '5': 8,
      '9': 10,
      '10': 'imageOverText',
      '17': true
    },
    {
      '1': 'show_sort_numbers',
      '3': 32,
      '4': 1,
      '5': 8,
      '9': 11,
      '10': 'showSortNumbers',
      '17': true
    },
    {
      '1': 'apply_scope',
      '3': 33,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.ApplyScope',
      '9': 12,
      '10': 'applyScope',
      '17': true
    },
    {
      '1': 'custom_render',
      '3': 34,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.CustomRenderMode',
      '9': 13,
      '10': 'customRender',
      '17': true
    },
    {
      '1': 'format',
      '3': 40,
      '4': 1,
      '5': 9,
      '9': 14,
      '10': 'format',
      '17': true
    },
    {
      '1': 'word_wrap',
      '3': 41,
      '4': 1,
      '5': 8,
      '9': 15,
      '10': 'wordWrap',
      '17': true
    },
    {
      '1': 'ellipsis',
      '3': 42,
      '4': 1,
      '5': 5,
      '9': 16,
      '10': 'ellipsis',
      '17': true
    },
    {
      '1': 'text_overflow',
      '3': 43,
      '4': 1,
      '5': 8,
      '9': 17,
      '10': 'textOverflow',
      '17': true
    },
  ],
  '8': [
    {'1': '_background'},
    {'1': '_foreground'},
    {'1': '_alternate_background'},
    {'1': '_text_effect'},
    {'1': '_progress_color'},
    {'1': '_sheet_background'},
    {'1': '_sheet_border'},
    {'1': '_appearance'},
    {'1': '_background_image'},
    {'1': '_background_image_align'},
    {'1': '_image_over_text'},
    {'1': '_show_sort_numbers'},
    {'1': '_apply_scope'},
    {'1': '_custom_render'},
    {'1': '_format'},
    {'1': '_word_wrap'},
    {'1': '_ellipsis'},
    {'1': '_text_overflow'},
  ],
};

/// Descriptor for `StyleConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List styleConfigDescriptor = $convert.base64Decode(
    'CgtTdHlsZUNvbmZpZxIjCgpiYWNrZ3JvdW5kGAEgASgNSABSCmJhY2tncm91bmSIAQESIwoKZm'
    '9yZWdyb3VuZBgCIAEoDUgBUgpmb3JlZ3JvdW5kiAEBEjYKFGFsdGVybmF0ZV9iYWNrZ3JvdW5k'
    'GAMgASgNSAJSE2FsdGVybmF0ZUJhY2tncm91bmSIAQESJwoEZm9udBgEIAEoCzITLnZvbHZveG'
    'dyaWQudjEuRm9udFIEZm9udBI5CgxjZWxsX3BhZGRpbmcYBSABKAsyFi52b2x2b3hncmlkLnYx'
    'LlBhZGRpbmdSC2NlbGxQYWRkaW5nEj8KC3RleHRfZWZmZWN0GAYgASgOMhkudm9sdm94Z3JpZC'
    '52MS5UZXh0RWZmZWN0SANSCnRleHRFZmZlY3SIAQESKgoOcHJvZ3Jlc3NfY29sb3IYByABKA1I'
    'BFINcHJvZ3Jlc3NDb2xvcogBARI3CgpncmlkX2xpbmVzGAogASgLMhgudm9sdm94Z3JpZC52MS'
    '5HcmlkTGluZXNSCWdyaWRMaW5lcxIwCgVmaXhlZBgLIAEoCzIaLnZvbHZveGdyaWQudjEuUmVn'
    'aW9uU3R5bGVSBWZpeGVkEjIKBmZyb3plbhgMIAEoCzIaLnZvbHZveGdyaWQudjEuUmVnaW9uU3'
    'R5bGVSBmZyb3plbhIyCgZoZWFkZXIYDSABKAsyGi52b2x2b3hncmlkLnYxLkhlYWRlclN0eWxl'
    'UgZoZWFkZXISLgoQc2hlZXRfYmFja2dyb3VuZBgUIAEoDUgFUg9zaGVldEJhY2tncm91bmSIAQ'
    'ESJgoMc2hlZXRfYm9yZGVyGBUgASgNSAZSC3NoZWV0Qm9yZGVyiAEBEkQKCmFwcGVhcmFuY2UY'
    'FiABKA4yHy52b2x2b3hncmlkLnYxLkJvcmRlckFwcGVhcmFuY2VIB1IKYXBwZWFyYW5jZYgBAR'
    'IuChBiYWNrZ3JvdW5kX2ltYWdlGBcgASgMSAhSD2JhY2tncm91bmRJbWFnZYgBARJYChZiYWNr'
    'Z3JvdW5kX2ltYWdlX2FsaWduGBggASgOMh0udm9sdm94Z3JpZC52MS5JbWFnZUFsaWdubWVudE'
    'gJUhRiYWNrZ3JvdW5kSW1hZ2VBbGlnbogBARJDCg50ZXh0X3JlbmRlcmluZxgZIAEoCzIcLnZv'
    'bHZveGdyaWQudjEuVGV4dFJlbmRlcmluZ1INdGV4dFJlbmRlcmluZxIuCgVpY29ucxgeIAEoCz'
    'IYLnZvbHZveGdyaWQudjEuSWNvblRoZW1lUgVpY29ucxIrCg9pbWFnZV9vdmVyX3RleHQYHyAB'
    'KAhIClINaW1hZ2VPdmVyVGV4dIgBARIvChFzaG93X3NvcnRfbnVtYmVycxggIAEoCEgLUg9zaG'
    '93U29ydE51bWJlcnOIAQESPwoLYXBwbHlfc2NvcGUYISABKA4yGS52b2x2b3hncmlkLnYxLkFw'
    'cGx5U2NvcGVIDFIKYXBwbHlTY29wZYgBARJJCg1jdXN0b21fcmVuZGVyGCIgASgOMh8udm9sdm'
    '94Z3JpZC52MS5DdXN0b21SZW5kZXJNb2RlSA1SDGN1c3RvbVJlbmRlcogBARIbCgZmb3JtYXQY'
    'KCABKAlIDlIGZm9ybWF0iAEBEiAKCXdvcmRfd3JhcBgpIAEoCEgPUgh3b3JkV3JhcIgBARIfCg'
    'hlbGxpcHNpcxgqIAEoBUgQUghlbGxpcHNpc4gBARIoCg10ZXh0X292ZXJmbG93GCsgASgISBFS'
    'DHRleHRPdmVyZmxvd4gBAUINCgtfYmFja2dyb3VuZEINCgtfZm9yZWdyb3VuZEIXChVfYWx0ZX'
    'JuYXRlX2JhY2tncm91bmRCDgoMX3RleHRfZWZmZWN0QhEKD19wcm9ncmVzc19jb2xvckITChFf'
    'c2hlZXRfYmFja2dyb3VuZEIPCg1fc2hlZXRfYm9yZGVyQg0KC19hcHBlYXJhbmNlQhMKEV9iYW'
    'NrZ3JvdW5kX2ltYWdlQhkKF19iYWNrZ3JvdW5kX2ltYWdlX2FsaWduQhIKEF9pbWFnZV9vdmVy'
    'X3RleHRCFAoSX3Nob3dfc29ydF9udW1iZXJzQg4KDF9hcHBseV9zY29wZUIQCg5fY3VzdG9tX3'
    'JlbmRlckIJCgdfZm9ybWF0QgwKCl93b3JkX3dyYXBCCwoJX2VsbGlwc2lzQhAKDl90ZXh0X292'
    'ZXJmbG93');

@$core.Deprecated('Use selectionConfigDescriptor instead')
const SelectionConfig$json = {
  '1': 'SelectionConfig',
  '2': [
    {
      '1': 'mode',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.SelectionMode',
      '9': 0,
      '10': 'mode',
      '17': true
    },
    {
      '1': 'focus_border',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.FocusBorderStyle',
      '9': 1,
      '10': 'focusBorder',
      '17': true
    },
    {
      '1': 'visibility',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.SelectionVisibility',
      '9': 2,
      '10': 'visibility',
      '17': true
    },
    {'1': 'allow', '3': 4, '4': 1, '5': 8, '9': 3, '10': 'allow', '17': true},
    {
      '1': 'header_click_select',
      '3': 5,
      '4': 1,
      '5': 8,
      '9': 4,
      '10': 'headerClickSelect',
      '17': true
    },
    {
      '1': 'style',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.HighlightStyle',
      '10': 'style'
    },
    {
      '1': 'hover',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.HoverConfig',
      '10': 'hover'
    },
    {
      '1': 'indicator_row_style',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.HighlightStyle',
      '10': 'indicatorRowStyle'
    },
    {
      '1': 'indicator_col_style',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.HighlightStyle',
      '10': 'indicatorColStyle'
    },
    {
      '1': 'active_cell_style',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.HighlightStyle',
      '10': 'activeCellStyle'
    },
  ],
  '8': [
    {'1': '_mode'},
    {'1': '_focus_border'},
    {'1': '_visibility'},
    {'1': '_allow'},
    {'1': '_header_click_select'},
  ],
};

/// Descriptor for `SelectionConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List selectionConfigDescriptor = $convert.base64Decode(
    'Cg9TZWxlY3Rpb25Db25maWcSNQoEbW9kZRgBIAEoDjIcLnZvbHZveGdyaWQudjEuU2VsZWN0aW'
    '9uTW9kZUgAUgRtb2RliAEBEkcKDGZvY3VzX2JvcmRlchgCIAEoDjIfLnZvbHZveGdyaWQudjEu'
    'Rm9jdXNCb3JkZXJTdHlsZUgBUgtmb2N1c0JvcmRlcogBARJHCgp2aXNpYmlsaXR5GAMgASgOMi'
    'Iudm9sdm94Z3JpZC52MS5TZWxlY3Rpb25WaXNpYmlsaXR5SAJSCnZpc2liaWxpdHmIAQESGQoF'
    'YWxsb3cYBCABKAhIA1IFYWxsb3eIAQESMwoTaGVhZGVyX2NsaWNrX3NlbGVjdBgFIAEoCEgEUh'
    'FoZWFkZXJDbGlja1NlbGVjdIgBARIzCgVzdHlsZRgGIAEoCzIdLnZvbHZveGdyaWQudjEuSGln'
    'aGxpZ2h0U3R5bGVSBXN0eWxlEjAKBWhvdmVyGAcgASgLMhoudm9sdm94Z3JpZC52MS5Ib3Zlck'
    'NvbmZpZ1IFaG92ZXISTQoTaW5kaWNhdG9yX3Jvd19zdHlsZRgIIAEoCzIdLnZvbHZveGdyaWQu'
    'djEuSGlnaGxpZ2h0U3R5bGVSEWluZGljYXRvclJvd1N0eWxlEk0KE2luZGljYXRvcl9jb2xfc3'
    'R5bGUYCSABKAsyHS52b2x2b3hncmlkLnYxLkhpZ2hsaWdodFN0eWxlUhFpbmRpY2F0b3JDb2xT'
    'dHlsZRJJChFhY3RpdmVfY2VsbF9zdHlsZRgKIAEoCzIdLnZvbHZveGdyaWQudjEuSGlnaGxpZ2'
    'h0U3R5bGVSD2FjdGl2ZUNlbGxTdHlsZUIHCgVfbW9kZUIPCg1fZm9jdXNfYm9yZGVyQg0KC192'
    'aXNpYmlsaXR5QggKBl9hbGxvd0IWChRfaGVhZGVyX2NsaWNrX3NlbGVjdA==');

@$core.Deprecated('Use editConfigDescriptor instead')
const EditConfig$json = {
  '1': 'EditConfig',
  '2': [
    {
      '1': 'trigger',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.EditTrigger',
      '9': 0,
      '10': 'trigger',
      '17': true
    },
    {
      '1': 'tab_behavior',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.TabBehavior',
      '9': 1,
      '10': 'tabBehavior',
      '17': true
    },
    {
      '1': 'dropdown_trigger',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.DropdownTrigger',
      '9': 2,
      '10': 'dropdownTrigger',
      '17': true
    },
    {
      '1': 'dropdown_search',
      '3': 4,
      '4': 1,
      '5': 8,
      '9': 3,
      '10': 'dropdownSearch',
      '17': true
    },
    {
      '1': 'max_length',
      '3': 5,
      '4': 1,
      '5': 5,
      '9': 4,
      '10': 'maxLength',
      '17': true
    },
    {'1': 'mask', '3': 6, '4': 1, '5': 9, '9': 5, '10': 'mask', '17': true},
    {
      '1': 'host_key_dispatch',
      '3': 7,
      '4': 1,
      '5': 8,
      '9': 6,
      '10': 'hostKeyDispatch',
      '17': true
    },
    {
      '1': 'host_pointer_dispatch',
      '3': 8,
      '4': 1,
      '5': 8,
      '9': 7,
      '10': 'hostPointerDispatch',
      '17': true
    },
    {
      '1': 'engine_compose',
      '3': 9,
      '4': 1,
      '5': 8,
      '9': 8,
      '10': 'engineCompose',
      '17': true
    },
    {
      '1': 'compose_method',
      '3': 10,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.ComposeMethod',
      '9': 9,
      '10': 'composeMethod',
      '17': true
    },
  ],
  '8': [
    {'1': '_trigger'},
    {'1': '_tab_behavior'},
    {'1': '_dropdown_trigger'},
    {'1': '_dropdown_search'},
    {'1': '_max_length'},
    {'1': '_mask'},
    {'1': '_host_key_dispatch'},
    {'1': '_host_pointer_dispatch'},
    {'1': '_engine_compose'},
    {'1': '_compose_method'},
  ],
};

/// Descriptor for `EditConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List editConfigDescriptor = $convert.base64Decode(
    'CgpFZGl0Q29uZmlnEjkKB3RyaWdnZXIYASABKA4yGi52b2x2b3hncmlkLnYxLkVkaXRUcmlnZ2'
    'VySABSB3RyaWdnZXKIAQESQgoMdGFiX2JlaGF2aW9yGAIgASgOMhoudm9sdm94Z3JpZC52MS5U'
    'YWJCZWhhdmlvckgBUgt0YWJCZWhhdmlvcogBARJOChBkcm9wZG93bl90cmlnZ2VyGAMgASgOMh'
    '4udm9sdm94Z3JpZC52MS5Ecm9wZG93blRyaWdnZXJIAlIPZHJvcGRvd25UcmlnZ2VyiAEBEiwK'
    'D2Ryb3Bkb3duX3NlYXJjaBgEIAEoCEgDUg5kcm9wZG93blNlYXJjaIgBARIiCgptYXhfbGVuZ3'
    'RoGAUgASgFSARSCW1heExlbmd0aIgBARIXCgRtYXNrGAYgASgJSAVSBG1hc2uIAQESLwoRaG9z'
    'dF9rZXlfZGlzcGF0Y2gYByABKAhIBlIPaG9zdEtleURpc3BhdGNoiAEBEjcKFWhvc3RfcG9pbn'
    'Rlcl9kaXNwYXRjaBgIIAEoCEgHUhNob3N0UG9pbnRlckRpc3BhdGNoiAEBEioKDmVuZ2luZV9j'
    'b21wb3NlGAkgASgISAhSDWVuZ2luZUNvbXBvc2WIAQESSAoOY29tcG9zZV9tZXRob2QYCiABKA'
    '4yHC52b2x2b3hncmlkLnYxLkNvbXBvc2VNZXRob2RICVINY29tcG9zZU1ldGhvZIgBAUIKCghf'
    'dHJpZ2dlckIPCg1fdGFiX2JlaGF2aW9yQhMKEV9kcm9wZG93bl90cmlnZ2VyQhIKEF9kcm9wZG'
    '93bl9zZWFyY2hCDQoLX21heF9sZW5ndGhCBwoFX21hc2tCFAoSX2hvc3Rfa2V5X2Rpc3BhdGNo'
    'QhgKFl9ob3N0X3BvaW50ZXJfZGlzcGF0Y2hCEQoPX2VuZ2luZV9jb21wb3NlQhEKD19jb21wb3'
    'NlX21ldGhvZA==');

@$core.Deprecated('Use pullToRefreshConfigDescriptor instead')
const PullToRefreshConfig$json = {
  '1': 'PullToRefreshConfig',
  '2': [
    {
      '1': 'enabled',
      '3': 1,
      '4': 1,
      '5': 8,
      '9': 0,
      '10': 'enabled',
      '17': true
    },
    {
      '1': 'theme',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.PullToRefreshTheme',
      '9': 1,
      '10': 'theme',
      '17': true
    },
    {
      '1': 'text_pull',
      '3': 3,
      '4': 1,
      '5': 9,
      '9': 2,
      '10': 'textPull',
      '17': true
    },
    {
      '1': 'text_release',
      '3': 4,
      '4': 1,
      '5': 9,
      '9': 3,
      '10': 'textRelease',
      '17': true
    },
  ],
  '8': [
    {'1': '_enabled'},
    {'1': '_theme'},
    {'1': '_text_pull'},
    {'1': '_text_release'},
  ],
};

/// Descriptor for `PullToRefreshConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pullToRefreshConfigDescriptor = $convert.base64Decode(
    'ChNQdWxsVG9SZWZyZXNoQ29uZmlnEh0KB2VuYWJsZWQYASABKAhIAFIHZW5hYmxlZIgBARI8Cg'
    'V0aGVtZRgCIAEoDjIhLnZvbHZveGdyaWQudjEuUHVsbFRvUmVmcmVzaFRoZW1lSAFSBXRoZW1l'
    'iAEBEiAKCXRleHRfcHVsbBgDIAEoCUgCUgh0ZXh0UHVsbIgBARImCgx0ZXh0X3JlbGVhc2UYBC'
    'ABKAlIA1ILdGV4dFJlbGVhc2WIAQFCCgoIX2VuYWJsZWRCCAoGX3RoZW1lQgwKCl90ZXh0X3B1'
    'bGxCDwoNX3RleHRfcmVsZWFzZQ==');

@$core.Deprecated('Use scrollConfigDescriptor instead')
const ScrollConfig$json = {
  '1': 'ScrollConfig',
  '2': [
    {
      '1': 'scroll_bar',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.ScrollBarConfig',
      '10': 'scrollBar'
    },
    {
      '1': 'scroll_track',
      '3': 2,
      '4': 1,
      '5': 8,
      '9': 0,
      '10': 'scrollTrack',
      '17': true
    },
    {
      '1': 'scroll_tips',
      '3': 3,
      '4': 1,
      '5': 8,
      '9': 1,
      '10': 'scrollTips',
      '17': true
    },
    {
      '1': 'fling_enabled',
      '3': 4,
      '4': 1,
      '5': 8,
      '9': 2,
      '10': 'flingEnabled',
      '17': true
    },
    {
      '1': 'fling_impulse_gain',
      '3': 5,
      '4': 1,
      '5': 2,
      '9': 3,
      '10': 'flingImpulseGain',
      '17': true
    },
    {
      '1': 'fling_friction',
      '3': 6,
      '4': 1,
      '5': 2,
      '9': 4,
      '10': 'flingFriction',
      '17': true
    },
    {
      '1': 'pinch_zoom_enabled',
      '3': 7,
      '4': 1,
      '5': 8,
      '9': 5,
      '10': 'pinchZoomEnabled',
      '17': true
    },
    {
      '1': 'fast_scroll',
      '3': 8,
      '4': 1,
      '5': 8,
      '9': 6,
      '10': 'fastScroll',
      '17': true
    },
    {
      '1': 'scrollbars',
      '3': 9,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.ScrollBarsMode',
      '9': 7,
      '10': 'scrollbars',
      '17': true
    },
    {
      '1': 'pull_to_refresh',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.PullToRefreshConfig',
      '10': 'pullToRefresh'
    },
  ],
  '8': [
    {'1': '_scroll_track'},
    {'1': '_scroll_tips'},
    {'1': '_fling_enabled'},
    {'1': '_fling_impulse_gain'},
    {'1': '_fling_friction'},
    {'1': '_pinch_zoom_enabled'},
    {'1': '_fast_scroll'},
    {'1': '_scrollbars'},
  ],
};

/// Descriptor for `ScrollConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List scrollConfigDescriptor = $convert.base64Decode(
    'CgxTY3JvbGxDb25maWcSPQoKc2Nyb2xsX2JhchgBIAEoCzIeLnZvbHZveGdyaWQudjEuU2Nyb2'
    'xsQmFyQ29uZmlnUglzY3JvbGxCYXISJgoMc2Nyb2xsX3RyYWNrGAIgASgISABSC3Njcm9sbFRy'
    'YWNriAEBEiQKC3Njcm9sbF90aXBzGAMgASgISAFSCnNjcm9sbFRpcHOIAQESKAoNZmxpbmdfZW'
    '5hYmxlZBgEIAEoCEgCUgxmbGluZ0VuYWJsZWSIAQESMQoSZmxpbmdfaW1wdWxzZV9nYWluGAUg'
    'ASgCSANSEGZsaW5nSW1wdWxzZUdhaW6IAQESKgoOZmxpbmdfZnJpY3Rpb24YBiABKAJIBFINZm'
    'xpbmdGcmljdGlvbogBARIxChJwaW5jaF96b29tX2VuYWJsZWQYByABKAhIBVIQcGluY2hab29t'
    'RW5hYmxlZIgBARIkCgtmYXN0X3Njcm9sbBgIIAEoCEgGUgpmYXN0U2Nyb2xsiAEBEkIKCnNjcm'
    '9sbGJhcnMYCSABKA4yHS52b2x2b3hncmlkLnYxLlNjcm9sbEJhcnNNb2RlSAdSCnNjcm9sbGJh'
    'cnOIAQESSgoPcHVsbF90b19yZWZyZXNoGAogASgLMiIudm9sdm94Z3JpZC52MS5QdWxsVG9SZW'
    'ZyZXNoQ29uZmlnUg1wdWxsVG9SZWZyZXNoQg8KDV9zY3JvbGxfdHJhY2tCDgoMX3Njcm9sbF90'
    'aXBzQhAKDl9mbGluZ19lbmFibGVkQhUKE19mbGluZ19pbXB1bHNlX2dhaW5CEQoPX2ZsaW5nX2'
    'ZyaWN0aW9uQhUKE19waW5jaF96b29tX2VuYWJsZWRCDgoMX2Zhc3Rfc2Nyb2xsQg0KC19zY3Jv'
    'bGxiYXJz');

@$core.Deprecated('Use outlineConfigDescriptor instead')
const OutlineConfig$json = {
  '1': 'OutlineConfig',
  '2': [
    {
      '1': 'tree_indicator',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.TreeIndicatorStyle',
      '9': 0,
      '10': 'treeIndicator',
      '17': true
    },
    {
      '1': 'tree_column',
      '3': 2,
      '4': 1,
      '5': 5,
      '9': 1,
      '10': 'treeColumn',
      '17': true
    },
    {
      '1': 'tree_color',
      '3': 3,
      '4': 1,
      '5': 13,
      '9': 2,
      '10': 'treeColor',
      '17': true
    },
    {
      '1': 'group_total_position',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.GroupTotalPosition',
      '9': 3,
      '10': 'groupTotalPosition',
      '17': true
    },
    {
      '1': 'multi_totals',
      '3': 5,
      '4': 1,
      '5': 8,
      '9': 4,
      '10': 'multiTotals',
      '17': true
    },
  ],
  '8': [
    {'1': '_tree_indicator'},
    {'1': '_tree_column'},
    {'1': '_tree_color'},
    {'1': '_group_total_position'},
    {'1': '_multi_totals'},
  ],
};

/// Descriptor for `OutlineConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List outlineConfigDescriptor = $convert.base64Decode(
    'Cg1PdXRsaW5lQ29uZmlnEk0KDnRyZWVfaW5kaWNhdG9yGAEgASgOMiEudm9sdm94Z3JpZC52MS'
    '5UcmVlSW5kaWNhdG9yU3R5bGVIAFINdHJlZUluZGljYXRvcogBARIkCgt0cmVlX2NvbHVtbhgC'
    'IAEoBUgBUgp0cmVlQ29sdW1uiAEBEiIKCnRyZWVfY29sb3IYAyABKA1IAlIJdHJlZUNvbG9yiA'
    'EBElgKFGdyb3VwX3RvdGFsX3Bvc2l0aW9uGAQgASgOMiEudm9sdm94Z3JpZC52MS5Hcm91cFRv'
    'dGFsUG9zaXRpb25IA1ISZ3JvdXBUb3RhbFBvc2l0aW9uiAEBEiYKDG11bHRpX3RvdGFscxgFIA'
    'EoCEgEUgttdWx0aVRvdGFsc4gBAUIRCg9fdHJlZV9pbmRpY2F0b3JCDgoMX3RyZWVfY29sdW1u'
    'Qg0KC190cmVlX2NvbG9yQhcKFV9ncm91cF90b3RhbF9wb3NpdGlvbkIPCg1fbXVsdGlfdG90YW'
    'xz');

@$core.Deprecated('Use spanConfigDescriptor instead')
const SpanConfig$json = {
  '1': 'SpanConfig',
  '2': [
    {
      '1': 'cell_span',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.CellSpanMode',
      '9': 0,
      '10': 'cellSpan',
      '17': true
    },
    {
      '1': 'cell_span_fixed',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.CellSpanMode',
      '9': 1,
      '10': 'cellSpanFixed',
      '17': true
    },
    {
      '1': 'cell_span_compare',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.SpanCompareMode',
      '9': 2,
      '10': 'cellSpanCompare',
      '17': true
    },
    {
      '1': 'group_span_compare',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.SpanCompareMode',
      '9': 3,
      '10': 'groupSpanCompare',
      '17': true
    },
  ],
  '8': [
    {'1': '_cell_span'},
    {'1': '_cell_span_fixed'},
    {'1': '_cell_span_compare'},
    {'1': '_group_span_compare'},
  ],
};

/// Descriptor for `SpanConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List spanConfigDescriptor = $convert.base64Decode(
    'CgpTcGFuQ29uZmlnEj0KCWNlbGxfc3BhbhgBIAEoDjIbLnZvbHZveGdyaWQudjEuQ2VsbFNwYW'
    '5Nb2RlSABSCGNlbGxTcGFuiAEBEkgKD2NlbGxfc3Bhbl9maXhlZBgCIAEoDjIbLnZvbHZveGdy'
    'aWQudjEuQ2VsbFNwYW5Nb2RlSAFSDWNlbGxTcGFuRml4ZWSIAQESTwoRY2VsbF9zcGFuX2NvbX'
    'BhcmUYAyABKA4yHi52b2x2b3hncmlkLnYxLlNwYW5Db21wYXJlTW9kZUgCUg9jZWxsU3BhbkNv'
    'bXBhcmWIAQESUQoSZ3JvdXBfc3Bhbl9jb21wYXJlGAQgASgOMh4udm9sdm94Z3JpZC52MS5TcG'
    'FuQ29tcGFyZU1vZGVIA1IQZ3JvdXBTcGFuQ29tcGFyZYgBAUIMCgpfY2VsbF9zcGFuQhIKEF9j'
    'ZWxsX3NwYW5fZml4ZWRCFAoSX2NlbGxfc3Bhbl9jb21wYXJlQhUKE19ncm91cF9zcGFuX2NvbX'
    'BhcmU=');

@$core.Deprecated('Use interactionConfigDescriptor instead')
const InteractionConfig$json = {
  '1': 'InteractionConfig',
  '2': [
    {
      '1': 'resize',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.ResizePolicy',
      '10': 'resize'
    },
    {
      '1': 'freeze',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.FreezePolicy',
      '10': 'freeze'
    },
    {
      '1': 'type_ahead',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.TypeAheadMode',
      '9': 0,
      '10': 'typeAhead',
      '17': true
    },
    {
      '1': 'type_ahead_delay',
      '3': 4,
      '4': 1,
      '5': 5,
      '9': 1,
      '10': 'typeAheadDelay',
      '17': true
    },
    {
      '1': 'auto_size_mouse',
      '3': 5,
      '4': 1,
      '5': 8,
      '9': 2,
      '10': 'autoSizeMouse',
      '17': true
    },
    {
      '1': 'auto_size_mode',
      '3': 6,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.AutoSizeMode',
      '9': 3,
      '10': 'autoSizeMode',
      '17': true
    },
    {
      '1': 'auto_resize',
      '3': 7,
      '4': 1,
      '5': 8,
      '9': 4,
      '10': 'autoResize',
      '17': true
    },
    {
      '1': 'drag_mode',
      '3': 8,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.DragMode',
      '9': 5,
      '10': 'dragMode',
      '17': true
    },
    {
      '1': 'drop_mode',
      '3': 9,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.DropMode',
      '9': 6,
      '10': 'dropMode',
      '17': true
    },
    {
      '1': 'header_features',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.HeaderFeatures',
      '10': 'headerFeatures'
    },
  ],
  '8': [
    {'1': '_type_ahead'},
    {'1': '_type_ahead_delay'},
    {'1': '_auto_size_mouse'},
    {'1': '_auto_size_mode'},
    {'1': '_auto_resize'},
    {'1': '_drag_mode'},
    {'1': '_drop_mode'},
  ],
};

/// Descriptor for `InteractionConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List interactionConfigDescriptor = $convert.base64Decode(
    'ChFJbnRlcmFjdGlvbkNvbmZpZxIzCgZyZXNpemUYASABKAsyGy52b2x2b3hncmlkLnYxLlJlc2'
    'l6ZVBvbGljeVIGcmVzaXplEjMKBmZyZWV6ZRgCIAEoCzIbLnZvbHZveGdyaWQudjEuRnJlZXpl'
    'UG9saWN5UgZmcmVlemUSQAoKdHlwZV9haGVhZBgDIAEoDjIcLnZvbHZveGdyaWQudjEuVHlwZU'
    'FoZWFkTW9kZUgAUgl0eXBlQWhlYWSIAQESLQoQdHlwZV9haGVhZF9kZWxheRgEIAEoBUgBUg50'
    'eXBlQWhlYWREZWxheYgBARIrCg9hdXRvX3NpemVfbW91c2UYBSABKAhIAlINYXV0b1NpemVNb3'
    'VzZYgBARJGCg5hdXRvX3NpemVfbW9kZRgGIAEoDjIbLnZvbHZveGdyaWQudjEuQXV0b1NpemVN'
    'b2RlSANSDGF1dG9TaXplTW9kZYgBARIkCgthdXRvX3Jlc2l6ZRgHIAEoCEgEUgphdXRvUmVzaX'
    'pliAEBEjkKCWRyYWdfbW9kZRgIIAEoDjIXLnZvbHZveGdyaWQudjEuRHJhZ01vZGVIBVIIZHJh'
    'Z01vZGWIAQESOQoJZHJvcF9tb2RlGAkgASgOMhcudm9sdm94Z3JpZC52MS5Ecm9wTW9kZUgGUg'
    'hkcm9wTW9kZYgBARJGCg9oZWFkZXJfZmVhdHVyZXMYCiABKAsyHS52b2x2b3hncmlkLnYxLkhl'
    'YWRlckZlYXR1cmVzUg5oZWFkZXJGZWF0dXJlc0INCgtfdHlwZV9haGVhZEITChFfdHlwZV9haG'
    'VhZF9kZWxheUISChBfYXV0b19zaXplX21vdXNlQhEKD19hdXRvX3NpemVfbW9kZUIOCgxfYXV0'
    'b19yZXNpemVCDAoKX2RyYWdfbW9kZUIMCgpfZHJvcF9tb2Rl');

@$core.Deprecated('Use renderConfigDescriptor instead')
const RenderConfig$json = {
  '1': 'RenderConfig',
  '2': [
    {
      '1': 'renderer_mode',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.RendererMode',
      '9': 0,
      '10': 'rendererMode',
      '17': true
    },
    {
      '1': 'debug_overlay',
      '3': 2,
      '4': 1,
      '5': 8,
      '9': 1,
      '10': 'debugOverlay',
      '17': true
    },
    {
      '1': 'animation_enabled',
      '3': 3,
      '4': 1,
      '5': 8,
      '9': 2,
      '10': 'animationEnabled',
      '17': true
    },
    {
      '1': 'animation_duration_ms',
      '3': 4,
      '4': 1,
      '5': 5,
      '9': 3,
      '10': 'animationDurationMs',
      '17': true
    },
    {
      '1': 'text_layout_cache_cap',
      '3': 5,
      '4': 1,
      '5': 5,
      '9': 4,
      '10': 'textLayoutCacheCap',
      '17': true
    },
    {
      '1': 'present_mode',
      '3': 6,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.PresentMode',
      '9': 5,
      '10': 'presentMode',
      '17': true
    },
    {
      '1': 'frame_pacing_mode',
      '3': 7,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.FramePacingMode',
      '9': 6,
      '10': 'framePacingMode',
      '17': true
    },
    {
      '1': 'target_frame_rate_hz',
      '3': 8,
      '4': 1,
      '5': 5,
      '9': 7,
      '10': 'targetFrameRateHz',
      '17': true
    },
    {
      '1': 'render_layer_mask',
      '3': 9,
      '4': 1,
      '5': 3,
      '9': 8,
      '10': 'renderLayerMask',
      '17': true
    },
    {
      '1': 'layer_profiling',
      '3': 10,
      '4': 1,
      '5': 8,
      '9': 9,
      '10': 'layerProfiling',
      '17': true
    },
    {
      '1': 'scroll_blit',
      '3': 11,
      '4': 1,
      '5': 8,
      '9': 10,
      '10': 'scrollBlit',
      '17': true
    },
  ],
  '8': [
    {'1': '_renderer_mode'},
    {'1': '_debug_overlay'},
    {'1': '_animation_enabled'},
    {'1': '_animation_duration_ms'},
    {'1': '_text_layout_cache_cap'},
    {'1': '_present_mode'},
    {'1': '_frame_pacing_mode'},
    {'1': '_target_frame_rate_hz'},
    {'1': '_render_layer_mask'},
    {'1': '_layer_profiling'},
    {'1': '_scroll_blit'},
  ],
};

/// Descriptor for `RenderConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List renderConfigDescriptor = $convert.base64Decode(
    'CgxSZW5kZXJDb25maWcSRQoNcmVuZGVyZXJfbW9kZRgBIAEoDjIbLnZvbHZveGdyaWQudjEuUm'
    'VuZGVyZXJNb2RlSABSDHJlbmRlcmVyTW9kZYgBARIoCg1kZWJ1Z19vdmVybGF5GAIgASgISAFS'
    'DGRlYnVnT3ZlcmxheYgBARIwChFhbmltYXRpb25fZW5hYmxlZBgDIAEoCEgCUhBhbmltYXRpb2'
    '5FbmFibGVkiAEBEjcKFWFuaW1hdGlvbl9kdXJhdGlvbl9tcxgEIAEoBUgDUhNhbmltYXRpb25E'
    'dXJhdGlvbk1ziAEBEjYKFXRleHRfbGF5b3V0X2NhY2hlX2NhcBgFIAEoBUgEUhJ0ZXh0TGF5b3'
    'V0Q2FjaGVDYXCIAQESQgoMcHJlc2VudF9tb2RlGAYgASgOMhoudm9sdm94Z3JpZC52MS5QcmVz'
    'ZW50TW9kZUgFUgtwcmVzZW50TW9kZYgBARJPChFmcmFtZV9wYWNpbmdfbW9kZRgHIAEoDjIeLn'
    'ZvbHZveGdyaWQudjEuRnJhbWVQYWNpbmdNb2RlSAZSD2ZyYW1lUGFjaW5nTW9kZYgBARI0ChR0'
    'YXJnZXRfZnJhbWVfcmF0ZV9oehgIIAEoBUgHUhF0YXJnZXRGcmFtZVJhdGVIeogBARIvChFyZW'
    '5kZXJfbGF5ZXJfbWFzaxgJIAEoA0gIUg9yZW5kZXJMYXllck1hc2uIAQESLAoPbGF5ZXJfcHJv'
    'ZmlsaW5nGAogASgISAlSDmxheWVyUHJvZmlsaW5niAEBEiQKC3Njcm9sbF9ibGl0GAsgASgISA'
    'pSCnNjcm9sbEJsaXSIAQFCEAoOX3JlbmRlcmVyX21vZGVCEAoOX2RlYnVnX292ZXJsYXlCFAoS'
    'X2FuaW1hdGlvbl9lbmFibGVkQhgKFl9hbmltYXRpb25fZHVyYXRpb25fbXNCGAoWX3RleHRfbG'
    'F5b3V0X2NhY2hlX2NhcEIPCg1fcHJlc2VudF9tb2RlQhQKEl9mcmFtZV9wYWNpbmdfbW9kZUIX'
    'ChVfdGFyZ2V0X2ZyYW1lX3JhdGVfaHpCFAoSX3JlbmRlcl9sYXllcl9tYXNrQhIKEF9sYXllcl'
    '9wcm9maWxpbmdCDgoMX3Njcm9sbF9ibGl0');

@$core.Deprecated('Use rowIndicatorSlotDescriptor instead')
const RowIndicatorSlot$json = {
  '1': 'RowIndicatorSlot',
  '2': [
    {
      '1': 'kind',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.RowIndicatorSlotKind',
      '9': 0,
      '10': 'kind',
      '17': true
    },
    {'1': 'width', '3': 2, '4': 1, '5': 5, '9': 1, '10': 'width', '17': true},
    {
      '1': 'visible',
      '3': 3,
      '4': 1,
      '5': 8,
      '9': 2,
      '10': 'visible',
      '17': true
    },
    {
      '1': 'custom_key',
      '3': 4,
      '4': 1,
      '5': 9,
      '9': 3,
      '10': 'customKey',
      '17': true
    },
    {'1': 'data', '3': 5, '4': 1, '5': 12, '9': 4, '10': 'data', '17': true},
  ],
  '8': [
    {'1': '_kind'},
    {'1': '_width'},
    {'1': '_visible'},
    {'1': '_custom_key'},
    {'1': '_data'},
  ],
};

/// Descriptor for `RowIndicatorSlot`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List rowIndicatorSlotDescriptor = $convert.base64Decode(
    'ChBSb3dJbmRpY2F0b3JTbG90EjwKBGtpbmQYASABKA4yIy52b2x2b3hncmlkLnYxLlJvd0luZG'
    'ljYXRvclNsb3RLaW5kSABSBGtpbmSIAQESGQoFd2lkdGgYAiABKAVIAVIFd2lkdGiIAQESHQoH'
    'dmlzaWJsZRgDIAEoCEgCUgd2aXNpYmxliAEBEiIKCmN1c3RvbV9rZXkYBCABKAlIA1IJY3VzdG'
    '9tS2V5iAEBEhcKBGRhdGEYBSABKAxIBFIEZGF0YYgBAUIHCgVfa2luZEIICgZfd2lkdGhCCgoI'
    'X3Zpc2libGVCDQoLX2N1c3RvbV9rZXlCBwoFX2RhdGE=');

@$core.Deprecated('Use rowIndicatorConfigDescriptor instead')
const RowIndicatorConfig$json = {
  '1': 'RowIndicatorConfig',
  '2': [
    {
      '1': 'visible',
      '3': 1,
      '4': 1,
      '5': 8,
      '9': 0,
      '10': 'visible',
      '17': true
    },
    {'1': 'width', '3': 2, '4': 1, '5': 5, '9': 1, '10': 'width', '17': true},
    {
      '1': 'mode_bits',
      '3': 3,
      '4': 1,
      '5': 13,
      '9': 2,
      '10': 'modeBits',
      '17': true
    },
    {
      '1': 'background',
      '3': 4,
      '4': 1,
      '5': 13,
      '9': 3,
      '10': 'background',
      '17': true
    },
    {
      '1': 'foreground',
      '3': 5,
      '4': 1,
      '5': 13,
      '9': 4,
      '10': 'foreground',
      '17': true
    },
    {
      '1': 'grid_lines',
      '3': 6,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.GridLineStyle',
      '9': 5,
      '10': 'gridLines',
      '17': true
    },
    {
      '1': 'grid_color',
      '3': 7,
      '4': 1,
      '5': 13,
      '9': 6,
      '10': 'gridColor',
      '17': true
    },
    {
      '1': 'auto_size',
      '3': 8,
      '4': 1,
      '5': 8,
      '9': 7,
      '10': 'autoSize',
      '17': true
    },
    {
      '1': 'allow_resize',
      '3': 9,
      '4': 1,
      '5': 8,
      '9': 8,
      '10': 'allowResize',
      '17': true
    },
    {
      '1': 'allow_select',
      '3': 10,
      '4': 1,
      '5': 8,
      '9': 9,
      '10': 'allowSelect',
      '17': true
    },
    {
      '1': 'allow_reorder',
      '3': 11,
      '4': 1,
      '5': 8,
      '9': 10,
      '10': 'allowReorder',
      '17': true
    },
    {
      '1': 'slots',
      '3': 12,
      '4': 3,
      '5': 11,
      '6': '.volvoxgrid.v1.RowIndicatorSlot',
      '10': 'slots'
    },
  ],
  '8': [
    {'1': '_visible'},
    {'1': '_width'},
    {'1': '_mode_bits'},
    {'1': '_background'},
    {'1': '_foreground'},
    {'1': '_grid_lines'},
    {'1': '_grid_color'},
    {'1': '_auto_size'},
    {'1': '_allow_resize'},
    {'1': '_allow_select'},
    {'1': '_allow_reorder'},
  ],
};

/// Descriptor for `RowIndicatorConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List rowIndicatorConfigDescriptor = $convert.base64Decode(
    'ChJSb3dJbmRpY2F0b3JDb25maWcSHQoHdmlzaWJsZRgBIAEoCEgAUgd2aXNpYmxliAEBEhkKBX'
    'dpZHRoGAIgASgFSAFSBXdpZHRoiAEBEiAKCW1vZGVfYml0cxgDIAEoDUgCUghtb2RlQml0c4gB'
    'ARIjCgpiYWNrZ3JvdW5kGAQgASgNSANSCmJhY2tncm91bmSIAQESIwoKZm9yZWdyb3VuZBgFIA'
    'EoDUgEUgpmb3JlZ3JvdW5kiAEBEkAKCmdyaWRfbGluZXMYBiABKA4yHC52b2x2b3hncmlkLnYx'
    'LkdyaWRMaW5lU3R5bGVIBVIJZ3JpZExpbmVziAEBEiIKCmdyaWRfY29sb3IYByABKA1IBlIJZ3'
    'JpZENvbG9yiAEBEiAKCWF1dG9fc2l6ZRgIIAEoCEgHUghhdXRvU2l6ZYgBARImCgxhbGxvd19y'
    'ZXNpemUYCSABKAhICFILYWxsb3dSZXNpemWIAQESJgoMYWxsb3dfc2VsZWN0GAogASgISAlSC2'
    'FsbG93U2VsZWN0iAEBEigKDWFsbG93X3Jlb3JkZXIYCyABKAhIClIMYWxsb3dSZW9yZGVyiAEB'
    'EjUKBXNsb3RzGAwgAygLMh8udm9sdm94Z3JpZC52MS5Sb3dJbmRpY2F0b3JTbG90UgVzbG90c0'
    'IKCghfdmlzaWJsZUIICgZfd2lkdGhCDAoKX21vZGVfYml0c0INCgtfYmFja2dyb3VuZEINCgtf'
    'Zm9yZWdyb3VuZEINCgtfZ3JpZF9saW5lc0INCgtfZ3JpZF9jb2xvckIMCgpfYXV0b19zaXplQg'
    '8KDV9hbGxvd19yZXNpemVCDwoNX2FsbG93X3NlbGVjdEIQCg5fYWxsb3dfcmVvcmRlcg==');

@$core.Deprecated('Use colIndicatorRowDefDescriptor instead')
const ColIndicatorRowDef$json = {
  '1': 'ColIndicatorRowDef',
  '2': [
    {'1': 'index', '3': 1, '4': 1, '5': 5, '9': 0, '10': 'index', '17': true},
    {'1': 'height', '3': 2, '4': 1, '5': 5, '9': 1, '10': 'height', '17': true},
  ],
  '8': [
    {'1': '_index'},
    {'1': '_height'},
  ],
};

/// Descriptor for `ColIndicatorRowDef`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List colIndicatorRowDefDescriptor = $convert.base64Decode(
    'ChJDb2xJbmRpY2F0b3JSb3dEZWYSGQoFaW5kZXgYASABKAVIAFIFaW5kZXiIAQESGwoGaGVpZ2'
    'h0GAIgASgFSAFSBmhlaWdodIgBAUIICgZfaW5kZXhCCQoHX2hlaWdodA==');

@$core.Deprecated('Use colIndicatorCellDescriptor instead')
const ColIndicatorCell$json = {
  '1': 'ColIndicatorCell',
  '2': [
    {'1': 'row1', '3': 1, '4': 1, '5': 5, '9': 0, '10': 'row1', '17': true},
    {'1': 'row2', '3': 2, '4': 1, '5': 5, '9': 1, '10': 'row2', '17': true},
    {'1': 'col1', '3': 3, '4': 1, '5': 5, '9': 2, '10': 'col1', '17': true},
    {'1': 'col2', '3': 4, '4': 1, '5': 5, '9': 3, '10': 'col2', '17': true},
    {'1': 'text', '3': 5, '4': 1, '5': 9, '9': 4, '10': 'text', '17': true},
    {
      '1': 'mode_bits',
      '3': 6,
      '4': 1,
      '5': 13,
      '9': 5,
      '10': 'modeBits',
      '17': true
    },
    {
      '1': 'custom_key',
      '3': 7,
      '4': 1,
      '5': 9,
      '9': 6,
      '10': 'customKey',
      '17': true
    },
    {'1': 'data', '3': 8, '4': 1, '5': 12, '9': 7, '10': 'data', '17': true},
  ],
  '8': [
    {'1': '_row1'},
    {'1': '_row2'},
    {'1': '_col1'},
    {'1': '_col2'},
    {'1': '_text'},
    {'1': '_mode_bits'},
    {'1': '_custom_key'},
    {'1': '_data'},
  ],
};

/// Descriptor for `ColIndicatorCell`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List colIndicatorCellDescriptor = $convert.base64Decode(
    'ChBDb2xJbmRpY2F0b3JDZWxsEhcKBHJvdzEYASABKAVIAFIEcm93MYgBARIXCgRyb3cyGAIgAS'
    'gFSAFSBHJvdzKIAQESFwoEY29sMRgDIAEoBUgCUgRjb2wxiAEBEhcKBGNvbDIYBCABKAVIA1IE'
    'Y29sMogBARIXCgR0ZXh0GAUgASgJSARSBHRleHSIAQESIAoJbW9kZV9iaXRzGAYgASgNSAVSCG'
    '1vZGVCaXRziAEBEiIKCmN1c3RvbV9rZXkYByABKAlIBlIJY3VzdG9tS2V5iAEBEhcKBGRhdGEY'
    'CCABKAxIB1IEZGF0YYgBAUIHCgVfcm93MUIHCgVfcm93MkIHCgVfY29sMUIHCgVfY29sMkIHCg'
    'VfdGV4dEIMCgpfbW9kZV9iaXRzQg0KC19jdXN0b21fa2V5QgcKBV9kYXRh');

@$core.Deprecated('Use colIndicatorConfigDescriptor instead')
const ColIndicatorConfig$json = {
  '1': 'ColIndicatorConfig',
  '2': [
    {
      '1': 'visible',
      '3': 1,
      '4': 1,
      '5': 8,
      '9': 0,
      '10': 'visible',
      '17': true
    },
    {
      '1': 'default_row_height',
      '3': 2,
      '4': 1,
      '5': 5,
      '9': 1,
      '10': 'defaultRowHeight',
      '17': true
    },
    {
      '1': 'band_rows',
      '3': 3,
      '4': 1,
      '5': 5,
      '9': 2,
      '10': 'bandRows',
      '17': true
    },
    {
      '1': 'mode_bits',
      '3': 4,
      '4': 1,
      '5': 13,
      '9': 3,
      '10': 'modeBits',
      '17': true
    },
    {
      '1': 'background',
      '3': 5,
      '4': 1,
      '5': 13,
      '9': 4,
      '10': 'background',
      '17': true
    },
    {
      '1': 'foreground',
      '3': 6,
      '4': 1,
      '5': 13,
      '9': 5,
      '10': 'foreground',
      '17': true
    },
    {
      '1': 'grid_lines',
      '3': 7,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.GridLineStyle',
      '9': 6,
      '10': 'gridLines',
      '17': true
    },
    {
      '1': 'grid_color',
      '3': 8,
      '4': 1,
      '5': 13,
      '9': 7,
      '10': 'gridColor',
      '17': true
    },
    {
      '1': 'auto_size',
      '3': 9,
      '4': 1,
      '5': 8,
      '9': 8,
      '10': 'autoSize',
      '17': true
    },
    {
      '1': 'allow_resize',
      '3': 10,
      '4': 1,
      '5': 8,
      '9': 9,
      '10': 'allowResize',
      '17': true
    },
    {
      '1': 'allow_reorder',
      '3': 11,
      '4': 1,
      '5': 8,
      '9': 10,
      '10': 'allowReorder',
      '17': true
    },
    {
      '1': 'allow_menu',
      '3': 12,
      '4': 1,
      '5': 8,
      '9': 11,
      '10': 'allowMenu',
      '17': true
    },
    {
      '1': 'row_defs',
      '3': 13,
      '4': 3,
      '5': 11,
      '6': '.volvoxgrid.v1.ColIndicatorRowDef',
      '10': 'rowDefs'
    },
    {
      '1': 'cells',
      '3': 14,
      '4': 3,
      '5': 11,
      '6': '.volvoxgrid.v1.ColIndicatorCell',
      '10': 'cells'
    },
  ],
  '8': [
    {'1': '_visible'},
    {'1': '_default_row_height'},
    {'1': '_band_rows'},
    {'1': '_mode_bits'},
    {'1': '_background'},
    {'1': '_foreground'},
    {'1': '_grid_lines'},
    {'1': '_grid_color'},
    {'1': '_auto_size'},
    {'1': '_allow_resize'},
    {'1': '_allow_reorder'},
    {'1': '_allow_menu'},
  ],
};

/// Descriptor for `ColIndicatorConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List colIndicatorConfigDescriptor = $convert.base64Decode(
    'ChJDb2xJbmRpY2F0b3JDb25maWcSHQoHdmlzaWJsZRgBIAEoCEgAUgd2aXNpYmxliAEBEjEKEm'
    'RlZmF1bHRfcm93X2hlaWdodBgCIAEoBUgBUhBkZWZhdWx0Um93SGVpZ2h0iAEBEiAKCWJhbmRf'
    'cm93cxgDIAEoBUgCUghiYW5kUm93c4gBARIgCgltb2RlX2JpdHMYBCABKA1IA1IIbW9kZUJpdH'
    'OIAQESIwoKYmFja2dyb3VuZBgFIAEoDUgEUgpiYWNrZ3JvdW5kiAEBEiMKCmZvcmVncm91bmQY'
    'BiABKA1IBVIKZm9yZWdyb3VuZIgBARJACgpncmlkX2xpbmVzGAcgASgOMhwudm9sdm94Z3JpZC'
    '52MS5HcmlkTGluZVN0eWxlSAZSCWdyaWRMaW5lc4gBARIiCgpncmlkX2NvbG9yGAggASgNSAdS'
    'CWdyaWRDb2xvcogBARIgCglhdXRvX3NpemUYCSABKAhICFIIYXV0b1NpemWIAQESJgoMYWxsb3'
    'dfcmVzaXplGAogASgISAlSC2FsbG93UmVzaXpliAEBEigKDWFsbG93X3Jlb3JkZXIYCyABKAhI'
    'ClIMYWxsb3dSZW9yZGVyiAEBEiIKCmFsbG93X21lbnUYDCABKAhIC1IJYWxsb3dNZW51iAEBEj'
    'wKCHJvd19kZWZzGA0gAygLMiEudm9sdm94Z3JpZC52MS5Db2xJbmRpY2F0b3JSb3dEZWZSB3Jv'
    'd0RlZnMSNQoFY2VsbHMYDiADKAsyHy52b2x2b3hncmlkLnYxLkNvbEluZGljYXRvckNlbGxSBW'
    'NlbGxzQgoKCF92aXNpYmxlQhUKE19kZWZhdWx0X3Jvd19oZWlnaHRCDAoKX2JhbmRfcm93c0IM'
    'CgpfbW9kZV9iaXRzQg0KC19iYWNrZ3JvdW5kQg0KC19mb3JlZ3JvdW5kQg0KC19ncmlkX2xpbm'
    'VzQg0KC19ncmlkX2NvbG9yQgwKCl9hdXRvX3NpemVCDwoNX2FsbG93X3Jlc2l6ZUIQCg5fYWxs'
    'b3dfcmVvcmRlckINCgtfYWxsb3dfbWVudQ==');

@$core.Deprecated('Use cornerIndicatorConfigDescriptor instead')
const CornerIndicatorConfig$json = {
  '1': 'CornerIndicatorConfig',
  '2': [
    {
      '1': 'visible',
      '3': 1,
      '4': 1,
      '5': 8,
      '9': 0,
      '10': 'visible',
      '17': true
    },
    {
      '1': 'mode_bits',
      '3': 2,
      '4': 1,
      '5': 13,
      '9': 1,
      '10': 'modeBits',
      '17': true
    },
    {
      '1': 'background',
      '3': 3,
      '4': 1,
      '5': 13,
      '9': 2,
      '10': 'background',
      '17': true
    },
    {
      '1': 'foreground',
      '3': 4,
      '4': 1,
      '5': 13,
      '9': 3,
      '10': 'foreground',
      '17': true
    },
    {
      '1': 'custom_key',
      '3': 5,
      '4': 1,
      '5': 9,
      '9': 4,
      '10': 'customKey',
      '17': true
    },
    {'1': 'data', '3': 6, '4': 1, '5': 12, '9': 5, '10': 'data', '17': true},
  ],
  '8': [
    {'1': '_visible'},
    {'1': '_mode_bits'},
    {'1': '_background'},
    {'1': '_foreground'},
    {'1': '_custom_key'},
    {'1': '_data'},
  ],
};

/// Descriptor for `CornerIndicatorConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cornerIndicatorConfigDescriptor = $convert.base64Decode(
    'ChVDb3JuZXJJbmRpY2F0b3JDb25maWcSHQoHdmlzaWJsZRgBIAEoCEgAUgd2aXNpYmxliAEBEi'
    'AKCW1vZGVfYml0cxgCIAEoDUgBUghtb2RlQml0c4gBARIjCgpiYWNrZ3JvdW5kGAMgASgNSAJS'
    'CmJhY2tncm91bmSIAQESIwoKZm9yZWdyb3VuZBgEIAEoDUgDUgpmb3JlZ3JvdW5kiAEBEiIKCm'
    'N1c3RvbV9rZXkYBSABKAlIBFIJY3VzdG9tS2V5iAEBEhcKBGRhdGEYBiABKAxIBVIEZGF0YYgB'
    'AUIKCghfdmlzaWJsZUIMCgpfbW9kZV9iaXRzQg0KC19iYWNrZ3JvdW5kQg0KC19mb3JlZ3JvdW'
    '5kQg0KC19jdXN0b21fa2V5QgcKBV9kYXRh');

@$core.Deprecated('Use indicatorsConfigDescriptor instead')
const IndicatorsConfig$json = {
  '1': 'IndicatorsConfig',
  '2': [
    {
      '1': 'row_start',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.RowIndicatorConfig',
      '10': 'rowStart'
    },
    {
      '1': 'row_end',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.RowIndicatorConfig',
      '10': 'rowEnd'
    },
    {
      '1': 'col_top',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.ColIndicatorConfig',
      '10': 'colTop'
    },
    {
      '1': 'col_bottom',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.ColIndicatorConfig',
      '10': 'colBottom'
    },
    {
      '1': 'corner_top_start',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.CornerIndicatorConfig',
      '10': 'cornerTopStart'
    },
    {
      '1': 'corner_top_end',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.CornerIndicatorConfig',
      '10': 'cornerTopEnd'
    },
    {
      '1': 'corner_bottom_start',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.CornerIndicatorConfig',
      '10': 'cornerBottomStart'
    },
    {
      '1': 'corner_bottom_end',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.CornerIndicatorConfig',
      '10': 'cornerBottomEnd'
    },
  ],
};

/// Descriptor for `IndicatorsConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List indicatorsConfigDescriptor = $convert.base64Decode(
    'ChBJbmRpY2F0b3JzQ29uZmlnEj4KCXJvd19zdGFydBgBIAEoCzIhLnZvbHZveGdyaWQudjEuUm'
    '93SW5kaWNhdG9yQ29uZmlnUghyb3dTdGFydBI6Cgdyb3dfZW5kGAIgASgLMiEudm9sdm94Z3Jp'
    'ZC52MS5Sb3dJbmRpY2F0b3JDb25maWdSBnJvd0VuZBI6Cgdjb2xfdG9wGAMgASgLMiEudm9sdm'
    '94Z3JpZC52MS5Db2xJbmRpY2F0b3JDb25maWdSBmNvbFRvcBJACgpjb2xfYm90dG9tGAQgASgL'
    'MiEudm9sdm94Z3JpZC52MS5Db2xJbmRpY2F0b3JDb25maWdSCWNvbEJvdHRvbRJOChBjb3JuZX'
    'JfdG9wX3N0YXJ0GAUgASgLMiQudm9sdm94Z3JpZC52MS5Db3JuZXJJbmRpY2F0b3JDb25maWdS'
    'DmNvcm5lclRvcFN0YXJ0EkoKDmNvcm5lcl90b3BfZW5kGAYgASgLMiQudm9sdm94Z3JpZC52MS'
    '5Db3JuZXJJbmRpY2F0b3JDb25maWdSDGNvcm5lclRvcEVuZBJUChNjb3JuZXJfYm90dG9tX3N0'
    'YXJ0GAcgASgLMiQudm9sdm94Z3JpZC52MS5Db3JuZXJJbmRpY2F0b3JDb25maWdSEWNvcm5lck'
    'JvdHRvbVN0YXJ0ElAKEWNvcm5lcl9ib3R0b21fZW5kGAggASgLMiQudm9sdm94Z3JpZC52MS5D'
    'b3JuZXJJbmRpY2F0b3JDb25maWdSD2Nvcm5lckJvdHRvbUVuZA==');

@$core.Deprecated('Use columnDefDescriptor instead')
const ColumnDef$json = {
  '1': 'ColumnDef',
  '2': [
    {'1': 'index', '3': 1, '4': 1, '5': 5, '10': 'index'},
    {'1': 'width', '3': 2, '4': 1, '5': 5, '9': 0, '10': 'width', '17': true},
    {
      '1': 'min_width',
      '3': 3,
      '4': 1,
      '5': 5,
      '9': 1,
      '10': 'minWidth',
      '17': true
    },
    {
      '1': 'max_width',
      '3': 4,
      '4': 1,
      '5': 5,
      '9': 2,
      '10': 'maxWidth',
      '17': true
    },
    {
      '1': 'caption',
      '3': 5,
      '4': 1,
      '5': 9,
      '9': 3,
      '10': 'caption',
      '17': true
    },
    {
      '1': 'align',
      '3': 6,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.Align',
      '9': 4,
      '10': 'align',
      '17': true
    },
    {
      '1': 'fixed_align',
      '3': 7,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.Align',
      '9': 5,
      '10': 'fixedAlign',
      '17': true
    },
    {
      '1': 'data_type',
      '3': 8,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.ColumnDataType',
      '9': 6,
      '10': 'dataType',
      '17': true
    },
    {'1': 'format', '3': 9, '4': 1, '5': 9, '9': 7, '10': 'format', '17': true},
    {'1': 'key', '3': 10, '4': 1, '5': 9, '9': 8, '10': 'key', '17': true},
    {
      '1': 'sort_order',
      '3': 11,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.SortOrder',
      '9': 9,
      '10': 'sortOrder',
      '17': true
    },
    {
      '1': 'sort_type',
      '3': 12,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.SortType',
      '9': 10,
      '10': 'sortType',
      '17': true
    },
    {
      '1': 'dropdown',
      '3': 13,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.Dropdown',
      '9': 11,
      '10': 'dropdown',
      '17': true
    },
    {
      '1': 'edit_mask',
      '3': 14,
      '4': 1,
      '5': 9,
      '9': 12,
      '10': 'editMask',
      '17': true
    },
    {
      '1': 'indent',
      '3': 15,
      '4': 1,
      '5': 5,
      '9': 13,
      '10': 'indent',
      '17': true
    },
    {
      '1': 'hidden',
      '3': 16,
      '4': 1,
      '5': 8,
      '9': 14,
      '10': 'hidden',
      '17': true
    },
    {'1': 'span', '3': 17, '4': 1, '5': 8, '9': 15, '10': 'span', '17': true},
    {
      '1': 'image_list',
      '3': 18,
      '4': 3,
      '5': 11,
      '6': '.volvoxgrid.v1.ImageData',
      '10': 'imageList'
    },
    {'1': 'data', '3': 19, '4': 1, '5': 12, '9': 16, '10': 'data', '17': true},
    {
      '1': 'sticky',
      '3': 20,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.StickyEdge',
      '9': 17,
      '10': 'sticky',
      '17': true
    },
    {
      '1': 'padding',
      '3': 21,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.Padding',
      '10': 'padding'
    },
    {
      '1': 'fixed_padding',
      '3': 22,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.Padding',
      '10': 'fixedPadding'
    },
    {
      '1': 'nullable',
      '3': 23,
      '4': 1,
      '5': 8,
      '9': 18,
      '10': 'nullable',
      '17': true
    },
    {
      '1': 'coercion_mode',
      '3': 24,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.CoercionMode',
      '9': 19,
      '10': 'coercionMode',
      '17': true
    },
    {
      '1': 'error_mode',
      '3': 25,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.WriteErrorMode',
      '9': 20,
      '10': 'errorMode',
      '17': true
    },
    {
      '1': 'interaction',
      '3': 26,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.CellInteraction',
      '9': 21,
      '10': 'interaction',
      '17': true
    },
    {
      '1': 'progress_color',
      '3': 27,
      '4': 1,
      '5': 13,
      '9': 22,
      '10': 'progressColor',
      '17': true
    },
  ],
  '8': [
    {'1': '_width'},
    {'1': '_min_width'},
    {'1': '_max_width'},
    {'1': '_caption'},
    {'1': '_align'},
    {'1': '_fixed_align'},
    {'1': '_data_type'},
    {'1': '_format'},
    {'1': '_key'},
    {'1': '_sort_order'},
    {'1': '_sort_type'},
    {'1': '_dropdown'},
    {'1': '_edit_mask'},
    {'1': '_indent'},
    {'1': '_hidden'},
    {'1': '_span'},
    {'1': '_data'},
    {'1': '_sticky'},
    {'1': '_nullable'},
    {'1': '_coercion_mode'},
    {'1': '_error_mode'},
    {'1': '_interaction'},
    {'1': '_progress_color'},
  ],
};

/// Descriptor for `ColumnDef`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List columnDefDescriptor = $convert.base64Decode(
    'CglDb2x1bW5EZWYSFAoFaW5kZXgYASABKAVSBWluZGV4EhkKBXdpZHRoGAIgASgFSABSBXdpZH'
    'RoiAEBEiAKCW1pbl93aWR0aBgDIAEoBUgBUghtaW5XaWR0aIgBARIgCgltYXhfd2lkdGgYBCAB'
    'KAVIAlIIbWF4V2lkdGiIAQESHQoHY2FwdGlvbhgFIAEoCUgDUgdjYXB0aW9uiAEBEi8KBWFsaW'
    'duGAYgASgOMhQudm9sdm94Z3JpZC52MS5BbGlnbkgEUgVhbGlnbogBARI6CgtmaXhlZF9hbGln'
    'bhgHIAEoDjIULnZvbHZveGdyaWQudjEuQWxpZ25IBVIKZml4ZWRBbGlnbogBARI/CglkYXRhX3'
    'R5cGUYCCABKA4yHS52b2x2b3hncmlkLnYxLkNvbHVtbkRhdGFUeXBlSAZSCGRhdGFUeXBliAEB'
    'EhsKBmZvcm1hdBgJIAEoCUgHUgZmb3JtYXSIAQESFQoDa2V5GAogASgJSAhSA2tleYgBARI8Cg'
    'pzb3J0X29yZGVyGAsgASgOMhgudm9sdm94Z3JpZC52MS5Tb3J0T3JkZXJICVIJc29ydE9yZGVy'
    'iAEBEjkKCXNvcnRfdHlwZRgMIAEoDjIXLnZvbHZveGdyaWQudjEuU29ydFR5cGVIClIIc29ydF'
    'R5cGWIAQESOAoIZHJvcGRvd24YDSABKAsyFy52b2x2b3hncmlkLnYxLkRyb3Bkb3duSAtSCGRy'
    'b3Bkb3duiAEBEiAKCWVkaXRfbWFzaxgOIAEoCUgMUghlZGl0TWFza4gBARIbCgZpbmRlbnQYDy'
    'ABKAVIDVIGaW5kZW50iAEBEhsKBmhpZGRlbhgQIAEoCEgOUgZoaWRkZW6IAQESFwoEc3BhbhgR'
    'IAEoCEgPUgRzcGFuiAEBEjcKCmltYWdlX2xpc3QYEiADKAsyGC52b2x2b3hncmlkLnYxLkltYW'
    'dlRGF0YVIJaW1hZ2VMaXN0EhcKBGRhdGEYEyABKAxIEFIEZGF0YYgBARI2CgZzdGlja3kYFCAB'
    'KA4yGS52b2x2b3hncmlkLnYxLlN0aWNreUVkZ2VIEVIGc3RpY2t5iAEBEjAKB3BhZGRpbmcYFS'
    'ABKAsyFi52b2x2b3hncmlkLnYxLlBhZGRpbmdSB3BhZGRpbmcSOwoNZml4ZWRfcGFkZGluZxgW'
    'IAEoCzIWLnZvbHZveGdyaWQudjEuUGFkZGluZ1IMZml4ZWRQYWRkaW5nEh8KCG51bGxhYmxlGB'
    'cgASgISBJSCG51bGxhYmxliAEBEkUKDWNvZXJjaW9uX21vZGUYGCABKA4yGy52b2x2b3hncmlk'
    'LnYxLkNvZXJjaW9uTW9kZUgTUgxjb2VyY2lvbk1vZGWIAQESQQoKZXJyb3JfbW9kZRgZIAEoDj'
    'IdLnZvbHZveGdyaWQudjEuV3JpdGVFcnJvck1vZGVIFFIJZXJyb3JNb2RliAEBEkUKC2ludGVy'
    'YWN0aW9uGBogASgOMh4udm9sdm94Z3JpZC52MS5DZWxsSW50ZXJhY3Rpb25IFVILaW50ZXJhY3'
    'Rpb26IAQESKgoOcHJvZ3Jlc3NfY29sb3IYGyABKA1IFlINcHJvZ3Jlc3NDb2xvcogBAUIICgZf'
    'd2lkdGhCDAoKX21pbl93aWR0aEIMCgpfbWF4X3dpZHRoQgoKCF9jYXB0aW9uQggKBl9hbGlnbk'
    'IOCgxfZml4ZWRfYWxpZ25CDAoKX2RhdGFfdHlwZUIJCgdfZm9ybWF0QgYKBF9rZXlCDQoLX3Nv'
    'cnRfb3JkZXJCDAoKX3NvcnRfdHlwZUILCglfZHJvcGRvd25CDAoKX2VkaXRfbWFza0IJCgdfaW'
    '5kZW50QgkKB19oaWRkZW5CBwoFX3NwYW5CBwoFX2RhdGFCCQoHX3N0aWNreUILCglfbnVsbGFi'
    'bGVCEAoOX2NvZXJjaW9uX21vZGVCDQoLX2Vycm9yX21vZGVCDgoMX2ludGVyYWN0aW9uQhEKD1'
    '9wcm9ncmVzc19jb2xvcg==');

@$core.Deprecated('Use defineColumnsRequestDescriptor instead')
const DefineColumnsRequest$json = {
  '1': 'DefineColumnsRequest',
  '2': [
    {'1': 'grid_id', '3': 1, '4': 1, '5': 3, '10': 'gridId'},
    {
      '1': 'columns',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.volvoxgrid.v1.ColumnDef',
      '10': 'columns'
    },
  ],
};

/// Descriptor for `DefineColumnsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List defineColumnsRequestDescriptor = $convert.base64Decode(
    'ChREZWZpbmVDb2x1bW5zUmVxdWVzdBIXCgdncmlkX2lkGAEgASgDUgZncmlkSWQSMgoHY29sdW'
    '1ucxgCIAMoCzIYLnZvbHZveGdyaWQudjEuQ29sdW1uRGVmUgdjb2x1bW5z');

@$core.Deprecated('Use schemaResponseDescriptor instead')
const SchemaResponse$json = {
  '1': 'SchemaResponse',
  '2': [
    {
      '1': 'columns',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.volvoxgrid.v1.ColumnDef',
      '10': 'columns'
    },
  ],
};

/// Descriptor for `SchemaResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List schemaResponseDescriptor = $convert.base64Decode(
    'Cg5TY2hlbWFSZXNwb25zZRIyCgdjb2x1bW5zGAEgAygLMhgudm9sdm94Z3JpZC52MS5Db2x1bW'
    '5EZWZSB2NvbHVtbnM=');

@$core.Deprecated('Use rowDefDescriptor instead')
const RowDef$json = {
  '1': 'RowDef',
  '2': [
    {'1': 'index', '3': 1, '4': 1, '5': 5, '10': 'index'},
    {'1': 'height', '3': 2, '4': 1, '5': 5, '9': 0, '10': 'height', '17': true},
    {'1': 'hidden', '3': 3, '4': 1, '5': 8, '9': 1, '10': 'hidden', '17': true},
    {
      '1': 'is_subtotal',
      '3': 4,
      '4': 1,
      '5': 8,
      '9': 2,
      '10': 'isSubtotal',
      '17': true
    },
    {
      '1': 'outline_level',
      '3': 5,
      '4': 1,
      '5': 5,
      '9': 3,
      '10': 'outlineLevel',
      '17': true
    },
    {
      '1': 'is_collapsed',
      '3': 6,
      '4': 1,
      '5': 8,
      '9': 4,
      '10': 'isCollapsed',
      '17': true
    },
    {'1': 'data', '3': 7, '4': 1, '5': 12, '9': 5, '10': 'data', '17': true},
    {
      '1': 'status',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.RowStatus',
      '10': 'status'
    },
    {'1': 'span', '3': 9, '4': 1, '5': 8, '9': 6, '10': 'span', '17': true},
    {
      '1': 'pin',
      '3': 10,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.PinPosition',
      '9': 7,
      '10': 'pin',
      '17': true
    },
    {
      '1': 'sticky',
      '3': 11,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.StickyEdge',
      '9': 8,
      '10': 'sticky',
      '17': true
    },
  ],
  '8': [
    {'1': '_height'},
    {'1': '_hidden'},
    {'1': '_is_subtotal'},
    {'1': '_outline_level'},
    {'1': '_is_collapsed'},
    {'1': '_data'},
    {'1': '_span'},
    {'1': '_pin'},
    {'1': '_sticky'},
  ],
};

/// Descriptor for `RowDef`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List rowDefDescriptor = $convert.base64Decode(
    'CgZSb3dEZWYSFAoFaW5kZXgYASABKAVSBWluZGV4EhsKBmhlaWdodBgCIAEoBUgAUgZoZWlnaH'
    'SIAQESGwoGaGlkZGVuGAMgASgISAFSBmhpZGRlbogBARIkCgtpc19zdWJ0b3RhbBgEIAEoCEgC'
    'Ugppc1N1YnRvdGFsiAEBEigKDW91dGxpbmVfbGV2ZWwYBSABKAVIA1IMb3V0bGluZUxldmVsiA'
    'EBEiYKDGlzX2NvbGxhcHNlZBgGIAEoCEgEUgtpc0NvbGxhcHNlZIgBARIXCgRkYXRhGAcgASgM'
    'SAVSBGRhdGGIAQESMAoGc3RhdHVzGAggASgLMhgudm9sdm94Z3JpZC52MS5Sb3dTdGF0dXNSBn'
    'N0YXR1cxIXCgRzcGFuGAkgASgISAZSBHNwYW6IAQESMQoDcGluGAogASgOMhoudm9sdm94Z3Jp'
    'ZC52MS5QaW5Qb3NpdGlvbkgHUgNwaW6IAQESNgoGc3RpY2t5GAsgASgOMhkudm9sdm94Z3JpZC'
    '52MS5TdGlja3lFZGdlSAhSBnN0aWNreYgBAUIJCgdfaGVpZ2h0QgkKB19oaWRkZW5CDgoMX2lz'
    'X3N1YnRvdGFsQhAKDl9vdXRsaW5lX2xldmVsQg8KDV9pc19jb2xsYXBzZWRCBwoFX2RhdGFCBw'
    'oFX3NwYW5CBgoEX3BpbkIJCgdfc3RpY2t5');

@$core.Deprecated('Use rowStatusDescriptor instead')
const RowStatus$json = {
  '1': 'RowStatus',
  '2': [
    {'1': 'domain', '3': 1, '4': 1, '5': 9, '10': 'domain'},
    {'1': 'code', '3': 2, '4': 1, '5': 5, '10': 'code'},
  ],
};

/// Descriptor for `RowStatus`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List rowStatusDescriptor = $convert.base64Decode(
    'CglSb3dTdGF0dXMSFgoGZG9tYWluGAEgASgJUgZkb21haW4SEgoEY29kZRgCIAEoBVIEY29kZQ'
    '==');

@$core.Deprecated('Use defineRowsRequestDescriptor instead')
const DefineRowsRequest$json = {
  '1': 'DefineRowsRequest',
  '2': [
    {'1': 'grid_id', '3': 1, '4': 1, '5': 3, '10': 'gridId'},
    {
      '1': 'rows',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.volvoxgrid.v1.RowDef',
      '10': 'rows'
    },
  ],
};

/// Descriptor for `DefineRowsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List defineRowsRequestDescriptor = $convert.base64Decode(
    'ChFEZWZpbmVSb3dzUmVxdWVzdBIXCgdncmlkX2lkGAEgASgDUgZncmlkSWQSKQoEcm93cxgCIA'
    'MoCzIVLnZvbHZveGdyaWQudjEuUm93RGVmUgRyb3dz');

@$core.Deprecated('Use cellUpdateDescriptor instead')
const CellUpdate$json = {
  '1': 'CellUpdate',
  '2': [
    {'1': 'row', '3': 1, '4': 1, '5': 5, '10': 'row'},
    {'1': 'col', '3': 2, '4': 1, '5': 5, '10': 'col'},
    {
      '1': 'value',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.CellValue',
      '10': 'value'
    },
    {
      '1': 'style',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.CellStyle',
      '10': 'style'
    },
    {
      '1': 'checked',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.CheckedState',
      '9': 0,
      '10': 'checked',
      '17': true
    },
    {
      '1': 'picture',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.ImageData',
      '10': 'picture'
    },
    {
      '1': 'picture_align',
      '3': 7,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.ImageAlignment',
      '9': 1,
      '10': 'pictureAlign',
      '17': true
    },
    {
      '1': 'button_picture',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.ImageData',
      '10': 'buttonPicture'
    },
    {
      '1': 'dropdown',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.Dropdown',
      '9': 2,
      '10': 'dropdown',
      '17': true
    },
    {
      '1': 'sticky_row',
      '3': 10,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.StickyEdge',
      '9': 3,
      '10': 'stickyRow',
      '17': true
    },
    {
      '1': 'sticky_col',
      '3': 11,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.StickyEdge',
      '9': 4,
      '10': 'stickyCol',
      '17': true
    },
    {
      '1': 'interaction',
      '3': 12,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.CellInteraction',
      '9': 5,
      '10': 'interaction',
      '17': true
    },
    {
      '1': 'barcode',
      '3': 13,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.BarcodeData',
      '9': 6,
      '10': 'barcode',
      '17': true
    },
  ],
  '8': [
    {'1': '_checked'},
    {'1': '_picture_align'},
    {'1': '_dropdown'},
    {'1': '_sticky_row'},
    {'1': '_sticky_col'},
    {'1': '_interaction'},
    {'1': '_barcode'},
  ],
};

/// Descriptor for `CellUpdate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cellUpdateDescriptor = $convert.base64Decode(
    'CgpDZWxsVXBkYXRlEhAKA3JvdxgBIAEoBVIDcm93EhAKA2NvbBgCIAEoBVIDY29sEi4KBXZhbH'
    'VlGAMgASgLMhgudm9sdm94Z3JpZC52MS5DZWxsVmFsdWVSBXZhbHVlEi4KBXN0eWxlGAQgASgL'
    'Mhgudm9sdm94Z3JpZC52MS5DZWxsU3R5bGVSBXN0eWxlEjoKB2NoZWNrZWQYBSABKA4yGy52b2'
    'x2b3hncmlkLnYxLkNoZWNrZWRTdGF0ZUgAUgdjaGVja2VkiAEBEjIKB3BpY3R1cmUYBiABKAsy'
    'GC52b2x2b3hncmlkLnYxLkltYWdlRGF0YVIHcGljdHVyZRJHCg1waWN0dXJlX2FsaWduGAcgAS'
    'gOMh0udm9sdm94Z3JpZC52MS5JbWFnZUFsaWdubWVudEgBUgxwaWN0dXJlQWxpZ26IAQESPwoO'
    'YnV0dG9uX3BpY3R1cmUYCCABKAsyGC52b2x2b3hncmlkLnYxLkltYWdlRGF0YVINYnV0dG9uUG'
    'ljdHVyZRI4Cghkcm9wZG93bhgJIAEoCzIXLnZvbHZveGdyaWQudjEuRHJvcGRvd25IAlIIZHJv'
    'cGRvd26IAQESPQoKc3RpY2t5X3JvdxgKIAEoDjIZLnZvbHZveGdyaWQudjEuU3RpY2t5RWRnZU'
    'gDUglzdGlja3lSb3eIAQESPQoKc3RpY2t5X2NvbBgLIAEoDjIZLnZvbHZveGdyaWQudjEuU3Rp'
    'Y2t5RWRnZUgEUglzdGlja3lDb2yIAQESRQoLaW50ZXJhY3Rpb24YDCABKA4yHi52b2x2b3hncm'
    'lkLnYxLkNlbGxJbnRlcmFjdGlvbkgFUgtpbnRlcmFjdGlvbogBARI5CgdiYXJjb2RlGA0gASgL'
    'Mhoudm9sdm94Z3JpZC52MS5CYXJjb2RlRGF0YUgGUgdiYXJjb2RliAEBQgoKCF9jaGVja2VkQh'
    'AKDl9waWN0dXJlX2FsaWduQgsKCV9kcm9wZG93bkINCgtfc3RpY2t5X3Jvd0INCgtfc3RpY2t5'
    'X2NvbEIOCgxfaW50ZXJhY3Rpb25CCgoIX2JhcmNvZGU=');

@$core.Deprecated('Use updateCellsRequestDescriptor instead')
const UpdateCellsRequest$json = {
  '1': 'UpdateCellsRequest',
  '2': [
    {'1': 'grid_id', '3': 1, '4': 1, '5': 3, '10': 'gridId'},
    {
      '1': 'cells',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.volvoxgrid.v1.CellUpdate',
      '10': 'cells'
    },
    {'1': 'atomic', '3': 3, '4': 1, '5': 8, '10': 'atomic'},
  ],
};

/// Descriptor for `UpdateCellsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateCellsRequestDescriptor = $convert.base64Decode(
    'ChJVcGRhdGVDZWxsc1JlcXVlc3QSFwoHZ3JpZF9pZBgBIAEoA1IGZ3JpZElkEi8KBWNlbGxzGA'
    'IgAygLMhkudm9sdm94Z3JpZC52MS5DZWxsVXBkYXRlUgVjZWxscxIWCgZhdG9taWMYAyABKAhS'
    'BmF0b21pYw==');

@$core.Deprecated('Use getCellsRequestDescriptor instead')
const GetCellsRequest$json = {
  '1': 'GetCellsRequest',
  '2': [
    {'1': 'grid_id', '3': 1, '4': 1, '5': 3, '10': 'gridId'},
    {'1': 'row1', '3': 2, '4': 1, '5': 5, '10': 'row1'},
    {'1': 'col1', '3': 3, '4': 1, '5': 5, '10': 'col1'},
    {'1': 'row2', '3': 4, '4': 1, '5': 5, '10': 'row2'},
    {'1': 'col2', '3': 5, '4': 1, '5': 5, '10': 'col2'},
    {'1': 'include_style', '3': 6, '4': 1, '5': 8, '10': 'includeStyle'},
    {'1': 'include_checked', '3': 7, '4': 1, '5': 8, '10': 'includeChecked'},
    {'1': 'include_typed', '3': 8, '4': 1, '5': 8, '10': 'includeTyped'},
    {
      '1': 'include_barcode_status',
      '3': 9,
      '4': 1,
      '5': 8,
      '10': 'includeBarcodeStatus'
    },
  ],
};

/// Descriptor for `GetCellsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getCellsRequestDescriptor = $convert.base64Decode(
    'Cg9HZXRDZWxsc1JlcXVlc3QSFwoHZ3JpZF9pZBgBIAEoA1IGZ3JpZElkEhIKBHJvdzEYAiABKA'
    'VSBHJvdzESEgoEY29sMRgDIAEoBVIEY29sMRISCgRyb3cyGAQgASgFUgRyb3cyEhIKBGNvbDIY'
    'BSABKAVSBGNvbDISIwoNaW5jbHVkZV9zdHlsZRgGIAEoCFIMaW5jbHVkZVN0eWxlEicKD2luY2'
    'x1ZGVfY2hlY2tlZBgHIAEoCFIOaW5jbHVkZUNoZWNrZWQSIwoNaW5jbHVkZV90eXBlZBgIIAEo'
    'CFIMaW5jbHVkZVR5cGVkEjQKFmluY2x1ZGVfYmFyY29kZV9zdGF0dXMYCSABKAhSFGluY2x1ZG'
    'VCYXJjb2RlU3RhdHVz');

@$core.Deprecated('Use cellDataDescriptor instead')
const CellData$json = {
  '1': 'CellData',
  '2': [
    {'1': 'row', '3': 1, '4': 1, '5': 5, '10': 'row'},
    {'1': 'col', '3': 2, '4': 1, '5': 5, '10': 'col'},
    {
      '1': 'value',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.CellValue',
      '10': 'value'
    },
    {
      '1': 'style',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.CellStyle',
      '10': 'style'
    },
    {
      '1': 'checked',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.CheckedState',
      '10': 'checked'
    },
    {
      '1': 'interaction',
      '3': 6,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.CellInteraction',
      '9': 0,
      '10': 'interaction',
      '17': true
    },
    {
      '1': 'barcode',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.BarcodeData',
      '9': 1,
      '10': 'barcode',
      '17': true
    },
    {
      '1': 'barcode_status',
      '3': 8,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.BarcodeRenderStatus',
      '9': 2,
      '10': 'barcodeStatus',
      '17': true
    },
  ],
  '8': [
    {'1': '_interaction'},
    {'1': '_barcode'},
    {'1': '_barcode_status'},
  ],
};

/// Descriptor for `CellData`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cellDataDescriptor = $convert.base64Decode(
    'CghDZWxsRGF0YRIQCgNyb3cYASABKAVSA3JvdxIQCgNjb2wYAiABKAVSA2NvbBIuCgV2YWx1ZR'
    'gDIAEoCzIYLnZvbHZveGdyaWQudjEuQ2VsbFZhbHVlUgV2YWx1ZRIuCgVzdHlsZRgEIAEoCzIY'
    'LnZvbHZveGdyaWQudjEuQ2VsbFN0eWxlUgVzdHlsZRI1CgdjaGVja2VkGAUgASgOMhsudm9sdm'
    '94Z3JpZC52MS5DaGVja2VkU3RhdGVSB2NoZWNrZWQSRQoLaW50ZXJhY3Rpb24YBiABKA4yHi52'
    'b2x2b3hncmlkLnYxLkNlbGxJbnRlcmFjdGlvbkgAUgtpbnRlcmFjdGlvbogBARI5CgdiYXJjb2'
    'RlGAcgASgLMhoudm9sdm94Z3JpZC52MS5CYXJjb2RlRGF0YUgBUgdiYXJjb2RliAEBEk4KDmJh'
    'cmNvZGVfc3RhdHVzGAggASgOMiIudm9sdm94Z3JpZC52MS5CYXJjb2RlUmVuZGVyU3RhdHVzSA'
    'JSDWJhcmNvZGVTdGF0dXOIAQFCDgoMX2ludGVyYWN0aW9uQgoKCF9iYXJjb2RlQhEKD19iYXJj'
    'b2RlX3N0YXR1cw==');

@$core.Deprecated('Use cellsResponseDescriptor instead')
const CellsResponse$json = {
  '1': 'CellsResponse',
  '2': [
    {
      '1': 'cells',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.volvoxgrid.v1.CellData',
      '10': 'cells'
    },
  ],
};

/// Descriptor for `CellsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cellsResponseDescriptor = $convert.base64Decode(
    'Cg1DZWxsc1Jlc3BvbnNlEi0KBWNlbGxzGAEgAygLMhcudm9sdm94Z3JpZC52MS5DZWxsRGF0YV'
    'IFY2VsbHM=');

@$core.Deprecated('Use typeViolationDescriptor instead')
const TypeViolation$json = {
  '1': 'TypeViolation',
  '2': [
    {'1': 'row', '3': 1, '4': 1, '5': 5, '10': 'row'},
    {'1': 'col', '3': 2, '4': 1, '5': 5, '10': 'col'},
    {
      '1': 'expected',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.ColumnDataType',
      '10': 'expected'
    },
    {
      '1': 'actual',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.CellValue',
      '10': 'actual'
    },
    {'1': 'reason', '3': 5, '4': 1, '5': 9, '10': 'reason'},
  ],
};

/// Descriptor for `TypeViolation`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List typeViolationDescriptor = $convert.base64Decode(
    'Cg1UeXBlVmlvbGF0aW9uEhAKA3JvdxgBIAEoBVIDcm93EhAKA2NvbBgCIAEoBVIDY29sEjkKCG'
    'V4cGVjdGVkGAMgASgOMh0udm9sdm94Z3JpZC52MS5Db2x1bW5EYXRhVHlwZVIIZXhwZWN0ZWQS'
    'MAoGYWN0dWFsGAQgASgLMhgudm9sdm94Z3JpZC52MS5DZWxsVmFsdWVSBmFjdHVhbBIWCgZyZW'
    'Fzb24YBSABKAlSBnJlYXNvbg==');

@$core.Deprecated('Use writeResultDescriptor instead')
const WriteResult$json = {
  '1': 'WriteResult',
  '2': [
    {'1': 'written_count', '3': 1, '4': 1, '5': 5, '10': 'writtenCount'},
    {'1': 'rejected_count', '3': 2, '4': 1, '5': 5, '10': 'rejectedCount'},
    {
      '1': 'violations',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.volvoxgrid.v1.TypeViolation',
      '10': 'violations'
    },
  ],
};

/// Descriptor for `WriteResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List writeResultDescriptor = $convert.base64Decode(
    'CgtXcml0ZVJlc3VsdBIjCg13cml0dGVuX2NvdW50GAEgASgFUgx3cml0dGVuQ291bnQSJQoOcm'
    'VqZWN0ZWRfY291bnQYAiABKAVSDXJlamVjdGVkQ291bnQSPAoKdmlvbGF0aW9ucxgDIAMoCzIc'
    'LnZvbHZveGdyaWQudjEuVHlwZVZpb2xhdGlvblIKdmlvbGF0aW9ucw==');

@$core.Deprecated('Use loadTableRequestDescriptor instead')
const LoadTableRequest$json = {
  '1': 'LoadTableRequest',
  '2': [
    {'1': 'grid_id', '3': 1, '4': 1, '5': 3, '10': 'gridId'},
    {'1': 'rows', '3': 2, '4': 1, '5': 5, '10': 'rows'},
    {'1': 'cols', '3': 3, '4': 1, '5': 5, '10': 'cols'},
    {
      '1': 'values',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.volvoxgrid.v1.CellValue',
      '10': 'values'
    },
    {'1': 'atomic', '3': 5, '4': 1, '5': 8, '10': 'atomic'},
  ],
};

/// Descriptor for `LoadTableRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List loadTableRequestDescriptor = $convert.base64Decode(
    'ChBMb2FkVGFibGVSZXF1ZXN0EhcKB2dyaWRfaWQYASABKANSBmdyaWRJZBISCgRyb3dzGAIgAS'
    'gFUgRyb3dzEhIKBGNvbHMYAyABKAVSBGNvbHMSMAoGdmFsdWVzGAQgAygLMhgudm9sdm94Z3Jp'
    'ZC52MS5DZWxsVmFsdWVSBnZhbHVlcxIWCgZhdG9taWMYBSABKAhSBmF0b21pYw==');

@$core.Deprecated('Use fieldMappingDescriptor instead')
const FieldMapping$json = {
  '1': 'FieldMapping',
  '2': [
    {'1': 'field', '3': 1, '4': 1, '5': 9, '10': 'field'},
    {'1': 'col_index', '3': 2, '4': 1, '5': 5, '9': 0, '10': 'colIndex'},
    {'1': 'col_key', '3': 3, '4': 1, '5': 9, '9': 0, '10': 'colKey'},
  ],
  '8': [
    {'1': 'target'},
  ],
};

/// Descriptor for `FieldMapping`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List fieldMappingDescriptor = $convert.base64Decode(
    'CgxGaWVsZE1hcHBpbmcSFAoFZmllbGQYASABKAlSBWZpZWxkEh0KCWNvbF9pbmRleBgCIAEoBU'
    'gAUghjb2xJbmRleBIZCgdjb2xfa2V5GAMgASgJSABSBmNvbEtleUIICgZ0YXJnZXQ=');

@$core.Deprecated('Use csvOptionsDescriptor instead')
const CsvOptions$json = {
  '1': 'CsvOptions',
  '2': [
    {
      '1': 'delimiter',
      '3': 1,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'delimiter',
      '17': true
    },
    {
      '1': 'quote_char',
      '3': 2,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'quoteChar',
      '17': true
    },
    {
      '1': 'trim_whitespace',
      '3': 3,
      '4': 1,
      '5': 8,
      '9': 2,
      '10': 'trimWhitespace',
      '17': true
    },
  ],
  '8': [
    {'1': '_delimiter'},
    {'1': '_quote_char'},
    {'1': '_trim_whitespace'},
  ],
};

/// Descriptor for `CsvOptions`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List csvOptionsDescriptor = $convert.base64Decode(
    'CgpDc3ZPcHRpb25zEiEKCWRlbGltaXRlchgBIAEoCUgAUglkZWxpbWl0ZXKIAQESIgoKcXVvdG'
    'VfY2hhchgCIAEoCUgBUglxdW90ZUNoYXKIAQESLAoPdHJpbV93aGl0ZXNwYWNlGAMgASgISAJS'
    'DnRyaW1XaGl0ZXNwYWNliAEBQgwKCl9kZWxpbWl0ZXJCDQoLX3F1b3RlX2NoYXJCEgoQX3RyaW'
    '1fd2hpdGVzcGFjZQ==');

@$core.Deprecated('Use jsonOptionsDescriptor instead')
const JsonOptions$json = {
  '1': 'JsonOptions',
  '2': [
    {
      '1': 'data_path',
      '3': 1,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'dataPath',
      '17': true
    },
  ],
  '8': [
    {'1': '_data_path'},
  ],
};

/// Descriptor for `JsonOptions`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List jsonOptionsDescriptor = $convert.base64Decode(
    'CgtKc29uT3B0aW9ucxIgCglkYXRhX3BhdGgYASABKAlIAFIIZGF0YVBhdGiIAQFCDAoKX2RhdG'
    'FfcGF0aA==');

@$core.Deprecated('Use loadDataOptionsDescriptor instead')
const LoadDataOptions$json = {
  '1': 'LoadDataOptions',
  '2': [
    {
      '1': 'csv',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.CsvOptions',
      '9': 0,
      '10': 'csv'
    },
    {
      '1': 'json',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.JsonOptions',
      '9': 0,
      '10': 'json'
    },
    {
      '1': 'header_policy',
      '3': 10,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.HeaderPolicy',
      '9': 1,
      '10': 'headerPolicy',
      '17': true
    },
    {
      '1': 'field_map',
      '3': 11,
      '4': 3,
      '5': 11,
      '6': '.volvoxgrid.v1.FieldMapping',
      '10': 'fieldMap'
    },
    {
      '1': 'type_policy',
      '3': 12,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.TypePolicy',
      '9': 2,
      '10': 'typePolicy',
      '17': true
    },
    {
      '1': 'coercion',
      '3': 13,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.CoercionMode',
      '9': 3,
      '10': 'coercion',
      '17': true
    },
    {
      '1': 'error_mode',
      '3': 14,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.WriteErrorMode',
      '9': 4,
      '10': 'errorMode',
      '17': true
    },
    {
      '1': 'date_format',
      '3': 15,
      '4': 1,
      '5': 9,
      '9': 5,
      '10': 'dateFormat',
      '17': true
    },
    {
      '1': 'decimal_char',
      '3': 16,
      '4': 1,
      '5': 9,
      '9': 6,
      '10': 'decimalChar',
      '17': true
    },
    {
      '1': 'auto_create_columns',
      '3': 17,
      '4': 1,
      '5': 8,
      '9': 7,
      '10': 'autoCreateColumns',
      '17': true
    },
    {
      '1': 'mode',
      '3': 18,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.LoadMode',
      '9': 8,
      '10': 'mode',
      '17': true
    },
    {
      '1': 'atomic',
      '3': 19,
      '4': 1,
      '5': 8,
      '9': 9,
      '10': 'atomic',
      '17': true
    },
    {
      '1': 'skip_rows',
      '3': 20,
      '4': 1,
      '5': 5,
      '9': 10,
      '10': 'skipRows',
      '17': true
    },
    {
      '1': 'max_rows',
      '3': 21,
      '4': 1,
      '5': 5,
      '9': 11,
      '10': 'maxRows',
      '17': true
    },
  ],
  '8': [
    {'1': 'format'},
    {'1': '_header_policy'},
    {'1': '_type_policy'},
    {'1': '_coercion'},
    {'1': '_error_mode'},
    {'1': '_date_format'},
    {'1': '_decimal_char'},
    {'1': '_auto_create_columns'},
    {'1': '_mode'},
    {'1': '_atomic'},
    {'1': '_skip_rows'},
    {'1': '_max_rows'},
  ],
};

/// Descriptor for `LoadDataOptions`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List loadDataOptionsDescriptor = $convert.base64Decode(
    'Cg9Mb2FkRGF0YU9wdGlvbnMSLQoDY3N2GAEgASgLMhkudm9sdm94Z3JpZC52MS5Dc3ZPcHRpb2'
    '5zSABSA2NzdhIwCgRqc29uGAIgASgLMhoudm9sdm94Z3JpZC52MS5Kc29uT3B0aW9uc0gAUgRq'
    'c29uEkUKDWhlYWRlcl9wb2xpY3kYCiABKA4yGy52b2x2b3hncmlkLnYxLkhlYWRlclBvbGljeU'
    'gBUgxoZWFkZXJQb2xpY3mIAQESOAoJZmllbGRfbWFwGAsgAygLMhsudm9sdm94Z3JpZC52MS5G'
    'aWVsZE1hcHBpbmdSCGZpZWxkTWFwEj8KC3R5cGVfcG9saWN5GAwgASgOMhkudm9sdm94Z3JpZC'
    '52MS5UeXBlUG9saWN5SAJSCnR5cGVQb2xpY3mIAQESPAoIY29lcmNpb24YDSABKA4yGy52b2x2'
    'b3hncmlkLnYxLkNvZXJjaW9uTW9kZUgDUghjb2VyY2lvbogBARJBCgplcnJvcl9tb2RlGA4gAS'
    'gOMh0udm9sdm94Z3JpZC52MS5Xcml0ZUVycm9yTW9kZUgEUgllcnJvck1vZGWIAQESJAoLZGF0'
    'ZV9mb3JtYXQYDyABKAlIBVIKZGF0ZUZvcm1hdIgBARImCgxkZWNpbWFsX2NoYXIYECABKAlIBl'
    'ILZGVjaW1hbENoYXKIAQESMwoTYXV0b19jcmVhdGVfY29sdW1ucxgRIAEoCEgHUhFhdXRvQ3Jl'
    'YXRlQ29sdW1uc4gBARIwCgRtb2RlGBIgASgOMhcudm9sdm94Z3JpZC52MS5Mb2FkTW9kZUgIUg'
    'Rtb2RliAEBEhsKBmF0b21pYxgTIAEoCEgJUgZhdG9taWOIAQESIAoJc2tpcF9yb3dzGBQgASgF'
    'SApSCHNraXBSb3dziAEBEh4KCG1heF9yb3dzGBUgASgFSAtSB21heFJvd3OIAQFCCAoGZm9ybW'
    'F0QhAKDl9oZWFkZXJfcG9saWN5Qg4KDF90eXBlX3BvbGljeUILCglfY29lcmNpb25CDQoLX2Vy'
    'cm9yX21vZGVCDgoMX2RhdGVfZm9ybWF0Qg8KDV9kZWNpbWFsX2NoYXJCFgoUX2F1dG9fY3JlYX'
    'RlX2NvbHVtbnNCBwoFX21vZGVCCQoHX2F0b21pY0IMCgpfc2tpcF9yb3dzQgsKCV9tYXhfcm93'
    'cw==');

@$core.Deprecated('Use loadDataRequestDescriptor instead')
const LoadDataRequest$json = {
  '1': 'LoadDataRequest',
  '2': [
    {'1': 'grid_id', '3': 1, '4': 1, '5': 3, '10': 'gridId'},
    {'1': 'data', '3': 2, '4': 1, '5': 12, '10': 'data'},
    {
      '1': 'options',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.LoadDataOptions',
      '9': 0,
      '10': 'options',
      '17': true
    },
  ],
  '8': [
    {'1': '_options'},
  ],
};

/// Descriptor for `LoadDataRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List loadDataRequestDescriptor = $convert.base64Decode(
    'Cg9Mb2FkRGF0YVJlcXVlc3QSFwoHZ3JpZF9pZBgBIAEoA1IGZ3JpZElkEhIKBGRhdGEYAiABKA'
    'xSBGRhdGESPQoHb3B0aW9ucxgDIAEoCzIeLnZvbHZveGdyaWQudjEuTG9hZERhdGFPcHRpb25z'
    'SABSB29wdGlvbnOIAQFCCgoIX29wdGlvbnM=');

@$core.Deprecated('Use loadDataResultDescriptor instead')
const LoadDataResult$json = {
  '1': 'LoadDataResult',
  '2': [
    {
      '1': 'status',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.LoadDataStatus',
      '10': 'status'
    },
    {'1': 'rows', '3': 2, '4': 1, '5': 5, '10': 'rows'},
    {'1': 'cols', '3': 3, '4': 1, '5': 5, '10': 'cols'},
    {'1': 'rejected', '3': 4, '4': 1, '5': 5, '10': 'rejected'},
    {
      '1': 'violations',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.volvoxgrid.v1.TypeViolation',
      '10': 'violations'
    },
    {'1': 'warnings', '3': 6, '4': 3, '5': 9, '10': 'warnings'},
    {
      '1': 'inferred_columns',
      '3': 7,
      '4': 3,
      '5': 11,
      '6': '.volvoxgrid.v1.ColumnDef',
      '10': 'inferredColumns'
    },
  ],
};

/// Descriptor for `LoadDataResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List loadDataResultDescriptor = $convert.base64Decode(
    'Cg5Mb2FkRGF0YVJlc3VsdBI1CgZzdGF0dXMYASABKA4yHS52b2x2b3hncmlkLnYxLkxvYWREYX'
    'RhU3RhdHVzUgZzdGF0dXMSEgoEcm93cxgCIAEoBVIEcm93cxISCgRjb2xzGAMgASgFUgRjb2xz'
    'EhoKCHJlamVjdGVkGAQgASgFUghyZWplY3RlZBI8Cgp2aW9sYXRpb25zGAUgAygLMhwudm9sdm'
    '94Z3JpZC52MS5UeXBlVmlvbGF0aW9uUgp2aW9sYXRpb25zEhoKCHdhcm5pbmdzGAYgAygJUgh3'
    'YXJuaW5ncxJDChBpbmZlcnJlZF9jb2x1bW5zGAcgAygLMhgudm9sdm94Z3JpZC52MS5Db2x1bW'
    '5EZWZSD2luZmVycmVkQ29sdW1ucw==');

@$core.Deprecated('Use clearRequestDescriptor instead')
const ClearRequest$json = {
  '1': 'ClearRequest',
  '2': [
    {'1': 'grid_id', '3': 1, '4': 1, '5': 3, '10': 'gridId'},
    {
      '1': 'scope',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.ClearScope',
      '10': 'scope'
    },
    {
      '1': 'region',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.ClearRegion',
      '10': 'region'
    },
  ],
};

/// Descriptor for `ClearRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List clearRequestDescriptor = $convert.base64Decode(
    'CgxDbGVhclJlcXVlc3QSFwoHZ3JpZF9pZBgBIAEoA1IGZ3JpZElkEi8KBXNjb3BlGAIgASgOMh'
    'kudm9sdm94Z3JpZC52MS5DbGVhclNjb3BlUgVzY29wZRIyCgZyZWdpb24YAyABKA4yGi52b2x2'
    'b3hncmlkLnYxLkNsZWFyUmVnaW9uUgZyZWdpb24=');

@$core.Deprecated('Use insertRowsRequestDescriptor instead')
const InsertRowsRequest$json = {
  '1': 'InsertRowsRequest',
  '2': [
    {'1': 'grid_id', '3': 1, '4': 1, '5': 3, '10': 'gridId'},
    {'1': 'index', '3': 2, '4': 1, '5': 5, '10': 'index'},
    {'1': 'count', '3': 3, '4': 1, '5': 5, '10': 'count'},
    {'1': 'text', '3': 4, '4': 3, '5': 9, '10': 'text'},
  ],
};

/// Descriptor for `InsertRowsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List insertRowsRequestDescriptor = $convert.base64Decode(
    'ChFJbnNlcnRSb3dzUmVxdWVzdBIXCgdncmlkX2lkGAEgASgDUgZncmlkSWQSFAoFaW5kZXgYAi'
    'ABKAVSBWluZGV4EhQKBWNvdW50GAMgASgFUgVjb3VudBISCgR0ZXh0GAQgAygJUgR0ZXh0');

@$core.Deprecated('Use removeRowsRequestDescriptor instead')
const RemoveRowsRequest$json = {
  '1': 'RemoveRowsRequest',
  '2': [
    {'1': 'grid_id', '3': 1, '4': 1, '5': 3, '10': 'gridId'},
    {'1': 'index', '3': 2, '4': 1, '5': 5, '10': 'index'},
    {'1': 'count', '3': 3, '4': 1, '5': 5, '10': 'count'},
  ],
};

/// Descriptor for `RemoveRowsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List removeRowsRequestDescriptor = $convert.base64Decode(
    'ChFSZW1vdmVSb3dzUmVxdWVzdBIXCgdncmlkX2lkGAEgASgDUgZncmlkSWQSFAoFaW5kZXgYAi'
    'ABKAVSBWluZGV4EhQKBWNvdW50GAMgASgFUgVjb3VudA==');

@$core.Deprecated('Use moveColumnRequestDescriptor instead')
const MoveColumnRequest$json = {
  '1': 'MoveColumnRequest',
  '2': [
    {'1': 'grid_id', '3': 1, '4': 1, '5': 3, '10': 'gridId'},
    {'1': 'col', '3': 2, '4': 1, '5': 5, '10': 'col'},
    {'1': 'position', '3': 3, '4': 1, '5': 5, '10': 'position'},
  ],
};

/// Descriptor for `MoveColumnRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List moveColumnRequestDescriptor = $convert.base64Decode(
    'ChFNb3ZlQ29sdW1uUmVxdWVzdBIXCgdncmlkX2lkGAEgASgDUgZncmlkSWQSEAoDY29sGAIgAS'
    'gFUgNjb2wSGgoIcG9zaXRpb24YAyABKAVSCHBvc2l0aW9u');

@$core.Deprecated('Use moveRowRequestDescriptor instead')
const MoveRowRequest$json = {
  '1': 'MoveRowRequest',
  '2': [
    {'1': 'grid_id', '3': 1, '4': 1, '5': 3, '10': 'gridId'},
    {'1': 'row', '3': 2, '4': 1, '5': 5, '10': 'row'},
    {'1': 'position', '3': 3, '4': 1, '5': 5, '10': 'position'},
  ],
};

/// Descriptor for `MoveRowRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List moveRowRequestDescriptor = $convert.base64Decode(
    'Cg5Nb3ZlUm93UmVxdWVzdBIXCgdncmlkX2lkGAEgASgDUgZncmlkSWQSEAoDcm93GAIgASgFUg'
    'Nyb3cSGgoIcG9zaXRpb24YAyABKAVSCHBvc2l0aW9u');

@$core.Deprecated('Use selectRequestDescriptor instead')
const SelectRequest$json = {
  '1': 'SelectRequest',
  '2': [
    {'1': 'grid_id', '3': 1, '4': 1, '5': 3, '10': 'gridId'},
    {'1': 'active_row', '3': 2, '4': 1, '5': 5, '10': 'activeRow'},
    {'1': 'active_col', '3': 3, '4': 1, '5': 5, '10': 'activeCol'},
    {
      '1': 'ranges',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.volvoxgrid.v1.CellRange',
      '10': 'ranges'
    },
    {'1': 'show', '3': 5, '4': 1, '5': 8, '9': 0, '10': 'show', '17': true},
  ],
  '8': [
    {'1': '_show'},
  ],
};

/// Descriptor for `SelectRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List selectRequestDescriptor = $convert.base64Decode(
    'Cg1TZWxlY3RSZXF1ZXN0EhcKB2dyaWRfaWQYASABKANSBmdyaWRJZBIdCgphY3RpdmVfcm93GA'
    'IgASgFUglhY3RpdmVSb3cSHQoKYWN0aXZlX2NvbBgDIAEoBVIJYWN0aXZlQ29sEjAKBnJhbmdl'
    'cxgEIAMoCzIYLnZvbHZveGdyaWQudjEuQ2VsbFJhbmdlUgZyYW5nZXMSFwoEc2hvdxgFIAEoCE'
    'gAUgRzaG93iAEBQgcKBV9zaG93');

@$core.Deprecated('Use selectionStateDescriptor instead')
const SelectionState$json = {
  '1': 'SelectionState',
  '2': [
    {'1': 'active_row', '3': 1, '4': 1, '5': 5, '10': 'activeRow'},
    {'1': 'active_col', '3': 2, '4': 1, '5': 5, '10': 'activeCol'},
    {
      '1': 'ranges',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.volvoxgrid.v1.CellRange',
      '10': 'ranges'
    },
    {'1': 'top_row', '3': 4, '4': 1, '5': 5, '10': 'topRow'},
    {'1': 'left_col', '3': 5, '4': 1, '5': 5, '10': 'leftCol'},
    {'1': 'bottom_row', '3': 6, '4': 1, '5': 5, '10': 'bottomRow'},
    {'1': 'right_col', '3': 7, '4': 1, '5': 5, '10': 'rightCol'},
    {'1': 'mouse_row', '3': 8, '4': 1, '5': 5, '10': 'mouseRow'},
    {'1': 'mouse_col', '3': 9, '4': 1, '5': 5, '10': 'mouseCol'},
  ],
};

/// Descriptor for `SelectionState`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List selectionStateDescriptor = $convert.base64Decode(
    'Cg5TZWxlY3Rpb25TdGF0ZRIdCgphY3RpdmVfcm93GAEgASgFUglhY3RpdmVSb3cSHQoKYWN0aX'
    'ZlX2NvbBgCIAEoBVIJYWN0aXZlQ29sEjAKBnJhbmdlcxgDIAMoCzIYLnZvbHZveGdyaWQudjEu'
    'Q2VsbFJhbmdlUgZyYW5nZXMSFwoHdG9wX3JvdxgEIAEoBVIGdG9wUm93EhkKCGxlZnRfY29sGA'
    'UgASgFUgdsZWZ0Q29sEh0KCmJvdHRvbV9yb3cYBiABKAVSCWJvdHRvbVJvdxIbCglyaWdodF9j'
    'b2wYByABKAVSCHJpZ2h0Q29sEhsKCW1vdXNlX3JvdxgIIAEoBVIIbW91c2VSb3cSGwoJbW91c2'
    'VfY29sGAkgASgFUghtb3VzZUNvbA==');

@$core.Deprecated('Use highlightRegionDescriptor instead')
const HighlightRegion$json = {
  '1': 'HighlightRegion',
  '2': [
    {
      '1': 'range',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.CellRange',
      '10': 'range'
    },
    {
      '1': 'style',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.HighlightStyle',
      '10': 'style'
    },
    {'1': 'ref_id', '3': 3, '4': 1, '5': 5, '9': 0, '10': 'refId', '17': true},
    {
      '1': 'text_start',
      '3': 4,
      '4': 1,
      '5': 5,
      '9': 1,
      '10': 'textStart',
      '17': true
    },
    {
      '1': 'text_length',
      '3': 5,
      '4': 1,
      '5': 5,
      '9': 2,
      '10': 'textLength',
      '17': true
    },
  ],
  '8': [
    {'1': '_ref_id'},
    {'1': '_text_start'},
    {'1': '_text_length'},
  ],
};

/// Descriptor for `HighlightRegion`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List highlightRegionDescriptor = $convert.base64Decode(
    'Cg9IaWdobGlnaHRSZWdpb24SLgoFcmFuZ2UYASABKAsyGC52b2x2b3hncmlkLnYxLkNlbGxSYW'
    '5nZVIFcmFuZ2USMwoFc3R5bGUYAiABKAsyHS52b2x2b3hncmlkLnYxLkhpZ2hsaWdodFN0eWxl'
    'UgVzdHlsZRIaCgZyZWZfaWQYAyABKAVIAFIFcmVmSWSIAQESIgoKdGV4dF9zdGFydBgEIAEoBU'
    'gBUgl0ZXh0U3RhcnSIAQESJAoLdGV4dF9sZW5ndGgYBSABKAVIAlIKdGV4dExlbmd0aIgBAUIJ'
    'CgdfcmVmX2lkQg0KC190ZXh0X3N0YXJ0Qg4KDF90ZXh0X2xlbmd0aA==');

@$core.Deprecated('Use editSetHighlightsDescriptor instead')
const EditSetHighlights$json = {
  '1': 'EditSetHighlights',
  '2': [
    {
      '1': 'regions',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.volvoxgrid.v1.HighlightRegion',
      '10': 'regions'
    },
  ],
};

/// Descriptor for `EditSetHighlights`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List editSetHighlightsDescriptor = $convert.base64Decode(
    'ChFFZGl0U2V0SGlnaGxpZ2h0cxI4CgdyZWdpb25zGAEgAygLMh4udm9sdm94Z3JpZC52MS5IaW'
    'dobGlnaHRSZWdpb25SB3JlZ2lvbnM=');

@$core.Deprecated('Use editCommandDescriptor instead')
const EditCommand$json = {
  '1': 'EditCommand',
  '2': [
    {'1': 'grid_id', '3': 1, '4': 1, '5': 3, '10': 'gridId'},
    {
      '1': 'start',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.EditStart',
      '9': 0,
      '10': 'start'
    },
    {
      '1': 'commit',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.EditCommit',
      '9': 0,
      '10': 'commit'
    },
    {
      '1': 'cancel',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.EditCancel',
      '9': 0,
      '10': 'cancel'
    },
    {
      '1': 'set_text',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.EditSetText',
      '9': 0,
      '10': 'setText'
    },
    {
      '1': 'set_selection',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.EditSetSelection',
      '9': 0,
      '10': 'setSelection'
    },
    {
      '1': 'finish',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.EditFinish',
      '9': 0,
      '10': 'finish'
    },
    {
      '1': 'set_highlights',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.EditSetHighlights',
      '9': 0,
      '10': 'setHighlights'
    },
    {
      '1': 'set_preedit',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.EditSetPreedit',
      '9': 0,
      '10': 'setPreedit'
    },
  ],
  '8': [
    {'1': 'command'},
  ],
};

/// Descriptor for `EditCommand`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List editCommandDescriptor = $convert.base64Decode(
    'CgtFZGl0Q29tbWFuZBIXCgdncmlkX2lkGAEgASgDUgZncmlkSWQSMAoFc3RhcnQYAiABKAsyGC'
    '52b2x2b3hncmlkLnYxLkVkaXRTdGFydEgAUgVzdGFydBIzCgZjb21taXQYAyABKAsyGS52b2x2'
    'b3hncmlkLnYxLkVkaXRDb21taXRIAFIGY29tbWl0EjMKBmNhbmNlbBgEIAEoCzIZLnZvbHZveG'
    'dyaWQudjEuRWRpdENhbmNlbEgAUgZjYW5jZWwSNwoIc2V0X3RleHQYBSABKAsyGi52b2x2b3hn'
    'cmlkLnYxLkVkaXRTZXRUZXh0SABSB3NldFRleHQSRgoNc2V0X3NlbGVjdGlvbhgGIAEoCzIfLn'
    'ZvbHZveGdyaWQudjEuRWRpdFNldFNlbGVjdGlvbkgAUgxzZXRTZWxlY3Rpb24SMwoGZmluaXNo'
    'GAcgASgLMhkudm9sdm94Z3JpZC52MS5FZGl0RmluaXNoSABSBmZpbmlzaBJJCg5zZXRfaGlnaG'
    'xpZ2h0cxgIIAEoCzIgLnZvbHZveGdyaWQudjEuRWRpdFNldEhpZ2hsaWdodHNIAFINc2V0SGln'
    'aGxpZ2h0cxJACgtzZXRfcHJlZWRpdBgJIAEoCzIdLnZvbHZveGdyaWQudjEuRWRpdFNldFByZW'
    'VkaXRIAFIKc2V0UHJlZWRpdEIJCgdjb21tYW5k');

@$core.Deprecated('Use editStartDescriptor instead')
const EditStart$json = {
  '1': 'EditStart',
  '2': [
    {'1': 'row', '3': 1, '4': 1, '5': 5, '10': 'row'},
    {'1': 'col', '3': 2, '4': 1, '5': 5, '10': 'col'},
    {
      '1': 'select_all',
      '3': 3,
      '4': 1,
      '5': 8,
      '9': 0,
      '10': 'selectAll',
      '17': true
    },
    {
      '1': 'caret_end',
      '3': 4,
      '4': 1,
      '5': 8,
      '9': 1,
      '10': 'caretEnd',
      '17': true
    },
    {
      '1': 'seed_text',
      '3': 5,
      '4': 1,
      '5': 9,
      '9': 2,
      '10': 'seedText',
      '17': true
    },
    {
      '1': 'formula_mode',
      '3': 6,
      '4': 1,
      '5': 8,
      '9': 3,
      '10': 'formulaMode',
      '17': true
    },
  ],
  '8': [
    {'1': '_select_all'},
    {'1': '_caret_end'},
    {'1': '_seed_text'},
    {'1': '_formula_mode'},
  ],
};

/// Descriptor for `EditStart`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List editStartDescriptor = $convert.base64Decode(
    'CglFZGl0U3RhcnQSEAoDcm93GAEgASgFUgNyb3cSEAoDY29sGAIgASgFUgNjb2wSIgoKc2VsZW'
    'N0X2FsbBgDIAEoCEgAUglzZWxlY3RBbGyIAQESIAoJY2FyZXRfZW5kGAQgASgISAFSCGNhcmV0'
    'RW5kiAEBEiAKCXNlZWRfdGV4dBgFIAEoCUgCUghzZWVkVGV4dIgBARImCgxmb3JtdWxhX21vZG'
    'UYBiABKAhIA1ILZm9ybXVsYU1vZGWIAQFCDQoLX3NlbGVjdF9hbGxCDAoKX2NhcmV0X2VuZEIM'
    'Cgpfc2VlZF90ZXh0Qg8KDV9mb3JtdWxhX21vZGU=');

@$core.Deprecated('Use editCommitDescriptor instead')
const EditCommit$json = {
  '1': 'EditCommit',
  '2': [
    {'1': 'text', '3': 1, '4': 1, '5': 9, '9': 0, '10': 'text', '17': true},
  ],
  '8': [
    {'1': '_text'},
  ],
};

/// Descriptor for `EditCommit`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List editCommitDescriptor = $convert.base64Decode(
    'CgpFZGl0Q29tbWl0EhcKBHRleHQYASABKAlIAFIEdGV4dIgBAUIHCgVfdGV4dA==');

@$core.Deprecated('Use editCancelDescriptor instead')
const EditCancel$json = {
  '1': 'EditCancel',
};

/// Descriptor for `EditCancel`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List editCancelDescriptor =
    $convert.base64Decode('CgpFZGl0Q2FuY2Vs');

@$core.Deprecated('Use editSetTextDescriptor instead')
const EditSetText$json = {
  '1': 'EditSetText',
  '2': [
    {'1': 'text', '3': 1, '4': 1, '5': 9, '10': 'text'},
  ],
};

/// Descriptor for `EditSetText`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List editSetTextDescriptor =
    $convert.base64Decode('CgtFZGl0U2V0VGV4dBISCgR0ZXh0GAEgASgJUgR0ZXh0');

@$core.Deprecated('Use editSetSelectionDescriptor instead')
const EditSetSelection$json = {
  '1': 'EditSetSelection',
  '2': [
    {'1': 'start', '3': 1, '4': 1, '5': 5, '10': 'start'},
    {'1': 'length', '3': 2, '4': 1, '5': 5, '10': 'length'},
  ],
};

/// Descriptor for `EditSetSelection`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List editSetSelectionDescriptor = $convert.base64Decode(
    'ChBFZGl0U2V0U2VsZWN0aW9uEhQKBXN0YXJ0GAEgASgFUgVzdGFydBIWCgZsZW5ndGgYAiABKA'
    'VSBmxlbmd0aA==');

@$core.Deprecated('Use editSetPreeditDescriptor instead')
const EditSetPreedit$json = {
  '1': 'EditSetPreedit',
  '2': [
    {'1': 'text', '3': 1, '4': 1, '5': 9, '10': 'text'},
    {'1': 'cursor', '3': 2, '4': 1, '5': 5, '10': 'cursor'},
    {'1': 'commit', '3': 3, '4': 1, '5': 8, '10': 'commit'},
  ],
};

/// Descriptor for `EditSetPreedit`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List editSetPreeditDescriptor = $convert.base64Decode(
    'Cg5FZGl0U2V0UHJlZWRpdBISCgR0ZXh0GAEgASgJUgR0ZXh0EhYKBmN1cnNvchgCIAEoBVIGY3'
    'Vyc29yEhYKBmNvbW1pdBgDIAEoCFIGY29tbWl0');

@$core.Deprecated('Use editFinishDescriptor instead')
const EditFinish$json = {
  '1': 'EditFinish',
};

/// Descriptor for `EditFinish`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List editFinishDescriptor =
    $convert.base64Decode('CgpFZGl0RmluaXNo');

@$core.Deprecated('Use editStateDescriptor instead')
const EditState$json = {
  '1': 'EditState',
  '2': [
    {'1': 'active', '3': 1, '4': 1, '5': 8, '10': 'active'},
    {'1': 'row', '3': 2, '4': 1, '5': 5, '10': 'row'},
    {'1': 'col', '3': 3, '4': 1, '5': 5, '10': 'col'},
    {'1': 'text', '3': 4, '4': 1, '5': 9, '10': 'text'},
    {'1': 'sel_start', '3': 5, '4': 1, '5': 5, '10': 'selStart'},
    {'1': 'sel_length', '3': 6, '4': 1, '5': 5, '10': 'selLength'},
    {'1': 'composing', '3': 7, '4': 1, '5': 8, '10': 'composing'},
    {'1': 'preedit_text', '3': 8, '4': 1, '5': 9, '10': 'preeditText'},
    {
      '1': 'ui_mode',
      '3': 9,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.EditUiMode',
      '10': 'uiMode'
    },
    {'1': 'x', '3': 10, '4': 1, '5': 2, '10': 'x'},
    {'1': 'y', '3': 11, '4': 1, '5': 2, '10': 'y'},
    {'1': 'width', '3': 12, '4': 1, '5': 2, '10': 'width'},
    {'1': 'height', '3': 13, '4': 1, '5': 2, '10': 'height'},
    {'1': 'max_length', '3': 14, '4': 1, '5': 5, '10': 'maxLength'},
  ],
};

/// Descriptor for `EditState`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List editStateDescriptor = $convert.base64Decode(
    'CglFZGl0U3RhdGUSFgoGYWN0aXZlGAEgASgIUgZhY3RpdmUSEAoDcm93GAIgASgFUgNyb3cSEA'
    'oDY29sGAMgASgFUgNjb2wSEgoEdGV4dBgEIAEoCVIEdGV4dBIbCglzZWxfc3RhcnQYBSABKAVS'
    'CHNlbFN0YXJ0Eh0KCnNlbF9sZW5ndGgYBiABKAVSCXNlbExlbmd0aBIcCgljb21wb3NpbmcYBy'
    'ABKAhSCWNvbXBvc2luZxIhCgxwcmVlZGl0X3RleHQYCCABKAlSC3ByZWVkaXRUZXh0EjIKB3Vp'
    'X21vZGUYCSABKA4yGS52b2x2b3hncmlkLnYxLkVkaXRVaU1vZGVSBnVpTW9kZRIMCgF4GAogAS'
    'gCUgF4EgwKAXkYCyABKAJSAXkSFAoFd2lkdGgYDCABKAJSBXdpZHRoEhYKBmhlaWdodBgNIAEo'
    'AlIGaGVpZ2h0Eh0KCm1heF9sZW5ndGgYDiABKAVSCW1heExlbmd0aA==');

@$core.Deprecated('Use sortColumnDescriptor instead')
const SortColumn$json = {
  '1': 'SortColumn',
  '2': [
    {'1': 'col', '3': 1, '4': 1, '5': 5, '10': 'col'},
    {
      '1': 'order',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.SortOrder',
      '9': 0,
      '10': 'order',
      '17': true
    },
    {
      '1': 'type',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.SortType',
      '9': 1,
      '10': 'type',
      '17': true
    },
  ],
  '8': [
    {'1': '_order'},
    {'1': '_type'},
  ],
};

/// Descriptor for `SortColumn`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sortColumnDescriptor = $convert.base64Decode(
    'CgpTb3J0Q29sdW1uEhAKA2NvbBgBIAEoBVIDY29sEjMKBW9yZGVyGAIgASgOMhgudm9sdm94Z3'
    'JpZC52MS5Tb3J0T3JkZXJIAFIFb3JkZXKIAQESMAoEdHlwZRgDIAEoDjIXLnZvbHZveGdyaWQu'
    'djEuU29ydFR5cGVIAVIEdHlwZYgBAUIICgZfb3JkZXJCBwoFX3R5cGU=');

@$core.Deprecated('Use sortRequestDescriptor instead')
const SortRequest$json = {
  '1': 'SortRequest',
  '2': [
    {'1': 'grid_id', '3': 1, '4': 1, '5': 3, '10': 'gridId'},
    {
      '1': 'sort_columns',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.volvoxgrid.v1.SortColumn',
      '10': 'sortColumns'
    },
  ],
};

/// Descriptor for `SortRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sortRequestDescriptor = $convert.base64Decode(
    'CgtTb3J0UmVxdWVzdBIXCgdncmlkX2lkGAEgASgDUgZncmlkSWQSPAoMc29ydF9jb2x1bW5zGA'
    'IgAygLMhkudm9sdm94Z3JpZC52MS5Tb3J0Q29sdW1uUgtzb3J0Q29sdW1ucw==');

@$core.Deprecated('Use subtotalRequestDescriptor instead')
const SubtotalRequest$json = {
  '1': 'SubtotalRequest',
  '2': [
    {'1': 'grid_id', '3': 1, '4': 1, '5': 3, '10': 'gridId'},
    {
      '1': 'aggregate',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.AggregateType',
      '10': 'aggregate'
    },
    {'1': 'group_on_col', '3': 3, '4': 1, '5': 5, '10': 'groupOnCol'},
    {'1': 'aggregate_col', '3': 4, '4': 1, '5': 5, '10': 'aggregateCol'},
    {'1': 'caption', '3': 5, '4': 1, '5': 9, '10': 'caption'},
    {'1': 'background', '3': 6, '4': 1, '5': 13, '10': 'background'},
    {'1': 'foreground', '3': 7, '4': 1, '5': 13, '10': 'foreground'},
    {'1': 'add_outline', '3': 8, '4': 1, '5': 8, '10': 'addOutline'},
    {
      '1': 'font',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.Font',
      '10': 'font'
    },
  ],
};

/// Descriptor for `SubtotalRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List subtotalRequestDescriptor = $convert.base64Decode(
    'Cg9TdWJ0b3RhbFJlcXVlc3QSFwoHZ3JpZF9pZBgBIAEoA1IGZ3JpZElkEjoKCWFnZ3JlZ2F0ZR'
    'gCIAEoDjIcLnZvbHZveGdyaWQudjEuQWdncmVnYXRlVHlwZVIJYWdncmVnYXRlEiAKDGdyb3Vw'
    'X29uX2NvbBgDIAEoBVIKZ3JvdXBPbkNvbBIjCg1hZ2dyZWdhdGVfY29sGAQgASgFUgxhZ2dyZW'
    'dhdGVDb2wSGAoHY2FwdGlvbhgFIAEoCVIHY2FwdGlvbhIeCgpiYWNrZ3JvdW5kGAYgASgNUgpi'
    'YWNrZ3JvdW5kEh4KCmZvcmVncm91bmQYByABKA1SCmZvcmVncm91bmQSHwoLYWRkX291dGxpbm'
    'UYCCABKAhSCmFkZE91dGxpbmUSJwoEZm9udBgJIAEoCzITLnZvbHZveGdyaWQudjEuRm9udFIE'
    'Zm9udA==');

@$core.Deprecated('Use subtotalResultDescriptor instead')
const SubtotalResult$json = {
  '1': 'SubtotalResult',
  '2': [
    {'1': 'rows', '3': 1, '4': 3, '5': 5, '10': 'rows'},
  ],
};

/// Descriptor for `SubtotalResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List subtotalResultDescriptor =
    $convert.base64Decode('Cg5TdWJ0b3RhbFJlc3VsdBISCgRyb3dzGAEgAygFUgRyb3dz');

@$core.Deprecated('Use autoSizeRequestDescriptor instead')
const AutoSizeRequest$json = {
  '1': 'AutoSizeRequest',
  '2': [
    {'1': 'grid_id', '3': 1, '4': 1, '5': 3, '10': 'gridId'},
    {'1': 'col_from', '3': 2, '4': 1, '5': 5, '10': 'colFrom'},
    {'1': 'col_to', '3': 3, '4': 1, '5': 5, '10': 'colTo'},
    {'1': 'equal', '3': 4, '4': 1, '5': 8, '10': 'equal'},
    {'1': 'max_width', '3': 5, '4': 1, '5': 5, '10': 'maxWidth'},
  ],
};

/// Descriptor for `AutoSizeRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List autoSizeRequestDescriptor = $convert.base64Decode(
    'Cg9BdXRvU2l6ZVJlcXVlc3QSFwoHZ3JpZF9pZBgBIAEoA1IGZ3JpZElkEhkKCGNvbF9mcm9tGA'
    'IgASgFUgdjb2xGcm9tEhUKBmNvbF90bxgDIAEoBVIFY29sVG8SFAoFZXF1YWwYBCABKAhSBWVx'
    'dWFsEhsKCW1heF93aWR0aBgFIAEoBVIIbWF4V2lkdGg=');

@$core.Deprecated('Use outlineRequestDescriptor instead')
const OutlineRequest$json = {
  '1': 'OutlineRequest',
  '2': [
    {'1': 'grid_id', '3': 1, '4': 1, '5': 3, '10': 'gridId'},
    {'1': 'level', '3': 2, '4': 1, '5': 5, '10': 'level'},
  ],
};

/// Descriptor for `OutlineRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List outlineRequestDescriptor = $convert.base64Decode(
    'Cg5PdXRsaW5lUmVxdWVzdBIXCgdncmlkX2lkGAEgASgDUgZncmlkSWQSFAoFbGV2ZWwYAiABKA'
    'VSBWxldmVs');

@$core.Deprecated('Use getNodeRequestDescriptor instead')
const GetNodeRequest$json = {
  '1': 'GetNodeRequest',
  '2': [
    {'1': 'grid_id', '3': 1, '4': 1, '5': 3, '10': 'gridId'},
    {'1': 'row', '3': 2, '4': 1, '5': 5, '10': 'row'},
    {
      '1': 'relation',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.NodeRelation',
      '9': 0,
      '10': 'relation',
      '17': true
    },
  ],
  '8': [
    {'1': '_relation'},
  ],
};

/// Descriptor for `GetNodeRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getNodeRequestDescriptor = $convert.base64Decode(
    'Cg5HZXROb2RlUmVxdWVzdBIXCgdncmlkX2lkGAEgASgDUgZncmlkSWQSEAoDcm93GAIgASgFUg'
    'Nyb3cSPAoIcmVsYXRpb24YAyABKA4yGy52b2x2b3hncmlkLnYxLk5vZGVSZWxhdGlvbkgAUghy'
    'ZWxhdGlvbogBAUILCglfcmVsYXRpb24=');

@$core.Deprecated('Use nodeInfoDescriptor instead')
const NodeInfo$json = {
  '1': 'NodeInfo',
  '2': [
    {'1': 'row', '3': 1, '4': 1, '5': 5, '10': 'row'},
    {'1': 'level', '3': 2, '4': 1, '5': 5, '10': 'level'},
    {'1': 'is_expanded', '3': 3, '4': 1, '5': 8, '10': 'isExpanded'},
    {'1': 'child_count', '3': 4, '4': 1, '5': 5, '10': 'childCount'},
    {'1': 'parent_row', '3': 5, '4': 1, '5': 5, '10': 'parentRow'},
    {'1': 'first_child', '3': 6, '4': 1, '5': 5, '10': 'firstChild'},
    {'1': 'last_child', '3': 7, '4': 1, '5': 5, '10': 'lastChild'},
  ],
};

/// Descriptor for `NodeInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List nodeInfoDescriptor = $convert.base64Decode(
    'CghOb2RlSW5mbxIQCgNyb3cYASABKAVSA3JvdxIUCgVsZXZlbBgCIAEoBVIFbGV2ZWwSHwoLaX'
    'NfZXhwYW5kZWQYAyABKAhSCmlzRXhwYW5kZWQSHwoLY2hpbGRfY291bnQYBCABKAVSCmNoaWxk'
    'Q291bnQSHQoKcGFyZW50X3JvdxgFIAEoBVIJcGFyZW50Um93Eh8KC2ZpcnN0X2NoaWxkGAYgAS'
    'gFUgpmaXJzdENoaWxkEh0KCmxhc3RfY2hpbGQYByABKAVSCWxhc3RDaGlsZA==');

@$core.Deprecated('Use findRequestDescriptor instead')
const FindRequest$json = {
  '1': 'FindRequest',
  '2': [
    {'1': 'grid_id', '3': 1, '4': 1, '5': 3, '10': 'gridId'},
    {'1': 'col', '3': 2, '4': 1, '5': 5, '10': 'col'},
    {'1': 'start_row', '3': 3, '4': 1, '5': 5, '10': 'startRow'},
    {
      '1': 'text_query',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.TextQuery',
      '9': 0,
      '10': 'textQuery'
    },
    {
      '1': 'regex_query',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.RegexQuery',
      '9': 0,
      '10': 'regexQuery'
    },
  ],
  '8': [
    {'1': 'query'},
  ],
};

/// Descriptor for `FindRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List findRequestDescriptor = $convert.base64Decode(
    'CgtGaW5kUmVxdWVzdBIXCgdncmlkX2lkGAEgASgDUgZncmlkSWQSEAoDY29sGAIgASgFUgNjb2'
    'wSGwoJc3RhcnRfcm93GAMgASgFUghzdGFydFJvdxI5Cgp0ZXh0X3F1ZXJ5GAQgASgLMhgudm9s'
    'dm94Z3JpZC52MS5UZXh0UXVlcnlIAFIJdGV4dFF1ZXJ5EjwKC3JlZ2V4X3F1ZXJ5GAUgASgLMh'
    'kudm9sdm94Z3JpZC52MS5SZWdleFF1ZXJ5SABSCnJlZ2V4UXVlcnlCBwoFcXVlcnk=');

@$core.Deprecated('Use textQueryDescriptor instead')
const TextQuery$json = {
  '1': 'TextQuery',
  '2': [
    {'1': 'text', '3': 1, '4': 1, '5': 9, '10': 'text'},
    {'1': 'case_sensitive', '3': 2, '4': 1, '5': 8, '10': 'caseSensitive'},
    {'1': 'full_match', '3': 3, '4': 1, '5': 8, '10': 'fullMatch'},
  ],
};

/// Descriptor for `TextQuery`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List textQueryDescriptor = $convert.base64Decode(
    'CglUZXh0UXVlcnkSEgoEdGV4dBgBIAEoCVIEdGV4dBIlCg5jYXNlX3NlbnNpdGl2ZRgCIAEoCF'
    'INY2FzZVNlbnNpdGl2ZRIdCgpmdWxsX21hdGNoGAMgASgIUglmdWxsTWF0Y2g=');

@$core.Deprecated('Use regexQueryDescriptor instead')
const RegexQuery$json = {
  '1': 'RegexQuery',
  '2': [
    {'1': 'pattern', '3': 1, '4': 1, '5': 9, '10': 'pattern'},
  ],
};

/// Descriptor for `RegexQuery`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List regexQueryDescriptor = $convert
    .base64Decode('CgpSZWdleFF1ZXJ5EhgKB3BhdHRlcm4YASABKAlSB3BhdHRlcm4=');

@$core.Deprecated('Use findResponseDescriptor instead')
const FindResponse$json = {
  '1': 'FindResponse',
  '2': [
    {'1': 'row', '3': 1, '4': 1, '5': 5, '10': 'row'},
  ],
};

/// Descriptor for `FindResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List findResponseDescriptor =
    $convert.base64Decode('CgxGaW5kUmVzcG9uc2USEAoDcm93GAEgASgFUgNyb3c=');

@$core.Deprecated('Use aggregateRequestDescriptor instead')
const AggregateRequest$json = {
  '1': 'AggregateRequest',
  '2': [
    {'1': 'grid_id', '3': 1, '4': 1, '5': 3, '10': 'gridId'},
    {
      '1': 'aggregate',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.AggregateType',
      '10': 'aggregate'
    },
    {'1': 'row1', '3': 3, '4': 1, '5': 5, '10': 'row1'},
    {'1': 'col1', '3': 4, '4': 1, '5': 5, '10': 'col1'},
    {'1': 'row2', '3': 5, '4': 1, '5': 5, '10': 'row2'},
    {'1': 'col2', '3': 6, '4': 1, '5': 5, '10': 'col2'},
  ],
};

/// Descriptor for `AggregateRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List aggregateRequestDescriptor = $convert.base64Decode(
    'ChBBZ2dyZWdhdGVSZXF1ZXN0EhcKB2dyaWRfaWQYASABKANSBmdyaWRJZBI6CglhZ2dyZWdhdG'
    'UYAiABKA4yHC52b2x2b3hncmlkLnYxLkFnZ3JlZ2F0ZVR5cGVSCWFnZ3JlZ2F0ZRISCgRyb3cx'
    'GAMgASgFUgRyb3cxEhIKBGNvbDEYBCABKAVSBGNvbDESEgoEcm93MhgFIAEoBVIEcm93MhISCg'
    'Rjb2wyGAYgASgFUgRjb2wy');

@$core.Deprecated('Use aggregateResponseDescriptor instead')
const AggregateResponse$json = {
  '1': 'AggregateResponse',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 1, '10': 'value'},
  ],
};

/// Descriptor for `AggregateResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List aggregateResponseDescriptor = $convert
    .base64Decode('ChFBZ2dyZWdhdGVSZXNwb25zZRIUCgV2YWx1ZRgBIAEoAVIFdmFsdWU=');

@$core.Deprecated('Use getMergedRangeRequestDescriptor instead')
const GetMergedRangeRequest$json = {
  '1': 'GetMergedRangeRequest',
  '2': [
    {'1': 'grid_id', '3': 1, '4': 1, '5': 3, '10': 'gridId'},
    {'1': 'row', '3': 2, '4': 1, '5': 5, '10': 'row'},
    {'1': 'col', '3': 3, '4': 1, '5': 5, '10': 'col'},
  ],
};

/// Descriptor for `GetMergedRangeRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getMergedRangeRequestDescriptor = $convert.base64Decode(
    'ChVHZXRNZXJnZWRSYW5nZVJlcXVlc3QSFwoHZ3JpZF9pZBgBIAEoA1IGZ3JpZElkEhAKA3Jvdx'
    'gCIAEoBVIDcm93EhAKA2NvbBgDIAEoBVIDY29s');

@$core.Deprecated('Use mergeCellsRequestDescriptor instead')
const MergeCellsRequest$json = {
  '1': 'MergeCellsRequest',
  '2': [
    {'1': 'grid_id', '3': 1, '4': 1, '5': 3, '10': 'gridId'},
    {
      '1': 'range',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.CellRange',
      '10': 'range'
    },
  ],
};

/// Descriptor for `MergeCellsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List mergeCellsRequestDescriptor = $convert.base64Decode(
    'ChFNZXJnZUNlbGxzUmVxdWVzdBIXCgdncmlkX2lkGAEgASgDUgZncmlkSWQSLgoFcmFuZ2UYAi'
    'ABKAsyGC52b2x2b3hncmlkLnYxLkNlbGxSYW5nZVIFcmFuZ2U=');

@$core.Deprecated('Use unmergeCellsRequestDescriptor instead')
const UnmergeCellsRequest$json = {
  '1': 'UnmergeCellsRequest',
  '2': [
    {'1': 'grid_id', '3': 1, '4': 1, '5': 3, '10': 'gridId'},
    {
      '1': 'range',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.CellRange',
      '10': 'range'
    },
  ],
};

/// Descriptor for `UnmergeCellsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List unmergeCellsRequestDescriptor = $convert.base64Decode(
    'ChNVbm1lcmdlQ2VsbHNSZXF1ZXN0EhcKB2dyaWRfaWQYASABKANSBmdyaWRJZBIuCgVyYW5nZR'
    'gCIAEoCzIYLnZvbHZveGdyaWQudjEuQ2VsbFJhbmdlUgVyYW5nZQ==');

@$core.Deprecated('Use mergedRegionsResponseDescriptor instead')
const MergedRegionsResponse$json = {
  '1': 'MergedRegionsResponse',
  '2': [
    {
      '1': 'ranges',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.volvoxgrid.v1.CellRange',
      '10': 'ranges'
    },
  ],
};

/// Descriptor for `MergedRegionsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List mergedRegionsResponseDescriptor = $convert.base64Decode(
    'ChVNZXJnZWRSZWdpb25zUmVzcG9uc2USMAoGcmFuZ2VzGAEgAygLMhgudm9sdm94Z3JpZC52MS'
    '5DZWxsUmFuZ2VSBnJhbmdlcw==');

@$core.Deprecated('Use memoryUsageResponseDescriptor instead')
const MemoryUsageResponse$json = {
  '1': 'MemoryUsageResponse',
  '2': [
    {'1': 'total_bytes', '3': 1, '4': 1, '5': 3, '10': 'totalBytes'},
    {'1': 'cell_data_bytes', '3': 2, '4': 1, '5': 3, '10': 'cellDataBytes'},
    {'1': 'style_bytes', '3': 3, '4': 1, '5': 3, '10': 'styleBytes'},
    {'1': 'layout_bytes', '3': 4, '4': 1, '5': 3, '10': 'layoutBytes'},
    {'1': 'column_bytes', '3': 5, '4': 1, '5': 3, '10': 'columnBytes'},
    {'1': 'row_bytes', '3': 6, '4': 1, '5': 3, '10': 'rowBytes'},
    {'1': 'selection_bytes', '3': 7, '4': 1, '5': 3, '10': 'selectionBytes'},
    {'1': 'animation_bytes', '3': 8, '4': 1, '5': 3, '10': 'animationBytes'},
    {'1': 'text_engine_bytes', '3': 9, '4': 1, '5': 3, '10': 'textEngineBytes'},
    {'1': 'event_bytes', '3': 10, '4': 1, '5': 3, '10': 'eventBytes'},
    {'1': 'misc_bytes', '3': 11, '4': 1, '5': 3, '10': 'miscBytes'},
    {'1': 'cell_count', '3': 12, '4': 1, '5': 5, '10': 'cellCount'},
    {'1': 'rows', '3': 13, '4': 1, '5': 5, '10': 'rows'},
    {'1': 'cols', '3': 14, '4': 1, '5': 5, '10': 'cols'},
  ],
};

/// Descriptor for `MemoryUsageResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List memoryUsageResponseDescriptor = $convert.base64Decode(
    'ChNNZW1vcnlVc2FnZVJlc3BvbnNlEh8KC3RvdGFsX2J5dGVzGAEgASgDUgp0b3RhbEJ5dGVzEi'
    'YKD2NlbGxfZGF0YV9ieXRlcxgCIAEoA1INY2VsbERhdGFCeXRlcxIfCgtzdHlsZV9ieXRlcxgD'
    'IAEoA1IKc3R5bGVCeXRlcxIhCgxsYXlvdXRfYnl0ZXMYBCABKANSC2xheW91dEJ5dGVzEiEKDG'
    'NvbHVtbl9ieXRlcxgFIAEoA1ILY29sdW1uQnl0ZXMSGwoJcm93X2J5dGVzGAYgASgDUghyb3dC'
    'eXRlcxInCg9zZWxlY3Rpb25fYnl0ZXMYByABKANSDnNlbGVjdGlvbkJ5dGVzEicKD2FuaW1hdG'
    'lvbl9ieXRlcxgIIAEoA1IOYW5pbWF0aW9uQnl0ZXMSKgoRdGV4dF9lbmdpbmVfYnl0ZXMYCSAB'
    'KANSD3RleHRFbmdpbmVCeXRlcxIfCgtldmVudF9ieXRlcxgKIAEoA1IKZXZlbnRCeXRlcxIdCg'
    'ptaXNjX2J5dGVzGAsgASgDUgltaXNjQnl0ZXMSHQoKY2VsbF9jb3VudBgMIAEoBVIJY2VsbENv'
    'dW50EhIKBHJvd3MYDSABKAVSBHJvd3MSEgoEY29scxgOIAEoBVIEY29scw==');

@$core.Deprecated('Use clipboardCommandDescriptor instead')
const ClipboardCommand$json = {
  '1': 'ClipboardCommand',
  '2': [
    {'1': 'grid_id', '3': 1, '4': 1, '5': 3, '10': 'gridId'},
    {
      '1': 'copy',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.ClipboardCopy',
      '9': 0,
      '10': 'copy'
    },
    {
      '1': 'cut',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.ClipboardCut',
      '9': 0,
      '10': 'cut'
    },
    {
      '1': 'paste',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.ClipboardPaste',
      '9': 0,
      '10': 'paste'
    },
    {
      '1': 'delete',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.ClipboardDelete',
      '9': 0,
      '10': 'delete'
    },
  ],
  '8': [
    {'1': 'command'},
  ],
};

/// Descriptor for `ClipboardCommand`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List clipboardCommandDescriptor = $convert.base64Decode(
    'ChBDbGlwYm9hcmRDb21tYW5kEhcKB2dyaWRfaWQYASABKANSBmdyaWRJZBIyCgRjb3B5GAIgAS'
    'gLMhwudm9sdm94Z3JpZC52MS5DbGlwYm9hcmRDb3B5SABSBGNvcHkSLwoDY3V0GAMgASgLMhsu'
    'dm9sdm94Z3JpZC52MS5DbGlwYm9hcmRDdXRIAFIDY3V0EjUKBXBhc3RlGAQgASgLMh0udm9sdm'
    '94Z3JpZC52MS5DbGlwYm9hcmRQYXN0ZUgAUgVwYXN0ZRI4CgZkZWxldGUYBSABKAsyHi52b2x2'
    'b3hncmlkLnYxLkNsaXBib2FyZERlbGV0ZUgAUgZkZWxldGVCCQoHY29tbWFuZA==');

@$core.Deprecated('Use clipboardCopyDescriptor instead')
const ClipboardCopy$json = {
  '1': 'ClipboardCopy',
};

/// Descriptor for `ClipboardCopy`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List clipboardCopyDescriptor =
    $convert.base64Decode('Cg1DbGlwYm9hcmRDb3B5');

@$core.Deprecated('Use clipboardCutDescriptor instead')
const ClipboardCut$json = {
  '1': 'ClipboardCut',
};

/// Descriptor for `ClipboardCut`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List clipboardCutDescriptor =
    $convert.base64Decode('CgxDbGlwYm9hcmRDdXQ=');

@$core.Deprecated('Use clipboardPasteDescriptor instead')
const ClipboardPaste$json = {
  '1': 'ClipboardPaste',
  '2': [
    {'1': 'text', '3': 1, '4': 1, '5': 9, '10': 'text'},
    {'1': 'rich_data', '3': 2, '4': 1, '5': 12, '10': 'richData'},
  ],
};

/// Descriptor for `ClipboardPaste`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List clipboardPasteDescriptor = $convert.base64Decode(
    'Cg5DbGlwYm9hcmRQYXN0ZRISCgR0ZXh0GAEgASgJUgR0ZXh0EhsKCXJpY2hfZGF0YRgCIAEoDF'
    'IIcmljaERhdGE=');

@$core.Deprecated('Use clipboardDeleteDescriptor instead')
const ClipboardDelete$json = {
  '1': 'ClipboardDelete',
};

/// Descriptor for `ClipboardDelete`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List clipboardDeleteDescriptor =
    $convert.base64Decode('Cg9DbGlwYm9hcmREZWxldGU=');

@$core.Deprecated('Use clipboardResponseDescriptor instead')
const ClipboardResponse$json = {
  '1': 'ClipboardResponse',
  '2': [
    {'1': 'text', '3': 1, '4': 1, '5': 9, '10': 'text'},
    {'1': 'rich_data', '3': 2, '4': 1, '5': 12, '10': 'richData'},
  ],
};

/// Descriptor for `ClipboardResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List clipboardResponseDescriptor = $convert.base64Decode(
    'ChFDbGlwYm9hcmRSZXNwb25zZRISCgR0ZXh0GAEgASgJUgR0ZXh0EhsKCXJpY2hfZGF0YRgCIA'
    'EoDFIIcmljaERhdGE=');

@$core.Deprecated('Use exportRequestDescriptor instead')
const ExportRequest$json = {
  '1': 'ExportRequest',
  '2': [
    {'1': 'grid_id', '3': 1, '4': 1, '5': 3, '10': 'gridId'},
    {
      '1': 'format',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.ExportFormat',
      '10': 'format'
    },
    {
      '1': 'scope',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.ExportScope',
      '10': 'scope'
    },
  ],
};

/// Descriptor for `ExportRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List exportRequestDescriptor = $convert.base64Decode(
    'Cg1FeHBvcnRSZXF1ZXN0EhcKB2dyaWRfaWQYASABKANSBmdyaWRJZBIzCgZmb3JtYXQYAiABKA'
    '4yGy52b2x2b3hncmlkLnYxLkV4cG9ydEZvcm1hdFIGZm9ybWF0EjAKBXNjb3BlGAMgASgOMhou'
    'dm9sdm94Z3JpZC52MS5FeHBvcnRTY29wZVIFc2NvcGU=');

@$core.Deprecated('Use exportResponseDescriptor instead')
const ExportResponse$json = {
  '1': 'ExportResponse',
  '2': [
    {'1': 'data', '3': 1, '4': 1, '5': 12, '10': 'data'},
    {
      '1': 'format',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.ExportFormat',
      '10': 'format'
    },
  ],
};

/// Descriptor for `ExportResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List exportResponseDescriptor = $convert.base64Decode(
    'Cg5FeHBvcnRSZXNwb25zZRISCgRkYXRhGAEgASgMUgRkYXRhEjMKBmZvcm1hdBgCIAEoDjIbLn'
    'ZvbHZveGdyaWQudjEuRXhwb3J0Rm9ybWF0UgZmb3JtYXQ=');

@$core.Deprecated('Use printRequestDescriptor instead')
const PrintRequest$json = {
  '1': 'PrintRequest',
  '2': [
    {'1': 'grid_id', '3': 1, '4': 1, '5': 3, '10': 'gridId'},
    {
      '1': 'orientation',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.PrintOrientation',
      '9': 0,
      '10': 'orientation',
      '17': true
    },
    {
      '1': 'margin_left',
      '3': 3,
      '4': 1,
      '5': 5,
      '9': 1,
      '10': 'marginLeft',
      '17': true
    },
    {
      '1': 'margin_top',
      '3': 4,
      '4': 1,
      '5': 5,
      '9': 2,
      '10': 'marginTop',
      '17': true
    },
    {
      '1': 'margin_right',
      '3': 5,
      '4': 1,
      '5': 5,
      '9': 3,
      '10': 'marginRight',
      '17': true
    },
    {
      '1': 'margin_bottom',
      '3': 6,
      '4': 1,
      '5': 5,
      '9': 4,
      '10': 'marginBottom',
      '17': true
    },
    {'1': 'header', '3': 7, '4': 1, '5': 9, '9': 5, '10': 'header', '17': true},
    {'1': 'footer', '3': 8, '4': 1, '5': 9, '9': 6, '10': 'footer', '17': true},
    {
      '1': 'show_page_numbers',
      '3': 9,
      '4': 1,
      '5': 8,
      '9': 7,
      '10': 'showPageNumbers',
      '17': true
    },
  ],
  '8': [
    {'1': '_orientation'},
    {'1': '_margin_left'},
    {'1': '_margin_top'},
    {'1': '_margin_right'},
    {'1': '_margin_bottom'},
    {'1': '_header'},
    {'1': '_footer'},
    {'1': '_show_page_numbers'},
  ],
};

/// Descriptor for `PrintRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List printRequestDescriptor = $convert.base64Decode(
    'CgxQcmludFJlcXVlc3QSFwoHZ3JpZF9pZBgBIAEoA1IGZ3JpZElkEkYKC29yaWVudGF0aW9uGA'
    'IgASgOMh8udm9sdm94Z3JpZC52MS5QcmludE9yaWVudGF0aW9uSABSC29yaWVudGF0aW9uiAEB'
    'EiQKC21hcmdpbl9sZWZ0GAMgASgFSAFSCm1hcmdpbkxlZnSIAQESIgoKbWFyZ2luX3RvcBgEIA'
    'EoBUgCUgltYXJnaW5Ub3CIAQESJgoMbWFyZ2luX3JpZ2h0GAUgASgFSANSC21hcmdpblJpZ2h0'
    'iAEBEigKDW1hcmdpbl9ib3R0b20YBiABKAVIBFIMbWFyZ2luQm90dG9tiAEBEhsKBmhlYWRlch'
    'gHIAEoCUgFUgZoZWFkZXKIAQESGwoGZm9vdGVyGAggASgJSAZSBmZvb3RlcogBARIvChFzaG93'
    'X3BhZ2VfbnVtYmVycxgJIAEoCEgHUg9zaG93UGFnZU51bWJlcnOIAQFCDgoMX29yaWVudGF0aW'
    '9uQg4KDF9tYXJnaW5fbGVmdEINCgtfbWFyZ2luX3RvcEIPCg1fbWFyZ2luX3JpZ2h0QhAKDl9t'
    'YXJnaW5fYm90dG9tQgkKB19oZWFkZXJCCQoHX2Zvb3RlckIUChJfc2hvd19wYWdlX251bWJlcn'
    'M=');

@$core.Deprecated('Use printResponseDescriptor instead')
const PrintResponse$json = {
  '1': 'PrintResponse',
  '2': [
    {
      '1': 'pages',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.volvoxgrid.v1.PrintPage',
      '10': 'pages'
    },
  ],
};

/// Descriptor for `PrintResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List printResponseDescriptor = $convert.base64Decode(
    'Cg1QcmludFJlc3BvbnNlEi4KBXBhZ2VzGAEgAygLMhgudm9sdm94Z3JpZC52MS5QcmludFBhZ2'
    'VSBXBhZ2Vz');

@$core.Deprecated('Use printPageDescriptor instead')
const PrintPage$json = {
  '1': 'PrintPage',
  '2': [
    {'1': 'page_number', '3': 1, '4': 1, '5': 5, '10': 'pageNumber'},
    {'1': 'image_data', '3': 2, '4': 1, '5': 12, '10': 'imageData'},
    {'1': 'width', '3': 3, '4': 1, '5': 5, '10': 'width'},
    {'1': 'height', '3': 4, '4': 1, '5': 5, '10': 'height'},
  ],
};

/// Descriptor for `PrintPage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List printPageDescriptor = $convert.base64Decode(
    'CglQcmludFBhZ2USHwoLcGFnZV9udW1iZXIYASABKAVSCnBhZ2VOdW1iZXISHQoKaW1hZ2VfZG'
    'F0YRgCIAEoDFIJaW1hZ2VEYXRhEhQKBXdpZHRoGAMgASgFUgV3aWR0aBIWCgZoZWlnaHQYBCAB'
    'KAVSBmhlaWdodA==');

@$core.Deprecated('Use archiveRequestDescriptor instead')
const ArchiveRequest$json = {
  '1': 'ArchiveRequest',
  '2': [
    {'1': 'grid_id', '3': 1, '4': 1, '5': 3, '10': 'gridId'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {
      '1': 'action',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.ArchiveRequest.Action',
      '10': 'action'
    },
    {'1': 'data', '3': 4, '4': 1, '5': 12, '10': 'data'},
  ],
  '4': [ArchiveRequest_Action$json],
};

@$core.Deprecated('Use archiveRequestDescriptor instead')
const ArchiveRequest_Action$json = {
  '1': 'Action',
  '2': [
    {'1': 'ACTION_UNSPECIFIED', '2': 0},
    {'1': 'SAVE', '2': 1},
    {'1': 'LOAD', '2': 2},
    {'1': 'DELETE', '2': 3},
    {'1': 'LIST', '2': 4},
  ],
};

/// Descriptor for `ArchiveRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List archiveRequestDescriptor = $convert.base64Decode(
    'Cg5BcmNoaXZlUmVxdWVzdBIXCgdncmlkX2lkGAEgASgDUgZncmlkSWQSEgoEbmFtZRgCIAEoCV'
    'IEbmFtZRI8CgZhY3Rpb24YAyABKA4yJC52b2x2b3hncmlkLnYxLkFyY2hpdmVSZXF1ZXN0LkFj'
    'dGlvblIGYWN0aW9uEhIKBGRhdGEYBCABKAxSBGRhdGEiSgoGQWN0aW9uEhYKEkFDVElPTl9VTl'
    'NQRUNJRklFRBAAEggKBFNBVkUQARIICgRMT0FEEAISCgoGREVMRVRFEAMSCAoETElTVBAE');

@$core.Deprecated('Use archiveResponseDescriptor instead')
const ArchiveResponse$json = {
  '1': 'ArchiveResponse',
  '2': [
    {'1': 'data', '3': 1, '4': 1, '5': 12, '10': 'data'},
    {'1': 'names', '3': 2, '4': 3, '5': 9, '10': 'names'},
  ],
};

/// Descriptor for `ArchiveResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List archiveResponseDescriptor = $convert.base64Decode(
    'Cg9BcmNoaXZlUmVzcG9uc2USEgoEZGF0YRgBIAEoDFIEZGF0YRIUCgVuYW1lcxgCIAMoCVIFbm'
    'FtZXM=');

@$core.Deprecated('Use createRequestDescriptor instead')
const CreateRequest$json = {
  '1': 'CreateRequest',
  '2': [
    {'1': 'viewport_width', '3': 1, '4': 1, '5': 5, '10': 'viewportWidth'},
    {'1': 'viewport_height', '3': 2, '4': 1, '5': 5, '10': 'viewportHeight'},
    {'1': 'scale', '3': 3, '4': 1, '5': 2, '10': 'scale'},
    {
      '1': 'config',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.GridConfig',
      '10': 'config'
    },
  ],
};

/// Descriptor for `CreateRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createRequestDescriptor = $convert.base64Decode(
    'Cg1DcmVhdGVSZXF1ZXN0EiUKDnZpZXdwb3J0X3dpZHRoGAEgASgFUg12aWV3cG9ydFdpZHRoEi'
    'cKD3ZpZXdwb3J0X2hlaWdodBgCIAEoBVIOdmlld3BvcnRIZWlnaHQSFAoFc2NhbGUYAyABKAJS'
    'BXNjYWxlEjEKBmNvbmZpZxgEIAEoCzIZLnZvbHZveGdyaWQudjEuR3JpZENvbmZpZ1IGY29uZm'
    'ln');

@$core.Deprecated('Use createResponseDescriptor instead')
const CreateResponse$json = {
  '1': 'CreateResponse',
  '2': [
    {'1': 'grid_id', '3': 1, '4': 1, '5': 3, '10': 'gridId'},
    {'1': 'warnings', '3': 2, '4': 3, '5': 9, '10': 'warnings'},
  ],
};

/// Descriptor for `CreateResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createResponseDescriptor = $convert.base64Decode(
    'Cg5DcmVhdGVSZXNwb25zZRIXCgdncmlkX2lkGAEgASgDUgZncmlkSWQSGgoId2FybmluZ3MYAi'
    'ADKAlSCHdhcm5pbmdz');

@$core.Deprecated('Use destroyRequestDescriptor instead')
const DestroyRequest$json = {
  '1': 'DestroyRequest',
  '2': [
    {'1': 'grid_id', '3': 1, '4': 1, '5': 3, '10': 'gridId'},
  ],
};

/// Descriptor for `DestroyRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List destroyRequestDescriptor = $convert
    .base64Decode('Cg5EZXN0cm95UmVxdWVzdBIXCgdncmlkX2lkGAEgASgDUgZncmlkSWQ=');

@$core.Deprecated('Use getConfigRequestDescriptor instead')
const GetConfigRequest$json = {
  '1': 'GetConfigRequest',
  '2': [
    {'1': 'grid_id', '3': 1, '4': 1, '5': 3, '10': 'gridId'},
  ],
};

/// Descriptor for `GetConfigRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getConfigRequestDescriptor = $convert.base64Decode(
    'ChBHZXRDb25maWdSZXF1ZXN0EhcKB2dyaWRfaWQYASABKANSBmdyaWRJZA==');

@$core.Deprecated('Use getSchemaRequestDescriptor instead')
const GetSchemaRequest$json = {
  '1': 'GetSchemaRequest',
  '2': [
    {'1': 'grid_id', '3': 1, '4': 1, '5': 3, '10': 'gridId'},
  ],
};

/// Descriptor for `GetSchemaRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getSchemaRequestDescriptor = $convert.base64Decode(
    'ChBHZXRTY2hlbWFSZXF1ZXN0EhcKB2dyaWRfaWQYASABKANSBmdyaWRJZA==');

@$core.Deprecated('Use getSelectionRequestDescriptor instead')
const GetSelectionRequest$json = {
  '1': 'GetSelectionRequest',
  '2': [
    {'1': 'grid_id', '3': 1, '4': 1, '5': 3, '10': 'gridId'},
  ],
};

/// Descriptor for `GetSelectionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getSelectionRequestDescriptor =
    $convert.base64Decode(
        'ChNHZXRTZWxlY3Rpb25SZXF1ZXN0EhcKB2dyaWRfaWQYASABKANSBmdyaWRJZA==');

@$core.Deprecated('Use getMergedRegionsRequestDescriptor instead')
const GetMergedRegionsRequest$json = {
  '1': 'GetMergedRegionsRequest',
  '2': [
    {'1': 'grid_id', '3': 1, '4': 1, '5': 3, '10': 'gridId'},
  ],
};

/// Descriptor for `GetMergedRegionsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getMergedRegionsRequestDescriptor =
    $convert.base64Decode(
        'ChdHZXRNZXJnZWRSZWdpb25zUmVxdWVzdBIXCgdncmlkX2lkGAEgASgDUgZncmlkSWQ=');

@$core.Deprecated('Use getMemoryUsageRequestDescriptor instead')
const GetMemoryUsageRequest$json = {
  '1': 'GetMemoryUsageRequest',
  '2': [
    {'1': 'grid_id', '3': 1, '4': 1, '5': 3, '10': 'gridId'},
  ],
};

/// Descriptor for `GetMemoryUsageRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getMemoryUsageRequestDescriptor =
    $convert.base64Decode(
        'ChVHZXRNZW1vcnlVc2FnZVJlcXVlc3QSFwoHZ3JpZF9pZBgBIAEoA1IGZ3JpZElk');

@$core.Deprecated('Use refreshRequestDescriptor instead')
const RefreshRequest$json = {
  '1': 'RefreshRequest',
  '2': [
    {'1': 'grid_id', '3': 1, '4': 1, '5': 3, '10': 'gridId'},
  ],
};

/// Descriptor for `RefreshRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List refreshRequestDescriptor = $convert
    .base64Decode('Cg5SZWZyZXNoUmVxdWVzdBIXCgdncmlkX2lkGAEgASgDUgZncmlkSWQ=');

@$core.Deprecated('Use eventStreamRequestDescriptor instead')
const EventStreamRequest$json = {
  '1': 'EventStreamRequest',
  '2': [
    {'1': 'grid_id', '3': 1, '4': 1, '5': 3, '10': 'gridId'},
  ],
};

/// Descriptor for `EventStreamRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List eventStreamRequestDescriptor =
    $convert.base64Decode(
        'ChJFdmVudFN0cmVhbVJlcXVlc3QSFwoHZ3JpZF9pZBgBIAEoA1IGZ3JpZElk');

@$core.Deprecated('Use resizeViewportRequestDescriptor instead')
const ResizeViewportRequest$json = {
  '1': 'ResizeViewportRequest',
  '2': [
    {'1': 'grid_id', '3': 1, '4': 1, '5': 3, '10': 'gridId'},
    {'1': 'width', '3': 2, '4': 1, '5': 5, '10': 'width'},
    {'1': 'height', '3': 3, '4': 1, '5': 5, '10': 'height'},
  ],
};

/// Descriptor for `ResizeViewportRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List resizeViewportRequestDescriptor = $convert.base64Decode(
    'ChVSZXNpemVWaWV3cG9ydFJlcXVlc3QSFwoHZ3JpZF9pZBgBIAEoA1IGZ3JpZElkEhQKBXdpZH'
    'RoGAIgASgFUgV3aWR0aBIWCgZoZWlnaHQYAyABKAVSBmhlaWdodA==');

@$core.Deprecated('Use showCellRequestDescriptor instead')
const ShowCellRequest$json = {
  '1': 'ShowCellRequest',
  '2': [
    {'1': 'grid_id', '3': 1, '4': 1, '5': 3, '10': 'gridId'},
    {'1': 'row', '3': 2, '4': 1, '5': 5, '10': 'row'},
    {'1': 'col', '3': 3, '4': 1, '5': 5, '10': 'col'},
  ],
};

/// Descriptor for `ShowCellRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List showCellRequestDescriptor = $convert.base64Decode(
    'Cg9TaG93Q2VsbFJlcXVlc3QSFwoHZ3JpZF9pZBgBIAEoA1IGZ3JpZElkEhAKA3JvdxgCIAEoBV'
    'IDcm93EhAKA2NvbBgDIAEoBVIDY29s');

@$core.Deprecated('Use setRowRequestDescriptor instead')
const SetRowRequest$json = {
  '1': 'SetRowRequest',
  '2': [
    {'1': 'grid_id', '3': 1, '4': 1, '5': 3, '10': 'gridId'},
    {'1': 'row', '3': 2, '4': 1, '5': 5, '10': 'row'},
  ],
};

/// Descriptor for `SetRowRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setRowRequestDescriptor = $convert.base64Decode(
    'Cg1TZXRSb3dSZXF1ZXN0EhcKB2dyaWRfaWQYASABKANSBmdyaWRJZBIQCgNyb3cYAiABKAVSA3'
    'Jvdw==');

@$core.Deprecated('Use setColRequestDescriptor instead')
const SetColRequest$json = {
  '1': 'SetColRequest',
  '2': [
    {'1': 'grid_id', '3': 1, '4': 1, '5': 3, '10': 'gridId'},
    {'1': 'col', '3': 2, '4': 1, '5': 5, '10': 'col'},
  ],
};

/// Descriptor for `SetColRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setColRequestDescriptor = $convert.base64Decode(
    'Cg1TZXRDb2xSZXF1ZXN0EhcKB2dyaWRfaWQYASABKANSBmdyaWRJZBIQCgNjb2wYAiABKAVSA2'
    'NvbA==');

@$core.Deprecated('Use setRedrawRequestDescriptor instead')
const SetRedrawRequest$json = {
  '1': 'SetRedrawRequest',
  '2': [
    {'1': 'grid_id', '3': 1, '4': 1, '5': 3, '10': 'gridId'},
    {'1': 'enabled', '3': 2, '4': 1, '5': 8, '10': 'enabled'},
  ],
};

/// Descriptor for `SetRedrawRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setRedrawRequestDescriptor = $convert.base64Decode(
    'ChBTZXRSZWRyYXdSZXF1ZXN0EhcKB2dyaWRfaWQYASABKANSBmdyaWRJZBIYCgdlbmFibGVkGA'
    'IgASgIUgdlbmFibGVk');

@$core.Deprecated('Use configureRequestDescriptor instead')
const ConfigureRequest$json = {
  '1': 'ConfigureRequest',
  '2': [
    {'1': 'grid_id', '3': 1, '4': 1, '5': 3, '10': 'gridId'},
    {
      '1': 'config',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.GridConfig',
      '10': 'config'
    },
  ],
};

/// Descriptor for `ConfigureRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List configureRequestDescriptor = $convert.base64Decode(
    'ChBDb25maWd1cmVSZXF1ZXN0EhcKB2dyaWRfaWQYASABKANSBmdyaWRJZBIxCgZjb25maWcYAi'
    'ABKAsyGS52b2x2b3hncmlkLnYxLkdyaWRDb25maWdSBmNvbmZpZw==');

@$core.Deprecated('Use loadFontDataRequestDescriptor instead')
const LoadFontDataRequest$json = {
  '1': 'LoadFontDataRequest',
  '2': [
    {'1': 'data', '3': 1, '4': 1, '5': 12, '10': 'data'},
    {'1': 'font_name', '3': 2, '4': 1, '5': 9, '10': 'fontName'},
    {'1': 'font_names', '3': 3, '4': 3, '5': 9, '10': 'fontNames'},
  ],
};

/// Descriptor for `LoadFontDataRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List loadFontDataRequestDescriptor = $convert.base64Decode(
    'ChNMb2FkRm9udERhdGFSZXF1ZXN0EhIKBGRhdGEYASABKAxSBGRhdGESGwoJZm9udF9uYW1lGA'
    'IgASgJUghmb250TmFtZRIdCgpmb250X25hbWVzGAMgAygJUglmb250TmFtZXM=');

@$core.Deprecated('Use loadDemoRequestDescriptor instead')
const LoadDemoRequest$json = {
  '1': 'LoadDemoRequest',
  '2': [
    {'1': 'grid_id', '3': 1, '4': 1, '5': 3, '10': 'gridId'},
    {'1': 'demo', '3': 2, '4': 1, '5': 9, '10': 'demo'},
  ],
};

/// Descriptor for `LoadDemoRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List loadDemoRequestDescriptor = $convert.base64Decode(
    'Cg9Mb2FkRGVtb1JlcXVlc3QSFwoHZ3JpZF9pZBgBIAEoA1IGZ3JpZElkEhIKBGRlbW8YAiABKA'
    'lSBGRlbW8=');

@$core.Deprecated('Use getDemoDataRequestDescriptor instead')
const GetDemoDataRequest$json = {
  '1': 'GetDemoDataRequest',
  '2': [
    {'1': 'demo', '3': 1, '4': 1, '5': 9, '10': 'demo'},
  ],
};

/// Descriptor for `GetDemoDataRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getDemoDataRequestDescriptor = $convert
    .base64Decode('ChJHZXREZW1vRGF0YVJlcXVlc3QSEgoEZGVtbxgBIAEoCVIEZGVtbw==');

@$core.Deprecated('Use getDemoDataResponseDescriptor instead')
const GetDemoDataResponse$json = {
  '1': 'GetDemoDataResponse',
  '2': [
    {'1': 'demo', '3': 1, '4': 1, '5': 9, '10': 'demo'},
    {
      '1': 'format',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.DemoDataFormat',
      '10': 'format'
    },
    {'1': 'data', '3': 3, '4': 1, '5': 12, '10': 'data'},
  ],
};

/// Descriptor for `GetDemoDataResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getDemoDataResponseDescriptor = $convert.base64Decode(
    'ChNHZXREZW1vRGF0YVJlc3BvbnNlEhIKBGRlbW8YASABKAlSBGRlbW8SNQoGZm9ybWF0GAIgAS'
    'gOMh0udm9sdm94Z3JpZC52MS5EZW1vRGF0YUZvcm1hdFIGZm9ybWF0EhIKBGRhdGEYAyABKAxS'
    'BGRhdGE=');

@$core.Deprecated('Use destroyResponseDescriptor instead')
const DestroyResponse$json = {
  '1': 'DestroyResponse',
};

/// Descriptor for `DestroyResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List destroyResponseDescriptor =
    $convert.base64Decode('Cg9EZXN0cm95UmVzcG9uc2U=');

@$core.Deprecated('Use configureResponseDescriptor instead')
const ConfigureResponse$json = {
  '1': 'ConfigureResponse',
};

/// Descriptor for `ConfigureResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List configureResponseDescriptor =
    $convert.base64Decode('ChFDb25maWd1cmVSZXNwb25zZQ==');

@$core.Deprecated('Use loadFontDataResponseDescriptor instead')
const LoadFontDataResponse$json = {
  '1': 'LoadFontDataResponse',
};

/// Descriptor for `LoadFontDataResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List loadFontDataResponseDescriptor =
    $convert.base64Decode('ChRMb2FkRm9udERhdGFSZXNwb25zZQ==');

@$core.Deprecated('Use defineColumnsResponseDescriptor instead')
const DefineColumnsResponse$json = {
  '1': 'DefineColumnsResponse',
};

/// Descriptor for `DefineColumnsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List defineColumnsResponseDescriptor =
    $convert.base64Decode('ChVEZWZpbmVDb2x1bW5zUmVzcG9uc2U=');

@$core.Deprecated('Use defineRowsResponseDescriptor instead')
const DefineRowsResponse$json = {
  '1': 'DefineRowsResponse',
};

/// Descriptor for `DefineRowsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List defineRowsResponseDescriptor =
    $convert.base64Decode('ChJEZWZpbmVSb3dzUmVzcG9uc2U=');

@$core.Deprecated('Use insertRowsResponseDescriptor instead')
const InsertRowsResponse$json = {
  '1': 'InsertRowsResponse',
  '2': [
    {'1': 'inserted_count', '3': 1, '4': 1, '5': 5, '10': 'insertedCount'},
    {'1': 'new_row_count', '3': 2, '4': 1, '5': 5, '10': 'newRowCount'},
    {'1': 'first_row', '3': 3, '4': 1, '5': 5, '10': 'firstRow'},
  ],
};

/// Descriptor for `InsertRowsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List insertRowsResponseDescriptor = $convert.base64Decode(
    'ChJJbnNlcnRSb3dzUmVzcG9uc2USJQoOaW5zZXJ0ZWRfY291bnQYASABKAVSDWluc2VydGVkQ2'
    '91bnQSIgoNbmV3X3Jvd19jb3VudBgCIAEoBVILbmV3Um93Q291bnQSGwoJZmlyc3Rfcm93GAMg'
    'ASgFUghmaXJzdFJvdw==');

@$core.Deprecated('Use removeRowsResponseDescriptor instead')
const RemoveRowsResponse$json = {
  '1': 'RemoveRowsResponse',
  '2': [
    {'1': 'removed_count', '3': 1, '4': 1, '5': 5, '10': 'removedCount'},
    {'1': 'new_row_count', '3': 2, '4': 1, '5': 5, '10': 'newRowCount'},
  ],
};

/// Descriptor for `RemoveRowsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List removeRowsResponseDescriptor = $convert.base64Decode(
    'ChJSZW1vdmVSb3dzUmVzcG9uc2USIwoNcmVtb3ZlZF9jb3VudBgBIAEoBVIMcmVtb3ZlZENvdW'
    '50EiIKDW5ld19yb3dfY291bnQYAiABKAVSC25ld1Jvd0NvdW50');

@$core.Deprecated('Use moveColumnResponseDescriptor instead')
const MoveColumnResponse$json = {
  '1': 'MoveColumnResponse',
};

/// Descriptor for `MoveColumnResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List moveColumnResponseDescriptor =
    $convert.base64Decode('ChJNb3ZlQ29sdW1uUmVzcG9uc2U=');

@$core.Deprecated('Use moveRowResponseDescriptor instead')
const MoveRowResponse$json = {
  '1': 'MoveRowResponse',
};

/// Descriptor for `MoveRowResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List moveRowResponseDescriptor =
    $convert.base64Decode('Cg9Nb3ZlUm93UmVzcG9uc2U=');

@$core.Deprecated('Use clearResponseDescriptor instead')
const ClearResponse$json = {
  '1': 'ClearResponse',
  '2': [
    {'1': 'cleared_count', '3': 1, '4': 1, '5': 5, '10': 'clearedCount'},
  ],
};

/// Descriptor for `ClearResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List clearResponseDescriptor = $convert.base64Decode(
    'Cg1DbGVhclJlc3BvbnNlEiMKDWNsZWFyZWRfY291bnQYASABKAVSDGNsZWFyZWRDb3VudA==');

@$core.Deprecated('Use selectResponseDescriptor instead')
const SelectResponse$json = {
  '1': 'SelectResponse',
  '2': [
    {
      '1': 'selection',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.SelectionState',
      '10': 'selection'
    },
  ],
};

/// Descriptor for `SelectResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List selectResponseDescriptor = $convert.base64Decode(
    'Cg5TZWxlY3RSZXNwb25zZRI7CglzZWxlY3Rpb24YASABKAsyHS52b2x2b3hncmlkLnYxLlNlbG'
    'VjdGlvblN0YXRlUglzZWxlY3Rpb24=');

@$core.Deprecated('Use showCellResponseDescriptor instead')
const ShowCellResponse$json = {
  '1': 'ShowCellResponse',
  '2': [
    {'1': 'top_row', '3': 1, '4': 1, '5': 5, '10': 'topRow'},
    {'1': 'left_col', '3': 2, '4': 1, '5': 5, '10': 'leftCol'},
  ],
};

/// Descriptor for `ShowCellResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List showCellResponseDescriptor = $convert.base64Decode(
    'ChBTaG93Q2VsbFJlc3BvbnNlEhcKB3RvcF9yb3cYASABKAVSBnRvcFJvdxIZCghsZWZ0X2NvbB'
    'gCIAEoBVIHbGVmdENvbA==');

@$core.Deprecated('Use setTopRowResponseDescriptor instead')
const SetTopRowResponse$json = {
  '1': 'SetTopRowResponse',
  '2': [
    {'1': 'top_row', '3': 1, '4': 1, '5': 5, '10': 'topRow'},
  ],
};

/// Descriptor for `SetTopRowResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setTopRowResponseDescriptor = $convert.base64Decode(
    'ChFTZXRUb3BSb3dSZXNwb25zZRIXCgd0b3Bfcm93GAEgASgFUgZ0b3BSb3c=');

@$core.Deprecated('Use setLeftColResponseDescriptor instead')
const SetLeftColResponse$json = {
  '1': 'SetLeftColResponse',
  '2': [
    {'1': 'left_col', '3': 1, '4': 1, '5': 5, '10': 'leftCol'},
  ],
};

/// Descriptor for `SetLeftColResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setLeftColResponseDescriptor =
    $convert.base64Decode(
        'ChJTZXRMZWZ0Q29sUmVzcG9uc2USGQoIbGVmdF9jb2wYASABKAVSB2xlZnRDb2w=');

@$core.Deprecated('Use sortResponseDescriptor instead')
const SortResponse$json = {
  '1': 'SortResponse',
};

/// Descriptor for `SortResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sortResponseDescriptor =
    $convert.base64Decode('CgxTb3J0UmVzcG9uc2U=');

@$core.Deprecated('Use autoSizeResponseDescriptor instead')
const AutoSizeResponse$json = {
  '1': 'AutoSizeResponse',
};

/// Descriptor for `AutoSizeResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List autoSizeResponseDescriptor =
    $convert.base64Decode('ChBBdXRvU2l6ZVJlc3BvbnNl');

@$core.Deprecated('Use outlineResponseDescriptor instead')
const OutlineResponse$json = {
  '1': 'OutlineResponse',
};

/// Descriptor for `OutlineResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List outlineResponseDescriptor =
    $convert.base64Decode('Cg9PdXRsaW5lUmVzcG9uc2U=');

@$core.Deprecated('Use mergeCellsResponseDescriptor instead')
const MergeCellsResponse$json = {
  '1': 'MergeCellsResponse',
  '2': [
    {
      '1': 'merged',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.CellRange',
      '10': 'merged'
    },
  ],
};

/// Descriptor for `MergeCellsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List mergeCellsResponseDescriptor = $convert.base64Decode(
    'ChJNZXJnZUNlbGxzUmVzcG9uc2USMAoGbWVyZ2VkGAEgASgLMhgudm9sdm94Z3JpZC52MS5DZW'
    'xsUmFuZ2VSBm1lcmdlZA==');

@$core.Deprecated('Use unmergeCellsResponseDescriptor instead')
const UnmergeCellsResponse$json = {
  '1': 'UnmergeCellsResponse',
  '2': [
    {'1': 'unmerged_count', '3': 1, '4': 1, '5': 5, '10': 'unmergedCount'},
  ],
};

/// Descriptor for `UnmergeCellsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List unmergeCellsResponseDescriptor = $convert.base64Decode(
    'ChRVbm1lcmdlQ2VsbHNSZXNwb25zZRIlCg51bm1lcmdlZF9jb3VudBgBIAEoBVINdW5tZXJnZW'
    'RDb3VudA==');

@$core.Deprecated('Use resizeViewportResponseDescriptor instead')
const ResizeViewportResponse$json = {
  '1': 'ResizeViewportResponse',
  '2': [
    {'1': 'viewport_width', '3': 1, '4': 1, '5': 5, '10': 'viewportWidth'},
    {'1': 'viewport_height', '3': 2, '4': 1, '5': 5, '10': 'viewportHeight'},
  ],
};

/// Descriptor for `ResizeViewportResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List resizeViewportResponseDescriptor =
    $convert.base64Decode(
        'ChZSZXNpemVWaWV3cG9ydFJlc3BvbnNlEiUKDnZpZXdwb3J0X3dpZHRoGAEgASgFUg12aWV3cG'
        '9ydFdpZHRoEicKD3ZpZXdwb3J0X2hlaWdodBgCIAEoBVIOdmlld3BvcnRIZWlnaHQ=');

@$core.Deprecated('Use setRedrawResponseDescriptor instead')
const SetRedrawResponse$json = {
  '1': 'SetRedrawResponse',
};

/// Descriptor for `SetRedrawResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setRedrawResponseDescriptor =
    $convert.base64Decode('ChFTZXRSZWRyYXdSZXNwb25zZQ==');

@$core.Deprecated('Use refreshResponseDescriptor instead')
const RefreshResponse$json = {
  '1': 'RefreshResponse',
};

/// Descriptor for `RefreshResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List refreshResponseDescriptor =
    $convert.base64Decode('Cg9SZWZyZXNoUmVzcG9uc2U=');

@$core.Deprecated('Use loadDemoResponseDescriptor instead')
const LoadDemoResponse$json = {
  '1': 'LoadDemoResponse',
};

/// Descriptor for `LoadDemoResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List loadDemoResponseDescriptor =
    $convert.base64Decode('ChBMb2FkRGVtb1Jlc3BvbnNl');

@$core.Deprecated('Use renderInputDescriptor instead')
const RenderInput$json = {
  '1': 'RenderInput',
  '2': [
    {'1': 'grid_id', '3': 1, '4': 1, '5': 3, '10': 'gridId'},
    {
      '1': 'viewport',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.ViewportState',
      '9': 0,
      '10': 'viewport'
    },
    {
      '1': 'pointer',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.PointerEvent',
      '9': 0,
      '10': 'pointer'
    },
    {
      '1': 'key',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.KeyEvent',
      '9': 0,
      '10': 'key'
    },
    {
      '1': 'buffer',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.BufferReady',
      '9': 0,
      '10': 'buffer'
    },
    {
      '1': 'scroll',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.ScrollEvent',
      '9': 0,
      '10': 'scroll'
    },
    {
      '1': 'event_decision',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.EventDecision',
      '9': 0,
      '10': 'eventDecision'
    },
    {
      '1': 'zoom',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.ZoomEvent',
      '9': 0,
      '10': 'zoom'
    },
    {
      '1': 'gpu_surface',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.GpuSurfaceReady',
      '9': 0,
      '10': 'gpuSurface'
    },
    {
      '1': 'terminal_input',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.TerminalInputBytes',
      '9': 0,
      '10': 'terminalInput'
    },
    {
      '1': 'terminal_capabilities',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.TerminalCapabilities',
      '9': 0,
      '10': 'terminalCapabilities'
    },
    {
      '1': 'terminal_viewport',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.TerminalViewport',
      '9': 0,
      '10': 'terminalViewport'
    },
    {
      '1': 'terminal_command',
      '3': 13,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.TerminalCommand',
      '9': 0,
      '10': 'terminalCommand'
    },
    {
      '1': 'compare_response',
      '3': 14,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.CompareResponse',
      '9': 0,
      '10': 'compareResponse'
    },
  ],
  '8': [
    {'1': 'input'},
  ],
};

/// Descriptor for `RenderInput`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List renderInputDescriptor = $convert.base64Decode(
    'CgtSZW5kZXJJbnB1dBIXCgdncmlkX2lkGAEgASgDUgZncmlkSWQSOgoIdmlld3BvcnQYAiABKA'
    'syHC52b2x2b3hncmlkLnYxLlZpZXdwb3J0U3RhdGVIAFIIdmlld3BvcnQSNwoHcG9pbnRlchgD'
    'IAEoCzIbLnZvbHZveGdyaWQudjEuUG9pbnRlckV2ZW50SABSB3BvaW50ZXISKwoDa2V5GAQgAS'
    'gLMhcudm9sdm94Z3JpZC52MS5LZXlFdmVudEgAUgNrZXkSNAoGYnVmZmVyGAUgASgLMhoudm9s'
    'dm94Z3JpZC52MS5CdWZmZXJSZWFkeUgAUgZidWZmZXISNAoGc2Nyb2xsGAYgASgLMhoudm9sdm'
    '94Z3JpZC52MS5TY3JvbGxFdmVudEgAUgZzY3JvbGwSRQoOZXZlbnRfZGVjaXNpb24YByABKAsy'
    'HC52b2x2b3hncmlkLnYxLkV2ZW50RGVjaXNpb25IAFINZXZlbnREZWNpc2lvbhIuCgR6b29tGA'
    'ggASgLMhgudm9sdm94Z3JpZC52MS5ab29tRXZlbnRIAFIEem9vbRJBCgtncHVfc3VyZmFjZRgJ'
    'IAEoCzIeLnZvbHZveGdyaWQudjEuR3B1U3VyZmFjZVJlYWR5SABSCmdwdVN1cmZhY2USSgoOdG'
    'VybWluYWxfaW5wdXQYCiABKAsyIS52b2x2b3hncmlkLnYxLlRlcm1pbmFsSW5wdXRCeXRlc0gA'
    'Ug10ZXJtaW5hbElucHV0EloKFXRlcm1pbmFsX2NhcGFiaWxpdGllcxgLIAEoCzIjLnZvbHZveG'
    'dyaWQudjEuVGVybWluYWxDYXBhYmlsaXRpZXNIAFIUdGVybWluYWxDYXBhYmlsaXRpZXMSTgoR'
    'dGVybWluYWxfdmlld3BvcnQYDCABKAsyHy52b2x2b3hncmlkLnYxLlRlcm1pbmFsVmlld3Bvcn'
    'RIAFIQdGVybWluYWxWaWV3cG9ydBJLChB0ZXJtaW5hbF9jb21tYW5kGA0gASgLMh4udm9sdm94'
    'Z3JpZC52MS5UZXJtaW5hbENvbW1hbmRIAFIPdGVybWluYWxDb21tYW5kEksKEGNvbXBhcmVfcm'
    'VzcG9uc2UYDiABKAsyHi52b2x2b3hncmlkLnYxLkNvbXBhcmVSZXNwb25zZUgAUg9jb21wYXJl'
    'UmVzcG9uc2VCBwoFaW5wdXQ=');

@$core.Deprecated('Use compareResponseDescriptor instead')
const CompareResponse$json = {
  '1': 'CompareResponse',
  '2': [
    {'1': 'request_id', '3': 1, '4': 1, '5': 3, '10': 'requestId'},
    {'1': 'result', '3': 2, '4': 1, '5': 5, '10': 'result'},
  ],
};

/// Descriptor for `CompareResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List compareResponseDescriptor = $convert.base64Decode(
    'Cg9Db21wYXJlUmVzcG9uc2USHQoKcmVxdWVzdF9pZBgBIAEoA1IJcmVxdWVzdElkEhYKBnJlc3'
    'VsdBgCIAEoBVIGcmVzdWx0');

@$core.Deprecated('Use viewportStateDescriptor instead')
const ViewportState$json = {
  '1': 'ViewportState',
  '2': [
    {'1': 'scroll_x', '3': 1, '4': 1, '5': 2, '10': 'scrollX'},
    {'1': 'scroll_y', '3': 2, '4': 1, '5': 2, '10': 'scrollY'},
    {'1': 'width', '3': 3, '4': 1, '5': 5, '10': 'width'},
    {'1': 'height', '3': 4, '4': 1, '5': 5, '10': 'height'},
  ],
};

/// Descriptor for `ViewportState`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List viewportStateDescriptor = $convert.base64Decode(
    'Cg1WaWV3cG9ydFN0YXRlEhkKCHNjcm9sbF94GAEgASgCUgdzY3JvbGxYEhkKCHNjcm9sbF95GA'
    'IgASgCUgdzY3JvbGxZEhQKBXdpZHRoGAMgASgFUgV3aWR0aBIWCgZoZWlnaHQYBCABKAVSBmhl'
    'aWdodA==');

@$core.Deprecated('Use pointerEventDescriptor instead')
const PointerEvent$json = {
  '1': 'PointerEvent',
  '2': [
    {
      '1': 'type',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.PointerEvent.Type',
      '10': 'type'
    },
    {'1': 'x', '3': 2, '4': 1, '5': 2, '10': 'x'},
    {'1': 'y', '3': 3, '4': 1, '5': 2, '10': 'y'},
    {'1': 'modifier', '3': 4, '4': 1, '5': 5, '10': 'modifier'},
    {'1': 'button', '3': 5, '4': 1, '5': 5, '10': 'button'},
    {'1': 'dbl_click', '3': 6, '4': 1, '5': 8, '10': 'dblClick'},
  ],
  '4': [PointerEvent_Type$json],
};

@$core.Deprecated('Use pointerEventDescriptor instead')
const PointerEvent_Type$json = {
  '1': 'Type',
  '2': [
    {'1': 'TYPE_UNSPECIFIED', '2': 0},
    {'1': 'DOWN', '2': 1},
    {'1': 'UP', '2': 2},
    {'1': 'MOVE', '2': 3},
  ],
};

/// Descriptor for `PointerEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pointerEventDescriptor = $convert.base64Decode(
    'CgxQb2ludGVyRXZlbnQSNAoEdHlwZRgBIAEoDjIgLnZvbHZveGdyaWQudjEuUG9pbnRlckV2ZW'
    '50LlR5cGVSBHR5cGUSDAoBeBgCIAEoAlIBeBIMCgF5GAMgASgCUgF5EhoKCG1vZGlmaWVyGAQg'
    'ASgFUghtb2RpZmllchIWCgZidXR0b24YBSABKAVSBmJ1dHRvbhIbCglkYmxfY2xpY2sYBiABKA'
    'hSCGRibENsaWNrIjgKBFR5cGUSFAoQVFlQRV9VTlNQRUNJRklFRBAAEggKBERPV04QARIGCgJV'
    'UBACEggKBE1PVkUQAw==');

@$core.Deprecated('Use scrollEventDescriptor instead')
const ScrollEvent$json = {
  '1': 'ScrollEvent',
  '2': [
    {'1': 'delta_x', '3': 1, '4': 1, '5': 2, '10': 'deltaX'},
    {'1': 'delta_y', '3': 2, '4': 1, '5': 2, '10': 'deltaY'},
  ],
};

/// Descriptor for `ScrollEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List scrollEventDescriptor = $convert.base64Decode(
    'CgtTY3JvbGxFdmVudBIXCgdkZWx0YV94GAEgASgCUgZkZWx0YVgSFwoHZGVsdGFfeRgCIAEoAl'
    'IGZGVsdGFZ');

@$core.Deprecated('Use zoomEventDescriptor instead')
const ZoomEvent$json = {
  '1': 'ZoomEvent',
  '2': [
    {
      '1': 'phase',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.ZoomEvent.Phase',
      '10': 'phase'
    },
    {'1': 'scale', '3': 2, '4': 1, '5': 2, '10': 'scale'},
    {'1': 'focal_x_px', '3': 3, '4': 1, '5': 2, '10': 'focalXPx'},
    {'1': 'focal_y_px', '3': 4, '4': 1, '5': 2, '10': 'focalYPx'},
  ],
  '4': [ZoomEvent_Phase$json],
};

@$core.Deprecated('Use zoomEventDescriptor instead')
const ZoomEvent_Phase$json = {
  '1': 'Phase',
  '2': [
    {'1': 'ZOOM_PHASE_UNSPECIFIED', '2': 0},
    {'1': 'ZOOM_BEGIN', '2': 1},
    {'1': 'ZOOM_UPDATE', '2': 2},
    {'1': 'ZOOM_END', '2': 3},
  ],
};

/// Descriptor for `ZoomEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List zoomEventDescriptor = $convert.base64Decode(
    'Cglab29tRXZlbnQSNAoFcGhhc2UYASABKA4yHi52b2x2b3hncmlkLnYxLlpvb21FdmVudC5QaG'
    'FzZVIFcGhhc2USFAoFc2NhbGUYAiABKAJSBXNjYWxlEhwKCmZvY2FsX3hfcHgYAyABKAJSCGZv'
    'Y2FsWFB4EhwKCmZvY2FsX3lfcHgYBCABKAJSCGZvY2FsWVB4IlIKBVBoYXNlEhoKFlpPT01fUE'
    'hBU0VfVU5TUEVDSUZJRUQQABIOCgpaT09NX0JFR0lOEAESDwoLWk9PTV9VUERBVEUQAhIMCgha'
    'T09NX0VORBAD');

@$core.Deprecated('Use keyEventDescriptor instead')
const KeyEvent$json = {
  '1': 'KeyEvent',
  '2': [
    {
      '1': 'type',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.KeyEvent.Type',
      '10': 'type'
    },
    {'1': 'key_code', '3': 2, '4': 1, '5': 5, '10': 'keyCode'},
    {'1': 'modifier', '3': 3, '4': 1, '5': 5, '10': 'modifier'},
    {'1': 'character', '3': 4, '4': 1, '5': 9, '10': 'character'},
  ],
  '4': [KeyEvent_Type$json],
};

@$core.Deprecated('Use keyEventDescriptor instead')
const KeyEvent_Type$json = {
  '1': 'Type',
  '2': [
    {'1': 'KEY_TYPE_UNSPECIFIED', '2': 0},
    {'1': 'KEY_DOWN', '2': 1},
    {'1': 'KEY_UP', '2': 2},
    {'1': 'KEY_PRESS', '2': 3},
  ],
};

/// Descriptor for `KeyEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List keyEventDescriptor = $convert.base64Decode(
    'CghLZXlFdmVudBIwCgR0eXBlGAEgASgOMhwudm9sdm94Z3JpZC52MS5LZXlFdmVudC5UeXBlUg'
    'R0eXBlEhkKCGtleV9jb2RlGAIgASgFUgdrZXlDb2RlEhoKCG1vZGlmaWVyGAMgASgFUghtb2Rp'
    'ZmllchIcCgljaGFyYWN0ZXIYBCABKAlSCWNoYXJhY3RlciJJCgRUeXBlEhgKFEtFWV9UWVBFX1'
    'VOU1BFQ0lGSUVEEAASDAoIS0VZX0RPV04QARIKCgZLRVlfVVAQAhINCglLRVlfUFJFU1MQAw==');

@$core.Deprecated('Use bufferReadyDescriptor instead')
const BufferReady$json = {
  '1': 'BufferReady',
  '2': [
    {'1': 'handle', '3': 1, '4': 1, '5': 3, '10': 'handle'},
    {'1': 'stride', '3': 2, '4': 1, '5': 5, '10': 'stride'},
    {'1': 'width', '3': 3, '4': 1, '5': 5, '10': 'width'},
    {'1': 'height', '3': 4, '4': 1, '5': 5, '10': 'height'},
    {'1': 'capacity', '3': 5, '4': 1, '5': 5, '10': 'capacity'},
  ],
};

/// Descriptor for `BufferReady`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List bufferReadyDescriptor = $convert.base64Decode(
    'CgtCdWZmZXJSZWFkeRIWCgZoYW5kbGUYASABKANSBmhhbmRsZRIWCgZzdHJpZGUYAiABKAVSBn'
    'N0cmlkZRIUCgV3aWR0aBgDIAEoBVIFd2lkdGgSFgoGaGVpZ2h0GAQgASgFUgZoZWlnaHQSGgoI'
    'Y2FwYWNpdHkYBSABKAVSCGNhcGFjaXR5');

@$core.Deprecated('Use terminalInputBytesDescriptor instead')
const TerminalInputBytes$json = {
  '1': 'TerminalInputBytes',
  '2': [
    {'1': 'data', '3': 1, '4': 1, '5': 12, '10': 'data'},
  ],
};

/// Descriptor for `TerminalInputBytes`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List terminalInputBytesDescriptor = $convert
    .base64Decode('ChJUZXJtaW5hbElucHV0Qnl0ZXMSEgoEZGF0YRgBIAEoDFIEZGF0YQ==');

@$core.Deprecated('Use terminalCapabilitiesDescriptor instead')
const TerminalCapabilities$json = {
  '1': 'TerminalCapabilities',
  '2': [
    {
      '1': 'color_level',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.TerminalColorLevel',
      '10': 'colorLevel'
    },
    {'1': 'sgr_mouse', '3': 2, '4': 1, '5': 8, '10': 'sgrMouse'},
    {'1': 'focus_events', '3': 3, '4': 1, '5': 8, '10': 'focusEvents'},
    {'1': 'bracketed_paste', '3': 4, '4': 1, '5': 8, '10': 'bracketedPaste'},
  ],
};

/// Descriptor for `TerminalCapabilities`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List terminalCapabilitiesDescriptor = $convert.base64Decode(
    'ChRUZXJtaW5hbENhcGFiaWxpdGllcxJCCgtjb2xvcl9sZXZlbBgBIAEoDjIhLnZvbHZveGdyaW'
    'QudjEuVGVybWluYWxDb2xvckxldmVsUgpjb2xvckxldmVsEhsKCXNncl9tb3VzZRgCIAEoCFII'
    'c2dyTW91c2USIQoMZm9jdXNfZXZlbnRzGAMgASgIUgtmb2N1c0V2ZW50cxInCg9icmFja2V0ZW'
    'RfcGFzdGUYBCABKAhSDmJyYWNrZXRlZFBhc3Rl');

@$core.Deprecated('Use terminalViewportDescriptor instead')
const TerminalViewport$json = {
  '1': 'TerminalViewport',
  '2': [
    {'1': 'origin_x', '3': 1, '4': 1, '5': 5, '10': 'originX'},
    {'1': 'origin_y', '3': 2, '4': 1, '5': 5, '10': 'originY'},
    {'1': 'width', '3': 3, '4': 1, '5': 5, '10': 'width'},
    {'1': 'height', '3': 4, '4': 1, '5': 5, '10': 'height'},
    {'1': 'fullscreen', '3': 5, '4': 1, '5': 8, '10': 'fullscreen'},
  ],
};

/// Descriptor for `TerminalViewport`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List terminalViewportDescriptor = $convert.base64Decode(
    'ChBUZXJtaW5hbFZpZXdwb3J0EhkKCG9yaWdpbl94GAEgASgFUgdvcmlnaW5YEhkKCG9yaWdpbl'
    '95GAIgASgFUgdvcmlnaW5ZEhQKBXdpZHRoGAMgASgFUgV3aWR0aBIWCgZoZWlnaHQYBCABKAVS'
    'BmhlaWdodBIeCgpmdWxsc2NyZWVuGAUgASgIUgpmdWxsc2NyZWVu');

@$core.Deprecated('Use terminalCommandDescriptor instead')
const TerminalCommand$json = {
  '1': 'TerminalCommand',
  '2': [
    {
      '1': 'kind',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.TerminalCommand.Kind',
      '10': 'kind'
    },
  ],
  '4': [TerminalCommand_Kind$json],
};

@$core.Deprecated('Use terminalCommandDescriptor instead')
const TerminalCommand_Kind$json = {
  '1': 'Kind',
  '2': [
    {'1': 'TERMINAL_COMMAND_NONE', '2': 0},
    {'1': 'TERMINAL_COMMAND_EXIT', '2': 1},
  ],
};

/// Descriptor for `TerminalCommand`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List terminalCommandDescriptor = $convert.base64Decode(
    'Cg9UZXJtaW5hbENvbW1hbmQSNwoEa2luZBgBIAEoDjIjLnZvbHZveGdyaWQudjEuVGVybWluYW'
    'xDb21tYW5kLktpbmRSBGtpbmQiPAoES2luZBIZChVURVJNSU5BTF9DT01NQU5EX05PTkUQABIZ'
    'ChVURVJNSU5BTF9DT01NQU5EX0VYSVQQAQ==');

@$core.Deprecated('Use gpuSurfaceReadyDescriptor instead')
const GpuSurfaceReady$json = {
  '1': 'GpuSurfaceReady',
  '2': [
    {'1': 'surface_handle', '3': 1, '4': 1, '5': 3, '10': 'surfaceHandle'},
    {'1': 'width', '3': 2, '4': 1, '5': 5, '10': 'width'},
    {'1': 'height', '3': 3, '4': 1, '5': 5, '10': 'height'},
  ],
};

/// Descriptor for `GpuSurfaceReady`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List gpuSurfaceReadyDescriptor = $convert.base64Decode(
    'Cg9HcHVTdXJmYWNlUmVhZHkSJQoOc3VyZmFjZV9oYW5kbGUYASABKANSDXN1cmZhY2VIYW5kbG'
    'USFAoFd2lkdGgYAiABKAVSBXdpZHRoEhYKBmhlaWdodBgDIAEoBVIGaGVpZ2h0');

@$core.Deprecated('Use eventDecisionDescriptor instead')
const EventDecision$json = {
  '1': 'EventDecision',
  '2': [
    {'1': 'grid_id', '3': 1, '4': 1, '5': 3, '10': 'gridId'},
    {'1': 'event_id', '3': 2, '4': 1, '5': 3, '10': 'eventId'},
    {'1': 'cancel', '3': 3, '4': 1, '5': 8, '10': 'cancel'},
  ],
};

/// Descriptor for `EventDecision`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List eventDecisionDescriptor = $convert.base64Decode(
    'Cg1FdmVudERlY2lzaW9uEhcKB2dyaWRfaWQYASABKANSBmdyaWRJZBIZCghldmVudF9pZBgCIA'
    'EoA1IHZXZlbnRJZBIWCgZjYW5jZWwYAyABKAhSBmNhbmNlbA==');

@$core.Deprecated('Use renderOutputDescriptor instead')
const RenderOutput$json = {
  '1': 'RenderOutput',
  '2': [
    {'1': 'rendered', '3': 1, '4': 1, '5': 8, '10': 'rendered'},
    {
      '1': 'frame_done',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.FrameDone',
      '9': 0,
      '10': 'frameDone'
    },
    {
      '1': 'selection',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.SelectionUpdate',
      '9': 0,
      '10': 'selection'
    },
    {
      '1': 'cursor',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.CursorChange',
      '9': 0,
      '10': 'cursor'
    },
    {
      '1': 'edit_request',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.EditRequest',
      '9': 0,
      '10': 'editRequest'
    },
    {
      '1': 'dropdown_request',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.DropdownRequest',
      '9': 0,
      '10': 'dropdownRequest'
    },
    {
      '1': 'tooltip_request',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.TooltipRequest',
      '9': 0,
      '10': 'tooltipRequest'
    },
    {
      '1': 'gpu_frame_done',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.GpuFrameDone',
      '9': 0,
      '10': 'gpuFrameDone'
    },
  ],
  '8': [
    {'1': 'event'},
  ],
};

/// Descriptor for `RenderOutput`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List renderOutputDescriptor = $convert.base64Decode(
    'CgxSZW5kZXJPdXRwdXQSGgoIcmVuZGVyZWQYASABKAhSCHJlbmRlcmVkEjkKCmZyYW1lX2Rvbm'
    'UYAiABKAsyGC52b2x2b3hncmlkLnYxLkZyYW1lRG9uZUgAUglmcmFtZURvbmUSPgoJc2VsZWN0'
    'aW9uGAMgASgLMh4udm9sdm94Z3JpZC52MS5TZWxlY3Rpb25VcGRhdGVIAFIJc2VsZWN0aW9uEj'
    'UKBmN1cnNvchgEIAEoCzIbLnZvbHZveGdyaWQudjEuQ3Vyc29yQ2hhbmdlSABSBmN1cnNvchI/'
    'CgxlZGl0X3JlcXVlc3QYBSABKAsyGi52b2x2b3hncmlkLnYxLkVkaXRSZXF1ZXN0SABSC2VkaX'
    'RSZXF1ZXN0EksKEGRyb3Bkb3duX3JlcXVlc3QYBiABKAsyHi52b2x2b3hncmlkLnYxLkRyb3Bk'
    'b3duUmVxdWVzdEgAUg9kcm9wZG93blJlcXVlc3QSSAoPdG9vbHRpcF9yZXF1ZXN0GAcgASgLMh'
    '0udm9sdm94Z3JpZC52MS5Ub29sdGlwUmVxdWVzdEgAUg50b29sdGlwUmVxdWVzdBJDCg5ncHVf'
    'ZnJhbWVfZG9uZRgIIAEoCzIbLnZvbHZveGdyaWQudjEuR3B1RnJhbWVEb25lSABSDGdwdUZyYW'
    '1lRG9uZUIHCgVldmVudA==');

@$core.Deprecated('Use frameDoneDescriptor instead')
const FrameDone$json = {
  '1': 'FrameDone',
  '2': [
    {'1': 'handle', '3': 1, '4': 1, '5': 3, '10': 'handle'},
    {'1': 'dirty_x', '3': 2, '4': 1, '5': 5, '10': 'dirtyX'},
    {'1': 'dirty_y', '3': 3, '4': 1, '5': 5, '10': 'dirtyY'},
    {'1': 'dirty_w', '3': 4, '4': 1, '5': 5, '10': 'dirtyW'},
    {'1': 'dirty_h', '3': 5, '4': 1, '5': 5, '10': 'dirtyH'},
    {
      '1': 'metrics',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.FrameMetrics',
      '10': 'metrics'
    },
    {'1': 'bytes_written', '3': 7, '4': 1, '5': 5, '10': 'bytesWritten'},
    {
      '1': 'required_capacity',
      '3': 8,
      '4': 1,
      '5': 5,
      '10': 'requiredCapacity'
    },
    {
      '1': 'frame_kind',
      '3': 9,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.FrameKind',
      '10': 'frameKind'
    },
  ],
};

/// Descriptor for `FrameDone`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List frameDoneDescriptor = $convert.base64Decode(
    'CglGcmFtZURvbmUSFgoGaGFuZGxlGAEgASgDUgZoYW5kbGUSFwoHZGlydHlfeBgCIAEoBVIGZG'
    'lydHlYEhcKB2RpcnR5X3kYAyABKAVSBmRpcnR5WRIXCgdkaXJ0eV93GAQgASgFUgZkaXJ0eVcS'
    'FwoHZGlydHlfaBgFIAEoBVIGZGlydHlIEjUKB21ldHJpY3MYBiABKAsyGy52b2x2b3hncmlkLn'
    'YxLkZyYW1lTWV0cmljc1IHbWV0cmljcxIjCg1ieXRlc193cml0dGVuGAcgASgFUgxieXRlc1dy'
    'aXR0ZW4SKwoRcmVxdWlyZWRfY2FwYWNpdHkYCCABKAVSEHJlcXVpcmVkQ2FwYWNpdHkSNwoKZn'
    'JhbWVfa2luZBgJIAEoDjIYLnZvbHZveGdyaWQudjEuRnJhbWVLaW5kUglmcmFtZUtpbmQ=');

@$core.Deprecated('Use gpuFrameDoneDescriptor instead')
const GpuFrameDone$json = {
  '1': 'GpuFrameDone',
  '2': [
    {'1': 'dirty_x', '3': 1, '4': 1, '5': 5, '10': 'dirtyX'},
    {'1': 'dirty_y', '3': 2, '4': 1, '5': 5, '10': 'dirtyY'},
    {'1': 'dirty_w', '3': 3, '4': 1, '5': 5, '10': 'dirtyW'},
    {'1': 'dirty_h', '3': 4, '4': 1, '5': 5, '10': 'dirtyH'},
    {
      '1': 'metrics',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.FrameMetrics',
      '10': 'metrics'
    },
  ],
};

/// Descriptor for `GpuFrameDone`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List gpuFrameDoneDescriptor = $convert.base64Decode(
    'CgxHcHVGcmFtZURvbmUSFwoHZGlydHlfeBgBIAEoBVIGZGlydHlYEhcKB2RpcnR5X3kYAiABKA'
    'VSBmRpcnR5WRIXCgdkaXJ0eV93GAMgASgFUgZkaXJ0eVcSFwoHZGlydHlfaBgEIAEoBVIGZGly'
    'dHlIEjUKB21ldHJpY3MYBSABKAsyGy52b2x2b3hncmlkLnYxLkZyYW1lTWV0cmljc1IHbWV0cm'
    'ljcw==');

@$core.Deprecated('Use frameMetricsDescriptor instead')
const FrameMetrics$json = {
  '1': 'FrameMetrics',
  '2': [
    {'1': 'frame_time_ms', '3': 1, '4': 1, '5': 2, '10': 'frameTimeMs'},
    {'1': 'fps', '3': 2, '4': 1, '5': 2, '10': 'fps'},
    {'1': 'layer_times_us', '3': 3, '4': 3, '5': 2, '10': 'layerTimesUs'},
    {'1': 'zone_cell_counts', '3': 4, '4': 3, '5': 13, '10': 'zoneCellCounts'},
    {'1': 'instance_count', '3': 5, '4': 1, '5': 5, '10': 'instanceCount'},
  ],
};

/// Descriptor for `FrameMetrics`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List frameMetricsDescriptor = $convert.base64Decode(
    'CgxGcmFtZU1ldHJpY3MSIgoNZnJhbWVfdGltZV9tcxgBIAEoAlILZnJhbWVUaW1lTXMSEAoDZn'
    'BzGAIgASgCUgNmcHMSJAoObGF5ZXJfdGltZXNfdXMYAyADKAJSDGxheWVyVGltZXNVcxIoChB6'
    'b25lX2NlbGxfY291bnRzGAQgAygNUg56b25lQ2VsbENvdW50cxIlCg5pbnN0YW5jZV9jb3VudB'
    'gFIAEoBVINaW5zdGFuY2VDb3VudA==');

@$core.Deprecated('Use selectionUpdateDescriptor instead')
const SelectionUpdate$json = {
  '1': 'SelectionUpdate',
  '2': [
    {'1': 'active_row', '3': 1, '4': 1, '5': 5, '10': 'activeRow'},
    {'1': 'active_col', '3': 2, '4': 1, '5': 5, '10': 'activeCol'},
    {
      '1': 'ranges',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.volvoxgrid.v1.CellRange',
      '10': 'ranges'
    },
  ],
};

/// Descriptor for `SelectionUpdate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List selectionUpdateDescriptor = $convert.base64Decode(
    'Cg9TZWxlY3Rpb25VcGRhdGUSHQoKYWN0aXZlX3JvdxgBIAEoBVIJYWN0aXZlUm93Eh0KCmFjdG'
    'l2ZV9jb2wYAiABKAVSCWFjdGl2ZUNvbBIwCgZyYW5nZXMYAyADKAsyGC52b2x2b3hncmlkLnYx'
    'LkNlbGxSYW5nZVIGcmFuZ2Vz');

@$core.Deprecated('Use cursorChangeDescriptor instead')
const CursorChange$json = {
  '1': 'CursorChange',
  '2': [
    {
      '1': 'cursor',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.CursorChange.CursorType',
      '10': 'cursor'
    },
  ],
  '4': [CursorChange_CursorType$json],
};

@$core.Deprecated('Use cursorChangeDescriptor instead')
const CursorChange_CursorType$json = {
  '1': 'CursorType',
  '2': [
    {'1': 'DEFAULT', '2': 0},
    {'1': 'RESIZE_COL', '2': 1},
    {'1': 'RESIZE_ROW', '2': 2},
    {'1': 'MOVE_COL', '2': 3},
    {'1': 'TEXT', '2': 4},
    {'1': 'HAND', '2': 5},
  ],
};

/// Descriptor for `CursorChange`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cursorChangeDescriptor = $convert.base64Decode(
    'CgxDdXJzb3JDaGFuZ2USPgoGY3Vyc29yGAEgASgOMiYudm9sdm94Z3JpZC52MS5DdXJzb3JDaG'
    'FuZ2UuQ3Vyc29yVHlwZVIGY3Vyc29yIlsKCkN1cnNvclR5cGUSCwoHREVGQVVMVBAAEg4KClJF'
    'U0laRV9DT0wQARIOCgpSRVNJWkVfUk9XEAISDAoITU9WRV9DT0wQAxIICgRURVhUEAQSCAoESE'
    'FORBAF');

@$core.Deprecated('Use editRequestDescriptor instead')
const EditRequest$json = {
  '1': 'EditRequest',
  '2': [
    {'1': 'row', '3': 1, '4': 1, '5': 5, '10': 'row'},
    {'1': 'col', '3': 2, '4': 1, '5': 5, '10': 'col'},
    {'1': 'x', '3': 3, '4': 1, '5': 2, '10': 'x'},
    {'1': 'y', '3': 4, '4': 1, '5': 2, '10': 'y'},
    {'1': 'width', '3': 5, '4': 1, '5': 2, '10': 'width'},
    {'1': 'height', '3': 6, '4': 1, '5': 2, '10': 'height'},
    {'1': 'current_value', '3': 7, '4': 1, '5': 9, '10': 'currentValue'},
    {'1': 'edit_mask', '3': 8, '4': 1, '5': 9, '10': 'editMask'},
    {'1': 'max_length', '3': 9, '4': 1, '5': 5, '10': 'maxLength'},
    {'1': 'sel_start', '3': 10, '4': 1, '5': 5, '10': 'selStart'},
    {'1': 'sel_length', '3': 11, '4': 1, '5': 5, '10': 'selLength'},
    {
      '1': 'ui_mode',
      '3': 12,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.EditUiMode',
      '10': 'uiMode'
    },
  ],
};

/// Descriptor for `EditRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List editRequestDescriptor = $convert.base64Decode(
    'CgtFZGl0UmVxdWVzdBIQCgNyb3cYASABKAVSA3JvdxIQCgNjb2wYAiABKAVSA2NvbBIMCgF4GA'
    'MgASgCUgF4EgwKAXkYBCABKAJSAXkSFAoFd2lkdGgYBSABKAJSBXdpZHRoEhYKBmhlaWdodBgG'
    'IAEoAlIGaGVpZ2h0EiMKDWN1cnJlbnRfdmFsdWUYByABKAlSDGN1cnJlbnRWYWx1ZRIbCgllZG'
    'l0X21hc2sYCCABKAlSCGVkaXRNYXNrEh0KCm1heF9sZW5ndGgYCSABKAVSCW1heExlbmd0aBIb'
    'CglzZWxfc3RhcnQYCiABKAVSCHNlbFN0YXJ0Eh0KCnNlbF9sZW5ndGgYCyABKAVSCXNlbExlbm'
    'd0aBIyCgd1aV9tb2RlGAwgASgOMhkudm9sdm94Z3JpZC52MS5FZGl0VWlNb2RlUgZ1aU1vZGU=');

@$core.Deprecated('Use dropdownRequestDescriptor instead')
const DropdownRequest$json = {
  '1': 'DropdownRequest',
  '2': [
    {'1': 'row', '3': 1, '4': 1, '5': 5, '10': 'row'},
    {'1': 'col', '3': 2, '4': 1, '5': 5, '10': 'col'},
    {'1': 'x', '3': 3, '4': 1, '5': 2, '10': 'x'},
    {'1': 'y', '3': 4, '4': 1, '5': 2, '10': 'y'},
    {'1': 'width', '3': 5, '4': 1, '5': 2, '10': 'width'},
    {'1': 'height', '3': 6, '4': 1, '5': 2, '10': 'height'},
    {'1': 'items', '3': 7, '4': 3, '5': 9, '10': 'items'},
    {'1': 'selected', '3': 8, '4': 1, '5': 5, '10': 'selected'},
    {'1': 'editable', '3': 9, '4': 1, '5': 8, '10': 'editable'},
  ],
};

/// Descriptor for `DropdownRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dropdownRequestDescriptor = $convert.base64Decode(
    'Cg9Ecm9wZG93blJlcXVlc3QSEAoDcm93GAEgASgFUgNyb3cSEAoDY29sGAIgASgFUgNjb2wSDA'
    'oBeBgDIAEoAlIBeBIMCgF5GAQgASgCUgF5EhQKBXdpZHRoGAUgASgCUgV3aWR0aBIWCgZoZWln'
    'aHQYBiABKAJSBmhlaWdodBIUCgVpdGVtcxgHIAMoCVIFaXRlbXMSGgoIc2VsZWN0ZWQYCCABKA'
    'VSCHNlbGVjdGVkEhoKCGVkaXRhYmxlGAkgASgIUghlZGl0YWJsZQ==');

@$core.Deprecated('Use tooltipRequestDescriptor instead')
const TooltipRequest$json = {
  '1': 'TooltipRequest',
  '2': [
    {'1': 'x', '3': 1, '4': 1, '5': 2, '10': 'x'},
    {'1': 'y', '3': 2, '4': 1, '5': 2, '10': 'y'},
    {'1': 'text', '3': 3, '4': 1, '5': 9, '10': 'text'},
  ],
};

/// Descriptor for `TooltipRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List tooltipRequestDescriptor = $convert.base64Decode(
    'Cg5Ub29sdGlwUmVxdWVzdBIMCgF4GAEgASgCUgF4EgwKAXkYAiABKAJSAXkSEgoEdGV4dBgDIA'
    'EoCVIEdGV4dA==');

@$core.Deprecated('Use gridEventDescriptor instead')
const GridEvent$json = {
  '1': 'GridEvent',
  '2': [
    {'1': 'grid_id', '3': 1, '4': 1, '5': 3, '10': 'gridId'},
    {'1': 'event_id', '3': 100, '4': 1, '5': 3, '10': 'eventId'},
    {
      '1': 'cell_focus_changing',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.CellFocusChangingEvent',
      '9': 0,
      '10': 'cellFocusChanging'
    },
    {
      '1': 'cell_focus_changed',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.CellFocusChangedEvent',
      '9': 0,
      '10': 'cellFocusChanged'
    },
    {
      '1': 'selection_changing',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.SelectionChangingEvent',
      '9': 0,
      '10': 'selectionChanging'
    },
    {
      '1': 'selection_changed',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.SelectionChangedEvent',
      '9': 0,
      '10': 'selectionChanged'
    },
    {
      '1': 'enter_cell',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.EnterCellEvent',
      '9': 0,
      '10': 'enterCell'
    },
    {
      '1': 'leave_cell',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.LeaveCellEvent',
      '9': 0,
      '10': 'leaveCell'
    },
    {
      '1': 'before_edit',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.BeforeEditEvent',
      '9': 0,
      '10': 'beforeEdit'
    },
    {
      '1': 'start_edit',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.StartEditEvent',
      '9': 0,
      '10': 'startEdit'
    },
    {
      '1': 'after_edit',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.AfterEditEvent',
      '9': 0,
      '10': 'afterEdit'
    },
    {
      '1': 'cell_edit_validate',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.CellEditValidateEvent',
      '9': 0,
      '10': 'cellEditValidate'
    },
    {
      '1': 'cell_edit_change',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.CellEditChangeEvent',
      '9': 0,
      '10': 'cellEditChange'
    },
    {
      '1': 'key_down_edit',
      '3': 14,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.KeyDownEditEvent',
      '9': 0,
      '10': 'keyDownEdit'
    },
    {
      '1': 'key_press_edit',
      '3': 15,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.KeyPressEditEvent',
      '9': 0,
      '10': 'keyPressEdit'
    },
    {
      '1': 'key_up_edit',
      '3': 16,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.KeyUpEditEvent',
      '9': 0,
      '10': 'keyUpEdit'
    },
    {
      '1': 'cell_edit_configure_style',
      '3': 17,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.CellEditConfigureStyleEvent',
      '9': 0,
      '10': 'cellEditConfigureStyle'
    },
    {
      '1': 'cell_edit_configure_window',
      '3': 18,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.CellEditConfigureWindowEvent',
      '9': 0,
      '10': 'cellEditConfigureWindow'
    },
    {
      '1': 'dropdown_closed',
      '3': 19,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.DropdownClosedEvent',
      '9': 0,
      '10': 'dropdownClosed'
    },
    {
      '1': 'dropdown_opened',
      '3': 20,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.DropdownOpenedEvent',
      '9': 0,
      '10': 'dropdownOpened'
    },
    {
      '1': 'cell_changed',
      '3': 21,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.CellChangedEvent',
      '9': 0,
      '10': 'cellChanged'
    },
    {
      '1': 'row_status_change',
      '3': 22,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.RowStatusChangeEvent',
      '9': 0,
      '10': 'rowStatusChange'
    },
    {
      '1': 'before_sort',
      '3': 23,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.BeforeSortEvent',
      '9': 0,
      '10': 'beforeSort'
    },
    {
      '1': 'after_sort',
      '3': 24,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.AfterSortEvent',
      '9': 0,
      '10': 'afterSort'
    },
    {
      '1': 'compare',
      '3': 25,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.CompareEvent',
      '9': 0,
      '10': 'compare'
    },
    {
      '1': 'before_node_toggle',
      '3': 26,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.BeforeNodeToggleEvent',
      '9': 0,
      '10': 'beforeNodeToggle'
    },
    {
      '1': 'after_node_toggle',
      '3': 27,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.AfterNodeToggleEvent',
      '9': 0,
      '10': 'afterNodeToggle'
    },
    {
      '1': 'before_scroll',
      '3': 28,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.BeforeScrollEvent',
      '9': 0,
      '10': 'beforeScroll'
    },
    {
      '1': 'after_scroll',
      '3': 29,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.AfterScrollEvent',
      '9': 0,
      '10': 'afterScroll'
    },
    {
      '1': 'scroll_tooltip',
      '3': 30,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.ScrollTooltipEvent',
      '9': 0,
      '10': 'scrollTooltip'
    },
    {
      '1': 'before_user_resize',
      '3': 31,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.BeforeUserResizeEvent',
      '9': 0,
      '10': 'beforeUserResize'
    },
    {
      '1': 'after_user_resize',
      '3': 32,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.AfterUserResizeEvent',
      '9': 0,
      '10': 'afterUserResize'
    },
    {
      '1': 'after_user_freeze',
      '3': 33,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.AfterUserFreezeEvent',
      '9': 0,
      '10': 'afterUserFreeze'
    },
    {
      '1': 'before_move_column',
      '3': 34,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.BeforeMoveColumnEvent',
      '9': 0,
      '10': 'beforeMoveColumn'
    },
    {
      '1': 'after_move_column',
      '3': 35,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.AfterMoveColumnEvent',
      '9': 0,
      '10': 'afterMoveColumn'
    },
    {
      '1': 'before_move_row',
      '3': 36,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.BeforeMoveRowEvent',
      '9': 0,
      '10': 'beforeMoveRow'
    },
    {
      '1': 'after_move_row',
      '3': 37,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.AfterMoveRowEvent',
      '9': 0,
      '10': 'afterMoveRow'
    },
    {
      '1': 'before_mouse_down',
      '3': 38,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.BeforeMouseDownEvent',
      '9': 0,
      '10': 'beforeMouseDown'
    },
    {
      '1': 'mouse_down',
      '3': 39,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.MouseDownEvent',
      '9': 0,
      '10': 'mouseDown'
    },
    {
      '1': 'mouse_up',
      '3': 40,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.MouseUpEvent',
      '9': 0,
      '10': 'mouseUp'
    },
    {
      '1': 'mouse_move',
      '3': 41,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.MouseMoveEvent',
      '9': 0,
      '10': 'mouseMove'
    },
    {
      '1': 'click',
      '3': 42,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.ClickEvent',
      '9': 0,
      '10': 'click'
    },
    {
      '1': 'dbl_click',
      '3': 43,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.DblClickEvent',
      '9': 0,
      '10': 'dblClick'
    },
    {
      '1': 'key_down',
      '3': 44,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.KeyDownEvent',
      '9': 0,
      '10': 'keyDown'
    },
    {
      '1': 'key_press',
      '3': 45,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.KeyPressEvent',
      '9': 0,
      '10': 'keyPress'
    },
    {
      '1': 'key_up',
      '3': 46,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.KeyUpEvent',
      '9': 0,
      '10': 'keyUp'
    },
    {
      '1': 'custom_render_cell',
      '3': 47,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.CustomRenderCellEvent',
      '9': 0,
      '10': 'customRenderCell'
    },
    {
      '1': 'drag_start',
      '3': 48,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.DragStartEvent',
      '9': 0,
      '10': 'dragStart'
    },
    {
      '1': 'drag_over',
      '3': 49,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.DragOverEvent',
      '9': 0,
      '10': 'dragOver'
    },
    {
      '1': 'drag_drop',
      '3': 50,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.DragDropEvent',
      '9': 0,
      '10': 'dragDrop'
    },
    {
      '1': 'drag_complete',
      '3': 51,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.DragCompleteEvent',
      '9': 0,
      '10': 'dragComplete'
    },
    {
      '1': 'type_ahead_started',
      '3': 52,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.TypeAheadStartedEvent',
      '9': 0,
      '10': 'typeAheadStarted'
    },
    {
      '1': 'type_ahead_ended',
      '3': 53,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.TypeAheadEndedEvent',
      '9': 0,
      '10': 'typeAheadEnded'
    },
    {
      '1': 'data_refreshing',
      '3': 54,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.DataRefreshingEvent',
      '9': 0,
      '10': 'dataRefreshing'
    },
    {
      '1': 'data_refreshed',
      '3': 55,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.DataRefreshedEvent',
      '9': 0,
      '10': 'dataRefreshed'
    },
    {
      '1': 'filter_data',
      '3': 56,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.FilterDataEvent',
      '9': 0,
      '10': 'filterData'
    },
    {
      '1': 'error',
      '3': 57,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.ErrorEvent',
      '9': 0,
      '10': 'error'
    },
    {
      '1': 'before_page_break',
      '3': 58,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.BeforePageBreakEvent',
      '9': 0,
      '10': 'beforePageBreak'
    },
    {
      '1': 'start_page',
      '3': 59,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.StartPageEvent',
      '9': 0,
      '10': 'startPage'
    },
    {
      '1': 'get_header_row',
      '3': 60,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.GetHeaderRowEvent',
      '9': 0,
      '10': 'getHeaderRow'
    },
    {
      '1': 'pull_to_refresh_triggered',
      '3': 61,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.PullToRefreshTriggeredEvent',
      '9': 0,
      '10': 'pullToRefreshTriggered'
    },
    {
      '1': 'pull_to_refresh_canceled',
      '3': 62,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.PullToRefreshCanceledEvent',
      '9': 0,
      '10': 'pullToRefreshCanceled'
    },
    {
      '1': 'before_dropdown_open',
      '3': 63,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.BeforeDropdownOpenEvent',
      '9': 0,
      '10': 'beforeDropdownOpen'
    },
  ],
  '8': [
    {'1': 'event'},
  ],
};

/// Descriptor for `GridEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List gridEventDescriptor = $convert.base64Decode(
    'CglHcmlkRXZlbnQSFwoHZ3JpZF9pZBgBIAEoA1IGZ3JpZElkEhkKCGV2ZW50X2lkGGQgASgDUg'
    'dldmVudElkElcKE2NlbGxfZm9jdXNfY2hhbmdpbmcYAiABKAsyJS52b2x2b3hncmlkLnYxLkNl'
    'bGxGb2N1c0NoYW5naW5nRXZlbnRIAFIRY2VsbEZvY3VzQ2hhbmdpbmcSVAoSY2VsbF9mb2N1c1'
    '9jaGFuZ2VkGAMgASgLMiQudm9sdm94Z3JpZC52MS5DZWxsRm9jdXNDaGFuZ2VkRXZlbnRIAFIQ'
    'Y2VsbEZvY3VzQ2hhbmdlZBJWChJzZWxlY3Rpb25fY2hhbmdpbmcYBCABKAsyJS52b2x2b3hncm'
    'lkLnYxLlNlbGVjdGlvbkNoYW5naW5nRXZlbnRIAFIRc2VsZWN0aW9uQ2hhbmdpbmcSUwoRc2Vs'
    'ZWN0aW9uX2NoYW5nZWQYBSABKAsyJC52b2x2b3hncmlkLnYxLlNlbGVjdGlvbkNoYW5nZWRFdm'
    'VudEgAUhBzZWxlY3Rpb25DaGFuZ2VkEj4KCmVudGVyX2NlbGwYBiABKAsyHS52b2x2b3hncmlk'
    'LnYxLkVudGVyQ2VsbEV2ZW50SABSCWVudGVyQ2VsbBI+CgpsZWF2ZV9jZWxsGAcgASgLMh0udm'
    '9sdm94Z3JpZC52MS5MZWF2ZUNlbGxFdmVudEgAUglsZWF2ZUNlbGwSQQoLYmVmb3JlX2VkaXQY'
    'CCABKAsyHi52b2x2b3hncmlkLnYxLkJlZm9yZUVkaXRFdmVudEgAUgpiZWZvcmVFZGl0Ej4KCn'
    'N0YXJ0X2VkaXQYCSABKAsyHS52b2x2b3hncmlkLnYxLlN0YXJ0RWRpdEV2ZW50SABSCXN0YXJ0'
    'RWRpdBI+CgphZnRlcl9lZGl0GAogASgLMh0udm9sdm94Z3JpZC52MS5BZnRlckVkaXRFdmVudE'
    'gAUglhZnRlckVkaXQSVAoSY2VsbF9lZGl0X3ZhbGlkYXRlGAsgASgLMiQudm9sdm94Z3JpZC52'
    'MS5DZWxsRWRpdFZhbGlkYXRlRXZlbnRIAFIQY2VsbEVkaXRWYWxpZGF0ZRJOChBjZWxsX2VkaX'
    'RfY2hhbmdlGAwgASgLMiIudm9sdm94Z3JpZC52MS5DZWxsRWRpdENoYW5nZUV2ZW50SABSDmNl'
    'bGxFZGl0Q2hhbmdlEkUKDWtleV9kb3duX2VkaXQYDiABKAsyHy52b2x2b3hncmlkLnYxLktleU'
    'Rvd25FZGl0RXZlbnRIAFILa2V5RG93bkVkaXQSSAoOa2V5X3ByZXNzX2VkaXQYDyABKAsyIC52'
    'b2x2b3hncmlkLnYxLktleVByZXNzRWRpdEV2ZW50SABSDGtleVByZXNzRWRpdBI/CgtrZXlfdX'
    'BfZWRpdBgQIAEoCzIdLnZvbHZveGdyaWQudjEuS2V5VXBFZGl0RXZlbnRIAFIJa2V5VXBFZGl0'
    'EmcKGWNlbGxfZWRpdF9jb25maWd1cmVfc3R5bGUYESABKAsyKi52b2x2b3hncmlkLnYxLkNlbG'
    'xFZGl0Q29uZmlndXJlU3R5bGVFdmVudEgAUhZjZWxsRWRpdENvbmZpZ3VyZVN0eWxlEmoKGmNl'
    'bGxfZWRpdF9jb25maWd1cmVfd2luZG93GBIgASgLMisudm9sdm94Z3JpZC52MS5DZWxsRWRpdE'
    'NvbmZpZ3VyZVdpbmRvd0V2ZW50SABSF2NlbGxFZGl0Q29uZmlndXJlV2luZG93Ek0KD2Ryb3Bk'
    'b3duX2Nsb3NlZBgTIAEoCzIiLnZvbHZveGdyaWQudjEuRHJvcGRvd25DbG9zZWRFdmVudEgAUg'
    '5kcm9wZG93bkNsb3NlZBJNCg9kcm9wZG93bl9vcGVuZWQYFCABKAsyIi52b2x2b3hncmlkLnYx'
    'LkRyb3Bkb3duT3BlbmVkRXZlbnRIAFIOZHJvcGRvd25PcGVuZWQSRAoMY2VsbF9jaGFuZ2VkGB'
    'UgASgLMh8udm9sdm94Z3JpZC52MS5DZWxsQ2hhbmdlZEV2ZW50SABSC2NlbGxDaGFuZ2VkElEK'
    'EXJvd19zdGF0dXNfY2hhbmdlGBYgASgLMiMudm9sdm94Z3JpZC52MS5Sb3dTdGF0dXNDaGFuZ2'
    'VFdmVudEgAUg9yb3dTdGF0dXNDaGFuZ2USQQoLYmVmb3JlX3NvcnQYFyABKAsyHi52b2x2b3hn'
    'cmlkLnYxLkJlZm9yZVNvcnRFdmVudEgAUgpiZWZvcmVTb3J0Ej4KCmFmdGVyX3NvcnQYGCABKA'
    'syHS52b2x2b3hncmlkLnYxLkFmdGVyU29ydEV2ZW50SABSCWFmdGVyU29ydBI3Cgdjb21wYXJl'
    'GBkgASgLMhsudm9sdm94Z3JpZC52MS5Db21wYXJlRXZlbnRIAFIHY29tcGFyZRJUChJiZWZvcm'
    'Vfbm9kZV90b2dnbGUYGiABKAsyJC52b2x2b3hncmlkLnYxLkJlZm9yZU5vZGVUb2dnbGVFdmVu'
    'dEgAUhBiZWZvcmVOb2RlVG9nZ2xlElEKEWFmdGVyX25vZGVfdG9nZ2xlGBsgASgLMiMudm9sdm'
    '94Z3JpZC52MS5BZnRlck5vZGVUb2dnbGVFdmVudEgAUg9hZnRlck5vZGVUb2dnbGUSRwoNYmVm'
    'b3JlX3Njcm9sbBgcIAEoCzIgLnZvbHZveGdyaWQudjEuQmVmb3JlU2Nyb2xsRXZlbnRIAFIMYm'
    'Vmb3JlU2Nyb2xsEkQKDGFmdGVyX3Njcm9sbBgdIAEoCzIfLnZvbHZveGdyaWQudjEuQWZ0ZXJT'
    'Y3JvbGxFdmVudEgAUgthZnRlclNjcm9sbBJKCg5zY3JvbGxfdG9vbHRpcBgeIAEoCzIhLnZvbH'
    'ZveGdyaWQudjEuU2Nyb2xsVG9vbHRpcEV2ZW50SABSDXNjcm9sbFRvb2x0aXASVAoSYmVmb3Jl'
    'X3VzZXJfcmVzaXplGB8gASgLMiQudm9sdm94Z3JpZC52MS5CZWZvcmVVc2VyUmVzaXplRXZlbn'
    'RIAFIQYmVmb3JlVXNlclJlc2l6ZRJRChFhZnRlcl91c2VyX3Jlc2l6ZRggIAEoCzIjLnZvbHZv'
    'eGdyaWQudjEuQWZ0ZXJVc2VyUmVzaXplRXZlbnRIAFIPYWZ0ZXJVc2VyUmVzaXplElEKEWFmdG'
    'VyX3VzZXJfZnJlZXplGCEgASgLMiMudm9sdm94Z3JpZC52MS5BZnRlclVzZXJGcmVlemVFdmVu'
    'dEgAUg9hZnRlclVzZXJGcmVlemUSVAoSYmVmb3JlX21vdmVfY29sdW1uGCIgASgLMiQudm9sdm'
    '94Z3JpZC52MS5CZWZvcmVNb3ZlQ29sdW1uRXZlbnRIAFIQYmVmb3JlTW92ZUNvbHVtbhJRChFh'
    'ZnRlcl9tb3ZlX2NvbHVtbhgjIAEoCzIjLnZvbHZveGdyaWQudjEuQWZ0ZXJNb3ZlQ29sdW1uRX'
    'ZlbnRIAFIPYWZ0ZXJNb3ZlQ29sdW1uEksKD2JlZm9yZV9tb3ZlX3JvdxgkIAEoCzIhLnZvbHZv'
    'eGdyaWQudjEuQmVmb3JlTW92ZVJvd0V2ZW50SABSDWJlZm9yZU1vdmVSb3cSSAoOYWZ0ZXJfbW'
    '92ZV9yb3cYJSABKAsyIC52b2x2b3hncmlkLnYxLkFmdGVyTW92ZVJvd0V2ZW50SABSDGFmdGVy'
    'TW92ZVJvdxJRChFiZWZvcmVfbW91c2VfZG93bhgmIAEoCzIjLnZvbHZveGdyaWQudjEuQmVmb3'
    'JlTW91c2VEb3duRXZlbnRIAFIPYmVmb3JlTW91c2VEb3duEj4KCm1vdXNlX2Rvd24YJyABKAsy'
    'HS52b2x2b3hncmlkLnYxLk1vdXNlRG93bkV2ZW50SABSCW1vdXNlRG93bhI4Cghtb3VzZV91cB'
    'goIAEoCzIbLnZvbHZveGdyaWQudjEuTW91c2VVcEV2ZW50SABSB21vdXNlVXASPgoKbW91c2Vf'
    'bW92ZRgpIAEoCzIdLnZvbHZveGdyaWQudjEuTW91c2VNb3ZlRXZlbnRIAFIJbW91c2VNb3ZlEj'
    'EKBWNsaWNrGCogASgLMhkudm9sdm94Z3JpZC52MS5DbGlja0V2ZW50SABSBWNsaWNrEjsKCWRi'
    'bF9jbGljaxgrIAEoCzIcLnZvbHZveGdyaWQudjEuRGJsQ2xpY2tFdmVudEgAUghkYmxDbGljax'
    'I4CghrZXlfZG93bhgsIAEoCzIbLnZvbHZveGdyaWQudjEuS2V5RG93bkV2ZW50SABSB2tleURv'
    'd24SOwoJa2V5X3ByZXNzGC0gASgLMhwudm9sdm94Z3JpZC52MS5LZXlQcmVzc0V2ZW50SABSCG'
    'tleVByZXNzEjIKBmtleV91cBguIAEoCzIZLnZvbHZveGdyaWQudjEuS2V5VXBFdmVudEgAUgVr'
    'ZXlVcBJUChJjdXN0b21fcmVuZGVyX2NlbGwYLyABKAsyJC52b2x2b3hncmlkLnYxLkN1c3RvbV'
    'JlbmRlckNlbGxFdmVudEgAUhBjdXN0b21SZW5kZXJDZWxsEj4KCmRyYWdfc3RhcnQYMCABKAsy'
    'HS52b2x2b3hncmlkLnYxLkRyYWdTdGFydEV2ZW50SABSCWRyYWdTdGFydBI7CglkcmFnX292ZX'
    'IYMSABKAsyHC52b2x2b3hncmlkLnYxLkRyYWdPdmVyRXZlbnRIAFIIZHJhZ092ZXISOwoJZHJh'
    'Z19kcm9wGDIgASgLMhwudm9sdm94Z3JpZC52MS5EcmFnRHJvcEV2ZW50SABSCGRyYWdEcm9wEk'
    'cKDWRyYWdfY29tcGxldGUYMyABKAsyIC52b2x2b3hncmlkLnYxLkRyYWdDb21wbGV0ZUV2ZW50'
    'SABSDGRyYWdDb21wbGV0ZRJUChJ0eXBlX2FoZWFkX3N0YXJ0ZWQYNCABKAsyJC52b2x2b3hncm'
    'lkLnYxLlR5cGVBaGVhZFN0YXJ0ZWRFdmVudEgAUhB0eXBlQWhlYWRTdGFydGVkEk4KEHR5cGVf'
    'YWhlYWRfZW5kZWQYNSABKAsyIi52b2x2b3hncmlkLnYxLlR5cGVBaGVhZEVuZGVkRXZlbnRIAF'
    'IOdHlwZUFoZWFkRW5kZWQSTQoPZGF0YV9yZWZyZXNoaW5nGDYgASgLMiIudm9sdm94Z3JpZC52'
    'MS5EYXRhUmVmcmVzaGluZ0V2ZW50SABSDmRhdGFSZWZyZXNoaW5nEkoKDmRhdGFfcmVmcmVzaG'
    'VkGDcgASgLMiEudm9sdm94Z3JpZC52MS5EYXRhUmVmcmVzaGVkRXZlbnRIAFINZGF0YVJlZnJl'
    'c2hlZBJBCgtmaWx0ZXJfZGF0YRg4IAEoCzIeLnZvbHZveGdyaWQudjEuRmlsdGVyRGF0YUV2ZW'
    '50SABSCmZpbHRlckRhdGESMQoFZXJyb3IYOSABKAsyGS52b2x2b3hncmlkLnYxLkVycm9yRXZl'
    'bnRIAFIFZXJyb3ISUQoRYmVmb3JlX3BhZ2VfYnJlYWsYOiABKAsyIy52b2x2b3hncmlkLnYxLk'
    'JlZm9yZVBhZ2VCcmVha0V2ZW50SABSD2JlZm9yZVBhZ2VCcmVhaxI+CgpzdGFydF9wYWdlGDsg'
    'ASgLMh0udm9sdm94Z3JpZC52MS5TdGFydFBhZ2VFdmVudEgAUglzdGFydFBhZ2USSAoOZ2V0X2'
    'hlYWRlcl9yb3cYPCABKAsyIC52b2x2b3hncmlkLnYxLkdldEhlYWRlclJvd0V2ZW50SABSDGdl'
    'dEhlYWRlclJvdxJnChlwdWxsX3RvX3JlZnJlc2hfdHJpZ2dlcmVkGD0gASgLMioudm9sdm94Z3'
    'JpZC52MS5QdWxsVG9SZWZyZXNoVHJpZ2dlcmVkRXZlbnRIAFIWcHVsbFRvUmVmcmVzaFRyaWdn'
    'ZXJlZBJkChhwdWxsX3RvX3JlZnJlc2hfY2FuY2VsZWQYPiABKAsyKS52b2x2b3hncmlkLnYxLl'
    'B1bGxUb1JlZnJlc2hDYW5jZWxlZEV2ZW50SABSFXB1bGxUb1JlZnJlc2hDYW5jZWxlZBJaChRi'
    'ZWZvcmVfZHJvcGRvd25fb3Blbhg/IAEoCzImLnZvbHZveGdyaWQudjEuQmVmb3JlRHJvcGRvd2'
    '5PcGVuRXZlbnRIAFISYmVmb3JlRHJvcGRvd25PcGVuQgcKBWV2ZW50');

@$core.Deprecated('Use cellFocusChangingEventDescriptor instead')
const CellFocusChangingEvent$json = {
  '1': 'CellFocusChangingEvent',
  '2': [
    {'1': 'old_row', '3': 1, '4': 1, '5': 5, '10': 'oldRow'},
    {'1': 'old_col', '3': 2, '4': 1, '5': 5, '10': 'oldCol'},
    {'1': 'new_row', '3': 3, '4': 1, '5': 5, '10': 'newRow'},
    {'1': 'new_col', '3': 4, '4': 1, '5': 5, '10': 'newCol'},
  ],
};

/// Descriptor for `CellFocusChangingEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cellFocusChangingEventDescriptor = $convert.base64Decode(
    'ChZDZWxsRm9jdXNDaGFuZ2luZ0V2ZW50EhcKB29sZF9yb3cYASABKAVSBm9sZFJvdxIXCgdvbG'
    'RfY29sGAIgASgFUgZvbGRDb2wSFwoHbmV3X3JvdxgDIAEoBVIGbmV3Um93EhcKB25ld19jb2wY'
    'BCABKAVSBm5ld0NvbA==');

@$core.Deprecated('Use cellFocusChangedEventDescriptor instead')
const CellFocusChangedEvent$json = {
  '1': 'CellFocusChangedEvent',
  '2': [
    {'1': 'old_row', '3': 1, '4': 1, '5': 5, '10': 'oldRow'},
    {'1': 'old_col', '3': 2, '4': 1, '5': 5, '10': 'oldCol'},
    {'1': 'new_row', '3': 3, '4': 1, '5': 5, '10': 'newRow'},
    {'1': 'new_col', '3': 4, '4': 1, '5': 5, '10': 'newCol'},
  ],
};

/// Descriptor for `CellFocusChangedEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cellFocusChangedEventDescriptor = $convert.base64Decode(
    'ChVDZWxsRm9jdXNDaGFuZ2VkRXZlbnQSFwoHb2xkX3JvdxgBIAEoBVIGb2xkUm93EhcKB29sZF'
    '9jb2wYAiABKAVSBm9sZENvbBIXCgduZXdfcm93GAMgASgFUgZuZXdSb3cSFwoHbmV3X2NvbBgE'
    'IAEoBVIGbmV3Q29s');

@$core.Deprecated('Use selectionChangingEventDescriptor instead')
const SelectionChangingEvent$json = {
  '1': 'SelectionChangingEvent',
  '2': [
    {
      '1': 'old_ranges',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.volvoxgrid.v1.CellRange',
      '10': 'oldRanges'
    },
    {
      '1': 'new_ranges',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.volvoxgrid.v1.CellRange',
      '10': 'newRanges'
    },
    {'1': 'active_row', '3': 3, '4': 1, '5': 5, '10': 'activeRow'},
    {'1': 'active_col', '3': 4, '4': 1, '5': 5, '10': 'activeCol'},
  ],
};

/// Descriptor for `SelectionChangingEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List selectionChangingEventDescriptor = $convert.base64Decode(
    'ChZTZWxlY3Rpb25DaGFuZ2luZ0V2ZW50EjcKCm9sZF9yYW5nZXMYASADKAsyGC52b2x2b3hncm'
    'lkLnYxLkNlbGxSYW5nZVIJb2xkUmFuZ2VzEjcKCm5ld19yYW5nZXMYAiADKAsyGC52b2x2b3hn'
    'cmlkLnYxLkNlbGxSYW5nZVIJbmV3UmFuZ2VzEh0KCmFjdGl2ZV9yb3cYAyABKAVSCWFjdGl2ZV'
    'JvdxIdCgphY3RpdmVfY29sGAQgASgFUglhY3RpdmVDb2w=');

@$core.Deprecated('Use selectionChangedEventDescriptor instead')
const SelectionChangedEvent$json = {
  '1': 'SelectionChangedEvent',
  '2': [
    {
      '1': 'old_ranges',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.volvoxgrid.v1.CellRange',
      '10': 'oldRanges'
    },
    {
      '1': 'new_ranges',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.volvoxgrid.v1.CellRange',
      '10': 'newRanges'
    },
    {'1': 'active_row', '3': 3, '4': 1, '5': 5, '10': 'activeRow'},
    {'1': 'active_col', '3': 4, '4': 1, '5': 5, '10': 'activeCol'},
  ],
};

/// Descriptor for `SelectionChangedEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List selectionChangedEventDescriptor = $convert.base64Decode(
    'ChVTZWxlY3Rpb25DaGFuZ2VkRXZlbnQSNwoKb2xkX3JhbmdlcxgBIAMoCzIYLnZvbHZveGdyaW'
    'QudjEuQ2VsbFJhbmdlUglvbGRSYW5nZXMSNwoKbmV3X3JhbmdlcxgCIAMoCzIYLnZvbHZveGdy'
    'aWQudjEuQ2VsbFJhbmdlUgluZXdSYW5nZXMSHQoKYWN0aXZlX3JvdxgDIAEoBVIJYWN0aXZlUm'
    '93Eh0KCmFjdGl2ZV9jb2wYBCABKAVSCWFjdGl2ZUNvbA==');

@$core.Deprecated('Use enterCellEventDescriptor instead')
const EnterCellEvent$json = {
  '1': 'EnterCellEvent',
  '2': [
    {'1': 'row', '3': 1, '4': 1, '5': 5, '10': 'row'},
    {'1': 'col', '3': 2, '4': 1, '5': 5, '10': 'col'},
  ],
};

/// Descriptor for `EnterCellEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List enterCellEventDescriptor = $convert.base64Decode(
    'Cg5FbnRlckNlbGxFdmVudBIQCgNyb3cYASABKAVSA3JvdxIQCgNjb2wYAiABKAVSA2NvbA==');

@$core.Deprecated('Use leaveCellEventDescriptor instead')
const LeaveCellEvent$json = {
  '1': 'LeaveCellEvent',
  '2': [
    {'1': 'row', '3': 1, '4': 1, '5': 5, '10': 'row'},
    {'1': 'col', '3': 2, '4': 1, '5': 5, '10': 'col'},
  ],
};

/// Descriptor for `LeaveCellEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List leaveCellEventDescriptor = $convert.base64Decode(
    'Cg5MZWF2ZUNlbGxFdmVudBIQCgNyb3cYASABKAVSA3JvdxIQCgNjb2wYAiABKAVSA2NvbA==');

@$core.Deprecated('Use beforeEditEventDescriptor instead')
const BeforeEditEvent$json = {
  '1': 'BeforeEditEvent',
  '2': [
    {'1': 'row', '3': 1, '4': 1, '5': 5, '10': 'row'},
    {'1': 'col', '3': 2, '4': 1, '5': 5, '10': 'col'},
  ],
};

/// Descriptor for `BeforeEditEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List beforeEditEventDescriptor = $convert.base64Decode(
    'Cg9CZWZvcmVFZGl0RXZlbnQSEAoDcm93GAEgASgFUgNyb3cSEAoDY29sGAIgASgFUgNjb2w=');

@$core.Deprecated('Use startEditEventDescriptor instead')
const StartEditEvent$json = {
  '1': 'StartEditEvent',
  '2': [
    {'1': 'row', '3': 1, '4': 1, '5': 5, '10': 'row'},
    {'1': 'col', '3': 2, '4': 1, '5': 5, '10': 'col'},
  ],
};

/// Descriptor for `StartEditEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List startEditEventDescriptor = $convert.base64Decode(
    'Cg5TdGFydEVkaXRFdmVudBIQCgNyb3cYASABKAVSA3JvdxIQCgNjb2wYAiABKAVSA2NvbA==');

@$core.Deprecated('Use afterEditEventDescriptor instead')
const AfterEditEvent$json = {
  '1': 'AfterEditEvent',
  '2': [
    {'1': 'row', '3': 1, '4': 1, '5': 5, '10': 'row'},
    {'1': 'col', '3': 2, '4': 1, '5': 5, '10': 'col'},
    {'1': 'old_text', '3': 3, '4': 1, '5': 9, '10': 'oldText'},
    {'1': 'new_text', '3': 4, '4': 1, '5': 9, '10': 'newText'},
  ],
};

/// Descriptor for `AfterEditEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List afterEditEventDescriptor = $convert.base64Decode(
    'Cg5BZnRlckVkaXRFdmVudBIQCgNyb3cYASABKAVSA3JvdxIQCgNjb2wYAiABKAVSA2NvbBIZCg'
    'hvbGRfdGV4dBgDIAEoCVIHb2xkVGV4dBIZCghuZXdfdGV4dBgEIAEoCVIHbmV3VGV4dA==');

@$core.Deprecated('Use cellEditValidateEventDescriptor instead')
const CellEditValidateEvent$json = {
  '1': 'CellEditValidateEvent',
  '2': [
    {'1': 'row', '3': 1, '4': 1, '5': 5, '10': 'row'},
    {'1': 'col', '3': 2, '4': 1, '5': 5, '10': 'col'},
    {'1': 'edit_text', '3': 3, '4': 1, '5': 9, '10': 'editText'},
  ],
};

/// Descriptor for `CellEditValidateEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cellEditValidateEventDescriptor = $convert.base64Decode(
    'ChVDZWxsRWRpdFZhbGlkYXRlRXZlbnQSEAoDcm93GAEgASgFUgNyb3cSEAoDY29sGAIgASgFUg'
    'Njb2wSGwoJZWRpdF90ZXh0GAMgASgJUghlZGl0VGV4dA==');

@$core.Deprecated('Use cellEditChangeEventDescriptor instead')
const CellEditChangeEvent$json = {
  '1': 'CellEditChangeEvent',
  '2': [
    {'1': 'text', '3': 1, '4': 1, '5': 9, '10': 'text'},
  ],
};

/// Descriptor for `CellEditChangeEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cellEditChangeEventDescriptor = $convert
    .base64Decode('ChNDZWxsRWRpdENoYW5nZUV2ZW50EhIKBHRleHQYASABKAlSBHRleHQ=');

@$core.Deprecated('Use keyDownEditEventDescriptor instead')
const KeyDownEditEvent$json = {
  '1': 'KeyDownEditEvent',
  '2': [
    {'1': 'key_code', '3': 1, '4': 1, '5': 5, '10': 'keyCode'},
    {'1': 'modifier', '3': 2, '4': 1, '5': 5, '10': 'modifier'},
  ],
};

/// Descriptor for `KeyDownEditEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List keyDownEditEventDescriptor = $convert.base64Decode(
    'ChBLZXlEb3duRWRpdEV2ZW50EhkKCGtleV9jb2RlGAEgASgFUgdrZXlDb2RlEhoKCG1vZGlmaW'
    'VyGAIgASgFUghtb2RpZmllcg==');

@$core.Deprecated('Use keyPressEditEventDescriptor instead')
const KeyPressEditEvent$json = {
  '1': 'KeyPressEditEvent',
  '2': [
    {'1': 'key_ascii', '3': 1, '4': 1, '5': 5, '10': 'keyAscii'},
  ],
};

/// Descriptor for `KeyPressEditEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List keyPressEditEventDescriptor = $convert.base64Decode(
    'ChFLZXlQcmVzc0VkaXRFdmVudBIbCglrZXlfYXNjaWkYASABKAVSCGtleUFzY2lp');

@$core.Deprecated('Use keyUpEditEventDescriptor instead')
const KeyUpEditEvent$json = {
  '1': 'KeyUpEditEvent',
  '2': [
    {'1': 'key_code', '3': 1, '4': 1, '5': 5, '10': 'keyCode'},
    {'1': 'modifier', '3': 2, '4': 1, '5': 5, '10': 'modifier'},
  ],
};

/// Descriptor for `KeyUpEditEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List keyUpEditEventDescriptor = $convert.base64Decode(
    'Cg5LZXlVcEVkaXRFdmVudBIZCghrZXlfY29kZRgBIAEoBVIHa2V5Q29kZRIaCghtb2RpZmllch'
    'gCIAEoBVIIbW9kaWZpZXI=');

@$core.Deprecated('Use cellEditConfigureStyleEventDescriptor instead')
const CellEditConfigureStyleEvent$json = {
  '1': 'CellEditConfigureStyleEvent',
  '2': [
    {'1': 'row', '3': 1, '4': 1, '5': 5, '10': 'row'},
    {'1': 'col', '3': 2, '4': 1, '5': 5, '10': 'col'},
  ],
};

/// Descriptor for `CellEditConfigureStyleEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cellEditConfigureStyleEventDescriptor =
    $convert.base64Decode(
        'ChtDZWxsRWRpdENvbmZpZ3VyZVN0eWxlRXZlbnQSEAoDcm93GAEgASgFUgNyb3cSEAoDY29sGA'
        'IgASgFUgNjb2w=');

@$core.Deprecated('Use cellEditConfigureWindowEventDescriptor instead')
const CellEditConfigureWindowEvent$json = {
  '1': 'CellEditConfigureWindowEvent',
  '2': [
    {'1': 'row', '3': 1, '4': 1, '5': 5, '10': 'row'},
    {'1': 'col', '3': 2, '4': 1, '5': 5, '10': 'col'},
  ],
};

/// Descriptor for `CellEditConfigureWindowEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cellEditConfigureWindowEventDescriptor =
    $convert.base64Decode(
        'ChxDZWxsRWRpdENvbmZpZ3VyZVdpbmRvd0V2ZW50EhAKA3JvdxgBIAEoBVIDcm93EhAKA2NvbB'
        'gCIAEoBVIDY29s');

@$core.Deprecated('Use beforeDropdownOpenEventDescriptor instead')
const BeforeDropdownOpenEvent$json = {
  '1': 'BeforeDropdownOpenEvent',
  '2': [
    {'1': 'row', '3': 1, '4': 1, '5': 5, '10': 'row'},
    {'1': 'col', '3': 2, '4': 1, '5': 5, '10': 'col'},
    {'1': 'x', '3': 3, '4': 1, '5': 2, '10': 'x'},
    {'1': 'y', '3': 4, '4': 1, '5': 2, '10': 'y'},
    {'1': 'width', '3': 5, '4': 1, '5': 2, '10': 'width'},
    {'1': 'height', '3': 6, '4': 1, '5': 2, '10': 'height'},
    {
      '1': 'dropdown',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.Dropdown',
      '10': 'dropdown'
    },
    {'1': 'current_value', '3': 8, '4': 1, '5': 9, '10': 'currentValue'},
    {'1': 'selected_index', '3': 9, '4': 1, '5': 5, '10': 'selectedIndex'},
  ],
};

/// Descriptor for `BeforeDropdownOpenEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List beforeDropdownOpenEventDescriptor = $convert.base64Decode(
    'ChdCZWZvcmVEcm9wZG93bk9wZW5FdmVudBIQCgNyb3cYASABKAVSA3JvdxIQCgNjb2wYAiABKA'
    'VSA2NvbBIMCgF4GAMgASgCUgF4EgwKAXkYBCABKAJSAXkSFAoFd2lkdGgYBSABKAJSBXdpZHRo'
    'EhYKBmhlaWdodBgGIAEoAlIGaGVpZ2h0EjMKCGRyb3Bkb3duGAcgASgLMhcudm9sdm94Z3JpZC'
    '52MS5Ecm9wZG93blIIZHJvcGRvd24SIwoNY3VycmVudF92YWx1ZRgIIAEoCVIMY3VycmVudFZh'
    'bHVlEiUKDnNlbGVjdGVkX2luZGV4GAkgASgFUg1zZWxlY3RlZEluZGV4');

@$core.Deprecated('Use dropdownClosedEventDescriptor instead')
const DropdownClosedEvent$json = {
  '1': 'DropdownClosedEvent',
};

/// Descriptor for `DropdownClosedEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dropdownClosedEventDescriptor =
    $convert.base64Decode('ChNEcm9wZG93bkNsb3NlZEV2ZW50');

@$core.Deprecated('Use dropdownOpenedEventDescriptor instead')
const DropdownOpenedEvent$json = {
  '1': 'DropdownOpenedEvent',
};

/// Descriptor for `DropdownOpenedEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dropdownOpenedEventDescriptor =
    $convert.base64Decode('ChNEcm9wZG93bk9wZW5lZEV2ZW50');

@$core.Deprecated('Use cellChangedEventDescriptor instead')
const CellChangedEvent$json = {
  '1': 'CellChangedEvent',
  '2': [
    {'1': 'row', '3': 1, '4': 1, '5': 5, '10': 'row'},
    {'1': 'col', '3': 2, '4': 1, '5': 5, '10': 'col'},
    {'1': 'old_text', '3': 3, '4': 1, '5': 9, '10': 'oldText'},
    {'1': 'new_text', '3': 4, '4': 1, '5': 9, '10': 'newText'},
  ],
};

/// Descriptor for `CellChangedEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cellChangedEventDescriptor = $convert.base64Decode(
    'ChBDZWxsQ2hhbmdlZEV2ZW50EhAKA3JvdxgBIAEoBVIDcm93EhAKA2NvbBgCIAEoBVIDY29sEh'
    'kKCG9sZF90ZXh0GAMgASgJUgdvbGRUZXh0EhkKCG5ld190ZXh0GAQgASgJUgduZXdUZXh0');

@$core.Deprecated('Use rowStatusChangeEventDescriptor instead')
const RowStatusChangeEvent$json = {
  '1': 'RowStatusChangeEvent',
  '2': [
    {'1': 'row', '3': 1, '4': 1, '5': 5, '10': 'row'},
    {
      '1': 'status',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.RowStatus',
      '10': 'status'
    },
  ],
};

/// Descriptor for `RowStatusChangeEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List rowStatusChangeEventDescriptor = $convert.base64Decode(
    'ChRSb3dTdGF0dXNDaGFuZ2VFdmVudBIQCgNyb3cYASABKAVSA3JvdxIwCgZzdGF0dXMYAiABKA'
    'syGC52b2x2b3hncmlkLnYxLlJvd1N0YXR1c1IGc3RhdHVz');

@$core.Deprecated('Use beforeSortEventDescriptor instead')
const BeforeSortEvent$json = {
  '1': 'BeforeSortEvent',
  '2': [
    {'1': 'col', '3': 1, '4': 1, '5': 5, '10': 'col'},
  ],
};

/// Descriptor for `BeforeSortEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List beforeSortEventDescriptor =
    $convert.base64Decode('Cg9CZWZvcmVTb3J0RXZlbnQSEAoDY29sGAEgASgFUgNjb2w=');

@$core.Deprecated('Use afterSortEventDescriptor instead')
const AfterSortEvent$json = {
  '1': 'AfterSortEvent',
  '2': [
    {'1': 'col', '3': 1, '4': 1, '5': 5, '10': 'col'},
  ],
};

/// Descriptor for `AfterSortEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List afterSortEventDescriptor =
    $convert.base64Decode('Cg5BZnRlclNvcnRFdmVudBIQCgNjb2wYASABKAVSA2NvbA==');

@$core.Deprecated('Use compareEventDescriptor instead')
const CompareEvent$json = {
  '1': 'CompareEvent',
  '2': [
    {'1': 'request_id', '3': 1, '4': 1, '5': 3, '10': 'requestId'},
    {'1': 'row1', '3': 2, '4': 1, '5': 5, '10': 'row1'},
    {'1': 'row2', '3': 3, '4': 1, '5': 5, '10': 'row2'},
    {'1': 'col', '3': 4, '4': 1, '5': 5, '10': 'col'},
  ],
};

/// Descriptor for `CompareEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List compareEventDescriptor = $convert.base64Decode(
    'CgxDb21wYXJlRXZlbnQSHQoKcmVxdWVzdF9pZBgBIAEoA1IJcmVxdWVzdElkEhIKBHJvdzEYAi'
    'ABKAVSBHJvdzESEgoEcm93MhgDIAEoBVIEcm93MhIQCgNjb2wYBCABKAVSA2NvbA==');

@$core.Deprecated('Use beforeNodeToggleEventDescriptor instead')
const BeforeNodeToggleEvent$json = {
  '1': 'BeforeNodeToggleEvent',
  '2': [
    {'1': 'row', '3': 1, '4': 1, '5': 5, '10': 'row'},
    {'1': 'collapse', '3': 2, '4': 1, '5': 8, '10': 'collapse'},
  ],
};

/// Descriptor for `BeforeNodeToggleEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List beforeNodeToggleEventDescriptor = $convert.base64Decode(
    'ChVCZWZvcmVOb2RlVG9nZ2xlRXZlbnQSEAoDcm93GAEgASgFUgNyb3cSGgoIY29sbGFwc2UYAi'
    'ABKAhSCGNvbGxhcHNl');

@$core.Deprecated('Use afterNodeToggleEventDescriptor instead')
const AfterNodeToggleEvent$json = {
  '1': 'AfterNodeToggleEvent',
  '2': [
    {'1': 'row', '3': 1, '4': 1, '5': 5, '10': 'row'},
    {'1': 'collapse', '3': 2, '4': 1, '5': 8, '10': 'collapse'},
  ],
};

/// Descriptor for `AfterNodeToggleEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List afterNodeToggleEventDescriptor = $convert.base64Decode(
    'ChRBZnRlck5vZGVUb2dnbGVFdmVudBIQCgNyb3cYASABKAVSA3JvdxIaCghjb2xsYXBzZRgCIA'
    'EoCFIIY29sbGFwc2U=');

@$core.Deprecated('Use beforeScrollEventDescriptor instead')
const BeforeScrollEvent$json = {
  '1': 'BeforeScrollEvent',
  '2': [
    {'1': 'old_top_row', '3': 1, '4': 1, '5': 5, '10': 'oldTopRow'},
    {'1': 'old_left_col', '3': 2, '4': 1, '5': 5, '10': 'oldLeftCol'},
    {'1': 'new_top_row', '3': 3, '4': 1, '5': 5, '10': 'newTopRow'},
    {'1': 'new_left_col', '3': 4, '4': 1, '5': 5, '10': 'newLeftCol'},
  ],
};

/// Descriptor for `BeforeScrollEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List beforeScrollEventDescriptor = $convert.base64Decode(
    'ChFCZWZvcmVTY3JvbGxFdmVudBIeCgtvbGRfdG9wX3JvdxgBIAEoBVIJb2xkVG9wUm93EiAKDG'
    '9sZF9sZWZ0X2NvbBgCIAEoBVIKb2xkTGVmdENvbBIeCgtuZXdfdG9wX3JvdxgDIAEoBVIJbmV3'
    'VG9wUm93EiAKDG5ld19sZWZ0X2NvbBgEIAEoBVIKbmV3TGVmdENvbA==');

@$core.Deprecated('Use afterScrollEventDescriptor instead')
const AfterScrollEvent$json = {
  '1': 'AfterScrollEvent',
  '2': [
    {'1': 'old_top_row', '3': 1, '4': 1, '5': 5, '10': 'oldTopRow'},
    {'1': 'old_left_col', '3': 2, '4': 1, '5': 5, '10': 'oldLeftCol'},
    {'1': 'new_top_row', '3': 3, '4': 1, '5': 5, '10': 'newTopRow'},
    {'1': 'new_left_col', '3': 4, '4': 1, '5': 5, '10': 'newLeftCol'},
  ],
};

/// Descriptor for `AfterScrollEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List afterScrollEventDescriptor = $convert.base64Decode(
    'ChBBZnRlclNjcm9sbEV2ZW50Eh4KC29sZF90b3Bfcm93GAEgASgFUglvbGRUb3BSb3cSIAoMb2'
    'xkX2xlZnRfY29sGAIgASgFUgpvbGRMZWZ0Q29sEh4KC25ld190b3Bfcm93GAMgASgFUgluZXdU'
    'b3BSb3cSIAoMbmV3X2xlZnRfY29sGAQgASgFUgpuZXdMZWZ0Q29s');

@$core.Deprecated('Use scrollTooltipEventDescriptor instead')
const ScrollTooltipEvent$json = {
  '1': 'ScrollTooltipEvent',
  '2': [
    {'1': 'text', '3': 1, '4': 1, '5': 9, '10': 'text'},
  ],
};

/// Descriptor for `ScrollTooltipEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List scrollTooltipEventDescriptor = $convert
    .base64Decode('ChJTY3JvbGxUb29sdGlwRXZlbnQSEgoEdGV4dBgBIAEoCVIEdGV4dA==');

@$core.Deprecated('Use beforeUserResizeEventDescriptor instead')
const BeforeUserResizeEvent$json = {
  '1': 'BeforeUserResizeEvent',
  '2': [
    {'1': 'row', '3': 1, '4': 1, '5': 5, '10': 'row'},
    {'1': 'col', '3': 2, '4': 1, '5': 5, '10': 'col'},
  ],
};

/// Descriptor for `BeforeUserResizeEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List beforeUserResizeEventDescriptor = $convert.base64Decode(
    'ChVCZWZvcmVVc2VyUmVzaXplRXZlbnQSEAoDcm93GAEgASgFUgNyb3cSEAoDY29sGAIgASgFUg'
    'Njb2w=');

@$core.Deprecated('Use afterUserResizeEventDescriptor instead')
const AfterUserResizeEvent$json = {
  '1': 'AfterUserResizeEvent',
  '2': [
    {'1': 'row', '3': 1, '4': 1, '5': 5, '10': 'row'},
    {'1': 'col', '3': 2, '4': 1, '5': 5, '10': 'col'},
  ],
};

/// Descriptor for `AfterUserResizeEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List afterUserResizeEventDescriptor = $convert.base64Decode(
    'ChRBZnRlclVzZXJSZXNpemVFdmVudBIQCgNyb3cYASABKAVSA3JvdxIQCgNjb2wYAiABKAVSA2'
    'NvbA==');

@$core.Deprecated('Use afterUserFreezeEventDescriptor instead')
const AfterUserFreezeEvent$json = {
  '1': 'AfterUserFreezeEvent',
  '2': [
    {'1': 'frozen_rows', '3': 1, '4': 1, '5': 5, '10': 'frozenRows'},
    {'1': 'frozen_cols', '3': 2, '4': 1, '5': 5, '10': 'frozenCols'},
  ],
};

/// Descriptor for `AfterUserFreezeEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List afterUserFreezeEventDescriptor = $convert.base64Decode(
    'ChRBZnRlclVzZXJGcmVlemVFdmVudBIfCgtmcm96ZW5fcm93cxgBIAEoBVIKZnJvemVuUm93cx'
    'IfCgtmcm96ZW5fY29scxgCIAEoBVIKZnJvemVuQ29scw==');

@$core.Deprecated('Use beforeMoveColumnEventDescriptor instead')
const BeforeMoveColumnEvent$json = {
  '1': 'BeforeMoveColumnEvent',
  '2': [
    {'1': 'col', '3': 1, '4': 1, '5': 5, '10': 'col'},
    {'1': 'new_position', '3': 2, '4': 1, '5': 5, '10': 'newPosition'},
  ],
};

/// Descriptor for `BeforeMoveColumnEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List beforeMoveColumnEventDescriptor = $convert.base64Decode(
    'ChVCZWZvcmVNb3ZlQ29sdW1uRXZlbnQSEAoDY29sGAEgASgFUgNjb2wSIQoMbmV3X3Bvc2l0aW'
    '9uGAIgASgFUgtuZXdQb3NpdGlvbg==');

@$core.Deprecated('Use afterMoveColumnEventDescriptor instead')
const AfterMoveColumnEvent$json = {
  '1': 'AfterMoveColumnEvent',
  '2': [
    {'1': 'col', '3': 1, '4': 1, '5': 5, '10': 'col'},
    {'1': 'old_position', '3': 2, '4': 1, '5': 5, '10': 'oldPosition'},
  ],
};

/// Descriptor for `AfterMoveColumnEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List afterMoveColumnEventDescriptor = $convert.base64Decode(
    'ChRBZnRlck1vdmVDb2x1bW5FdmVudBIQCgNjb2wYASABKAVSA2NvbBIhCgxvbGRfcG9zaXRpb2'
    '4YAiABKAVSC29sZFBvc2l0aW9u');

@$core.Deprecated('Use beforeMoveRowEventDescriptor instead')
const BeforeMoveRowEvent$json = {
  '1': 'BeforeMoveRowEvent',
  '2': [
    {'1': 'row', '3': 1, '4': 1, '5': 5, '10': 'row'},
    {'1': 'new_position', '3': 2, '4': 1, '5': 5, '10': 'newPosition'},
  ],
};

/// Descriptor for `BeforeMoveRowEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List beforeMoveRowEventDescriptor = $convert.base64Decode(
    'ChJCZWZvcmVNb3ZlUm93RXZlbnQSEAoDcm93GAEgASgFUgNyb3cSIQoMbmV3X3Bvc2l0aW9uGA'
    'IgASgFUgtuZXdQb3NpdGlvbg==');

@$core.Deprecated('Use afterMoveRowEventDescriptor instead')
const AfterMoveRowEvent$json = {
  '1': 'AfterMoveRowEvent',
  '2': [
    {'1': 'row', '3': 1, '4': 1, '5': 5, '10': 'row'},
    {'1': 'old_position', '3': 2, '4': 1, '5': 5, '10': 'oldPosition'},
  ],
};

/// Descriptor for `AfterMoveRowEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List afterMoveRowEventDescriptor = $convert.base64Decode(
    'ChFBZnRlck1vdmVSb3dFdmVudBIQCgNyb3cYASABKAVSA3JvdxIhCgxvbGRfcG9zaXRpb24YAi'
    'ABKAVSC29sZFBvc2l0aW9u');

@$core.Deprecated('Use beforeMouseDownEventDescriptor instead')
const BeforeMouseDownEvent$json = {
  '1': 'BeforeMouseDownEvent',
  '2': [
    {'1': 'row', '3': 1, '4': 1, '5': 5, '10': 'row'},
    {'1': 'col', '3': 2, '4': 1, '5': 5, '10': 'col'},
  ],
};

/// Descriptor for `BeforeMouseDownEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List beforeMouseDownEventDescriptor = $convert.base64Decode(
    'ChRCZWZvcmVNb3VzZURvd25FdmVudBIQCgNyb3cYASABKAVSA3JvdxIQCgNjb2wYAiABKAVSA2'
    'NvbA==');

@$core.Deprecated('Use mouseDownEventDescriptor instead')
const MouseDownEvent$json = {
  '1': 'MouseDownEvent',
  '2': [
    {'1': 'button', '3': 1, '4': 1, '5': 5, '10': 'button'},
    {'1': 'modifier', '3': 2, '4': 1, '5': 5, '10': 'modifier'},
    {'1': 'x', '3': 3, '4': 1, '5': 2, '10': 'x'},
    {'1': 'y', '3': 4, '4': 1, '5': 2, '10': 'y'},
  ],
};

/// Descriptor for `MouseDownEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List mouseDownEventDescriptor = $convert.base64Decode(
    'Cg5Nb3VzZURvd25FdmVudBIWCgZidXR0b24YASABKAVSBmJ1dHRvbhIaCghtb2RpZmllchgCIA'
    'EoBVIIbW9kaWZpZXISDAoBeBgDIAEoAlIBeBIMCgF5GAQgASgCUgF5');

@$core.Deprecated('Use mouseUpEventDescriptor instead')
const MouseUpEvent$json = {
  '1': 'MouseUpEvent',
  '2': [
    {'1': 'button', '3': 1, '4': 1, '5': 5, '10': 'button'},
    {'1': 'modifier', '3': 2, '4': 1, '5': 5, '10': 'modifier'},
    {'1': 'x', '3': 3, '4': 1, '5': 2, '10': 'x'},
    {'1': 'y', '3': 4, '4': 1, '5': 2, '10': 'y'},
  ],
};

/// Descriptor for `MouseUpEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List mouseUpEventDescriptor = $convert.base64Decode(
    'CgxNb3VzZVVwRXZlbnQSFgoGYnV0dG9uGAEgASgFUgZidXR0b24SGgoIbW9kaWZpZXIYAiABKA'
    'VSCG1vZGlmaWVyEgwKAXgYAyABKAJSAXgSDAoBeRgEIAEoAlIBeQ==');

@$core.Deprecated('Use mouseMoveEventDescriptor instead')
const MouseMoveEvent$json = {
  '1': 'MouseMoveEvent',
  '2': [
    {'1': 'button', '3': 1, '4': 1, '5': 5, '10': 'button'},
    {'1': 'modifier', '3': 2, '4': 1, '5': 5, '10': 'modifier'},
    {'1': 'x', '3': 3, '4': 1, '5': 2, '10': 'x'},
    {'1': 'y', '3': 4, '4': 1, '5': 2, '10': 'y'},
  ],
};

/// Descriptor for `MouseMoveEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List mouseMoveEventDescriptor = $convert.base64Decode(
    'Cg5Nb3VzZU1vdmVFdmVudBIWCgZidXR0b24YASABKAVSBmJ1dHRvbhIaCghtb2RpZmllchgCIA'
    'EoBVIIbW9kaWZpZXISDAoBeBgDIAEoAlIBeBIMCgF5GAQgASgCUgF5');

@$core.Deprecated('Use clickEventDescriptor instead')
const ClickEvent$json = {
  '1': 'ClickEvent',
  '2': [
    {'1': 'row', '3': 1, '4': 1, '5': 5, '10': 'row'},
    {'1': 'col', '3': 2, '4': 1, '5': 5, '10': 'col'},
    {
      '1': 'hit_area',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.CellHitArea',
      '10': 'hitArea'
    },
    {
      '1': 'interaction',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.CellInteraction',
      '10': 'interaction'
    },
  ],
};

/// Descriptor for `ClickEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List clickEventDescriptor = $convert.base64Decode(
    'CgpDbGlja0V2ZW50EhAKA3JvdxgBIAEoBVIDcm93EhAKA2NvbBgCIAEoBVIDY29sEjUKCGhpdF'
    '9hcmVhGAMgASgOMhoudm9sdm94Z3JpZC52MS5DZWxsSGl0QXJlYVIHaGl0QXJlYRJACgtpbnRl'
    'cmFjdGlvbhgEIAEoDjIeLnZvbHZveGdyaWQudjEuQ2VsbEludGVyYWN0aW9uUgtpbnRlcmFjdG'
    'lvbg==');

@$core.Deprecated('Use dblClickEventDescriptor instead')
const DblClickEvent$json = {
  '1': 'DblClickEvent',
  '2': [
    {'1': 'row', '3': 1, '4': 1, '5': 5, '10': 'row'},
    {'1': 'col', '3': 2, '4': 1, '5': 5, '10': 'col'},
  ],
};

/// Descriptor for `DblClickEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dblClickEventDescriptor = $convert.base64Decode(
    'Cg1EYmxDbGlja0V2ZW50EhAKA3JvdxgBIAEoBVIDcm93EhAKA2NvbBgCIAEoBVIDY29s');

@$core.Deprecated('Use keyDownEventDescriptor instead')
const KeyDownEvent$json = {
  '1': 'KeyDownEvent',
  '2': [
    {'1': 'key_code', '3': 1, '4': 1, '5': 5, '10': 'keyCode'},
    {'1': 'modifier', '3': 2, '4': 1, '5': 5, '10': 'modifier'},
  ],
};

/// Descriptor for `KeyDownEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List keyDownEventDescriptor = $convert.base64Decode(
    'CgxLZXlEb3duRXZlbnQSGQoIa2V5X2NvZGUYASABKAVSB2tleUNvZGUSGgoIbW9kaWZpZXIYAi'
    'ABKAVSCG1vZGlmaWVy');

@$core.Deprecated('Use keyPressEventDescriptor instead')
const KeyPressEvent$json = {
  '1': 'KeyPressEvent',
  '2': [
    {'1': 'key_ascii', '3': 1, '4': 1, '5': 5, '10': 'keyAscii'},
  ],
};

/// Descriptor for `KeyPressEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List keyPressEventDescriptor = $convert.base64Decode(
    'Cg1LZXlQcmVzc0V2ZW50EhsKCWtleV9hc2NpaRgBIAEoBVIIa2V5QXNjaWk=');

@$core.Deprecated('Use keyUpEventDescriptor instead')
const KeyUpEvent$json = {
  '1': 'KeyUpEvent',
  '2': [
    {'1': 'key_code', '3': 1, '4': 1, '5': 5, '10': 'keyCode'},
    {'1': 'modifier', '3': 2, '4': 1, '5': 5, '10': 'modifier'},
  ],
};

/// Descriptor for `KeyUpEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List keyUpEventDescriptor = $convert.base64Decode(
    'CgpLZXlVcEV2ZW50EhkKCGtleV9jb2RlGAEgASgFUgdrZXlDb2RlEhoKCG1vZGlmaWVyGAIgAS'
    'gFUghtb2RpZmllcg==');

@$core.Deprecated('Use customRenderCellEventDescriptor instead')
const CustomRenderCellEvent$json = {
  '1': 'CustomRenderCellEvent',
  '2': [
    {'1': 'row', '3': 1, '4': 1, '5': 5, '10': 'row'},
    {'1': 'col', '3': 2, '4': 1, '5': 5, '10': 'col'},
    {'1': 'x', '3': 3, '4': 1, '5': 2, '10': 'x'},
    {'1': 'y', '3': 4, '4': 1, '5': 2, '10': 'y'},
    {'1': 'width', '3': 5, '4': 1, '5': 2, '10': 'width'},
    {'1': 'height', '3': 6, '4': 1, '5': 2, '10': 'height'},
    {'1': 'text', '3': 7, '4': 1, '5': 9, '10': 'text'},
    {
      '1': 'style',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.CellStyle',
      '10': 'style'
    },
    {'1': 'done', '3': 9, '4': 1, '5': 8, '10': 'done'},
  ],
};

/// Descriptor for `CustomRenderCellEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List customRenderCellEventDescriptor = $convert.base64Decode(
    'ChVDdXN0b21SZW5kZXJDZWxsRXZlbnQSEAoDcm93GAEgASgFUgNyb3cSEAoDY29sGAIgASgFUg'
    'Njb2wSDAoBeBgDIAEoAlIBeBIMCgF5GAQgASgCUgF5EhQKBXdpZHRoGAUgASgCUgV3aWR0aBIW'
    'CgZoZWlnaHQYBiABKAJSBmhlaWdodBISCgR0ZXh0GAcgASgJUgR0ZXh0Ei4KBXN0eWxlGAggAS'
    'gLMhgudm9sdm94Z3JpZC52MS5DZWxsU3R5bGVSBXN0eWxlEhIKBGRvbmUYCSABKAhSBGRvbmU=');

@$core.Deprecated('Use dragStartEventDescriptor instead')
const DragStartEvent$json = {
  '1': 'DragStartEvent',
  '2': [
    {'1': 'row', '3': 1, '4': 1, '5': 5, '10': 'row'},
    {'1': 'col', '3': 2, '4': 1, '5': 5, '10': 'col'},
  ],
};

/// Descriptor for `DragStartEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dragStartEventDescriptor = $convert.base64Decode(
    'Cg5EcmFnU3RhcnRFdmVudBIQCgNyb3cYASABKAVSA3JvdxIQCgNjb2wYAiABKAVSA2NvbA==');

@$core.Deprecated('Use dragOverEventDescriptor instead')
const DragOverEvent$json = {
  '1': 'DragOverEvent',
  '2': [
    {'1': 'row', '3': 1, '4': 1, '5': 5, '10': 'row'},
    {'1': 'col', '3': 2, '4': 1, '5': 5, '10': 'col'},
    {'1': 'x', '3': 3, '4': 1, '5': 2, '10': 'x'},
    {'1': 'y', '3': 4, '4': 1, '5': 2, '10': 'y'},
  ],
};

/// Descriptor for `DragOverEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dragOverEventDescriptor = $convert.base64Decode(
    'Cg1EcmFnT3ZlckV2ZW50EhAKA3JvdxgBIAEoBVIDcm93EhAKA2NvbBgCIAEoBVIDY29sEgwKAX'
    'gYAyABKAJSAXgSDAoBeRgEIAEoAlIBeQ==');

@$core.Deprecated('Use dragDropEventDescriptor instead')
const DragDropEvent$json = {
  '1': 'DragDropEvent',
  '2': [
    {'1': 'row', '3': 1, '4': 1, '5': 5, '10': 'row'},
    {'1': 'col', '3': 2, '4': 1, '5': 5, '10': 'col'},
  ],
};

/// Descriptor for `DragDropEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dragDropEventDescriptor = $convert.base64Decode(
    'Cg1EcmFnRHJvcEV2ZW50EhAKA3JvdxgBIAEoBVIDcm93EhAKA2NvbBgCIAEoBVIDY29s');

@$core.Deprecated('Use dragCompleteEventDescriptor instead')
const DragCompleteEvent$json = {
  '1': 'DragCompleteEvent',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
  ],
};

/// Descriptor for `DragCompleteEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dragCompleteEventDescriptor = $convert.base64Decode(
    'ChFEcmFnQ29tcGxldGVFdmVudBIYCgdzdWNjZXNzGAEgASgIUgdzdWNjZXNz');

@$core.Deprecated('Use typeAheadStartedEventDescriptor instead')
const TypeAheadStartedEvent$json = {
  '1': 'TypeAheadStartedEvent',
  '2': [
    {'1': 'col', '3': 1, '4': 1, '5': 5, '10': 'col'},
    {'1': 'text', '3': 2, '4': 1, '5': 9, '10': 'text'},
  ],
};

/// Descriptor for `TypeAheadStartedEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List typeAheadStartedEventDescriptor = $convert.base64Decode(
    'ChVUeXBlQWhlYWRTdGFydGVkRXZlbnQSEAoDY29sGAEgASgFUgNjb2wSEgoEdGV4dBgCIAEoCV'
    'IEdGV4dA==');

@$core.Deprecated('Use typeAheadEndedEventDescriptor instead')
const TypeAheadEndedEvent$json = {
  '1': 'TypeAheadEndedEvent',
};

/// Descriptor for `TypeAheadEndedEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List typeAheadEndedEventDescriptor =
    $convert.base64Decode('ChNUeXBlQWhlYWRFbmRlZEV2ZW50');

@$core.Deprecated('Use dataRefreshingEventDescriptor instead')
const DataRefreshingEvent$json = {
  '1': 'DataRefreshingEvent',
};

/// Descriptor for `DataRefreshingEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dataRefreshingEventDescriptor =
    $convert.base64Decode('ChNEYXRhUmVmcmVzaGluZ0V2ZW50');

@$core.Deprecated('Use dataRefreshedEventDescriptor instead')
const DataRefreshedEvent$json = {
  '1': 'DataRefreshedEvent',
};

/// Descriptor for `DataRefreshedEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dataRefreshedEventDescriptor =
    $convert.base64Decode('ChJEYXRhUmVmcmVzaGVkRXZlbnQ=');

@$core.Deprecated('Use filterDataEventDescriptor instead')
const FilterDataEvent$json = {
  '1': 'FilterDataEvent',
  '2': [
    {'1': 'row', '3': 1, '4': 1, '5': 5, '10': 'row'},
    {'1': 'col', '3': 2, '4': 1, '5': 5, '10': 'col'},
    {'1': 'text', '3': 3, '4': 1, '5': 9, '10': 'text'},
  ],
};

/// Descriptor for `FilterDataEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List filterDataEventDescriptor = $convert.base64Decode(
    'Cg9GaWx0ZXJEYXRhRXZlbnQSEAoDcm93GAEgASgFUgNyb3cSEAoDY29sGAIgASgFUgNjb2wSEg'
    'oEdGV4dBgDIAEoCVIEdGV4dA==');

@$core.Deprecated('Use pullToRefreshTriggeredEventDescriptor instead')
const PullToRefreshTriggeredEvent$json = {
  '1': 'PullToRefreshTriggeredEvent',
};

/// Descriptor for `PullToRefreshTriggeredEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pullToRefreshTriggeredEventDescriptor =
    $convert.base64Decode('ChtQdWxsVG9SZWZyZXNoVHJpZ2dlcmVkRXZlbnQ=');

@$core.Deprecated('Use pullToRefreshCanceledEventDescriptor instead')
const PullToRefreshCanceledEvent$json = {
  '1': 'PullToRefreshCanceledEvent',
};

/// Descriptor for `PullToRefreshCanceledEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pullToRefreshCanceledEventDescriptor =
    $convert.base64Decode('ChpQdWxsVG9SZWZyZXNoQ2FuY2VsZWRFdmVudA==');

@$core.Deprecated('Use errorEventDescriptor instead')
const ErrorEvent$json = {
  '1': 'ErrorEvent',
  '2': [
    {'1': 'code', '3': 1, '4': 1, '5': 5, '10': 'code'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `ErrorEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List errorEventDescriptor = $convert.base64Decode(
    'CgpFcnJvckV2ZW50EhIKBGNvZGUYASABKAVSBGNvZGUSGAoHbWVzc2FnZRgCIAEoCVIHbWVzc2'
    'FnZQ==');

@$core.Deprecated('Use beforePageBreakEventDescriptor instead')
const BeforePageBreakEvent$json = {
  '1': 'BeforePageBreakEvent',
  '2': [
    {'1': 'row', '3': 1, '4': 1, '5': 5, '10': 'row'},
  ],
};

/// Descriptor for `BeforePageBreakEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List beforePageBreakEventDescriptor = $convert
    .base64Decode('ChRCZWZvcmVQYWdlQnJlYWtFdmVudBIQCgNyb3cYASABKAVSA3Jvdw==');

@$core.Deprecated('Use startPageEventDescriptor instead')
const StartPageEvent$json = {
  '1': 'StartPageEvent',
  '2': [
    {'1': 'page', '3': 1, '4': 1, '5': 5, '10': 'page'},
  ],
};

/// Descriptor for `StartPageEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List startPageEventDescriptor =
    $convert.base64Decode('Cg5TdGFydFBhZ2VFdmVudBISCgRwYWdlGAEgASgFUgRwYWdl');

@$core.Deprecated('Use getHeaderRowEventDescriptor instead')
const GetHeaderRowEvent$json = {
  '1': 'GetHeaderRowEvent',
  '2': [
    {'1': 'page', '3': 1, '4': 1, '5': 5, '10': 'page'},
  ],
};

/// Descriptor for `GetHeaderRowEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getHeaderRowEventDescriptor = $convert
    .base64Decode('ChFHZXRIZWFkZXJSb3dFdmVudBISCgRwYWdlGAEgASgFUgRwYWdl');

const $core.Map<$core.String, $core.dynamic> VolvoxGridServiceBase$json = {
  '1': 'VolvoxGridService',
  '2': [
    {
      '1': 'Create',
      '2': '.volvoxgrid.v1.CreateRequest',
      '3': '.volvoxgrid.v1.CreateResponse'
    },
    {
      '1': 'Destroy',
      '2': '.volvoxgrid.v1.DestroyRequest',
      '3': '.volvoxgrid.v1.DestroyResponse'
    },
    {
      '1': 'Configure',
      '2': '.volvoxgrid.v1.ConfigureRequest',
      '3': '.volvoxgrid.v1.ConfigureResponse'
    },
    {
      '1': 'GetConfig',
      '2': '.volvoxgrid.v1.GetConfigRequest',
      '3': '.volvoxgrid.v1.GridConfig'
    },
    {
      '1': 'LoadFontData',
      '2': '.volvoxgrid.v1.LoadFontDataRequest',
      '3': '.volvoxgrid.v1.LoadFontDataResponse'
    },
    {
      '1': 'DefineColumns',
      '2': '.volvoxgrid.v1.DefineColumnsRequest',
      '3': '.volvoxgrid.v1.DefineColumnsResponse'
    },
    {
      '1': 'GetSchema',
      '2': '.volvoxgrid.v1.GetSchemaRequest',
      '3': '.volvoxgrid.v1.SchemaResponse'
    },
    {
      '1': 'DefineRows',
      '2': '.volvoxgrid.v1.DefineRowsRequest',
      '3': '.volvoxgrid.v1.DefineRowsResponse'
    },
    {
      '1': 'InsertRows',
      '2': '.volvoxgrid.v1.InsertRowsRequest',
      '3': '.volvoxgrid.v1.InsertRowsResponse'
    },
    {
      '1': 'RemoveRows',
      '2': '.volvoxgrid.v1.RemoveRowsRequest',
      '3': '.volvoxgrid.v1.RemoveRowsResponse'
    },
    {
      '1': 'MoveColumn',
      '2': '.volvoxgrid.v1.MoveColumnRequest',
      '3': '.volvoxgrid.v1.MoveColumnResponse'
    },
    {
      '1': 'MoveRow',
      '2': '.volvoxgrid.v1.MoveRowRequest',
      '3': '.volvoxgrid.v1.MoveRowResponse'
    },
    {
      '1': 'UpdateCells',
      '2': '.volvoxgrid.v1.UpdateCellsRequest',
      '3': '.volvoxgrid.v1.WriteResult'
    },
    {
      '1': 'GetCells',
      '2': '.volvoxgrid.v1.GetCellsRequest',
      '3': '.volvoxgrid.v1.CellsResponse'
    },
    {
      '1': 'LoadTable',
      '2': '.volvoxgrid.v1.LoadTableRequest',
      '3': '.volvoxgrid.v1.WriteResult'
    },
    {
      '1': 'LoadData',
      '2': '.volvoxgrid.v1.LoadDataRequest',
      '3': '.volvoxgrid.v1.LoadDataResult'
    },
    {
      '1': 'Clear',
      '2': '.volvoxgrid.v1.ClearRequest',
      '3': '.volvoxgrid.v1.ClearResponse'
    },
    {
      '1': 'Select',
      '2': '.volvoxgrid.v1.SelectRequest',
      '3': '.volvoxgrid.v1.SelectResponse'
    },
    {
      '1': 'GetSelection',
      '2': '.volvoxgrid.v1.GetSelectionRequest',
      '3': '.volvoxgrid.v1.SelectionState'
    },
    {
      '1': 'ShowCell',
      '2': '.volvoxgrid.v1.ShowCellRequest',
      '3': '.volvoxgrid.v1.ShowCellResponse'
    },
    {
      '1': 'SetTopRow',
      '2': '.volvoxgrid.v1.SetRowRequest',
      '3': '.volvoxgrid.v1.SetTopRowResponse'
    },
    {
      '1': 'SetLeftCol',
      '2': '.volvoxgrid.v1.SetColRequest',
      '3': '.volvoxgrid.v1.SetLeftColResponse'
    },
    {
      '1': 'Edit',
      '2': '.volvoxgrid.v1.EditCommand',
      '3': '.volvoxgrid.v1.EditState'
    },
    {
      '1': 'Sort',
      '2': '.volvoxgrid.v1.SortRequest',
      '3': '.volvoxgrid.v1.SortResponse'
    },
    {
      '1': 'Subtotal',
      '2': '.volvoxgrid.v1.SubtotalRequest',
      '3': '.volvoxgrid.v1.SubtotalResult'
    },
    {
      '1': 'AutoSize',
      '2': '.volvoxgrid.v1.AutoSizeRequest',
      '3': '.volvoxgrid.v1.AutoSizeResponse'
    },
    {
      '1': 'Outline',
      '2': '.volvoxgrid.v1.OutlineRequest',
      '3': '.volvoxgrid.v1.OutlineResponse'
    },
    {
      '1': 'GetNode',
      '2': '.volvoxgrid.v1.GetNodeRequest',
      '3': '.volvoxgrid.v1.NodeInfo'
    },
    {
      '1': 'Find',
      '2': '.volvoxgrid.v1.FindRequest',
      '3': '.volvoxgrid.v1.FindResponse'
    },
    {
      '1': 'Aggregate',
      '2': '.volvoxgrid.v1.AggregateRequest',
      '3': '.volvoxgrid.v1.AggregateResponse'
    },
    {
      '1': 'GetMergedRange',
      '2': '.volvoxgrid.v1.GetMergedRangeRequest',
      '3': '.volvoxgrid.v1.CellRange'
    },
    {
      '1': 'MergeCells',
      '2': '.volvoxgrid.v1.MergeCellsRequest',
      '3': '.volvoxgrid.v1.MergeCellsResponse'
    },
    {
      '1': 'UnmergeCells',
      '2': '.volvoxgrid.v1.UnmergeCellsRequest',
      '3': '.volvoxgrid.v1.UnmergeCellsResponse'
    },
    {
      '1': 'GetMergedRegions',
      '2': '.volvoxgrid.v1.GetMergedRegionsRequest',
      '3': '.volvoxgrid.v1.MergedRegionsResponse'
    },
    {
      '1': 'GetMemoryUsage',
      '2': '.volvoxgrid.v1.GetMemoryUsageRequest',
      '3': '.volvoxgrid.v1.MemoryUsageResponse'
    },
    {
      '1': 'Clipboard',
      '2': '.volvoxgrid.v1.ClipboardCommand',
      '3': '.volvoxgrid.v1.ClipboardResponse'
    },
    {
      '1': 'Export',
      '2': '.volvoxgrid.v1.ExportRequest',
      '3': '.volvoxgrid.v1.ExportResponse'
    },
    {
      '1': 'Print',
      '2': '.volvoxgrid.v1.PrintRequest',
      '3': '.volvoxgrid.v1.PrintResponse'
    },
    {
      '1': 'Archive',
      '2': '.volvoxgrid.v1.ArchiveRequest',
      '3': '.volvoxgrid.v1.ArchiveResponse'
    },
    {
      '1': 'ResizeViewport',
      '2': '.volvoxgrid.v1.ResizeViewportRequest',
      '3': '.volvoxgrid.v1.ResizeViewportResponse'
    },
    {
      '1': 'SetRedraw',
      '2': '.volvoxgrid.v1.SetRedrawRequest',
      '3': '.volvoxgrid.v1.SetRedrawResponse'
    },
    {
      '1': 'Refresh',
      '2': '.volvoxgrid.v1.RefreshRequest',
      '3': '.volvoxgrid.v1.RefreshResponse'
    },
    {
      '1': 'LoadDemo',
      '2': '.volvoxgrid.v1.LoadDemoRequest',
      '3': '.volvoxgrid.v1.LoadDemoResponse'
    },
    {
      '1': 'GetDemoData',
      '2': '.volvoxgrid.v1.GetDemoDataRequest',
      '3': '.volvoxgrid.v1.GetDemoDataResponse'
    },
    {
      '1': 'RenderSession',
      '2': '.volvoxgrid.v1.RenderInput',
      '3': '.volvoxgrid.v1.RenderOutput',
      '5': true,
      '6': true
    },
    {
      '1': 'EventStream',
      '2': '.volvoxgrid.v1.EventStreamRequest',
      '3': '.volvoxgrid.v1.GridEvent',
      '6': true
    },
  ],
};

@$core.Deprecated('Use volvoxGridServiceDescriptor instead')
const $core.Map<$core.String, $core.Map<$core.String, $core.dynamic>>
    VolvoxGridServiceBase$messageJson = {
  '.volvoxgrid.v1.CreateRequest': CreateRequest$json,
  '.volvoxgrid.v1.GridConfig': GridConfig$json,
  '.volvoxgrid.v1.LayoutConfig': LayoutConfig$json,
  '.volvoxgrid.v1.StyleConfig': StyleConfig$json,
  '.volvoxgrid.v1.Font': Font$json,
  '.volvoxgrid.v1.Padding': Padding$json,
  '.volvoxgrid.v1.GridLines': GridLines$json,
  '.volvoxgrid.v1.RegionStyle': RegionStyle$json,
  '.volvoxgrid.v1.Separator': Separator$json,
  '.volvoxgrid.v1.HeaderStyle': HeaderStyle$json,
  '.volvoxgrid.v1.HeaderSeparator': HeaderSeparator$json,
  '.volvoxgrid.v1.HeaderMarkSize': HeaderMarkSize$json,
  '.volvoxgrid.v1.HeaderResizeHandle': HeaderResizeHandle$json,
  '.volvoxgrid.v1.TextRendering': TextRendering$json,
  '.volvoxgrid.v1.IconTheme': IconTheme$json,
  '.volvoxgrid.v1.IconSlots': IconSlots$json,
  '.volvoxgrid.v1.IconStyle': IconStyle$json,
  '.volvoxgrid.v1.IconSlotStyles': IconSlotStyles$json,
  '.volvoxgrid.v1.IconPictures': IconPictures$json,
  '.volvoxgrid.v1.ImageData': ImageData$json,
  '.volvoxgrid.v1.SelectionConfig': SelectionConfig$json,
  '.volvoxgrid.v1.HighlightStyle': HighlightStyle$json,
  '.volvoxgrid.v1.Borders': Borders$json,
  '.volvoxgrid.v1.Border': Border$json,
  '.volvoxgrid.v1.HoverConfig': HoverConfig$json,
  '.volvoxgrid.v1.EditConfig': EditConfig$json,
  '.volvoxgrid.v1.ScrollConfig': ScrollConfig$json,
  '.volvoxgrid.v1.ScrollBarConfig': ScrollBarConfig$json,
  '.volvoxgrid.v1.ScrollBarColors': ScrollBarColors$json,
  '.volvoxgrid.v1.PullToRefreshConfig': PullToRefreshConfig$json,
  '.volvoxgrid.v1.OutlineConfig': OutlineConfig$json,
  '.volvoxgrid.v1.SpanConfig': SpanConfig$json,
  '.volvoxgrid.v1.InteractionConfig': InteractionConfig$json,
  '.volvoxgrid.v1.ResizePolicy': ResizePolicy$json,
  '.volvoxgrid.v1.FreezePolicy': FreezePolicy$json,
  '.volvoxgrid.v1.HeaderFeatures': HeaderFeatures$json,
  '.volvoxgrid.v1.RenderConfig': RenderConfig$json,
  '.volvoxgrid.v1.IndicatorsConfig': IndicatorsConfig$json,
  '.volvoxgrid.v1.RowIndicatorConfig': RowIndicatorConfig$json,
  '.volvoxgrid.v1.RowIndicatorSlot': RowIndicatorSlot$json,
  '.volvoxgrid.v1.ColIndicatorConfig': ColIndicatorConfig$json,
  '.volvoxgrid.v1.ColIndicatorRowDef': ColIndicatorRowDef$json,
  '.volvoxgrid.v1.ColIndicatorCell': ColIndicatorCell$json,
  '.volvoxgrid.v1.CornerIndicatorConfig': CornerIndicatorConfig$json,
  '.volvoxgrid.v1.CreateResponse': CreateResponse$json,
  '.volvoxgrid.v1.DestroyRequest': DestroyRequest$json,
  '.volvoxgrid.v1.DestroyResponse': DestroyResponse$json,
  '.volvoxgrid.v1.ConfigureRequest': ConfigureRequest$json,
  '.volvoxgrid.v1.ConfigureResponse': ConfigureResponse$json,
  '.volvoxgrid.v1.GetConfigRequest': GetConfigRequest$json,
  '.volvoxgrid.v1.LoadFontDataRequest': LoadFontDataRequest$json,
  '.volvoxgrid.v1.LoadFontDataResponse': LoadFontDataResponse$json,
  '.volvoxgrid.v1.DefineColumnsRequest': DefineColumnsRequest$json,
  '.volvoxgrid.v1.ColumnDef': ColumnDef$json,
  '.volvoxgrid.v1.Dropdown': Dropdown$json,
  '.volvoxgrid.v1.DropdownItem': DropdownItem$json,
  '.volvoxgrid.v1.DefineColumnsResponse': DefineColumnsResponse$json,
  '.volvoxgrid.v1.GetSchemaRequest': GetSchemaRequest$json,
  '.volvoxgrid.v1.SchemaResponse': SchemaResponse$json,
  '.volvoxgrid.v1.DefineRowsRequest': DefineRowsRequest$json,
  '.volvoxgrid.v1.RowDef': RowDef$json,
  '.volvoxgrid.v1.RowStatus': RowStatus$json,
  '.volvoxgrid.v1.DefineRowsResponse': DefineRowsResponse$json,
  '.volvoxgrid.v1.InsertRowsRequest': InsertRowsRequest$json,
  '.volvoxgrid.v1.InsertRowsResponse': InsertRowsResponse$json,
  '.volvoxgrid.v1.RemoveRowsRequest': RemoveRowsRequest$json,
  '.volvoxgrid.v1.RemoveRowsResponse': RemoveRowsResponse$json,
  '.volvoxgrid.v1.MoveColumnRequest': MoveColumnRequest$json,
  '.volvoxgrid.v1.MoveColumnResponse': MoveColumnResponse$json,
  '.volvoxgrid.v1.MoveRowRequest': MoveRowRequest$json,
  '.volvoxgrid.v1.MoveRowResponse': MoveRowResponse$json,
  '.volvoxgrid.v1.UpdateCellsRequest': UpdateCellsRequest$json,
  '.volvoxgrid.v1.CellUpdate': CellUpdate$json,
  '.volvoxgrid.v1.CellValue': CellValue$json,
  '.volvoxgrid.v1.CellStyle': CellStyle$json,
  '.volvoxgrid.v1.BarcodeData': BarcodeData$json,
  '.volvoxgrid.v1.BarcodeEncodingOptions': BarcodeEncodingOptions$json,
  '.volvoxgrid.v1.BarcodeRenderOptions': BarcodeRenderOptions$json,
  '.volvoxgrid.v1.BarcodeCaptionOptions': BarcodeCaptionOptions$json,
  '.volvoxgrid.v1.WriteResult': WriteResult$json,
  '.volvoxgrid.v1.TypeViolation': TypeViolation$json,
  '.volvoxgrid.v1.GetCellsRequest': GetCellsRequest$json,
  '.volvoxgrid.v1.CellsResponse': CellsResponse$json,
  '.volvoxgrid.v1.CellData': CellData$json,
  '.volvoxgrid.v1.LoadTableRequest': LoadTableRequest$json,
  '.volvoxgrid.v1.LoadDataRequest': LoadDataRequest$json,
  '.volvoxgrid.v1.LoadDataOptions': LoadDataOptions$json,
  '.volvoxgrid.v1.CsvOptions': CsvOptions$json,
  '.volvoxgrid.v1.JsonOptions': JsonOptions$json,
  '.volvoxgrid.v1.FieldMapping': FieldMapping$json,
  '.volvoxgrid.v1.LoadDataResult': LoadDataResult$json,
  '.volvoxgrid.v1.ClearRequest': ClearRequest$json,
  '.volvoxgrid.v1.ClearResponse': ClearResponse$json,
  '.volvoxgrid.v1.SelectRequest': SelectRequest$json,
  '.volvoxgrid.v1.CellRange': CellRange$json,
  '.volvoxgrid.v1.SelectResponse': SelectResponse$json,
  '.volvoxgrid.v1.SelectionState': SelectionState$json,
  '.volvoxgrid.v1.GetSelectionRequest': GetSelectionRequest$json,
  '.volvoxgrid.v1.ShowCellRequest': ShowCellRequest$json,
  '.volvoxgrid.v1.ShowCellResponse': ShowCellResponse$json,
  '.volvoxgrid.v1.SetRowRequest': SetRowRequest$json,
  '.volvoxgrid.v1.SetTopRowResponse': SetTopRowResponse$json,
  '.volvoxgrid.v1.SetColRequest': SetColRequest$json,
  '.volvoxgrid.v1.SetLeftColResponse': SetLeftColResponse$json,
  '.volvoxgrid.v1.EditCommand': EditCommand$json,
  '.volvoxgrid.v1.EditStart': EditStart$json,
  '.volvoxgrid.v1.EditCommit': EditCommit$json,
  '.volvoxgrid.v1.EditCancel': EditCancel$json,
  '.volvoxgrid.v1.EditSetText': EditSetText$json,
  '.volvoxgrid.v1.EditSetSelection': EditSetSelection$json,
  '.volvoxgrid.v1.EditFinish': EditFinish$json,
  '.volvoxgrid.v1.EditSetHighlights': EditSetHighlights$json,
  '.volvoxgrid.v1.HighlightRegion': HighlightRegion$json,
  '.volvoxgrid.v1.EditSetPreedit': EditSetPreedit$json,
  '.volvoxgrid.v1.EditState': EditState$json,
  '.volvoxgrid.v1.SortRequest': SortRequest$json,
  '.volvoxgrid.v1.SortColumn': SortColumn$json,
  '.volvoxgrid.v1.SortResponse': SortResponse$json,
  '.volvoxgrid.v1.SubtotalRequest': SubtotalRequest$json,
  '.volvoxgrid.v1.SubtotalResult': SubtotalResult$json,
  '.volvoxgrid.v1.AutoSizeRequest': AutoSizeRequest$json,
  '.volvoxgrid.v1.AutoSizeResponse': AutoSizeResponse$json,
  '.volvoxgrid.v1.OutlineRequest': OutlineRequest$json,
  '.volvoxgrid.v1.OutlineResponse': OutlineResponse$json,
  '.volvoxgrid.v1.GetNodeRequest': GetNodeRequest$json,
  '.volvoxgrid.v1.NodeInfo': NodeInfo$json,
  '.volvoxgrid.v1.FindRequest': FindRequest$json,
  '.volvoxgrid.v1.TextQuery': TextQuery$json,
  '.volvoxgrid.v1.RegexQuery': RegexQuery$json,
  '.volvoxgrid.v1.FindResponse': FindResponse$json,
  '.volvoxgrid.v1.AggregateRequest': AggregateRequest$json,
  '.volvoxgrid.v1.AggregateResponse': AggregateResponse$json,
  '.volvoxgrid.v1.GetMergedRangeRequest': GetMergedRangeRequest$json,
  '.volvoxgrid.v1.MergeCellsRequest': MergeCellsRequest$json,
  '.volvoxgrid.v1.MergeCellsResponse': MergeCellsResponse$json,
  '.volvoxgrid.v1.UnmergeCellsRequest': UnmergeCellsRequest$json,
  '.volvoxgrid.v1.UnmergeCellsResponse': UnmergeCellsResponse$json,
  '.volvoxgrid.v1.GetMergedRegionsRequest': GetMergedRegionsRequest$json,
  '.volvoxgrid.v1.MergedRegionsResponse': MergedRegionsResponse$json,
  '.volvoxgrid.v1.GetMemoryUsageRequest': GetMemoryUsageRequest$json,
  '.volvoxgrid.v1.MemoryUsageResponse': MemoryUsageResponse$json,
  '.volvoxgrid.v1.ClipboardCommand': ClipboardCommand$json,
  '.volvoxgrid.v1.ClipboardCopy': ClipboardCopy$json,
  '.volvoxgrid.v1.ClipboardCut': ClipboardCut$json,
  '.volvoxgrid.v1.ClipboardPaste': ClipboardPaste$json,
  '.volvoxgrid.v1.ClipboardDelete': ClipboardDelete$json,
  '.volvoxgrid.v1.ClipboardResponse': ClipboardResponse$json,
  '.volvoxgrid.v1.ExportRequest': ExportRequest$json,
  '.volvoxgrid.v1.ExportResponse': ExportResponse$json,
  '.volvoxgrid.v1.PrintRequest': PrintRequest$json,
  '.volvoxgrid.v1.PrintResponse': PrintResponse$json,
  '.volvoxgrid.v1.PrintPage': PrintPage$json,
  '.volvoxgrid.v1.ArchiveRequest': ArchiveRequest$json,
  '.volvoxgrid.v1.ArchiveResponse': ArchiveResponse$json,
  '.volvoxgrid.v1.ResizeViewportRequest': ResizeViewportRequest$json,
  '.volvoxgrid.v1.ResizeViewportResponse': ResizeViewportResponse$json,
  '.volvoxgrid.v1.SetRedrawRequest': SetRedrawRequest$json,
  '.volvoxgrid.v1.SetRedrawResponse': SetRedrawResponse$json,
  '.volvoxgrid.v1.RefreshRequest': RefreshRequest$json,
  '.volvoxgrid.v1.RefreshResponse': RefreshResponse$json,
  '.volvoxgrid.v1.LoadDemoRequest': LoadDemoRequest$json,
  '.volvoxgrid.v1.LoadDemoResponse': LoadDemoResponse$json,
  '.volvoxgrid.v1.GetDemoDataRequest': GetDemoDataRequest$json,
  '.volvoxgrid.v1.GetDemoDataResponse': GetDemoDataResponse$json,
  '.volvoxgrid.v1.RenderInput': RenderInput$json,
  '.volvoxgrid.v1.ViewportState': ViewportState$json,
  '.volvoxgrid.v1.PointerEvent': PointerEvent$json,
  '.volvoxgrid.v1.KeyEvent': KeyEvent$json,
  '.volvoxgrid.v1.BufferReady': BufferReady$json,
  '.volvoxgrid.v1.ScrollEvent': ScrollEvent$json,
  '.volvoxgrid.v1.EventDecision': EventDecision$json,
  '.volvoxgrid.v1.ZoomEvent': ZoomEvent$json,
  '.volvoxgrid.v1.GpuSurfaceReady': GpuSurfaceReady$json,
  '.volvoxgrid.v1.TerminalInputBytes': TerminalInputBytes$json,
  '.volvoxgrid.v1.TerminalCapabilities': TerminalCapabilities$json,
  '.volvoxgrid.v1.TerminalViewport': TerminalViewport$json,
  '.volvoxgrid.v1.TerminalCommand': TerminalCommand$json,
  '.volvoxgrid.v1.CompareResponse': CompareResponse$json,
  '.volvoxgrid.v1.RenderOutput': RenderOutput$json,
  '.volvoxgrid.v1.FrameDone': FrameDone$json,
  '.volvoxgrid.v1.FrameMetrics': FrameMetrics$json,
  '.volvoxgrid.v1.SelectionUpdate': SelectionUpdate$json,
  '.volvoxgrid.v1.CursorChange': CursorChange$json,
  '.volvoxgrid.v1.EditRequest': EditRequest$json,
  '.volvoxgrid.v1.DropdownRequest': DropdownRequest$json,
  '.volvoxgrid.v1.TooltipRequest': TooltipRequest$json,
  '.volvoxgrid.v1.GpuFrameDone': GpuFrameDone$json,
  '.volvoxgrid.v1.EventStreamRequest': EventStreamRequest$json,
  '.volvoxgrid.v1.GridEvent': GridEvent$json,
  '.volvoxgrid.v1.CellFocusChangingEvent': CellFocusChangingEvent$json,
  '.volvoxgrid.v1.CellFocusChangedEvent': CellFocusChangedEvent$json,
  '.volvoxgrid.v1.SelectionChangingEvent': SelectionChangingEvent$json,
  '.volvoxgrid.v1.SelectionChangedEvent': SelectionChangedEvent$json,
  '.volvoxgrid.v1.EnterCellEvent': EnterCellEvent$json,
  '.volvoxgrid.v1.LeaveCellEvent': LeaveCellEvent$json,
  '.volvoxgrid.v1.BeforeEditEvent': BeforeEditEvent$json,
  '.volvoxgrid.v1.StartEditEvent': StartEditEvent$json,
  '.volvoxgrid.v1.AfterEditEvent': AfterEditEvent$json,
  '.volvoxgrid.v1.CellEditValidateEvent': CellEditValidateEvent$json,
  '.volvoxgrid.v1.CellEditChangeEvent': CellEditChangeEvent$json,
  '.volvoxgrid.v1.KeyDownEditEvent': KeyDownEditEvent$json,
  '.volvoxgrid.v1.KeyPressEditEvent': KeyPressEditEvent$json,
  '.volvoxgrid.v1.KeyUpEditEvent': KeyUpEditEvent$json,
  '.volvoxgrid.v1.CellEditConfigureStyleEvent':
      CellEditConfigureStyleEvent$json,
  '.volvoxgrid.v1.CellEditConfigureWindowEvent':
      CellEditConfigureWindowEvent$json,
  '.volvoxgrid.v1.DropdownClosedEvent': DropdownClosedEvent$json,
  '.volvoxgrid.v1.DropdownOpenedEvent': DropdownOpenedEvent$json,
  '.volvoxgrid.v1.CellChangedEvent': CellChangedEvent$json,
  '.volvoxgrid.v1.RowStatusChangeEvent': RowStatusChangeEvent$json,
  '.volvoxgrid.v1.BeforeSortEvent': BeforeSortEvent$json,
  '.volvoxgrid.v1.AfterSortEvent': AfterSortEvent$json,
  '.volvoxgrid.v1.CompareEvent': CompareEvent$json,
  '.volvoxgrid.v1.BeforeNodeToggleEvent': BeforeNodeToggleEvent$json,
  '.volvoxgrid.v1.AfterNodeToggleEvent': AfterNodeToggleEvent$json,
  '.volvoxgrid.v1.BeforeScrollEvent': BeforeScrollEvent$json,
  '.volvoxgrid.v1.AfterScrollEvent': AfterScrollEvent$json,
  '.volvoxgrid.v1.ScrollTooltipEvent': ScrollTooltipEvent$json,
  '.volvoxgrid.v1.BeforeUserResizeEvent': BeforeUserResizeEvent$json,
  '.volvoxgrid.v1.AfterUserResizeEvent': AfterUserResizeEvent$json,
  '.volvoxgrid.v1.AfterUserFreezeEvent': AfterUserFreezeEvent$json,
  '.volvoxgrid.v1.BeforeMoveColumnEvent': BeforeMoveColumnEvent$json,
  '.volvoxgrid.v1.AfterMoveColumnEvent': AfterMoveColumnEvent$json,
  '.volvoxgrid.v1.BeforeMoveRowEvent': BeforeMoveRowEvent$json,
  '.volvoxgrid.v1.AfterMoveRowEvent': AfterMoveRowEvent$json,
  '.volvoxgrid.v1.BeforeMouseDownEvent': BeforeMouseDownEvent$json,
  '.volvoxgrid.v1.MouseDownEvent': MouseDownEvent$json,
  '.volvoxgrid.v1.MouseUpEvent': MouseUpEvent$json,
  '.volvoxgrid.v1.MouseMoveEvent': MouseMoveEvent$json,
  '.volvoxgrid.v1.ClickEvent': ClickEvent$json,
  '.volvoxgrid.v1.DblClickEvent': DblClickEvent$json,
  '.volvoxgrid.v1.KeyDownEvent': KeyDownEvent$json,
  '.volvoxgrid.v1.KeyPressEvent': KeyPressEvent$json,
  '.volvoxgrid.v1.KeyUpEvent': KeyUpEvent$json,
  '.volvoxgrid.v1.CustomRenderCellEvent': CustomRenderCellEvent$json,
  '.volvoxgrid.v1.DragStartEvent': DragStartEvent$json,
  '.volvoxgrid.v1.DragOverEvent': DragOverEvent$json,
  '.volvoxgrid.v1.DragDropEvent': DragDropEvent$json,
  '.volvoxgrid.v1.DragCompleteEvent': DragCompleteEvent$json,
  '.volvoxgrid.v1.TypeAheadStartedEvent': TypeAheadStartedEvent$json,
  '.volvoxgrid.v1.TypeAheadEndedEvent': TypeAheadEndedEvent$json,
  '.volvoxgrid.v1.DataRefreshingEvent': DataRefreshingEvent$json,
  '.volvoxgrid.v1.DataRefreshedEvent': DataRefreshedEvent$json,
  '.volvoxgrid.v1.FilterDataEvent': FilterDataEvent$json,
  '.volvoxgrid.v1.ErrorEvent': ErrorEvent$json,
  '.volvoxgrid.v1.BeforePageBreakEvent': BeforePageBreakEvent$json,
  '.volvoxgrid.v1.StartPageEvent': StartPageEvent$json,
  '.volvoxgrid.v1.GetHeaderRowEvent': GetHeaderRowEvent$json,
  '.volvoxgrid.v1.PullToRefreshTriggeredEvent':
      PullToRefreshTriggeredEvent$json,
  '.volvoxgrid.v1.PullToRefreshCanceledEvent': PullToRefreshCanceledEvent$json,
  '.volvoxgrid.v1.BeforeDropdownOpenEvent': BeforeDropdownOpenEvent$json,
};

/// Descriptor for `VolvoxGridService`. Decode as a `google.protobuf.ServiceDescriptorProto`.
final $typed_data.Uint8List volvoxGridServiceDescriptor = $convert.base64Decode(
    'ChFWb2x2b3hHcmlkU2VydmljZRJFCgZDcmVhdGUSHC52b2x2b3hncmlkLnYxLkNyZWF0ZVJlcX'
    'Vlc3QaHS52b2x2b3hncmlkLnYxLkNyZWF0ZVJlc3BvbnNlEkgKB0Rlc3Ryb3kSHS52b2x2b3hn'
    'cmlkLnYxLkRlc3Ryb3lSZXF1ZXN0Gh4udm9sdm94Z3JpZC52MS5EZXN0cm95UmVzcG9uc2USTg'
    'oJQ29uZmlndXJlEh8udm9sdm94Z3JpZC52MS5Db25maWd1cmVSZXF1ZXN0GiAudm9sdm94Z3Jp'
    'ZC52MS5Db25maWd1cmVSZXNwb25zZRJHCglHZXRDb25maWcSHy52b2x2b3hncmlkLnYxLkdldE'
    'NvbmZpZ1JlcXVlc3QaGS52b2x2b3hncmlkLnYxLkdyaWRDb25maWcSVwoMTG9hZEZvbnREYXRh'
    'EiIudm9sdm94Z3JpZC52MS5Mb2FkRm9udERhdGFSZXF1ZXN0GiMudm9sdm94Z3JpZC52MS5Mb2'
    'FkRm9udERhdGFSZXNwb25zZRJaCg1EZWZpbmVDb2x1bW5zEiMudm9sdm94Z3JpZC52MS5EZWZp'
    'bmVDb2x1bW5zUmVxdWVzdBokLnZvbHZveGdyaWQudjEuRGVmaW5lQ29sdW1uc1Jlc3BvbnNlEk'
    'sKCUdldFNjaGVtYRIfLnZvbHZveGdyaWQudjEuR2V0U2NoZW1hUmVxdWVzdBodLnZvbHZveGdy'
    'aWQudjEuU2NoZW1hUmVzcG9uc2USUQoKRGVmaW5lUm93cxIgLnZvbHZveGdyaWQudjEuRGVmaW'
    '5lUm93c1JlcXVlc3QaIS52b2x2b3hncmlkLnYxLkRlZmluZVJvd3NSZXNwb25zZRJRCgpJbnNl'
    'cnRSb3dzEiAudm9sdm94Z3JpZC52MS5JbnNlcnRSb3dzUmVxdWVzdBohLnZvbHZveGdyaWQudj'
    'EuSW5zZXJ0Um93c1Jlc3BvbnNlElEKClJlbW92ZVJvd3MSIC52b2x2b3hncmlkLnYxLlJlbW92'
    'ZVJvd3NSZXF1ZXN0GiEudm9sdm94Z3JpZC52MS5SZW1vdmVSb3dzUmVzcG9uc2USUQoKTW92ZU'
    'NvbHVtbhIgLnZvbHZveGdyaWQudjEuTW92ZUNvbHVtblJlcXVlc3QaIS52b2x2b3hncmlkLnYx'
    'Lk1vdmVDb2x1bW5SZXNwb25zZRJICgdNb3ZlUm93Eh0udm9sdm94Z3JpZC52MS5Nb3ZlUm93Um'
    'VxdWVzdBoeLnZvbHZveGdyaWQudjEuTW92ZVJvd1Jlc3BvbnNlEkwKC1VwZGF0ZUNlbGxzEiEu'
    'dm9sdm94Z3JpZC52MS5VcGRhdGVDZWxsc1JlcXVlc3QaGi52b2x2b3hncmlkLnYxLldyaXRlUm'
    'VzdWx0EkgKCEdldENlbGxzEh4udm9sdm94Z3JpZC52MS5HZXRDZWxsc1JlcXVlc3QaHC52b2x2'
    'b3hncmlkLnYxLkNlbGxzUmVzcG9uc2USSAoJTG9hZFRhYmxlEh8udm9sdm94Z3JpZC52MS5Mb2'
    'FkVGFibGVSZXF1ZXN0Ghoudm9sdm94Z3JpZC52MS5Xcml0ZVJlc3VsdBJJCghMb2FkRGF0YRIe'
    'LnZvbHZveGdyaWQudjEuTG9hZERhdGFSZXF1ZXN0Gh0udm9sdm94Z3JpZC52MS5Mb2FkRGF0YV'
    'Jlc3VsdBJCCgVDbGVhchIbLnZvbHZveGdyaWQudjEuQ2xlYXJSZXF1ZXN0Ghwudm9sdm94Z3Jp'
    'ZC52MS5DbGVhclJlc3BvbnNlEkUKBlNlbGVjdBIcLnZvbHZveGdyaWQudjEuU2VsZWN0UmVxdW'
    'VzdBodLnZvbHZveGdyaWQudjEuU2VsZWN0UmVzcG9uc2USUQoMR2V0U2VsZWN0aW9uEiIudm9s'
    'dm94Z3JpZC52MS5HZXRTZWxlY3Rpb25SZXF1ZXN0Gh0udm9sdm94Z3JpZC52MS5TZWxlY3Rpb2'
    '5TdGF0ZRJLCghTaG93Q2VsbBIeLnZvbHZveGdyaWQudjEuU2hvd0NlbGxSZXF1ZXN0Gh8udm9s'
    'dm94Z3JpZC52MS5TaG93Q2VsbFJlc3BvbnNlEksKCVNldFRvcFJvdxIcLnZvbHZveGdyaWQudj'
    'EuU2V0Um93UmVxdWVzdBogLnZvbHZveGdyaWQudjEuU2V0VG9wUm93UmVzcG9uc2USTQoKU2V0'
    'TGVmdENvbBIcLnZvbHZveGdyaWQudjEuU2V0Q29sUmVxdWVzdBohLnZvbHZveGdyaWQudjEuU2'
    'V0TGVmdENvbFJlc3BvbnNlEjwKBEVkaXQSGi52b2x2b3hncmlkLnYxLkVkaXRDb21tYW5kGhgu'
    'dm9sdm94Z3JpZC52MS5FZGl0U3RhdGUSPwoEU29ydBIaLnZvbHZveGdyaWQudjEuU29ydFJlcX'
    'Vlc3QaGy52b2x2b3hncmlkLnYxLlNvcnRSZXNwb25zZRJJCghTdWJ0b3RhbBIeLnZvbHZveGdy'
    'aWQudjEuU3VidG90YWxSZXF1ZXN0Gh0udm9sdm94Z3JpZC52MS5TdWJ0b3RhbFJlc3VsdBJLCg'
    'hBdXRvU2l6ZRIeLnZvbHZveGdyaWQudjEuQXV0b1NpemVSZXF1ZXN0Gh8udm9sdm94Z3JpZC52'
    'MS5BdXRvU2l6ZVJlc3BvbnNlEkgKB091dGxpbmUSHS52b2x2b3hncmlkLnYxLk91dGxpbmVSZX'
    'F1ZXN0Gh4udm9sdm94Z3JpZC52MS5PdXRsaW5lUmVzcG9uc2USQQoHR2V0Tm9kZRIdLnZvbHZv'
    'eGdyaWQudjEuR2V0Tm9kZVJlcXVlc3QaFy52b2x2b3hncmlkLnYxLk5vZGVJbmZvEj8KBEZpbm'
    'QSGi52b2x2b3hncmlkLnYxLkZpbmRSZXF1ZXN0Ghsudm9sdm94Z3JpZC52MS5GaW5kUmVzcG9u'
    'c2USTgoJQWdncmVnYXRlEh8udm9sdm94Z3JpZC52MS5BZ2dyZWdhdGVSZXF1ZXN0GiAudm9sdm'
    '94Z3JpZC52MS5BZ2dyZWdhdGVSZXNwb25zZRJQCg5HZXRNZXJnZWRSYW5nZRIkLnZvbHZveGdy'
    'aWQudjEuR2V0TWVyZ2VkUmFuZ2VSZXF1ZXN0Ghgudm9sdm94Z3JpZC52MS5DZWxsUmFuZ2USUQ'
    'oKTWVyZ2VDZWxscxIgLnZvbHZveGdyaWQudjEuTWVyZ2VDZWxsc1JlcXVlc3QaIS52b2x2b3hn'
    'cmlkLnYxLk1lcmdlQ2VsbHNSZXNwb25zZRJXCgxVbm1lcmdlQ2VsbHMSIi52b2x2b3hncmlkLn'
    'YxLlVubWVyZ2VDZWxsc1JlcXVlc3QaIy52b2x2b3hncmlkLnYxLlVubWVyZ2VDZWxsc1Jlc3Bv'
    'bnNlEmAKEEdldE1lcmdlZFJlZ2lvbnMSJi52b2x2b3hncmlkLnYxLkdldE1lcmdlZFJlZ2lvbn'
    'NSZXF1ZXN0GiQudm9sdm94Z3JpZC52MS5NZXJnZWRSZWdpb25zUmVzcG9uc2USWgoOR2V0TWVt'
    'b3J5VXNhZ2USJC52b2x2b3hncmlkLnYxLkdldE1lbW9yeVVzYWdlUmVxdWVzdBoiLnZvbHZveG'
    'dyaWQudjEuTWVtb3J5VXNhZ2VSZXNwb25zZRJOCglDbGlwYm9hcmQSHy52b2x2b3hncmlkLnYx'
    'LkNsaXBib2FyZENvbW1hbmQaIC52b2x2b3hncmlkLnYxLkNsaXBib2FyZFJlc3BvbnNlEkUKBk'
    'V4cG9ydBIcLnZvbHZveGdyaWQudjEuRXhwb3J0UmVxdWVzdBodLnZvbHZveGdyaWQudjEuRXhw'
    'b3J0UmVzcG9uc2USQgoFUHJpbnQSGy52b2x2b3hncmlkLnYxLlByaW50UmVxdWVzdBocLnZvbH'
    'ZveGdyaWQudjEuUHJpbnRSZXNwb25zZRJICgdBcmNoaXZlEh0udm9sdm94Z3JpZC52MS5BcmNo'
    'aXZlUmVxdWVzdBoeLnZvbHZveGdyaWQudjEuQXJjaGl2ZVJlc3BvbnNlEl0KDlJlc2l6ZVZpZX'
    'dwb3J0EiQudm9sdm94Z3JpZC52MS5SZXNpemVWaWV3cG9ydFJlcXVlc3QaJS52b2x2b3hncmlk'
    'LnYxLlJlc2l6ZVZpZXdwb3J0UmVzcG9uc2USTgoJU2V0UmVkcmF3Eh8udm9sdm94Z3JpZC52MS'
    '5TZXRSZWRyYXdSZXF1ZXN0GiAudm9sdm94Z3JpZC52MS5TZXRSZWRyYXdSZXNwb25zZRJICgdS'
    'ZWZyZXNoEh0udm9sdm94Z3JpZC52MS5SZWZyZXNoUmVxdWVzdBoeLnZvbHZveGdyaWQudjEuUm'
    'VmcmVzaFJlc3BvbnNlEksKCExvYWREZW1vEh4udm9sdm94Z3JpZC52MS5Mb2FkRGVtb1JlcXVl'
    'c3QaHy52b2x2b3hncmlkLnYxLkxvYWREZW1vUmVzcG9uc2USVAoLR2V0RGVtb0RhdGESIS52b2'
    'x2b3hncmlkLnYxLkdldERlbW9EYXRhUmVxdWVzdBoiLnZvbHZveGdyaWQudjEuR2V0RGVtb0Rh'
    'dGFSZXNwb25zZRJMCg1SZW5kZXJTZXNzaW9uEhoudm9sdm94Z3JpZC52MS5SZW5kZXJJbnB1dB'
    'obLnZvbHZveGdyaWQudjEuUmVuZGVyT3V0cHV0KAEwARJMCgtFdmVudFN0cmVhbRIhLnZvbHZv'
    'eGdyaWQudjEuRXZlbnRTdHJlYW1SZXF1ZXN0Ghgudm9sdm94Z3JpZC52MS5HcmlkRXZlbnQwAQ'
    '==');
