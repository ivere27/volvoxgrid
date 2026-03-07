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
  static const SortOrder SORT_GENERIC_ASCENDING =
      SortOrder._(1, _omitEnumNames ? '' : 'SORT_GENERIC_ASCENDING');
  static const SortOrder SORT_GENERIC_DESCENDING =
      SortOrder._(2, _omitEnumNames ? '' : 'SORT_GENERIC_DESCENDING');
  static const SortOrder SORT_NUMERIC_ASCENDING =
      SortOrder._(3, _omitEnumNames ? '' : 'SORT_NUMERIC_ASCENDING');
  static const SortOrder SORT_NUMERIC_DESCENDING =
      SortOrder._(4, _omitEnumNames ? '' : 'SORT_NUMERIC_DESCENDING');
  static const SortOrder SORT_STRING_NO_CASE_ASC =
      SortOrder._(5, _omitEnumNames ? '' : 'SORT_STRING_NO_CASE_ASC');
  static const SortOrder SORT_STRING_NO_CASE_DESC =
      SortOrder._(6, _omitEnumNames ? '' : 'SORT_STRING_NO_CASE_DESC');
  static const SortOrder SORT_STRING_ASC =
      SortOrder._(7, _omitEnumNames ? '' : 'SORT_STRING_ASC');
  static const SortOrder SORT_STRING_DESC =
      SortOrder._(8, _omitEnumNames ? '' : 'SORT_STRING_DESC');
  static const SortOrder SORT_CUSTOM =
      SortOrder._(9, _omitEnumNames ? '' : 'SORT_CUSTOM');
  static const SortOrder SORT_USE_COL_SORT =
      SortOrder._(10, _omitEnumNames ? '' : 'SORT_USE_COL_SORT');

  static const $core.List<SortOrder> values = <SortOrder>[
    SORT_NONE,
    SORT_GENERIC_ASCENDING,
    SORT_GENERIC_DESCENDING,
    SORT_NUMERIC_ASCENDING,
    SORT_NUMERIC_DESCENDING,
    SORT_STRING_NO_CASE_ASC,
    SORT_STRING_NO_CASE_DESC,
    SORT_STRING_ASC,
    SORT_STRING_DESC,
    SORT_CUSTOM,
    SORT_USE_COL_SORT,
  ];

  static final $core.List<SortOrder?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 10);
  static SortOrder? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const SortOrder._(super.value, super.name);
}

class HeaderFeatures extends $pb.ProtobufEnum {
  static const HeaderFeatures HEADER_NONE =
      HeaderFeatures._(0, _omitEnumNames ? '' : 'HEADER_NONE');
  static const HeaderFeatures HEADER_SORT =
      HeaderFeatures._(1, _omitEnumNames ? '' : 'HEADER_SORT');
  static const HeaderFeatures HEADER_REORDER =
      HeaderFeatures._(2, _omitEnumNames ? '' : 'HEADER_REORDER');
  static const HeaderFeatures HEADER_SORT_REORDER =
      HeaderFeatures._(3, _omitEnumNames ? '' : 'HEADER_SORT_REORDER');
  static const HeaderFeatures HEADER_SORT_CHOOSER =
      HeaderFeatures._(5, _omitEnumNames ? '' : 'HEADER_SORT_CHOOSER');
  static const HeaderFeatures HEADER_REORDER_CHOOSER =
      HeaderFeatures._(6, _omitEnumNames ? '' : 'HEADER_REORDER_CHOOSER');
  static const HeaderFeatures HEADER_SORT_REORDER_CHOOSER =
      HeaderFeatures._(7, _omitEnumNames ? '' : 'HEADER_SORT_REORDER_CHOOSER');

  static const $core.List<HeaderFeatures> values = <HeaderFeatures>[
    HEADER_NONE,
    HEADER_SORT,
    HEADER_REORDER,
    HEADER_SORT_REORDER,
    HEADER_SORT_CHOOSER,
    HEADER_REORDER_CHOOSER,
    HEADER_SORT_REORDER_CHOOSER,
  ];

  static final $core.List<HeaderFeatures?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 7);
  static HeaderFeatures? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const HeaderFeatures._(super.value, super.name);
}

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

class GridLineStyle extends $pb.ProtobufEnum {
  static const GridLineStyle GRIDLINE_NONE =
      GridLineStyle._(0, _omitEnumNames ? '' : 'GRIDLINE_NONE');
  static const GridLineStyle GRIDLINE_SOLID =
      GridLineStyle._(1, _omitEnumNames ? '' : 'GRIDLINE_SOLID');
  static const GridLineStyle GRIDLINE_INSET =
      GridLineStyle._(2, _omitEnumNames ? '' : 'GRIDLINE_INSET');
  static const GridLineStyle GRIDLINE_RAISED =
      GridLineStyle._(3, _omitEnumNames ? '' : 'GRIDLINE_RAISED');
  static const GridLineStyle GRIDLINE_SOLID_HORIZONTAL =
      GridLineStyle._(4, _omitEnumNames ? '' : 'GRIDLINE_SOLID_HORIZONTAL');
  static const GridLineStyle GRIDLINE_SOLID_VERTICAL =
      GridLineStyle._(5, _omitEnumNames ? '' : 'GRIDLINE_SOLID_VERTICAL');
  static const GridLineStyle GRIDLINE_INSET_HORIZONTAL =
      GridLineStyle._(6, _omitEnumNames ? '' : 'GRIDLINE_INSET_HORIZONTAL');
  static const GridLineStyle GRIDLINE_INSET_VERTICAL =
      GridLineStyle._(7, _omitEnumNames ? '' : 'GRIDLINE_INSET_VERTICAL');
  static const GridLineStyle GRIDLINE_RAISED_HORIZONTAL =
      GridLineStyle._(8, _omitEnumNames ? '' : 'GRIDLINE_RAISED_HORIZONTAL');
  static const GridLineStyle GRIDLINE_RAISED_VERTICAL =
      GridLineStyle._(9, _omitEnumNames ? '' : 'GRIDLINE_RAISED_VERTICAL');

  static const $core.List<GridLineStyle> values = <GridLineStyle>[
    GRIDLINE_NONE,
    GRIDLINE_SOLID,
    GRIDLINE_INSET,
    GRIDLINE_RAISED,
    GRIDLINE_SOLID_HORIZONTAL,
    GRIDLINE_SOLID_VERTICAL,
    GRIDLINE_INSET_HORIZONTAL,
    GRIDLINE_INSET_VERTICAL,
    GRIDLINE_RAISED_HORIZONTAL,
    GRIDLINE_RAISED_VERTICAL,
  ];

  static final $core.List<GridLineStyle?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 9);
  static GridLineStyle? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const GridLineStyle._(super.value, super.name);
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

/// Defines how the grid handles incoming data that does not match
/// the configured column type.
class CoercionMode extends $pb.ProtobufEnum {
  static const CoercionMode COERCION_MODE_UNSPECIFIED =
      CoercionMode._(0, _omitEnumNames ? '' : 'COERCION_MODE_UNSPECIFIED');

  /// Types must match exactly.
  static const CoercionMode COERCION_MODE_STRICT =
      CoercionMode._(1, _omitEnumNames ? '' : 'COERCION_MODE_STRICT');

  /// Attempt standard type conversions.
  static const CoercionMode COERCION_MODE_FLEXIBLE =
      CoercionMode._(2, _omitEnumNames ? '' : 'COERCION_MODE_FLEXIBLE');

  /// Only allow parsing from string input.
  static const CoercionMode COERCION_MODE_PARSE_ONLY =
      CoercionMode._(3, _omitEnumNames ? '' : 'COERCION_MODE_PARSE_ONLY');

  static const $core.List<CoercionMode> values = <CoercionMode>[
    COERCION_MODE_UNSPECIFIED,
    COERCION_MODE_STRICT,
    COERCION_MODE_FLEXIBLE,
    COERCION_MODE_PARSE_ONLY,
  ];

  static final $core.List<CoercionMode?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static CoercionMode? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const CoercionMode._(super.value, super.name);
}

/// Defines what happens when type validation/coercion fails.
class WriteErrorMode extends $pb.ProtobufEnum {
  static const WriteErrorMode WRITE_ERROR_MODE_UNSPECIFIED =
      WriteErrorMode._(0, _omitEnumNames ? '' : 'WRITE_ERROR_MODE_UNSPECIFIED');

  /// Reject the write for the cell.
  static const WriteErrorMode WRITE_ERROR_MODE_REJECT =
      WriteErrorMode._(1, _omitEnumNames ? '' : 'WRITE_ERROR_MODE_REJECT');

  /// Write null/empty instead.
  static const WriteErrorMode WRITE_ERROR_MODE_SET_NULL =
      WriteErrorMode._(2, _omitEnumNames ? '' : 'WRITE_ERROR_MODE_SET_NULL');

  /// Skip this cell write and keep previous value.
  static const WriteErrorMode WRITE_ERROR_MODE_SKIP =
      WriteErrorMode._(3, _omitEnumNames ? '' : 'WRITE_ERROR_MODE_SKIP');

  static const $core.List<WriteErrorMode> values = <WriteErrorMode>[
    WRITE_ERROR_MODE_UNSPECIFIED,
    WRITE_ERROR_MODE_REJECT,
    WRITE_ERROR_MODE_SET_NULL,
    WRITE_ERROR_MODE_SKIP,
  ];

  static final $core.List<WriteErrorMode?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static WriteErrorMode? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const WriteErrorMode._(super.value, super.name);
}

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

class AllowUserResizingMode extends $pb.ProtobufEnum {
  static const AllowUserResizingMode RESIZE_NONE =
      AllowUserResizingMode._(0, _omitEnumNames ? '' : 'RESIZE_NONE');
  static const AllowUserResizingMode RESIZE_COLUMNS =
      AllowUserResizingMode._(1, _omitEnumNames ? '' : 'RESIZE_COLUMNS');
  static const AllowUserResizingMode RESIZE_ROWS =
      AllowUserResizingMode._(2, _omitEnumNames ? '' : 'RESIZE_ROWS');
  static const AllowUserResizingMode RESIZE_BOTH =
      AllowUserResizingMode._(3, _omitEnumNames ? '' : 'RESIZE_BOTH');
  static const AllowUserResizingMode RESIZE_COLUMNS_UNIFORM =
      AllowUserResizingMode._(
          4, _omitEnumNames ? '' : 'RESIZE_COLUMNS_UNIFORM');
  static const AllowUserResizingMode RESIZE_ROWS_UNIFORM =
      AllowUserResizingMode._(5, _omitEnumNames ? '' : 'RESIZE_ROWS_UNIFORM');
  static const AllowUserResizingMode RESIZE_BOTH_UNIFORM =
      AllowUserResizingMode._(6, _omitEnumNames ? '' : 'RESIZE_BOTH_UNIFORM');

  static const $core.List<AllowUserResizingMode> values =
      <AllowUserResizingMode>[
    RESIZE_NONE,
    RESIZE_COLUMNS,
    RESIZE_ROWS,
    RESIZE_BOTH,
    RESIZE_COLUMNS_UNIFORM,
    RESIZE_ROWS_UNIFORM,
    RESIZE_BOTH_UNIFORM,
  ];

  static final $core.List<AllowUserResizingMode?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 6);
  static AllowUserResizingMode? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const AllowUserResizingMode._(super.value, super.name);
}

class UserFreezeMode extends $pb.ProtobufEnum {
  static const UserFreezeMode USER_FREEZE_NONE =
      UserFreezeMode._(0, _omitEnumNames ? '' : 'USER_FREEZE_NONE');
  static const UserFreezeMode USER_FREEZE_COLUMNS =
      UserFreezeMode._(1, _omitEnumNames ? '' : 'USER_FREEZE_COLUMNS');
  static const UserFreezeMode USER_FREEZE_ROWS =
      UserFreezeMode._(2, _omitEnumNames ? '' : 'USER_FREEZE_ROWS');
  static const UserFreezeMode USER_FREEZE_BOTH =
      UserFreezeMode._(3, _omitEnumNames ? '' : 'USER_FREEZE_BOTH');

  static const $core.List<UserFreezeMode> values = <UserFreezeMode>[
    USER_FREEZE_NONE,
    USER_FREEZE_COLUMNS,
    USER_FREEZE_ROWS,
    USER_FREEZE_BOTH,
  ];

  static final $core.List<UserFreezeMode?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static UserFreezeMode? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const UserFreezeMode._(super.value, super.name);
}

class AutoSizeMode extends $pb.ProtobufEnum {
  static const AutoSizeMode AUTOSIZE_BOTH_WAYS =
      AutoSizeMode._(0, _omitEnumNames ? '' : 'AUTOSIZE_BOTH_WAYS');
  static const AutoSizeMode AUTOSIZE_COL_WIDTH =
      AutoSizeMode._(1, _omitEnumNames ? '' : 'AUTOSIZE_COL_WIDTH');
  static const AutoSizeMode AUTOSIZE_ROW_HEIGHT =
      AutoSizeMode._(2, _omitEnumNames ? '' : 'AUTOSIZE_ROW_HEIGHT');

  static const $core.List<AutoSizeMode> values = <AutoSizeMode>[
    AUTOSIZE_BOTH_WAYS,
    AUTOSIZE_COL_WIDTH,
    AUTOSIZE_ROW_HEIGHT,
  ];

  static final $core.List<AutoSizeMode?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static AutoSizeMode? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const AutoSizeMode._(super.value, super.name);
}

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

  static const $core.List<RendererMode> values = <RendererMode>[
    RENDERER_AUTO,
    RENDERER_CPU,
    RENDERER_GPU,
    RENDERER_GPU_VULKAN,
    RENDERER_GPU_GLES,
  ];

  static final $core.List<RendererMode?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
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

/// Structural pin — row moves to pinned section
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

/// Visual sticky overlay — element sticks to edge when scrolled out
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
  static const BorderStyle BORDER_RAISED =
      BorderStyle._(6, _omitEnumNames ? '' : 'BORDER_RAISED');
  static const BorderStyle BORDER_INSET =
      BorderStyle._(7, _omitEnumNames ? '' : 'BORDER_INSET');

  static const $core.List<BorderStyle> values = <BorderStyle>[
    BORDER_NONE,
    BORDER_THIN,
    BORDER_THICK,
    BORDER_DOTTED,
    BORDER_DASHED,
    BORDER_DOUBLE,
    BORDER_RAISED,
    BORDER_INSET,
  ];

  static final $core.List<BorderStyle?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 7);
  static BorderStyle? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const BorderStyle._(super.value, super.name);
}

/// Hover bitmask flags. Combine with OR:
/// - row+col: 3
/// - row+cell: 5
/// - row+col+cell: 7
class HoverMode extends $pb.ProtobufEnum {
  static const HoverMode HOVER_NONE =
      HoverMode._(0, _omitEnumNames ? '' : 'HOVER_NONE');
  static const HoverMode HOVER_ROW =
      HoverMode._(1, _omitEnumNames ? '' : 'HOVER_ROW');
  static const HoverMode HOVER_COLUMN =
      HoverMode._(2, _omitEnumNames ? '' : 'HOVER_COLUMN');
  static const HoverMode HOVER_CELL =
      HoverMode._(4, _omitEnumNames ? '' : 'HOVER_CELL');

  static const $core.List<HoverMode> values = <HoverMode>[
    HOVER_NONE,
    HOVER_ROW,
    HOVER_COLUMN,
    HOVER_CELL,
  ];

  static final $core.List<HoverMode?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static HoverMode? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const HoverMode._(super.value, super.name);
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

class ClearScope extends $pb.ProtobufEnum {
  static const ClearScope CLEAR_EVERYTHING =
      ClearScope._(0, _omitEnumNames ? '' : 'CLEAR_EVERYTHING');
  static const ClearScope CLEAR_FORMATTING =
      ClearScope._(1, _omitEnumNames ? '' : 'CLEAR_FORMATTING');
  static const ClearScope CLEAR_DATA =
      ClearScope._(2, _omitEnumNames ? '' : 'CLEAR_DATA');
  static const ClearScope CLEAR_SELECTION =
      ClearScope._(3, _omitEnumNames ? '' : 'CLEAR_SELECTION');

  static const $core.List<ClearScope> values = <ClearScope>[
    CLEAR_EVERYTHING,
    CLEAR_FORMATTING,
    CLEAR_DATA,
    CLEAR_SELECTION,
  ];

  static final $core.List<ClearScope?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
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

class ExportFormat extends $pb.ProtobufEnum {
  static const ExportFormat EXPORT_BINARY =
      ExportFormat._(0, _omitEnumNames ? '' : 'EXPORT_BINARY');
  static const ExportFormat EXPORT_TSV =
      ExportFormat._(1, _omitEnumNames ? '' : 'EXPORT_TSV');
  static const ExportFormat EXPORT_CSV =
      ExportFormat._(2, _omitEnumNames ? '' : 'EXPORT_CSV');
  static const ExportFormat EXPORT_DELIMITED =
      ExportFormat._(3, _omitEnumNames ? '' : 'EXPORT_DELIMITED');
  static const ExportFormat EXPORT_XLSX =
      ExportFormat._(4, _omitEnumNames ? '' : 'EXPORT_XLSX');

  static const $core.List<ExportFormat> values = <ExportFormat>[
    EXPORT_BINARY,
    EXPORT_TSV,
    EXPORT_CSV,
    EXPORT_DELIMITED,
    EXPORT_XLSX,
  ];

  static final $core.List<ExportFormat?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static ExportFormat? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ExportFormat._(super.value, super.name);
}

class ExportScope extends $pb.ProtobufEnum {
  static const ExportScope EXPORT_ALL =
      ExportScope._(0, _omitEnumNames ? '' : 'EXPORT_ALL');
  static const ExportScope EXPORT_DATA_ONLY =
      ExportScope._(1, _omitEnumNames ? '' : 'EXPORT_DATA_ONLY');
  static const ExportScope EXPORT_FORMAT_ONLY =
      ExportScope._(2, _omitEnumNames ? '' : 'EXPORT_FORMAT_ONLY');

  static const $core.List<ExportScope> values = <ExportScope>[
    EXPORT_ALL,
    EXPORT_DATA_ONLY,
    EXPORT_FORMAT_ONLY,
  ];

  static final $core.List<ExportScope?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static ExportScope? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ExportScope._(super.value, super.name);
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

class ArchiveRequest_Action extends $pb.ProtobufEnum {
  static const ArchiveRequest_Action SAVE =
      ArchiveRequest_Action._(0, _omitEnumNames ? '' : 'SAVE');
  static const ArchiveRequest_Action LOAD =
      ArchiveRequest_Action._(1, _omitEnumNames ? '' : 'LOAD');
  static const ArchiveRequest_Action DELETE =
      ArchiveRequest_Action._(2, _omitEnumNames ? '' : 'DELETE');
  static const ArchiveRequest_Action LIST =
      ArchiveRequest_Action._(3, _omitEnumNames ? '' : 'LIST');

  static const $core.List<ArchiveRequest_Action> values =
      <ArchiveRequest_Action>[
    SAVE,
    LOAD,
    DELETE,
    LIST,
  ];

  static final $core.List<ArchiveRequest_Action?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static ArchiveRequest_Action? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ArchiveRequest_Action._(super.value, super.name);
}

class PointerEvent_Type extends $pb.ProtobufEnum {
  static const PointerEvent_Type DOWN =
      PointerEvent_Type._(0, _omitEnumNames ? '' : 'DOWN');
  static const PointerEvent_Type UP =
      PointerEvent_Type._(1, _omitEnumNames ? '' : 'UP');
  static const PointerEvent_Type MOVE =
      PointerEvent_Type._(2, _omitEnumNames ? '' : 'MOVE');

  static const $core.List<PointerEvent_Type> values = <PointerEvent_Type>[
    DOWN,
    UP,
    MOVE,
  ];

  static final $core.List<PointerEvent_Type?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static PointerEvent_Type? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const PointerEvent_Type._(super.value, super.name);
}

class ZoomEvent_Phase extends $pb.ProtobufEnum {
  static const ZoomEvent_Phase ZOOM_BEGIN =
      ZoomEvent_Phase._(0, _omitEnumNames ? '' : 'ZOOM_BEGIN');
  static const ZoomEvent_Phase ZOOM_UPDATE =
      ZoomEvent_Phase._(1, _omitEnumNames ? '' : 'ZOOM_UPDATE');
  static const ZoomEvent_Phase ZOOM_END =
      ZoomEvent_Phase._(2, _omitEnumNames ? '' : 'ZOOM_END');

  static const $core.List<ZoomEvent_Phase> values = <ZoomEvent_Phase>[
    ZOOM_BEGIN,
    ZOOM_UPDATE,
    ZOOM_END,
  ];

  static final $core.List<ZoomEvent_Phase?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static ZoomEvent_Phase? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ZoomEvent_Phase._(super.value, super.name);
}

class KeyEvent_Type extends $pb.ProtobufEnum {
  static const KeyEvent_Type KEY_DOWN =
      KeyEvent_Type._(0, _omitEnumNames ? '' : 'KEY_DOWN');
  static const KeyEvent_Type KEY_UP =
      KeyEvent_Type._(1, _omitEnumNames ? '' : 'KEY_UP');
  static const KeyEvent_Type KEY_PRESS =
      KeyEvent_Type._(2, _omitEnumNames ? '' : 'KEY_PRESS');

  static const $core.List<KeyEvent_Type> values = <KeyEvent_Type>[
    KEY_DOWN,
    KEY_UP,
    KEY_PRESS,
  ];

  static final $core.List<KeyEvent_Type?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static KeyEvent_Type? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const KeyEvent_Type._(super.value, super.name);
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
