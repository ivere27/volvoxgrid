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
    {'1': 'SORT_GENERIC_ASCENDING', '2': 1},
    {'1': 'SORT_GENERIC_DESCENDING', '2': 2},
    {'1': 'SORT_NUMERIC_ASCENDING', '2': 3},
    {'1': 'SORT_NUMERIC_DESCENDING', '2': 4},
    {'1': 'SORT_STRING_NO_CASE_ASC', '2': 5},
    {'1': 'SORT_STRING_NO_CASE_DESC', '2': 6},
    {'1': 'SORT_STRING_ASC', '2': 7},
    {'1': 'SORT_STRING_DESC', '2': 8},
    {'1': 'SORT_CUSTOM', '2': 9},
    {'1': 'SORT_USE_COL_SORT', '2': 10},
  ],
};

/// Descriptor for `SortOrder`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List sortOrderDescriptor = $convert.base64Decode(
    'CglTb3J0T3JkZXISDQoJU09SVF9OT05FEAASGgoWU09SVF9HRU5FUklDX0FTQ0VORElORxABEh'
    'sKF1NPUlRfR0VORVJJQ19ERVNDRU5ESU5HEAISGgoWU09SVF9OVU1FUklDX0FTQ0VORElORxAD'
    'EhsKF1NPUlRfTlVNRVJJQ19ERVNDRU5ESU5HEAQSGwoXU09SVF9TVFJJTkdfTk9fQ0FTRV9BU0'
    'MQBRIcChhTT1JUX1NUUklOR19OT19DQVNFX0RFU0MQBhITCg9TT1JUX1NUUklOR19BU0MQBxIU'
    'ChBTT1JUX1NUUklOR19ERVNDEAgSDwoLU09SVF9DVVNUT00QCRIVChFTT1JUX1VTRV9DT0xfU0'
    '9SVBAK');

@$core.Deprecated('Use headerFeaturesDescriptor instead')
const HeaderFeatures$json = {
  '1': 'HeaderFeatures',
  '2': [
    {'1': 'HEADER_NONE', '2': 0},
    {'1': 'HEADER_SORT', '2': 1},
    {'1': 'HEADER_REORDER', '2': 2},
    {'1': 'HEADER_SORT_REORDER', '2': 3},
    {'1': 'HEADER_SORT_CHOOSER', '2': 5},
    {'1': 'HEADER_REORDER_CHOOSER', '2': 6},
    {'1': 'HEADER_SORT_REORDER_CHOOSER', '2': 7},
  ],
};

/// Descriptor for `HeaderFeatures`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List headerFeaturesDescriptor = $convert.base64Decode(
    'Cg5IZWFkZXJGZWF0dXJlcxIPCgtIRUFERVJfTk9ORRAAEg8KC0hFQURFUl9TT1JUEAESEgoOSE'
    'VBREVSX1JFT1JERVIQAhIXChNIRUFERVJfU09SVF9SRU9SREVSEAMSFwoTSEVBREVSX1NPUlRf'
    'Q0hPT1NFUhAFEhoKFkhFQURFUl9SRU9SREVSX0NIT09TRVIQBhIfChtIRUFERVJfU09SVF9SRU'
    '9SREVSX0NIT09TRVIQBw==');

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

@$core.Deprecated('Use gridLineStyleDescriptor instead')
const GridLineStyle$json = {
  '1': 'GridLineStyle',
  '2': [
    {'1': 'GRIDLINE_NONE', '2': 0},
    {'1': 'GRIDLINE_SOLID', '2': 1},
    {'1': 'GRIDLINE_INSET', '2': 2},
    {'1': 'GRIDLINE_RAISED', '2': 3},
    {'1': 'GRIDLINE_SOLID_HORIZONTAL', '2': 4},
    {'1': 'GRIDLINE_SOLID_VERTICAL', '2': 5},
    {'1': 'GRIDLINE_INSET_HORIZONTAL', '2': 6},
    {'1': 'GRIDLINE_INSET_VERTICAL', '2': 7},
    {'1': 'GRIDLINE_RAISED_HORIZONTAL', '2': 8},
    {'1': 'GRIDLINE_RAISED_VERTICAL', '2': 9},
  ],
};

/// Descriptor for `GridLineStyle`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List gridLineStyleDescriptor = $convert.base64Decode(
    'Cg1HcmlkTGluZVN0eWxlEhEKDUdSSURMSU5FX05PTkUQABISCg5HUklETElORV9TT0xJRBABEh'
    'IKDkdSSURMSU5FX0lOU0VUEAISEwoPR1JJRExJTkVfUkFJU0VEEAMSHQoZR1JJRExJTkVfU09M'
    'SURfSE9SSVpPTlRBTBAEEhsKF0dSSURMSU5FX1NPTElEX1ZFUlRJQ0FMEAUSHQoZR1JJRExJTk'
    'VfSU5TRVRfSE9SSVpPTlRBTBAGEhsKF0dSSURMSU5FX0lOU0VUX1ZFUlRJQ0FMEAcSHgoaR1JJ'
    'RExJTkVfUkFJU0VEX0hPUklaT05UQUwQCBIcChhHUklETElORV9SQUlTRURfVkVSVElDQUwQCQ'
    '==');

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
    {'1': 'COERCION_MODE_UNSPECIFIED', '2': 0},
    {'1': 'COERCION_MODE_STRICT', '2': 1},
    {'1': 'COERCION_MODE_FLEXIBLE', '2': 2},
    {'1': 'COERCION_MODE_PARSE_ONLY', '2': 3},
  ],
};

/// Descriptor for `CoercionMode`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List coercionModeDescriptor = $convert.base64Decode(
    'CgxDb2VyY2lvbk1vZGUSHQoZQ09FUkNJT05fTU9ERV9VTlNQRUNJRklFRBAAEhgKFENPRVJDSU'
    '9OX01PREVfU1RSSUNUEAESGgoWQ09FUkNJT05fTU9ERV9GTEVYSUJMRRACEhwKGENPRVJDSU9O'
    'X01PREVfUEFSU0VfT05MWRAD');

@$core.Deprecated('Use writeErrorModeDescriptor instead')
const WriteErrorMode$json = {
  '1': 'WriteErrorMode',
  '2': [
    {'1': 'WRITE_ERROR_MODE_UNSPECIFIED', '2': 0},
    {'1': 'WRITE_ERROR_MODE_REJECT', '2': 1},
    {'1': 'WRITE_ERROR_MODE_SET_NULL', '2': 2},
    {'1': 'WRITE_ERROR_MODE_SKIP', '2': 3},
  ],
};

/// Descriptor for `WriteErrorMode`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List writeErrorModeDescriptor = $convert.base64Decode(
    'Cg5Xcml0ZUVycm9yTW9kZRIgChxXUklURV9FUlJPUl9NT0RFX1VOU1BFQ0lGSUVEEAASGwoXV1'
    'JJVEVfRVJST1JfTU9ERV9SRUpFQ1QQARIdChlXUklURV9FUlJPUl9NT0RFX1NFVF9OVUxMEAIS'
    'GQoVV1JJVEVfRVJST1JfTU9ERV9TS0lQEAM=');

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

@$core.Deprecated('Use allowUserResizingModeDescriptor instead')
const AllowUserResizingMode$json = {
  '1': 'AllowUserResizingMode',
  '2': [
    {'1': 'RESIZE_NONE', '2': 0},
    {'1': 'RESIZE_COLUMNS', '2': 1},
    {'1': 'RESIZE_ROWS', '2': 2},
    {'1': 'RESIZE_BOTH', '2': 3},
    {'1': 'RESIZE_COLUMNS_UNIFORM', '2': 4},
    {'1': 'RESIZE_ROWS_UNIFORM', '2': 5},
    {'1': 'RESIZE_BOTH_UNIFORM', '2': 6},
  ],
};

/// Descriptor for `AllowUserResizingMode`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List allowUserResizingModeDescriptor = $convert.base64Decode(
    'ChVBbGxvd1VzZXJSZXNpemluZ01vZGUSDwoLUkVTSVpFX05PTkUQABISCg5SRVNJWkVfQ09MVU'
    '1OUxABEg8KC1JFU0laRV9ST1dTEAISDwoLUkVTSVpFX0JPVEgQAxIaChZSRVNJWkVfQ09MVU1O'
    'U19VTklGT1JNEAQSFwoTUkVTSVpFX1JPV1NfVU5JRk9STRAFEhcKE1JFU0laRV9CT1RIX1VOSU'
    'ZPUk0QBg==');

@$core.Deprecated('Use userFreezeModeDescriptor instead')
const UserFreezeMode$json = {
  '1': 'UserFreezeMode',
  '2': [
    {'1': 'USER_FREEZE_NONE', '2': 0},
    {'1': 'USER_FREEZE_COLUMNS', '2': 1},
    {'1': 'USER_FREEZE_ROWS', '2': 2},
    {'1': 'USER_FREEZE_BOTH', '2': 3},
  ],
};

/// Descriptor for `UserFreezeMode`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List userFreezeModeDescriptor = $convert.base64Decode(
    'Cg5Vc2VyRnJlZXplTW9kZRIUChBVU0VSX0ZSRUVaRV9OT05FEAASFwoTVVNFUl9GUkVFWkVfQ0'
    '9MVU1OUxABEhQKEFVTRVJfRlJFRVpFX1JPV1MQAhIUChBVU0VSX0ZSRUVaRV9CT1RIEAM=');

@$core.Deprecated('Use autoSizeModeDescriptor instead')
const AutoSizeMode$json = {
  '1': 'AutoSizeMode',
  '2': [
    {'1': 'AUTOSIZE_BOTH_WAYS', '2': 0},
    {'1': 'AUTOSIZE_COL_WIDTH', '2': 1},
    {'1': 'AUTOSIZE_ROW_HEIGHT', '2': 2},
  ],
};

/// Descriptor for `AutoSizeMode`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List autoSizeModeDescriptor = $convert.base64Decode(
    'CgxBdXRvU2l6ZU1vZGUSFgoSQVVUT1NJWkVfQk9USF9XQVlTEAASFgoSQVVUT1NJWkVfQ09MX1'
    'dJRFRIEAESFwoTQVVUT1NJWkVfUk9XX0hFSUdIVBAC');

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

@$core.Deprecated('Use rendererModeDescriptor instead')
const RendererMode$json = {
  '1': 'RendererMode',
  '2': [
    {'1': 'RENDERER_AUTO', '2': 0},
    {'1': 'RENDERER_CPU', '2': 1},
    {'1': 'RENDERER_GPU', '2': 2},
    {'1': 'RENDERER_GPU_VULKAN', '2': 3},
    {'1': 'RENDERER_GPU_GLES', '2': 4},
  ],
};

/// Descriptor for `RendererMode`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List rendererModeDescriptor = $convert.base64Decode(
    'CgxSZW5kZXJlck1vZGUSEQoNUkVOREVSRVJfQVVUTxAAEhAKDFJFTkRFUkVSX0NQVRABEhAKDF'
    'JFTkRFUkVSX0dQVRACEhcKE1JFTkRFUkVSX0dQVV9WVUxLQU4QAxIVChFSRU5ERVJFUl9HUFVf'
    'R0xFUxAE');

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
    {'1': 'BORDER_RAISED', '2': 6},
    {'1': 'BORDER_INSET', '2': 7},
  ],
};

/// Descriptor for `BorderStyle`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List borderStyleDescriptor = $convert.base64Decode(
    'CgtCb3JkZXJTdHlsZRIPCgtCT1JERVJfTk9ORRAAEg8KC0JPUkRFUl9USElOEAESEAoMQk9SRE'
    'VSX1RISUNLEAISEQoNQk9SREVSX0RPVFRFRBADEhEKDUJPUkRFUl9EQVNIRUQQBBIRCg1CT1JE'
    'RVJfRE9VQkxFEAUSEQoNQk9SREVSX1JBSVNFRBAGEhAKDEJPUkRFUl9JTlNFVBAH');

@$core.Deprecated('Use hoverModeDescriptor instead')
const HoverMode$json = {
  '1': 'HoverMode',
  '2': [
    {'1': 'HOVER_NONE', '2': 0},
    {'1': 'HOVER_ROW', '2': 1},
    {'1': 'HOVER_COLUMN', '2': 2},
    {'1': 'HOVER_CELL', '2': 4},
  ],
};

/// Descriptor for `HoverMode`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List hoverModeDescriptor = $convert.base64Decode(
    'CglIb3Zlck1vZGUSDgoKSE9WRVJfTk9ORRAAEg0KCUhPVkVSX1JPVxABEhAKDEhPVkVSX0NPTF'
    'VNThACEg4KCkhPVkVSX0NFTEwQBA==');

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

@$core.Deprecated('Use clearScopeDescriptor instead')
const ClearScope$json = {
  '1': 'ClearScope',
  '2': [
    {'1': 'CLEAR_EVERYTHING', '2': 0},
    {'1': 'CLEAR_FORMATTING', '2': 1},
    {'1': 'CLEAR_DATA', '2': 2},
    {'1': 'CLEAR_SELECTION', '2': 3},
  ],
};

/// Descriptor for `ClearScope`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List clearScopeDescriptor = $convert.base64Decode(
    'CgpDbGVhclNjb3BlEhQKEENMRUFSX0VWRVJZVEhJTkcQABIUChBDTEVBUl9GT1JNQVRUSU5HEA'
    'ESDgoKQ0xFQVJfREFUQRACEhMKD0NMRUFSX1NFTEVDVElPThAD');

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

@$core.Deprecated('Use exportFormatDescriptor instead')
const ExportFormat$json = {
  '1': 'ExportFormat',
  '2': [
    {'1': 'EXPORT_BINARY', '2': 0},
    {'1': 'EXPORT_TSV', '2': 1},
    {'1': 'EXPORT_CSV', '2': 2},
    {'1': 'EXPORT_DELIMITED', '2': 3},
    {'1': 'EXPORT_XLSX', '2': 4},
  ],
};

/// Descriptor for `ExportFormat`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List exportFormatDescriptor = $convert.base64Decode(
    'CgxFeHBvcnRGb3JtYXQSEQoNRVhQT1JUX0JJTkFSWRAAEg4KCkVYUE9SVF9UU1YQARIOCgpFWF'
    'BPUlRfQ1NWEAISFAoQRVhQT1JUX0RFTElNSVRFRBADEg8KC0VYUE9SVF9YTFNYEAQ=');

@$core.Deprecated('Use exportScopeDescriptor instead')
const ExportScope$json = {
  '1': 'ExportScope',
  '2': [
    {'1': 'EXPORT_ALL', '2': 0},
    {'1': 'EXPORT_DATA_ONLY', '2': 1},
    {'1': 'EXPORT_FORMAT_ONLY', '2': 2},
  ],
};

/// Descriptor for `ExportScope`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List exportScopeDescriptor = $convert.base64Decode(
    'CgtFeHBvcnRTY29wZRIOCgpFWFBPUlRfQUxMEAASFAoQRVhQT1JUX0RBVEFfT05MWRABEhYKEk'
    'VYUE9SVF9GT1JNQVRfT05MWRAC');

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

@$core.Deprecated('Use emptyDescriptor instead')
const Empty$json = {
  '1': 'Empty',
};

/// Descriptor for `Empty`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List emptyDescriptor =
    $convert.base64Decode('CgVFbXB0eQ==');

@$core.Deprecated('Use gridHandleDescriptor instead')
const GridHandle$json = {
  '1': 'GridHandle',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 3, '10': 'id'},
  ],
};

/// Descriptor for `GridHandle`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List gridHandleDescriptor =
    $convert.base64Decode('CgpHcmlkSGFuZGxlEg4KAmlkGAEgASgDUgJpZA==');

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

@$core.Deprecated('Use cellValueDescriptor instead')
const CellValue$json = {
  '1': 'CellValue',
  '2': [
    {'1': 'text', '3': 1, '4': 1, '5': 9, '9': 0, '10': 'text'},
    {'1': 'number', '3': 2, '4': 1, '5': 1, '9': 0, '10': 'number'},
    {'1': 'flag', '3': 3, '4': 1, '5': 8, '9': 0, '10': 'flag'},
    {'1': 'data', '3': 4, '4': 1, '5': 12, '9': 0, '10': 'data'},
    {'1': 'timestamp', '3': 5, '4': 1, '5': 3, '9': 0, '10': 'timestamp'},
  ],
  '8': [
    {'1': 'value'},
  ],
};

/// Descriptor for `CellValue`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cellValueDescriptor = $convert.base64Decode(
    'CglDZWxsVmFsdWUSFAoEdGV4dBgBIAEoCUgAUgR0ZXh0EhgKBm51bWJlchgCIAEoAUgAUgZudW'
    '1iZXISFAoEZmxhZxgDIAEoCEgAUgRmbGFnEhQKBGRhdGEYBCABKAxIAFIEZGF0YRIeCgl0aW1l'
    'c3RhbXAYBSABKANIAFIJdGltZXN0YW1wQgcKBXZhbHVl');

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

@$core.Deprecated('Use cellPaddingDescriptor instead')
const CellPadding$json = {
  '1': 'CellPadding',
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

/// Descriptor for `CellPadding`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cellPaddingDescriptor = $convert.base64Decode(
    'CgtDZWxsUGFkZGluZxIXCgRsZWZ0GAEgASgFSABSBGxlZnSIAQESFQoDdG9wGAIgASgFSAFSA3'
    'RvcIgBARIZCgVyaWdodBgDIAEoBUgCUgVyaWdodIgBARIbCgZib3R0b20YBCABKAVIA1IGYm90'
    'dG9tiAEBQgcKBV9sZWZ0QgYKBF90b3BCCAoGX3JpZ2h0QgkKB19ib3R0b20=');

@$core.Deprecated('Use highlightStyleDescriptor instead')
const HighlightStyle$json = {
  '1': 'HighlightStyle',
  '2': [
    {
      '1': 'back_color',
      '3': 1,
      '4': 1,
      '5': 13,
      '9': 0,
      '10': 'backColor',
      '17': true
    },
    {
      '1': 'fore_color',
      '3': 2,
      '4': 1,
      '5': 13,
      '9': 1,
      '10': 'foreColor',
      '17': true
    },
    {
      '1': 'border',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.BorderStyle',
      '9': 2,
      '10': 'border',
      '17': true
    },
    {
      '1': 'border_color',
      '3': 4,
      '4': 1,
      '5': 13,
      '9': 3,
      '10': 'borderColor',
      '17': true
    },
    {
      '1': 'border_top',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.BorderStyle',
      '9': 4,
      '10': 'borderTop',
      '17': true
    },
    {
      '1': 'border_right',
      '3': 6,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.BorderStyle',
      '9': 5,
      '10': 'borderRight',
      '17': true
    },
    {
      '1': 'border_bottom',
      '3': 7,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.BorderStyle',
      '9': 6,
      '10': 'borderBottom',
      '17': true
    },
    {
      '1': 'border_left',
      '3': 8,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.BorderStyle',
      '9': 7,
      '10': 'borderLeft',
      '17': true
    },
    {
      '1': 'border_top_color',
      '3': 9,
      '4': 1,
      '5': 13,
      '9': 8,
      '10': 'borderTopColor',
      '17': true
    },
    {
      '1': 'border_right_color',
      '3': 10,
      '4': 1,
      '5': 13,
      '9': 9,
      '10': 'borderRightColor',
      '17': true
    },
    {
      '1': 'border_bottom_color',
      '3': 11,
      '4': 1,
      '5': 13,
      '9': 10,
      '10': 'borderBottomColor',
      '17': true
    },
    {
      '1': 'border_left_color',
      '3': 12,
      '4': 1,
      '5': 13,
      '9': 11,
      '10': 'borderLeftColor',
      '17': true
    },
    {
      '1': 'fill_handle',
      '3': 13,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.FillHandlePosition',
      '9': 12,
      '10': 'fillHandle',
      '17': true
    },
    {
      '1': 'fill_handle_color',
      '3': 14,
      '4': 1,
      '5': 13,
      '9': 13,
      '10': 'fillHandleColor',
      '17': true
    },
  ],
  '8': [
    {'1': '_back_color'},
    {'1': '_fore_color'},
    {'1': '_border'},
    {'1': '_border_color'},
    {'1': '_border_top'},
    {'1': '_border_right'},
    {'1': '_border_bottom'},
    {'1': '_border_left'},
    {'1': '_border_top_color'},
    {'1': '_border_right_color'},
    {'1': '_border_bottom_color'},
    {'1': '_border_left_color'},
    {'1': '_fill_handle'},
    {'1': '_fill_handle_color'},
  ],
};

/// Descriptor for `HighlightStyle`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List highlightStyleDescriptor = $convert.base64Decode(
    'Cg5IaWdobGlnaHRTdHlsZRIiCgpiYWNrX2NvbG9yGAEgASgNSABSCWJhY2tDb2xvcogBARIiCg'
    'pmb3JlX2NvbG9yGAIgASgNSAFSCWZvcmVDb2xvcogBARI3CgZib3JkZXIYAyABKA4yGi52b2x2'
    'b3hncmlkLnYxLkJvcmRlclN0eWxlSAJSBmJvcmRlcogBARImCgxib3JkZXJfY29sb3IYBCABKA'
    '1IA1ILYm9yZGVyQ29sb3KIAQESPgoKYm9yZGVyX3RvcBgFIAEoDjIaLnZvbHZveGdyaWQudjEu'
    'Qm9yZGVyU3R5bGVIBFIJYm9yZGVyVG9wiAEBEkIKDGJvcmRlcl9yaWdodBgGIAEoDjIaLnZvbH'
    'ZveGdyaWQudjEuQm9yZGVyU3R5bGVIBVILYm9yZGVyUmlnaHSIAQESRAoNYm9yZGVyX2JvdHRv'
    'bRgHIAEoDjIaLnZvbHZveGdyaWQudjEuQm9yZGVyU3R5bGVIBlIMYm9yZGVyQm90dG9tiAEBEk'
    'AKC2JvcmRlcl9sZWZ0GAggASgOMhoudm9sdm94Z3JpZC52MS5Cb3JkZXJTdHlsZUgHUgpib3Jk'
    'ZXJMZWZ0iAEBEi0KEGJvcmRlcl90b3BfY29sb3IYCSABKA1ICFIOYm9yZGVyVG9wQ29sb3KIAQ'
    'ESMQoSYm9yZGVyX3JpZ2h0X2NvbG9yGAogASgNSAlSEGJvcmRlclJpZ2h0Q29sb3KIAQESMwoT'
    'Ym9yZGVyX2JvdHRvbV9jb2xvchgLIAEoDUgKUhFib3JkZXJCb3R0b21Db2xvcogBARIvChFib3'
    'JkZXJfbGVmdF9jb2xvchgMIAEoDUgLUg9ib3JkZXJMZWZ0Q29sb3KIAQESRwoLZmlsbF9oYW5k'
    'bGUYDSABKA4yIS52b2x2b3hncmlkLnYxLkZpbGxIYW5kbGVQb3NpdGlvbkgMUgpmaWxsSGFuZG'
    'xliAEBEi8KEWZpbGxfaGFuZGxlX2NvbG9yGA4gASgNSA1SD2ZpbGxIYW5kbGVDb2xvcogBAUIN'
    'CgtfYmFja19jb2xvckINCgtfZm9yZV9jb2xvckIJCgdfYm9yZGVyQg8KDV9ib3JkZXJfY29sb3'
    'JCDQoLX2JvcmRlcl90b3BCDwoNX2JvcmRlcl9yaWdodEIQCg5fYm9yZGVyX2JvdHRvbUIOCgxf'
    'Ym9yZGVyX2xlZnRCEwoRX2JvcmRlcl90b3BfY29sb3JCFQoTX2JvcmRlcl9yaWdodF9jb2xvck'
    'IWChRfYm9yZGVyX2JvdHRvbV9jb2xvckIUChJfYm9yZGVyX2xlZnRfY29sb3JCDgoMX2ZpbGxf'
    'aGFuZGxlQhQKEl9maWxsX2hhbmRsZV9jb2xvcg==');

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

@$core.Deprecated('Use headerSeparatorStyleDescriptor instead')
const HeaderSeparatorStyle$json = {
  '1': 'HeaderSeparatorStyle',
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
    {
      '1': 'width_px',
      '3': 3,
      '4': 1,
      '5': 5,
      '9': 2,
      '10': 'widthPx',
      '17': true
    },
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
    {'1': '_width_px'},
    {'1': '_skip_merged'},
  ],
};

/// Descriptor for `HeaderSeparatorStyle`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List headerSeparatorStyleDescriptor = $convert.base64Decode(
    'ChRIZWFkZXJTZXBhcmF0b3JTdHlsZRIdCgdlbmFibGVkGAEgASgISABSB2VuYWJsZWSIAQESGQ'
    'oFY29sb3IYAiABKA1IAVIFY29sb3KIAQESHgoId2lkdGhfcHgYAyABKAVIAlIHd2lkdGhQeIgB'
    'ARI1CgZoZWlnaHQYBCABKAsyHS52b2x2b3hncmlkLnYxLkhlYWRlck1hcmtTaXplUgZoZWlnaH'
    'QSJAoLc2tpcF9tZXJnZWQYBSABKAhIA1IKc2tpcE1lcmdlZIgBAUIKCghfZW5hYmxlZEIICgZf'
    'Y29sb3JCCwoJX3dpZHRoX3B4Qg4KDF9za2lwX21lcmdlZA==');

@$core.Deprecated('Use headerResizeHandleStyleDescriptor instead')
const HeaderResizeHandleStyle$json = {
  '1': 'HeaderResizeHandleStyle',
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
    {
      '1': 'width_px',
      '3': 3,
      '4': 1,
      '5': 5,
      '9': 2,
      '10': 'widthPx',
      '17': true
    },
    {
      '1': 'height',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.HeaderMarkSize',
      '10': 'height'
    },
    {
      '1': 'hit_width_px',
      '3': 5,
      '4': 1,
      '5': 5,
      '9': 3,
      '10': 'hitWidthPx',
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
    {'1': '_width_px'},
    {'1': '_hit_width_px'},
    {'1': '_show_only_when_resizable'},
  ],
};

/// Descriptor for `HeaderResizeHandleStyle`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List headerResizeHandleStyleDescriptor = $convert.base64Decode(
    'ChdIZWFkZXJSZXNpemVIYW5kbGVTdHlsZRIdCgdlbmFibGVkGAEgASgISABSB2VuYWJsZWSIAQ'
    'ESGQoFY29sb3IYAiABKA1IAVIFY29sb3KIAQESHgoId2lkdGhfcHgYAyABKAVIAlIHd2lkdGhQ'
    'eIgBARI1CgZoZWlnaHQYBCABKAsyHS52b2x2b3hncmlkLnYxLkhlYWRlck1hcmtTaXplUgZoZW'
    'lnaHQSJQoMaGl0X3dpZHRoX3B4GAUgASgFSANSCmhpdFdpZHRoUHiIAQESPAoYc2hvd19vbmx5'
    'X3doZW5fcmVzaXphYmxlGAYgASgISARSFXNob3dPbmx5V2hlblJlc2l6YWJsZYgBAUIKCghfZW'
    '5hYmxlZEIICgZfY29sb3JCCwoJX3dpZHRoX3B4Qg8KDV9oaXRfd2lkdGhfcHhCGwoZX3Nob3df'
    'b25seV93aGVuX3Jlc2l6YWJsZQ==');

@$core.Deprecated('Use iconThemeSlotsDescriptor instead')
const IconThemeSlots$json = {
  '1': 'IconThemeSlots',
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

/// Descriptor for `IconThemeSlots`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List iconThemeSlotsDescriptor = $convert.base64Decode(
    'Cg5JY29uVGhlbWVTbG90cxIqCg5zb3J0X2FzY2VuZGluZxgBIAEoCUgAUg1zb3J0QXNjZW5kaW'
    '5niAEBEiwKD3NvcnRfZGVzY2VuZGluZxgCIAEoCUgBUg5zb3J0RGVzY2VuZGluZ4gBARIgCglz'
    'b3J0X25vbmUYAyABKAlIAlIIc29ydE5vbmWIAQESKAoNdHJlZV9leHBhbmRlZBgEIAEoCUgDUg'
    'x0cmVlRXhwYW5kZWSIAQESKgoOdHJlZV9jb2xsYXBzZWQYBSABKAlIBFINdHJlZUNvbGxhcHNl'
    'ZIgBARIXCgRtZW51GAYgASgJSAVSBG1lbnWIAQESGwoGZmlsdGVyGAcgASgJSAZSBmZpbHRlco'
    'gBARIoCg1maWx0ZXJfYWN0aXZlGAggASgJSAdSDGZpbHRlckFjdGl2ZYgBARIdCgdjb2x1bW5z'
    'GAkgASgJSAhSB2NvbHVtbnOIAQESJAoLZHJhZ19oYW5kbGUYCiABKAlICVIKZHJhZ0hhbmRsZY'
    'gBARIuChBjaGVja2JveF9jaGVja2VkGAsgASgJSApSD2NoZWNrYm94Q2hlY2tlZIgBARIyChJj'
    'aGVja2JveF91bmNoZWNrZWQYDCABKAlIC1IRY2hlY2tib3hVbmNoZWNrZWSIAQESOgoWY2hlY2'
    'tib3hfaW5kZXRlcm1pbmF0ZRgNIAEoCUgMUhVjaGVja2JveEluZGV0ZXJtaW5hdGWIAQFCEQoP'
    'X3NvcnRfYXNjZW5kaW5nQhIKEF9zb3J0X2Rlc2NlbmRpbmdCDAoKX3NvcnRfbm9uZUIQCg5fdH'
    'JlZV9leHBhbmRlZEIRCg9fdHJlZV9jb2xsYXBzZWRCBwoFX21lbnVCCQoHX2ZpbHRlckIQCg5f'
    'ZmlsdGVyX2FjdGl2ZUIKCghfY29sdW1uc0IOCgxfZHJhZ19oYW5kbGVCEwoRX2NoZWNrYm94X2'
    'NoZWNrZWRCFQoTX2NoZWNrYm94X3VuY2hlY2tlZEIZChdfY2hlY2tib3hfaW5kZXRlcm1pbmF0'
    'ZQ==');

@$core.Deprecated('Use iconTextStyleDescriptor instead')
const IconTextStyle$json = {
  '1': 'IconTextStyle',
  '2': [
    {
      '1': 'font_name',
      '3': 1,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'fontName',
      '17': true
    },
    {'1': 'font_names', '3': 6, '4': 3, '5': 9, '10': 'fontNames'},
    {
      '1': 'font_size',
      '3': 2,
      '4': 1,
      '5': 2,
      '9': 1,
      '10': 'fontSize',
      '17': true
    },
    {
      '1': 'font_bold',
      '3': 3,
      '4': 1,
      '5': 8,
      '9': 2,
      '10': 'fontBold',
      '17': true
    },
    {
      '1': 'font_italic',
      '3': 4,
      '4': 1,
      '5': 8,
      '9': 3,
      '10': 'fontItalic',
      '17': true
    },
    {'1': 'color', '3': 5, '4': 1, '5': 13, '9': 4, '10': 'color', '17': true},
  ],
  '8': [
    {'1': '_font_name'},
    {'1': '_font_size'},
    {'1': '_font_bold'},
    {'1': '_font_italic'},
    {'1': '_color'},
  ],
};

/// Descriptor for `IconTextStyle`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List iconTextStyleDescriptor = $convert.base64Decode(
    'Cg1JY29uVGV4dFN0eWxlEiAKCWZvbnRfbmFtZRgBIAEoCUgAUghmb250TmFtZYgBARIdCgpmb2'
    '50X25hbWVzGAYgAygJUglmb250TmFtZXMSIAoJZm9udF9zaXplGAIgASgCSAFSCGZvbnRTaXpl'
    'iAEBEiAKCWZvbnRfYm9sZBgDIAEoCEgCUghmb250Qm9sZIgBARIkCgtmb250X2l0YWxpYxgEIA'
    'EoCEgDUgpmb250SXRhbGljiAEBEhkKBWNvbG9yGAUgASgNSARSBWNvbG9yiAEBQgwKCl9mb250'
    'X25hbWVCDAoKX2ZvbnRfc2l6ZUIMCgpfZm9udF9ib2xkQg4KDF9mb250X2l0YWxpY0IICgZfY2'
    '9sb3I=');

@$core.Deprecated('Use iconLayoutStyleDescriptor instead')
const IconLayoutStyle$json = {
  '1': 'IconLayoutStyle',
  '2': [
    {
      '1': 'align',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.IconAlign',
      '9': 0,
      '10': 'align',
      '17': true
    },
    {'1': 'gap_px', '3': 2, '4': 1, '5': 5, '9': 1, '10': 'gapPx', '17': true},
  ],
  '8': [
    {'1': '_align'},
    {'1': '_gap_px'},
  ],
};

/// Descriptor for `IconLayoutStyle`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List iconLayoutStyleDescriptor = $convert.base64Decode(
    'Cg9JY29uTGF5b3V0U3R5bGUSMwoFYWxpZ24YASABKA4yGC52b2x2b3hncmlkLnYxLkljb25BbG'
    'lnbkgAUgVhbGlnbogBARIaCgZnYXBfcHgYAiABKAVIAVIFZ2FwUHiIAQFCCAoGX2FsaWduQgkK'
    'B19nYXBfcHg=');

@$core.Deprecated('Use iconThemeDefaultsDescriptor instead')
const IconThemeDefaults$json = {
  '1': 'IconThemeDefaults',
  '2': [
    {
      '1': 'text_style',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.IconTextStyle',
      '10': 'textStyle'
    },
    {
      '1': 'layout',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.IconLayoutStyle',
      '10': 'layout'
    },
  ],
};

/// Descriptor for `IconThemeDefaults`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List iconThemeDefaultsDescriptor = $convert.base64Decode(
    'ChFJY29uVGhlbWVEZWZhdWx0cxI7Cgp0ZXh0X3N0eWxlGAEgASgLMhwudm9sdm94Z3JpZC52MS'
    '5JY29uVGV4dFN0eWxlUgl0ZXh0U3R5bGUSNgoGbGF5b3V0GAIgASgLMh4udm9sdm94Z3JpZC52'
    'MS5JY29uTGF5b3V0U3R5bGVSBmxheW91dA==');

@$core.Deprecated('Use iconThemeSlotStyleDescriptor instead')
const IconThemeSlotStyle$json = {
  '1': 'IconThemeSlotStyle',
  '2': [
    {
      '1': 'text_style',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.IconTextStyle',
      '10': 'textStyle'
    },
    {
      '1': 'layout',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.IconLayoutStyle',
      '10': 'layout'
    },
  ],
};

/// Descriptor for `IconThemeSlotStyle`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List iconThemeSlotStyleDescriptor = $convert.base64Decode(
    'ChJJY29uVGhlbWVTbG90U3R5bGUSOwoKdGV4dF9zdHlsZRgBIAEoCzIcLnZvbHZveGdyaWQudj'
    'EuSWNvblRleHRTdHlsZVIJdGV4dFN0eWxlEjYKBmxheW91dBgCIAEoCzIeLnZvbHZveGdyaWQu'
    'djEuSWNvbkxheW91dFN0eWxlUgZsYXlvdXQ=');

@$core.Deprecated('Use iconThemeSlotStylesDescriptor instead')
const IconThemeSlotStyles$json = {
  '1': 'IconThemeSlotStyles',
  '2': [
    {
      '1': 'sort_ascending',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.IconThemeSlotStyle',
      '10': 'sortAscending'
    },
    {
      '1': 'sort_descending',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.IconThemeSlotStyle',
      '10': 'sortDescending'
    },
    {
      '1': 'sort_none',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.IconThemeSlotStyle',
      '10': 'sortNone'
    },
    {
      '1': 'tree_expanded',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.IconThemeSlotStyle',
      '10': 'treeExpanded'
    },
    {
      '1': 'tree_collapsed',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.IconThemeSlotStyle',
      '10': 'treeCollapsed'
    },
    {
      '1': 'menu',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.IconThemeSlotStyle',
      '10': 'menu'
    },
    {
      '1': 'filter',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.IconThemeSlotStyle',
      '10': 'filter'
    },
    {
      '1': 'filter_active',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.IconThemeSlotStyle',
      '10': 'filterActive'
    },
    {
      '1': 'columns',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.IconThemeSlotStyle',
      '10': 'columns'
    },
    {
      '1': 'drag_handle',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.IconThemeSlotStyle',
      '10': 'dragHandle'
    },
    {
      '1': 'checkbox_checked',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.IconThemeSlotStyle',
      '10': 'checkboxChecked'
    },
    {
      '1': 'checkbox_unchecked',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.IconThemeSlotStyle',
      '10': 'checkboxUnchecked'
    },
    {
      '1': 'checkbox_indeterminate',
      '3': 13,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.IconThemeSlotStyle',
      '10': 'checkboxIndeterminate'
    },
  ],
};

/// Descriptor for `IconThemeSlotStyles`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List iconThemeSlotStylesDescriptor = $convert.base64Decode(
    'ChNJY29uVGhlbWVTbG90U3R5bGVzEkgKDnNvcnRfYXNjZW5kaW5nGAEgASgLMiEudm9sdm94Z3'
    'JpZC52MS5JY29uVGhlbWVTbG90U3R5bGVSDXNvcnRBc2NlbmRpbmcSSgoPc29ydF9kZXNjZW5k'
    'aW5nGAIgASgLMiEudm9sdm94Z3JpZC52MS5JY29uVGhlbWVTbG90U3R5bGVSDnNvcnREZXNjZW'
    '5kaW5nEj4KCXNvcnRfbm9uZRgDIAEoCzIhLnZvbHZveGdyaWQudjEuSWNvblRoZW1lU2xvdFN0'
    'eWxlUghzb3J0Tm9uZRJGCg10cmVlX2V4cGFuZGVkGAQgASgLMiEudm9sdm94Z3JpZC52MS5JY2'
    '9uVGhlbWVTbG90U3R5bGVSDHRyZWVFeHBhbmRlZBJICg50cmVlX2NvbGxhcHNlZBgFIAEoCzIh'
    'LnZvbHZveGdyaWQudjEuSWNvblRoZW1lU2xvdFN0eWxlUg10cmVlQ29sbGFwc2VkEjUKBG1lbn'
    'UYBiABKAsyIS52b2x2b3hncmlkLnYxLkljb25UaGVtZVNsb3RTdHlsZVIEbWVudRI5CgZmaWx0'
    'ZXIYByABKAsyIS52b2x2b3hncmlkLnYxLkljb25UaGVtZVNsb3RTdHlsZVIGZmlsdGVyEkYKDW'
    'ZpbHRlcl9hY3RpdmUYCCABKAsyIS52b2x2b3hncmlkLnYxLkljb25UaGVtZVNsb3RTdHlsZVIM'
    'ZmlsdGVyQWN0aXZlEjsKB2NvbHVtbnMYCSABKAsyIS52b2x2b3hncmlkLnYxLkljb25UaGVtZV'
    'Nsb3RTdHlsZVIHY29sdW1ucxJCCgtkcmFnX2hhbmRsZRgKIAEoCzIhLnZvbHZveGdyaWQudjEu'
    'SWNvblRoZW1lU2xvdFN0eWxlUgpkcmFnSGFuZGxlEkwKEGNoZWNrYm94X2NoZWNrZWQYCyABKA'
    'syIS52b2x2b3hncmlkLnYxLkljb25UaGVtZVNsb3RTdHlsZVIPY2hlY2tib3hDaGVja2VkElAK'
    'EmNoZWNrYm94X3VuY2hlY2tlZBgMIAEoCzIhLnZvbHZveGdyaWQudjEuSWNvblRoZW1lU2xvdF'
    'N0eWxlUhFjaGVja2JveFVuY2hlY2tlZBJYChZjaGVja2JveF9pbmRldGVybWluYXRlGA0gASgL'
    'MiEudm9sdm94Z3JpZC52MS5JY29uVGhlbWVTbG90U3R5bGVSFWNoZWNrYm94SW5kZXRlcm1pbm'
    'F0ZQ==');

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
      '1': 'indicator_bands',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.IndicatorBandsConfig',
      '10': 'indicatorBands'
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
    'RlckNvbmZpZ1IJcmVuZGVyaW5nEhgKB3ZlcnNpb24YCiABKAlSB3ZlcnNpb24STAoPaW5kaWNh'
    'dG9yX2JhbmRzGAsgASgLMiMudm9sdm94Z3JpZC52MS5JbmRpY2F0b3JCYW5kc0NvbmZpZ1IOaW'
    '5kaWNhdG9yQmFuZHM=');

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
    {
      '1': 'format_string',
      '3': 11,
      '4': 1,
      '5': 9,
      '9': 10,
      '10': 'formatString',
      '17': true
    },
    {
      '1': 'word_wrap',
      '3': 12,
      '4': 1,
      '5': 8,
      '9': 11,
      '10': 'wordWrap',
      '17': true
    },
    {
      '1': 'ellipsis',
      '3': 13,
      '4': 1,
      '5': 5,
      '9': 12,
      '10': 'ellipsis',
      '17': true
    },
    {
      '1': 'text_overflow',
      '3': 14,
      '4': 1,
      '5': 8,
      '9': 13,
      '10': 'textOverflow',
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
    {'1': '_format_string'},
    {'1': '_word_wrap'},
    {'1': '_ellipsis'},
    {'1': '_text_overflow'},
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
    'xhc3RDb2yIAQESKAoNZm9ybWF0X3N0cmluZxgLIAEoCUgKUgxmb3JtYXRTdHJpbmeIAQESIAoJ'
    'd29yZF93cmFwGAwgASgISAtSCHdvcmRXcmFwiAEBEh8KCGVsbGlwc2lzGA0gASgFSAxSCGVsbG'
    'lwc2lziAEBEigKDXRleHRfb3ZlcmZsb3cYDiABKAhIDVIMdGV4dE92ZXJmbG93iAEBQgcKBV9y'
    'b3dzQgcKBV9jb2xzQg0KC19maXhlZF9yb3dzQg0KC19maXhlZF9jb2xzQg4KDF9mcm96ZW5fcm'
    '93c0IOCgxfZnJvemVuX2NvbHNCFQoTX2RlZmF1bHRfcm93X2hlaWdodEIUChJfZGVmYXVsdF9j'
    'b2xfd2lkdGhCEAoOX3JpZ2h0X3RvX2xlZnRCEgoQX2V4dGVuZF9sYXN0X2NvbEIQCg5fZm9ybW'
    'F0X3N0cmluZ0IMCgpfd29yZF93cmFwQgsKCV9lbGxpcHNpc0IQCg5fdGV4dF9vdmVyZmxvdw==');

@$core.Deprecated('Use styleConfigDescriptor instead')
const StyleConfig$json = {
  '1': 'StyleConfig',
  '2': [
    {
      '1': 'appearance',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.BorderAppearance',
      '9': 0,
      '10': 'appearance',
      '17': true
    },
    {
      '1': 'back_color',
      '3': 2,
      '4': 1,
      '5': 13,
      '9': 1,
      '10': 'backColor',
      '17': true
    },
    {
      '1': 'fore_color',
      '3': 3,
      '4': 1,
      '5': 13,
      '9': 2,
      '10': 'foreColor',
      '17': true
    },
    {
      '1': 'back_color_fixed',
      '3': 4,
      '4': 1,
      '5': 13,
      '9': 3,
      '10': 'backColorFixed',
      '17': true
    },
    {
      '1': 'fore_color_fixed',
      '3': 5,
      '4': 1,
      '5': 13,
      '9': 4,
      '10': 'foreColorFixed',
      '17': true
    },
    {
      '1': 'back_color_frozen',
      '3': 6,
      '4': 1,
      '5': 13,
      '9': 5,
      '10': 'backColorFrozen',
      '17': true
    },
    {
      '1': 'fore_color_frozen',
      '3': 7,
      '4': 1,
      '5': 13,
      '9': 6,
      '10': 'foreColorFrozen',
      '17': true
    },
    {
      '1': 'back_color_bkg',
      '3': 10,
      '4': 1,
      '5': 13,
      '9': 7,
      '10': 'backColorBkg',
      '17': true
    },
    {
      '1': 'back_color_alternate',
      '3': 11,
      '4': 1,
      '5': 13,
      '9': 8,
      '10': 'backColorAlternate',
      '17': true
    },
    {
      '1': 'grid_lines',
      '3': 12,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.GridLineStyle',
      '9': 9,
      '10': 'gridLines',
      '17': true
    },
    {
      '1': 'grid_lines_fixed',
      '3': 13,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.GridLineStyle',
      '9': 10,
      '10': 'gridLinesFixed',
      '17': true
    },
    {
      '1': 'grid_color',
      '3': 14,
      '4': 1,
      '5': 13,
      '9': 11,
      '10': 'gridColor',
      '17': true
    },
    {
      '1': 'grid_color_fixed',
      '3': 15,
      '4': 1,
      '5': 13,
      '9': 12,
      '10': 'gridColorFixed',
      '17': true
    },
    {
      '1': 'grid_line_width',
      '3': 16,
      '4': 1,
      '5': 5,
      '9': 13,
      '10': 'gridLineWidth',
      '17': true
    },
    {
      '1': 'text_effect',
      '3': 17,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.TextEffect',
      '9': 14,
      '10': 'textEffect',
      '17': true
    },
    {
      '1': 'text_effect_fixed',
      '3': 18,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.TextEffect',
      '9': 15,
      '10': 'textEffectFixed',
      '17': true
    },
    {
      '1': 'font_name',
      '3': 19,
      '4': 1,
      '5': 9,
      '9': 16,
      '10': 'fontName',
      '17': true
    },
    {
      '1': 'font_size',
      '3': 20,
      '4': 1,
      '5': 2,
      '9': 17,
      '10': 'fontSize',
      '17': true
    },
    {
      '1': 'font_bold',
      '3': 21,
      '4': 1,
      '5': 8,
      '9': 18,
      '10': 'fontBold',
      '17': true
    },
    {
      '1': 'font_italic',
      '3': 22,
      '4': 1,
      '5': 8,
      '9': 19,
      '10': 'fontItalic',
      '17': true
    },
    {
      '1': 'font_underline',
      '3': 23,
      '4': 1,
      '5': 8,
      '9': 20,
      '10': 'fontUnderline',
      '17': true
    },
    {
      '1': 'font_strikethrough',
      '3': 24,
      '4': 1,
      '5': 8,
      '9': 21,
      '10': 'fontStrikethrough',
      '17': true
    },
    {
      '1': 'font_width',
      '3': 25,
      '4': 1,
      '5': 2,
      '9': 22,
      '10': 'fontWidth',
      '17': true
    },
    {
      '1': 'sheet_border',
      '3': 26,
      '4': 1,
      '5': 13,
      '9': 23,
      '10': 'sheetBorder',
      '17': true
    },
    {
      '1': 'progress_color',
      '3': 27,
      '4': 1,
      '5': 13,
      '9': 24,
      '10': 'progressColor',
      '17': true
    },
    {
      '1': 'image_over_text',
      '3': 28,
      '4': 1,
      '5': 8,
      '9': 25,
      '10': 'imageOverText',
      '17': true
    },
    {
      '1': 'background_image',
      '3': 29,
      '4': 1,
      '5': 12,
      '9': 26,
      '10': 'backgroundImage',
      '17': true
    },
    {
      '1': 'background_image_alignment',
      '3': 30,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.ImageAlignment',
      '9': 27,
      '10': 'backgroundImageAlignment',
      '17': true
    },
    {
      '1': 'text_render_mode',
      '3': 31,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.TextRenderMode',
      '9': 28,
      '10': 'textRenderMode',
      '17': true
    },
    {
      '1': 'text_hinting_mode',
      '3': 32,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.TextHintingMode',
      '9': 29,
      '10': 'textHintingMode',
      '17': true
    },
    {
      '1': 'text_pixel_snap',
      '3': 33,
      '4': 1,
      '5': 8,
      '9': 30,
      '10': 'textPixelSnap',
      '17': true
    },
    {
      '1': 'apply_scope',
      '3': 34,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.ApplyScope',
      '9': 31,
      '10': 'applyScope',
      '17': true
    },
    {
      '1': 'custom_render',
      '3': 35,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.CustomRenderMode',
      '9': 32,
      '10': 'customRender',
      '17': true
    },
    {
      '1': 'sort_ascending_picture',
      '3': 36,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.ImageData',
      '10': 'sortAscendingPicture'
    },
    {
      '1': 'sort_descending_picture',
      '3': 37,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.ImageData',
      '10': 'sortDescendingPicture'
    },
    {
      '1': 'node_open_picture',
      '3': 38,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.ImageData',
      '10': 'nodeOpenPicture'
    },
    {
      '1': 'node_closed_picture',
      '3': 39,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.ImageData',
      '10': 'nodeClosedPicture'
    },
    {
      '1': 'cell_padding',
      '3': 40,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.CellPadding',
      '10': 'cellPadding'
    },
    {
      '1': 'fixed_cell_padding',
      '3': 41,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.CellPadding',
      '10': 'fixedCellPadding'
    },
    {
      '1': 'header_separator',
      '3': 42,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.HeaderSeparatorStyle',
      '10': 'headerSeparator'
    },
    {
      '1': 'header_resize_handle',
      '3': 43,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.HeaderResizeHandleStyle',
      '10': 'headerResizeHandle'
    },
    {
      '1': 'icon_theme_slots',
      '3': 44,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.IconThemeSlots',
      '10': 'iconThemeSlots'
    },
    {
      '1': 'checkbox_checked_picture',
      '3': 45,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.ImageData',
      '10': 'checkboxCheckedPicture'
    },
    {
      '1': 'checkbox_unchecked_picture',
      '3': 46,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.ImageData',
      '10': 'checkboxUncheckedPicture'
    },
    {
      '1': 'checkbox_indeterminate_picture',
      '3': 47,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.ImageData',
      '10': 'checkboxIndeterminatePicture'
    },
    {
      '1': 'icon_theme_defaults',
      '3': 48,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.IconThemeDefaults',
      '10': 'iconThemeDefaults'
    },
    {
      '1': 'icon_theme_slot_styles',
      '3': 49,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.IconThemeSlotStyles',
      '10': 'iconThemeSlotStyles'
    },
    {
      '1': 'show_sort_numbers',
      '3': 50,
      '4': 1,
      '5': 8,
      '9': 33,
      '10': 'showSortNumbers',
      '17': true
    },
  ],
  '8': [
    {'1': '_appearance'},
    {'1': '_back_color'},
    {'1': '_fore_color'},
    {'1': '_back_color_fixed'},
    {'1': '_fore_color_fixed'},
    {'1': '_back_color_frozen'},
    {'1': '_fore_color_frozen'},
    {'1': '_back_color_bkg'},
    {'1': '_back_color_alternate'},
    {'1': '_grid_lines'},
    {'1': '_grid_lines_fixed'},
    {'1': '_grid_color'},
    {'1': '_grid_color_fixed'},
    {'1': '_grid_line_width'},
    {'1': '_text_effect'},
    {'1': '_text_effect_fixed'},
    {'1': '_font_name'},
    {'1': '_font_size'},
    {'1': '_font_bold'},
    {'1': '_font_italic'},
    {'1': '_font_underline'},
    {'1': '_font_strikethrough'},
    {'1': '_font_width'},
    {'1': '_sheet_border'},
    {'1': '_progress_color'},
    {'1': '_image_over_text'},
    {'1': '_background_image'},
    {'1': '_background_image_alignment'},
    {'1': '_text_render_mode'},
    {'1': '_text_hinting_mode'},
    {'1': '_text_pixel_snap'},
    {'1': '_apply_scope'},
    {'1': '_custom_render'},
    {'1': '_show_sort_numbers'},
  ],
};

/// Descriptor for `StyleConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List styleConfigDescriptor = $convert.base64Decode(
    'CgtTdHlsZUNvbmZpZxJECgphcHBlYXJhbmNlGAEgASgOMh8udm9sdm94Z3JpZC52MS5Cb3JkZX'
    'JBcHBlYXJhbmNlSABSCmFwcGVhcmFuY2WIAQESIgoKYmFja19jb2xvchgCIAEoDUgBUgliYWNr'
    'Q29sb3KIAQESIgoKZm9yZV9jb2xvchgDIAEoDUgCUglmb3JlQ29sb3KIAQESLQoQYmFja19jb2'
    'xvcl9maXhlZBgEIAEoDUgDUg5iYWNrQ29sb3JGaXhlZIgBARItChBmb3JlX2NvbG9yX2ZpeGVk'
    'GAUgASgNSARSDmZvcmVDb2xvckZpeGVkiAEBEi8KEWJhY2tfY29sb3JfZnJvemVuGAYgASgNSA'
    'VSD2JhY2tDb2xvckZyb3plbogBARIvChFmb3JlX2NvbG9yX2Zyb3plbhgHIAEoDUgGUg9mb3Jl'
    'Q29sb3JGcm96ZW6IAQESKQoOYmFja19jb2xvcl9ia2cYCiABKA1IB1IMYmFja0NvbG9yQmtniA'
    'EBEjUKFGJhY2tfY29sb3JfYWx0ZXJuYXRlGAsgASgNSAhSEmJhY2tDb2xvckFsdGVybmF0ZYgB'
    'ARJACgpncmlkX2xpbmVzGAwgASgOMhwudm9sdm94Z3JpZC52MS5HcmlkTGluZVN0eWxlSAlSCW'
    'dyaWRMaW5lc4gBARJLChBncmlkX2xpbmVzX2ZpeGVkGA0gASgOMhwudm9sdm94Z3JpZC52MS5H'
    'cmlkTGluZVN0eWxlSApSDmdyaWRMaW5lc0ZpeGVkiAEBEiIKCmdyaWRfY29sb3IYDiABKA1IC1'
    'IJZ3JpZENvbG9yiAEBEi0KEGdyaWRfY29sb3JfZml4ZWQYDyABKA1IDFIOZ3JpZENvbG9yRml4'
    'ZWSIAQESKwoPZ3JpZF9saW5lX3dpZHRoGBAgASgFSA1SDWdyaWRMaW5lV2lkdGiIAQESPwoLdG'
    'V4dF9lZmZlY3QYESABKA4yGS52b2x2b3hncmlkLnYxLlRleHRFZmZlY3RIDlIKdGV4dEVmZmVj'
    'dIgBARJKChF0ZXh0X2VmZmVjdF9maXhlZBgSIAEoDjIZLnZvbHZveGdyaWQudjEuVGV4dEVmZm'
    'VjdEgPUg90ZXh0RWZmZWN0Rml4ZWSIAQESIAoJZm9udF9uYW1lGBMgASgJSBBSCGZvbnROYW1l'
    'iAEBEiAKCWZvbnRfc2l6ZRgUIAEoAkgRUghmb250U2l6ZYgBARIgCglmb250X2JvbGQYFSABKA'
    'hIElIIZm9udEJvbGSIAQESJAoLZm9udF9pdGFsaWMYFiABKAhIE1IKZm9udEl0YWxpY4gBARIq'
    'Cg5mb250X3VuZGVybGluZRgXIAEoCEgUUg1mb250VW5kZXJsaW5liAEBEjIKEmZvbnRfc3RyaW'
    'tldGhyb3VnaBgYIAEoCEgVUhFmb250U3RyaWtldGhyb3VnaIgBARIiCgpmb250X3dpZHRoGBkg'
    'ASgCSBZSCWZvbnRXaWR0aIgBARImCgxzaGVldF9ib3JkZXIYGiABKA1IF1ILc2hlZXRCb3JkZX'
    'KIAQESKgoOcHJvZ3Jlc3NfY29sb3IYGyABKA1IGFINcHJvZ3Jlc3NDb2xvcogBARIrCg9pbWFn'
    'ZV9vdmVyX3RleHQYHCABKAhIGVINaW1hZ2VPdmVyVGV4dIgBARIuChBiYWNrZ3JvdW5kX2ltYW'
    'dlGB0gASgMSBpSD2JhY2tncm91bmRJbWFnZYgBARJgChpiYWNrZ3JvdW5kX2ltYWdlX2FsaWdu'
    'bWVudBgeIAEoDjIdLnZvbHZveGdyaWQudjEuSW1hZ2VBbGlnbm1lbnRIG1IYYmFja2dyb3VuZE'
    'ltYWdlQWxpZ25tZW50iAEBEkwKEHRleHRfcmVuZGVyX21vZGUYHyABKA4yHS52b2x2b3hncmlk'
    'LnYxLlRleHRSZW5kZXJNb2RlSBxSDnRleHRSZW5kZXJNb2RliAEBEk8KEXRleHRfaGludGluZ1'
    '9tb2RlGCAgASgOMh4udm9sdm94Z3JpZC52MS5UZXh0SGludGluZ01vZGVIHVIPdGV4dEhpbnRp'
    'bmdNb2RliAEBEisKD3RleHRfcGl4ZWxfc25hcBghIAEoCEgeUg10ZXh0UGl4ZWxTbmFwiAEBEj'
    '8KC2FwcGx5X3Njb3BlGCIgASgOMhkudm9sdm94Z3JpZC52MS5BcHBseVNjb3BlSB9SCmFwcGx5'
    'U2NvcGWIAQESSQoNY3VzdG9tX3JlbmRlchgjIAEoDjIfLnZvbHZveGdyaWQudjEuQ3VzdG9tUm'
    'VuZGVyTW9kZUggUgxjdXN0b21SZW5kZXKIAQESTgoWc29ydF9hc2NlbmRpbmdfcGljdHVyZRgk'
    'IAEoCzIYLnZvbHZveGdyaWQudjEuSW1hZ2VEYXRhUhRzb3J0QXNjZW5kaW5nUGljdHVyZRJQCh'
    'dzb3J0X2Rlc2NlbmRpbmdfcGljdHVyZRglIAEoCzIYLnZvbHZveGdyaWQudjEuSW1hZ2VEYXRh'
    'UhVzb3J0RGVzY2VuZGluZ1BpY3R1cmUSRAoRbm9kZV9vcGVuX3BpY3R1cmUYJiABKAsyGC52b2'
    'x2b3hncmlkLnYxLkltYWdlRGF0YVIPbm9kZU9wZW5QaWN0dXJlEkgKE25vZGVfY2xvc2VkX3Bp'
    'Y3R1cmUYJyABKAsyGC52b2x2b3hncmlkLnYxLkltYWdlRGF0YVIRbm9kZUNsb3NlZFBpY3R1cm'
    'USPQoMY2VsbF9wYWRkaW5nGCggASgLMhoudm9sdm94Z3JpZC52MS5DZWxsUGFkZGluZ1ILY2Vs'
    'bFBhZGRpbmcSSAoSZml4ZWRfY2VsbF9wYWRkaW5nGCkgASgLMhoudm9sdm94Z3JpZC52MS5DZW'
    'xsUGFkZGluZ1IQZml4ZWRDZWxsUGFkZGluZxJOChBoZWFkZXJfc2VwYXJhdG9yGCogASgLMiMu'
    'dm9sdm94Z3JpZC52MS5IZWFkZXJTZXBhcmF0b3JTdHlsZVIPaGVhZGVyU2VwYXJhdG9yElgKFG'
    'hlYWRlcl9yZXNpemVfaGFuZGxlGCsgASgLMiYudm9sdm94Z3JpZC52MS5IZWFkZXJSZXNpemVI'
    'YW5kbGVTdHlsZVISaGVhZGVyUmVzaXplSGFuZGxlEkcKEGljb25fdGhlbWVfc2xvdHMYLCABKA'
    'syHS52b2x2b3hncmlkLnYxLkljb25UaGVtZVNsb3RzUg5pY29uVGhlbWVTbG90cxJSChhjaGVj'
    'a2JveF9jaGVja2VkX3BpY3R1cmUYLSABKAsyGC52b2x2b3hncmlkLnYxLkltYWdlRGF0YVIWY2'
    'hlY2tib3hDaGVja2VkUGljdHVyZRJWChpjaGVja2JveF91bmNoZWNrZWRfcGljdHVyZRguIAEo'
    'CzIYLnZvbHZveGdyaWQudjEuSW1hZ2VEYXRhUhhjaGVja2JveFVuY2hlY2tlZFBpY3R1cmUSXg'
    'oeY2hlY2tib3hfaW5kZXRlcm1pbmF0ZV9waWN0dXJlGC8gASgLMhgudm9sdm94Z3JpZC52MS5J'
    'bWFnZURhdGFSHGNoZWNrYm94SW5kZXRlcm1pbmF0ZVBpY3R1cmUSUAoTaWNvbl90aGVtZV9kZW'
    'ZhdWx0cxgwIAEoCzIgLnZvbHZveGdyaWQudjEuSWNvblRoZW1lRGVmYXVsdHNSEWljb25UaGVt'
    'ZURlZmF1bHRzElcKFmljb25fdGhlbWVfc2xvdF9zdHlsZXMYMSABKAsyIi52b2x2b3hncmlkLn'
    'YxLkljb25UaGVtZVNsb3RTdHlsZXNSE2ljb25UaGVtZVNsb3RTdHlsZXMSLwoRc2hvd19zb3J0'
    'X251bWJlcnMYMiABKAhIIVIPc2hvd1NvcnROdW1iZXJziAEBQg0KC19hcHBlYXJhbmNlQg0KC1'
    '9iYWNrX2NvbG9yQg0KC19mb3JlX2NvbG9yQhMKEV9iYWNrX2NvbG9yX2ZpeGVkQhMKEV9mb3Jl'
    'X2NvbG9yX2ZpeGVkQhQKEl9iYWNrX2NvbG9yX2Zyb3plbkIUChJfZm9yZV9jb2xvcl9mcm96ZW'
    '5CEQoPX2JhY2tfY29sb3JfYmtnQhcKFV9iYWNrX2NvbG9yX2FsdGVybmF0ZUINCgtfZ3JpZF9s'
    'aW5lc0ITChFfZ3JpZF9saW5lc19maXhlZEINCgtfZ3JpZF9jb2xvckITChFfZ3JpZF9jb2xvcl'
    '9maXhlZEISChBfZ3JpZF9saW5lX3dpZHRoQg4KDF90ZXh0X2VmZmVjdEIUChJfdGV4dF9lZmZl'
    'Y3RfZml4ZWRCDAoKX2ZvbnRfbmFtZUIMCgpfZm9udF9zaXplQgwKCl9mb250X2JvbGRCDgoMX2'
    'ZvbnRfaXRhbGljQhEKD19mb250X3VuZGVybGluZUIVChNfZm9udF9zdHJpa2V0aHJvdWdoQg0K'
    'C19mb250X3dpZHRoQg8KDV9zaGVldF9ib3JkZXJCEQoPX3Byb2dyZXNzX2NvbG9yQhIKEF9pbW'
    'FnZV9vdmVyX3RleHRCEwoRX2JhY2tncm91bmRfaW1hZ2VCHQobX2JhY2tncm91bmRfaW1hZ2Vf'
    'YWxpZ25tZW50QhMKEV90ZXh0X3JlbmRlcl9tb2RlQhQKEl90ZXh0X2hpbnRpbmdfbW9kZUISCh'
    'BfdGV4dF9waXhlbF9zbmFwQg4KDF9hcHBseV9zY29wZUIQCg5fY3VzdG9tX3JlbmRlckIUChJf'
    'c2hvd19zb3J0X251bWJlcnM=');

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
      '1': 'selection_visibility',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.SelectionVisibility',
      '9': 2,
      '10': 'selectionVisibility',
      '17': true
    },
    {
      '1': 'allow_selection',
      '3': 4,
      '4': 1,
      '5': 8,
      '9': 3,
      '10': 'allowSelection',
      '17': true
    },
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
      '1': 'selection_style',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.HighlightStyle',
      '10': 'selectionStyle'
    },
    {
      '1': 'hover_mode',
      '3': 7,
      '4': 1,
      '5': 13,
      '9': 5,
      '10': 'hoverMode',
      '17': true
    },
    {
      '1': 'hover_row_style',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.HighlightStyle',
      '10': 'hoverRowStyle'
    },
    {
      '1': 'hover_column_style',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.HighlightStyle',
      '10': 'hoverColumnStyle'
    },
    {
      '1': 'hover_cell_style',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.HighlightStyle',
      '10': 'hoverCellStyle'
    },
  ],
  '8': [
    {'1': '_mode'},
    {'1': '_focus_border'},
    {'1': '_selection_visibility'},
    {'1': '_allow_selection'},
    {'1': '_header_click_select'},
    {'1': '_hover_mode'},
  ],
};

/// Descriptor for `SelectionConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List selectionConfigDescriptor = $convert.base64Decode(
    'Cg9TZWxlY3Rpb25Db25maWcSNQoEbW9kZRgBIAEoDjIcLnZvbHZveGdyaWQudjEuU2VsZWN0aW'
    '9uTW9kZUgAUgRtb2RliAEBEkcKDGZvY3VzX2JvcmRlchgCIAEoDjIfLnZvbHZveGdyaWQudjEu'
    'Rm9jdXNCb3JkZXJTdHlsZUgBUgtmb2N1c0JvcmRlcogBARJaChRzZWxlY3Rpb25fdmlzaWJpbG'
    'l0eRgDIAEoDjIiLnZvbHZveGdyaWQudjEuU2VsZWN0aW9uVmlzaWJpbGl0eUgCUhNzZWxlY3Rp'
    'b25WaXNpYmlsaXR5iAEBEiwKD2FsbG93X3NlbGVjdGlvbhgEIAEoCEgDUg5hbGxvd1NlbGVjdG'
    'lvbogBARIzChNoZWFkZXJfY2xpY2tfc2VsZWN0GAUgASgISARSEWhlYWRlckNsaWNrU2VsZWN0'
    'iAEBEkYKD3NlbGVjdGlvbl9zdHlsZRgGIAEoCzIdLnZvbHZveGdyaWQudjEuSGlnaGxpZ2h0U3'
    'R5bGVSDnNlbGVjdGlvblN0eWxlEiIKCmhvdmVyX21vZGUYByABKA1IBVIJaG92ZXJNb2RliAEB'
    'EkUKD2hvdmVyX3Jvd19zdHlsZRgIIAEoCzIdLnZvbHZveGdyaWQudjEuSGlnaGxpZ2h0U3R5bG'
    'VSDWhvdmVyUm93U3R5bGUSSwoSaG92ZXJfY29sdW1uX3N0eWxlGAkgASgLMh0udm9sdm94Z3Jp'
    'ZC52MS5IaWdobGlnaHRTdHlsZVIQaG92ZXJDb2x1bW5TdHlsZRJHChBob3Zlcl9jZWxsX3N0eW'
    'xlGAogASgLMh0udm9sdm94Z3JpZC52MS5IaWdobGlnaHRTdHlsZVIOaG92ZXJDZWxsU3R5bGVC'
    'BwoFX21vZGVCDwoNX2ZvY3VzX2JvcmRlckIXChVfc2VsZWN0aW9uX3Zpc2liaWxpdHlCEgoQX2'
    'FsbG93X3NlbGVjdGlvbkIWChRfaGVhZGVyX2NsaWNrX3NlbGVjdEINCgtfaG92ZXJfbW9kZQ==');

@$core.Deprecated('Use editConfigDescriptor instead')
const EditConfig$json = {
  '1': 'EditConfig',
  '2': [
    {
      '1': 'edit_trigger',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.EditTrigger',
      '9': 0,
      '10': 'editTrigger',
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
      '1': 'edit_max_length',
      '3': 5,
      '4': 1,
      '5': 5,
      '9': 4,
      '10': 'editMaxLength',
      '17': true
    },
    {
      '1': 'edit_mask',
      '3': 6,
      '4': 1,
      '5': 9,
      '9': 5,
      '10': 'editMask',
      '17': true
    },
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
  ],
  '8': [
    {'1': '_edit_trigger'},
    {'1': '_tab_behavior'},
    {'1': '_dropdown_trigger'},
    {'1': '_dropdown_search'},
    {'1': '_edit_max_length'},
    {'1': '_edit_mask'},
    {'1': '_host_key_dispatch'},
    {'1': '_host_pointer_dispatch'},
  ],
};

/// Descriptor for `EditConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List editConfigDescriptor = $convert.base64Decode(
    'CgpFZGl0Q29uZmlnEkIKDGVkaXRfdHJpZ2dlchgBIAEoDjIaLnZvbHZveGdyaWQudjEuRWRpdF'
    'RyaWdnZXJIAFILZWRpdFRyaWdnZXKIAQESQgoMdGFiX2JlaGF2aW9yGAIgASgOMhoudm9sdm94'
    'Z3JpZC52MS5UYWJCZWhhdmlvckgBUgt0YWJCZWhhdmlvcogBARJOChBkcm9wZG93bl90cmlnZ2'
    'VyGAMgASgOMh4udm9sdm94Z3JpZC52MS5Ecm9wZG93blRyaWdnZXJIAlIPZHJvcGRvd25Ucmln'
    'Z2VyiAEBEiwKD2Ryb3Bkb3duX3NlYXJjaBgEIAEoCEgDUg5kcm9wZG93blNlYXJjaIgBARIrCg'
    '9lZGl0X21heF9sZW5ndGgYBSABKAVIBFINZWRpdE1heExlbmd0aIgBARIgCgllZGl0X21hc2sY'
    'BiABKAlIBVIIZWRpdE1hc2uIAQESLwoRaG9zdF9rZXlfZGlzcGF0Y2gYByABKAhIBlIPaG9zdE'
    'tleURpc3BhdGNoiAEBEjcKFWhvc3RfcG9pbnRlcl9kaXNwYXRjaBgIIAEoCEgHUhNob3N0UG9p'
    'bnRlckRpc3BhdGNoiAEBQg8KDV9lZGl0X3RyaWdnZXJCDwoNX3RhYl9iZWhhdmlvckITChFfZH'
    'JvcGRvd25fdHJpZ2dlckISChBfZHJvcGRvd25fc2VhcmNoQhIKEF9lZGl0X21heF9sZW5ndGhC'
    'DAoKX2VkaXRfbWFza0IUChJfaG9zdF9rZXlfZGlzcGF0Y2hCGAoWX2hvc3RfcG9pbnRlcl9kaX'
    'NwYXRjaA==');

@$core.Deprecated('Use scrollConfigDescriptor instead')
const ScrollConfig$json = {
  '1': 'ScrollConfig',
  '2': [
    {
      '1': 'scrollbars',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.ScrollBarsMode',
      '9': 0,
      '10': 'scrollbars',
      '17': true
    },
    {
      '1': 'scroll_track',
      '3': 2,
      '4': 1,
      '5': 8,
      '9': 1,
      '10': 'scrollTrack',
      '17': true
    },
    {
      '1': 'scroll_tips',
      '3': 3,
      '4': 1,
      '5': 8,
      '9': 2,
      '10': 'scrollTips',
      '17': true
    },
    {
      '1': 'fling_enabled',
      '3': 4,
      '4': 1,
      '5': 8,
      '9': 3,
      '10': 'flingEnabled',
      '17': true
    },
    {
      '1': 'fling_impulse_gain',
      '3': 5,
      '4': 1,
      '5': 2,
      '9': 4,
      '10': 'flingImpulseGain',
      '17': true
    },
    {
      '1': 'fling_friction',
      '3': 6,
      '4': 1,
      '5': 2,
      '9': 5,
      '10': 'flingFriction',
      '17': true
    },
    {
      '1': 'pinch_zoom_enabled',
      '3': 7,
      '4': 1,
      '5': 8,
      '9': 6,
      '10': 'pinchZoomEnabled',
      '17': true
    },
    {
      '1': 'fast_scroll',
      '3': 8,
      '4': 1,
      '5': 8,
      '9': 7,
      '10': 'fastScroll',
      '17': true
    },
  ],
  '8': [
    {'1': '_scrollbars'},
    {'1': '_scroll_track'},
    {'1': '_scroll_tips'},
    {'1': '_fling_enabled'},
    {'1': '_fling_impulse_gain'},
    {'1': '_fling_friction'},
    {'1': '_pinch_zoom_enabled'},
    {'1': '_fast_scroll'},
  ],
};

/// Descriptor for `ScrollConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List scrollConfigDescriptor = $convert.base64Decode(
    'CgxTY3JvbGxDb25maWcSQgoKc2Nyb2xsYmFycxgBIAEoDjIdLnZvbHZveGdyaWQudjEuU2Nyb2'
    'xsQmFyc01vZGVIAFIKc2Nyb2xsYmFyc4gBARImCgxzY3JvbGxfdHJhY2sYAiABKAhIAVILc2Ny'
    'b2xsVHJhY2uIAQESJAoLc2Nyb2xsX3RpcHMYAyABKAhIAlIKc2Nyb2xsVGlwc4gBARIoCg1mbG'
    'luZ19lbmFibGVkGAQgASgISANSDGZsaW5nRW5hYmxlZIgBARIxChJmbGluZ19pbXB1bHNlX2dh'
    'aW4YBSABKAJIBFIQZmxpbmdJbXB1bHNlR2FpbogBARIqCg5mbGluZ19mcmljdGlvbhgGIAEoAk'
    'gFUg1mbGluZ0ZyaWN0aW9uiAEBEjEKEnBpbmNoX3pvb21fZW5hYmxlZBgHIAEoCEgGUhBwaW5j'
    'aFpvb21FbmFibGVkiAEBEiQKC2Zhc3Rfc2Nyb2xsGAggASgISAdSCmZhc3RTY3JvbGyIAQFCDQ'
    'oLX3Njcm9sbGJhcnNCDwoNX3Njcm9sbF90cmFja0IOCgxfc2Nyb2xsX3RpcHNCEAoOX2ZsaW5n'
    'X2VuYWJsZWRCFQoTX2ZsaW5nX2ltcHVsc2VfZ2FpbkIRCg9fZmxpbmdfZnJpY3Rpb25CFQoTX3'
    'BpbmNoX3pvb21fZW5hYmxlZEIOCgxfZmFzdF9zY3JvbGw=');

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
      '5': 5,
      '9': 2,
      '10': 'cellSpanCompare',
      '17': true
    },
    {
      '1': 'group_span_compare',
      '3': 4,
      '4': 1,
      '5': 5,
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
    'aWQudjEuQ2VsbFNwYW5Nb2RlSAFSDWNlbGxTcGFuRml4ZWSIAQESLwoRY2VsbF9zcGFuX2NvbX'
    'BhcmUYAyABKAVIAlIPY2VsbFNwYW5Db21wYXJliAEBEjEKEmdyb3VwX3NwYW5fY29tcGFyZRgE'
    'IAEoBUgDUhBncm91cFNwYW5Db21wYXJliAEBQgwKCl9jZWxsX3NwYW5CEgoQX2NlbGxfc3Bhbl'
    '9maXhlZEIUChJfY2VsbF9zcGFuX2NvbXBhcmVCFQoTX2dyb3VwX3NwYW5fY29tcGFyZQ==');

@$core.Deprecated('Use interactionConfigDescriptor instead')
const InteractionConfig$json = {
  '1': 'InteractionConfig',
  '2': [
    {
      '1': 'allow_user_resizing',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.AllowUserResizingMode',
      '9': 0,
      '10': 'allowUserResizing',
      '17': true
    },
    {
      '1': 'allow_user_freezing',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.UserFreezeMode',
      '9': 1,
      '10': 'allowUserFreezing',
      '17': true
    },
    {
      '1': 'type_ahead',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.TypeAheadMode',
      '9': 2,
      '10': 'typeAhead',
      '17': true
    },
    {
      '1': 'type_ahead_delay',
      '3': 4,
      '4': 1,
      '5': 5,
      '9': 3,
      '10': 'typeAheadDelay',
      '17': true
    },
    {
      '1': 'auto_size_mouse',
      '3': 5,
      '4': 1,
      '5': 8,
      '9': 4,
      '10': 'autoSizeMouse',
      '17': true
    },
    {
      '1': 'auto_size_mode',
      '3': 6,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.AutoSizeMode',
      '9': 5,
      '10': 'autoSizeMode',
      '17': true
    },
    {
      '1': 'auto_resize',
      '3': 7,
      '4': 1,
      '5': 8,
      '9': 6,
      '10': 'autoResize',
      '17': true
    },
    {
      '1': 'drag_mode',
      '3': 8,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.DragMode',
      '9': 7,
      '10': 'dragMode',
      '17': true
    },
    {
      '1': 'drop_mode',
      '3': 9,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.DropMode',
      '9': 8,
      '10': 'dropMode',
      '17': true
    },
    {
      '1': 'header_features',
      '3': 10,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.HeaderFeatures',
      '9': 9,
      '10': 'headerFeatures',
      '17': true
    },
  ],
  '8': [
    {'1': '_allow_user_resizing'},
    {'1': '_allow_user_freezing'},
    {'1': '_type_ahead'},
    {'1': '_type_ahead_delay'},
    {'1': '_auto_size_mouse'},
    {'1': '_auto_size_mode'},
    {'1': '_auto_resize'},
    {'1': '_drag_mode'},
    {'1': '_drop_mode'},
    {'1': '_header_features'},
  ],
};

/// Descriptor for `InteractionConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List interactionConfigDescriptor = $convert.base64Decode(
    'ChFJbnRlcmFjdGlvbkNvbmZpZxJZChNhbGxvd191c2VyX3Jlc2l6aW5nGAEgASgOMiQudm9sdm'
    '94Z3JpZC52MS5BbGxvd1VzZXJSZXNpemluZ01vZGVIAFIRYWxsb3dVc2VyUmVzaXppbmeIAQES'
    'UgoTYWxsb3dfdXNlcl9mcmVlemluZxgCIAEoDjIdLnZvbHZveGdyaWQudjEuVXNlckZyZWV6ZU'
    '1vZGVIAVIRYWxsb3dVc2VyRnJlZXppbmeIAQESQAoKdHlwZV9haGVhZBgDIAEoDjIcLnZvbHZv'
    'eGdyaWQudjEuVHlwZUFoZWFkTW9kZUgCUgl0eXBlQWhlYWSIAQESLQoQdHlwZV9haGVhZF9kZW'
    'xheRgEIAEoBUgDUg50eXBlQWhlYWREZWxheYgBARIrCg9hdXRvX3NpemVfbW91c2UYBSABKAhI'
    'BFINYXV0b1NpemVNb3VzZYgBARJGCg5hdXRvX3NpemVfbW9kZRgGIAEoDjIbLnZvbHZveGdyaW'
    'QudjEuQXV0b1NpemVNb2RlSAVSDGF1dG9TaXplTW9kZYgBARIkCgthdXRvX3Jlc2l6ZRgHIAEo'
    'CEgGUgphdXRvUmVzaXpliAEBEjkKCWRyYWdfbW9kZRgIIAEoDjIXLnZvbHZveGdyaWQudjEuRH'
    'JhZ01vZGVIB1IIZHJhZ01vZGWIAQESOQoJZHJvcF9tb2RlGAkgASgOMhcudm9sdm94Z3JpZC52'
    'MS5Ecm9wTW9kZUgIUghkcm9wTW9kZYgBARJLCg9oZWFkZXJfZmVhdHVyZXMYCiABKA4yHS52b2'
    'x2b3hncmlkLnYxLkhlYWRlckZlYXR1cmVzSAlSDmhlYWRlckZlYXR1cmVziAEBQhYKFF9hbGxv'
    'd191c2VyX3Jlc2l6aW5nQhYKFF9hbGxvd191c2VyX2ZyZWV6aW5nQg0KC190eXBlX2FoZWFkQh'
    'MKEV90eXBlX2FoZWFkX2RlbGF5QhIKEF9hdXRvX3NpemVfbW91c2VCEQoPX2F1dG9fc2l6ZV9t'
    'b2RlQg4KDF9hdXRvX3Jlc2l6ZUIMCgpfZHJhZ19tb2RlQgwKCl9kcm9wX21vZGVCEgoQX2hlYW'
    'Rlcl9mZWF0dXJlcw==');

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
  ],
  '8': [
    {'1': '_renderer_mode'},
    {'1': '_debug_overlay'},
    {'1': '_animation_enabled'},
    {'1': '_animation_duration_ms'},
    {'1': '_text_layout_cache_cap'},
    {'1': '_present_mode'},
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
    'ZW50TW9kZUgFUgtwcmVzZW50TW9kZYgBAUIQCg5fcmVuZGVyZXJfbW9kZUIQCg5fZGVidWdfb3'
    'ZlcmxheUIUChJfYW5pbWF0aW9uX2VuYWJsZWRCGAoWX2FuaW1hdGlvbl9kdXJhdGlvbl9tc0IY'
    'ChZfdGV4dF9sYXlvdXRfY2FjaGVfY2FwQg8KDV9wcmVzZW50X21vZGU=');

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
    {
      '1': 'width_px',
      '3': 2,
      '4': 1,
      '5': 5,
      '9': 1,
      '10': 'widthPx',
      '17': true
    },
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
    {'1': '_width_px'},
    {'1': '_visible'},
    {'1': '_custom_key'},
    {'1': '_data'},
  ],
};

/// Descriptor for `RowIndicatorSlot`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List rowIndicatorSlotDescriptor = $convert.base64Decode(
    'ChBSb3dJbmRpY2F0b3JTbG90EjwKBGtpbmQYASABKA4yIy52b2x2b3hncmlkLnYxLlJvd0luZG'
    'ljYXRvclNsb3RLaW5kSABSBGtpbmSIAQESHgoId2lkdGhfcHgYAiABKAVIAVIHd2lkdGhQeIgB'
    'ARIdCgd2aXNpYmxlGAMgASgISAJSB3Zpc2libGWIAQESIgoKY3VzdG9tX2tleRgEIAEoCUgDUg'
    'ljdXN0b21LZXmIAQESFwoEZGF0YRgFIAEoDEgEUgRkYXRhiAEBQgcKBV9raW5kQgsKCV93aWR0'
    'aF9weEIKCghfdmlzaWJsZUINCgtfY3VzdG9tX2tleUIHCgVfZGF0YQ==');

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
    {
      '1': 'width_px',
      '3': 2,
      '4': 1,
      '5': 5,
      '9': 1,
      '10': 'widthPx',
      '17': true
    },
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
      '1': 'back_color',
      '3': 4,
      '4': 1,
      '5': 13,
      '9': 3,
      '10': 'backColor',
      '17': true
    },
    {
      '1': 'fore_color',
      '3': 5,
      '4': 1,
      '5': 13,
      '9': 4,
      '10': 'foreColor',
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
    {'1': '_width_px'},
    {'1': '_mode_bits'},
    {'1': '_back_color'},
    {'1': '_fore_color'},
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
    'ChJSb3dJbmRpY2F0b3JDb25maWcSHQoHdmlzaWJsZRgBIAEoCEgAUgd2aXNpYmxliAEBEh4KCH'
    'dpZHRoX3B4GAIgASgFSAFSB3dpZHRoUHiIAQESIAoJbW9kZV9iaXRzGAMgASgNSAJSCG1vZGVC'
    'aXRziAEBEiIKCmJhY2tfY29sb3IYBCABKA1IA1IJYmFja0NvbG9yiAEBEiIKCmZvcmVfY29sb3'
    'IYBSABKA1IBFIJZm9yZUNvbG9yiAEBEkAKCmdyaWRfbGluZXMYBiABKA4yHC52b2x2b3hncmlk'
    'LnYxLkdyaWRMaW5lU3R5bGVIBVIJZ3JpZExpbmVziAEBEiIKCmdyaWRfY29sb3IYByABKA1IBl'
    'IJZ3JpZENvbG9yiAEBEiAKCWF1dG9fc2l6ZRgIIAEoCEgHUghhdXRvU2l6ZYgBARImCgxhbGxv'
    'd19yZXNpemUYCSABKAhICFILYWxsb3dSZXNpemWIAQESJgoMYWxsb3dfc2VsZWN0GAogASgISA'
    'lSC2FsbG93U2VsZWN0iAEBEigKDWFsbG93X3Jlb3JkZXIYCyABKAhIClIMYWxsb3dSZW9yZGVy'
    'iAEBEjUKBXNsb3RzGAwgAygLMh8udm9sdm94Z3JpZC52MS5Sb3dJbmRpY2F0b3JTbG90UgVzbG'
    '90c0IKCghfdmlzaWJsZUILCglfd2lkdGhfcHhCDAoKX21vZGVfYml0c0INCgtfYmFja19jb2xv'
    'ckINCgtfZm9yZV9jb2xvckINCgtfZ3JpZF9saW5lc0INCgtfZ3JpZF9jb2xvckIMCgpfYXV0b1'
    '9zaXplQg8KDV9hbGxvd19yZXNpemVCDwoNX2FsbG93X3NlbGVjdEIQCg5fYWxsb3dfcmVvcmRl'
    'cg==');

@$core.Deprecated('Use colIndicatorRowDefDescriptor instead')
const ColIndicatorRowDef$json = {
  '1': 'ColIndicatorRowDef',
  '2': [
    {'1': 'index', '3': 1, '4': 1, '5': 5, '9': 0, '10': 'index', '17': true},
    {
      '1': 'height_px',
      '3': 2,
      '4': 1,
      '5': 5,
      '9': 1,
      '10': 'heightPx',
      '17': true
    },
  ],
  '8': [
    {'1': '_index'},
    {'1': '_height_px'},
  ],
};

/// Descriptor for `ColIndicatorRowDef`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List colIndicatorRowDefDescriptor = $convert.base64Decode(
    'ChJDb2xJbmRpY2F0b3JSb3dEZWYSGQoFaW5kZXgYASABKAVIAFIFaW5kZXiIAQESIAoJaGVpZ2'
    'h0X3B4GAIgASgFSAFSCGhlaWdodFB4iAEBQggKBl9pbmRleEIMCgpfaGVpZ2h0X3B4');

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
      '1': 'default_row_height_px',
      '3': 2,
      '4': 1,
      '5': 5,
      '9': 1,
      '10': 'defaultRowHeightPx',
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
      '1': 'back_color',
      '3': 5,
      '4': 1,
      '5': 13,
      '9': 4,
      '10': 'backColor',
      '17': true
    },
    {
      '1': 'fore_color',
      '3': 6,
      '4': 1,
      '5': 13,
      '9': 5,
      '10': 'foreColor',
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
    {'1': '_default_row_height_px'},
    {'1': '_band_rows'},
    {'1': '_mode_bits'},
    {'1': '_back_color'},
    {'1': '_fore_color'},
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
    'ChJDb2xJbmRpY2F0b3JDb25maWcSHQoHdmlzaWJsZRgBIAEoCEgAUgd2aXNpYmxliAEBEjYKFW'
    'RlZmF1bHRfcm93X2hlaWdodF9weBgCIAEoBUgBUhJkZWZhdWx0Um93SGVpZ2h0UHiIAQESIAoJ'
    'YmFuZF9yb3dzGAMgASgFSAJSCGJhbmRSb3dziAEBEiAKCW1vZGVfYml0cxgEIAEoDUgDUghtb2'
    'RlQml0c4gBARIiCgpiYWNrX2NvbG9yGAUgASgNSARSCWJhY2tDb2xvcogBARIiCgpmb3JlX2Nv'
    'bG9yGAYgASgNSAVSCWZvcmVDb2xvcogBARJACgpncmlkX2xpbmVzGAcgASgOMhwudm9sdm94Z3'
    'JpZC52MS5HcmlkTGluZVN0eWxlSAZSCWdyaWRMaW5lc4gBARIiCgpncmlkX2NvbG9yGAggASgN'
    'SAdSCWdyaWRDb2xvcogBARIgCglhdXRvX3NpemUYCSABKAhICFIIYXV0b1NpemWIAQESJgoMYW'
    'xsb3dfcmVzaXplGAogASgISAlSC2FsbG93UmVzaXpliAEBEigKDWFsbG93X3Jlb3JkZXIYCyAB'
    'KAhIClIMYWxsb3dSZW9yZGVyiAEBEiIKCmFsbG93X21lbnUYDCABKAhIC1IJYWxsb3dNZW51iA'
    'EBEjwKCHJvd19kZWZzGA0gAygLMiEudm9sdm94Z3JpZC52MS5Db2xJbmRpY2F0b3JSb3dEZWZS'
    'B3Jvd0RlZnMSNQoFY2VsbHMYDiADKAsyHy52b2x2b3hncmlkLnYxLkNvbEluZGljYXRvckNlbG'
    'xSBWNlbGxzQgoKCF92aXNpYmxlQhgKFl9kZWZhdWx0X3Jvd19oZWlnaHRfcHhCDAoKX2JhbmRf'
    'cm93c0IMCgpfbW9kZV9iaXRzQg0KC19iYWNrX2NvbG9yQg0KC19mb3JlX2NvbG9yQg0KC19ncm'
    'lkX2xpbmVzQg0KC19ncmlkX2NvbG9yQgwKCl9hdXRvX3NpemVCDwoNX2FsbG93X3Jlc2l6ZUIQ'
    'Cg5fYWxsb3dfcmVvcmRlckINCgtfYWxsb3dfbWVudQ==');

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
      '1': 'back_color',
      '3': 3,
      '4': 1,
      '5': 13,
      '9': 2,
      '10': 'backColor',
      '17': true
    },
    {
      '1': 'fore_color',
      '3': 4,
      '4': 1,
      '5': 13,
      '9': 3,
      '10': 'foreColor',
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
    {'1': '_back_color'},
    {'1': '_fore_color'},
    {'1': '_custom_key'},
    {'1': '_data'},
  ],
};

/// Descriptor for `CornerIndicatorConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cornerIndicatorConfigDescriptor = $convert.base64Decode(
    'ChVDb3JuZXJJbmRpY2F0b3JDb25maWcSHQoHdmlzaWJsZRgBIAEoCEgAUgd2aXNpYmxliAEBEi'
    'AKCW1vZGVfYml0cxgCIAEoDUgBUghtb2RlQml0c4gBARIiCgpiYWNrX2NvbG9yGAMgASgNSAJS'
    'CWJhY2tDb2xvcogBARIiCgpmb3JlX2NvbG9yGAQgASgNSANSCWZvcmVDb2xvcogBARIiCgpjdX'
    'N0b21fa2V5GAUgASgJSARSCWN1c3RvbUtleYgBARIXCgRkYXRhGAYgASgMSAVSBGRhdGGIAQFC'
    'CgoIX3Zpc2libGVCDAoKX21vZGVfYml0c0INCgtfYmFja19jb2xvckINCgtfZm9yZV9jb2xvck'
    'INCgtfY3VzdG9tX2tleUIHCgVfZGF0YQ==');

@$core.Deprecated('Use indicatorBandsConfigDescriptor instead')
const IndicatorBandsConfig$json = {
  '1': 'IndicatorBandsConfig',
  '2': [
    {
      '1': 'row_indicator_start',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.RowIndicatorConfig',
      '10': 'rowIndicatorStart'
    },
    {
      '1': 'row_indicator_end',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.RowIndicatorConfig',
      '10': 'rowIndicatorEnd'
    },
    {
      '1': 'col_indicator_top',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.ColIndicatorConfig',
      '10': 'colIndicatorTop'
    },
    {
      '1': 'col_indicator_bottom',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.ColIndicatorConfig',
      '10': 'colIndicatorBottom'
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

/// Descriptor for `IndicatorBandsConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List indicatorBandsConfigDescriptor = $convert.base64Decode(
    'ChRJbmRpY2F0b3JCYW5kc0NvbmZpZxJRChNyb3dfaW5kaWNhdG9yX3N0YXJ0GAEgASgLMiEudm'
    '9sdm94Z3JpZC52MS5Sb3dJbmRpY2F0b3JDb25maWdSEXJvd0luZGljYXRvclN0YXJ0Ek0KEXJv'
    'd19pbmRpY2F0b3JfZW5kGAIgASgLMiEudm9sdm94Z3JpZC52MS5Sb3dJbmRpY2F0b3JDb25maW'
    'dSD3Jvd0luZGljYXRvckVuZBJNChFjb2xfaW5kaWNhdG9yX3RvcBgDIAEoCzIhLnZvbHZveGdy'
    'aWQudjEuQ29sSW5kaWNhdG9yQ29uZmlnUg9jb2xJbmRpY2F0b3JUb3ASUwoUY29sX2luZGljYX'
    'Rvcl9ib3R0b20YBCABKAsyIS52b2x2b3hncmlkLnYxLkNvbEluZGljYXRvckNvbmZpZ1ISY29s'
    'SW5kaWNhdG9yQm90dG9tEk4KEGNvcm5lcl90b3Bfc3RhcnQYBSABKAsyJC52b2x2b3hncmlkLn'
    'YxLkNvcm5lckluZGljYXRvckNvbmZpZ1IOY29ybmVyVG9wU3RhcnQSSgoOY29ybmVyX3RvcF9l'
    'bmQYBiABKAsyJC52b2x2b3hncmlkLnYxLkNvcm5lckluZGljYXRvckNvbmZpZ1IMY29ybmVyVG'
    '9wRW5kElQKE2Nvcm5lcl9ib3R0b21fc3RhcnQYByABKAsyJC52b2x2b3hncmlkLnYxLkNvcm5l'
    'ckluZGljYXRvckNvbmZpZ1IRY29ybmVyQm90dG9tU3RhcnQSUAoRY29ybmVyX2JvdHRvbV9lbm'
    'QYCCABKAsyJC52b2x2b3hncmlkLnYxLkNvcm5lckluZGljYXRvckNvbmZpZ1IPY29ybmVyQm90'
    'dG9tRW5k');

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
      '1': 'alignment',
      '3': 6,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.Align',
      '9': 4,
      '10': 'alignment',
      '17': true
    },
    {
      '1': 'fixed_alignment',
      '3': 7,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.Align',
      '9': 5,
      '10': 'fixedAlignment',
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
      '1': 'sort',
      '3': 11,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.SortOrder',
      '9': 9,
      '10': 'sort',
      '17': true
    },
    {
      '1': 'dropdown_items',
      '3': 12,
      '4': 1,
      '5': 9,
      '9': 10,
      '10': 'dropdownItems',
      '17': true
    },
    {
      '1': 'edit_mask',
      '3': 13,
      '4': 1,
      '5': 9,
      '9': 11,
      '10': 'editMask',
      '17': true
    },
    {
      '1': 'indent',
      '3': 14,
      '4': 1,
      '5': 5,
      '9': 12,
      '10': 'indent',
      '17': true
    },
    {
      '1': 'hidden',
      '3': 15,
      '4': 1,
      '5': 8,
      '9': 13,
      '10': 'hidden',
      '17': true
    },
    {'1': 'span', '3': 16, '4': 1, '5': 8, '9': 14, '10': 'span', '17': true},
    {
      '1': 'image_list',
      '3': 17,
      '4': 3,
      '5': 11,
      '6': '.volvoxgrid.v1.ImageData',
      '10': 'imageList'
    },
    {'1': 'data', '3': 18, '4': 1, '5': 12, '9': 15, '10': 'data', '17': true},
    {
      '1': 'sticky',
      '3': 19,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.StickyEdge',
      '9': 16,
      '10': 'sticky',
      '17': true
    },
    {
      '1': 'cell_padding',
      '3': 20,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.CellPadding',
      '10': 'cellPadding'
    },
    {
      '1': 'fixed_cell_padding',
      '3': 21,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.CellPadding',
      '10': 'fixedCellPadding'
    },
    {
      '1': 'nullable',
      '3': 22,
      '4': 1,
      '5': 8,
      '9': 17,
      '10': 'nullable',
      '17': true
    },
    {
      '1': 'coercion_mode',
      '3': 23,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.CoercionMode',
      '9': 18,
      '10': 'coercionMode',
      '17': true
    },
    {
      '1': 'error_mode',
      '3': 24,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.WriteErrorMode',
      '9': 19,
      '10': 'errorMode',
      '17': true
    },
  ],
  '8': [
    {'1': '_width'},
    {'1': '_min_width'},
    {'1': '_max_width'},
    {'1': '_caption'},
    {'1': '_alignment'},
    {'1': '_fixed_alignment'},
    {'1': '_data_type'},
    {'1': '_format'},
    {'1': '_key'},
    {'1': '_sort'},
    {'1': '_dropdown_items'},
    {'1': '_edit_mask'},
    {'1': '_indent'},
    {'1': '_hidden'},
    {'1': '_span'},
    {'1': '_data'},
    {'1': '_sticky'},
    {'1': '_nullable'},
    {'1': '_coercion_mode'},
    {'1': '_error_mode'},
  ],
};

/// Descriptor for `ColumnDef`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List columnDefDescriptor = $convert.base64Decode(
    'CglDb2x1bW5EZWYSFAoFaW5kZXgYASABKAVSBWluZGV4EhkKBXdpZHRoGAIgASgFSABSBXdpZH'
    'RoiAEBEiAKCW1pbl93aWR0aBgDIAEoBUgBUghtaW5XaWR0aIgBARIgCgltYXhfd2lkdGgYBCAB'
    'KAVIAlIIbWF4V2lkdGiIAQESHQoHY2FwdGlvbhgFIAEoCUgDUgdjYXB0aW9uiAEBEjcKCWFsaW'
    'dubWVudBgGIAEoDjIULnZvbHZveGdyaWQudjEuQWxpZ25IBFIJYWxpZ25tZW50iAEBEkIKD2Zp'
    'eGVkX2FsaWdubWVudBgHIAEoDjIULnZvbHZveGdyaWQudjEuQWxpZ25IBVIOZml4ZWRBbGlnbm'
    '1lbnSIAQESPwoJZGF0YV90eXBlGAggASgOMh0udm9sdm94Z3JpZC52MS5Db2x1bW5EYXRhVHlw'
    'ZUgGUghkYXRhVHlwZYgBARIbCgZmb3JtYXQYCSABKAlIB1IGZm9ybWF0iAEBEhUKA2tleRgKIA'
    'EoCUgIUgNrZXmIAQESMQoEc29ydBgLIAEoDjIYLnZvbHZveGdyaWQudjEuU29ydE9yZGVySAlS'
    'BHNvcnSIAQESKgoOZHJvcGRvd25faXRlbXMYDCABKAlIClINZHJvcGRvd25JdGVtc4gBARIgCg'
    'llZGl0X21hc2sYDSABKAlIC1IIZWRpdE1hc2uIAQESGwoGaW5kZW50GA4gASgFSAxSBmluZGVu'
    'dIgBARIbCgZoaWRkZW4YDyABKAhIDVIGaGlkZGVuiAEBEhcKBHNwYW4YECABKAhIDlIEc3Bhbo'
    'gBARI3CgppbWFnZV9saXN0GBEgAygLMhgudm9sdm94Z3JpZC52MS5JbWFnZURhdGFSCWltYWdl'
    'TGlzdBIXCgRkYXRhGBIgASgMSA9SBGRhdGGIAQESNgoGc3RpY2t5GBMgASgOMhkudm9sdm94Z3'
    'JpZC52MS5TdGlja3lFZGdlSBBSBnN0aWNreYgBARI9CgxjZWxsX3BhZGRpbmcYFCABKAsyGi52'
    'b2x2b3hncmlkLnYxLkNlbGxQYWRkaW5nUgtjZWxsUGFkZGluZxJIChJmaXhlZF9jZWxsX3BhZG'
    'RpbmcYFSABKAsyGi52b2x2b3hncmlkLnYxLkNlbGxQYWRkaW5nUhBmaXhlZENlbGxQYWRkaW5n'
    'Eh8KCG51bGxhYmxlGBYgASgISBFSCG51bGxhYmxliAEBEkUKDWNvZXJjaW9uX21vZGUYFyABKA'
    '4yGy52b2x2b3hncmlkLnYxLkNvZXJjaW9uTW9kZUgSUgxjb2VyY2lvbk1vZGWIAQESQQoKZXJy'
    'b3JfbW9kZRgYIAEoDjIdLnZvbHZveGdyaWQudjEuV3JpdGVFcnJvck1vZGVIE1IJZXJyb3JNb2'
    'RliAEBQggKBl93aWR0aEIMCgpfbWluX3dpZHRoQgwKCl9tYXhfd2lkdGhCCgoIX2NhcHRpb25C'
    'DAoKX2FsaWdubWVudEISChBfZml4ZWRfYWxpZ25tZW50QgwKCl9kYXRhX3R5cGVCCQoHX2Zvcm'
    '1hdEIGCgRfa2V5QgcKBV9zb3J0QhEKD19kcm9wZG93bl9pdGVtc0IMCgpfZWRpdF9tYXNrQgkK'
    'B19pbmRlbnRCCQoHX2hpZGRlbkIHCgVfc3BhbkIHCgVfZGF0YUIJCgdfc3RpY2t5QgsKCV9udW'
    'xsYWJsZUIQCg5fY29lcmNpb25fbW9kZUINCgtfZXJyb3JfbW9kZQ==');

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
    {'1': 'status', '3': 8, '4': 1, '5': 5, '9': 6, '10': 'status', '17': true},
    {'1': 'span', '3': 9, '4': 1, '5': 8, '9': 7, '10': 'span', '17': true},
    {
      '1': 'pin',
      '3': 10,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.PinPosition',
      '9': 8,
      '10': 'pin',
      '17': true
    },
    {
      '1': 'sticky',
      '3': 11,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.StickyEdge',
      '9': 9,
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
    {'1': '_status'},
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
    'SAVSBGRhdGGIAQESGwoGc3RhdHVzGAggASgFSAZSBnN0YXR1c4gBARIXCgRzcGFuGAkgASgISA'
    'dSBHNwYW6IAQESMQoDcGluGAogASgOMhoudm9sdm94Z3JpZC52MS5QaW5Qb3NpdGlvbkgIUgNw'
    'aW6IAQESNgoGc3RpY2t5GAsgASgOMhkudm9sdm94Z3JpZC52MS5TdGlja3lFZGdlSAlSBnN0aW'
    'NreYgBAUIJCgdfaGVpZ2h0QgkKB19oaWRkZW5CDgoMX2lzX3N1YnRvdGFsQhAKDl9vdXRsaW5l'
    'X2xldmVsQg8KDV9pc19jb2xsYXBzZWRCBwoFX2RhdGFCCQoHX3N0YXR1c0IHCgVfc3BhbkIGCg'
    'RfcGluQgkKB19zdGlja3k=');

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

@$core.Deprecated('Use cellStyleOverrideDescriptor instead')
const CellStyleOverride$json = {
  '1': 'CellStyleOverride',
  '2': [
    {
      '1': 'back_color',
      '3': 1,
      '4': 1,
      '5': 13,
      '9': 0,
      '10': 'backColor',
      '17': true
    },
    {
      '1': 'fore_color',
      '3': 2,
      '4': 1,
      '5': 13,
      '9': 1,
      '10': 'foreColor',
      '17': true
    },
    {
      '1': 'alignment',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.Align',
      '9': 2,
      '10': 'alignment',
      '17': true
    },
    {
      '1': 'text_effect',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.TextEffect',
      '9': 3,
      '10': 'textEffect',
      '17': true
    },
    {
      '1': 'font_name',
      '3': 5,
      '4': 1,
      '5': 9,
      '9': 4,
      '10': 'fontName',
      '17': true
    },
    {
      '1': 'font_size',
      '3': 6,
      '4': 1,
      '5': 2,
      '9': 5,
      '10': 'fontSize',
      '17': true
    },
    {
      '1': 'font_bold',
      '3': 7,
      '4': 1,
      '5': 8,
      '9': 6,
      '10': 'fontBold',
      '17': true
    },
    {
      '1': 'font_italic',
      '3': 8,
      '4': 1,
      '5': 8,
      '9': 7,
      '10': 'fontItalic',
      '17': true
    },
    {
      '1': 'font_underline',
      '3': 9,
      '4': 1,
      '5': 8,
      '9': 8,
      '10': 'fontUnderline',
      '17': true
    },
    {
      '1': 'font_strikethrough',
      '3': 10,
      '4': 1,
      '5': 8,
      '9': 9,
      '10': 'fontStrikethrough',
      '17': true
    },
    {
      '1': 'font_width',
      '3': 11,
      '4': 1,
      '5': 2,
      '9': 10,
      '10': 'fontWidth',
      '17': true
    },
    {
      '1': 'progress_color',
      '3': 12,
      '4': 1,
      '5': 13,
      '9': 11,
      '10': 'progressColor',
      '17': true
    },
    {
      '1': 'progress_percent',
      '3': 13,
      '4': 1,
      '5': 2,
      '9': 12,
      '10': 'progressPercent',
      '17': true
    },
    {
      '1': 'border',
      '3': 14,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.BorderStyle',
      '9': 13,
      '10': 'border',
      '17': true
    },
    {
      '1': 'border_color',
      '3': 15,
      '4': 1,
      '5': 13,
      '9': 14,
      '10': 'borderColor',
      '17': true
    },
    {
      '1': 'padding',
      '3': 16,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.CellPadding',
      '10': 'padding'
    },
    {
      '1': 'border_top',
      '3': 17,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.BorderStyle',
      '9': 15,
      '10': 'borderTop',
      '17': true
    },
    {
      '1': 'border_right',
      '3': 18,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.BorderStyle',
      '9': 16,
      '10': 'borderRight',
      '17': true
    },
    {
      '1': 'border_bottom',
      '3': 19,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.BorderStyle',
      '9': 17,
      '10': 'borderBottom',
      '17': true
    },
    {
      '1': 'border_left',
      '3': 20,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.BorderStyle',
      '9': 18,
      '10': 'borderLeft',
      '17': true
    },
    {
      '1': 'border_top_color',
      '3': 21,
      '4': 1,
      '5': 13,
      '9': 19,
      '10': 'borderTopColor',
      '17': true
    },
    {
      '1': 'border_right_color',
      '3': 22,
      '4': 1,
      '5': 13,
      '9': 20,
      '10': 'borderRightColor',
      '17': true
    },
    {
      '1': 'border_bottom_color',
      '3': 23,
      '4': 1,
      '5': 13,
      '9': 21,
      '10': 'borderBottomColor',
      '17': true
    },
    {
      '1': 'border_left_color',
      '3': 24,
      '4': 1,
      '5': 13,
      '9': 22,
      '10': 'borderLeftColor',
      '17': true
    },
    {
      '1': 'shrink_to_fit',
      '3': 25,
      '4': 1,
      '5': 8,
      '9': 23,
      '10': 'shrinkToFit',
      '17': true
    },
  ],
  '8': [
    {'1': '_back_color'},
    {'1': '_fore_color'},
    {'1': '_alignment'},
    {'1': '_text_effect'},
    {'1': '_font_name'},
    {'1': '_font_size'},
    {'1': '_font_bold'},
    {'1': '_font_italic'},
    {'1': '_font_underline'},
    {'1': '_font_strikethrough'},
    {'1': '_font_width'},
    {'1': '_progress_color'},
    {'1': '_progress_percent'},
    {'1': '_border'},
    {'1': '_border_color'},
    {'1': '_border_top'},
    {'1': '_border_right'},
    {'1': '_border_bottom'},
    {'1': '_border_left'},
    {'1': '_border_top_color'},
    {'1': '_border_right_color'},
    {'1': '_border_bottom_color'},
    {'1': '_border_left_color'},
    {'1': '_shrink_to_fit'},
  ],
};

/// Descriptor for `CellStyleOverride`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cellStyleOverrideDescriptor = $convert.base64Decode(
    'ChFDZWxsU3R5bGVPdmVycmlkZRIiCgpiYWNrX2NvbG9yGAEgASgNSABSCWJhY2tDb2xvcogBAR'
    'IiCgpmb3JlX2NvbG9yGAIgASgNSAFSCWZvcmVDb2xvcogBARI3CglhbGlnbm1lbnQYAyABKA4y'
    'FC52b2x2b3hncmlkLnYxLkFsaWduSAJSCWFsaWdubWVudIgBARI/Cgt0ZXh0X2VmZmVjdBgEIA'
    'EoDjIZLnZvbHZveGdyaWQudjEuVGV4dEVmZmVjdEgDUgp0ZXh0RWZmZWN0iAEBEiAKCWZvbnRf'
    'bmFtZRgFIAEoCUgEUghmb250TmFtZYgBARIgCglmb250X3NpemUYBiABKAJIBVIIZm9udFNpem'
    'WIAQESIAoJZm9udF9ib2xkGAcgASgISAZSCGZvbnRCb2xkiAEBEiQKC2ZvbnRfaXRhbGljGAgg'
    'ASgISAdSCmZvbnRJdGFsaWOIAQESKgoOZm9udF91bmRlcmxpbmUYCSABKAhICFINZm9udFVuZG'
    'VybGluZYgBARIyChJmb250X3N0cmlrZXRocm91Z2gYCiABKAhICVIRZm9udFN0cmlrZXRocm91'
    'Z2iIAQESIgoKZm9udF93aWR0aBgLIAEoAkgKUglmb250V2lkdGiIAQESKgoOcHJvZ3Jlc3NfY2'
    '9sb3IYDCABKA1IC1INcHJvZ3Jlc3NDb2xvcogBARIuChBwcm9ncmVzc19wZXJjZW50GA0gASgC'
    'SAxSD3Byb2dyZXNzUGVyY2VudIgBARI3CgZib3JkZXIYDiABKA4yGi52b2x2b3hncmlkLnYxLk'
    'JvcmRlclN0eWxlSA1SBmJvcmRlcogBARImCgxib3JkZXJfY29sb3IYDyABKA1IDlILYm9yZGVy'
    'Q29sb3KIAQESNAoHcGFkZGluZxgQIAEoCzIaLnZvbHZveGdyaWQudjEuQ2VsbFBhZGRpbmdSB3'
    'BhZGRpbmcSPgoKYm9yZGVyX3RvcBgRIAEoDjIaLnZvbHZveGdyaWQudjEuQm9yZGVyU3R5bGVI'
    'D1IJYm9yZGVyVG9wiAEBEkIKDGJvcmRlcl9yaWdodBgSIAEoDjIaLnZvbHZveGdyaWQudjEuQm'
    '9yZGVyU3R5bGVIEFILYm9yZGVyUmlnaHSIAQESRAoNYm9yZGVyX2JvdHRvbRgTIAEoDjIaLnZv'
    'bHZveGdyaWQudjEuQm9yZGVyU3R5bGVIEVIMYm9yZGVyQm90dG9tiAEBEkAKC2JvcmRlcl9sZW'
    'Z0GBQgASgOMhoudm9sdm94Z3JpZC52MS5Cb3JkZXJTdHlsZUgSUgpib3JkZXJMZWZ0iAEBEi0K'
    'EGJvcmRlcl90b3BfY29sb3IYFSABKA1IE1IOYm9yZGVyVG9wQ29sb3KIAQESMQoSYm9yZGVyX3'
    'JpZ2h0X2NvbG9yGBYgASgNSBRSEGJvcmRlclJpZ2h0Q29sb3KIAQESMwoTYm9yZGVyX2JvdHRv'
    'bV9jb2xvchgXIAEoDUgVUhFib3JkZXJCb3R0b21Db2xvcogBARIvChFib3JkZXJfbGVmdF9jb2'
    'xvchgYIAEoDUgWUg9ib3JkZXJMZWZ0Q29sb3KIAQESJwoNc2hyaW5rX3RvX2ZpdBgZIAEoCEgX'
    'UgtzaHJpbmtUb0ZpdIgBAUINCgtfYmFja19jb2xvckINCgtfZm9yZV9jb2xvckIMCgpfYWxpZ2'
    '5tZW50Qg4KDF90ZXh0X2VmZmVjdEIMCgpfZm9udF9uYW1lQgwKCl9mb250X3NpemVCDAoKX2Zv'
    'bnRfYm9sZEIOCgxfZm9udF9pdGFsaWNCEQoPX2ZvbnRfdW5kZXJsaW5lQhUKE19mb250X3N0cm'
    'lrZXRocm91Z2hCDQoLX2ZvbnRfd2lkdGhCEQoPX3Byb2dyZXNzX2NvbG9yQhMKEV9wcm9ncmVz'
    'c19wZXJjZW50QgkKB19ib3JkZXJCDwoNX2JvcmRlcl9jb2xvckINCgtfYm9yZGVyX3RvcEIPCg'
    '1fYm9yZGVyX3JpZ2h0QhAKDl9ib3JkZXJfYm90dG9tQg4KDF9ib3JkZXJfbGVmdEITChFfYm9y'
    'ZGVyX3RvcF9jb2xvckIVChNfYm9yZGVyX3JpZ2h0X2NvbG9yQhYKFF9ib3JkZXJfYm90dG9tX2'
    'NvbG9yQhQKEl9ib3JkZXJfbGVmdF9jb2xvckIQCg5fc2hyaW5rX3RvX2ZpdA==');

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
      '6': '.volvoxgrid.v1.CellStyleOverride',
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
      '1': 'picture_alignment',
      '3': 7,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.ImageAlignment',
      '9': 1,
      '10': 'pictureAlignment',
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
      '1': 'dropdown_items',
      '3': 9,
      '4': 1,
      '5': 9,
      '9': 2,
      '10': 'dropdownItems',
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
  ],
  '8': [
    {'1': '_checked'},
    {'1': '_picture_alignment'},
    {'1': '_dropdown_items'},
    {'1': '_sticky_row'},
    {'1': '_sticky_col'},
  ],
};

/// Descriptor for `CellUpdate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cellUpdateDescriptor = $convert.base64Decode(
    'CgpDZWxsVXBkYXRlEhAKA3JvdxgBIAEoBVIDcm93EhAKA2NvbBgCIAEoBVIDY29sEi4KBXZhbH'
    'VlGAMgASgLMhgudm9sdm94Z3JpZC52MS5DZWxsVmFsdWVSBXZhbHVlEjYKBXN0eWxlGAQgASgL'
    'MiAudm9sdm94Z3JpZC52MS5DZWxsU3R5bGVPdmVycmlkZVIFc3R5bGUSOgoHY2hlY2tlZBgFIA'
    'EoDjIbLnZvbHZveGdyaWQudjEuQ2hlY2tlZFN0YXRlSABSB2NoZWNrZWSIAQESMgoHcGljdHVy'
    'ZRgGIAEoCzIYLnZvbHZveGdyaWQudjEuSW1hZ2VEYXRhUgdwaWN0dXJlEk8KEXBpY3R1cmVfYW'
    'xpZ25tZW50GAcgASgOMh0udm9sdm94Z3JpZC52MS5JbWFnZUFsaWdubWVudEgBUhBwaWN0dXJl'
    'QWxpZ25tZW50iAEBEj8KDmJ1dHRvbl9waWN0dXJlGAggASgLMhgudm9sdm94Z3JpZC52MS5JbW'
    'FnZURhdGFSDWJ1dHRvblBpY3R1cmUSKgoOZHJvcGRvd25faXRlbXMYCSABKAlIAlINZHJvcGRv'
    'd25JdGVtc4gBARI9CgpzdGlja3lfcm93GAogASgOMhkudm9sdm94Z3JpZC52MS5TdGlja3lFZG'
    'dlSANSCXN0aWNreVJvd4gBARI9CgpzdGlja3lfY29sGAsgASgOMhkudm9sdm94Z3JpZC52MS5T'
    'dGlja3lFZGdlSARSCXN0aWNreUNvbIgBAUIKCghfY2hlY2tlZEIUChJfcGljdHVyZV9hbGlnbm'
    '1lbnRCEQoPX2Ryb3Bkb3duX2l0ZW1zQg0KC19zdGlja3lfcm93Qg0KC19zdGlja3lfY29s');

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
  ],
};

/// Descriptor for `GetCellsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getCellsRequestDescriptor = $convert.base64Decode(
    'Cg9HZXRDZWxsc1JlcXVlc3QSFwoHZ3JpZF9pZBgBIAEoA1IGZ3JpZElkEhIKBHJvdzEYAiABKA'
    'VSBHJvdzESEgoEY29sMRgDIAEoBVIEY29sMRISCgRyb3cyGAQgASgFUgRyb3cyEhIKBGNvbDIY'
    'BSABKAVSBGNvbDISIwoNaW5jbHVkZV9zdHlsZRgGIAEoCFIMaW5jbHVkZVN0eWxlEicKD2luY2'
    'x1ZGVfY2hlY2tlZBgHIAEoCFIOaW5jbHVkZUNoZWNrZWQSIwoNaW5jbHVkZV90eXBlZBgIIAEo'
    'CFIMaW5jbHVkZVR5cGVk');

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
      '6': '.volvoxgrid.v1.CellStyleOverride',
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
  ],
};

/// Descriptor for `CellData`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cellDataDescriptor = $convert.base64Decode(
    'CghDZWxsRGF0YRIQCgNyb3cYASABKAVSA3JvdxIQCgNjb2wYAiABKAVSA2NvbBIuCgV2YWx1ZR'
    'gDIAEoCzIYLnZvbHZveGdyaWQudjEuQ2VsbFZhbHVlUgV2YWx1ZRI2CgVzdHlsZRgEIAEoCzIg'
    'LnZvbHZveGdyaWQudjEuQ2VsbFN0eWxlT3ZlcnJpZGVSBXN0eWxlEjUKB2NoZWNrZWQYBSABKA'
    '4yGy52b2x2b3hncmlkLnYxLkNoZWNrZWRTdGF0ZVIHY2hlY2tlZA==');

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
    'aGxpZ2h0c0IJCgdjb21tYW5k');

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
  ],
};

/// Descriptor for `EditState`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List editStateDescriptor = $convert.base64Decode(
    'CglFZGl0U3RhdGUSFgoGYWN0aXZlGAEgASgIUgZhY3RpdmUSEAoDcm93GAIgASgFUgNyb3cSEA'
    'oDY29sGAMgASgFUgNjb2wSEgoEdGV4dBgEIAEoCVIEdGV4dBIbCglzZWxfc3RhcnQYBSABKAVS'
    'CHNlbFN0YXJ0Eh0KCnNlbF9sZW5ndGgYBiABKAVSCXNlbExlbmd0aA==');

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
      '10': 'order'
    },
  ],
};

/// Descriptor for `SortColumn`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sortColumnDescriptor = $convert.base64Decode(
    'CgpTb3J0Q29sdW1uEhAKA2NvbBgBIAEoBVIDY29sEi4KBW9yZGVyGAIgASgOMhgudm9sdm94Z3'
    'JpZC52MS5Tb3J0T3JkZXJSBW9yZGVy');

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
    {'1': 'back_color', '3': 6, '4': 1, '5': 13, '10': 'backColor'},
    {'1': 'fore_color', '3': 7, '4': 1, '5': 13, '10': 'foreColor'},
    {'1': 'add_outline', '3': 8, '4': 1, '5': 8, '10': 'addOutline'},
  ],
};

/// Descriptor for `SubtotalRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List subtotalRequestDescriptor = $convert.base64Decode(
    'Cg9TdWJ0b3RhbFJlcXVlc3QSFwoHZ3JpZF9pZBgBIAEoA1IGZ3JpZElkEjoKCWFnZ3JlZ2F0ZR'
    'gCIAEoDjIcLnZvbHZveGdyaWQudjEuQWdncmVnYXRlVHlwZVIJYWdncmVnYXRlEiAKDGdyb3Vw'
    'X29uX2NvbBgDIAEoBVIKZ3JvdXBPbkNvbBIjCg1hZ2dyZWdhdGVfY29sGAQgASgFUgxhZ2dyZW'
    'dhdGVDb2wSGAoHY2FwdGlvbhgFIAEoCVIHY2FwdGlvbhIdCgpiYWNrX2NvbG9yGAYgASgNUgli'
    'YWNrQ29sb3ISHQoKZm9yZV9jb2xvchgHIAEoDVIJZm9yZUNvbG9yEh8KC2FkZF9vdXRsaW5lGA'
    'ggASgIUgphZGRPdXRsaW5l');

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

@$core.Deprecated('Use importRequestDescriptor instead')
const ImportRequest$json = {
  '1': 'ImportRequest',
  '2': [
    {'1': 'grid_id', '3': 1, '4': 1, '5': 3, '10': 'gridId'},
    {'1': 'data', '3': 2, '4': 1, '5': 12, '10': 'data'},
    {
      '1': 'format',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.ExportFormat',
      '10': 'format'
    },
    {
      '1': 'scope',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.volvoxgrid.v1.ExportScope',
      '10': 'scope'
    },
    {'1': 'url', '3': 5, '4': 1, '5': 9, '9': 0, '10': 'url', '17': true},
  ],
  '8': [
    {'1': '_url'},
  ],
};

/// Descriptor for `ImportRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List importRequestDescriptor = $convert.base64Decode(
    'Cg1JbXBvcnRSZXF1ZXN0EhcKB2dyaWRfaWQYASABKANSBmdyaWRJZBISCgRkYXRhGAIgASgMUg'
    'RkYXRhEjMKBmZvcm1hdBgDIAEoDjIbLnZvbHZveGdyaWQudjEuRXhwb3J0Rm9ybWF0UgZmb3Jt'
    'YXQSMAoFc2NvcGUYBCABKA4yGi52b2x2b3hncmlkLnYxLkV4cG9ydFNjb3BlUgVzY29wZRIVCg'
    'N1cmwYBSABKAlIAFIDdXJsiAEBQgYKBF91cmw=');

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
    {'1': 'SAVE', '2': 0},
    {'1': 'LOAD', '2': 1},
    {'1': 'DELETE', '2': 2},
    {'1': 'LIST', '2': 3},
  ],
};

/// Descriptor for `ArchiveRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List archiveRequestDescriptor = $convert.base64Decode(
    'Cg5BcmNoaXZlUmVxdWVzdBIXCgdncmlkX2lkGAEgASgDUgZncmlkSWQSEgoEbmFtZRgCIAEoCV'
    'IEbmFtZRI8CgZhY3Rpb24YAyABKA4yJC52b2x2b3hncmlkLnYxLkFyY2hpdmVSZXF1ZXN0LkFj'
    'dGlvblIGYWN0aW9uEhIKBGRhdGEYBCABKAxSBGRhdGEiMgoGQWN0aW9uEggKBFNBVkUQABIICg'
    'RMT0FEEAESCgoGREVMRVRFEAISCAoETElTVBAD');

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
    'IAEoCzIeLnZvbHZveGdyaWQudjEuR3B1U3VyZmFjZVJlYWR5SABSCmdwdVN1cmZhY2VCBwoFaW'
    '5wdXQ=');

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
    {'1': 'DOWN', '2': 0},
    {'1': 'UP', '2': 1},
    {'1': 'MOVE', '2': 2},
  ],
};

/// Descriptor for `PointerEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pointerEventDescriptor = $convert.base64Decode(
    'CgxQb2ludGVyRXZlbnQSNAoEdHlwZRgBIAEoDjIgLnZvbHZveGdyaWQudjEuUG9pbnRlckV2ZW'
    '50LlR5cGVSBHR5cGUSDAoBeBgCIAEoAlIBeBIMCgF5GAMgASgCUgF5EhoKCG1vZGlmaWVyGAQg'
    'ASgFUghtb2RpZmllchIWCgZidXR0b24YBSABKAVSBmJ1dHRvbhIbCglkYmxfY2xpY2sYBiABKA'
    'hSCGRibENsaWNrIiIKBFR5cGUSCAoERE9XThAAEgYKAlVQEAESCAoETU9WRRAC');

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
    {'1': 'ZOOM_BEGIN', '2': 0},
    {'1': 'ZOOM_UPDATE', '2': 1},
    {'1': 'ZOOM_END', '2': 2},
  ],
};

/// Descriptor for `ZoomEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List zoomEventDescriptor = $convert.base64Decode(
    'Cglab29tRXZlbnQSNAoFcGhhc2UYASABKA4yHi52b2x2b3hncmlkLnYxLlpvb21FdmVudC5QaG'
    'FzZVIFcGhhc2USFAoFc2NhbGUYAiABKAJSBXNjYWxlEhwKCmZvY2FsX3hfcHgYAyABKAJSCGZv'
    'Y2FsWFB4EhwKCmZvY2FsX3lfcHgYBCABKAJSCGZvY2FsWVB4IjYKBVBoYXNlEg4KClpPT01fQk'
    'VHSU4QABIPCgtaT09NX1VQREFURRABEgwKCFpPT01fRU5EEAI=');

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
    {'1': 'KEY_DOWN', '2': 0},
    {'1': 'KEY_UP', '2': 1},
    {'1': 'KEY_PRESS', '2': 2},
  ],
};

/// Descriptor for `KeyEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List keyEventDescriptor = $convert.base64Decode(
    'CghLZXlFdmVudBIwCgR0eXBlGAEgASgOMhwudm9sdm94Z3JpZC52MS5LZXlFdmVudC5UeXBlUg'
    'R0eXBlEhkKCGtleV9jb2RlGAIgASgFUgdrZXlDb2RlEhoKCG1vZGlmaWVyGAMgASgFUghtb2Rp'
    'ZmllchIcCgljaGFyYWN0ZXIYBCABKAlSCWNoYXJhY3RlciIvCgRUeXBlEgwKCEtFWV9ET1dOEA'
    'ASCgoGS0VZX1VQEAESDQoJS0VZX1BSRVNTEAI=');

@$core.Deprecated('Use bufferReadyDescriptor instead')
const BufferReady$json = {
  '1': 'BufferReady',
  '2': [
    {'1': 'handle', '3': 1, '4': 1, '5': 3, '10': 'handle'},
    {'1': 'stride', '3': 2, '4': 1, '5': 5, '10': 'stride'},
    {'1': 'width', '3': 3, '4': 1, '5': 5, '10': 'width'},
    {'1': 'height', '3': 4, '4': 1, '5': 5, '10': 'height'},
  ],
};

/// Descriptor for `BufferReady`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List bufferReadyDescriptor = $convert.base64Decode(
    'CgtCdWZmZXJSZWFkeRIWCgZoYW5kbGUYASABKANSBmhhbmRsZRIWCgZzdHJpZGUYAiABKAVSBn'
    'N0cmlkZRIUCgV3aWR0aBgDIAEoBVIFd2lkdGgSFgoGaGVpZ2h0GAQgASgFUgZoZWlnaHQ=');

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
  ],
};

/// Descriptor for `FrameDone`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List frameDoneDescriptor = $convert.base64Decode(
    'CglGcmFtZURvbmUSFgoGaGFuZGxlGAEgASgDUgZoYW5kbGUSFwoHZGlydHlfeBgCIAEoBVIGZG'
    'lydHlYEhcKB2RpcnR5X3kYAyABKAVSBmRpcnR5WRIXCgdkaXJ0eV93GAQgASgFUgZkaXJ0eVcS'
    'FwoHZGlydHlfaBgFIAEoBVIGZGlydHlI');

@$core.Deprecated('Use gpuFrameDoneDescriptor instead')
const GpuFrameDone$json = {
  '1': 'GpuFrameDone',
  '2': [
    {'1': 'dirty_x', '3': 1, '4': 1, '5': 5, '10': 'dirtyX'},
    {'1': 'dirty_y', '3': 2, '4': 1, '5': 5, '10': 'dirtyY'},
    {'1': 'dirty_w', '3': 3, '4': 1, '5': 5, '10': 'dirtyW'},
    {'1': 'dirty_h', '3': 4, '4': 1, '5': 5, '10': 'dirtyH'},
  ],
};

/// Descriptor for `GpuFrameDone`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List gpuFrameDoneDescriptor = $convert.base64Decode(
    'CgxHcHVGcmFtZURvbmUSFwoHZGlydHlfeBgBIAEoBVIGZGlydHlYEhcKB2RpcnR5X3kYAiABKA'
    'VSBmRpcnR5WRIXCgdkaXJ0eV93GAMgASgFUgZkaXJ0eVcSFwoHZGlydHlfaBgEIAEoBVIGZGly'
    'dHlI');

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
  ],
};

/// Descriptor for `EditRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List editRequestDescriptor = $convert.base64Decode(
    'CgtFZGl0UmVxdWVzdBIQCgNyb3cYASABKAVSA3JvdxIQCgNjb2wYAiABKAVSA2NvbBIMCgF4GA'
    'MgASgCUgF4EgwKAXkYBCABKAJSAXkSFAoFd2lkdGgYBSABKAJSBXdpZHRoEhYKBmhlaWdodBgG'
    'IAEoAlIGaGVpZ2h0EiMKDWN1cnJlbnRfdmFsdWUYByABKAlSDGN1cnJlbnRWYWx1ZRIbCgllZG'
    'l0X21hc2sYCCABKAlSCGVkaXRNYXNrEh0KCm1heF9sZW5ndGgYCSABKAVSCW1heExlbmd0aA==');

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
      '1': 'cell_button_click',
      '3': 13,
      '4': 1,
      '5': 11,
      '6': '.volvoxgrid.v1.CellButtonClickEvent',
      '9': 0,
      '10': 'cellButtonClick'
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
    'bGxFZGl0Q2hhbmdlElEKEWNlbGxfYnV0dG9uX2NsaWNrGA0gASgLMiMudm9sdm94Z3JpZC52MS'
    '5DZWxsQnV0dG9uQ2xpY2tFdmVudEgAUg9jZWxsQnV0dG9uQ2xpY2sSRQoNa2V5X2Rvd25fZWRp'
    'dBgOIAEoCzIfLnZvbHZveGdyaWQudjEuS2V5RG93bkVkaXRFdmVudEgAUgtrZXlEb3duRWRpdB'
    'JICg5rZXlfcHJlc3NfZWRpdBgPIAEoCzIgLnZvbHZveGdyaWQudjEuS2V5UHJlc3NFZGl0RXZl'
    'bnRIAFIMa2V5UHJlc3NFZGl0Ej8KC2tleV91cF9lZGl0GBAgASgLMh0udm9sdm94Z3JpZC52MS'
    '5LZXlVcEVkaXRFdmVudEgAUglrZXlVcEVkaXQSZwoZY2VsbF9lZGl0X2NvbmZpZ3VyZV9zdHls'
    'ZRgRIAEoCzIqLnZvbHZveGdyaWQudjEuQ2VsbEVkaXRDb25maWd1cmVTdHlsZUV2ZW50SABSFm'
    'NlbGxFZGl0Q29uZmlndXJlU3R5bGUSagoaY2VsbF9lZGl0X2NvbmZpZ3VyZV93aW5kb3cYEiAB'
    'KAsyKy52b2x2b3hncmlkLnYxLkNlbGxFZGl0Q29uZmlndXJlV2luZG93RXZlbnRIAFIXY2VsbE'
    'VkaXRDb25maWd1cmVXaW5kb3cSTQoPZHJvcGRvd25fY2xvc2VkGBMgASgLMiIudm9sdm94Z3Jp'
    'ZC52MS5Ecm9wZG93bkNsb3NlZEV2ZW50SABSDmRyb3Bkb3duQ2xvc2VkEk0KD2Ryb3Bkb3duX2'
    '9wZW5lZBgUIAEoCzIiLnZvbHZveGdyaWQudjEuRHJvcGRvd25PcGVuZWRFdmVudEgAUg5kcm9w'
    'ZG93bk9wZW5lZBJECgxjZWxsX2NoYW5nZWQYFSABKAsyHy52b2x2b3hncmlkLnYxLkNlbGxDaG'
    'FuZ2VkRXZlbnRIAFILY2VsbENoYW5nZWQSUQoRcm93X3N0YXR1c19jaGFuZ2UYFiABKAsyIy52'
    'b2x2b3hncmlkLnYxLlJvd1N0YXR1c0NoYW5nZUV2ZW50SABSD3Jvd1N0YXR1c0NoYW5nZRJBCg'
    'tiZWZvcmVfc29ydBgXIAEoCzIeLnZvbHZveGdyaWQudjEuQmVmb3JlU29ydEV2ZW50SABSCmJl'
    'Zm9yZVNvcnQSPgoKYWZ0ZXJfc29ydBgYIAEoCzIdLnZvbHZveGdyaWQudjEuQWZ0ZXJTb3J0RX'
    'ZlbnRIAFIJYWZ0ZXJTb3J0EjcKB2NvbXBhcmUYGSABKAsyGy52b2x2b3hncmlkLnYxLkNvbXBh'
    'cmVFdmVudEgAUgdjb21wYXJlElQKEmJlZm9yZV9ub2RlX3RvZ2dsZRgaIAEoCzIkLnZvbHZveG'
    'dyaWQudjEuQmVmb3JlTm9kZVRvZ2dsZUV2ZW50SABSEGJlZm9yZU5vZGVUb2dnbGUSUQoRYWZ0'
    'ZXJfbm9kZV90b2dnbGUYGyABKAsyIy52b2x2b3hncmlkLnYxLkFmdGVyTm9kZVRvZ2dsZUV2ZW'
    '50SABSD2FmdGVyTm9kZVRvZ2dsZRJHCg1iZWZvcmVfc2Nyb2xsGBwgASgLMiAudm9sdm94Z3Jp'
    'ZC52MS5CZWZvcmVTY3JvbGxFdmVudEgAUgxiZWZvcmVTY3JvbGwSRAoMYWZ0ZXJfc2Nyb2xsGB'
    '0gASgLMh8udm9sdm94Z3JpZC52MS5BZnRlclNjcm9sbEV2ZW50SABSC2FmdGVyU2Nyb2xsEkoK'
    'DnNjcm9sbF90b29sdGlwGB4gASgLMiEudm9sdm94Z3JpZC52MS5TY3JvbGxUb29sdGlwRXZlbn'
    'RIAFINc2Nyb2xsVG9vbHRpcBJUChJiZWZvcmVfdXNlcl9yZXNpemUYHyABKAsyJC52b2x2b3hn'
    'cmlkLnYxLkJlZm9yZVVzZXJSZXNpemVFdmVudEgAUhBiZWZvcmVVc2VyUmVzaXplElEKEWFmdG'
    'VyX3VzZXJfcmVzaXplGCAgASgLMiMudm9sdm94Z3JpZC52MS5BZnRlclVzZXJSZXNpemVFdmVu'
    'dEgAUg9hZnRlclVzZXJSZXNpemUSUQoRYWZ0ZXJfdXNlcl9mcmVlemUYISABKAsyIy52b2x2b3'
    'hncmlkLnYxLkFmdGVyVXNlckZyZWV6ZUV2ZW50SABSD2FmdGVyVXNlckZyZWV6ZRJUChJiZWZv'
    'cmVfbW92ZV9jb2x1bW4YIiABKAsyJC52b2x2b3hncmlkLnYxLkJlZm9yZU1vdmVDb2x1bW5Fdm'
    'VudEgAUhBiZWZvcmVNb3ZlQ29sdW1uElEKEWFmdGVyX21vdmVfY29sdW1uGCMgASgLMiMudm9s'
    'dm94Z3JpZC52MS5BZnRlck1vdmVDb2x1bW5FdmVudEgAUg9hZnRlck1vdmVDb2x1bW4SSwoPYm'
    'Vmb3JlX21vdmVfcm93GCQgASgLMiEudm9sdm94Z3JpZC52MS5CZWZvcmVNb3ZlUm93RXZlbnRI'
    'AFINYmVmb3JlTW92ZVJvdxJICg5hZnRlcl9tb3ZlX3JvdxglIAEoCzIgLnZvbHZveGdyaWQudj'
    'EuQWZ0ZXJNb3ZlUm93RXZlbnRIAFIMYWZ0ZXJNb3ZlUm93ElEKEWJlZm9yZV9tb3VzZV9kb3du'
    'GCYgASgLMiMudm9sdm94Z3JpZC52MS5CZWZvcmVNb3VzZURvd25FdmVudEgAUg9iZWZvcmVNb3'
    'VzZURvd24SPgoKbW91c2VfZG93bhgnIAEoCzIdLnZvbHZveGdyaWQudjEuTW91c2VEb3duRXZl'
    'bnRIAFIJbW91c2VEb3duEjgKCG1vdXNlX3VwGCggASgLMhsudm9sdm94Z3JpZC52MS5Nb3VzZV'
    'VwRXZlbnRIAFIHbW91c2VVcBI+Cgptb3VzZV9tb3ZlGCkgASgLMh0udm9sdm94Z3JpZC52MS5N'
    'b3VzZU1vdmVFdmVudEgAUgltb3VzZU1vdmUSMQoFY2xpY2sYKiABKAsyGS52b2x2b3hncmlkLn'
    'YxLkNsaWNrRXZlbnRIAFIFY2xpY2sSOwoJZGJsX2NsaWNrGCsgASgLMhwudm9sdm94Z3JpZC52'
    'MS5EYmxDbGlja0V2ZW50SABSCGRibENsaWNrEjgKCGtleV9kb3duGCwgASgLMhsudm9sdm94Z3'
    'JpZC52MS5LZXlEb3duRXZlbnRIAFIHa2V5RG93bhI7CglrZXlfcHJlc3MYLSABKAsyHC52b2x2'
    'b3hncmlkLnYxLktleVByZXNzRXZlbnRIAFIIa2V5UHJlc3MSMgoGa2V5X3VwGC4gASgLMhkudm'
    '9sdm94Z3JpZC52MS5LZXlVcEV2ZW50SABSBWtleVVwElQKEmN1c3RvbV9yZW5kZXJfY2VsbBgv'
    'IAEoCzIkLnZvbHZveGdyaWQudjEuQ3VzdG9tUmVuZGVyQ2VsbEV2ZW50SABSEGN1c3RvbVJlbm'
    'RlckNlbGwSPgoKZHJhZ19zdGFydBgwIAEoCzIdLnZvbHZveGdyaWQudjEuRHJhZ1N0YXJ0RXZl'
    'bnRIAFIJZHJhZ1N0YXJ0EjsKCWRyYWdfb3ZlchgxIAEoCzIcLnZvbHZveGdyaWQudjEuRHJhZ0'
    '92ZXJFdmVudEgAUghkcmFnT3ZlchI7CglkcmFnX2Ryb3AYMiABKAsyHC52b2x2b3hncmlkLnYx'
    'LkRyYWdEcm9wRXZlbnRIAFIIZHJhZ0Ryb3ASRwoNZHJhZ19jb21wbGV0ZRgzIAEoCzIgLnZvbH'
    'ZveGdyaWQudjEuRHJhZ0NvbXBsZXRlRXZlbnRIAFIMZHJhZ0NvbXBsZXRlElQKEnR5cGVfYWhl'
    'YWRfc3RhcnRlZBg0IAEoCzIkLnZvbHZveGdyaWQudjEuVHlwZUFoZWFkU3RhcnRlZEV2ZW50SA'
    'BSEHR5cGVBaGVhZFN0YXJ0ZWQSTgoQdHlwZV9haGVhZF9lbmRlZBg1IAEoCzIiLnZvbHZveGdy'
    'aWQudjEuVHlwZUFoZWFkRW5kZWRFdmVudEgAUg50eXBlQWhlYWRFbmRlZBJNCg9kYXRhX3JlZn'
    'Jlc2hpbmcYNiABKAsyIi52b2x2b3hncmlkLnYxLkRhdGFSZWZyZXNoaW5nRXZlbnRIAFIOZGF0'
    'YVJlZnJlc2hpbmcSSgoOZGF0YV9yZWZyZXNoZWQYNyABKAsyIS52b2x2b3hncmlkLnYxLkRhdG'
    'FSZWZyZXNoZWRFdmVudEgAUg1kYXRhUmVmcmVzaGVkEkEKC2ZpbHRlcl9kYXRhGDggASgLMh4u'
    'dm9sdm94Z3JpZC52MS5GaWx0ZXJEYXRhRXZlbnRIAFIKZmlsdGVyRGF0YRIxCgVlcnJvchg5IA'
    'EoCzIZLnZvbHZveGdyaWQudjEuRXJyb3JFdmVudEgAUgVlcnJvchJRChFiZWZvcmVfcGFnZV9i'
    'cmVhaxg6IAEoCzIjLnZvbHZveGdyaWQudjEuQmVmb3JlUGFnZUJyZWFrRXZlbnRIAFIPYmVmb3'
    'JlUGFnZUJyZWFrEj4KCnN0YXJ0X3BhZ2UYOyABKAsyHS52b2x2b3hncmlkLnYxLlN0YXJ0UGFn'
    'ZUV2ZW50SABSCXN0YXJ0UGFnZRJICg5nZXRfaGVhZGVyX3Jvdxg8IAEoCzIgLnZvbHZveGdyaW'
    'QudjEuR2V0SGVhZGVyUm93RXZlbnRIAFIMZ2V0SGVhZGVyUm93QgcKBWV2ZW50');

@$core.Deprecated('Use cellFocusChangingEventDescriptor instead')
const CellFocusChangingEvent$json = {
  '1': 'CellFocusChangingEvent',
  '2': [
    {'1': 'old_row', '3': 1, '4': 1, '5': 5, '10': 'oldRow'},
    {'1': 'old_col', '3': 2, '4': 1, '5': 5, '10': 'oldCol'},
    {'1': 'new_row', '3': 3, '4': 1, '5': 5, '10': 'newRow'},
    {'1': 'new_col', '3': 4, '4': 1, '5': 5, '10': 'newCol'},
    {'1': 'cancel', '3': 5, '4': 1, '5': 8, '10': 'cancel'},
  ],
};

/// Descriptor for `CellFocusChangingEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cellFocusChangingEventDescriptor = $convert.base64Decode(
    'ChZDZWxsRm9jdXNDaGFuZ2luZ0V2ZW50EhcKB29sZF9yb3cYASABKAVSBm9sZFJvdxIXCgdvbG'
    'RfY29sGAIgASgFUgZvbGRDb2wSFwoHbmV3X3JvdxgDIAEoBVIGbmV3Um93EhcKB25ld19jb2wY'
    'BCABKAVSBm5ld0NvbBIWCgZjYW5jZWwYBSABKAhSBmNhbmNlbA==');

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
    {'1': 'cancel', '3': 5, '4': 1, '5': 8, '10': 'cancel'},
  ],
};

/// Descriptor for `SelectionChangingEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List selectionChangingEventDescriptor = $convert.base64Decode(
    'ChZTZWxlY3Rpb25DaGFuZ2luZ0V2ZW50EjcKCm9sZF9yYW5nZXMYASADKAsyGC52b2x2b3hncm'
    'lkLnYxLkNlbGxSYW5nZVIJb2xkUmFuZ2VzEjcKCm5ld19yYW5nZXMYAiADKAsyGC52b2x2b3hn'
    'cmlkLnYxLkNlbGxSYW5nZVIJbmV3UmFuZ2VzEh0KCmFjdGl2ZV9yb3cYAyABKAVSCWFjdGl2ZV'
    'JvdxIdCgphY3RpdmVfY29sGAQgASgFUglhY3RpdmVDb2wSFgoGY2FuY2VsGAUgASgIUgZjYW5j'
    'ZWw=');

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
    {'1': 'cancel', '3': 3, '4': 1, '5': 8, '10': 'cancel'},
  ],
};

/// Descriptor for `BeforeEditEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List beforeEditEventDescriptor = $convert.base64Decode(
    'Cg9CZWZvcmVFZGl0RXZlbnQSEAoDcm93GAEgASgFUgNyb3cSEAoDY29sGAIgASgFUgNjb2wSFg'
    'oGY2FuY2VsGAMgASgIUgZjYW5jZWw=');

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
    {'1': 'cancel', '3': 4, '4': 1, '5': 8, '10': 'cancel'},
  ],
};

/// Descriptor for `CellEditValidateEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cellEditValidateEventDescriptor = $convert.base64Decode(
    'ChVDZWxsRWRpdFZhbGlkYXRlRXZlbnQSEAoDcm93GAEgASgFUgNyb3cSEAoDY29sGAIgASgFUg'
    'Njb2wSGwoJZWRpdF90ZXh0GAMgASgJUghlZGl0VGV4dBIWCgZjYW5jZWwYBCABKAhSBmNhbmNl'
    'bA==');

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

@$core.Deprecated('Use cellButtonClickEventDescriptor instead')
const CellButtonClickEvent$json = {
  '1': 'CellButtonClickEvent',
  '2': [
    {'1': 'row', '3': 1, '4': 1, '5': 5, '10': 'row'},
    {'1': 'col', '3': 2, '4': 1, '5': 5, '10': 'col'},
  ],
};

/// Descriptor for `CellButtonClickEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cellButtonClickEventDescriptor = $convert.base64Decode(
    'ChRDZWxsQnV0dG9uQ2xpY2tFdmVudBIQCgNyb3cYASABKAVSA3JvdxIQCgNjb2wYAiABKAVSA2'
    'NvbA==');

@$core.Deprecated('Use keyDownEditEventDescriptor instead')
const KeyDownEditEvent$json = {
  '1': 'KeyDownEditEvent',
  '2': [
    {'1': 'key_code', '3': 1, '4': 1, '5': 5, '10': 'keyCode'},
    {'1': 'shift', '3': 2, '4': 1, '5': 5, '10': 'shift'},
  ],
};

/// Descriptor for `KeyDownEditEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List keyDownEditEventDescriptor = $convert.base64Decode(
    'ChBLZXlEb3duRWRpdEV2ZW50EhkKCGtleV9jb2RlGAEgASgFUgdrZXlDb2RlEhQKBXNoaWZ0GA'
    'IgASgFUgVzaGlmdA==');

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
    {'1': 'shift', '3': 2, '4': 1, '5': 5, '10': 'shift'},
  ],
};

/// Descriptor for `KeyUpEditEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List keyUpEditEventDescriptor = $convert.base64Decode(
    'Cg5LZXlVcEVkaXRFdmVudBIZCghrZXlfY29kZRgBIAEoBVIHa2V5Q29kZRIUCgVzaGlmdBgCIA'
    'EoBVIFc2hpZnQ=');

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
    {'1': 'status', '3': 2, '4': 1, '5': 5, '10': 'status'},
  ],
};

/// Descriptor for `RowStatusChangeEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List rowStatusChangeEventDescriptor = $convert.base64Decode(
    'ChRSb3dTdGF0dXNDaGFuZ2VFdmVudBIQCgNyb3cYASABKAVSA3JvdxIWCgZzdGF0dXMYAiABKA'
    'VSBnN0YXR1cw==');

@$core.Deprecated('Use beforeSortEventDescriptor instead')
const BeforeSortEvent$json = {
  '1': 'BeforeSortEvent',
  '2': [
    {'1': 'col', '3': 1, '4': 1, '5': 5, '10': 'col'},
    {'1': 'cancel', '3': 2, '4': 1, '5': 8, '10': 'cancel'},
  ],
};

/// Descriptor for `BeforeSortEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List beforeSortEventDescriptor = $convert.base64Decode(
    'Cg9CZWZvcmVTb3J0RXZlbnQSEAoDY29sGAEgASgFUgNjb2wSFgoGY2FuY2VsGAIgASgIUgZjYW'
    '5jZWw=');

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
    {'1': 'row1', '3': 1, '4': 1, '5': 5, '10': 'row1'},
    {'1': 'row2', '3': 2, '4': 1, '5': 5, '10': 'row2'},
    {'1': 'col', '3': 3, '4': 1, '5': 5, '10': 'col'},
    {'1': 'result', '3': 4, '4': 1, '5': 5, '10': 'result'},
  ],
};

/// Descriptor for `CompareEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List compareEventDescriptor = $convert.base64Decode(
    'CgxDb21wYXJlRXZlbnQSEgoEcm93MRgBIAEoBVIEcm93MRISCgRyb3cyGAIgASgFUgRyb3cyEh'
    'AKA2NvbBgDIAEoBVIDY29sEhYKBnJlc3VsdBgEIAEoBVIGcmVzdWx0');

@$core.Deprecated('Use beforeNodeToggleEventDescriptor instead')
const BeforeNodeToggleEvent$json = {
  '1': 'BeforeNodeToggleEvent',
  '2': [
    {'1': 'row', '3': 1, '4': 1, '5': 5, '10': 'row'},
    {'1': 'collapse', '3': 2, '4': 1, '5': 8, '10': 'collapse'},
    {'1': 'cancel', '3': 3, '4': 1, '5': 8, '10': 'cancel'},
  ],
};

/// Descriptor for `BeforeNodeToggleEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List beforeNodeToggleEventDescriptor = $convert.base64Decode(
    'ChVCZWZvcmVOb2RlVG9nZ2xlRXZlbnQSEAoDcm93GAEgASgFUgNyb3cSGgoIY29sbGFwc2UYAi'
    'ABKAhSCGNvbGxhcHNlEhYKBmNhbmNlbBgDIAEoCFIGY2FuY2Vs');

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
    {'1': 'cancel', '3': 1, '4': 1, '5': 8, '10': 'cancel'},
    {'1': 'old_top_row', '3': 2, '4': 1, '5': 5, '10': 'oldTopRow'},
    {'1': 'old_left_col', '3': 3, '4': 1, '5': 5, '10': 'oldLeftCol'},
    {'1': 'new_top_row', '3': 4, '4': 1, '5': 5, '10': 'newTopRow'},
    {'1': 'new_left_col', '3': 5, '4': 1, '5': 5, '10': 'newLeftCol'},
  ],
};

/// Descriptor for `BeforeScrollEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List beforeScrollEventDescriptor = $convert.base64Decode(
    'ChFCZWZvcmVTY3JvbGxFdmVudBIWCgZjYW5jZWwYASABKAhSBmNhbmNlbBIeCgtvbGRfdG9wX3'
    'JvdxgCIAEoBVIJb2xkVG9wUm93EiAKDG9sZF9sZWZ0X2NvbBgDIAEoBVIKb2xkTGVmdENvbBIe'
    'CgtuZXdfdG9wX3JvdxgEIAEoBVIJbmV3VG9wUm93EiAKDG5ld19sZWZ0X2NvbBgFIAEoBVIKbm'
    'V3TGVmdENvbA==');

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
    {'1': 'cancel', '3': 3, '4': 1, '5': 8, '10': 'cancel'},
  ],
};

/// Descriptor for `BeforeUserResizeEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List beforeUserResizeEventDescriptor = $convert.base64Decode(
    'ChVCZWZvcmVVc2VyUmVzaXplRXZlbnQSEAoDcm93GAEgASgFUgNyb3cSEAoDY29sGAIgASgFUg'
    'Njb2wSFgoGY2FuY2VsGAMgASgIUgZjYW5jZWw=');

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
    {'1': 'cancel', '3': 3, '4': 1, '5': 8, '10': 'cancel'},
  ],
};

/// Descriptor for `BeforeMoveColumnEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List beforeMoveColumnEventDescriptor = $convert.base64Decode(
    'ChVCZWZvcmVNb3ZlQ29sdW1uRXZlbnQSEAoDY29sGAEgASgFUgNjb2wSIQoMbmV3X3Bvc2l0aW'
    '9uGAIgASgFUgtuZXdQb3NpdGlvbhIWCgZjYW5jZWwYAyABKAhSBmNhbmNlbA==');

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
    {'1': 'cancel', '3': 3, '4': 1, '5': 8, '10': 'cancel'},
  ],
};

/// Descriptor for `BeforeMoveRowEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List beforeMoveRowEventDescriptor = $convert.base64Decode(
    'ChJCZWZvcmVNb3ZlUm93RXZlbnQSEAoDcm93GAEgASgFUgNyb3cSIQoMbmV3X3Bvc2l0aW9uGA'
    'IgASgFUgtuZXdQb3NpdGlvbhIWCgZjYW5jZWwYAyABKAhSBmNhbmNlbA==');

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
    {'1': 'cancel', '3': 3, '4': 1, '5': 8, '10': 'cancel'},
  ],
};

/// Descriptor for `BeforeMouseDownEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List beforeMouseDownEventDescriptor = $convert.base64Decode(
    'ChRCZWZvcmVNb3VzZURvd25FdmVudBIQCgNyb3cYASABKAVSA3JvdxIQCgNjb2wYAiABKAVSA2'
    'NvbBIWCgZjYW5jZWwYAyABKAhSBmNhbmNlbA==');

@$core.Deprecated('Use mouseDownEventDescriptor instead')
const MouseDownEvent$json = {
  '1': 'MouseDownEvent',
  '2': [
    {'1': 'button', '3': 1, '4': 1, '5': 5, '10': 'button'},
    {'1': 'shift', '3': 2, '4': 1, '5': 5, '10': 'shift'},
    {'1': 'x', '3': 3, '4': 1, '5': 2, '10': 'x'},
    {'1': 'y', '3': 4, '4': 1, '5': 2, '10': 'y'},
  ],
};

/// Descriptor for `MouseDownEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List mouseDownEventDescriptor = $convert.base64Decode(
    'Cg5Nb3VzZURvd25FdmVudBIWCgZidXR0b24YASABKAVSBmJ1dHRvbhIUCgVzaGlmdBgCIAEoBV'
    'IFc2hpZnQSDAoBeBgDIAEoAlIBeBIMCgF5GAQgASgCUgF5');

@$core.Deprecated('Use mouseUpEventDescriptor instead')
const MouseUpEvent$json = {
  '1': 'MouseUpEvent',
  '2': [
    {'1': 'button', '3': 1, '4': 1, '5': 5, '10': 'button'},
    {'1': 'shift', '3': 2, '4': 1, '5': 5, '10': 'shift'},
    {'1': 'x', '3': 3, '4': 1, '5': 2, '10': 'x'},
    {'1': 'y', '3': 4, '4': 1, '5': 2, '10': 'y'},
  ],
};

/// Descriptor for `MouseUpEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List mouseUpEventDescriptor = $convert.base64Decode(
    'CgxNb3VzZVVwRXZlbnQSFgoGYnV0dG9uGAEgASgFUgZidXR0b24SFAoFc2hpZnQYAiABKAVSBX'
    'NoaWZ0EgwKAXgYAyABKAJSAXgSDAoBeRgEIAEoAlIBeQ==');

@$core.Deprecated('Use mouseMoveEventDescriptor instead')
const MouseMoveEvent$json = {
  '1': 'MouseMoveEvent',
  '2': [
    {'1': 'button', '3': 1, '4': 1, '5': 5, '10': 'button'},
    {'1': 'shift', '3': 2, '4': 1, '5': 5, '10': 'shift'},
    {'1': 'x', '3': 3, '4': 1, '5': 2, '10': 'x'},
    {'1': 'y', '3': 4, '4': 1, '5': 2, '10': 'y'},
  ],
};

/// Descriptor for `MouseMoveEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List mouseMoveEventDescriptor = $convert.base64Decode(
    'Cg5Nb3VzZU1vdmVFdmVudBIWCgZidXR0b24YASABKAVSBmJ1dHRvbhIUCgVzaGlmdBgCIAEoBV'
    'IFc2hpZnQSDAoBeBgDIAEoAlIBeBIMCgF5GAQgASgCUgF5');

@$core.Deprecated('Use clickEventDescriptor instead')
const ClickEvent$json = {
  '1': 'ClickEvent',
};

/// Descriptor for `ClickEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List clickEventDescriptor =
    $convert.base64Decode('CgpDbGlja0V2ZW50');

@$core.Deprecated('Use dblClickEventDescriptor instead')
const DblClickEvent$json = {
  '1': 'DblClickEvent',
};

/// Descriptor for `DblClickEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dblClickEventDescriptor =
    $convert.base64Decode('Cg1EYmxDbGlja0V2ZW50');

@$core.Deprecated('Use keyDownEventDescriptor instead')
const KeyDownEvent$json = {
  '1': 'KeyDownEvent',
  '2': [
    {'1': 'key_code', '3': 1, '4': 1, '5': 5, '10': 'keyCode'},
    {'1': 'shift', '3': 2, '4': 1, '5': 5, '10': 'shift'},
  ],
};

/// Descriptor for `KeyDownEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List keyDownEventDescriptor = $convert.base64Decode(
    'CgxLZXlEb3duRXZlbnQSGQoIa2V5X2NvZGUYASABKAVSB2tleUNvZGUSFAoFc2hpZnQYAiABKA'
    'VSBXNoaWZ0');

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
    {'1': 'shift', '3': 2, '4': 1, '5': 5, '10': 'shift'},
  ],
};

/// Descriptor for `KeyUpEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List keyUpEventDescriptor = $convert.base64Decode(
    'CgpLZXlVcEV2ZW50EhkKCGtleV9jb2RlGAEgASgFUgdrZXlDb2RlEhQKBXNoaWZ0GAIgASgFUg'
    'VzaGlmdA==');

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
      '6': '.volvoxgrid.v1.CellStyleOverride',
      '10': 'style'
    },
    {'1': 'done', '3': 9, '4': 1, '5': 8, '10': 'done'},
  ],
};

/// Descriptor for `CustomRenderCellEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List customRenderCellEventDescriptor = $convert.base64Decode(
    'ChVDdXN0b21SZW5kZXJDZWxsRXZlbnQSEAoDcm93GAEgASgFUgNyb3cSEAoDY29sGAIgASgFUg'
    'Njb2wSDAoBeBgDIAEoAlIBeBIMCgF5GAQgASgCUgF5EhQKBXdpZHRoGAUgASgCUgV3aWR0aBIW'
    'CgZoZWlnaHQYBiABKAJSBmhlaWdodBISCgR0ZXh0GAcgASgJUgR0ZXh0EjYKBXN0eWxlGAggAS'
    'gLMiAudm9sdm94Z3JpZC52MS5DZWxsU3R5bGVPdmVycmlkZVIFc3R5bGUSEgoEZG9uZRgJIAEo'
    'CFIEZG9uZQ==');

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
  '2': [
    {'1': 'cancel', '3': 1, '4': 1, '5': 8, '10': 'cancel'},
  ],
};

/// Descriptor for `DataRefreshingEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dataRefreshingEventDescriptor =
    $convert.base64Decode(
        'ChNEYXRhUmVmcmVzaGluZ0V2ZW50EhYKBmNhbmNlbBgBIAEoCFIGY2FuY2Vs');

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
    {'1': 'cancel', '3': 2, '4': 1, '5': 8, '10': 'cancel'},
  ],
};

/// Descriptor for `BeforePageBreakEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List beforePageBreakEventDescriptor = $convert.base64Decode(
    'ChRCZWZvcmVQYWdlQnJlYWtFdmVudBIQCgNyb3cYASABKAVSA3JvdxIWCgZjYW5jZWwYAiABKA'
    'hSBmNhbmNlbA==');

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

const $core.Map<$core.String, $core.dynamic> VolvoxGridServiceBase$json = {
  '1': 'VolvoxGridService',
  '2': [
    {
      '1': 'Create',
      '2': '.volvoxgrid.v1.CreateRequest',
      '3': '.volvoxgrid.v1.GridHandle'
    },
    {
      '1': 'Destroy',
      '2': '.volvoxgrid.v1.GridHandle',
      '3': '.volvoxgrid.v1.Empty'
    },
    {
      '1': 'Configure',
      '2': '.volvoxgrid.v1.ConfigureRequest',
      '3': '.volvoxgrid.v1.Empty'
    },
    {
      '1': 'GetConfig',
      '2': '.volvoxgrid.v1.GridHandle',
      '3': '.volvoxgrid.v1.GridConfig'
    },
    {
      '1': 'LoadFontData',
      '2': '.volvoxgrid.v1.LoadFontDataRequest',
      '3': '.volvoxgrid.v1.Empty'
    },
    {
      '1': 'DefineColumns',
      '2': '.volvoxgrid.v1.DefineColumnsRequest',
      '3': '.volvoxgrid.v1.Empty'
    },
    {
      '1': 'GetSchema',
      '2': '.volvoxgrid.v1.GridHandle',
      '3': '.volvoxgrid.v1.DefineColumnsRequest'
    },
    {
      '1': 'DefineRows',
      '2': '.volvoxgrid.v1.DefineRowsRequest',
      '3': '.volvoxgrid.v1.Empty'
    },
    {
      '1': 'InsertRows',
      '2': '.volvoxgrid.v1.InsertRowsRequest',
      '3': '.volvoxgrid.v1.Empty'
    },
    {
      '1': 'RemoveRows',
      '2': '.volvoxgrid.v1.RemoveRowsRequest',
      '3': '.volvoxgrid.v1.Empty'
    },
    {
      '1': 'MoveColumn',
      '2': '.volvoxgrid.v1.MoveColumnRequest',
      '3': '.volvoxgrid.v1.Empty'
    },
    {
      '1': 'MoveRow',
      '2': '.volvoxgrid.v1.MoveRowRequest',
      '3': '.volvoxgrid.v1.Empty'
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
      '1': 'Clear',
      '2': '.volvoxgrid.v1.ClearRequest',
      '3': '.volvoxgrid.v1.Empty'
    },
    {
      '1': 'Select',
      '2': '.volvoxgrid.v1.SelectRequest',
      '3': '.volvoxgrid.v1.Empty'
    },
    {
      '1': 'GetSelection',
      '2': '.volvoxgrid.v1.GridHandle',
      '3': '.volvoxgrid.v1.SelectionState'
    },
    {
      '1': 'Edit',
      '2': '.volvoxgrid.v1.EditCommand',
      '3': '.volvoxgrid.v1.EditState'
    },
    {
      '1': 'Sort',
      '2': '.volvoxgrid.v1.SortRequest',
      '3': '.volvoxgrid.v1.Empty'
    },
    {
      '1': 'Subtotal',
      '2': '.volvoxgrid.v1.SubtotalRequest',
      '3': '.volvoxgrid.v1.Empty'
    },
    {
      '1': 'AutoSize',
      '2': '.volvoxgrid.v1.AutoSizeRequest',
      '3': '.volvoxgrid.v1.Empty'
    },
    {
      '1': 'Outline',
      '2': '.volvoxgrid.v1.OutlineRequest',
      '3': '.volvoxgrid.v1.Empty'
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
      '3': '.volvoxgrid.v1.Empty'
    },
    {
      '1': 'UnmergeCells',
      '2': '.volvoxgrid.v1.UnmergeCellsRequest',
      '3': '.volvoxgrid.v1.Empty'
    },
    {
      '1': 'GetMergedRegions',
      '2': '.volvoxgrid.v1.GridHandle',
      '3': '.volvoxgrid.v1.MergedRegionsResponse'
    },
    {
      '1': 'GetMemoryUsage',
      '2': '.volvoxgrid.v1.GridHandle',
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
      '1': 'Import',
      '2': '.volvoxgrid.v1.ImportRequest',
      '3': '.volvoxgrid.v1.Empty'
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
      '3': '.volvoxgrid.v1.Empty'
    },
    {
      '1': 'SetRedraw',
      '2': '.volvoxgrid.v1.SetRedrawRequest',
      '3': '.volvoxgrid.v1.Empty'
    },
    {
      '1': 'Refresh',
      '2': '.volvoxgrid.v1.GridHandle',
      '3': '.volvoxgrid.v1.Empty'
    },
    {
      '1': 'LoadDemo',
      '2': '.volvoxgrid.v1.LoadDemoRequest',
      '3': '.volvoxgrid.v1.Empty'
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
      '2': '.volvoxgrid.v1.GridHandle',
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
  '.volvoxgrid.v1.ImageData': ImageData$json,
  '.volvoxgrid.v1.CellPadding': CellPadding$json,
  '.volvoxgrid.v1.HeaderSeparatorStyle': HeaderSeparatorStyle$json,
  '.volvoxgrid.v1.HeaderMarkSize': HeaderMarkSize$json,
  '.volvoxgrid.v1.HeaderResizeHandleStyle': HeaderResizeHandleStyle$json,
  '.volvoxgrid.v1.IconThemeSlots': IconThemeSlots$json,
  '.volvoxgrid.v1.IconThemeDefaults': IconThemeDefaults$json,
  '.volvoxgrid.v1.IconTextStyle': IconTextStyle$json,
  '.volvoxgrid.v1.IconLayoutStyle': IconLayoutStyle$json,
  '.volvoxgrid.v1.IconThemeSlotStyles': IconThemeSlotStyles$json,
  '.volvoxgrid.v1.IconThemeSlotStyle': IconThemeSlotStyle$json,
  '.volvoxgrid.v1.SelectionConfig': SelectionConfig$json,
  '.volvoxgrid.v1.HighlightStyle': HighlightStyle$json,
  '.volvoxgrid.v1.EditConfig': EditConfig$json,
  '.volvoxgrid.v1.ScrollConfig': ScrollConfig$json,
  '.volvoxgrid.v1.OutlineConfig': OutlineConfig$json,
  '.volvoxgrid.v1.SpanConfig': SpanConfig$json,
  '.volvoxgrid.v1.InteractionConfig': InteractionConfig$json,
  '.volvoxgrid.v1.RenderConfig': RenderConfig$json,
  '.volvoxgrid.v1.IndicatorBandsConfig': IndicatorBandsConfig$json,
  '.volvoxgrid.v1.RowIndicatorConfig': RowIndicatorConfig$json,
  '.volvoxgrid.v1.RowIndicatorSlot': RowIndicatorSlot$json,
  '.volvoxgrid.v1.ColIndicatorConfig': ColIndicatorConfig$json,
  '.volvoxgrid.v1.ColIndicatorRowDef': ColIndicatorRowDef$json,
  '.volvoxgrid.v1.ColIndicatorCell': ColIndicatorCell$json,
  '.volvoxgrid.v1.CornerIndicatorConfig': CornerIndicatorConfig$json,
  '.volvoxgrid.v1.GridHandle': GridHandle$json,
  '.volvoxgrid.v1.Empty': Empty$json,
  '.volvoxgrid.v1.ConfigureRequest': ConfigureRequest$json,
  '.volvoxgrid.v1.LoadFontDataRequest': LoadFontDataRequest$json,
  '.volvoxgrid.v1.DefineColumnsRequest': DefineColumnsRequest$json,
  '.volvoxgrid.v1.ColumnDef': ColumnDef$json,
  '.volvoxgrid.v1.DefineRowsRequest': DefineRowsRequest$json,
  '.volvoxgrid.v1.RowDef': RowDef$json,
  '.volvoxgrid.v1.InsertRowsRequest': InsertRowsRequest$json,
  '.volvoxgrid.v1.RemoveRowsRequest': RemoveRowsRequest$json,
  '.volvoxgrid.v1.MoveColumnRequest': MoveColumnRequest$json,
  '.volvoxgrid.v1.MoveRowRequest': MoveRowRequest$json,
  '.volvoxgrid.v1.UpdateCellsRequest': UpdateCellsRequest$json,
  '.volvoxgrid.v1.CellUpdate': CellUpdate$json,
  '.volvoxgrid.v1.CellValue': CellValue$json,
  '.volvoxgrid.v1.CellStyleOverride': CellStyleOverride$json,
  '.volvoxgrid.v1.WriteResult': WriteResult$json,
  '.volvoxgrid.v1.TypeViolation': TypeViolation$json,
  '.volvoxgrid.v1.GetCellsRequest': GetCellsRequest$json,
  '.volvoxgrid.v1.CellsResponse': CellsResponse$json,
  '.volvoxgrid.v1.CellData': CellData$json,
  '.volvoxgrid.v1.LoadTableRequest': LoadTableRequest$json,
  '.volvoxgrid.v1.ClearRequest': ClearRequest$json,
  '.volvoxgrid.v1.SelectRequest': SelectRequest$json,
  '.volvoxgrid.v1.CellRange': CellRange$json,
  '.volvoxgrid.v1.SelectionState': SelectionState$json,
  '.volvoxgrid.v1.EditCommand': EditCommand$json,
  '.volvoxgrid.v1.EditStart': EditStart$json,
  '.volvoxgrid.v1.EditCommit': EditCommit$json,
  '.volvoxgrid.v1.EditCancel': EditCancel$json,
  '.volvoxgrid.v1.EditSetText': EditSetText$json,
  '.volvoxgrid.v1.EditSetSelection': EditSetSelection$json,
  '.volvoxgrid.v1.EditFinish': EditFinish$json,
  '.volvoxgrid.v1.EditSetHighlights': EditSetHighlights$json,
  '.volvoxgrid.v1.HighlightRegion': HighlightRegion$json,
  '.volvoxgrid.v1.EditState': EditState$json,
  '.volvoxgrid.v1.SortRequest': SortRequest$json,
  '.volvoxgrid.v1.SortColumn': SortColumn$json,
  '.volvoxgrid.v1.SubtotalRequest': SubtotalRequest$json,
  '.volvoxgrid.v1.AutoSizeRequest': AutoSizeRequest$json,
  '.volvoxgrid.v1.OutlineRequest': OutlineRequest$json,
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
  '.volvoxgrid.v1.UnmergeCellsRequest': UnmergeCellsRequest$json,
  '.volvoxgrid.v1.MergedRegionsResponse': MergedRegionsResponse$json,
  '.volvoxgrid.v1.MemoryUsageResponse': MemoryUsageResponse$json,
  '.volvoxgrid.v1.ClipboardCommand': ClipboardCommand$json,
  '.volvoxgrid.v1.ClipboardCopy': ClipboardCopy$json,
  '.volvoxgrid.v1.ClipboardCut': ClipboardCut$json,
  '.volvoxgrid.v1.ClipboardPaste': ClipboardPaste$json,
  '.volvoxgrid.v1.ClipboardDelete': ClipboardDelete$json,
  '.volvoxgrid.v1.ClipboardResponse': ClipboardResponse$json,
  '.volvoxgrid.v1.ExportRequest': ExportRequest$json,
  '.volvoxgrid.v1.ExportResponse': ExportResponse$json,
  '.volvoxgrid.v1.ImportRequest': ImportRequest$json,
  '.volvoxgrid.v1.PrintRequest': PrintRequest$json,
  '.volvoxgrid.v1.PrintResponse': PrintResponse$json,
  '.volvoxgrid.v1.PrintPage': PrintPage$json,
  '.volvoxgrid.v1.ArchiveRequest': ArchiveRequest$json,
  '.volvoxgrid.v1.ArchiveResponse': ArchiveResponse$json,
  '.volvoxgrid.v1.ResizeViewportRequest': ResizeViewportRequest$json,
  '.volvoxgrid.v1.SetRedrawRequest': SetRedrawRequest$json,
  '.volvoxgrid.v1.LoadDemoRequest': LoadDemoRequest$json,
  '.volvoxgrid.v1.RenderInput': RenderInput$json,
  '.volvoxgrid.v1.ViewportState': ViewportState$json,
  '.volvoxgrid.v1.PointerEvent': PointerEvent$json,
  '.volvoxgrid.v1.KeyEvent': KeyEvent$json,
  '.volvoxgrid.v1.BufferReady': BufferReady$json,
  '.volvoxgrid.v1.ScrollEvent': ScrollEvent$json,
  '.volvoxgrid.v1.EventDecision': EventDecision$json,
  '.volvoxgrid.v1.ZoomEvent': ZoomEvent$json,
  '.volvoxgrid.v1.GpuSurfaceReady': GpuSurfaceReady$json,
  '.volvoxgrid.v1.RenderOutput': RenderOutput$json,
  '.volvoxgrid.v1.FrameDone': FrameDone$json,
  '.volvoxgrid.v1.SelectionUpdate': SelectionUpdate$json,
  '.volvoxgrid.v1.CursorChange': CursorChange$json,
  '.volvoxgrid.v1.EditRequest': EditRequest$json,
  '.volvoxgrid.v1.DropdownRequest': DropdownRequest$json,
  '.volvoxgrid.v1.TooltipRequest': TooltipRequest$json,
  '.volvoxgrid.v1.GpuFrameDone': GpuFrameDone$json,
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
  '.volvoxgrid.v1.CellButtonClickEvent': CellButtonClickEvent$json,
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
};

/// Descriptor for `VolvoxGridService`. Decode as a `google.protobuf.ServiceDescriptorProto`.
final $typed_data.Uint8List volvoxGridServiceDescriptor = $convert.base64Decode(
    'ChFWb2x2b3hHcmlkU2VydmljZRJBCgZDcmVhdGUSHC52b2x2b3hncmlkLnYxLkNyZWF0ZVJlcX'
    'Vlc3QaGS52b2x2b3hncmlkLnYxLkdyaWRIYW5kbGUSOgoHRGVzdHJveRIZLnZvbHZveGdyaWQu'
    'djEuR3JpZEhhbmRsZRoULnZvbHZveGdyaWQudjEuRW1wdHkSQgoJQ29uZmlndXJlEh8udm9sdm'
    '94Z3JpZC52MS5Db25maWd1cmVSZXF1ZXN0GhQudm9sdm94Z3JpZC52MS5FbXB0eRJBCglHZXRD'
    'b25maWcSGS52b2x2b3hncmlkLnYxLkdyaWRIYW5kbGUaGS52b2x2b3hncmlkLnYxLkdyaWRDb2'
    '5maWcSSAoMTG9hZEZvbnREYXRhEiIudm9sdm94Z3JpZC52MS5Mb2FkRm9udERhdGFSZXF1ZXN0'
    'GhQudm9sdm94Z3JpZC52MS5FbXB0eRJKCg1EZWZpbmVDb2x1bW5zEiMudm9sdm94Z3JpZC52MS'
    '5EZWZpbmVDb2x1bW5zUmVxdWVzdBoULnZvbHZveGdyaWQudjEuRW1wdHkSSwoJR2V0U2NoZW1h'
    'Ehkudm9sdm94Z3JpZC52MS5HcmlkSGFuZGxlGiMudm9sdm94Z3JpZC52MS5EZWZpbmVDb2x1bW'
    '5zUmVxdWVzdBJECgpEZWZpbmVSb3dzEiAudm9sdm94Z3JpZC52MS5EZWZpbmVSb3dzUmVxdWVz'
    'dBoULnZvbHZveGdyaWQudjEuRW1wdHkSRAoKSW5zZXJ0Um93cxIgLnZvbHZveGdyaWQudjEuSW'
    '5zZXJ0Um93c1JlcXVlc3QaFC52b2x2b3hncmlkLnYxLkVtcHR5EkQKClJlbW92ZVJvd3MSIC52'
    'b2x2b3hncmlkLnYxLlJlbW92ZVJvd3NSZXF1ZXN0GhQudm9sdm94Z3JpZC52MS5FbXB0eRJECg'
    'pNb3ZlQ29sdW1uEiAudm9sdm94Z3JpZC52MS5Nb3ZlQ29sdW1uUmVxdWVzdBoULnZvbHZveGdy'
    'aWQudjEuRW1wdHkSPgoHTW92ZVJvdxIdLnZvbHZveGdyaWQudjEuTW92ZVJvd1JlcXVlc3QaFC'
    '52b2x2b3hncmlkLnYxLkVtcHR5EkwKC1VwZGF0ZUNlbGxzEiEudm9sdm94Z3JpZC52MS5VcGRh'
    'dGVDZWxsc1JlcXVlc3QaGi52b2x2b3hncmlkLnYxLldyaXRlUmVzdWx0EkgKCEdldENlbGxzEh'
    '4udm9sdm94Z3JpZC52MS5HZXRDZWxsc1JlcXVlc3QaHC52b2x2b3hncmlkLnYxLkNlbGxzUmVz'
    'cG9uc2USSAoJTG9hZFRhYmxlEh8udm9sdm94Z3JpZC52MS5Mb2FkVGFibGVSZXF1ZXN0Ghoudm'
    '9sdm94Z3JpZC52MS5Xcml0ZVJlc3VsdBI6CgVDbGVhchIbLnZvbHZveGdyaWQudjEuQ2xlYXJS'
    'ZXF1ZXN0GhQudm9sdm94Z3JpZC52MS5FbXB0eRI8CgZTZWxlY3QSHC52b2x2b3hncmlkLnYxLl'
    'NlbGVjdFJlcXVlc3QaFC52b2x2b3hncmlkLnYxLkVtcHR5EkgKDEdldFNlbGVjdGlvbhIZLnZv'
    'bHZveGdyaWQudjEuR3JpZEhhbmRsZRodLnZvbHZveGdyaWQudjEuU2VsZWN0aW9uU3RhdGUSPA'
    'oERWRpdBIaLnZvbHZveGdyaWQudjEuRWRpdENvbW1hbmQaGC52b2x2b3hncmlkLnYxLkVkaXRT'
    'dGF0ZRI4CgRTb3J0Ehoudm9sdm94Z3JpZC52MS5Tb3J0UmVxdWVzdBoULnZvbHZveGdyaWQudj'
    'EuRW1wdHkSQAoIU3VidG90YWwSHi52b2x2b3hncmlkLnYxLlN1YnRvdGFsUmVxdWVzdBoULnZv'
    'bHZveGdyaWQudjEuRW1wdHkSQAoIQXV0b1NpemUSHi52b2x2b3hncmlkLnYxLkF1dG9TaXplUm'
    'VxdWVzdBoULnZvbHZveGdyaWQudjEuRW1wdHkSPgoHT3V0bGluZRIdLnZvbHZveGdyaWQudjEu'
    'T3V0bGluZVJlcXVlc3QaFC52b2x2b3hncmlkLnYxLkVtcHR5EkEKB0dldE5vZGUSHS52b2x2b3'
    'hncmlkLnYxLkdldE5vZGVSZXF1ZXN0Ghcudm9sdm94Z3JpZC52MS5Ob2RlSW5mbxI/CgRGaW5k'
    'Ehoudm9sdm94Z3JpZC52MS5GaW5kUmVxdWVzdBobLnZvbHZveGdyaWQudjEuRmluZFJlc3Bvbn'
    'NlEk4KCUFnZ3JlZ2F0ZRIfLnZvbHZveGdyaWQudjEuQWdncmVnYXRlUmVxdWVzdBogLnZvbHZv'
    'eGdyaWQudjEuQWdncmVnYXRlUmVzcG9uc2USUAoOR2V0TWVyZ2VkUmFuZ2USJC52b2x2b3hncm'
    'lkLnYxLkdldE1lcmdlZFJhbmdlUmVxdWVzdBoYLnZvbHZveGdyaWQudjEuQ2VsbFJhbmdlEkQK'
    'Ck1lcmdlQ2VsbHMSIC52b2x2b3hncmlkLnYxLk1lcmdlQ2VsbHNSZXF1ZXN0GhQudm9sdm94Z3'
    'JpZC52MS5FbXB0eRJICgxVbm1lcmdlQ2VsbHMSIi52b2x2b3hncmlkLnYxLlVubWVyZ2VDZWxs'
    'c1JlcXVlc3QaFC52b2x2b3hncmlkLnYxLkVtcHR5ElMKEEdldE1lcmdlZFJlZ2lvbnMSGS52b2'
    'x2b3hncmlkLnYxLkdyaWRIYW5kbGUaJC52b2x2b3hncmlkLnYxLk1lcmdlZFJlZ2lvbnNSZXNw'
    'b25zZRJPCg5HZXRNZW1vcnlVc2FnZRIZLnZvbHZveGdyaWQudjEuR3JpZEhhbmRsZRoiLnZvbH'
    'ZveGdyaWQudjEuTWVtb3J5VXNhZ2VSZXNwb25zZRJOCglDbGlwYm9hcmQSHy52b2x2b3hncmlk'
    'LnYxLkNsaXBib2FyZENvbW1hbmQaIC52b2x2b3hncmlkLnYxLkNsaXBib2FyZFJlc3BvbnNlEk'
    'UKBkV4cG9ydBIcLnZvbHZveGdyaWQudjEuRXhwb3J0UmVxdWVzdBodLnZvbHZveGdyaWQudjEu'
    'RXhwb3J0UmVzcG9uc2USPAoGSW1wb3J0Ehwudm9sdm94Z3JpZC52MS5JbXBvcnRSZXF1ZXN0Gh'
    'Qudm9sdm94Z3JpZC52MS5FbXB0eRJCCgVQcmludBIbLnZvbHZveGdyaWQudjEuUHJpbnRSZXF1'
    'ZXN0Ghwudm9sdm94Z3JpZC52MS5QcmludFJlc3BvbnNlEkgKB0FyY2hpdmUSHS52b2x2b3hncm'
    'lkLnYxLkFyY2hpdmVSZXF1ZXN0Gh4udm9sdm94Z3JpZC52MS5BcmNoaXZlUmVzcG9uc2USTAoO'
    'UmVzaXplVmlld3BvcnQSJC52b2x2b3hncmlkLnYxLlJlc2l6ZVZpZXdwb3J0UmVxdWVzdBoULn'
    'ZvbHZveGdyaWQudjEuRW1wdHkSQgoJU2V0UmVkcmF3Eh8udm9sdm94Z3JpZC52MS5TZXRSZWRy'
    'YXdSZXF1ZXN0GhQudm9sdm94Z3JpZC52MS5FbXB0eRI6CgdSZWZyZXNoEhkudm9sdm94Z3JpZC'
    '52MS5HcmlkSGFuZGxlGhQudm9sdm94Z3JpZC52MS5FbXB0eRJACghMb2FkRGVtbxIeLnZvbHZv'
    'eGdyaWQudjEuTG9hZERlbW9SZXF1ZXN0GhQudm9sdm94Z3JpZC52MS5FbXB0eRJMCg1SZW5kZX'
    'JTZXNzaW9uEhoudm9sdm94Z3JpZC52MS5SZW5kZXJJbnB1dBobLnZvbHZveGdyaWQudjEuUmVu'
    'ZGVyT3V0cHV0KAEwARJECgtFdmVudFN0cmVhbRIZLnZvbHZveGdyaWQudjEuR3JpZEhhbmRsZR'
    'oYLnZvbHZveGdyaWQudjEuR3JpZEV2ZW50MAE=');
