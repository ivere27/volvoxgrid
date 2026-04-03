// This is a generated file - do not edit.
//
// Generated from volvoxgrid.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'volvoxgrid.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'volvoxgrid.pbenum.dart';

class Font extends $pb.GeneratedMessage {
  factory Font({
    $core.String? family,
    $core.Iterable<$core.String>? families,
    $core.double? size,
    $core.bool? bold,
    $core.bool? italic,
    $core.bool? underline,
    $core.bool? strikethrough,
    $core.double? stretch,
  }) {
    final result = create();
    if (family != null) result.family = family;
    if (families != null) result.families.addAll(families);
    if (size != null) result.size = size;
    if (bold != null) result.bold = bold;
    if (italic != null) result.italic = italic;
    if (underline != null) result.underline = underline;
    if (strikethrough != null) result.strikethrough = strikethrough;
    if (stretch != null) result.stretch = stretch;
    return result;
  }

  Font._();

  factory Font.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Font.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Font',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'family')
    ..pPS(2, _omitFieldNames ? '' : 'families')
    ..aD(3, _omitFieldNames ? '' : 'size', fieldType: $pb.PbFieldType.OF)
    ..aOB(4, _omitFieldNames ? '' : 'bold')
    ..aOB(5, _omitFieldNames ? '' : 'italic')
    ..aOB(6, _omitFieldNames ? '' : 'underline')
    ..aOB(7, _omitFieldNames ? '' : 'strikethrough')
    ..aD(8, _omitFieldNames ? '' : 'stretch', fieldType: $pb.PbFieldType.OF)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Font clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Font copyWith(void Function(Font) updates) =>
      super.copyWith((message) => updates(message as Font)) as Font;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Font create() => Font._();
  @$core.override
  Font createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Font getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Font>(create);
  static Font? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get family => $_getSZ(0);
  @$pb.TagNumber(1)
  set family($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFamily() => $_has(0);
  @$pb.TagNumber(1)
  void clearFamily() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<$core.String> get families => $_getList(1);

  @$pb.TagNumber(3)
  $core.double get size => $_getN(2);
  @$pb.TagNumber(3)
  set size($core.double value) => $_setFloat(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSize() => $_has(2);
  @$pb.TagNumber(3)
  void clearSize() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get bold => $_getBF(3);
  @$pb.TagNumber(4)
  set bold($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasBold() => $_has(3);
  @$pb.TagNumber(4)
  void clearBold() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get italic => $_getBF(4);
  @$pb.TagNumber(5)
  set italic($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasItalic() => $_has(4);
  @$pb.TagNumber(5)
  void clearItalic() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get underline => $_getBF(5);
  @$pb.TagNumber(6)
  set underline($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasUnderline() => $_has(5);
  @$pb.TagNumber(6)
  void clearUnderline() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.bool get strikethrough => $_getBF(6);
  @$pb.TagNumber(7)
  set strikethrough($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasStrikethrough() => $_has(6);
  @$pb.TagNumber(7)
  void clearStrikethrough() => $_clearField(7);

  /// Horizontal font stretch (condensed/expanded width of the glyphs).
  /// VSFlexGrid legacy `font_width` maps to this field.
  @$pb.TagNumber(8)
  $core.double get stretch => $_getN(7);
  @$pb.TagNumber(8)
  set stretch($core.double value) => $_setFloat(7, value);
  @$pb.TagNumber(8)
  $core.bool hasStretch() => $_has(7);
  @$pb.TagNumber(8)
  void clearStretch() => $_clearField(8);
}

class Padding extends $pb.GeneratedMessage {
  factory Padding({
    $core.int? left,
    $core.int? top,
    $core.int? right,
    $core.int? bottom,
  }) {
    final result = create();
    if (left != null) result.left = left;
    if (top != null) result.top = top;
    if (right != null) result.right = right;
    if (bottom != null) result.bottom = bottom;
    return result;
  }

  Padding._();

  factory Padding.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Padding.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Padding',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'left')
    ..aI(2, _omitFieldNames ? '' : 'top')
    ..aI(3, _omitFieldNames ? '' : 'right')
    ..aI(4, _omitFieldNames ? '' : 'bottom')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Padding clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Padding copyWith(void Function(Padding) updates) =>
      super.copyWith((message) => updates(message as Padding)) as Padding;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Padding create() => Padding._();
  @$core.override
  Padding createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Padding getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Padding>(create);
  static Padding? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get left => $_getIZ(0);
  @$pb.TagNumber(1)
  set left($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLeft() => $_has(0);
  @$pb.TagNumber(1)
  void clearLeft() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get top => $_getIZ(1);
  @$pb.TagNumber(2)
  set top($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTop() => $_has(1);
  @$pb.TagNumber(2)
  void clearTop() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get right => $_getIZ(2);
  @$pb.TagNumber(3)
  set right($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRight() => $_has(2);
  @$pb.TagNumber(3)
  void clearRight() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get bottom => $_getIZ(3);
  @$pb.TagNumber(4)
  set bottom($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasBottom() => $_has(3);
  @$pb.TagNumber(4)
  void clearBottom() => $_clearField(4);
}

class Border extends $pb.GeneratedMessage {
  factory Border({
    BorderStyle? style,
    $core.int? color,
  }) {
    final result = create();
    if (style != null) result.style = style;
    if (color != null) result.color = color;
    return result;
  }

  Border._();

  factory Border.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Border.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Border',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aE<BorderStyle>(1, _omitFieldNames ? '' : 'style',
        enumValues: BorderStyle.values)
    ..aI(2, _omitFieldNames ? '' : 'color', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Border clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Border copyWith(void Function(Border) updates) =>
      super.copyWith((message) => updates(message as Border)) as Border;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Border create() => Border._();
  @$core.override
  Border createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Border getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Border>(create);
  static Border? _defaultInstance;

  @$pb.TagNumber(1)
  BorderStyle get style => $_getN(0);
  @$pb.TagNumber(1)
  set style(BorderStyle value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasStyle() => $_has(0);
  @$pb.TagNumber(1)
  void clearStyle() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get color => $_getIZ(1);
  @$pb.TagNumber(2)
  set color($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasColor() => $_has(1);
  @$pb.TagNumber(2)
  void clearColor() => $_clearField(2);
}

/// Per-edge borders with a shorthand `all` field.
/// Resolution: per-edge > all > inherited.
class Borders extends $pb.GeneratedMessage {
  factory Borders({
    Border? all,
    Border? top,
    Border? right,
    Border? bottom,
    Border? left,
  }) {
    final result = create();
    if (all != null) result.all = all;
    if (top != null) result.top = top;
    if (right != null) result.right = right;
    if (bottom != null) result.bottom = bottom;
    if (left != null) result.left = left;
    return result;
  }

  Borders._();

  factory Borders.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Borders.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Borders',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aOM<Border>(1, _omitFieldNames ? '' : 'all', subBuilder: Border.create)
    ..aOM<Border>(2, _omitFieldNames ? '' : 'top', subBuilder: Border.create)
    ..aOM<Border>(3, _omitFieldNames ? '' : 'right', subBuilder: Border.create)
    ..aOM<Border>(4, _omitFieldNames ? '' : 'bottom', subBuilder: Border.create)
    ..aOM<Border>(5, _omitFieldNames ? '' : 'left', subBuilder: Border.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Borders clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Borders copyWith(void Function(Borders) updates) =>
      super.copyWith((message) => updates(message as Borders)) as Borders;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Borders create() => Borders._();
  @$core.override
  Borders createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Borders getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Borders>(create);
  static Borders? _defaultInstance;

  @$pb.TagNumber(1)
  Border get all => $_getN(0);
  @$pb.TagNumber(1)
  set all(Border value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasAll() => $_has(0);
  @$pb.TagNumber(1)
  void clearAll() => $_clearField(1);
  @$pb.TagNumber(1)
  Border ensureAll() => $_ensure(0);

  @$pb.TagNumber(2)
  Border get top => $_getN(1);
  @$pb.TagNumber(2)
  set top(Border value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasTop() => $_has(1);
  @$pb.TagNumber(2)
  void clearTop() => $_clearField(2);
  @$pb.TagNumber(2)
  Border ensureTop() => $_ensure(1);

  @$pb.TagNumber(3)
  Border get right => $_getN(2);
  @$pb.TagNumber(3)
  set right(Border value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasRight() => $_has(2);
  @$pb.TagNumber(3)
  void clearRight() => $_clearField(3);
  @$pb.TagNumber(3)
  Border ensureRight() => $_ensure(2);

  @$pb.TagNumber(4)
  Border get bottom => $_getN(3);
  @$pb.TagNumber(4)
  set bottom(Border value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasBottom() => $_has(3);
  @$pb.TagNumber(4)
  void clearBottom() => $_clearField(4);
  @$pb.TagNumber(4)
  Border ensureBottom() => $_ensure(3);

  @$pb.TagNumber(5)
  Border get left => $_getN(4);
  @$pb.TagNumber(5)
  set left(Border value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasLeft() => $_has(4);
  @$pb.TagNumber(5)
  void clearLeft() => $_clearField(5);
  @$pb.TagNumber(5)
  Border ensureLeft() => $_ensure(4);
}

class GridLines extends $pb.GeneratedMessage {
  factory GridLines({
    GridLineStyle? style,
    GridLineDirection? direction,
    $core.int? color,
    $core.int? width,
  }) {
    final result = create();
    if (style != null) result.style = style;
    if (direction != null) result.direction = direction;
    if (color != null) result.color = color;
    if (width != null) result.width = width;
    return result;
  }

  GridLines._();

  factory GridLines.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GridLines.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GridLines',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aE<GridLineStyle>(1, _omitFieldNames ? '' : 'style',
        enumValues: GridLineStyle.values)
    ..aE<GridLineDirection>(2, _omitFieldNames ? '' : 'direction',
        enumValues: GridLineDirection.values)
    ..aI(3, _omitFieldNames ? '' : 'color', fieldType: $pb.PbFieldType.OU3)
    ..aI(4, _omitFieldNames ? '' : 'width')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GridLines clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GridLines copyWith(void Function(GridLines) updates) =>
      super.copyWith((message) => updates(message as GridLines)) as GridLines;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GridLines create() => GridLines._();
  @$core.override
  GridLines createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GridLines getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GridLines>(create);
  static GridLines? _defaultInstance;

  @$pb.TagNumber(1)
  GridLineStyle get style => $_getN(0);
  @$pb.TagNumber(1)
  set style(GridLineStyle value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasStyle() => $_has(0);
  @$pb.TagNumber(1)
  void clearStyle() => $_clearField(1);

  @$pb.TagNumber(2)
  GridLineDirection get direction => $_getN(1);
  @$pb.TagNumber(2)
  set direction(GridLineDirection value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasDirection() => $_has(1);
  @$pb.TagNumber(2)
  void clearDirection() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get color => $_getIZ(2);
  @$pb.TagNumber(3)
  set color($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasColor() => $_has(2);
  @$pb.TagNumber(3)
  void clearColor() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get width => $_getIZ(3);
  @$pb.TagNumber(4)
  set width($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasWidth() => $_has(3);
  @$pb.TagNumber(4)
  void clearWidth() => $_clearField(4);
}

class Separator extends $pb.GeneratedMessage {
  factory Separator({
    $core.bool? visible,
    $core.int? color,
    $core.int? width,
  }) {
    final result = create();
    if (visible != null) result.visible = visible;
    if (color != null) result.color = color;
    if (width != null) result.width = width;
    return result;
  }

  Separator._();

  factory Separator.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Separator.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Separator',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'visible')
    ..aI(2, _omitFieldNames ? '' : 'color', fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'width')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Separator clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Separator copyWith(void Function(Separator) updates) =>
      super.copyWith((message) => updates(message as Separator)) as Separator;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Separator create() => Separator._();
  @$core.override
  Separator createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Separator getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Separator>(create);
  static Separator? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get visible => $_getBF(0);
  @$pb.TagNumber(1)
  set visible($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasVisible() => $_has(0);
  @$pb.TagNumber(1)
  void clearVisible() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get color => $_getIZ(1);
  @$pb.TagNumber(2)
  set color($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasColor() => $_has(1);
  @$pb.TagNumber(2)
  void clearColor() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get width => $_getIZ(2);
  @$pb.TagNumber(3)
  set width($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasWidth() => $_has(2);
  @$pb.TagNumber(3)
  void clearWidth() => $_clearField(3);
}

class TextRendering extends $pb.GeneratedMessage {
  factory TextRendering({
    TextRenderMode? mode,
    TextHintingMode? hinting,
    $core.bool? pixelSnap,
  }) {
    final result = create();
    if (mode != null) result.mode = mode;
    if (hinting != null) result.hinting = hinting;
    if (pixelSnap != null) result.pixelSnap = pixelSnap;
    return result;
  }

  TextRendering._();

  factory TextRendering.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TextRendering.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TextRendering',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aE<TextRenderMode>(1, _omitFieldNames ? '' : 'mode',
        enumValues: TextRenderMode.values)
    ..aE<TextHintingMode>(2, _omitFieldNames ? '' : 'hinting',
        enumValues: TextHintingMode.values)
    ..aOB(3, _omitFieldNames ? '' : 'pixelSnap')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TextRendering clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TextRendering copyWith(void Function(TextRendering) updates) =>
      super.copyWith((message) => updates(message as TextRendering))
          as TextRendering;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TextRendering create() => TextRendering._();
  @$core.override
  TextRendering createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TextRendering getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TextRendering>(create);
  static TextRendering? _defaultInstance;

  @$pb.TagNumber(1)
  TextRenderMode get mode => $_getN(0);
  @$pb.TagNumber(1)
  set mode(TextRenderMode value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasMode() => $_has(0);
  @$pb.TagNumber(1)
  void clearMode() => $_clearField(1);

  @$pb.TagNumber(2)
  TextHintingMode get hinting => $_getN(1);
  @$pb.TagNumber(2)
  set hinting(TextHintingMode value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasHinting() => $_has(1);
  @$pb.TagNumber(2)
  void clearHinting() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get pixelSnap => $_getBF(2);
  @$pb.TagNumber(3)
  set pixelSnap($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPixelSnap() => $_has(2);
  @$pb.TagNumber(3)
  void clearPixelSnap() => $_clearField(3);
}

class ImageData extends $pb.GeneratedMessage {
  factory ImageData({
    $core.List<$core.int>? data,
    $core.String? format,
  }) {
    final result = create();
    if (data != null) result.data = data;
    if (format != null) result.format = format;
    return result;
  }

  ImageData._();

  factory ImageData.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ImageData.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ImageData',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OY)
    ..aOS(2, _omitFieldNames ? '' : 'format')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ImageData clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ImageData copyWith(void Function(ImageData) updates) =>
      super.copyWith((message) => updates(message as ImageData)) as ImageData;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ImageData create() => ImageData._();
  @$core.override
  ImageData createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ImageData getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ImageData>(create);
  static ImageData? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get data => $_getN(0);
  @$pb.TagNumber(1)
  set data($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasData() => $_has(0);
  @$pb.TagNumber(1)
  void clearData() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get format => $_getSZ(1);
  @$pb.TagNumber(2)
  set format($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFormat() => $_has(1);
  @$pb.TagNumber(2)
  void clearFormat() => $_clearField(2);
}

class CellRange extends $pb.GeneratedMessage {
  factory CellRange({
    $core.int? row1,
    $core.int? col1,
    $core.int? row2,
    $core.int? col2,
  }) {
    final result = create();
    if (row1 != null) result.row1 = row1;
    if (col1 != null) result.col1 = col1;
    if (row2 != null) result.row2 = row2;
    if (col2 != null) result.col2 = col2;
    return result;
  }

  CellRange._();

  factory CellRange.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CellRange.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CellRange',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'row1')
    ..aI(2, _omitFieldNames ? '' : 'col1')
    ..aI(3, _omitFieldNames ? '' : 'row2')
    ..aI(4, _omitFieldNames ? '' : 'col2')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CellRange clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CellRange copyWith(void Function(CellRange) updates) =>
      super.copyWith((message) => updates(message as CellRange)) as CellRange;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CellRange create() => CellRange._();
  @$core.override
  CellRange createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CellRange getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CellRange>(create);
  static CellRange? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get row1 => $_getIZ(0);
  @$pb.TagNumber(1)
  set row1($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRow1() => $_has(0);
  @$pb.TagNumber(1)
  void clearRow1() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get col1 => $_getIZ(1);
  @$pb.TagNumber(2)
  set col1($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCol1() => $_has(1);
  @$pb.TagNumber(2)
  void clearCol1() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get row2 => $_getIZ(2);
  @$pb.TagNumber(3)
  set row2($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRow2() => $_has(2);
  @$pb.TagNumber(3)
  void clearRow2() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get col2 => $_getIZ(3);
  @$pb.TagNumber(4)
  set col2($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCol2() => $_has(3);
  @$pb.TagNumber(4)
  void clearCol2() => $_clearField(4);
}

enum CellValue_Value { text, number, flag, raw, timestamp, notSet }

class CellValue extends $pb.GeneratedMessage {
  factory CellValue({
    $core.String? text,
    $core.double? number,
    $core.bool? flag,
    $core.List<$core.int>? raw,
    $fixnum.Int64? timestamp,
  }) {
    final result = create();
    if (text != null) result.text = text;
    if (number != null) result.number = number;
    if (flag != null) result.flag = flag;
    if (raw != null) result.raw = raw;
    if (timestamp != null) result.timestamp = timestamp;
    return result;
  }

  CellValue._();

  factory CellValue.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CellValue.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, CellValue_Value> _CellValue_ValueByTag = {
    1: CellValue_Value.text,
    2: CellValue_Value.number,
    3: CellValue_Value.flag,
    4: CellValue_Value.raw,
    5: CellValue_Value.timestamp,
    0: CellValue_Value.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CellValue',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..oo(0, [1, 2, 3, 4, 5])
    ..aOS(1, _omitFieldNames ? '' : 'text')
    ..aD(2, _omitFieldNames ? '' : 'number')
    ..aOB(3, _omitFieldNames ? '' : 'flag')
    ..a<$core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'raw', $pb.PbFieldType.OY)
    ..aInt64(5, _omitFieldNames ? '' : 'timestamp')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CellValue clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CellValue copyWith(void Function(CellValue) updates) =>
      super.copyWith((message) => updates(message as CellValue)) as CellValue;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CellValue create() => CellValue._();
  @$core.override
  CellValue createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CellValue getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CellValue>(create);
  static CellValue? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  CellValue_Value whichValue() => _CellValue_ValueByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  void clearValue() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $core.String get text => $_getSZ(0);
  @$pb.TagNumber(1)
  set text($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasText() => $_has(0);
  @$pb.TagNumber(1)
  void clearText() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.double get number => $_getN(1);
  @$pb.TagNumber(2)
  set number($core.double value) => $_setDouble(1, value);
  @$pb.TagNumber(2)
  $core.bool hasNumber() => $_has(1);
  @$pb.TagNumber(2)
  void clearNumber() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get flag => $_getBF(2);
  @$pb.TagNumber(3)
  set flag($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFlag() => $_has(2);
  @$pb.TagNumber(3)
  void clearFlag() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get raw => $_getN(3);
  @$pb.TagNumber(4)
  set raw($core.List<$core.int> value) => $_setBytes(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRaw() => $_has(3);
  @$pb.TagNumber(4)
  void clearRaw() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get timestamp => $_getI64(4);
  @$pb.TagNumber(5)
  set timestamp($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTimestamp() => $_has(4);
  @$pb.TagNumber(5)
  void clearTimestamp() => $_clearField(5);
}

class ScrollBarColors extends $pb.GeneratedMessage {
  factory ScrollBarColors({
    $core.int? thumb,
    $core.int? thumbHover,
    $core.int? thumbActive,
    $core.int? track,
    $core.int? arrow,
    $core.int? border,
  }) {
    final result = create();
    if (thumb != null) result.thumb = thumb;
    if (thumbHover != null) result.thumbHover = thumbHover;
    if (thumbActive != null) result.thumbActive = thumbActive;
    if (track != null) result.track = track;
    if (arrow != null) result.arrow = arrow;
    if (border != null) result.border = border;
    return result;
  }

  ScrollBarColors._();

  factory ScrollBarColors.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ScrollBarColors.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ScrollBarColors',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'thumb', fieldType: $pb.PbFieldType.OU3)
    ..aI(2, _omitFieldNames ? '' : 'thumbHover', fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'thumbActive',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(4, _omitFieldNames ? '' : 'track', fieldType: $pb.PbFieldType.OU3)
    ..aI(5, _omitFieldNames ? '' : 'arrow', fieldType: $pb.PbFieldType.OU3)
    ..aI(6, _omitFieldNames ? '' : 'border', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ScrollBarColors clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ScrollBarColors copyWith(void Function(ScrollBarColors) updates) =>
      super.copyWith((message) => updates(message as ScrollBarColors))
          as ScrollBarColors;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ScrollBarColors create() => ScrollBarColors._();
  @$core.override
  ScrollBarColors createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ScrollBarColors getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ScrollBarColors>(create);
  static ScrollBarColors? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get thumb => $_getIZ(0);
  @$pb.TagNumber(1)
  set thumb($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasThumb() => $_has(0);
  @$pb.TagNumber(1)
  void clearThumb() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get thumbHover => $_getIZ(1);
  @$pb.TagNumber(2)
  set thumbHover($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasThumbHover() => $_has(1);
  @$pb.TagNumber(2)
  void clearThumbHover() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get thumbActive => $_getIZ(2);
  @$pb.TagNumber(3)
  set thumbActive($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasThumbActive() => $_has(2);
  @$pb.TagNumber(3)
  void clearThumbActive() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get track => $_getIZ(3);
  @$pb.TagNumber(4)
  set track($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTrack() => $_has(3);
  @$pb.TagNumber(4)
  void clearTrack() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get arrow => $_getIZ(4);
  @$pb.TagNumber(5)
  set arrow($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasArrow() => $_has(4);
  @$pb.TagNumber(5)
  void clearArrow() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get border => $_getIZ(5);
  @$pb.TagNumber(6)
  set border($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasBorder() => $_has(5);
  @$pb.TagNumber(6)
  void clearBorder() => $_clearField(6);
}

class ScrollBarConfig extends $pb.GeneratedMessage {
  factory ScrollBarConfig({
    ScrollBarMode? showH,
    ScrollBarMode? showV,
    ScrollBarAppearance? appearance,
    $core.int? size,
    $core.int? minThumb,
    $core.int? cornerRadius,
    ScrollBarColors? colors,
    $core.int? fadeDelayMs,
    $core.int? fadeDurationMs,
    $core.int? margin,
  }) {
    final result = create();
    if (showH != null) result.showH = showH;
    if (showV != null) result.showV = showV;
    if (appearance != null) result.appearance = appearance;
    if (size != null) result.size = size;
    if (minThumb != null) result.minThumb = minThumb;
    if (cornerRadius != null) result.cornerRadius = cornerRadius;
    if (colors != null) result.colors = colors;
    if (fadeDelayMs != null) result.fadeDelayMs = fadeDelayMs;
    if (fadeDurationMs != null) result.fadeDurationMs = fadeDurationMs;
    if (margin != null) result.margin = margin;
    return result;
  }

  ScrollBarConfig._();

  factory ScrollBarConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ScrollBarConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ScrollBarConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aE<ScrollBarMode>(1, _omitFieldNames ? '' : 'showH',
        enumValues: ScrollBarMode.values)
    ..aE<ScrollBarMode>(2, _omitFieldNames ? '' : 'showV',
        enumValues: ScrollBarMode.values)
    ..aE<ScrollBarAppearance>(3, _omitFieldNames ? '' : 'appearance',
        enumValues: ScrollBarAppearance.values)
    ..aI(4, _omitFieldNames ? '' : 'size')
    ..aI(5, _omitFieldNames ? '' : 'minThumb')
    ..aI(6, _omitFieldNames ? '' : 'cornerRadius')
    ..aOM<ScrollBarColors>(7, _omitFieldNames ? '' : 'colors',
        subBuilder: ScrollBarColors.create)
    ..aI(8, _omitFieldNames ? '' : 'fadeDelayMs')
    ..aI(9, _omitFieldNames ? '' : 'fadeDurationMs')
    ..aI(10, _omitFieldNames ? '' : 'margin')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ScrollBarConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ScrollBarConfig copyWith(void Function(ScrollBarConfig) updates) =>
      super.copyWith((message) => updates(message as ScrollBarConfig))
          as ScrollBarConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ScrollBarConfig create() => ScrollBarConfig._();
  @$core.override
  ScrollBarConfig createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ScrollBarConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ScrollBarConfig>(create);
  static ScrollBarConfig? _defaultInstance;

  @$pb.TagNumber(1)
  ScrollBarMode get showH => $_getN(0);
  @$pb.TagNumber(1)
  set showH(ScrollBarMode value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasShowH() => $_has(0);
  @$pb.TagNumber(1)
  void clearShowH() => $_clearField(1);

  @$pb.TagNumber(2)
  ScrollBarMode get showV => $_getN(1);
  @$pb.TagNumber(2)
  set showV(ScrollBarMode value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasShowV() => $_has(1);
  @$pb.TagNumber(2)
  void clearShowV() => $_clearField(2);

  @$pb.TagNumber(3)
  ScrollBarAppearance get appearance => $_getN(2);
  @$pb.TagNumber(3)
  set appearance(ScrollBarAppearance value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasAppearance() => $_has(2);
  @$pb.TagNumber(3)
  void clearAppearance() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get size => $_getIZ(3);
  @$pb.TagNumber(4)
  set size($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSize() => $_has(3);
  @$pb.TagNumber(4)
  void clearSize() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get minThumb => $_getIZ(4);
  @$pb.TagNumber(5)
  set minThumb($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasMinThumb() => $_has(4);
  @$pb.TagNumber(5)
  void clearMinThumb() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get cornerRadius => $_getIZ(5);
  @$pb.TagNumber(6)
  set cornerRadius($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCornerRadius() => $_has(5);
  @$pb.TagNumber(6)
  void clearCornerRadius() => $_clearField(6);

  @$pb.TagNumber(7)
  ScrollBarColors get colors => $_getN(6);
  @$pb.TagNumber(7)
  set colors(ScrollBarColors value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasColors() => $_has(6);
  @$pb.TagNumber(7)
  void clearColors() => $_clearField(7);
  @$pb.TagNumber(7)
  ScrollBarColors ensureColors() => $_ensure(6);

  @$pb.TagNumber(8)
  $core.int get fadeDelayMs => $_getIZ(7);
  @$pb.TagNumber(8)
  set fadeDelayMs($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasFadeDelayMs() => $_has(7);
  @$pb.TagNumber(8)
  void clearFadeDelayMs() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get fadeDurationMs => $_getIZ(8);
  @$pb.TagNumber(9)
  set fadeDurationMs($core.int value) => $_setSignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasFadeDurationMs() => $_has(8);
  @$pb.TagNumber(9)
  void clearFadeDurationMs() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.int get margin => $_getIZ(9);
  @$pb.TagNumber(10)
  set margin($core.int value) => $_setSignedInt32(9, value);
  @$pb.TagNumber(10)
  $core.bool hasMargin() => $_has(9);
  @$pb.TagNumber(10)
  void clearMargin() => $_clearField(10);
}

/// Override style for a region (fixed rows, frozen rows, etc.).
/// Only set fields override the grid-level default.
class RegionStyle extends $pb.GeneratedMessage {
  factory RegionStyle({
    $core.int? background,
    $core.int? foreground,
    Font? font,
    GridLines? gridLines,
    TextEffect? textEffect,
    Separator? separator,
    Padding? cellPadding,
  }) {
    final result = create();
    if (background != null) result.background = background;
    if (foreground != null) result.foreground = foreground;
    if (font != null) result.font = font;
    if (gridLines != null) result.gridLines = gridLines;
    if (textEffect != null) result.textEffect = textEffect;
    if (separator != null) result.separator = separator;
    if (cellPadding != null) result.cellPadding = cellPadding;
    return result;
  }

  RegionStyle._();

  factory RegionStyle.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RegionStyle.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RegionStyle',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'background', fieldType: $pb.PbFieldType.OU3)
    ..aI(2, _omitFieldNames ? '' : 'foreground', fieldType: $pb.PbFieldType.OU3)
    ..aOM<Font>(3, _omitFieldNames ? '' : 'font', subBuilder: Font.create)
    ..aOM<GridLines>(4, _omitFieldNames ? '' : 'gridLines',
        subBuilder: GridLines.create)
    ..aE<TextEffect>(5, _omitFieldNames ? '' : 'textEffect',
        enumValues: TextEffect.values)
    ..aOM<Separator>(6, _omitFieldNames ? '' : 'separator',
        subBuilder: Separator.create)
    ..aOM<Padding>(7, _omitFieldNames ? '' : 'cellPadding',
        subBuilder: Padding.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegionStyle clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegionStyle copyWith(void Function(RegionStyle) updates) =>
      super.copyWith((message) => updates(message as RegionStyle))
          as RegionStyle;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RegionStyle create() => RegionStyle._();
  @$core.override
  RegionStyle createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RegionStyle getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RegionStyle>(create);
  static RegionStyle? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get background => $_getIZ(0);
  @$pb.TagNumber(1)
  set background($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBackground() => $_has(0);
  @$pb.TagNumber(1)
  void clearBackground() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get foreground => $_getIZ(1);
  @$pb.TagNumber(2)
  set foreground($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasForeground() => $_has(1);
  @$pb.TagNumber(2)
  void clearForeground() => $_clearField(2);

  @$pb.TagNumber(3)
  Font get font => $_getN(2);
  @$pb.TagNumber(3)
  set font(Font value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasFont() => $_has(2);
  @$pb.TagNumber(3)
  void clearFont() => $_clearField(3);
  @$pb.TagNumber(3)
  Font ensureFont() => $_ensure(2);

  @$pb.TagNumber(4)
  GridLines get gridLines => $_getN(3);
  @$pb.TagNumber(4)
  set gridLines(GridLines value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasGridLines() => $_has(3);
  @$pb.TagNumber(4)
  void clearGridLines() => $_clearField(4);
  @$pb.TagNumber(4)
  GridLines ensureGridLines() => $_ensure(3);

  @$pb.TagNumber(5)
  TextEffect get textEffect => $_getN(4);
  @$pb.TagNumber(5)
  set textEffect(TextEffect value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasTextEffect() => $_has(4);
  @$pb.TagNumber(5)
  void clearTextEffect() => $_clearField(5);

  @$pb.TagNumber(6)
  Separator get separator => $_getN(5);
  @$pb.TagNumber(6)
  set separator(Separator value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasSeparator() => $_has(5);
  @$pb.TagNumber(6)
  void clearSeparator() => $_clearField(6);
  @$pb.TagNumber(6)
  Separator ensureSeparator() => $_ensure(5);

  @$pb.TagNumber(7)
  Padding get cellPadding => $_getN(6);
  @$pb.TagNumber(7)
  set cellPadding(Padding value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasCellPadding() => $_has(6);
  @$pb.TagNumber(7)
  void clearCellPadding() => $_clearField(7);
  @$pb.TagNumber(7)
  Padding ensureCellPadding() => $_ensure(6);
}

/// Per-cell style override. Composed from building blocks.
class CellStyle extends $pb.GeneratedMessage {
  factory CellStyle({
    $core.int? background,
    $core.int? foreground,
    Align? align,
    Font? font,
    Padding? padding,
    Borders? borders,
    TextEffect? textEffect,
    $core.double? progress,
    $core.int? progressColor,
    $core.bool? shrinkToFit,
  }) {
    final result = create();
    if (background != null) result.background = background;
    if (foreground != null) result.foreground = foreground;
    if (align != null) result.align = align;
    if (font != null) result.font = font;
    if (padding != null) result.padding = padding;
    if (borders != null) result.borders = borders;
    if (textEffect != null) result.textEffect = textEffect;
    if (progress != null) result.progress = progress;
    if (progressColor != null) result.progressColor = progressColor;
    if (shrinkToFit != null) result.shrinkToFit = shrinkToFit;
    return result;
  }

  CellStyle._();

  factory CellStyle.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CellStyle.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CellStyle',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'background', fieldType: $pb.PbFieldType.OU3)
    ..aI(2, _omitFieldNames ? '' : 'foreground', fieldType: $pb.PbFieldType.OU3)
    ..aE<Align>(3, _omitFieldNames ? '' : 'align', enumValues: Align.values)
    ..aOM<Font>(4, _omitFieldNames ? '' : 'font', subBuilder: Font.create)
    ..aOM<Padding>(5, _omitFieldNames ? '' : 'padding',
        subBuilder: Padding.create)
    ..aOM<Borders>(6, _omitFieldNames ? '' : 'borders',
        subBuilder: Borders.create)
    ..aE<TextEffect>(7, _omitFieldNames ? '' : 'textEffect',
        enumValues: TextEffect.values)
    ..aD(8, _omitFieldNames ? '' : 'progress', fieldType: $pb.PbFieldType.OF)
    ..aI(9, _omitFieldNames ? '' : 'progressColor',
        fieldType: $pb.PbFieldType.OU3)
    ..aOB(10, _omitFieldNames ? '' : 'shrinkToFit')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CellStyle clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CellStyle copyWith(void Function(CellStyle) updates) =>
      super.copyWith((message) => updates(message as CellStyle)) as CellStyle;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CellStyle create() => CellStyle._();
  @$core.override
  CellStyle createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CellStyle getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CellStyle>(create);
  static CellStyle? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get background => $_getIZ(0);
  @$pb.TagNumber(1)
  set background($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBackground() => $_has(0);
  @$pb.TagNumber(1)
  void clearBackground() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get foreground => $_getIZ(1);
  @$pb.TagNumber(2)
  set foreground($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasForeground() => $_has(1);
  @$pb.TagNumber(2)
  void clearForeground() => $_clearField(2);

  @$pb.TagNumber(3)
  Align get align => $_getN(2);
  @$pb.TagNumber(3)
  set align(Align value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasAlign() => $_has(2);
  @$pb.TagNumber(3)
  void clearAlign() => $_clearField(3);

  @$pb.TagNumber(4)
  Font get font => $_getN(3);
  @$pb.TagNumber(4)
  set font(Font value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasFont() => $_has(3);
  @$pb.TagNumber(4)
  void clearFont() => $_clearField(4);
  @$pb.TagNumber(4)
  Font ensureFont() => $_ensure(3);

  @$pb.TagNumber(5)
  Padding get padding => $_getN(4);
  @$pb.TagNumber(5)
  set padding(Padding value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasPadding() => $_has(4);
  @$pb.TagNumber(5)
  void clearPadding() => $_clearField(5);
  @$pb.TagNumber(5)
  Padding ensurePadding() => $_ensure(4);

  @$pb.TagNumber(6)
  Borders get borders => $_getN(5);
  @$pb.TagNumber(6)
  set borders(Borders value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasBorders() => $_has(5);
  @$pb.TagNumber(6)
  void clearBorders() => $_clearField(6);
  @$pb.TagNumber(6)
  Borders ensureBorders() => $_ensure(5);

  @$pb.TagNumber(7)
  TextEffect get textEffect => $_getN(6);
  @$pb.TagNumber(7)
  set textEffect(TextEffect value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasTextEffect() => $_has(6);
  @$pb.TagNumber(7)
  void clearTextEffect() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.double get progress => $_getN(7);
  @$pb.TagNumber(8)
  set progress($core.double value) => $_setFloat(7, value);
  @$pb.TagNumber(8)
  $core.bool hasProgress() => $_has(7);
  @$pb.TagNumber(8)
  void clearProgress() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get progressColor => $_getIZ(8);
  @$pb.TagNumber(9)
  set progressColor($core.int value) => $_setUnsignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasProgressColor() => $_has(8);
  @$pb.TagNumber(9)
  void clearProgressColor() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.bool get shrinkToFit => $_getBF(9);
  @$pb.TagNumber(10)
  set shrinkToFit($core.bool value) => $_setBool(9, value);
  @$pb.TagNumber(10)
  $core.bool hasShrinkToFit() => $_has(9);
  @$pb.TagNumber(10)
  void clearShrinkToFit() => $_clearField(10);
}

/// Selection / hover highlight appearance.
class HighlightStyle extends $pb.GeneratedMessage {
  factory HighlightStyle({
    $core.int? background,
    $core.int? foreground,
    Borders? borders,
    FillHandlePosition? fillHandle,
    $core.int? fillHandleColor,
  }) {
    final result = create();
    if (background != null) result.background = background;
    if (foreground != null) result.foreground = foreground;
    if (borders != null) result.borders = borders;
    if (fillHandle != null) result.fillHandle = fillHandle;
    if (fillHandleColor != null) result.fillHandleColor = fillHandleColor;
    return result;
  }

  HighlightStyle._();

  factory HighlightStyle.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory HighlightStyle.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'HighlightStyle',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'background', fieldType: $pb.PbFieldType.OU3)
    ..aI(2, _omitFieldNames ? '' : 'foreground', fieldType: $pb.PbFieldType.OU3)
    ..aOM<Borders>(3, _omitFieldNames ? '' : 'borders',
        subBuilder: Borders.create)
    ..aE<FillHandlePosition>(4, _omitFieldNames ? '' : 'fillHandle',
        enumValues: FillHandlePosition.values)
    ..aI(5, _omitFieldNames ? '' : 'fillHandleColor',
        fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HighlightStyle clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HighlightStyle copyWith(void Function(HighlightStyle) updates) =>
      super.copyWith((message) => updates(message as HighlightStyle))
          as HighlightStyle;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static HighlightStyle create() => HighlightStyle._();
  @$core.override
  HighlightStyle createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static HighlightStyle getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<HighlightStyle>(create);
  static HighlightStyle? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get background => $_getIZ(0);
  @$pb.TagNumber(1)
  set background($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBackground() => $_has(0);
  @$pb.TagNumber(1)
  void clearBackground() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get foreground => $_getIZ(1);
  @$pb.TagNumber(2)
  set foreground($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasForeground() => $_has(1);
  @$pb.TagNumber(2)
  void clearForeground() => $_clearField(2);

  @$pb.TagNumber(3)
  Borders get borders => $_getN(2);
  @$pb.TagNumber(3)
  set borders(Borders value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasBorders() => $_has(2);
  @$pb.TagNumber(3)
  void clearBorders() => $_clearField(3);
  @$pb.TagNumber(3)
  Borders ensureBorders() => $_ensure(2);

  @$pb.TagNumber(4)
  FillHandlePosition get fillHandle => $_getN(3);
  @$pb.TagNumber(4)
  set fillHandle(FillHandlePosition value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasFillHandle() => $_has(3);
  @$pb.TagNumber(4)
  void clearFillHandle() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get fillHandleColor => $_getIZ(4);
  @$pb.TagNumber(5)
  set fillHandleColor($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasFillHandleColor() => $_has(4);
  @$pb.TagNumber(5)
  void clearFillHandleColor() => $_clearField(5);
}

enum HeaderMarkSize_Value { ratio, px, notSet }

class HeaderMarkSize extends $pb.GeneratedMessage {
  factory HeaderMarkSize({
    $core.double? ratio,
    $core.int? px,
  }) {
    final result = create();
    if (ratio != null) result.ratio = ratio;
    if (px != null) result.px = px;
    return result;
  }

  HeaderMarkSize._();

  factory HeaderMarkSize.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory HeaderMarkSize.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, HeaderMarkSize_Value>
      _HeaderMarkSize_ValueByTag = {
    1: HeaderMarkSize_Value.ratio,
    2: HeaderMarkSize_Value.px,
    0: HeaderMarkSize_Value.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'HeaderMarkSize',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..oo(0, [1, 2])
    ..aD(1, _omitFieldNames ? '' : 'ratio', fieldType: $pb.PbFieldType.OF)
    ..aI(2, _omitFieldNames ? '' : 'px')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HeaderMarkSize clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HeaderMarkSize copyWith(void Function(HeaderMarkSize) updates) =>
      super.copyWith((message) => updates(message as HeaderMarkSize))
          as HeaderMarkSize;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static HeaderMarkSize create() => HeaderMarkSize._();
  @$core.override
  HeaderMarkSize createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static HeaderMarkSize getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<HeaderMarkSize>(create);
  static HeaderMarkSize? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  HeaderMarkSize_Value whichValue() =>
      _HeaderMarkSize_ValueByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  void clearValue() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $core.double get ratio => $_getN(0);
  @$pb.TagNumber(1)
  set ratio($core.double value) => $_setFloat(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRatio() => $_has(0);
  @$pb.TagNumber(1)
  void clearRatio() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get px => $_getIZ(1);
  @$pb.TagNumber(2)
  set px($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPx() => $_has(1);
  @$pb.TagNumber(2)
  void clearPx() => $_clearField(2);
}

class HeaderSeparator extends $pb.GeneratedMessage {
  factory HeaderSeparator({
    $core.bool? enabled,
    $core.int? color,
    $core.int? width,
    HeaderMarkSize? height,
    $core.bool? skipMerged,
  }) {
    final result = create();
    if (enabled != null) result.enabled = enabled;
    if (color != null) result.color = color;
    if (width != null) result.width = width;
    if (height != null) result.height = height;
    if (skipMerged != null) result.skipMerged = skipMerged;
    return result;
  }

  HeaderSeparator._();

  factory HeaderSeparator.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory HeaderSeparator.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'HeaderSeparator',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'enabled')
    ..aI(2, _omitFieldNames ? '' : 'color', fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'width')
    ..aOM<HeaderMarkSize>(4, _omitFieldNames ? '' : 'height',
        subBuilder: HeaderMarkSize.create)
    ..aOB(5, _omitFieldNames ? '' : 'skipMerged')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HeaderSeparator clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HeaderSeparator copyWith(void Function(HeaderSeparator) updates) =>
      super.copyWith((message) => updates(message as HeaderSeparator))
          as HeaderSeparator;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static HeaderSeparator create() => HeaderSeparator._();
  @$core.override
  HeaderSeparator createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static HeaderSeparator getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<HeaderSeparator>(create);
  static HeaderSeparator? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get enabled => $_getBF(0);
  @$pb.TagNumber(1)
  set enabled($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEnabled() => $_has(0);
  @$pb.TagNumber(1)
  void clearEnabled() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get color => $_getIZ(1);
  @$pb.TagNumber(2)
  set color($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasColor() => $_has(1);
  @$pb.TagNumber(2)
  void clearColor() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get width => $_getIZ(2);
  @$pb.TagNumber(3)
  set width($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasWidth() => $_has(2);
  @$pb.TagNumber(3)
  void clearWidth() => $_clearField(3);

  @$pb.TagNumber(4)
  HeaderMarkSize get height => $_getN(3);
  @$pb.TagNumber(4)
  set height(HeaderMarkSize value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasHeight() => $_has(3);
  @$pb.TagNumber(4)
  void clearHeight() => $_clearField(4);
  @$pb.TagNumber(4)
  HeaderMarkSize ensureHeight() => $_ensure(3);

  @$pb.TagNumber(5)
  $core.bool get skipMerged => $_getBF(4);
  @$pb.TagNumber(5)
  set skipMerged($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSkipMerged() => $_has(4);
  @$pb.TagNumber(5)
  void clearSkipMerged() => $_clearField(5);
}

class HeaderResizeHandle extends $pb.GeneratedMessage {
  factory HeaderResizeHandle({
    $core.bool? enabled,
    $core.int? color,
    $core.int? width,
    HeaderMarkSize? height,
    $core.int? hitWidth,
    $core.bool? showOnlyWhenResizable,
  }) {
    final result = create();
    if (enabled != null) result.enabled = enabled;
    if (color != null) result.color = color;
    if (width != null) result.width = width;
    if (height != null) result.height = height;
    if (hitWidth != null) result.hitWidth = hitWidth;
    if (showOnlyWhenResizable != null)
      result.showOnlyWhenResizable = showOnlyWhenResizable;
    return result;
  }

  HeaderResizeHandle._();

  factory HeaderResizeHandle.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory HeaderResizeHandle.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'HeaderResizeHandle',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'enabled')
    ..aI(2, _omitFieldNames ? '' : 'color', fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'width')
    ..aOM<HeaderMarkSize>(4, _omitFieldNames ? '' : 'height',
        subBuilder: HeaderMarkSize.create)
    ..aI(5, _omitFieldNames ? '' : 'hitWidth')
    ..aOB(6, _omitFieldNames ? '' : 'showOnlyWhenResizable')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HeaderResizeHandle clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HeaderResizeHandle copyWith(void Function(HeaderResizeHandle) updates) =>
      super.copyWith((message) => updates(message as HeaderResizeHandle))
          as HeaderResizeHandle;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static HeaderResizeHandle create() => HeaderResizeHandle._();
  @$core.override
  HeaderResizeHandle createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static HeaderResizeHandle getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<HeaderResizeHandle>(create);
  static HeaderResizeHandle? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get enabled => $_getBF(0);
  @$pb.TagNumber(1)
  set enabled($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEnabled() => $_has(0);
  @$pb.TagNumber(1)
  void clearEnabled() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get color => $_getIZ(1);
  @$pb.TagNumber(2)
  set color($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasColor() => $_has(1);
  @$pb.TagNumber(2)
  void clearColor() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get width => $_getIZ(2);
  @$pb.TagNumber(3)
  set width($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasWidth() => $_has(2);
  @$pb.TagNumber(3)
  void clearWidth() => $_clearField(3);

  @$pb.TagNumber(4)
  HeaderMarkSize get height => $_getN(3);
  @$pb.TagNumber(4)
  set height(HeaderMarkSize value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasHeight() => $_has(3);
  @$pb.TagNumber(4)
  void clearHeight() => $_clearField(4);
  @$pb.TagNumber(4)
  HeaderMarkSize ensureHeight() => $_ensure(3);

  @$pb.TagNumber(5)
  $core.int get hitWidth => $_getIZ(4);
  @$pb.TagNumber(5)
  set hitWidth($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasHitWidth() => $_has(4);
  @$pb.TagNumber(5)
  void clearHitWidth() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get showOnlyWhenResizable => $_getBF(5);
  @$pb.TagNumber(6)
  set showOnlyWhenResizable($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasShowOnlyWhenResizable() => $_has(5);
  @$pb.TagNumber(6)
  void clearShowOnlyWhenResizable() => $_clearField(6);
}

class HeaderStyle extends $pb.GeneratedMessage {
  factory HeaderStyle({
    HeaderSeparator? separator,
    HeaderResizeHandle? resizeHandle,
  }) {
    final result = create();
    if (separator != null) result.separator = separator;
    if (resizeHandle != null) result.resizeHandle = resizeHandle;
    return result;
  }

  HeaderStyle._();

  factory HeaderStyle.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory HeaderStyle.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'HeaderStyle',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aOM<HeaderSeparator>(1, _omitFieldNames ? '' : 'separator',
        subBuilder: HeaderSeparator.create)
    ..aOM<HeaderResizeHandle>(2, _omitFieldNames ? '' : 'resizeHandle',
        subBuilder: HeaderResizeHandle.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HeaderStyle clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HeaderStyle copyWith(void Function(HeaderStyle) updates) =>
      super.copyWith((message) => updates(message as HeaderStyle))
          as HeaderStyle;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static HeaderStyle create() => HeaderStyle._();
  @$core.override
  HeaderStyle createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static HeaderStyle getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<HeaderStyle>(create);
  static HeaderStyle? _defaultInstance;

  @$pb.TagNumber(1)
  HeaderSeparator get separator => $_getN(0);
  @$pb.TagNumber(1)
  set separator(HeaderSeparator value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasSeparator() => $_has(0);
  @$pb.TagNumber(1)
  void clearSeparator() => $_clearField(1);
  @$pb.TagNumber(1)
  HeaderSeparator ensureSeparator() => $_ensure(0);

  @$pb.TagNumber(2)
  HeaderResizeHandle get resizeHandle => $_getN(1);
  @$pb.TagNumber(2)
  set resizeHandle(HeaderResizeHandle value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasResizeHandle() => $_has(1);
  @$pb.TagNumber(2)
  void clearResizeHandle() => $_clearField(2);
  @$pb.TagNumber(2)
  HeaderResizeHandle ensureResizeHandle() => $_ensure(1);
}

/// Text glyph values per slot (e.g. Material Icons codepoints).
class IconSlots extends $pb.GeneratedMessage {
  factory IconSlots({
    $core.String? sortAscending,
    $core.String? sortDescending,
    $core.String? sortNone,
    $core.String? treeExpanded,
    $core.String? treeCollapsed,
    $core.String? menu,
    $core.String? filter,
    $core.String? filterActive,
    $core.String? columns,
    $core.String? dragHandle,
    $core.String? checkboxChecked,
    $core.String? checkboxUnchecked,
    $core.String? checkboxIndeterminate,
  }) {
    final result = create();
    if (sortAscending != null) result.sortAscending = sortAscending;
    if (sortDescending != null) result.sortDescending = sortDescending;
    if (sortNone != null) result.sortNone = sortNone;
    if (treeExpanded != null) result.treeExpanded = treeExpanded;
    if (treeCollapsed != null) result.treeCollapsed = treeCollapsed;
    if (menu != null) result.menu = menu;
    if (filter != null) result.filter = filter;
    if (filterActive != null) result.filterActive = filterActive;
    if (columns != null) result.columns = columns;
    if (dragHandle != null) result.dragHandle = dragHandle;
    if (checkboxChecked != null) result.checkboxChecked = checkboxChecked;
    if (checkboxUnchecked != null) result.checkboxUnchecked = checkboxUnchecked;
    if (checkboxIndeterminate != null)
      result.checkboxIndeterminate = checkboxIndeterminate;
    return result;
  }

  IconSlots._();

  factory IconSlots.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory IconSlots.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'IconSlots',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sortAscending')
    ..aOS(2, _omitFieldNames ? '' : 'sortDescending')
    ..aOS(3, _omitFieldNames ? '' : 'sortNone')
    ..aOS(4, _omitFieldNames ? '' : 'treeExpanded')
    ..aOS(5, _omitFieldNames ? '' : 'treeCollapsed')
    ..aOS(6, _omitFieldNames ? '' : 'menu')
    ..aOS(7, _omitFieldNames ? '' : 'filter')
    ..aOS(8, _omitFieldNames ? '' : 'filterActive')
    ..aOS(9, _omitFieldNames ? '' : 'columns')
    ..aOS(10, _omitFieldNames ? '' : 'dragHandle')
    ..aOS(11, _omitFieldNames ? '' : 'checkboxChecked')
    ..aOS(12, _omitFieldNames ? '' : 'checkboxUnchecked')
    ..aOS(13, _omitFieldNames ? '' : 'checkboxIndeterminate')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  IconSlots clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  IconSlots copyWith(void Function(IconSlots) updates) =>
      super.copyWith((message) => updates(message as IconSlots)) as IconSlots;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static IconSlots create() => IconSlots._();
  @$core.override
  IconSlots createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static IconSlots getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<IconSlots>(create);
  static IconSlots? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sortAscending => $_getSZ(0);
  @$pb.TagNumber(1)
  set sortAscending($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSortAscending() => $_has(0);
  @$pb.TagNumber(1)
  void clearSortAscending() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get sortDescending => $_getSZ(1);
  @$pb.TagNumber(2)
  set sortDescending($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSortDescending() => $_has(1);
  @$pb.TagNumber(2)
  void clearSortDescending() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get sortNone => $_getSZ(2);
  @$pb.TagNumber(3)
  set sortNone($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSortNone() => $_has(2);
  @$pb.TagNumber(3)
  void clearSortNone() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get treeExpanded => $_getSZ(3);
  @$pb.TagNumber(4)
  set treeExpanded($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTreeExpanded() => $_has(3);
  @$pb.TagNumber(4)
  void clearTreeExpanded() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get treeCollapsed => $_getSZ(4);
  @$pb.TagNumber(5)
  set treeCollapsed($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTreeCollapsed() => $_has(4);
  @$pb.TagNumber(5)
  void clearTreeCollapsed() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get menu => $_getSZ(5);
  @$pb.TagNumber(6)
  set menu($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasMenu() => $_has(5);
  @$pb.TagNumber(6)
  void clearMenu() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get filter => $_getSZ(6);
  @$pb.TagNumber(7)
  set filter($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasFilter() => $_has(6);
  @$pb.TagNumber(7)
  void clearFilter() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get filterActive => $_getSZ(7);
  @$pb.TagNumber(8)
  set filterActive($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasFilterActive() => $_has(7);
  @$pb.TagNumber(8)
  void clearFilterActive() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get columns => $_getSZ(8);
  @$pb.TagNumber(9)
  set columns($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasColumns() => $_has(8);
  @$pb.TagNumber(9)
  void clearColumns() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get dragHandle => $_getSZ(9);
  @$pb.TagNumber(10)
  set dragHandle($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasDragHandle() => $_has(9);
  @$pb.TagNumber(10)
  void clearDragHandle() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.String get checkboxChecked => $_getSZ(10);
  @$pb.TagNumber(11)
  set checkboxChecked($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasCheckboxChecked() => $_has(10);
  @$pb.TagNumber(11)
  void clearCheckboxChecked() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.String get checkboxUnchecked => $_getSZ(11);
  @$pb.TagNumber(12)
  set checkboxUnchecked($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasCheckboxUnchecked() => $_has(11);
  @$pb.TagNumber(12)
  void clearCheckboxUnchecked() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.String get checkboxIndeterminate => $_getSZ(12);
  @$pb.TagNumber(13)
  set checkboxIndeterminate($core.String value) => $_setString(12, value);
  @$pb.TagNumber(13)
  $core.bool hasCheckboxIndeterminate() => $_has(12);
  @$pb.TagNumber(13)
  void clearCheckboxIndeterminate() => $_clearField(13);
}

/// Rendering style for a single icon slot.
class IconStyle extends $pb.GeneratedMessage {
  factory IconStyle({
    Font? font,
    $core.int? color,
    IconAlign? align,
    $core.int? gap,
  }) {
    final result = create();
    if (font != null) result.font = font;
    if (color != null) result.color = color;
    if (align != null) result.align = align;
    if (gap != null) result.gap = gap;
    return result;
  }

  IconStyle._();

  factory IconStyle.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory IconStyle.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'IconStyle',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aOM<Font>(1, _omitFieldNames ? '' : 'font', subBuilder: Font.create)
    ..aI(2, _omitFieldNames ? '' : 'color', fieldType: $pb.PbFieldType.OU3)
    ..aE<IconAlign>(3, _omitFieldNames ? '' : 'align',
        enumValues: IconAlign.values)
    ..aI(4, _omitFieldNames ? '' : 'gap')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  IconStyle clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  IconStyle copyWith(void Function(IconStyle) updates) =>
      super.copyWith((message) => updates(message as IconStyle)) as IconStyle;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static IconStyle create() => IconStyle._();
  @$core.override
  IconStyle createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static IconStyle getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<IconStyle>(create);
  static IconStyle? _defaultInstance;

  @$pb.TagNumber(1)
  Font get font => $_getN(0);
  @$pb.TagNumber(1)
  set font(Font value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasFont() => $_has(0);
  @$pb.TagNumber(1)
  void clearFont() => $_clearField(1);
  @$pb.TagNumber(1)
  Font ensureFont() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.int get color => $_getIZ(1);
  @$pb.TagNumber(2)
  set color($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasColor() => $_has(1);
  @$pb.TagNumber(2)
  void clearColor() => $_clearField(2);

  @$pb.TagNumber(3)
  IconAlign get align => $_getN(2);
  @$pb.TagNumber(3)
  set align(IconAlign value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasAlign() => $_has(2);
  @$pb.TagNumber(3)
  void clearAlign() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get gap => $_getIZ(3);
  @$pb.TagNumber(4)
  set gap($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasGap() => $_has(3);
  @$pb.TagNumber(4)
  void clearGap() => $_clearField(4);
}

/// Per-slot style overrides.
class IconSlotStyles extends $pb.GeneratedMessage {
  factory IconSlotStyles({
    IconStyle? sortAscending,
    IconStyle? sortDescending,
    IconStyle? sortNone,
    IconStyle? treeExpanded,
    IconStyle? treeCollapsed,
    IconStyle? menu,
    IconStyle? filter,
    IconStyle? filterActive,
    IconStyle? columns,
    IconStyle? dragHandle,
    IconStyle? checkboxChecked,
    IconStyle? checkboxUnchecked,
    IconStyle? checkboxIndeterminate,
  }) {
    final result = create();
    if (sortAscending != null) result.sortAscending = sortAscending;
    if (sortDescending != null) result.sortDescending = sortDescending;
    if (sortNone != null) result.sortNone = sortNone;
    if (treeExpanded != null) result.treeExpanded = treeExpanded;
    if (treeCollapsed != null) result.treeCollapsed = treeCollapsed;
    if (menu != null) result.menu = menu;
    if (filter != null) result.filter = filter;
    if (filterActive != null) result.filterActive = filterActive;
    if (columns != null) result.columns = columns;
    if (dragHandle != null) result.dragHandle = dragHandle;
    if (checkboxChecked != null) result.checkboxChecked = checkboxChecked;
    if (checkboxUnchecked != null) result.checkboxUnchecked = checkboxUnchecked;
    if (checkboxIndeterminate != null)
      result.checkboxIndeterminate = checkboxIndeterminate;
    return result;
  }

  IconSlotStyles._();

  factory IconSlotStyles.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory IconSlotStyles.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'IconSlotStyles',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aOM<IconStyle>(1, _omitFieldNames ? '' : 'sortAscending',
        subBuilder: IconStyle.create)
    ..aOM<IconStyle>(2, _omitFieldNames ? '' : 'sortDescending',
        subBuilder: IconStyle.create)
    ..aOM<IconStyle>(3, _omitFieldNames ? '' : 'sortNone',
        subBuilder: IconStyle.create)
    ..aOM<IconStyle>(4, _omitFieldNames ? '' : 'treeExpanded',
        subBuilder: IconStyle.create)
    ..aOM<IconStyle>(5, _omitFieldNames ? '' : 'treeCollapsed',
        subBuilder: IconStyle.create)
    ..aOM<IconStyle>(6, _omitFieldNames ? '' : 'menu',
        subBuilder: IconStyle.create)
    ..aOM<IconStyle>(7, _omitFieldNames ? '' : 'filter',
        subBuilder: IconStyle.create)
    ..aOM<IconStyle>(8, _omitFieldNames ? '' : 'filterActive',
        subBuilder: IconStyle.create)
    ..aOM<IconStyle>(9, _omitFieldNames ? '' : 'columns',
        subBuilder: IconStyle.create)
    ..aOM<IconStyle>(10, _omitFieldNames ? '' : 'dragHandle',
        subBuilder: IconStyle.create)
    ..aOM<IconStyle>(11, _omitFieldNames ? '' : 'checkboxChecked',
        subBuilder: IconStyle.create)
    ..aOM<IconStyle>(12, _omitFieldNames ? '' : 'checkboxUnchecked',
        subBuilder: IconStyle.create)
    ..aOM<IconStyle>(13, _omitFieldNames ? '' : 'checkboxIndeterminate',
        subBuilder: IconStyle.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  IconSlotStyles clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  IconSlotStyles copyWith(void Function(IconSlotStyles) updates) =>
      super.copyWith((message) => updates(message as IconSlotStyles))
          as IconSlotStyles;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static IconSlotStyles create() => IconSlotStyles._();
  @$core.override
  IconSlotStyles createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static IconSlotStyles getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<IconSlotStyles>(create);
  static IconSlotStyles? _defaultInstance;

  @$pb.TagNumber(1)
  IconStyle get sortAscending => $_getN(0);
  @$pb.TagNumber(1)
  set sortAscending(IconStyle value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasSortAscending() => $_has(0);
  @$pb.TagNumber(1)
  void clearSortAscending() => $_clearField(1);
  @$pb.TagNumber(1)
  IconStyle ensureSortAscending() => $_ensure(0);

  @$pb.TagNumber(2)
  IconStyle get sortDescending => $_getN(1);
  @$pb.TagNumber(2)
  set sortDescending(IconStyle value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasSortDescending() => $_has(1);
  @$pb.TagNumber(2)
  void clearSortDescending() => $_clearField(2);
  @$pb.TagNumber(2)
  IconStyle ensureSortDescending() => $_ensure(1);

  @$pb.TagNumber(3)
  IconStyle get sortNone => $_getN(2);
  @$pb.TagNumber(3)
  set sortNone(IconStyle value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasSortNone() => $_has(2);
  @$pb.TagNumber(3)
  void clearSortNone() => $_clearField(3);
  @$pb.TagNumber(3)
  IconStyle ensureSortNone() => $_ensure(2);

  @$pb.TagNumber(4)
  IconStyle get treeExpanded => $_getN(3);
  @$pb.TagNumber(4)
  set treeExpanded(IconStyle value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasTreeExpanded() => $_has(3);
  @$pb.TagNumber(4)
  void clearTreeExpanded() => $_clearField(4);
  @$pb.TagNumber(4)
  IconStyle ensureTreeExpanded() => $_ensure(3);

  @$pb.TagNumber(5)
  IconStyle get treeCollapsed => $_getN(4);
  @$pb.TagNumber(5)
  set treeCollapsed(IconStyle value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasTreeCollapsed() => $_has(4);
  @$pb.TagNumber(5)
  void clearTreeCollapsed() => $_clearField(5);
  @$pb.TagNumber(5)
  IconStyle ensureTreeCollapsed() => $_ensure(4);

  @$pb.TagNumber(6)
  IconStyle get menu => $_getN(5);
  @$pb.TagNumber(6)
  set menu(IconStyle value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasMenu() => $_has(5);
  @$pb.TagNumber(6)
  void clearMenu() => $_clearField(6);
  @$pb.TagNumber(6)
  IconStyle ensureMenu() => $_ensure(5);

  @$pb.TagNumber(7)
  IconStyle get filter => $_getN(6);
  @$pb.TagNumber(7)
  set filter(IconStyle value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasFilter() => $_has(6);
  @$pb.TagNumber(7)
  void clearFilter() => $_clearField(7);
  @$pb.TagNumber(7)
  IconStyle ensureFilter() => $_ensure(6);

  @$pb.TagNumber(8)
  IconStyle get filterActive => $_getN(7);
  @$pb.TagNumber(8)
  set filterActive(IconStyle value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasFilterActive() => $_has(7);
  @$pb.TagNumber(8)
  void clearFilterActive() => $_clearField(8);
  @$pb.TagNumber(8)
  IconStyle ensureFilterActive() => $_ensure(7);

  @$pb.TagNumber(9)
  IconStyle get columns => $_getN(8);
  @$pb.TagNumber(9)
  set columns(IconStyle value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasColumns() => $_has(8);
  @$pb.TagNumber(9)
  void clearColumns() => $_clearField(9);
  @$pb.TagNumber(9)
  IconStyle ensureColumns() => $_ensure(8);

  @$pb.TagNumber(10)
  IconStyle get dragHandle => $_getN(9);
  @$pb.TagNumber(10)
  set dragHandle(IconStyle value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasDragHandle() => $_has(9);
  @$pb.TagNumber(10)
  void clearDragHandle() => $_clearField(10);
  @$pb.TagNumber(10)
  IconStyle ensureDragHandle() => $_ensure(9);

  @$pb.TagNumber(11)
  IconStyle get checkboxChecked => $_getN(10);
  @$pb.TagNumber(11)
  set checkboxChecked(IconStyle value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasCheckboxChecked() => $_has(10);
  @$pb.TagNumber(11)
  void clearCheckboxChecked() => $_clearField(11);
  @$pb.TagNumber(11)
  IconStyle ensureCheckboxChecked() => $_ensure(10);

  @$pb.TagNumber(12)
  IconStyle get checkboxUnchecked => $_getN(11);
  @$pb.TagNumber(12)
  set checkboxUnchecked(IconStyle value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasCheckboxUnchecked() => $_has(11);
  @$pb.TagNumber(12)
  void clearCheckboxUnchecked() => $_clearField(12);
  @$pb.TagNumber(12)
  IconStyle ensureCheckboxUnchecked() => $_ensure(11);

  @$pb.TagNumber(13)
  IconStyle get checkboxIndeterminate => $_getN(12);
  @$pb.TagNumber(13)
  set checkboxIndeterminate(IconStyle value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasCheckboxIndeterminate() => $_has(12);
  @$pb.TagNumber(13)
  void clearCheckboxIndeterminate() => $_clearField(13);
  @$pb.TagNumber(13)
  IconStyle ensureCheckboxIndeterminate() => $_ensure(12);
}

/// Image-based icon alternatives (PNG/BMP assets).
class IconPictures extends $pb.GeneratedMessage {
  factory IconPictures({
    ImageData? sortAscending,
    ImageData? sortDescending,
    ImageData? nodeOpen,
    ImageData? nodeClosed,
    ImageData? checkboxChecked,
    ImageData? checkboxUnchecked,
    ImageData? checkboxIndeterminate,
  }) {
    final result = create();
    if (sortAscending != null) result.sortAscending = sortAscending;
    if (sortDescending != null) result.sortDescending = sortDescending;
    if (nodeOpen != null) result.nodeOpen = nodeOpen;
    if (nodeClosed != null) result.nodeClosed = nodeClosed;
    if (checkboxChecked != null) result.checkboxChecked = checkboxChecked;
    if (checkboxUnchecked != null) result.checkboxUnchecked = checkboxUnchecked;
    if (checkboxIndeterminate != null)
      result.checkboxIndeterminate = checkboxIndeterminate;
    return result;
  }

  IconPictures._();

  factory IconPictures.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory IconPictures.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'IconPictures',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aOM<ImageData>(1, _omitFieldNames ? '' : 'sortAscending',
        subBuilder: ImageData.create)
    ..aOM<ImageData>(2, _omitFieldNames ? '' : 'sortDescending',
        subBuilder: ImageData.create)
    ..aOM<ImageData>(3, _omitFieldNames ? '' : 'nodeOpen',
        subBuilder: ImageData.create)
    ..aOM<ImageData>(4, _omitFieldNames ? '' : 'nodeClosed',
        subBuilder: ImageData.create)
    ..aOM<ImageData>(5, _omitFieldNames ? '' : 'checkboxChecked',
        subBuilder: ImageData.create)
    ..aOM<ImageData>(6, _omitFieldNames ? '' : 'checkboxUnchecked',
        subBuilder: ImageData.create)
    ..aOM<ImageData>(7, _omitFieldNames ? '' : 'checkboxIndeterminate',
        subBuilder: ImageData.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  IconPictures clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  IconPictures copyWith(void Function(IconPictures) updates) =>
      super.copyWith((message) => updates(message as IconPictures))
          as IconPictures;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static IconPictures create() => IconPictures._();
  @$core.override
  IconPictures createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static IconPictures getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<IconPictures>(create);
  static IconPictures? _defaultInstance;

  @$pb.TagNumber(1)
  ImageData get sortAscending => $_getN(0);
  @$pb.TagNumber(1)
  set sortAscending(ImageData value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasSortAscending() => $_has(0);
  @$pb.TagNumber(1)
  void clearSortAscending() => $_clearField(1);
  @$pb.TagNumber(1)
  ImageData ensureSortAscending() => $_ensure(0);

  @$pb.TagNumber(2)
  ImageData get sortDescending => $_getN(1);
  @$pb.TagNumber(2)
  set sortDescending(ImageData value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasSortDescending() => $_has(1);
  @$pb.TagNumber(2)
  void clearSortDescending() => $_clearField(2);
  @$pb.TagNumber(2)
  ImageData ensureSortDescending() => $_ensure(1);

  @$pb.TagNumber(3)
  ImageData get nodeOpen => $_getN(2);
  @$pb.TagNumber(3)
  set nodeOpen(ImageData value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasNodeOpen() => $_has(2);
  @$pb.TagNumber(3)
  void clearNodeOpen() => $_clearField(3);
  @$pb.TagNumber(3)
  ImageData ensureNodeOpen() => $_ensure(2);

  @$pb.TagNumber(4)
  ImageData get nodeClosed => $_getN(3);
  @$pb.TagNumber(4)
  set nodeClosed(ImageData value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasNodeClosed() => $_has(3);
  @$pb.TagNumber(4)
  void clearNodeClosed() => $_clearField(4);
  @$pb.TagNumber(4)
  ImageData ensureNodeClosed() => $_ensure(3);

  @$pb.TagNumber(5)
  ImageData get checkboxChecked => $_getN(4);
  @$pb.TagNumber(5)
  set checkboxChecked(ImageData value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasCheckboxChecked() => $_has(4);
  @$pb.TagNumber(5)
  void clearCheckboxChecked() => $_clearField(5);
  @$pb.TagNumber(5)
  ImageData ensureCheckboxChecked() => $_ensure(4);

  @$pb.TagNumber(6)
  ImageData get checkboxUnchecked => $_getN(5);
  @$pb.TagNumber(6)
  set checkboxUnchecked(ImageData value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasCheckboxUnchecked() => $_has(5);
  @$pb.TagNumber(6)
  void clearCheckboxUnchecked() => $_clearField(6);
  @$pb.TagNumber(6)
  ImageData ensureCheckboxUnchecked() => $_ensure(5);

  @$pb.TagNumber(7)
  ImageData get checkboxIndeterminate => $_getN(6);
  @$pb.TagNumber(7)
  set checkboxIndeterminate(ImageData value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasCheckboxIndeterminate() => $_has(6);
  @$pb.TagNumber(7)
  void clearCheckboxIndeterminate() => $_clearField(7);
  @$pb.TagNumber(7)
  ImageData ensureCheckboxIndeterminate() => $_ensure(6);
}

class IconTheme extends $pb.GeneratedMessage {
  factory IconTheme({
    IconSlots? slots,
    IconStyle? defaults,
    IconSlotStyles? overrides,
    IconPictures? pictures,
  }) {
    final result = create();
    if (slots != null) result.slots = slots;
    if (defaults != null) result.defaults = defaults;
    if (overrides != null) result.overrides = overrides;
    if (pictures != null) result.pictures = pictures;
    return result;
  }

  IconTheme._();

  factory IconTheme.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory IconTheme.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'IconTheme',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aOM<IconSlots>(1, _omitFieldNames ? '' : 'slots',
        subBuilder: IconSlots.create)
    ..aOM<IconStyle>(2, _omitFieldNames ? '' : 'defaults',
        subBuilder: IconStyle.create)
    ..aOM<IconSlotStyles>(3, _omitFieldNames ? '' : 'overrides',
        subBuilder: IconSlotStyles.create)
    ..aOM<IconPictures>(4, _omitFieldNames ? '' : 'pictures',
        subBuilder: IconPictures.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  IconTheme clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  IconTheme copyWith(void Function(IconTheme) updates) =>
      super.copyWith((message) => updates(message as IconTheme)) as IconTheme;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static IconTheme create() => IconTheme._();
  @$core.override
  IconTheme createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static IconTheme getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<IconTheme>(create);
  static IconTheme? _defaultInstance;

  @$pb.TagNumber(1)
  IconSlots get slots => $_getN(0);
  @$pb.TagNumber(1)
  set slots(IconSlots value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasSlots() => $_has(0);
  @$pb.TagNumber(1)
  void clearSlots() => $_clearField(1);
  @$pb.TagNumber(1)
  IconSlots ensureSlots() => $_ensure(0);

  @$pb.TagNumber(2)
  IconStyle get defaults => $_getN(1);
  @$pb.TagNumber(2)
  set defaults(IconStyle value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasDefaults() => $_has(1);
  @$pb.TagNumber(2)
  void clearDefaults() => $_clearField(2);
  @$pb.TagNumber(2)
  IconStyle ensureDefaults() => $_ensure(1);

  @$pb.TagNumber(3)
  IconSlotStyles get overrides => $_getN(2);
  @$pb.TagNumber(3)
  set overrides(IconSlotStyles value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasOverrides() => $_has(2);
  @$pb.TagNumber(3)
  void clearOverrides() => $_clearField(3);
  @$pb.TagNumber(3)
  IconSlotStyles ensureOverrides() => $_ensure(2);

  @$pb.TagNumber(4)
  IconPictures get pictures => $_getN(3);
  @$pb.TagNumber(4)
  set pictures(IconPictures value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasPictures() => $_has(3);
  @$pb.TagNumber(4)
  void clearPictures() => $_clearField(4);
  @$pb.TagNumber(4)
  IconPictures ensurePictures() => $_ensure(3);
}

class HoverConfig extends $pb.GeneratedMessage {
  factory HoverConfig({
    $core.bool? row,
    $core.bool? column,
    $core.bool? cell,
    HighlightStyle? rowStyle,
    HighlightStyle? columnStyle,
    HighlightStyle? cellStyle,
  }) {
    final result = create();
    if (row != null) result.row = row;
    if (column != null) result.column = column;
    if (cell != null) result.cell = cell;
    if (rowStyle != null) result.rowStyle = rowStyle;
    if (columnStyle != null) result.columnStyle = columnStyle;
    if (cellStyle != null) result.cellStyle = cellStyle;
    return result;
  }

  HoverConfig._();

  factory HoverConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory HoverConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'HoverConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'row')
    ..aOB(2, _omitFieldNames ? '' : 'column')
    ..aOB(3, _omitFieldNames ? '' : 'cell')
    ..aOM<HighlightStyle>(4, _omitFieldNames ? '' : 'rowStyle',
        subBuilder: HighlightStyle.create)
    ..aOM<HighlightStyle>(5, _omitFieldNames ? '' : 'columnStyle',
        subBuilder: HighlightStyle.create)
    ..aOM<HighlightStyle>(6, _omitFieldNames ? '' : 'cellStyle',
        subBuilder: HighlightStyle.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HoverConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HoverConfig copyWith(void Function(HoverConfig) updates) =>
      super.copyWith((message) => updates(message as HoverConfig))
          as HoverConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static HoverConfig create() => HoverConfig._();
  @$core.override
  HoverConfig createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static HoverConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<HoverConfig>(create);
  static HoverConfig? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get row => $_getBF(0);
  @$pb.TagNumber(1)
  set row($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRow() => $_has(0);
  @$pb.TagNumber(1)
  void clearRow() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get column => $_getBF(1);
  @$pb.TagNumber(2)
  set column($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasColumn() => $_has(1);
  @$pb.TagNumber(2)
  void clearColumn() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get cell => $_getBF(2);
  @$pb.TagNumber(3)
  set cell($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCell() => $_has(2);
  @$pb.TagNumber(3)
  void clearCell() => $_clearField(3);

  @$pb.TagNumber(4)
  HighlightStyle get rowStyle => $_getN(3);
  @$pb.TagNumber(4)
  set rowStyle(HighlightStyle value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasRowStyle() => $_has(3);
  @$pb.TagNumber(4)
  void clearRowStyle() => $_clearField(4);
  @$pb.TagNumber(4)
  HighlightStyle ensureRowStyle() => $_ensure(3);

  @$pb.TagNumber(5)
  HighlightStyle get columnStyle => $_getN(4);
  @$pb.TagNumber(5)
  set columnStyle(HighlightStyle value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasColumnStyle() => $_has(4);
  @$pb.TagNumber(5)
  void clearColumnStyle() => $_clearField(5);
  @$pb.TagNumber(5)
  HighlightStyle ensureColumnStyle() => $_ensure(4);

  @$pb.TagNumber(6)
  HighlightStyle get cellStyle => $_getN(5);
  @$pb.TagNumber(6)
  set cellStyle(HighlightStyle value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasCellStyle() => $_has(5);
  @$pb.TagNumber(6)
  void clearCellStyle() => $_clearField(6);
  @$pb.TagNumber(6)
  HighlightStyle ensureCellStyle() => $_ensure(5);
}

class ResizePolicy extends $pb.GeneratedMessage {
  factory ResizePolicy({
    $core.bool? columns,
    $core.bool? rows,
    $core.bool? uniform,
  }) {
    final result = create();
    if (columns != null) result.columns = columns;
    if (rows != null) result.rows = rows;
    if (uniform != null) result.uniform = uniform;
    return result;
  }

  ResizePolicy._();

  factory ResizePolicy.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ResizePolicy.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ResizePolicy',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'columns')
    ..aOB(2, _omitFieldNames ? '' : 'rows')
    ..aOB(3, _omitFieldNames ? '' : 'uniform')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResizePolicy clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResizePolicy copyWith(void Function(ResizePolicy) updates) =>
      super.copyWith((message) => updates(message as ResizePolicy))
          as ResizePolicy;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ResizePolicy create() => ResizePolicy._();
  @$core.override
  ResizePolicy createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ResizePolicy getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ResizePolicy>(create);
  static ResizePolicy? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get columns => $_getBF(0);
  @$pb.TagNumber(1)
  set columns($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasColumns() => $_has(0);
  @$pb.TagNumber(1)
  void clearColumns() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get rows => $_getBF(1);
  @$pb.TagNumber(2)
  set rows($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRows() => $_has(1);
  @$pb.TagNumber(2)
  void clearRows() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get uniform => $_getBF(2);
  @$pb.TagNumber(3)
  set uniform($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasUniform() => $_has(2);
  @$pb.TagNumber(3)
  void clearUniform() => $_clearField(3);
}

class FreezePolicy extends $pb.GeneratedMessage {
  factory FreezePolicy({
    $core.bool? columns,
    $core.bool? rows,
  }) {
    final result = create();
    if (columns != null) result.columns = columns;
    if (rows != null) result.rows = rows;
    return result;
  }

  FreezePolicy._();

  factory FreezePolicy.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory FreezePolicy.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FreezePolicy',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'columns')
    ..aOB(2, _omitFieldNames ? '' : 'rows')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FreezePolicy clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FreezePolicy copyWith(void Function(FreezePolicy) updates) =>
      super.copyWith((message) => updates(message as FreezePolicy))
          as FreezePolicy;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FreezePolicy create() => FreezePolicy._();
  @$core.override
  FreezePolicy createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static FreezePolicy getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FreezePolicy>(create);
  static FreezePolicy? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get columns => $_getBF(0);
  @$pb.TagNumber(1)
  set columns($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasColumns() => $_has(0);
  @$pb.TagNumber(1)
  void clearColumns() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get rows => $_getBF(1);
  @$pb.TagNumber(2)
  set rows($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRows() => $_has(1);
  @$pb.TagNumber(2)
  void clearRows() => $_clearField(2);
}

class HeaderFeatures extends $pb.GeneratedMessage {
  factory HeaderFeatures({
    $core.bool? sort,
    $core.bool? reorder,
    $core.bool? chooser,
  }) {
    final result = create();
    if (sort != null) result.sort = sort;
    if (reorder != null) result.reorder = reorder;
    if (chooser != null) result.chooser = chooser;
    return result;
  }

  HeaderFeatures._();

  factory HeaderFeatures.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory HeaderFeatures.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'HeaderFeatures',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'sort')
    ..aOB(2, _omitFieldNames ? '' : 'reorder')
    ..aOB(3, _omitFieldNames ? '' : 'chooser')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HeaderFeatures clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HeaderFeatures copyWith(void Function(HeaderFeatures) updates) =>
      super.copyWith((message) => updates(message as HeaderFeatures))
          as HeaderFeatures;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static HeaderFeatures create() => HeaderFeatures._();
  @$core.override
  HeaderFeatures createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static HeaderFeatures getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<HeaderFeatures>(create);
  static HeaderFeatures? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get sort => $_getBF(0);
  @$pb.TagNumber(1)
  set sort($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSort() => $_has(0);
  @$pb.TagNumber(1)
  void clearSort() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get reorder => $_getBF(1);
  @$pb.TagNumber(2)
  set reorder($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasReorder() => $_has(1);
  @$pb.TagNumber(2)
  void clearReorder() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get chooser => $_getBF(2);
  @$pb.TagNumber(3)
  set chooser($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasChooser() => $_has(2);
  @$pb.TagNumber(3)
  void clearChooser() => $_clearField(3);
}

class GridConfig extends $pb.GeneratedMessage {
  factory GridConfig({
    LayoutConfig? layout,
    StyleConfig? style,
    SelectionConfig? selection,
    EditConfig? editing,
    ScrollConfig? scrolling,
    OutlineConfig? outline,
    SpanConfig? span,
    InteractionConfig? interaction,
    RenderConfig? rendering,
    $core.String? version,
    IndicatorsConfig? indicators,
  }) {
    final result = create();
    if (layout != null) result.layout = layout;
    if (style != null) result.style = style;
    if (selection != null) result.selection = selection;
    if (editing != null) result.editing = editing;
    if (scrolling != null) result.scrolling = scrolling;
    if (outline != null) result.outline = outline;
    if (span != null) result.span = span;
    if (interaction != null) result.interaction = interaction;
    if (rendering != null) result.rendering = rendering;
    if (version != null) result.version = version;
    if (indicators != null) result.indicators = indicators;
    return result;
  }

  GridConfig._();

  factory GridConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GridConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GridConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aOM<LayoutConfig>(1, _omitFieldNames ? '' : 'layout',
        subBuilder: LayoutConfig.create)
    ..aOM<StyleConfig>(2, _omitFieldNames ? '' : 'style',
        subBuilder: StyleConfig.create)
    ..aOM<SelectionConfig>(3, _omitFieldNames ? '' : 'selection',
        subBuilder: SelectionConfig.create)
    ..aOM<EditConfig>(4, _omitFieldNames ? '' : 'editing',
        subBuilder: EditConfig.create)
    ..aOM<ScrollConfig>(5, _omitFieldNames ? '' : 'scrolling',
        subBuilder: ScrollConfig.create)
    ..aOM<OutlineConfig>(6, _omitFieldNames ? '' : 'outline',
        subBuilder: OutlineConfig.create)
    ..aOM<SpanConfig>(7, _omitFieldNames ? '' : 'span',
        subBuilder: SpanConfig.create)
    ..aOM<InteractionConfig>(8, _omitFieldNames ? '' : 'interaction',
        subBuilder: InteractionConfig.create)
    ..aOM<RenderConfig>(9, _omitFieldNames ? '' : 'rendering',
        subBuilder: RenderConfig.create)
    ..aOS(10, _omitFieldNames ? '' : 'version')
    ..aOM<IndicatorsConfig>(11, _omitFieldNames ? '' : 'indicators',
        subBuilder: IndicatorsConfig.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GridConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GridConfig copyWith(void Function(GridConfig) updates) =>
      super.copyWith((message) => updates(message as GridConfig)) as GridConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GridConfig create() => GridConfig._();
  @$core.override
  GridConfig createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GridConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GridConfig>(create);
  static GridConfig? _defaultInstance;

  @$pb.TagNumber(1)
  LayoutConfig get layout => $_getN(0);
  @$pb.TagNumber(1)
  set layout(LayoutConfig value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasLayout() => $_has(0);
  @$pb.TagNumber(1)
  void clearLayout() => $_clearField(1);
  @$pb.TagNumber(1)
  LayoutConfig ensureLayout() => $_ensure(0);

  @$pb.TagNumber(2)
  StyleConfig get style => $_getN(1);
  @$pb.TagNumber(2)
  set style(StyleConfig value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasStyle() => $_has(1);
  @$pb.TagNumber(2)
  void clearStyle() => $_clearField(2);
  @$pb.TagNumber(2)
  StyleConfig ensureStyle() => $_ensure(1);

  @$pb.TagNumber(3)
  SelectionConfig get selection => $_getN(2);
  @$pb.TagNumber(3)
  set selection(SelectionConfig value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasSelection() => $_has(2);
  @$pb.TagNumber(3)
  void clearSelection() => $_clearField(3);
  @$pb.TagNumber(3)
  SelectionConfig ensureSelection() => $_ensure(2);

  @$pb.TagNumber(4)
  EditConfig get editing => $_getN(3);
  @$pb.TagNumber(4)
  set editing(EditConfig value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasEditing() => $_has(3);
  @$pb.TagNumber(4)
  void clearEditing() => $_clearField(4);
  @$pb.TagNumber(4)
  EditConfig ensureEditing() => $_ensure(3);

  @$pb.TagNumber(5)
  ScrollConfig get scrolling => $_getN(4);
  @$pb.TagNumber(5)
  set scrolling(ScrollConfig value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasScrolling() => $_has(4);
  @$pb.TagNumber(5)
  void clearScrolling() => $_clearField(5);
  @$pb.TagNumber(5)
  ScrollConfig ensureScrolling() => $_ensure(4);

  @$pb.TagNumber(6)
  OutlineConfig get outline => $_getN(5);
  @$pb.TagNumber(6)
  set outline(OutlineConfig value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasOutline() => $_has(5);
  @$pb.TagNumber(6)
  void clearOutline() => $_clearField(6);
  @$pb.TagNumber(6)
  OutlineConfig ensureOutline() => $_ensure(5);

  @$pb.TagNumber(7)
  SpanConfig get span => $_getN(6);
  @$pb.TagNumber(7)
  set span(SpanConfig value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasSpan() => $_has(6);
  @$pb.TagNumber(7)
  void clearSpan() => $_clearField(7);
  @$pb.TagNumber(7)
  SpanConfig ensureSpan() => $_ensure(6);

  @$pb.TagNumber(8)
  InteractionConfig get interaction => $_getN(7);
  @$pb.TagNumber(8)
  set interaction(InteractionConfig value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasInteraction() => $_has(7);
  @$pb.TagNumber(8)
  void clearInteraction() => $_clearField(8);
  @$pb.TagNumber(8)
  InteractionConfig ensureInteraction() => $_ensure(7);

  @$pb.TagNumber(9)
  RenderConfig get rendering => $_getN(8);
  @$pb.TagNumber(9)
  set rendering(RenderConfig value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasRendering() => $_has(8);
  @$pb.TagNumber(9)
  void clearRendering() => $_clearField(9);
  @$pb.TagNumber(9)
  RenderConfig ensureRendering() => $_ensure(8);

  @$pb.TagNumber(10)
  $core.String get version => $_getSZ(9);
  @$pb.TagNumber(10)
  set version($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasVersion() => $_has(9);
  @$pb.TagNumber(10)
  void clearVersion() => $_clearField(10);

  @$pb.TagNumber(11)
  IndicatorsConfig get indicators => $_getN(10);
  @$pb.TagNumber(11)
  set indicators(IndicatorsConfig value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasIndicators() => $_has(10);
  @$pb.TagNumber(11)
  void clearIndicators() => $_clearField(11);
  @$pb.TagNumber(11)
  IndicatorsConfig ensureIndicators() => $_ensure(10);
}

/// ── Layout ──
/// Pure structural dimensions. Text defaults moved to StyleConfig.
class LayoutConfig extends $pb.GeneratedMessage {
  factory LayoutConfig({
    $core.int? rows,
    $core.int? cols,
    $core.int? fixedRows,
    $core.int? fixedCols,
    $core.int? frozenRows,
    $core.int? frozenCols,
    $core.int? defaultRowHeight,
    $core.int? defaultColWidth,
    $core.bool? rightToLeft,
    $core.bool? extendLastCol,
  }) {
    final result = create();
    if (rows != null) result.rows = rows;
    if (cols != null) result.cols = cols;
    if (fixedRows != null) result.fixedRows = fixedRows;
    if (fixedCols != null) result.fixedCols = fixedCols;
    if (frozenRows != null) result.frozenRows = frozenRows;
    if (frozenCols != null) result.frozenCols = frozenCols;
    if (defaultRowHeight != null) result.defaultRowHeight = defaultRowHeight;
    if (defaultColWidth != null) result.defaultColWidth = defaultColWidth;
    if (rightToLeft != null) result.rightToLeft = rightToLeft;
    if (extendLastCol != null) result.extendLastCol = extendLastCol;
    return result;
  }

  LayoutConfig._();

  factory LayoutConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory LayoutConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LayoutConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'rows')
    ..aI(2, _omitFieldNames ? '' : 'cols')
    ..aI(3, _omitFieldNames ? '' : 'fixedRows')
    ..aI(4, _omitFieldNames ? '' : 'fixedCols')
    ..aI(5, _omitFieldNames ? '' : 'frozenRows')
    ..aI(6, _omitFieldNames ? '' : 'frozenCols')
    ..aI(7, _omitFieldNames ? '' : 'defaultRowHeight')
    ..aI(8, _omitFieldNames ? '' : 'defaultColWidth')
    ..aOB(9, _omitFieldNames ? '' : 'rightToLeft')
    ..aOB(10, _omitFieldNames ? '' : 'extendLastCol')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LayoutConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LayoutConfig copyWith(void Function(LayoutConfig) updates) =>
      super.copyWith((message) => updates(message as LayoutConfig))
          as LayoutConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LayoutConfig create() => LayoutConfig._();
  @$core.override
  LayoutConfig createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static LayoutConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LayoutConfig>(create);
  static LayoutConfig? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get rows => $_getIZ(0);
  @$pb.TagNumber(1)
  set rows($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRows() => $_has(0);
  @$pb.TagNumber(1)
  void clearRows() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get cols => $_getIZ(1);
  @$pb.TagNumber(2)
  set cols($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCols() => $_has(1);
  @$pb.TagNumber(2)
  void clearCols() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get fixedRows => $_getIZ(2);
  @$pb.TagNumber(3)
  set fixedRows($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFixedRows() => $_has(2);
  @$pb.TagNumber(3)
  void clearFixedRows() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get fixedCols => $_getIZ(3);
  @$pb.TagNumber(4)
  set fixedCols($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasFixedCols() => $_has(3);
  @$pb.TagNumber(4)
  void clearFixedCols() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get frozenRows => $_getIZ(4);
  @$pb.TagNumber(5)
  set frozenRows($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasFrozenRows() => $_has(4);
  @$pb.TagNumber(5)
  void clearFrozenRows() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get frozenCols => $_getIZ(5);
  @$pb.TagNumber(6)
  set frozenCols($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasFrozenCols() => $_has(5);
  @$pb.TagNumber(6)
  void clearFrozenCols() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get defaultRowHeight => $_getIZ(6);
  @$pb.TagNumber(7)
  set defaultRowHeight($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasDefaultRowHeight() => $_has(6);
  @$pb.TagNumber(7)
  void clearDefaultRowHeight() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get defaultColWidth => $_getIZ(7);
  @$pb.TagNumber(8)
  set defaultColWidth($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasDefaultColWidth() => $_has(7);
  @$pb.TagNumber(8)
  void clearDefaultColWidth() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.bool get rightToLeft => $_getBF(8);
  @$pb.TagNumber(9)
  set rightToLeft($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasRightToLeft() => $_has(8);
  @$pb.TagNumber(9)
  void clearRightToLeft() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.bool get extendLastCol => $_getBF(9);
  @$pb.TagNumber(10)
  set extendLastCol($core.bool value) => $_setBool(9, value);
  @$pb.TagNumber(10)
  $core.bool hasExtendLastCol() => $_has(9);
  @$pb.TagNumber(10)
  void clearExtendLastCol() => $_clearField(10);
}

/// ── Style ──
/// Nested by region. Building blocks eliminate flat field sprawl.
class StyleConfig extends $pb.GeneratedMessage {
  factory StyleConfig({
    $core.int? background,
    $core.int? foreground,
    $core.int? alternateBackground,
    Font? font,
    Padding? cellPadding,
    TextEffect? textEffect,
    $core.int? progressColor,
    GridLines? gridLines,
    RegionStyle? fixed,
    RegionStyle? frozen,
    HeaderStyle? header,
    $core.int? sheetBackground,
    $core.int? sheetBorder,
    BorderAppearance? appearance,
    $core.List<$core.int>? backgroundImage,
    ImageAlignment? backgroundImageAlign,
    TextRendering? textRendering,
    IconTheme? icons,
    $core.bool? imageOverText,
    $core.bool? showSortNumbers,
    ApplyScope? applyScope,
    CustomRenderMode? customRender,
    $core.String? format,
    $core.bool? wordWrap,
    $core.int? ellipsis,
    $core.bool? textOverflow,
  }) {
    final result = create();
    if (background != null) result.background = background;
    if (foreground != null) result.foreground = foreground;
    if (alternateBackground != null)
      result.alternateBackground = alternateBackground;
    if (font != null) result.font = font;
    if (cellPadding != null) result.cellPadding = cellPadding;
    if (textEffect != null) result.textEffect = textEffect;
    if (progressColor != null) result.progressColor = progressColor;
    if (gridLines != null) result.gridLines = gridLines;
    if (fixed != null) result.fixed = fixed;
    if (frozen != null) result.frozen = frozen;
    if (header != null) result.header = header;
    if (sheetBackground != null) result.sheetBackground = sheetBackground;
    if (sheetBorder != null) result.sheetBorder = sheetBorder;
    if (appearance != null) result.appearance = appearance;
    if (backgroundImage != null) result.backgroundImage = backgroundImage;
    if (backgroundImageAlign != null)
      result.backgroundImageAlign = backgroundImageAlign;
    if (textRendering != null) result.textRendering = textRendering;
    if (icons != null) result.icons = icons;
    if (imageOverText != null) result.imageOverText = imageOverText;
    if (showSortNumbers != null) result.showSortNumbers = showSortNumbers;
    if (applyScope != null) result.applyScope = applyScope;
    if (customRender != null) result.customRender = customRender;
    if (format != null) result.format = format;
    if (wordWrap != null) result.wordWrap = wordWrap;
    if (ellipsis != null) result.ellipsis = ellipsis;
    if (textOverflow != null) result.textOverflow = textOverflow;
    return result;
  }

  StyleConfig._();

  factory StyleConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StyleConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StyleConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'background', fieldType: $pb.PbFieldType.OU3)
    ..aI(2, _omitFieldNames ? '' : 'foreground', fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'alternateBackground',
        fieldType: $pb.PbFieldType.OU3)
    ..aOM<Font>(4, _omitFieldNames ? '' : 'font', subBuilder: Font.create)
    ..aOM<Padding>(5, _omitFieldNames ? '' : 'cellPadding',
        subBuilder: Padding.create)
    ..aE<TextEffect>(6, _omitFieldNames ? '' : 'textEffect',
        enumValues: TextEffect.values)
    ..aI(7, _omitFieldNames ? '' : 'progressColor',
        fieldType: $pb.PbFieldType.OU3)
    ..aOM<GridLines>(10, _omitFieldNames ? '' : 'gridLines',
        subBuilder: GridLines.create)
    ..aOM<RegionStyle>(11, _omitFieldNames ? '' : 'fixed',
        subBuilder: RegionStyle.create)
    ..aOM<RegionStyle>(12, _omitFieldNames ? '' : 'frozen',
        subBuilder: RegionStyle.create)
    ..aOM<HeaderStyle>(13, _omitFieldNames ? '' : 'header',
        subBuilder: HeaderStyle.create)
    ..aI(20, _omitFieldNames ? '' : 'sheetBackground',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(21, _omitFieldNames ? '' : 'sheetBorder',
        fieldType: $pb.PbFieldType.OU3)
    ..aE<BorderAppearance>(22, _omitFieldNames ? '' : 'appearance',
        enumValues: BorderAppearance.values)
    ..a<$core.List<$core.int>>(
        23, _omitFieldNames ? '' : 'backgroundImage', $pb.PbFieldType.OY)
    ..aE<ImageAlignment>(24, _omitFieldNames ? '' : 'backgroundImageAlign',
        enumValues: ImageAlignment.values)
    ..aOM<TextRendering>(25, _omitFieldNames ? '' : 'textRendering',
        subBuilder: TextRendering.create)
    ..aOM<IconTheme>(30, _omitFieldNames ? '' : 'icons',
        subBuilder: IconTheme.create)
    ..aOB(31, _omitFieldNames ? '' : 'imageOverText')
    ..aOB(32, _omitFieldNames ? '' : 'showSortNumbers')
    ..aE<ApplyScope>(33, _omitFieldNames ? '' : 'applyScope',
        enumValues: ApplyScope.values)
    ..aE<CustomRenderMode>(34, _omitFieldNames ? '' : 'customRender',
        enumValues: CustomRenderMode.values)
    ..aOS(40, _omitFieldNames ? '' : 'format')
    ..aOB(41, _omitFieldNames ? '' : 'wordWrap')
    ..aI(42, _omitFieldNames ? '' : 'ellipsis')
    ..aOB(43, _omitFieldNames ? '' : 'textOverflow')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StyleConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StyleConfig copyWith(void Function(StyleConfig) updates) =>
      super.copyWith((message) => updates(message as StyleConfig))
          as StyleConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StyleConfig create() => StyleConfig._();
  @$core.override
  StyleConfig createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StyleConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StyleConfig>(create);
  static StyleConfig? _defaultInstance;

  /// Cell defaults
  @$pb.TagNumber(1)
  $core.int get background => $_getIZ(0);
  @$pb.TagNumber(1)
  set background($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBackground() => $_has(0);
  @$pb.TagNumber(1)
  void clearBackground() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get foreground => $_getIZ(1);
  @$pb.TagNumber(2)
  set foreground($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasForeground() => $_has(1);
  @$pb.TagNumber(2)
  void clearForeground() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get alternateBackground => $_getIZ(2);
  @$pb.TagNumber(3)
  set alternateBackground($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAlternateBackground() => $_has(2);
  @$pb.TagNumber(3)
  void clearAlternateBackground() => $_clearField(3);

  @$pb.TagNumber(4)
  Font get font => $_getN(3);
  @$pb.TagNumber(4)
  set font(Font value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasFont() => $_has(3);
  @$pb.TagNumber(4)
  void clearFont() => $_clearField(4);
  @$pb.TagNumber(4)
  Font ensureFont() => $_ensure(3);

  @$pb.TagNumber(5)
  Padding get cellPadding => $_getN(4);
  @$pb.TagNumber(5)
  set cellPadding(Padding value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasCellPadding() => $_has(4);
  @$pb.TagNumber(5)
  void clearCellPadding() => $_clearField(5);
  @$pb.TagNumber(5)
  Padding ensureCellPadding() => $_ensure(4);

  @$pb.TagNumber(6)
  TextEffect get textEffect => $_getN(5);
  @$pb.TagNumber(6)
  set textEffect(TextEffect value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasTextEffect() => $_has(5);
  @$pb.TagNumber(6)
  void clearTextEffect() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get progressColor => $_getIZ(6);
  @$pb.TagNumber(7)
  set progressColor($core.int value) => $_setUnsignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasProgressColor() => $_has(6);
  @$pb.TagNumber(7)
  void clearProgressColor() => $_clearField(7);

  /// Grid lines (scrollable area)
  @$pb.TagNumber(10)
  GridLines get gridLines => $_getN(7);
  @$pb.TagNumber(10)
  set gridLines(GridLines value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasGridLines() => $_has(7);
  @$pb.TagNumber(10)
  void clearGridLines() => $_clearField(10);
  @$pb.TagNumber(10)
  GridLines ensureGridLines() => $_ensure(7);

  /// Region overrides — only set fields override the defaults above
  @$pb.TagNumber(11)
  RegionStyle get fixed => $_getN(8);
  @$pb.TagNumber(11)
  set fixed(RegionStyle value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasFixed() => $_has(8);
  @$pb.TagNumber(11)
  void clearFixed() => $_clearField(11);
  @$pb.TagNumber(11)
  RegionStyle ensureFixed() => $_ensure(8);

  @$pb.TagNumber(12)
  RegionStyle get frozen => $_getN(9);
  @$pb.TagNumber(12)
  set frozen(RegionStyle value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasFrozen() => $_has(9);
  @$pb.TagNumber(12)
  void clearFrozen() => $_clearField(12);
  @$pb.TagNumber(12)
  RegionStyle ensureFrozen() => $_ensure(9);

  /// Header-specific appearance
  @$pb.TagNumber(13)
  HeaderStyle get header => $_getN(10);
  @$pb.TagNumber(13)
  set header(HeaderStyle value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasHeader() => $_has(10);
  @$pb.TagNumber(13)
  void clearHeader() => $_clearField(13);
  @$pb.TagNumber(13)
  HeaderStyle ensureHeader() => $_ensure(10);

  /// Sheet-level
  @$pb.TagNumber(20)
  $core.int get sheetBackground => $_getIZ(11);
  @$pb.TagNumber(20)
  set sheetBackground($core.int value) => $_setUnsignedInt32(11, value);
  @$pb.TagNumber(20)
  $core.bool hasSheetBackground() => $_has(11);
  @$pb.TagNumber(20)
  void clearSheetBackground() => $_clearField(20);

  @$pb.TagNumber(21)
  $core.int get sheetBorder => $_getIZ(12);
  @$pb.TagNumber(21)
  set sheetBorder($core.int value) => $_setUnsignedInt32(12, value);
  @$pb.TagNumber(21)
  $core.bool hasSheetBorder() => $_has(12);
  @$pb.TagNumber(21)
  void clearSheetBorder() => $_clearField(21);

  @$pb.TagNumber(22)
  BorderAppearance get appearance => $_getN(13);
  @$pb.TagNumber(22)
  set appearance(BorderAppearance value) => $_setField(22, value);
  @$pb.TagNumber(22)
  $core.bool hasAppearance() => $_has(13);
  @$pb.TagNumber(22)
  void clearAppearance() => $_clearField(22);

  /// Background image
  @$pb.TagNumber(23)
  $core.List<$core.int> get backgroundImage => $_getN(14);
  @$pb.TagNumber(23)
  set backgroundImage($core.List<$core.int> value) => $_setBytes(14, value);
  @$pb.TagNumber(23)
  $core.bool hasBackgroundImage() => $_has(14);
  @$pb.TagNumber(23)
  void clearBackgroundImage() => $_clearField(23);

  @$pb.TagNumber(24)
  ImageAlignment get backgroundImageAlign => $_getN(15);
  @$pb.TagNumber(24)
  set backgroundImageAlign(ImageAlignment value) => $_setField(24, value);
  @$pb.TagNumber(24)
  $core.bool hasBackgroundImageAlign() => $_has(15);
  @$pb.TagNumber(24)
  void clearBackgroundImageAlign() => $_clearField(24);

  /// Text rendering
  @$pb.TagNumber(25)
  TextRendering get textRendering => $_getN(16);
  @$pb.TagNumber(25)
  set textRendering(TextRendering value) => $_setField(25, value);
  @$pb.TagNumber(25)
  $core.bool hasTextRendering() => $_has(16);
  @$pb.TagNumber(25)
  void clearTextRendering() => $_clearField(25);
  @$pb.TagNumber(25)
  TextRendering ensureTextRendering() => $_ensure(16);

  /// Icons
  @$pb.TagNumber(30)
  IconTheme get icons => $_getN(17);
  @$pb.TagNumber(30)
  set icons(IconTheme value) => $_setField(30, value);
  @$pb.TagNumber(30)
  $core.bool hasIcons() => $_has(17);
  @$pb.TagNumber(30)
  void clearIcons() => $_clearField(30);
  @$pb.TagNumber(30)
  IconTheme ensureIcons() => $_ensure(17);

  /// Rendering options
  @$pb.TagNumber(31)
  $core.bool get imageOverText => $_getBF(18);
  @$pb.TagNumber(31)
  set imageOverText($core.bool value) => $_setBool(18, value);
  @$pb.TagNumber(31)
  $core.bool hasImageOverText() => $_has(18);
  @$pb.TagNumber(31)
  void clearImageOverText() => $_clearField(31);

  @$pb.TagNumber(32)
  $core.bool get showSortNumbers => $_getBF(19);
  @$pb.TagNumber(32)
  set showSortNumbers($core.bool value) => $_setBool(19, value);
  @$pb.TagNumber(32)
  $core.bool hasShowSortNumbers() => $_has(19);
  @$pb.TagNumber(32)
  void clearShowSortNumbers() => $_clearField(32);

  @$pb.TagNumber(33)
  ApplyScope get applyScope => $_getN(20);
  @$pb.TagNumber(33)
  set applyScope(ApplyScope value) => $_setField(33, value);
  @$pb.TagNumber(33)
  $core.bool hasApplyScope() => $_has(20);
  @$pb.TagNumber(33)
  void clearApplyScope() => $_clearField(33);

  @$pb.TagNumber(34)
  CustomRenderMode get customRender => $_getN(21);
  @$pb.TagNumber(34)
  set customRender(CustomRenderMode value) => $_setField(34, value);
  @$pb.TagNumber(34)
  $core.bool hasCustomRender() => $_has(21);
  @$pb.TagNumber(34)
  void clearCustomRender() => $_clearField(34);

  /// Default cell text behavior (moved from LayoutConfig)
  @$pb.TagNumber(40)
  $core.String get format => $_getSZ(22);
  @$pb.TagNumber(40)
  set format($core.String value) => $_setString(22, value);
  @$pb.TagNumber(40)
  $core.bool hasFormat() => $_has(22);
  @$pb.TagNumber(40)
  void clearFormat() => $_clearField(40);

  @$pb.TagNumber(41)
  $core.bool get wordWrap => $_getBF(23);
  @$pb.TagNumber(41)
  set wordWrap($core.bool value) => $_setBool(23, value);
  @$pb.TagNumber(41)
  $core.bool hasWordWrap() => $_has(23);
  @$pb.TagNumber(41)
  void clearWordWrap() => $_clearField(41);

  @$pb.TagNumber(42)
  $core.int get ellipsis => $_getIZ(24);
  @$pb.TagNumber(42)
  set ellipsis($core.int value) => $_setSignedInt32(24, value);
  @$pb.TagNumber(42)
  $core.bool hasEllipsis() => $_has(24);
  @$pb.TagNumber(42)
  void clearEllipsis() => $_clearField(42);

  @$pb.TagNumber(43)
  $core.bool get textOverflow => $_getBF(25);
  @$pb.TagNumber(43)
  set textOverflow($core.bool value) => $_setBool(25, value);
  @$pb.TagNumber(43)
  $core.bool hasTextOverflow() => $_has(25);
  @$pb.TagNumber(43)
  void clearTextOverflow() => $_clearField(43);
}

/// ── Selection ──
class SelectionConfig extends $pb.GeneratedMessage {
  factory SelectionConfig({
    SelectionMode? mode,
    FocusBorderStyle? focusBorder,
    SelectionVisibility? visibility,
    $core.bool? allow,
    $core.bool? headerClickSelect,
    HighlightStyle? style,
    HoverConfig? hover,
    HighlightStyle? indicatorRowStyle,
    HighlightStyle? indicatorColStyle,
    HighlightStyle? activeCellStyle,
  }) {
    final result = create();
    if (mode != null) result.mode = mode;
    if (focusBorder != null) result.focusBorder = focusBorder;
    if (visibility != null) result.visibility = visibility;
    if (allow != null) result.allow = allow;
    if (headerClickSelect != null) result.headerClickSelect = headerClickSelect;
    if (style != null) result.style = style;
    if (hover != null) result.hover = hover;
    if (indicatorRowStyle != null) result.indicatorRowStyle = indicatorRowStyle;
    if (indicatorColStyle != null) result.indicatorColStyle = indicatorColStyle;
    if (activeCellStyle != null) result.activeCellStyle = activeCellStyle;
    return result;
  }

  SelectionConfig._();

  factory SelectionConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SelectionConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SelectionConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aE<SelectionMode>(1, _omitFieldNames ? '' : 'mode',
        enumValues: SelectionMode.values)
    ..aE<FocusBorderStyle>(2, _omitFieldNames ? '' : 'focusBorder',
        enumValues: FocusBorderStyle.values)
    ..aE<SelectionVisibility>(3, _omitFieldNames ? '' : 'visibility',
        enumValues: SelectionVisibility.values)
    ..aOB(4, _omitFieldNames ? '' : 'allow')
    ..aOB(5, _omitFieldNames ? '' : 'headerClickSelect')
    ..aOM<HighlightStyle>(6, _omitFieldNames ? '' : 'style',
        subBuilder: HighlightStyle.create)
    ..aOM<HoverConfig>(7, _omitFieldNames ? '' : 'hover',
        subBuilder: HoverConfig.create)
    ..aOM<HighlightStyle>(8, _omitFieldNames ? '' : 'indicatorRowStyle',
        subBuilder: HighlightStyle.create)
    ..aOM<HighlightStyle>(9, _omitFieldNames ? '' : 'indicatorColStyle',
        subBuilder: HighlightStyle.create)
    ..aOM<HighlightStyle>(10, _omitFieldNames ? '' : 'activeCellStyle',
        subBuilder: HighlightStyle.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SelectionConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SelectionConfig copyWith(void Function(SelectionConfig) updates) =>
      super.copyWith((message) => updates(message as SelectionConfig))
          as SelectionConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SelectionConfig create() => SelectionConfig._();
  @$core.override
  SelectionConfig createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SelectionConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SelectionConfig>(create);
  static SelectionConfig? _defaultInstance;

  @$pb.TagNumber(1)
  SelectionMode get mode => $_getN(0);
  @$pb.TagNumber(1)
  set mode(SelectionMode value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasMode() => $_has(0);
  @$pb.TagNumber(1)
  void clearMode() => $_clearField(1);

  @$pb.TagNumber(2)
  FocusBorderStyle get focusBorder => $_getN(1);
  @$pb.TagNumber(2)
  set focusBorder(FocusBorderStyle value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasFocusBorder() => $_has(1);
  @$pb.TagNumber(2)
  void clearFocusBorder() => $_clearField(2);

  @$pb.TagNumber(3)
  SelectionVisibility get visibility => $_getN(2);
  @$pb.TagNumber(3)
  set visibility(SelectionVisibility value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasVisibility() => $_has(2);
  @$pb.TagNumber(3)
  void clearVisibility() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get allow => $_getBF(3);
  @$pb.TagNumber(4)
  set allow($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAllow() => $_has(3);
  @$pb.TagNumber(4)
  void clearAllow() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get headerClickSelect => $_getBF(4);
  @$pb.TagNumber(5)
  set headerClickSelect($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasHeaderClickSelect() => $_has(4);
  @$pb.TagNumber(5)
  void clearHeaderClickSelect() => $_clearField(5);

  @$pb.TagNumber(6)
  HighlightStyle get style => $_getN(5);
  @$pb.TagNumber(6)
  set style(HighlightStyle value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasStyle() => $_has(5);
  @$pb.TagNumber(6)
  void clearStyle() => $_clearField(6);
  @$pb.TagNumber(6)
  HighlightStyle ensureStyle() => $_ensure(5);

  @$pb.TagNumber(7)
  HoverConfig get hover => $_getN(6);
  @$pb.TagNumber(7)
  set hover(HoverConfig value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasHover() => $_has(6);
  @$pb.TagNumber(7)
  void clearHover() => $_clearField(7);
  @$pb.TagNumber(7)
  HoverConfig ensureHover() => $_ensure(6);

  @$pb.TagNumber(8)
  HighlightStyle get indicatorRowStyle => $_getN(7);
  @$pb.TagNumber(8)
  set indicatorRowStyle(HighlightStyle value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasIndicatorRowStyle() => $_has(7);
  @$pb.TagNumber(8)
  void clearIndicatorRowStyle() => $_clearField(8);
  @$pb.TagNumber(8)
  HighlightStyle ensureIndicatorRowStyle() => $_ensure(7);

  @$pb.TagNumber(9)
  HighlightStyle get indicatorColStyle => $_getN(8);
  @$pb.TagNumber(9)
  set indicatorColStyle(HighlightStyle value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasIndicatorColStyle() => $_has(8);
  @$pb.TagNumber(9)
  void clearIndicatorColStyle() => $_clearField(9);
  @$pb.TagNumber(9)
  HighlightStyle ensureIndicatorColStyle() => $_ensure(8);

  @$pb.TagNumber(10)
  HighlightStyle get activeCellStyle => $_getN(9);
  @$pb.TagNumber(10)
  set activeCellStyle(HighlightStyle value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasActiveCellStyle() => $_has(9);
  @$pb.TagNumber(10)
  void clearActiveCellStyle() => $_clearField(10);
  @$pb.TagNumber(10)
  HighlightStyle ensureActiveCellStyle() => $_ensure(9);
}

/// ── Editing ──
class EditConfig extends $pb.GeneratedMessage {
  factory EditConfig({
    EditTrigger? trigger,
    TabBehavior? tabBehavior,
    DropdownTrigger? dropdownTrigger,
    $core.bool? dropdownSearch,
    $core.int? maxLength,
    $core.String? mask,
    $core.bool? hostKeyDispatch,
    $core.bool? hostPointerDispatch,
  }) {
    final result = create();
    if (trigger != null) result.trigger = trigger;
    if (tabBehavior != null) result.tabBehavior = tabBehavior;
    if (dropdownTrigger != null) result.dropdownTrigger = dropdownTrigger;
    if (dropdownSearch != null) result.dropdownSearch = dropdownSearch;
    if (maxLength != null) result.maxLength = maxLength;
    if (mask != null) result.mask = mask;
    if (hostKeyDispatch != null) result.hostKeyDispatch = hostKeyDispatch;
    if (hostPointerDispatch != null)
      result.hostPointerDispatch = hostPointerDispatch;
    return result;
  }

  EditConfig._();

  factory EditConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory EditConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EditConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aE<EditTrigger>(1, _omitFieldNames ? '' : 'trigger',
        enumValues: EditTrigger.values)
    ..aE<TabBehavior>(2, _omitFieldNames ? '' : 'tabBehavior',
        enumValues: TabBehavior.values)
    ..aE<DropdownTrigger>(3, _omitFieldNames ? '' : 'dropdownTrigger',
        enumValues: DropdownTrigger.values)
    ..aOB(4, _omitFieldNames ? '' : 'dropdownSearch')
    ..aI(5, _omitFieldNames ? '' : 'maxLength')
    ..aOS(6, _omitFieldNames ? '' : 'mask')
    ..aOB(7, _omitFieldNames ? '' : 'hostKeyDispatch')
    ..aOB(8, _omitFieldNames ? '' : 'hostPointerDispatch')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EditConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EditConfig copyWith(void Function(EditConfig) updates) =>
      super.copyWith((message) => updates(message as EditConfig)) as EditConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EditConfig create() => EditConfig._();
  @$core.override
  EditConfig createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static EditConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EditConfig>(create);
  static EditConfig? _defaultInstance;

  @$pb.TagNumber(1)
  EditTrigger get trigger => $_getN(0);
  @$pb.TagNumber(1)
  set trigger(EditTrigger value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasTrigger() => $_has(0);
  @$pb.TagNumber(1)
  void clearTrigger() => $_clearField(1);

  @$pb.TagNumber(2)
  TabBehavior get tabBehavior => $_getN(1);
  @$pb.TagNumber(2)
  set tabBehavior(TabBehavior value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasTabBehavior() => $_has(1);
  @$pb.TagNumber(2)
  void clearTabBehavior() => $_clearField(2);

  @$pb.TagNumber(3)
  DropdownTrigger get dropdownTrigger => $_getN(2);
  @$pb.TagNumber(3)
  set dropdownTrigger(DropdownTrigger value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasDropdownTrigger() => $_has(2);
  @$pb.TagNumber(3)
  void clearDropdownTrigger() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get dropdownSearch => $_getBF(3);
  @$pb.TagNumber(4)
  set dropdownSearch($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDropdownSearch() => $_has(3);
  @$pb.TagNumber(4)
  void clearDropdownSearch() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get maxLength => $_getIZ(4);
  @$pb.TagNumber(5)
  set maxLength($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasMaxLength() => $_has(4);
  @$pb.TagNumber(5)
  void clearMaxLength() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get mask => $_getSZ(5);
  @$pb.TagNumber(6)
  set mask($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasMask() => $_has(5);
  @$pb.TagNumber(6)
  void clearMask() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.bool get hostKeyDispatch => $_getBF(6);
  @$pb.TagNumber(7)
  set hostKeyDispatch($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasHostKeyDispatch() => $_has(6);
  @$pb.TagNumber(7)
  void clearHostKeyDispatch() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.bool get hostPointerDispatch => $_getBF(7);
  @$pb.TagNumber(8)
  set hostPointerDispatch($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasHostPointerDispatch() => $_has(7);
  @$pb.TagNumber(8)
  void clearHostPointerDispatch() => $_clearField(8);
}

class PullToRefreshConfig extends $pb.GeneratedMessage {
  factory PullToRefreshConfig({
    $core.bool? enabled,
    PullToRefreshTheme? theme,
    $core.String? textPull,
    $core.String? textRelease,
  }) {
    final result = create();
    if (enabled != null) result.enabled = enabled;
    if (theme != null) result.theme = theme;
    if (textPull != null) result.textPull = textPull;
    if (textRelease != null) result.textRelease = textRelease;
    return result;
  }

  PullToRefreshConfig._();

  factory PullToRefreshConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PullToRefreshConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PullToRefreshConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'enabled')
    ..aE<PullToRefreshTheme>(2, _omitFieldNames ? '' : 'theme',
        enumValues: PullToRefreshTheme.values)
    ..aOS(3, _omitFieldNames ? '' : 'textPull')
    ..aOS(4, _omitFieldNames ? '' : 'textRelease')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PullToRefreshConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PullToRefreshConfig copyWith(void Function(PullToRefreshConfig) updates) =>
      super.copyWith((message) => updates(message as PullToRefreshConfig))
          as PullToRefreshConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PullToRefreshConfig create() => PullToRefreshConfig._();
  @$core.override
  PullToRefreshConfig createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PullToRefreshConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PullToRefreshConfig>(create);
  static PullToRefreshConfig? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get enabled => $_getBF(0);
  @$pb.TagNumber(1)
  set enabled($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEnabled() => $_has(0);
  @$pb.TagNumber(1)
  void clearEnabled() => $_clearField(1);

  @$pb.TagNumber(2)
  PullToRefreshTheme get theme => $_getN(1);
  @$pb.TagNumber(2)
  set theme(PullToRefreshTheme value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasTheme() => $_has(1);
  @$pb.TagNumber(2)
  void clearTheme() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get textPull => $_getSZ(2);
  @$pb.TagNumber(3)
  set textPull($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTextPull() => $_has(2);
  @$pb.TagNumber(3)
  void clearTextPull() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get textRelease => $_getSZ(3);
  @$pb.TagNumber(4)
  set textRelease($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTextRelease() => $_has(3);
  @$pb.TagNumber(4)
  void clearTextRelease() => $_clearField(4);
}

class ScrollConfig extends $pb.GeneratedMessage {
  factory ScrollConfig({
    ScrollBarConfig? scrollBar,
    $core.bool? scrollTrack,
    $core.bool? scrollTips,
    $core.bool? flingEnabled,
    $core.double? flingImpulseGain,
    $core.double? flingFriction,
    $core.bool? pinchZoomEnabled,
    $core.bool? fastScroll,
    ScrollBarsMode? scrollbars,
    PullToRefreshConfig? pullToRefresh,
  }) {
    final result = create();
    if (scrollBar != null) result.scrollBar = scrollBar;
    if (scrollTrack != null) result.scrollTrack = scrollTrack;
    if (scrollTips != null) result.scrollTips = scrollTips;
    if (flingEnabled != null) result.flingEnabled = flingEnabled;
    if (flingImpulseGain != null) result.flingImpulseGain = flingImpulseGain;
    if (flingFriction != null) result.flingFriction = flingFriction;
    if (pinchZoomEnabled != null) result.pinchZoomEnabled = pinchZoomEnabled;
    if (fastScroll != null) result.fastScroll = fastScroll;
    if (scrollbars != null) result.scrollbars = scrollbars;
    if (pullToRefresh != null) result.pullToRefresh = pullToRefresh;
    return result;
  }

  ScrollConfig._();

  factory ScrollConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ScrollConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ScrollConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aOM<ScrollBarConfig>(1, _omitFieldNames ? '' : 'scrollBar',
        subBuilder: ScrollBarConfig.create)
    ..aOB(2, _omitFieldNames ? '' : 'scrollTrack')
    ..aOB(3, _omitFieldNames ? '' : 'scrollTips')
    ..aOB(4, _omitFieldNames ? '' : 'flingEnabled')
    ..aD(5, _omitFieldNames ? '' : 'flingImpulseGain',
        fieldType: $pb.PbFieldType.OF)
    ..aD(6, _omitFieldNames ? '' : 'flingFriction',
        fieldType: $pb.PbFieldType.OF)
    ..aOB(7, _omitFieldNames ? '' : 'pinchZoomEnabled')
    ..aOB(8, _omitFieldNames ? '' : 'fastScroll')
    ..aE<ScrollBarsMode>(9, _omitFieldNames ? '' : 'scrollbars',
        enumValues: ScrollBarsMode.values)
    ..aOM<PullToRefreshConfig>(10, _omitFieldNames ? '' : 'pullToRefresh',
        subBuilder: PullToRefreshConfig.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ScrollConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ScrollConfig copyWith(void Function(ScrollConfig) updates) =>
      super.copyWith((message) => updates(message as ScrollConfig))
          as ScrollConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ScrollConfig create() => ScrollConfig._();
  @$core.override
  ScrollConfig createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ScrollConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ScrollConfig>(create);
  static ScrollConfig? _defaultInstance;

  @$pb.TagNumber(1)
  ScrollBarConfig get scrollBar => $_getN(0);
  @$pb.TagNumber(1)
  set scrollBar(ScrollBarConfig value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasScrollBar() => $_has(0);
  @$pb.TagNumber(1)
  void clearScrollBar() => $_clearField(1);
  @$pb.TagNumber(1)
  ScrollBarConfig ensureScrollBar() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.bool get scrollTrack => $_getBF(1);
  @$pb.TagNumber(2)
  set scrollTrack($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasScrollTrack() => $_has(1);
  @$pb.TagNumber(2)
  void clearScrollTrack() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get scrollTips => $_getBF(2);
  @$pb.TagNumber(3)
  set scrollTips($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasScrollTips() => $_has(2);
  @$pb.TagNumber(3)
  void clearScrollTips() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get flingEnabled => $_getBF(3);
  @$pb.TagNumber(4)
  set flingEnabled($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasFlingEnabled() => $_has(3);
  @$pb.TagNumber(4)
  void clearFlingEnabled() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.double get flingImpulseGain => $_getN(4);
  @$pb.TagNumber(5)
  set flingImpulseGain($core.double value) => $_setFloat(4, value);
  @$pb.TagNumber(5)
  $core.bool hasFlingImpulseGain() => $_has(4);
  @$pb.TagNumber(5)
  void clearFlingImpulseGain() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.double get flingFriction => $_getN(5);
  @$pb.TagNumber(6)
  set flingFriction($core.double value) => $_setFloat(5, value);
  @$pb.TagNumber(6)
  $core.bool hasFlingFriction() => $_has(5);
  @$pb.TagNumber(6)
  void clearFlingFriction() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.bool get pinchZoomEnabled => $_getBF(6);
  @$pb.TagNumber(7)
  set pinchZoomEnabled($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasPinchZoomEnabled() => $_has(6);
  @$pb.TagNumber(7)
  void clearPinchZoomEnabled() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.bool get fastScroll => $_getBF(7);
  @$pb.TagNumber(8)
  set fastScroll($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasFastScroll() => $_has(7);
  @$pb.TagNumber(8)
  void clearFastScroll() => $_clearField(8);

  @$pb.TagNumber(9)
  ScrollBarsMode get scrollbars => $_getN(8);
  @$pb.TagNumber(9)
  set scrollbars(ScrollBarsMode value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasScrollbars() => $_has(8);
  @$pb.TagNumber(9)
  void clearScrollbars() => $_clearField(9);

  @$pb.TagNumber(10)
  PullToRefreshConfig get pullToRefresh => $_getN(9);
  @$pb.TagNumber(10)
  set pullToRefresh(PullToRefreshConfig value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasPullToRefresh() => $_has(9);
  @$pb.TagNumber(10)
  void clearPullToRefresh() => $_clearField(10);
  @$pb.TagNumber(10)
  PullToRefreshConfig ensurePullToRefresh() => $_ensure(9);
}

/// ── Outline / Tree ──
class OutlineConfig extends $pb.GeneratedMessage {
  factory OutlineConfig({
    TreeIndicatorStyle? treeIndicator,
    $core.int? treeColumn,
    $core.int? treeColor,
    GroupTotalPosition? groupTotalPosition,
    $core.bool? multiTotals,
  }) {
    final result = create();
    if (treeIndicator != null) result.treeIndicator = treeIndicator;
    if (treeColumn != null) result.treeColumn = treeColumn;
    if (treeColor != null) result.treeColor = treeColor;
    if (groupTotalPosition != null)
      result.groupTotalPosition = groupTotalPosition;
    if (multiTotals != null) result.multiTotals = multiTotals;
    return result;
  }

  OutlineConfig._();

  factory OutlineConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory OutlineConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'OutlineConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aE<TreeIndicatorStyle>(1, _omitFieldNames ? '' : 'treeIndicator',
        enumValues: TreeIndicatorStyle.values)
    ..aI(2, _omitFieldNames ? '' : 'treeColumn')
    ..aI(3, _omitFieldNames ? '' : 'treeColor', fieldType: $pb.PbFieldType.OU3)
    ..aE<GroupTotalPosition>(4, _omitFieldNames ? '' : 'groupTotalPosition',
        enumValues: GroupTotalPosition.values)
    ..aOB(5, _omitFieldNames ? '' : 'multiTotals')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OutlineConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OutlineConfig copyWith(void Function(OutlineConfig) updates) =>
      super.copyWith((message) => updates(message as OutlineConfig))
          as OutlineConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static OutlineConfig create() => OutlineConfig._();
  @$core.override
  OutlineConfig createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static OutlineConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<OutlineConfig>(create);
  static OutlineConfig? _defaultInstance;

  @$pb.TagNumber(1)
  TreeIndicatorStyle get treeIndicator => $_getN(0);
  @$pb.TagNumber(1)
  set treeIndicator(TreeIndicatorStyle value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasTreeIndicator() => $_has(0);
  @$pb.TagNumber(1)
  void clearTreeIndicator() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get treeColumn => $_getIZ(1);
  @$pb.TagNumber(2)
  set treeColumn($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTreeColumn() => $_has(1);
  @$pb.TagNumber(2)
  void clearTreeColumn() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get treeColor => $_getIZ(2);
  @$pb.TagNumber(3)
  set treeColor($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTreeColor() => $_has(2);
  @$pb.TagNumber(3)
  void clearTreeColor() => $_clearField(3);

  @$pb.TagNumber(4)
  GroupTotalPosition get groupTotalPosition => $_getN(3);
  @$pb.TagNumber(4)
  set groupTotalPosition(GroupTotalPosition value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasGroupTotalPosition() => $_has(3);
  @$pb.TagNumber(4)
  void clearGroupTotalPosition() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get multiTotals => $_getBF(4);
  @$pb.TagNumber(5)
  set multiTotals($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasMultiTotals() => $_has(4);
  @$pb.TagNumber(5)
  void clearMultiTotals() => $_clearField(5);
}

/// ── Cell Span ──
class SpanConfig extends $pb.GeneratedMessage {
  factory SpanConfig({
    CellSpanMode? cellSpan,
    CellSpanMode? cellSpanFixed,
    $core.int? cellSpanCompare,
    $core.int? groupSpanCompare,
  }) {
    final result = create();
    if (cellSpan != null) result.cellSpan = cellSpan;
    if (cellSpanFixed != null) result.cellSpanFixed = cellSpanFixed;
    if (cellSpanCompare != null) result.cellSpanCompare = cellSpanCompare;
    if (groupSpanCompare != null) result.groupSpanCompare = groupSpanCompare;
    return result;
  }

  SpanConfig._();

  factory SpanConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SpanConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SpanConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aE<CellSpanMode>(1, _omitFieldNames ? '' : 'cellSpan',
        enumValues: CellSpanMode.values)
    ..aE<CellSpanMode>(2, _omitFieldNames ? '' : 'cellSpanFixed',
        enumValues: CellSpanMode.values)
    ..aI(3, _omitFieldNames ? '' : 'cellSpanCompare')
    ..aI(4, _omitFieldNames ? '' : 'groupSpanCompare')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SpanConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SpanConfig copyWith(void Function(SpanConfig) updates) =>
      super.copyWith((message) => updates(message as SpanConfig)) as SpanConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SpanConfig create() => SpanConfig._();
  @$core.override
  SpanConfig createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SpanConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SpanConfig>(create);
  static SpanConfig? _defaultInstance;

  @$pb.TagNumber(1)
  CellSpanMode get cellSpan => $_getN(0);
  @$pb.TagNumber(1)
  set cellSpan(CellSpanMode value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasCellSpan() => $_has(0);
  @$pb.TagNumber(1)
  void clearCellSpan() => $_clearField(1);

  @$pb.TagNumber(2)
  CellSpanMode get cellSpanFixed => $_getN(1);
  @$pb.TagNumber(2)
  set cellSpanFixed(CellSpanMode value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasCellSpanFixed() => $_has(1);
  @$pb.TagNumber(2)
  void clearCellSpanFixed() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get cellSpanCompare => $_getIZ(2);
  @$pb.TagNumber(3)
  set cellSpanCompare($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCellSpanCompare() => $_has(2);
  @$pb.TagNumber(3)
  void clearCellSpanCompare() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get groupSpanCompare => $_getIZ(3);
  @$pb.TagNumber(4)
  set groupSpanCompare($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasGroupSpanCompare() => $_has(3);
  @$pb.TagNumber(4)
  void clearGroupSpanCompare() => $_clearField(4);
}

/// ── Interaction ──
class InteractionConfig extends $pb.GeneratedMessage {
  factory InteractionConfig({
    ResizePolicy? resize,
    FreezePolicy? freeze_2,
    TypeAheadMode? typeAhead,
    $core.int? typeAheadDelay,
    $core.bool? autoSizeMouse,
    AutoSizeMode? autoSizeMode,
    $core.bool? autoResize,
    DragMode? dragMode,
    DropMode? dropMode,
    HeaderFeatures? headerFeatures,
  }) {
    final result = create();
    if (resize != null) result.resize = resize;
    if (freeze_2 != null) result.freeze_2 = freeze_2;
    if (typeAhead != null) result.typeAhead = typeAhead;
    if (typeAheadDelay != null) result.typeAheadDelay = typeAheadDelay;
    if (autoSizeMouse != null) result.autoSizeMouse = autoSizeMouse;
    if (autoSizeMode != null) result.autoSizeMode = autoSizeMode;
    if (autoResize != null) result.autoResize = autoResize;
    if (dragMode != null) result.dragMode = dragMode;
    if (dropMode != null) result.dropMode = dropMode;
    if (headerFeatures != null) result.headerFeatures = headerFeatures;
    return result;
  }

  InteractionConfig._();

  factory InteractionConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory InteractionConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'InteractionConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aOM<ResizePolicy>(1, _omitFieldNames ? '' : 'resize',
        subBuilder: ResizePolicy.create)
    ..aOM<FreezePolicy>(2, _omitFieldNames ? '' : 'freeze',
        subBuilder: FreezePolicy.create)
    ..aE<TypeAheadMode>(3, _omitFieldNames ? '' : 'typeAhead',
        enumValues: TypeAheadMode.values)
    ..aI(4, _omitFieldNames ? '' : 'typeAheadDelay')
    ..aOB(5, _omitFieldNames ? '' : 'autoSizeMouse')
    ..aE<AutoSizeMode>(6, _omitFieldNames ? '' : 'autoSizeMode',
        enumValues: AutoSizeMode.values)
    ..aOB(7, _omitFieldNames ? '' : 'autoResize')
    ..aE<DragMode>(8, _omitFieldNames ? '' : 'dragMode',
        enumValues: DragMode.values)
    ..aE<DropMode>(9, _omitFieldNames ? '' : 'dropMode',
        enumValues: DropMode.values)
    ..aOM<HeaderFeatures>(10, _omitFieldNames ? '' : 'headerFeatures',
        subBuilder: HeaderFeatures.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  InteractionConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  InteractionConfig copyWith(void Function(InteractionConfig) updates) =>
      super.copyWith((message) => updates(message as InteractionConfig))
          as InteractionConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static InteractionConfig create() => InteractionConfig._();
  @$core.override
  InteractionConfig createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static InteractionConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<InteractionConfig>(create);
  static InteractionConfig? _defaultInstance;

  @$pb.TagNumber(1)
  ResizePolicy get resize => $_getN(0);
  @$pb.TagNumber(1)
  set resize(ResizePolicy value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasResize() => $_has(0);
  @$pb.TagNumber(1)
  void clearResize() => $_clearField(1);
  @$pb.TagNumber(1)
  ResizePolicy ensureResize() => $_ensure(0);

  @$pb.TagNumber(2)
  FreezePolicy get freeze_2 => $_getN(1);
  @$pb.TagNumber(2)
  set freeze_2(FreezePolicy value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasFreeze_2() => $_has(1);
  @$pb.TagNumber(2)
  void clearFreeze_2() => $_clearField(2);
  @$pb.TagNumber(2)
  FreezePolicy ensureFreeze_2() => $_ensure(1);

  @$pb.TagNumber(3)
  TypeAheadMode get typeAhead => $_getN(2);
  @$pb.TagNumber(3)
  set typeAhead(TypeAheadMode value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasTypeAhead() => $_has(2);
  @$pb.TagNumber(3)
  void clearTypeAhead() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get typeAheadDelay => $_getIZ(3);
  @$pb.TagNumber(4)
  set typeAheadDelay($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTypeAheadDelay() => $_has(3);
  @$pb.TagNumber(4)
  void clearTypeAheadDelay() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get autoSizeMouse => $_getBF(4);
  @$pb.TagNumber(5)
  set autoSizeMouse($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasAutoSizeMouse() => $_has(4);
  @$pb.TagNumber(5)
  void clearAutoSizeMouse() => $_clearField(5);

  @$pb.TagNumber(6)
  AutoSizeMode get autoSizeMode => $_getN(5);
  @$pb.TagNumber(6)
  set autoSizeMode(AutoSizeMode value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasAutoSizeMode() => $_has(5);
  @$pb.TagNumber(6)
  void clearAutoSizeMode() => $_clearField(6);

  /// When true, bulk bind/load paths do a one-time auto-fit of row heights
  /// and/or column widths using `auto_size_mode`.
  /// Also enables the engine's per-cell auto-resize helper when an adapter
  /// explicitly calls it.
  /// Disable this for very large datasets (for example around 1M rows),
  /// because auto-fit may scan many or all cells to find the required size.
  @$pb.TagNumber(7)
  $core.bool get autoResize => $_getBF(6);
  @$pb.TagNumber(7)
  set autoResize($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasAutoResize() => $_has(6);
  @$pb.TagNumber(7)
  void clearAutoResize() => $_clearField(7);

  @$pb.TagNumber(8)
  DragMode get dragMode => $_getN(7);
  @$pb.TagNumber(8)
  set dragMode(DragMode value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasDragMode() => $_has(7);
  @$pb.TagNumber(8)
  void clearDragMode() => $_clearField(8);

  @$pb.TagNumber(9)
  DropMode get dropMode => $_getN(8);
  @$pb.TagNumber(9)
  set dropMode(DropMode value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasDropMode() => $_has(8);
  @$pb.TagNumber(9)
  void clearDropMode() => $_clearField(9);

  @$pb.TagNumber(10)
  HeaderFeatures get headerFeatures => $_getN(9);
  @$pb.TagNumber(10)
  set headerFeatures(HeaderFeatures value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasHeaderFeatures() => $_has(9);
  @$pb.TagNumber(10)
  void clearHeaderFeatures() => $_clearField(10);
  @$pb.TagNumber(10)
  HeaderFeatures ensureHeaderFeatures() => $_ensure(9);
}

/// ── Rendering ──
class RenderConfig extends $pb.GeneratedMessage {
  factory RenderConfig({
    RendererMode? rendererMode,
    $core.bool? debugOverlay,
    $core.bool? animationEnabled,
    $core.int? animationDurationMs,
    $core.int? textLayoutCacheCap,
    PresentMode? presentMode,
    FramePacingMode? framePacingMode,
    $core.int? targetFrameRateHz,
    $fixnum.Int64? renderLayerMask,
    $core.bool? layerProfiling,
    $core.bool? scrollBlit,
  }) {
    final result = create();
    if (rendererMode != null) result.rendererMode = rendererMode;
    if (debugOverlay != null) result.debugOverlay = debugOverlay;
    if (animationEnabled != null) result.animationEnabled = animationEnabled;
    if (animationDurationMs != null)
      result.animationDurationMs = animationDurationMs;
    if (textLayoutCacheCap != null)
      result.textLayoutCacheCap = textLayoutCacheCap;
    if (presentMode != null) result.presentMode = presentMode;
    if (framePacingMode != null) result.framePacingMode = framePacingMode;
    if (targetFrameRateHz != null) result.targetFrameRateHz = targetFrameRateHz;
    if (renderLayerMask != null) result.renderLayerMask = renderLayerMask;
    if (layerProfiling != null) result.layerProfiling = layerProfiling;
    if (scrollBlit != null) result.scrollBlit = scrollBlit;
    return result;
  }

  RenderConfig._();

  factory RenderConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RenderConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RenderConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aE<RendererMode>(1, _omitFieldNames ? '' : 'rendererMode',
        enumValues: RendererMode.values)
    ..aOB(2, _omitFieldNames ? '' : 'debugOverlay')
    ..aOB(3, _omitFieldNames ? '' : 'animationEnabled')
    ..aI(4, _omitFieldNames ? '' : 'animationDurationMs')
    ..aI(5, _omitFieldNames ? '' : 'textLayoutCacheCap')
    ..aE<PresentMode>(6, _omitFieldNames ? '' : 'presentMode',
        enumValues: PresentMode.values)
    ..aE<FramePacingMode>(7, _omitFieldNames ? '' : 'framePacingMode',
        enumValues: FramePacingMode.values)
    ..aI(8, _omitFieldNames ? '' : 'targetFrameRateHz')
    ..aInt64(9, _omitFieldNames ? '' : 'renderLayerMask')
    ..aOB(10, _omitFieldNames ? '' : 'layerProfiling')
    ..aOB(11, _omitFieldNames ? '' : 'scrollBlit')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RenderConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RenderConfig copyWith(void Function(RenderConfig) updates) =>
      super.copyWith((message) => updates(message as RenderConfig))
          as RenderConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RenderConfig create() => RenderConfig._();
  @$core.override
  RenderConfig createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RenderConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RenderConfig>(create);
  static RenderConfig? _defaultInstance;

  @$pb.TagNumber(1)
  RendererMode get rendererMode => $_getN(0);
  @$pb.TagNumber(1)
  set rendererMode(RendererMode value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasRendererMode() => $_has(0);
  @$pb.TagNumber(1)
  void clearRendererMode() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get debugOverlay => $_getBF(1);
  @$pb.TagNumber(2)
  set debugOverlay($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDebugOverlay() => $_has(1);
  @$pb.TagNumber(2)
  void clearDebugOverlay() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get animationEnabled => $_getBF(2);
  @$pb.TagNumber(3)
  set animationEnabled($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAnimationEnabled() => $_has(2);
  @$pb.TagNumber(3)
  void clearAnimationEnabled() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get animationDurationMs => $_getIZ(3);
  @$pb.TagNumber(4)
  set animationDurationMs($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAnimationDurationMs() => $_has(3);
  @$pb.TagNumber(4)
  void clearAnimationDurationMs() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get textLayoutCacheCap => $_getIZ(4);
  @$pb.TagNumber(5)
  set textLayoutCacheCap($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTextLayoutCacheCap() => $_has(4);
  @$pb.TagNumber(5)
  void clearTextLayoutCacheCap() => $_clearField(5);

  @$pb.TagNumber(6)
  PresentMode get presentMode => $_getN(5);
  @$pb.TagNumber(6)
  set presentMode(PresentMode value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasPresentMode() => $_has(5);
  @$pb.TagNumber(6)
  void clearPresentMode() => $_clearField(6);

  @$pb.TagNumber(7)
  FramePacingMode get framePacingMode => $_getN(6);
  @$pb.TagNumber(7)
  set framePacingMode(FramePacingMode value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasFramePacingMode() => $_has(6);
  @$pb.TagNumber(7)
  void clearFramePacingMode() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get targetFrameRateHz => $_getIZ(7);
  @$pb.TagNumber(8)
  set targetFrameRateHz($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasTargetFrameRateHz() => $_has(7);
  @$pb.TagNumber(8)
  void clearTargetFrameRateHz() => $_clearField(8);

  @$pb.TagNumber(9)
  $fixnum.Int64 get renderLayerMask => $_getI64(8);
  @$pb.TagNumber(9)
  set renderLayerMask($fixnum.Int64 value) => $_setInt64(8, value);
  @$pb.TagNumber(9)
  $core.bool hasRenderLayerMask() => $_has(8);
  @$pb.TagNumber(9)
  void clearRenderLayerMask() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.bool get layerProfiling => $_getBF(9);
  @$pb.TagNumber(10)
  set layerProfiling($core.bool value) => $_setBool(9, value);
  @$pb.TagNumber(10)
  $core.bool hasLayerProfiling() => $_has(9);
  @$pb.TagNumber(10)
  void clearLayerProfiling() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.bool get scrollBlit => $_getBF(10);
  @$pb.TagNumber(11)
  set scrollBlit($core.bool value) => $_setBool(10, value);
  @$pb.TagNumber(11)
  $core.bool hasScrollBlit() => $_has(10);
  @$pb.TagNumber(11)
  void clearScrollBlit() => $_clearField(11);
}

class RowIndicatorSlot extends $pb.GeneratedMessage {
  factory RowIndicatorSlot({
    RowIndicatorSlotKind? kind,
    $core.int? width,
    $core.bool? visible,
    $core.String? customKey,
    $core.List<$core.int>? data,
  }) {
    final result = create();
    if (kind != null) result.kind = kind;
    if (width != null) result.width = width;
    if (visible != null) result.visible = visible;
    if (customKey != null) result.customKey = customKey;
    if (data != null) result.data = data;
    return result;
  }

  RowIndicatorSlot._();

  factory RowIndicatorSlot.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RowIndicatorSlot.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RowIndicatorSlot',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aE<RowIndicatorSlotKind>(1, _omitFieldNames ? '' : 'kind',
        enumValues: RowIndicatorSlotKind.values)
    ..aI(2, _omitFieldNames ? '' : 'width')
    ..aOB(3, _omitFieldNames ? '' : 'visible')
    ..aOS(4, _omitFieldNames ? '' : 'customKey')
    ..a<$core.List<$core.int>>(
        5, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RowIndicatorSlot clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RowIndicatorSlot copyWith(void Function(RowIndicatorSlot) updates) =>
      super.copyWith((message) => updates(message as RowIndicatorSlot))
          as RowIndicatorSlot;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RowIndicatorSlot create() => RowIndicatorSlot._();
  @$core.override
  RowIndicatorSlot createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RowIndicatorSlot getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RowIndicatorSlot>(create);
  static RowIndicatorSlot? _defaultInstance;

  @$pb.TagNumber(1)
  RowIndicatorSlotKind get kind => $_getN(0);
  @$pb.TagNumber(1)
  set kind(RowIndicatorSlotKind value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasKind() => $_has(0);
  @$pb.TagNumber(1)
  void clearKind() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get width => $_getIZ(1);
  @$pb.TagNumber(2)
  set width($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasWidth() => $_has(1);
  @$pb.TagNumber(2)
  void clearWidth() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get visible => $_getBF(2);
  @$pb.TagNumber(3)
  set visible($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasVisible() => $_has(2);
  @$pb.TagNumber(3)
  void clearVisible() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get customKey => $_getSZ(3);
  @$pb.TagNumber(4)
  set customKey($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCustomKey() => $_has(3);
  @$pb.TagNumber(4)
  void clearCustomKey() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.List<$core.int> get data => $_getN(4);
  @$pb.TagNumber(5)
  set data($core.List<$core.int> value) => $_setBytes(4, value);
  @$pb.TagNumber(5)
  $core.bool hasData() => $_has(4);
  @$pb.TagNumber(5)
  void clearData() => $_clearField(5);
}

class RowIndicatorConfig extends $pb.GeneratedMessage {
  factory RowIndicatorConfig({
    $core.bool? visible,
    $core.int? width,
    $core.int? modeBits,
    $core.int? background,
    $core.int? foreground,
    GridLineStyle? gridLines,
    $core.int? gridColor,
    $core.bool? autoSize,
    $core.bool? allowResize,
    $core.bool? allowSelect,
    $core.bool? allowReorder,
    $core.Iterable<RowIndicatorSlot>? slots,
  }) {
    final result = create();
    if (visible != null) result.visible = visible;
    if (width != null) result.width = width;
    if (modeBits != null) result.modeBits = modeBits;
    if (background != null) result.background = background;
    if (foreground != null) result.foreground = foreground;
    if (gridLines != null) result.gridLines = gridLines;
    if (gridColor != null) result.gridColor = gridColor;
    if (autoSize != null) result.autoSize = autoSize;
    if (allowResize != null) result.allowResize = allowResize;
    if (allowSelect != null) result.allowSelect = allowSelect;
    if (allowReorder != null) result.allowReorder = allowReorder;
    if (slots != null) result.slots.addAll(slots);
    return result;
  }

  RowIndicatorConfig._();

  factory RowIndicatorConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RowIndicatorConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RowIndicatorConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'visible')
    ..aI(2, _omitFieldNames ? '' : 'width')
    ..aI(3, _omitFieldNames ? '' : 'modeBits', fieldType: $pb.PbFieldType.OU3)
    ..aI(4, _omitFieldNames ? '' : 'background', fieldType: $pb.PbFieldType.OU3)
    ..aI(5, _omitFieldNames ? '' : 'foreground', fieldType: $pb.PbFieldType.OU3)
    ..aE<GridLineStyle>(6, _omitFieldNames ? '' : 'gridLines',
        enumValues: GridLineStyle.values)
    ..aI(7, _omitFieldNames ? '' : 'gridColor', fieldType: $pb.PbFieldType.OU3)
    ..aOB(8, _omitFieldNames ? '' : 'autoSize')
    ..aOB(9, _omitFieldNames ? '' : 'allowResize')
    ..aOB(10, _omitFieldNames ? '' : 'allowSelect')
    ..aOB(11, _omitFieldNames ? '' : 'allowReorder')
    ..pPM<RowIndicatorSlot>(12, _omitFieldNames ? '' : 'slots',
        subBuilder: RowIndicatorSlot.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RowIndicatorConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RowIndicatorConfig copyWith(void Function(RowIndicatorConfig) updates) =>
      super.copyWith((message) => updates(message as RowIndicatorConfig))
          as RowIndicatorConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RowIndicatorConfig create() => RowIndicatorConfig._();
  @$core.override
  RowIndicatorConfig createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RowIndicatorConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RowIndicatorConfig>(create);
  static RowIndicatorConfig? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get visible => $_getBF(0);
  @$pb.TagNumber(1)
  set visible($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasVisible() => $_has(0);
  @$pb.TagNumber(1)
  void clearVisible() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get width => $_getIZ(1);
  @$pb.TagNumber(2)
  set width($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasWidth() => $_has(1);
  @$pb.TagNumber(2)
  void clearWidth() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get modeBits => $_getIZ(2);
  @$pb.TagNumber(3)
  set modeBits($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasModeBits() => $_has(2);
  @$pb.TagNumber(3)
  void clearModeBits() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get background => $_getIZ(3);
  @$pb.TagNumber(4)
  set background($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasBackground() => $_has(3);
  @$pb.TagNumber(4)
  void clearBackground() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get foreground => $_getIZ(4);
  @$pb.TagNumber(5)
  set foreground($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasForeground() => $_has(4);
  @$pb.TagNumber(5)
  void clearForeground() => $_clearField(5);

  @$pb.TagNumber(6)
  GridLineStyle get gridLines => $_getN(5);
  @$pb.TagNumber(6)
  set gridLines(GridLineStyle value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasGridLines() => $_has(5);
  @$pb.TagNumber(6)
  void clearGridLines() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get gridColor => $_getIZ(6);
  @$pb.TagNumber(7)
  set gridColor($core.int value) => $_setUnsignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasGridColor() => $_has(6);
  @$pb.TagNumber(7)
  void clearGridColor() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.bool get autoSize => $_getBF(7);
  @$pb.TagNumber(8)
  set autoSize($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasAutoSize() => $_has(7);
  @$pb.TagNumber(8)
  void clearAutoSize() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.bool get allowResize => $_getBF(8);
  @$pb.TagNumber(9)
  set allowResize($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasAllowResize() => $_has(8);
  @$pb.TagNumber(9)
  void clearAllowResize() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.bool get allowSelect => $_getBF(9);
  @$pb.TagNumber(10)
  set allowSelect($core.bool value) => $_setBool(9, value);
  @$pb.TagNumber(10)
  $core.bool hasAllowSelect() => $_has(9);
  @$pb.TagNumber(10)
  void clearAllowSelect() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.bool get allowReorder => $_getBF(10);
  @$pb.TagNumber(11)
  set allowReorder($core.bool value) => $_setBool(10, value);
  @$pb.TagNumber(11)
  $core.bool hasAllowReorder() => $_has(10);
  @$pb.TagNumber(11)
  void clearAllowReorder() => $_clearField(11);

  @$pb.TagNumber(12)
  $pb.PbList<RowIndicatorSlot> get slots => $_getList(11);
}

class ColIndicatorRowDef extends $pb.GeneratedMessage {
  factory ColIndicatorRowDef({
    $core.int? index,
    $core.int? height,
  }) {
    final result = create();
    if (index != null) result.index = index;
    if (height != null) result.height = height;
    return result;
  }

  ColIndicatorRowDef._();

  factory ColIndicatorRowDef.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ColIndicatorRowDef.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ColIndicatorRowDef',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'index')
    ..aI(2, _omitFieldNames ? '' : 'height')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ColIndicatorRowDef clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ColIndicatorRowDef copyWith(void Function(ColIndicatorRowDef) updates) =>
      super.copyWith((message) => updates(message as ColIndicatorRowDef))
          as ColIndicatorRowDef;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ColIndicatorRowDef create() => ColIndicatorRowDef._();
  @$core.override
  ColIndicatorRowDef createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ColIndicatorRowDef getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ColIndicatorRowDef>(create);
  static ColIndicatorRowDef? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get index => $_getIZ(0);
  @$pb.TagNumber(1)
  set index($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasIndex() => $_has(0);
  @$pb.TagNumber(1)
  void clearIndex() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get height => $_getIZ(1);
  @$pb.TagNumber(2)
  set height($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasHeight() => $_has(1);
  @$pb.TagNumber(2)
  void clearHeight() => $_clearField(2);
}

class ColIndicatorCell extends $pb.GeneratedMessage {
  factory ColIndicatorCell({
    $core.int? row1,
    $core.int? row2,
    $core.int? col1,
    $core.int? col2,
    $core.String? text,
    $core.int? modeBits,
    $core.String? customKey,
    $core.List<$core.int>? data,
  }) {
    final result = create();
    if (row1 != null) result.row1 = row1;
    if (row2 != null) result.row2 = row2;
    if (col1 != null) result.col1 = col1;
    if (col2 != null) result.col2 = col2;
    if (text != null) result.text = text;
    if (modeBits != null) result.modeBits = modeBits;
    if (customKey != null) result.customKey = customKey;
    if (data != null) result.data = data;
    return result;
  }

  ColIndicatorCell._();

  factory ColIndicatorCell.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ColIndicatorCell.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ColIndicatorCell',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'row1')
    ..aI(2, _omitFieldNames ? '' : 'row2')
    ..aI(3, _omitFieldNames ? '' : 'col1')
    ..aI(4, _omitFieldNames ? '' : 'col2')
    ..aOS(5, _omitFieldNames ? '' : 'text')
    ..aI(6, _omitFieldNames ? '' : 'modeBits', fieldType: $pb.PbFieldType.OU3)
    ..aOS(7, _omitFieldNames ? '' : 'customKey')
    ..a<$core.List<$core.int>>(
        8, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ColIndicatorCell clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ColIndicatorCell copyWith(void Function(ColIndicatorCell) updates) =>
      super.copyWith((message) => updates(message as ColIndicatorCell))
          as ColIndicatorCell;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ColIndicatorCell create() => ColIndicatorCell._();
  @$core.override
  ColIndicatorCell createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ColIndicatorCell getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ColIndicatorCell>(create);
  static ColIndicatorCell? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get row1 => $_getIZ(0);
  @$pb.TagNumber(1)
  set row1($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRow1() => $_has(0);
  @$pb.TagNumber(1)
  void clearRow1() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get row2 => $_getIZ(1);
  @$pb.TagNumber(2)
  set row2($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRow2() => $_has(1);
  @$pb.TagNumber(2)
  void clearRow2() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get col1 => $_getIZ(2);
  @$pb.TagNumber(3)
  set col1($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCol1() => $_has(2);
  @$pb.TagNumber(3)
  void clearCol1() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get col2 => $_getIZ(3);
  @$pb.TagNumber(4)
  set col2($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCol2() => $_has(3);
  @$pb.TagNumber(4)
  void clearCol2() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get text => $_getSZ(4);
  @$pb.TagNumber(5)
  set text($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasText() => $_has(4);
  @$pb.TagNumber(5)
  void clearText() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get modeBits => $_getIZ(5);
  @$pb.TagNumber(6)
  set modeBits($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasModeBits() => $_has(5);
  @$pb.TagNumber(6)
  void clearModeBits() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get customKey => $_getSZ(6);
  @$pb.TagNumber(7)
  set customKey($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasCustomKey() => $_has(6);
  @$pb.TagNumber(7)
  void clearCustomKey() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.List<$core.int> get data => $_getN(7);
  @$pb.TagNumber(8)
  set data($core.List<$core.int> value) => $_setBytes(7, value);
  @$pb.TagNumber(8)
  $core.bool hasData() => $_has(7);
  @$pb.TagNumber(8)
  void clearData() => $_clearField(8);
}

class ColIndicatorConfig extends $pb.GeneratedMessage {
  factory ColIndicatorConfig({
    $core.bool? visible,
    $core.int? defaultRowHeight,
    $core.int? bandRows,
    $core.int? modeBits,
    $core.int? background,
    $core.int? foreground,
    GridLineStyle? gridLines,
    $core.int? gridColor,
    $core.bool? autoSize,
    $core.bool? allowResize,
    $core.bool? allowReorder,
    $core.bool? allowMenu,
    $core.Iterable<ColIndicatorRowDef>? rowDefs,
    $core.Iterable<ColIndicatorCell>? cells,
  }) {
    final result = create();
    if (visible != null) result.visible = visible;
    if (defaultRowHeight != null) result.defaultRowHeight = defaultRowHeight;
    if (bandRows != null) result.bandRows = bandRows;
    if (modeBits != null) result.modeBits = modeBits;
    if (background != null) result.background = background;
    if (foreground != null) result.foreground = foreground;
    if (gridLines != null) result.gridLines = gridLines;
    if (gridColor != null) result.gridColor = gridColor;
    if (autoSize != null) result.autoSize = autoSize;
    if (allowResize != null) result.allowResize = allowResize;
    if (allowReorder != null) result.allowReorder = allowReorder;
    if (allowMenu != null) result.allowMenu = allowMenu;
    if (rowDefs != null) result.rowDefs.addAll(rowDefs);
    if (cells != null) result.cells.addAll(cells);
    return result;
  }

  ColIndicatorConfig._();

  factory ColIndicatorConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ColIndicatorConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ColIndicatorConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'visible')
    ..aI(2, _omitFieldNames ? '' : 'defaultRowHeight')
    ..aI(3, _omitFieldNames ? '' : 'bandRows')
    ..aI(4, _omitFieldNames ? '' : 'modeBits', fieldType: $pb.PbFieldType.OU3)
    ..aI(5, _omitFieldNames ? '' : 'background', fieldType: $pb.PbFieldType.OU3)
    ..aI(6, _omitFieldNames ? '' : 'foreground', fieldType: $pb.PbFieldType.OU3)
    ..aE<GridLineStyle>(7, _omitFieldNames ? '' : 'gridLines',
        enumValues: GridLineStyle.values)
    ..aI(8, _omitFieldNames ? '' : 'gridColor', fieldType: $pb.PbFieldType.OU3)
    ..aOB(9, _omitFieldNames ? '' : 'autoSize')
    ..aOB(10, _omitFieldNames ? '' : 'allowResize')
    ..aOB(11, _omitFieldNames ? '' : 'allowReorder')
    ..aOB(12, _omitFieldNames ? '' : 'allowMenu')
    ..pPM<ColIndicatorRowDef>(13, _omitFieldNames ? '' : 'rowDefs',
        subBuilder: ColIndicatorRowDef.create)
    ..pPM<ColIndicatorCell>(14, _omitFieldNames ? '' : 'cells',
        subBuilder: ColIndicatorCell.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ColIndicatorConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ColIndicatorConfig copyWith(void Function(ColIndicatorConfig) updates) =>
      super.copyWith((message) => updates(message as ColIndicatorConfig))
          as ColIndicatorConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ColIndicatorConfig create() => ColIndicatorConfig._();
  @$core.override
  ColIndicatorConfig createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ColIndicatorConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ColIndicatorConfig>(create);
  static ColIndicatorConfig? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get visible => $_getBF(0);
  @$pb.TagNumber(1)
  set visible($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasVisible() => $_has(0);
  @$pb.TagNumber(1)
  void clearVisible() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get defaultRowHeight => $_getIZ(1);
  @$pb.TagNumber(2)
  set defaultRowHeight($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDefaultRowHeight() => $_has(1);
  @$pb.TagNumber(2)
  void clearDefaultRowHeight() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get bandRows => $_getIZ(2);
  @$pb.TagNumber(3)
  set bandRows($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasBandRows() => $_has(2);
  @$pb.TagNumber(3)
  void clearBandRows() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get modeBits => $_getIZ(3);
  @$pb.TagNumber(4)
  set modeBits($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasModeBits() => $_has(3);
  @$pb.TagNumber(4)
  void clearModeBits() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get background => $_getIZ(4);
  @$pb.TagNumber(5)
  set background($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasBackground() => $_has(4);
  @$pb.TagNumber(5)
  void clearBackground() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get foreground => $_getIZ(5);
  @$pb.TagNumber(6)
  set foreground($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasForeground() => $_has(5);
  @$pb.TagNumber(6)
  void clearForeground() => $_clearField(6);

  @$pb.TagNumber(7)
  GridLineStyle get gridLines => $_getN(6);
  @$pb.TagNumber(7)
  set gridLines(GridLineStyle value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasGridLines() => $_has(6);
  @$pb.TagNumber(7)
  void clearGridLines() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get gridColor => $_getIZ(7);
  @$pb.TagNumber(8)
  set gridColor($core.int value) => $_setUnsignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasGridColor() => $_has(7);
  @$pb.TagNumber(8)
  void clearGridColor() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.bool get autoSize => $_getBF(8);
  @$pb.TagNumber(9)
  set autoSize($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasAutoSize() => $_has(8);
  @$pb.TagNumber(9)
  void clearAutoSize() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.bool get allowResize => $_getBF(9);
  @$pb.TagNumber(10)
  set allowResize($core.bool value) => $_setBool(9, value);
  @$pb.TagNumber(10)
  $core.bool hasAllowResize() => $_has(9);
  @$pb.TagNumber(10)
  void clearAllowResize() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.bool get allowReorder => $_getBF(10);
  @$pb.TagNumber(11)
  set allowReorder($core.bool value) => $_setBool(10, value);
  @$pb.TagNumber(11)
  $core.bool hasAllowReorder() => $_has(10);
  @$pb.TagNumber(11)
  void clearAllowReorder() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.bool get allowMenu => $_getBF(11);
  @$pb.TagNumber(12)
  set allowMenu($core.bool value) => $_setBool(11, value);
  @$pb.TagNumber(12)
  $core.bool hasAllowMenu() => $_has(11);
  @$pb.TagNumber(12)
  void clearAllowMenu() => $_clearField(12);

  @$pb.TagNumber(13)
  $pb.PbList<ColIndicatorRowDef> get rowDefs => $_getList(12);

  @$pb.TagNumber(14)
  $pb.PbList<ColIndicatorCell> get cells => $_getList(13);
}

class CornerIndicatorConfig extends $pb.GeneratedMessage {
  factory CornerIndicatorConfig({
    $core.bool? visible,
    $core.int? modeBits,
    $core.int? background,
    $core.int? foreground,
    $core.String? customKey,
    $core.List<$core.int>? data,
  }) {
    final result = create();
    if (visible != null) result.visible = visible;
    if (modeBits != null) result.modeBits = modeBits;
    if (background != null) result.background = background;
    if (foreground != null) result.foreground = foreground;
    if (customKey != null) result.customKey = customKey;
    if (data != null) result.data = data;
    return result;
  }

  CornerIndicatorConfig._();

  factory CornerIndicatorConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CornerIndicatorConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CornerIndicatorConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'visible')
    ..aI(2, _omitFieldNames ? '' : 'modeBits', fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'background', fieldType: $pb.PbFieldType.OU3)
    ..aI(4, _omitFieldNames ? '' : 'foreground', fieldType: $pb.PbFieldType.OU3)
    ..aOS(5, _omitFieldNames ? '' : 'customKey')
    ..a<$core.List<$core.int>>(
        6, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CornerIndicatorConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CornerIndicatorConfig copyWith(
          void Function(CornerIndicatorConfig) updates) =>
      super.copyWith((message) => updates(message as CornerIndicatorConfig))
          as CornerIndicatorConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CornerIndicatorConfig create() => CornerIndicatorConfig._();
  @$core.override
  CornerIndicatorConfig createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CornerIndicatorConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CornerIndicatorConfig>(create);
  static CornerIndicatorConfig? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get visible => $_getBF(0);
  @$pb.TagNumber(1)
  set visible($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasVisible() => $_has(0);
  @$pb.TagNumber(1)
  void clearVisible() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get modeBits => $_getIZ(1);
  @$pb.TagNumber(2)
  set modeBits($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasModeBits() => $_has(1);
  @$pb.TagNumber(2)
  void clearModeBits() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get background => $_getIZ(2);
  @$pb.TagNumber(3)
  set background($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasBackground() => $_has(2);
  @$pb.TagNumber(3)
  void clearBackground() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get foreground => $_getIZ(3);
  @$pb.TagNumber(4)
  set foreground($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasForeground() => $_has(3);
  @$pb.TagNumber(4)
  void clearForeground() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get customKey => $_getSZ(4);
  @$pb.TagNumber(5)
  set customKey($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCustomKey() => $_has(4);
  @$pb.TagNumber(5)
  void clearCustomKey() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.List<$core.int> get data => $_getN(5);
  @$pb.TagNumber(6)
  set data($core.List<$core.int> value) => $_setBytes(5, value);
  @$pb.TagNumber(6)
  $core.bool hasData() => $_has(5);
  @$pb.TagNumber(6)
  void clearData() => $_clearField(6);
}

class IndicatorsConfig extends $pb.GeneratedMessage {
  factory IndicatorsConfig({
    RowIndicatorConfig? rowStart,
    RowIndicatorConfig? rowEnd,
    ColIndicatorConfig? colTop,
    ColIndicatorConfig? colBottom,
    CornerIndicatorConfig? cornerTopStart,
    CornerIndicatorConfig? cornerTopEnd,
    CornerIndicatorConfig? cornerBottomStart,
    CornerIndicatorConfig? cornerBottomEnd,
  }) {
    final result = create();
    if (rowStart != null) result.rowStart = rowStart;
    if (rowEnd != null) result.rowEnd = rowEnd;
    if (colTop != null) result.colTop = colTop;
    if (colBottom != null) result.colBottom = colBottom;
    if (cornerTopStart != null) result.cornerTopStart = cornerTopStart;
    if (cornerTopEnd != null) result.cornerTopEnd = cornerTopEnd;
    if (cornerBottomStart != null) result.cornerBottomStart = cornerBottomStart;
    if (cornerBottomEnd != null) result.cornerBottomEnd = cornerBottomEnd;
    return result;
  }

  IndicatorsConfig._();

  factory IndicatorsConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory IndicatorsConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'IndicatorsConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aOM<RowIndicatorConfig>(1, _omitFieldNames ? '' : 'rowStart',
        subBuilder: RowIndicatorConfig.create)
    ..aOM<RowIndicatorConfig>(2, _omitFieldNames ? '' : 'rowEnd',
        subBuilder: RowIndicatorConfig.create)
    ..aOM<ColIndicatorConfig>(3, _omitFieldNames ? '' : 'colTop',
        subBuilder: ColIndicatorConfig.create)
    ..aOM<ColIndicatorConfig>(4, _omitFieldNames ? '' : 'colBottom',
        subBuilder: ColIndicatorConfig.create)
    ..aOM<CornerIndicatorConfig>(5, _omitFieldNames ? '' : 'cornerTopStart',
        subBuilder: CornerIndicatorConfig.create)
    ..aOM<CornerIndicatorConfig>(6, _omitFieldNames ? '' : 'cornerTopEnd',
        subBuilder: CornerIndicatorConfig.create)
    ..aOM<CornerIndicatorConfig>(7, _omitFieldNames ? '' : 'cornerBottomStart',
        subBuilder: CornerIndicatorConfig.create)
    ..aOM<CornerIndicatorConfig>(8, _omitFieldNames ? '' : 'cornerBottomEnd',
        subBuilder: CornerIndicatorConfig.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  IndicatorsConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  IndicatorsConfig copyWith(void Function(IndicatorsConfig) updates) =>
      super.copyWith((message) => updates(message as IndicatorsConfig))
          as IndicatorsConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static IndicatorsConfig create() => IndicatorsConfig._();
  @$core.override
  IndicatorsConfig createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static IndicatorsConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<IndicatorsConfig>(create);
  static IndicatorsConfig? _defaultInstance;

  @$pb.TagNumber(1)
  RowIndicatorConfig get rowStart => $_getN(0);
  @$pb.TagNumber(1)
  set rowStart(RowIndicatorConfig value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasRowStart() => $_has(0);
  @$pb.TagNumber(1)
  void clearRowStart() => $_clearField(1);
  @$pb.TagNumber(1)
  RowIndicatorConfig ensureRowStart() => $_ensure(0);

  @$pb.TagNumber(2)
  RowIndicatorConfig get rowEnd => $_getN(1);
  @$pb.TagNumber(2)
  set rowEnd(RowIndicatorConfig value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasRowEnd() => $_has(1);
  @$pb.TagNumber(2)
  void clearRowEnd() => $_clearField(2);
  @$pb.TagNumber(2)
  RowIndicatorConfig ensureRowEnd() => $_ensure(1);

  @$pb.TagNumber(3)
  ColIndicatorConfig get colTop => $_getN(2);
  @$pb.TagNumber(3)
  set colTop(ColIndicatorConfig value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasColTop() => $_has(2);
  @$pb.TagNumber(3)
  void clearColTop() => $_clearField(3);
  @$pb.TagNumber(3)
  ColIndicatorConfig ensureColTop() => $_ensure(2);

  @$pb.TagNumber(4)
  ColIndicatorConfig get colBottom => $_getN(3);
  @$pb.TagNumber(4)
  set colBottom(ColIndicatorConfig value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasColBottom() => $_has(3);
  @$pb.TagNumber(4)
  void clearColBottom() => $_clearField(4);
  @$pb.TagNumber(4)
  ColIndicatorConfig ensureColBottom() => $_ensure(3);

  @$pb.TagNumber(5)
  CornerIndicatorConfig get cornerTopStart => $_getN(4);
  @$pb.TagNumber(5)
  set cornerTopStart(CornerIndicatorConfig value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasCornerTopStart() => $_has(4);
  @$pb.TagNumber(5)
  void clearCornerTopStart() => $_clearField(5);
  @$pb.TagNumber(5)
  CornerIndicatorConfig ensureCornerTopStart() => $_ensure(4);

  @$pb.TagNumber(6)
  CornerIndicatorConfig get cornerTopEnd => $_getN(5);
  @$pb.TagNumber(6)
  set cornerTopEnd(CornerIndicatorConfig value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasCornerTopEnd() => $_has(5);
  @$pb.TagNumber(6)
  void clearCornerTopEnd() => $_clearField(6);
  @$pb.TagNumber(6)
  CornerIndicatorConfig ensureCornerTopEnd() => $_ensure(5);

  @$pb.TagNumber(7)
  CornerIndicatorConfig get cornerBottomStart => $_getN(6);
  @$pb.TagNumber(7)
  set cornerBottomStart(CornerIndicatorConfig value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasCornerBottomStart() => $_has(6);
  @$pb.TagNumber(7)
  void clearCornerBottomStart() => $_clearField(7);
  @$pb.TagNumber(7)
  CornerIndicatorConfig ensureCornerBottomStart() => $_ensure(6);

  @$pb.TagNumber(8)
  CornerIndicatorConfig get cornerBottomEnd => $_getN(7);
  @$pb.TagNumber(8)
  set cornerBottomEnd(CornerIndicatorConfig value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasCornerBottomEnd() => $_has(7);
  @$pb.TagNumber(8)
  void clearCornerBottomEnd() => $_clearField(8);
  @$pb.TagNumber(8)
  CornerIndicatorConfig ensureCornerBottomEnd() => $_ensure(7);
}

class ColumnDef extends $pb.GeneratedMessage {
  factory ColumnDef({
    $core.int? index,
    $core.int? width,
    $core.int? minWidth,
    $core.int? maxWidth,
    $core.String? caption,
    Align? align,
    Align? fixedAlign,
    ColumnDataType? dataType,
    $core.String? format,
    $core.String? key,
    SortOrder? sortOrder,
    SortType? sortType,
    $core.String? dropdownItems,
    $core.String? editMask,
    $core.int? indent,
    $core.bool? hidden,
    $core.bool? span,
    $core.Iterable<ImageData>? imageList,
    $core.List<$core.int>? data,
    StickyEdge? sticky,
    Padding? padding,
    Padding? fixedPadding,
    $core.bool? nullable,
    CoercionMode? coercionMode,
    WriteErrorMode? errorMode,
    CellInteraction? interaction,
    $core.int? progressColor,
  }) {
    final result = create();
    if (index != null) result.index = index;
    if (width != null) result.width = width;
    if (minWidth != null) result.minWidth = minWidth;
    if (maxWidth != null) result.maxWidth = maxWidth;
    if (caption != null) result.caption = caption;
    if (align != null) result.align = align;
    if (fixedAlign != null) result.fixedAlign = fixedAlign;
    if (dataType != null) result.dataType = dataType;
    if (format != null) result.format = format;
    if (key != null) result.key = key;
    if (sortOrder != null) result.sortOrder = sortOrder;
    if (sortType != null) result.sortType = sortType;
    if (dropdownItems != null) result.dropdownItems = dropdownItems;
    if (editMask != null) result.editMask = editMask;
    if (indent != null) result.indent = indent;
    if (hidden != null) result.hidden = hidden;
    if (span != null) result.span = span;
    if (imageList != null) result.imageList.addAll(imageList);
    if (data != null) result.data = data;
    if (sticky != null) result.sticky = sticky;
    if (padding != null) result.padding = padding;
    if (fixedPadding != null) result.fixedPadding = fixedPadding;
    if (nullable != null) result.nullable = nullable;
    if (coercionMode != null) result.coercionMode = coercionMode;
    if (errorMode != null) result.errorMode = errorMode;
    if (interaction != null) result.interaction = interaction;
    if (progressColor != null) result.progressColor = progressColor;
    return result;
  }

  ColumnDef._();

  factory ColumnDef.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ColumnDef.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ColumnDef',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'index')
    ..aI(2, _omitFieldNames ? '' : 'width')
    ..aI(3, _omitFieldNames ? '' : 'minWidth')
    ..aI(4, _omitFieldNames ? '' : 'maxWidth')
    ..aOS(5, _omitFieldNames ? '' : 'caption')
    ..aE<Align>(6, _omitFieldNames ? '' : 'align', enumValues: Align.values)
    ..aE<Align>(7, _omitFieldNames ? '' : 'fixedAlign',
        enumValues: Align.values)
    ..aE<ColumnDataType>(8, _omitFieldNames ? '' : 'dataType',
        enumValues: ColumnDataType.values)
    ..aOS(9, _omitFieldNames ? '' : 'format')
    ..aOS(10, _omitFieldNames ? '' : 'key')
    ..aE<SortOrder>(11, _omitFieldNames ? '' : 'sortOrder',
        enumValues: SortOrder.values)
    ..aE<SortType>(12, _omitFieldNames ? '' : 'sortType',
        enumValues: SortType.values)
    ..aOS(13, _omitFieldNames ? '' : 'dropdownItems')
    ..aOS(14, _omitFieldNames ? '' : 'editMask')
    ..aI(15, _omitFieldNames ? '' : 'indent')
    ..aOB(16, _omitFieldNames ? '' : 'hidden')
    ..aOB(17, _omitFieldNames ? '' : 'span')
    ..pPM<ImageData>(18, _omitFieldNames ? '' : 'imageList',
        subBuilder: ImageData.create)
    ..a<$core.List<$core.int>>(
        19, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OY)
    ..aE<StickyEdge>(20, _omitFieldNames ? '' : 'sticky',
        enumValues: StickyEdge.values)
    ..aOM<Padding>(21, _omitFieldNames ? '' : 'padding',
        subBuilder: Padding.create)
    ..aOM<Padding>(22, _omitFieldNames ? '' : 'fixedPadding',
        subBuilder: Padding.create)
    ..aOB(23, _omitFieldNames ? '' : 'nullable')
    ..aE<CoercionMode>(24, _omitFieldNames ? '' : 'coercionMode',
        enumValues: CoercionMode.values)
    ..aE<WriteErrorMode>(25, _omitFieldNames ? '' : 'errorMode',
        enumValues: WriteErrorMode.values)
    ..aE<CellInteraction>(26, _omitFieldNames ? '' : 'interaction',
        enumValues: CellInteraction.values)
    ..aI(27, _omitFieldNames ? '' : 'progressColor',
        fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ColumnDef clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ColumnDef copyWith(void Function(ColumnDef) updates) =>
      super.copyWith((message) => updates(message as ColumnDef)) as ColumnDef;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ColumnDef create() => ColumnDef._();
  @$core.override
  ColumnDef createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ColumnDef getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ColumnDef>(create);
  static ColumnDef? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get index => $_getIZ(0);
  @$pb.TagNumber(1)
  set index($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasIndex() => $_has(0);
  @$pb.TagNumber(1)
  void clearIndex() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get width => $_getIZ(1);
  @$pb.TagNumber(2)
  set width($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasWidth() => $_has(1);
  @$pb.TagNumber(2)
  void clearWidth() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get minWidth => $_getIZ(2);
  @$pb.TagNumber(3)
  set minWidth($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMinWidth() => $_has(2);
  @$pb.TagNumber(3)
  void clearMinWidth() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get maxWidth => $_getIZ(3);
  @$pb.TagNumber(4)
  set maxWidth($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasMaxWidth() => $_has(3);
  @$pb.TagNumber(4)
  void clearMaxWidth() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get caption => $_getSZ(4);
  @$pb.TagNumber(5)
  set caption($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCaption() => $_has(4);
  @$pb.TagNumber(5)
  void clearCaption() => $_clearField(5);

  @$pb.TagNumber(6)
  Align get align => $_getN(5);
  @$pb.TagNumber(6)
  set align(Align value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasAlign() => $_has(5);
  @$pb.TagNumber(6)
  void clearAlign() => $_clearField(6);

  @$pb.TagNumber(7)
  Align get fixedAlign => $_getN(6);
  @$pb.TagNumber(7)
  set fixedAlign(Align value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasFixedAlign() => $_has(6);
  @$pb.TagNumber(7)
  void clearFixedAlign() => $_clearField(7);

  @$pb.TagNumber(8)
  ColumnDataType get dataType => $_getN(7);
  @$pb.TagNumber(8)
  set dataType(ColumnDataType value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasDataType() => $_has(7);
  @$pb.TagNumber(8)
  void clearDataType() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get format => $_getSZ(8);
  @$pb.TagNumber(9)
  set format($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasFormat() => $_has(8);
  @$pb.TagNumber(9)
  void clearFormat() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get key => $_getSZ(9);
  @$pb.TagNumber(10)
  set key($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasKey() => $_has(9);
  @$pb.TagNumber(10)
  void clearKey() => $_clearField(10);

  @$pb.TagNumber(11)
  SortOrder get sortOrder => $_getN(10);
  @$pb.TagNumber(11)
  set sortOrder(SortOrder value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasSortOrder() => $_has(10);
  @$pb.TagNumber(11)
  void clearSortOrder() => $_clearField(11);

  @$pb.TagNumber(12)
  SortType get sortType => $_getN(11);
  @$pb.TagNumber(12)
  set sortType(SortType value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasSortType() => $_has(11);
  @$pb.TagNumber(12)
  void clearSortType() => $_clearField(12);

  /// Pipe-delimited dropdown items; prefix with `|` to make the list editable.
  @$pb.TagNumber(13)
  $core.String get dropdownItems => $_getSZ(12);
  @$pb.TagNumber(13)
  set dropdownItems($core.String value) => $_setString(12, value);
  @$pb.TagNumber(13)
  $core.bool hasDropdownItems() => $_has(12);
  @$pb.TagNumber(13)
  void clearDropdownItems() => $_clearField(13);

  @$pb.TagNumber(14)
  $core.String get editMask => $_getSZ(13);
  @$pb.TagNumber(14)
  set editMask($core.String value) => $_setString(13, value);
  @$pb.TagNumber(14)
  $core.bool hasEditMask() => $_has(13);
  @$pb.TagNumber(14)
  void clearEditMask() => $_clearField(14);

  @$pb.TagNumber(15)
  $core.int get indent => $_getIZ(14);
  @$pb.TagNumber(15)
  set indent($core.int value) => $_setSignedInt32(14, value);
  @$pb.TagNumber(15)
  $core.bool hasIndent() => $_has(14);
  @$pb.TagNumber(15)
  void clearIndent() => $_clearField(15);

  @$pb.TagNumber(16)
  $core.bool get hidden => $_getBF(15);
  @$pb.TagNumber(16)
  set hidden($core.bool value) => $_setBool(15, value);
  @$pb.TagNumber(16)
  $core.bool hasHidden() => $_has(15);
  @$pb.TagNumber(16)
  void clearHidden() => $_clearField(16);

  @$pb.TagNumber(17)
  $core.bool get span => $_getBF(16);
  @$pb.TagNumber(17)
  set span($core.bool value) => $_setBool(16, value);
  @$pb.TagNumber(17)
  $core.bool hasSpan() => $_has(16);
  @$pb.TagNumber(17)
  void clearSpan() => $_clearField(17);

  @$pb.TagNumber(18)
  $pb.PbList<ImageData> get imageList => $_getList(17);

  @$pb.TagNumber(19)
  $core.List<$core.int> get data => $_getN(18);
  @$pb.TagNumber(19)
  set data($core.List<$core.int> value) => $_setBytes(18, value);
  @$pb.TagNumber(19)
  $core.bool hasData() => $_has(18);
  @$pb.TagNumber(19)
  void clearData() => $_clearField(19);

  @$pb.TagNumber(20)
  StickyEdge get sticky => $_getN(19);
  @$pb.TagNumber(20)
  set sticky(StickyEdge value) => $_setField(20, value);
  @$pb.TagNumber(20)
  $core.bool hasSticky() => $_has(19);
  @$pb.TagNumber(20)
  void clearSticky() => $_clearField(20);

  @$pb.TagNumber(21)
  Padding get padding => $_getN(20);
  @$pb.TagNumber(21)
  set padding(Padding value) => $_setField(21, value);
  @$pb.TagNumber(21)
  $core.bool hasPadding() => $_has(20);
  @$pb.TagNumber(21)
  void clearPadding() => $_clearField(21);
  @$pb.TagNumber(21)
  Padding ensurePadding() => $_ensure(20);

  @$pb.TagNumber(22)
  Padding get fixedPadding => $_getN(21);
  @$pb.TagNumber(22)
  set fixedPadding(Padding value) => $_setField(22, value);
  @$pb.TagNumber(22)
  $core.bool hasFixedPadding() => $_has(21);
  @$pb.TagNumber(22)
  void clearFixedPadding() => $_clearField(22);
  @$pb.TagNumber(22)
  Padding ensureFixedPadding() => $_ensure(21);

  @$pb.TagNumber(23)
  $core.bool get nullable => $_getBF(22);
  @$pb.TagNumber(23)
  set nullable($core.bool value) => $_setBool(22, value);
  @$pb.TagNumber(23)
  $core.bool hasNullable() => $_has(22);
  @$pb.TagNumber(23)
  void clearNullable() => $_clearField(23);

  @$pb.TagNumber(24)
  CoercionMode get coercionMode => $_getN(23);
  @$pb.TagNumber(24)
  set coercionMode(CoercionMode value) => $_setField(24, value);
  @$pb.TagNumber(24)
  $core.bool hasCoercionMode() => $_has(23);
  @$pb.TagNumber(24)
  void clearCoercionMode() => $_clearField(24);

  @$pb.TagNumber(25)
  WriteErrorMode get errorMode => $_getN(24);
  @$pb.TagNumber(25)
  set errorMode(WriteErrorMode value) => $_setField(25, value);
  @$pb.TagNumber(25)
  $core.bool hasErrorMode() => $_has(24);
  @$pb.TagNumber(25)
  void clearErrorMode() => $_clearField(25);

  @$pb.TagNumber(26)
  CellInteraction get interaction => $_getN(25);
  @$pb.TagNumber(26)
  set interaction(CellInteraction value) => $_setField(26, value);
  @$pb.TagNumber(26)
  $core.bool hasInteraction() => $_has(25);
  @$pb.TagNumber(26)
  void clearInteraction() => $_clearField(26);

  @$pb.TagNumber(27)
  $core.int get progressColor => $_getIZ(26);
  @$pb.TagNumber(27)
  set progressColor($core.int value) => $_setUnsignedInt32(26, value);
  @$pb.TagNumber(27)
  $core.bool hasProgressColor() => $_has(26);
  @$pb.TagNumber(27)
  void clearProgressColor() => $_clearField(27);
}

class DefineColumnsRequest extends $pb.GeneratedMessage {
  factory DefineColumnsRequest({
    $fixnum.Int64? gridId,
    $core.Iterable<ColumnDef>? columns,
  }) {
    final result = create();
    if (gridId != null) result.gridId = gridId;
    if (columns != null) result.columns.addAll(columns);
    return result;
  }

  DefineColumnsRequest._();

  factory DefineColumnsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DefineColumnsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DefineColumnsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'gridId')
    ..pPM<ColumnDef>(2, _omitFieldNames ? '' : 'columns',
        subBuilder: ColumnDef.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DefineColumnsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DefineColumnsRequest copyWith(void Function(DefineColumnsRequest) updates) =>
      super.copyWith((message) => updates(message as DefineColumnsRequest))
          as DefineColumnsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DefineColumnsRequest create() => DefineColumnsRequest._();
  @$core.override
  DefineColumnsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DefineColumnsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DefineColumnsRequest>(create);
  static DefineColumnsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get gridId => $_getI64(0);
  @$pb.TagNumber(1)
  set gridId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGridId() => $_has(0);
  @$pb.TagNumber(1)
  void clearGridId() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<ColumnDef> get columns => $_getList(1);
}

class RowDef extends $pb.GeneratedMessage {
  factory RowDef({
    $core.int? index,
    $core.int? height,
    $core.bool? hidden,
    $core.bool? isSubtotal,
    $core.int? outlineLevel,
    $core.bool? isCollapsed,
    $core.List<$core.int>? data,
    $core.int? status,
    $core.bool? span,
    PinPosition? pin,
    StickyEdge? sticky,
  }) {
    final result = create();
    if (index != null) result.index = index;
    if (height != null) result.height = height;
    if (hidden != null) result.hidden = hidden;
    if (isSubtotal != null) result.isSubtotal = isSubtotal;
    if (outlineLevel != null) result.outlineLevel = outlineLevel;
    if (isCollapsed != null) result.isCollapsed = isCollapsed;
    if (data != null) result.data = data;
    if (status != null) result.status = status;
    if (span != null) result.span = span;
    if (pin != null) result.pin = pin;
    if (sticky != null) result.sticky = sticky;
    return result;
  }

  RowDef._();

  factory RowDef.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RowDef.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RowDef',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'index')
    ..aI(2, _omitFieldNames ? '' : 'height')
    ..aOB(3, _omitFieldNames ? '' : 'hidden')
    ..aOB(4, _omitFieldNames ? '' : 'isSubtotal')
    ..aI(5, _omitFieldNames ? '' : 'outlineLevel')
    ..aOB(6, _omitFieldNames ? '' : 'isCollapsed')
    ..a<$core.List<$core.int>>(
        7, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OY)
    ..aI(8, _omitFieldNames ? '' : 'status')
    ..aOB(9, _omitFieldNames ? '' : 'span')
    ..aE<PinPosition>(10, _omitFieldNames ? '' : 'pin',
        enumValues: PinPosition.values)
    ..aE<StickyEdge>(11, _omitFieldNames ? '' : 'sticky',
        enumValues: StickyEdge.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RowDef clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RowDef copyWith(void Function(RowDef) updates) =>
      super.copyWith((message) => updates(message as RowDef)) as RowDef;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RowDef create() => RowDef._();
  @$core.override
  RowDef createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RowDef getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RowDef>(create);
  static RowDef? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get index => $_getIZ(0);
  @$pb.TagNumber(1)
  set index($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasIndex() => $_has(0);
  @$pb.TagNumber(1)
  void clearIndex() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get height => $_getIZ(1);
  @$pb.TagNumber(2)
  set height($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasHeight() => $_has(1);
  @$pb.TagNumber(2)
  void clearHeight() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get hidden => $_getBF(2);
  @$pb.TagNumber(3)
  set hidden($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasHidden() => $_has(2);
  @$pb.TagNumber(3)
  void clearHidden() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get isSubtotal => $_getBF(3);
  @$pb.TagNumber(4)
  set isSubtotal($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasIsSubtotal() => $_has(3);
  @$pb.TagNumber(4)
  void clearIsSubtotal() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get outlineLevel => $_getIZ(4);
  @$pb.TagNumber(5)
  set outlineLevel($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasOutlineLevel() => $_has(4);
  @$pb.TagNumber(5)
  void clearOutlineLevel() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get isCollapsed => $_getBF(5);
  @$pb.TagNumber(6)
  set isCollapsed($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasIsCollapsed() => $_has(5);
  @$pb.TagNumber(6)
  void clearIsCollapsed() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.List<$core.int> get data => $_getN(6);
  @$pb.TagNumber(7)
  set data($core.List<$core.int> value) => $_setBytes(6, value);
  @$pb.TagNumber(7)
  $core.bool hasData() => $_has(6);
  @$pb.TagNumber(7)
  void clearData() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get status => $_getIZ(7);
  @$pb.TagNumber(8)
  set status($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasStatus() => $_has(7);
  @$pb.TagNumber(8)
  void clearStatus() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.bool get span => $_getBF(8);
  @$pb.TagNumber(9)
  set span($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasSpan() => $_has(8);
  @$pb.TagNumber(9)
  void clearSpan() => $_clearField(9);

  @$pb.TagNumber(10)
  PinPosition get pin => $_getN(9);
  @$pb.TagNumber(10)
  set pin(PinPosition value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasPin() => $_has(9);
  @$pb.TagNumber(10)
  void clearPin() => $_clearField(10);

  @$pb.TagNumber(11)
  StickyEdge get sticky => $_getN(10);
  @$pb.TagNumber(11)
  set sticky(StickyEdge value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasSticky() => $_has(10);
  @$pb.TagNumber(11)
  void clearSticky() => $_clearField(11);
}

class DefineRowsRequest extends $pb.GeneratedMessage {
  factory DefineRowsRequest({
    $fixnum.Int64? gridId,
    $core.Iterable<RowDef>? rows,
  }) {
    final result = create();
    if (gridId != null) result.gridId = gridId;
    if (rows != null) result.rows.addAll(rows);
    return result;
  }

  DefineRowsRequest._();

  factory DefineRowsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DefineRowsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DefineRowsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'gridId')
    ..pPM<RowDef>(2, _omitFieldNames ? '' : 'rows', subBuilder: RowDef.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DefineRowsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DefineRowsRequest copyWith(void Function(DefineRowsRequest) updates) =>
      super.copyWith((message) => updates(message as DefineRowsRequest))
          as DefineRowsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DefineRowsRequest create() => DefineRowsRequest._();
  @$core.override
  DefineRowsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DefineRowsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DefineRowsRequest>(create);
  static DefineRowsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get gridId => $_getI64(0);
  @$pb.TagNumber(1)
  set gridId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGridId() => $_has(0);
  @$pb.TagNumber(1)
  void clearGridId() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<RowDef> get rows => $_getList(1);
}

class CellUpdate extends $pb.GeneratedMessage {
  factory CellUpdate({
    $core.int? row,
    $core.int? col,
    CellValue? value,
    CellStyle? style,
    CheckedState? checked,
    ImageData? picture,
    ImageAlignment? pictureAlign,
    ImageData? buttonPicture,
    $core.String? dropdownItems,
    StickyEdge? stickyRow,
    StickyEdge? stickyCol,
    CellInteraction? interaction,
  }) {
    final result = create();
    if (row != null) result.row = row;
    if (col != null) result.col = col;
    if (value != null) result.value = value;
    if (style != null) result.style = style;
    if (checked != null) result.checked = checked;
    if (picture != null) result.picture = picture;
    if (pictureAlign != null) result.pictureAlign = pictureAlign;
    if (buttonPicture != null) result.buttonPicture = buttonPicture;
    if (dropdownItems != null) result.dropdownItems = dropdownItems;
    if (stickyRow != null) result.stickyRow = stickyRow;
    if (stickyCol != null) result.stickyCol = stickyCol;
    if (interaction != null) result.interaction = interaction;
    return result;
  }

  CellUpdate._();

  factory CellUpdate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CellUpdate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CellUpdate',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'row')
    ..aI(2, _omitFieldNames ? '' : 'col')
    ..aOM<CellValue>(3, _omitFieldNames ? '' : 'value',
        subBuilder: CellValue.create)
    ..aOM<CellStyle>(4, _omitFieldNames ? '' : 'style',
        subBuilder: CellStyle.create)
    ..aE<CheckedState>(5, _omitFieldNames ? '' : 'checked',
        enumValues: CheckedState.values)
    ..aOM<ImageData>(6, _omitFieldNames ? '' : 'picture',
        subBuilder: ImageData.create)
    ..aE<ImageAlignment>(7, _omitFieldNames ? '' : 'pictureAlign',
        enumValues: ImageAlignment.values)
    ..aOM<ImageData>(8, _omitFieldNames ? '' : 'buttonPicture',
        subBuilder: ImageData.create)
    ..aOS(9, _omitFieldNames ? '' : 'dropdownItems')
    ..aE<StickyEdge>(10, _omitFieldNames ? '' : 'stickyRow',
        enumValues: StickyEdge.values)
    ..aE<StickyEdge>(11, _omitFieldNames ? '' : 'stickyCol',
        enumValues: StickyEdge.values)
    ..aE<CellInteraction>(12, _omitFieldNames ? '' : 'interaction',
        enumValues: CellInteraction.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CellUpdate clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CellUpdate copyWith(void Function(CellUpdate) updates) =>
      super.copyWith((message) => updates(message as CellUpdate)) as CellUpdate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CellUpdate create() => CellUpdate._();
  @$core.override
  CellUpdate createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CellUpdate getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CellUpdate>(create);
  static CellUpdate? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get row => $_getIZ(0);
  @$pb.TagNumber(1)
  set row($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRow() => $_has(0);
  @$pb.TagNumber(1)
  void clearRow() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get col => $_getIZ(1);
  @$pb.TagNumber(2)
  set col($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCol() => $_has(1);
  @$pb.TagNumber(2)
  void clearCol() => $_clearField(2);

  @$pb.TagNumber(3)
  CellValue get value => $_getN(2);
  @$pb.TagNumber(3)
  set value(CellValue value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasValue() => $_has(2);
  @$pb.TagNumber(3)
  void clearValue() => $_clearField(3);
  @$pb.TagNumber(3)
  CellValue ensureValue() => $_ensure(2);

  @$pb.TagNumber(4)
  CellStyle get style => $_getN(3);
  @$pb.TagNumber(4)
  set style(CellStyle value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasStyle() => $_has(3);
  @$pb.TagNumber(4)
  void clearStyle() => $_clearField(4);
  @$pb.TagNumber(4)
  CellStyle ensureStyle() => $_ensure(3);

  @$pb.TagNumber(5)
  CheckedState get checked => $_getN(4);
  @$pb.TagNumber(5)
  set checked(CheckedState value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasChecked() => $_has(4);
  @$pb.TagNumber(5)
  void clearChecked() => $_clearField(5);

  @$pb.TagNumber(6)
  ImageData get picture => $_getN(5);
  @$pb.TagNumber(6)
  set picture(ImageData value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasPicture() => $_has(5);
  @$pb.TagNumber(6)
  void clearPicture() => $_clearField(6);
  @$pb.TagNumber(6)
  ImageData ensurePicture() => $_ensure(5);

  @$pb.TagNumber(7)
  ImageAlignment get pictureAlign => $_getN(6);
  @$pb.TagNumber(7)
  set pictureAlign(ImageAlignment value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasPictureAlign() => $_has(6);
  @$pb.TagNumber(7)
  void clearPictureAlign() => $_clearField(7);

  @$pb.TagNumber(8)
  ImageData get buttonPicture => $_getN(7);
  @$pb.TagNumber(8)
  set buttonPicture(ImageData value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasButtonPicture() => $_has(7);
  @$pb.TagNumber(8)
  void clearButtonPicture() => $_clearField(8);
  @$pb.TagNumber(8)
  ImageData ensureButtonPicture() => $_ensure(7);

  /// Pipe-delimited dropdown items; prefix with `|` to make the list editable.
  @$pb.TagNumber(9)
  $core.String get dropdownItems => $_getSZ(8);
  @$pb.TagNumber(9)
  set dropdownItems($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasDropdownItems() => $_has(8);
  @$pb.TagNumber(9)
  void clearDropdownItems() => $_clearField(9);

  @$pb.TagNumber(10)
  StickyEdge get stickyRow => $_getN(9);
  @$pb.TagNumber(10)
  set stickyRow(StickyEdge value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasStickyRow() => $_has(9);
  @$pb.TagNumber(10)
  void clearStickyRow() => $_clearField(10);

  @$pb.TagNumber(11)
  StickyEdge get stickyCol => $_getN(10);
  @$pb.TagNumber(11)
  set stickyCol(StickyEdge value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasStickyCol() => $_has(10);
  @$pb.TagNumber(11)
  void clearStickyCol() => $_clearField(11);

  @$pb.TagNumber(12)
  CellInteraction get interaction => $_getN(11);
  @$pb.TagNumber(12)
  set interaction(CellInteraction value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasInteraction() => $_has(11);
  @$pb.TagNumber(12)
  void clearInteraction() => $_clearField(12);
}

class UpdateCellsRequest extends $pb.GeneratedMessage {
  factory UpdateCellsRequest({
    $fixnum.Int64? gridId,
    $core.Iterable<CellUpdate>? cells,
    $core.bool? atomic,
  }) {
    final result = create();
    if (gridId != null) result.gridId = gridId;
    if (cells != null) result.cells.addAll(cells);
    if (atomic != null) result.atomic = atomic;
    return result;
  }

  UpdateCellsRequest._();

  factory UpdateCellsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateCellsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateCellsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'gridId')
    ..pPM<CellUpdate>(2, _omitFieldNames ? '' : 'cells',
        subBuilder: CellUpdate.create)
    ..aOB(3, _omitFieldNames ? '' : 'atomic')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateCellsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateCellsRequest copyWith(void Function(UpdateCellsRequest) updates) =>
      super.copyWith((message) => updates(message as UpdateCellsRequest))
          as UpdateCellsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateCellsRequest create() => UpdateCellsRequest._();
  @$core.override
  UpdateCellsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateCellsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateCellsRequest>(create);
  static UpdateCellsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get gridId => $_getI64(0);
  @$pb.TagNumber(1)
  set gridId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGridId() => $_has(0);
  @$pb.TagNumber(1)
  void clearGridId() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<CellUpdate> get cells => $_getList(1);

  @$pb.TagNumber(3)
  $core.bool get atomic => $_getBF(2);
  @$pb.TagNumber(3)
  set atomic($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAtomic() => $_has(2);
  @$pb.TagNumber(3)
  void clearAtomic() => $_clearField(3);
}

class GetCellsRequest extends $pb.GeneratedMessage {
  factory GetCellsRequest({
    $fixnum.Int64? gridId,
    $core.int? row1,
    $core.int? col1,
    $core.int? row2,
    $core.int? col2,
    $core.bool? includeStyle,
    $core.bool? includeChecked,
    $core.bool? includeTyped,
  }) {
    final result = create();
    if (gridId != null) result.gridId = gridId;
    if (row1 != null) result.row1 = row1;
    if (col1 != null) result.col1 = col1;
    if (row2 != null) result.row2 = row2;
    if (col2 != null) result.col2 = col2;
    if (includeStyle != null) result.includeStyle = includeStyle;
    if (includeChecked != null) result.includeChecked = includeChecked;
    if (includeTyped != null) result.includeTyped = includeTyped;
    return result;
  }

  GetCellsRequest._();

  factory GetCellsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetCellsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetCellsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'gridId')
    ..aI(2, _omitFieldNames ? '' : 'row1')
    ..aI(3, _omitFieldNames ? '' : 'col1')
    ..aI(4, _omitFieldNames ? '' : 'row2')
    ..aI(5, _omitFieldNames ? '' : 'col2')
    ..aOB(6, _omitFieldNames ? '' : 'includeStyle')
    ..aOB(7, _omitFieldNames ? '' : 'includeChecked')
    ..aOB(8, _omitFieldNames ? '' : 'includeTyped')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetCellsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetCellsRequest copyWith(void Function(GetCellsRequest) updates) =>
      super.copyWith((message) => updates(message as GetCellsRequest))
          as GetCellsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetCellsRequest create() => GetCellsRequest._();
  @$core.override
  GetCellsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetCellsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetCellsRequest>(create);
  static GetCellsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get gridId => $_getI64(0);
  @$pb.TagNumber(1)
  set gridId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGridId() => $_has(0);
  @$pb.TagNumber(1)
  void clearGridId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get row1 => $_getIZ(1);
  @$pb.TagNumber(2)
  set row1($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRow1() => $_has(1);
  @$pb.TagNumber(2)
  void clearRow1() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get col1 => $_getIZ(2);
  @$pb.TagNumber(3)
  set col1($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCol1() => $_has(2);
  @$pb.TagNumber(3)
  void clearCol1() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get row2 => $_getIZ(3);
  @$pb.TagNumber(4)
  set row2($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRow2() => $_has(3);
  @$pb.TagNumber(4)
  void clearRow2() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get col2 => $_getIZ(4);
  @$pb.TagNumber(5)
  set col2($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCol2() => $_has(4);
  @$pb.TagNumber(5)
  void clearCol2() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get includeStyle => $_getBF(5);
  @$pb.TagNumber(6)
  set includeStyle($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasIncludeStyle() => $_has(5);
  @$pb.TagNumber(6)
  void clearIncludeStyle() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.bool get includeChecked => $_getBF(6);
  @$pb.TagNumber(7)
  set includeChecked($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasIncludeChecked() => $_has(6);
  @$pb.TagNumber(7)
  void clearIncludeChecked() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.bool get includeTyped => $_getBF(7);
  @$pb.TagNumber(8)
  set includeTyped($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasIncludeTyped() => $_has(7);
  @$pb.TagNumber(8)
  void clearIncludeTyped() => $_clearField(8);
}

class CellData extends $pb.GeneratedMessage {
  factory CellData({
    $core.int? row,
    $core.int? col,
    CellValue? value,
    CellStyle? style,
    CheckedState? checked,
    CellInteraction? interaction,
  }) {
    final result = create();
    if (row != null) result.row = row;
    if (col != null) result.col = col;
    if (value != null) result.value = value;
    if (style != null) result.style = style;
    if (checked != null) result.checked = checked;
    if (interaction != null) result.interaction = interaction;
    return result;
  }

  CellData._();

  factory CellData.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CellData.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CellData',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'row')
    ..aI(2, _omitFieldNames ? '' : 'col')
    ..aOM<CellValue>(3, _omitFieldNames ? '' : 'value',
        subBuilder: CellValue.create)
    ..aOM<CellStyle>(4, _omitFieldNames ? '' : 'style',
        subBuilder: CellStyle.create)
    ..aE<CheckedState>(5, _omitFieldNames ? '' : 'checked',
        enumValues: CheckedState.values)
    ..aE<CellInteraction>(6, _omitFieldNames ? '' : 'interaction',
        enumValues: CellInteraction.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CellData clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CellData copyWith(void Function(CellData) updates) =>
      super.copyWith((message) => updates(message as CellData)) as CellData;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CellData create() => CellData._();
  @$core.override
  CellData createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CellData getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CellData>(create);
  static CellData? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get row => $_getIZ(0);
  @$pb.TagNumber(1)
  set row($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRow() => $_has(0);
  @$pb.TagNumber(1)
  void clearRow() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get col => $_getIZ(1);
  @$pb.TagNumber(2)
  set col($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCol() => $_has(1);
  @$pb.TagNumber(2)
  void clearCol() => $_clearField(2);

  @$pb.TagNumber(3)
  CellValue get value => $_getN(2);
  @$pb.TagNumber(3)
  set value(CellValue value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasValue() => $_has(2);
  @$pb.TagNumber(3)
  void clearValue() => $_clearField(3);
  @$pb.TagNumber(3)
  CellValue ensureValue() => $_ensure(2);

  @$pb.TagNumber(4)
  CellStyle get style => $_getN(3);
  @$pb.TagNumber(4)
  set style(CellStyle value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasStyle() => $_has(3);
  @$pb.TagNumber(4)
  void clearStyle() => $_clearField(4);
  @$pb.TagNumber(4)
  CellStyle ensureStyle() => $_ensure(3);

  @$pb.TagNumber(5)
  CheckedState get checked => $_getN(4);
  @$pb.TagNumber(5)
  set checked(CheckedState value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasChecked() => $_has(4);
  @$pb.TagNumber(5)
  void clearChecked() => $_clearField(5);

  @$pb.TagNumber(6)
  CellInteraction get interaction => $_getN(5);
  @$pb.TagNumber(6)
  set interaction(CellInteraction value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasInteraction() => $_has(5);
  @$pb.TagNumber(6)
  void clearInteraction() => $_clearField(6);
}

class CellsResponse extends $pb.GeneratedMessage {
  factory CellsResponse({
    $core.Iterable<CellData>? cells,
  }) {
    final result = create();
    if (cells != null) result.cells.addAll(cells);
    return result;
  }

  CellsResponse._();

  factory CellsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CellsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CellsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..pPM<CellData>(1, _omitFieldNames ? '' : 'cells',
        subBuilder: CellData.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CellsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CellsResponse copyWith(void Function(CellsResponse) updates) =>
      super.copyWith((message) => updates(message as CellsResponse))
          as CellsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CellsResponse create() => CellsResponse._();
  @$core.override
  CellsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CellsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CellsResponse>(create);
  static CellsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<CellData> get cells => $_getList(0);
}

class TypeViolation extends $pb.GeneratedMessage {
  factory TypeViolation({
    $core.int? row,
    $core.int? col,
    ColumnDataType? expected,
    CellValue? actual,
    $core.String? reason,
  }) {
    final result = create();
    if (row != null) result.row = row;
    if (col != null) result.col = col;
    if (expected != null) result.expected = expected;
    if (actual != null) result.actual = actual;
    if (reason != null) result.reason = reason;
    return result;
  }

  TypeViolation._();

  factory TypeViolation.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TypeViolation.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TypeViolation',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'row')
    ..aI(2, _omitFieldNames ? '' : 'col')
    ..aE<ColumnDataType>(3, _omitFieldNames ? '' : 'expected',
        enumValues: ColumnDataType.values)
    ..aOM<CellValue>(4, _omitFieldNames ? '' : 'actual',
        subBuilder: CellValue.create)
    ..aOS(5, _omitFieldNames ? '' : 'reason')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TypeViolation clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TypeViolation copyWith(void Function(TypeViolation) updates) =>
      super.copyWith((message) => updates(message as TypeViolation))
          as TypeViolation;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TypeViolation create() => TypeViolation._();
  @$core.override
  TypeViolation createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TypeViolation getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TypeViolation>(create);
  static TypeViolation? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get row => $_getIZ(0);
  @$pb.TagNumber(1)
  set row($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRow() => $_has(0);
  @$pb.TagNumber(1)
  void clearRow() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get col => $_getIZ(1);
  @$pb.TagNumber(2)
  set col($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCol() => $_has(1);
  @$pb.TagNumber(2)
  void clearCol() => $_clearField(2);

  @$pb.TagNumber(3)
  ColumnDataType get expected => $_getN(2);
  @$pb.TagNumber(3)
  set expected(ColumnDataType value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasExpected() => $_has(2);
  @$pb.TagNumber(3)
  void clearExpected() => $_clearField(3);

  @$pb.TagNumber(4)
  CellValue get actual => $_getN(3);
  @$pb.TagNumber(4)
  set actual(CellValue value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasActual() => $_has(3);
  @$pb.TagNumber(4)
  void clearActual() => $_clearField(4);
  @$pb.TagNumber(4)
  CellValue ensureActual() => $_ensure(3);

  @$pb.TagNumber(5)
  $core.String get reason => $_getSZ(4);
  @$pb.TagNumber(5)
  set reason($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasReason() => $_has(4);
  @$pb.TagNumber(5)
  void clearReason() => $_clearField(5);
}

class WriteResult extends $pb.GeneratedMessage {
  factory WriteResult({
    $core.int? writtenCount,
    $core.int? rejectedCount,
    $core.Iterable<TypeViolation>? violations,
  }) {
    final result = create();
    if (writtenCount != null) result.writtenCount = writtenCount;
    if (rejectedCount != null) result.rejectedCount = rejectedCount;
    if (violations != null) result.violations.addAll(violations);
    return result;
  }

  WriteResult._();

  factory WriteResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory WriteResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WriteResult',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'writtenCount')
    ..aI(2, _omitFieldNames ? '' : 'rejectedCount')
    ..pPM<TypeViolation>(3, _omitFieldNames ? '' : 'violations',
        subBuilder: TypeViolation.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WriteResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WriteResult copyWith(void Function(WriteResult) updates) =>
      super.copyWith((message) => updates(message as WriteResult))
          as WriteResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static WriteResult create() => WriteResult._();
  @$core.override
  WriteResult createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static WriteResult getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<WriteResult>(create);
  static WriteResult? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get writtenCount => $_getIZ(0);
  @$pb.TagNumber(1)
  set writtenCount($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWrittenCount() => $_has(0);
  @$pb.TagNumber(1)
  void clearWrittenCount() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get rejectedCount => $_getIZ(1);
  @$pb.TagNumber(2)
  set rejectedCount($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRejectedCount() => $_has(1);
  @$pb.TagNumber(2)
  void clearRejectedCount() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbList<TypeViolation> get violations => $_getList(2);
}

class LoadTableRequest extends $pb.GeneratedMessage {
  factory LoadTableRequest({
    $fixnum.Int64? gridId,
    $core.int? rows,
    $core.int? cols,
    $core.Iterable<CellValue>? values,
    $core.bool? atomic,
  }) {
    final result = create();
    if (gridId != null) result.gridId = gridId;
    if (rows != null) result.rows = rows;
    if (cols != null) result.cols = cols;
    if (values != null) result.values.addAll(values);
    if (atomic != null) result.atomic = atomic;
    return result;
  }

  LoadTableRequest._();

  factory LoadTableRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory LoadTableRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LoadTableRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'gridId')
    ..aI(2, _omitFieldNames ? '' : 'rows')
    ..aI(3, _omitFieldNames ? '' : 'cols')
    ..pPM<CellValue>(4, _omitFieldNames ? '' : 'values',
        subBuilder: CellValue.create)
    ..aOB(5, _omitFieldNames ? '' : 'atomic')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoadTableRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoadTableRequest copyWith(void Function(LoadTableRequest) updates) =>
      super.copyWith((message) => updates(message as LoadTableRequest))
          as LoadTableRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LoadTableRequest create() => LoadTableRequest._();
  @$core.override
  LoadTableRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static LoadTableRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LoadTableRequest>(create);
  static LoadTableRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get gridId => $_getI64(0);
  @$pb.TagNumber(1)
  set gridId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGridId() => $_has(0);
  @$pb.TagNumber(1)
  void clearGridId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get rows => $_getIZ(1);
  @$pb.TagNumber(2)
  set rows($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRows() => $_has(1);
  @$pb.TagNumber(2)
  void clearRows() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get cols => $_getIZ(2);
  @$pb.TagNumber(3)
  set cols($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCols() => $_has(2);
  @$pb.TagNumber(3)
  void clearCols() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<CellValue> get values => $_getList(3);

  @$pb.TagNumber(5)
  $core.bool get atomic => $_getBF(4);
  @$pb.TagNumber(5)
  set atomic($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasAtomic() => $_has(4);
  @$pb.TagNumber(5)
  void clearAtomic() => $_clearField(5);
}

enum FieldMapping_Target { colIndex, colKey, notSet }

class FieldMapping extends $pb.GeneratedMessage {
  factory FieldMapping({
    $core.String? field_1,
    $core.int? colIndex,
    $core.String? colKey,
  }) {
    final result = create();
    if (field_1 != null) result.field_1 = field_1;
    if (colIndex != null) result.colIndex = colIndex;
    if (colKey != null) result.colKey = colKey;
    return result;
  }

  FieldMapping._();

  factory FieldMapping.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory FieldMapping.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, FieldMapping_Target>
      _FieldMapping_TargetByTag = {
    2: FieldMapping_Target.colIndex,
    3: FieldMapping_Target.colKey,
    0: FieldMapping_Target.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FieldMapping',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..oo(0, [2, 3])
    ..aOS(1, _omitFieldNames ? '' : 'field')
    ..aI(2, _omitFieldNames ? '' : 'colIndex')
    ..aOS(3, _omitFieldNames ? '' : 'colKey')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FieldMapping clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FieldMapping copyWith(void Function(FieldMapping) updates) =>
      super.copyWith((message) => updates(message as FieldMapping))
          as FieldMapping;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FieldMapping create() => FieldMapping._();
  @$core.override
  FieldMapping createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static FieldMapping getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FieldMapping>(create);
  static FieldMapping? _defaultInstance;

  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  FieldMapping_Target whichTarget() =>
      _FieldMapping_TargetByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  void clearTarget() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $core.String get field_1 => $_getSZ(0);
  @$pb.TagNumber(1)
  set field_1($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasField_1() => $_has(0);
  @$pb.TagNumber(1)
  void clearField_1() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get colIndex => $_getIZ(1);
  @$pb.TagNumber(2)
  set colIndex($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasColIndex() => $_has(1);
  @$pb.TagNumber(2)
  void clearColIndex() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get colKey => $_getSZ(2);
  @$pb.TagNumber(3)
  set colKey($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasColKey() => $_has(2);
  @$pb.TagNumber(3)
  void clearColKey() => $_clearField(3);
}

class CsvOptions extends $pb.GeneratedMessage {
  factory CsvOptions({
    $core.String? delimiter,
    $core.String? quoteChar,
    $core.bool? trimWhitespace,
  }) {
    final result = create();
    if (delimiter != null) result.delimiter = delimiter;
    if (quoteChar != null) result.quoteChar = quoteChar;
    if (trimWhitespace != null) result.trimWhitespace = trimWhitespace;
    return result;
  }

  CsvOptions._();

  factory CsvOptions.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CsvOptions.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CsvOptions',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'delimiter')
    ..aOS(2, _omitFieldNames ? '' : 'quoteChar')
    ..aOB(3, _omitFieldNames ? '' : 'trimWhitespace')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CsvOptions clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CsvOptions copyWith(void Function(CsvOptions) updates) =>
      super.copyWith((message) => updates(message as CsvOptions)) as CsvOptions;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CsvOptions create() => CsvOptions._();
  @$core.override
  CsvOptions createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CsvOptions getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CsvOptions>(create);
  static CsvOptions? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get delimiter => $_getSZ(0);
  @$pb.TagNumber(1)
  set delimiter($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDelimiter() => $_has(0);
  @$pb.TagNumber(1)
  void clearDelimiter() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get quoteChar => $_getSZ(1);
  @$pb.TagNumber(2)
  set quoteChar($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasQuoteChar() => $_has(1);
  @$pb.TagNumber(2)
  void clearQuoteChar() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get trimWhitespace => $_getBF(2);
  @$pb.TagNumber(3)
  set trimWhitespace($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTrimWhitespace() => $_has(2);
  @$pb.TagNumber(3)
  void clearTrimWhitespace() => $_clearField(3);
}

class JsonOptions extends $pb.GeneratedMessage {
  factory JsonOptions({
    $core.String? dataPath,
  }) {
    final result = create();
    if (dataPath != null) result.dataPath = dataPath;
    return result;
  }

  JsonOptions._();

  factory JsonOptions.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory JsonOptions.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'JsonOptions',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'dataPath')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JsonOptions clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JsonOptions copyWith(void Function(JsonOptions) updates) =>
      super.copyWith((message) => updates(message as JsonOptions))
          as JsonOptions;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static JsonOptions create() => JsonOptions._();
  @$core.override
  JsonOptions createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static JsonOptions getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<JsonOptions>(create);
  static JsonOptions? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get dataPath => $_getSZ(0);
  @$pb.TagNumber(1)
  set dataPath($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDataPath() => $_has(0);
  @$pb.TagNumber(1)
  void clearDataPath() => $_clearField(1);
}

enum LoadDataOptions_Format { csv, json, notSet }

class LoadDataOptions extends $pb.GeneratedMessage {
  factory LoadDataOptions({
    CsvOptions? csv,
    JsonOptions? json,
    HeaderPolicy? headerPolicy,
    $core.Iterable<FieldMapping>? fieldMap,
    TypePolicy? typePolicy,
    CoercionMode? coercion,
    WriteErrorMode? errorMode,
    $core.String? dateFormat,
    $core.String? decimalChar,
    $core.bool? autoCreateColumns,
    LoadMode? mode,
    $core.bool? atomic,
    $core.int? skipRows,
    $core.int? maxRows,
  }) {
    final result = create();
    if (csv != null) result.csv = csv;
    if (json != null) result.json = json;
    if (headerPolicy != null) result.headerPolicy = headerPolicy;
    if (fieldMap != null) result.fieldMap.addAll(fieldMap);
    if (typePolicy != null) result.typePolicy = typePolicy;
    if (coercion != null) result.coercion = coercion;
    if (errorMode != null) result.errorMode = errorMode;
    if (dateFormat != null) result.dateFormat = dateFormat;
    if (decimalChar != null) result.decimalChar = decimalChar;
    if (autoCreateColumns != null) result.autoCreateColumns = autoCreateColumns;
    if (mode != null) result.mode = mode;
    if (atomic != null) result.atomic = atomic;
    if (skipRows != null) result.skipRows = skipRows;
    if (maxRows != null) result.maxRows = maxRows;
    return result;
  }

  LoadDataOptions._();

  factory LoadDataOptions.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory LoadDataOptions.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, LoadDataOptions_Format>
      _LoadDataOptions_FormatByTag = {
    1: LoadDataOptions_Format.csv,
    2: LoadDataOptions_Format.json,
    0: LoadDataOptions_Format.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LoadDataOptions',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..oo(0, [1, 2])
    ..aOM<CsvOptions>(1, _omitFieldNames ? '' : 'csv',
        subBuilder: CsvOptions.create)
    ..aOM<JsonOptions>(2, _omitFieldNames ? '' : 'json',
        subBuilder: JsonOptions.create)
    ..aE<HeaderPolicy>(10, _omitFieldNames ? '' : 'headerPolicy',
        enumValues: HeaderPolicy.values)
    ..pPM<FieldMapping>(11, _omitFieldNames ? '' : 'fieldMap',
        subBuilder: FieldMapping.create)
    ..aE<TypePolicy>(12, _omitFieldNames ? '' : 'typePolicy',
        enumValues: TypePolicy.values)
    ..aE<CoercionMode>(13, _omitFieldNames ? '' : 'coercion',
        enumValues: CoercionMode.values)
    ..aE<WriteErrorMode>(14, _omitFieldNames ? '' : 'errorMode',
        enumValues: WriteErrorMode.values)
    ..aOS(15, _omitFieldNames ? '' : 'dateFormat')
    ..aOS(16, _omitFieldNames ? '' : 'decimalChar')
    ..aOB(17, _omitFieldNames ? '' : 'autoCreateColumns')
    ..aE<LoadMode>(18, _omitFieldNames ? '' : 'mode',
        enumValues: LoadMode.values)
    ..aOB(19, _omitFieldNames ? '' : 'atomic')
    ..aI(20, _omitFieldNames ? '' : 'skipRows')
    ..aI(21, _omitFieldNames ? '' : 'maxRows')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoadDataOptions clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoadDataOptions copyWith(void Function(LoadDataOptions) updates) =>
      super.copyWith((message) => updates(message as LoadDataOptions))
          as LoadDataOptions;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LoadDataOptions create() => LoadDataOptions._();
  @$core.override
  LoadDataOptions createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static LoadDataOptions getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LoadDataOptions>(create);
  static LoadDataOptions? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  LoadDataOptions_Format whichFormat() =>
      _LoadDataOptions_FormatByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  void clearFormat() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  CsvOptions get csv => $_getN(0);
  @$pb.TagNumber(1)
  set csv(CsvOptions value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasCsv() => $_has(0);
  @$pb.TagNumber(1)
  void clearCsv() => $_clearField(1);
  @$pb.TagNumber(1)
  CsvOptions ensureCsv() => $_ensure(0);

  @$pb.TagNumber(2)
  JsonOptions get json => $_getN(1);
  @$pb.TagNumber(2)
  set json(JsonOptions value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasJson() => $_has(1);
  @$pb.TagNumber(2)
  void clearJson() => $_clearField(2);
  @$pb.TagNumber(2)
  JsonOptions ensureJson() => $_ensure(1);

  @$pb.TagNumber(10)
  HeaderPolicy get headerPolicy => $_getN(2);
  @$pb.TagNumber(10)
  set headerPolicy(HeaderPolicy value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasHeaderPolicy() => $_has(2);
  @$pb.TagNumber(10)
  void clearHeaderPolicy() => $_clearField(10);

  @$pb.TagNumber(11)
  $pb.PbList<FieldMapping> get fieldMap => $_getList(3);

  @$pb.TagNumber(12)
  TypePolicy get typePolicy => $_getN(4);
  @$pb.TagNumber(12)
  set typePolicy(TypePolicy value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasTypePolicy() => $_has(4);
  @$pb.TagNumber(12)
  void clearTypePolicy() => $_clearField(12);

  @$pb.TagNumber(13)
  CoercionMode get coercion => $_getN(5);
  @$pb.TagNumber(13)
  set coercion(CoercionMode value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasCoercion() => $_has(5);
  @$pb.TagNumber(13)
  void clearCoercion() => $_clearField(13);

  @$pb.TagNumber(14)
  WriteErrorMode get errorMode => $_getN(6);
  @$pb.TagNumber(14)
  set errorMode(WriteErrorMode value) => $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasErrorMode() => $_has(6);
  @$pb.TagNumber(14)
  void clearErrorMode() => $_clearField(14);

  @$pb.TagNumber(15)
  $core.String get dateFormat => $_getSZ(7);
  @$pb.TagNumber(15)
  set dateFormat($core.String value) => $_setString(7, value);
  @$pb.TagNumber(15)
  $core.bool hasDateFormat() => $_has(7);
  @$pb.TagNumber(15)
  void clearDateFormat() => $_clearField(15);

  @$pb.TagNumber(16)
  $core.String get decimalChar => $_getSZ(8);
  @$pb.TagNumber(16)
  set decimalChar($core.String value) => $_setString(8, value);
  @$pb.TagNumber(16)
  $core.bool hasDecimalChar() => $_has(8);
  @$pb.TagNumber(16)
  void clearDecimalChar() => $_clearField(16);

  @$pb.TagNumber(17)
  $core.bool get autoCreateColumns => $_getBF(9);
  @$pb.TagNumber(17)
  set autoCreateColumns($core.bool value) => $_setBool(9, value);
  @$pb.TagNumber(17)
  $core.bool hasAutoCreateColumns() => $_has(9);
  @$pb.TagNumber(17)
  void clearAutoCreateColumns() => $_clearField(17);

  @$pb.TagNumber(18)
  LoadMode get mode => $_getN(10);
  @$pb.TagNumber(18)
  set mode(LoadMode value) => $_setField(18, value);
  @$pb.TagNumber(18)
  $core.bool hasMode() => $_has(10);
  @$pb.TagNumber(18)
  void clearMode() => $_clearField(18);

  @$pb.TagNumber(19)
  $core.bool get atomic => $_getBF(11);
  @$pb.TagNumber(19)
  set atomic($core.bool value) => $_setBool(11, value);
  @$pb.TagNumber(19)
  $core.bool hasAtomic() => $_has(11);
  @$pb.TagNumber(19)
  void clearAtomic() => $_clearField(19);

  @$pb.TagNumber(20)
  $core.int get skipRows => $_getIZ(12);
  @$pb.TagNumber(20)
  set skipRows($core.int value) => $_setSignedInt32(12, value);
  @$pb.TagNumber(20)
  $core.bool hasSkipRows() => $_has(12);
  @$pb.TagNumber(20)
  void clearSkipRows() => $_clearField(20);

  @$pb.TagNumber(21)
  $core.int get maxRows => $_getIZ(13);
  @$pb.TagNumber(21)
  set maxRows($core.int value) => $_setSignedInt32(13, value);
  @$pb.TagNumber(21)
  $core.bool hasMaxRows() => $_has(13);
  @$pb.TagNumber(21)
  void clearMaxRows() => $_clearField(21);
}

class LoadDataRequest extends $pb.GeneratedMessage {
  factory LoadDataRequest({
    $fixnum.Int64? gridId,
    $core.List<$core.int>? data,
    LoadDataOptions? options,
  }) {
    final result = create();
    if (gridId != null) result.gridId = gridId;
    if (data != null) result.data = data;
    if (options != null) result.options = options;
    return result;
  }

  LoadDataRequest._();

  factory LoadDataRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory LoadDataRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LoadDataRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'gridId')
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OY)
    ..aOM<LoadDataOptions>(3, _omitFieldNames ? '' : 'options',
        subBuilder: LoadDataOptions.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoadDataRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoadDataRequest copyWith(void Function(LoadDataRequest) updates) =>
      super.copyWith((message) => updates(message as LoadDataRequest))
          as LoadDataRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LoadDataRequest create() => LoadDataRequest._();
  @$core.override
  LoadDataRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static LoadDataRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LoadDataRequest>(create);
  static LoadDataRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get gridId => $_getI64(0);
  @$pb.TagNumber(1)
  set gridId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGridId() => $_has(0);
  @$pb.TagNumber(1)
  void clearGridId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get data => $_getN(1);
  @$pb.TagNumber(2)
  set data($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasData() => $_has(1);
  @$pb.TagNumber(2)
  void clearData() => $_clearField(2);

  @$pb.TagNumber(3)
  LoadDataOptions get options => $_getN(2);
  @$pb.TagNumber(3)
  set options(LoadDataOptions value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasOptions() => $_has(2);
  @$pb.TagNumber(3)
  void clearOptions() => $_clearField(3);
  @$pb.TagNumber(3)
  LoadDataOptions ensureOptions() => $_ensure(2);
}

class LoadDataResult extends $pb.GeneratedMessage {
  factory LoadDataResult({
    LoadDataStatus? status,
    $core.int? rows,
    $core.int? cols,
    $core.int? rejected,
    $core.Iterable<TypeViolation>? violations,
    $core.Iterable<$core.String>? warnings,
    $core.Iterable<ColumnDef>? inferredColumns,
  }) {
    final result = create();
    if (status != null) result.status = status;
    if (rows != null) result.rows = rows;
    if (cols != null) result.cols = cols;
    if (rejected != null) result.rejected = rejected;
    if (violations != null) result.violations.addAll(violations);
    if (warnings != null) result.warnings.addAll(warnings);
    if (inferredColumns != null) result.inferredColumns.addAll(inferredColumns);
    return result;
  }

  LoadDataResult._();

  factory LoadDataResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory LoadDataResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LoadDataResult',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aE<LoadDataStatus>(1, _omitFieldNames ? '' : 'status',
        enumValues: LoadDataStatus.values)
    ..aI(2, _omitFieldNames ? '' : 'rows')
    ..aI(3, _omitFieldNames ? '' : 'cols')
    ..aI(4, _omitFieldNames ? '' : 'rejected')
    ..pPM<TypeViolation>(5, _omitFieldNames ? '' : 'violations',
        subBuilder: TypeViolation.create)
    ..pPS(6, _omitFieldNames ? '' : 'warnings')
    ..pPM<ColumnDef>(7, _omitFieldNames ? '' : 'inferredColumns',
        subBuilder: ColumnDef.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoadDataResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoadDataResult copyWith(void Function(LoadDataResult) updates) =>
      super.copyWith((message) => updates(message as LoadDataResult))
          as LoadDataResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LoadDataResult create() => LoadDataResult._();
  @$core.override
  LoadDataResult createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static LoadDataResult getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LoadDataResult>(create);
  static LoadDataResult? _defaultInstance;

  @$pb.TagNumber(1)
  LoadDataStatus get status => $_getN(0);
  @$pb.TagNumber(1)
  set status(LoadDataStatus value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasStatus() => $_has(0);
  @$pb.TagNumber(1)
  void clearStatus() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get rows => $_getIZ(1);
  @$pb.TagNumber(2)
  set rows($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRows() => $_has(1);
  @$pb.TagNumber(2)
  void clearRows() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get cols => $_getIZ(2);
  @$pb.TagNumber(3)
  set cols($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCols() => $_has(2);
  @$pb.TagNumber(3)
  void clearCols() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get rejected => $_getIZ(3);
  @$pb.TagNumber(4)
  set rejected($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRejected() => $_has(3);
  @$pb.TagNumber(4)
  void clearRejected() => $_clearField(4);

  @$pb.TagNumber(5)
  $pb.PbList<TypeViolation> get violations => $_getList(4);

  @$pb.TagNumber(6)
  $pb.PbList<$core.String> get warnings => $_getList(5);

  @$pb.TagNumber(7)
  $pb.PbList<ColumnDef> get inferredColumns => $_getList(6);
}

class ClearRequest extends $pb.GeneratedMessage {
  factory ClearRequest({
    $fixnum.Int64? gridId,
    ClearScope? scope,
    ClearRegion? region,
  }) {
    final result = create();
    if (gridId != null) result.gridId = gridId;
    if (scope != null) result.scope = scope;
    if (region != null) result.region = region;
    return result;
  }

  ClearRequest._();

  factory ClearRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ClearRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ClearRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'gridId')
    ..aE<ClearScope>(2, _omitFieldNames ? '' : 'scope',
        enumValues: ClearScope.values)
    ..aE<ClearRegion>(3, _omitFieldNames ? '' : 'region',
        enumValues: ClearRegion.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClearRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClearRequest copyWith(void Function(ClearRequest) updates) =>
      super.copyWith((message) => updates(message as ClearRequest))
          as ClearRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ClearRequest create() => ClearRequest._();
  @$core.override
  ClearRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ClearRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClearRequest>(create);
  static ClearRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get gridId => $_getI64(0);
  @$pb.TagNumber(1)
  set gridId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGridId() => $_has(0);
  @$pb.TagNumber(1)
  void clearGridId() => $_clearField(1);

  @$pb.TagNumber(2)
  ClearScope get scope => $_getN(1);
  @$pb.TagNumber(2)
  set scope(ClearScope value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasScope() => $_has(1);
  @$pb.TagNumber(2)
  void clearScope() => $_clearField(2);

  @$pb.TagNumber(3)
  ClearRegion get region => $_getN(2);
  @$pb.TagNumber(3)
  set region(ClearRegion value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasRegion() => $_has(2);
  @$pb.TagNumber(3)
  void clearRegion() => $_clearField(3);
}

class InsertRowsRequest extends $pb.GeneratedMessage {
  factory InsertRowsRequest({
    $fixnum.Int64? gridId,
    $core.int? index,
    $core.int? count,
    $core.Iterable<$core.String>? text,
  }) {
    final result = create();
    if (gridId != null) result.gridId = gridId;
    if (index != null) result.index = index;
    if (count != null) result.count = count;
    if (text != null) result.text.addAll(text);
    return result;
  }

  InsertRowsRequest._();

  factory InsertRowsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory InsertRowsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'InsertRowsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'gridId')
    ..aI(2, _omitFieldNames ? '' : 'index')
    ..aI(3, _omitFieldNames ? '' : 'count')
    ..pPS(4, _omitFieldNames ? '' : 'text')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  InsertRowsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  InsertRowsRequest copyWith(void Function(InsertRowsRequest) updates) =>
      super.copyWith((message) => updates(message as InsertRowsRequest))
          as InsertRowsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static InsertRowsRequest create() => InsertRowsRequest._();
  @$core.override
  InsertRowsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static InsertRowsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<InsertRowsRequest>(create);
  static InsertRowsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get gridId => $_getI64(0);
  @$pb.TagNumber(1)
  set gridId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGridId() => $_has(0);
  @$pb.TagNumber(1)
  void clearGridId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get index => $_getIZ(1);
  @$pb.TagNumber(2)
  set index($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasIndex() => $_has(1);
  @$pb.TagNumber(2)
  void clearIndex() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get count => $_getIZ(2);
  @$pb.TagNumber(3)
  set count($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCount() => $_has(2);
  @$pb.TagNumber(3)
  void clearCount() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<$core.String> get text => $_getList(3);
}

class RemoveRowsRequest extends $pb.GeneratedMessage {
  factory RemoveRowsRequest({
    $fixnum.Int64? gridId,
    $core.int? index,
    $core.int? count,
  }) {
    final result = create();
    if (gridId != null) result.gridId = gridId;
    if (index != null) result.index = index;
    if (count != null) result.count = count;
    return result;
  }

  RemoveRowsRequest._();

  factory RemoveRowsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RemoveRowsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RemoveRowsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'gridId')
    ..aI(2, _omitFieldNames ? '' : 'index')
    ..aI(3, _omitFieldNames ? '' : 'count')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoveRowsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoveRowsRequest copyWith(void Function(RemoveRowsRequest) updates) =>
      super.copyWith((message) => updates(message as RemoveRowsRequest))
          as RemoveRowsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RemoveRowsRequest create() => RemoveRowsRequest._();
  @$core.override
  RemoveRowsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RemoveRowsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RemoveRowsRequest>(create);
  static RemoveRowsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get gridId => $_getI64(0);
  @$pb.TagNumber(1)
  set gridId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGridId() => $_has(0);
  @$pb.TagNumber(1)
  void clearGridId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get index => $_getIZ(1);
  @$pb.TagNumber(2)
  set index($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasIndex() => $_has(1);
  @$pb.TagNumber(2)
  void clearIndex() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get count => $_getIZ(2);
  @$pb.TagNumber(3)
  set count($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCount() => $_has(2);
  @$pb.TagNumber(3)
  void clearCount() => $_clearField(3);
}

class MoveColumnRequest extends $pb.GeneratedMessage {
  factory MoveColumnRequest({
    $fixnum.Int64? gridId,
    $core.int? col,
    $core.int? position,
  }) {
    final result = create();
    if (gridId != null) result.gridId = gridId;
    if (col != null) result.col = col;
    if (position != null) result.position = position;
    return result;
  }

  MoveColumnRequest._();

  factory MoveColumnRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MoveColumnRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MoveColumnRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'gridId')
    ..aI(2, _omitFieldNames ? '' : 'col')
    ..aI(3, _omitFieldNames ? '' : 'position')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MoveColumnRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MoveColumnRequest copyWith(void Function(MoveColumnRequest) updates) =>
      super.copyWith((message) => updates(message as MoveColumnRequest))
          as MoveColumnRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MoveColumnRequest create() => MoveColumnRequest._();
  @$core.override
  MoveColumnRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MoveColumnRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MoveColumnRequest>(create);
  static MoveColumnRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get gridId => $_getI64(0);
  @$pb.TagNumber(1)
  set gridId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGridId() => $_has(0);
  @$pb.TagNumber(1)
  void clearGridId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get col => $_getIZ(1);
  @$pb.TagNumber(2)
  set col($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCol() => $_has(1);
  @$pb.TagNumber(2)
  void clearCol() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get position => $_getIZ(2);
  @$pb.TagNumber(3)
  set position($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPosition() => $_has(2);
  @$pb.TagNumber(3)
  void clearPosition() => $_clearField(3);
}

class MoveRowRequest extends $pb.GeneratedMessage {
  factory MoveRowRequest({
    $fixnum.Int64? gridId,
    $core.int? row,
    $core.int? position,
  }) {
    final result = create();
    if (gridId != null) result.gridId = gridId;
    if (row != null) result.row = row;
    if (position != null) result.position = position;
    return result;
  }

  MoveRowRequest._();

  factory MoveRowRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MoveRowRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MoveRowRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'gridId')
    ..aI(2, _omitFieldNames ? '' : 'row')
    ..aI(3, _omitFieldNames ? '' : 'position')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MoveRowRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MoveRowRequest copyWith(void Function(MoveRowRequest) updates) =>
      super.copyWith((message) => updates(message as MoveRowRequest))
          as MoveRowRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MoveRowRequest create() => MoveRowRequest._();
  @$core.override
  MoveRowRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MoveRowRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MoveRowRequest>(create);
  static MoveRowRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get gridId => $_getI64(0);
  @$pb.TagNumber(1)
  set gridId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGridId() => $_has(0);
  @$pb.TagNumber(1)
  void clearGridId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get row => $_getIZ(1);
  @$pb.TagNumber(2)
  set row($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRow() => $_has(1);
  @$pb.TagNumber(2)
  void clearRow() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get position => $_getIZ(2);
  @$pb.TagNumber(3)
  set position($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPosition() => $_has(2);
  @$pb.TagNumber(3)
  void clearPosition() => $_clearField(3);
}

class SelectRequest extends $pb.GeneratedMessage {
  factory SelectRequest({
    $fixnum.Int64? gridId,
    $core.int? activeRow,
    $core.int? activeCol,
    $core.Iterable<CellRange>? ranges,
    $core.bool? show,
  }) {
    final result = create();
    if (gridId != null) result.gridId = gridId;
    if (activeRow != null) result.activeRow = activeRow;
    if (activeCol != null) result.activeCol = activeCol;
    if (ranges != null) result.ranges.addAll(ranges);
    if (show != null) result.show = show;
    return result;
  }

  SelectRequest._();

  factory SelectRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SelectRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SelectRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'gridId')
    ..aI(2, _omitFieldNames ? '' : 'activeRow')
    ..aI(3, _omitFieldNames ? '' : 'activeCol')
    ..pPM<CellRange>(4, _omitFieldNames ? '' : 'ranges',
        subBuilder: CellRange.create)
    ..aOB(5, _omitFieldNames ? '' : 'show')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SelectRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SelectRequest copyWith(void Function(SelectRequest) updates) =>
      super.copyWith((message) => updates(message as SelectRequest))
          as SelectRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SelectRequest create() => SelectRequest._();
  @$core.override
  SelectRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SelectRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SelectRequest>(create);
  static SelectRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get gridId => $_getI64(0);
  @$pb.TagNumber(1)
  set gridId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGridId() => $_has(0);
  @$pb.TagNumber(1)
  void clearGridId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get activeRow => $_getIZ(1);
  @$pb.TagNumber(2)
  set activeRow($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasActiveRow() => $_has(1);
  @$pb.TagNumber(2)
  void clearActiveRow() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get activeCol => $_getIZ(2);
  @$pb.TagNumber(3)
  set activeCol($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasActiveCol() => $_has(2);
  @$pb.TagNumber(3)
  void clearActiveCol() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<CellRange> get ranges => $_getList(3);

  @$pb.TagNumber(5)
  $core.bool get show => $_getBF(4);
  @$pb.TagNumber(5)
  set show($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasShow() => $_has(4);
  @$pb.TagNumber(5)
  void clearShow() => $_clearField(5);
}

class SelectionState extends $pb.GeneratedMessage {
  factory SelectionState({
    $core.int? activeRow,
    $core.int? activeCol,
    $core.Iterable<CellRange>? ranges,
    $core.int? topRow,
    $core.int? leftCol,
    $core.int? bottomRow,
    $core.int? rightCol,
    $core.int? mouseRow,
    $core.int? mouseCol,
  }) {
    final result = create();
    if (activeRow != null) result.activeRow = activeRow;
    if (activeCol != null) result.activeCol = activeCol;
    if (ranges != null) result.ranges.addAll(ranges);
    if (topRow != null) result.topRow = topRow;
    if (leftCol != null) result.leftCol = leftCol;
    if (bottomRow != null) result.bottomRow = bottomRow;
    if (rightCol != null) result.rightCol = rightCol;
    if (mouseRow != null) result.mouseRow = mouseRow;
    if (mouseCol != null) result.mouseCol = mouseCol;
    return result;
  }

  SelectionState._();

  factory SelectionState.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SelectionState.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SelectionState',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'activeRow')
    ..aI(2, _omitFieldNames ? '' : 'activeCol')
    ..pPM<CellRange>(3, _omitFieldNames ? '' : 'ranges',
        subBuilder: CellRange.create)
    ..aI(4, _omitFieldNames ? '' : 'topRow')
    ..aI(5, _omitFieldNames ? '' : 'leftCol')
    ..aI(6, _omitFieldNames ? '' : 'bottomRow')
    ..aI(7, _omitFieldNames ? '' : 'rightCol')
    ..aI(8, _omitFieldNames ? '' : 'mouseRow')
    ..aI(9, _omitFieldNames ? '' : 'mouseCol')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SelectionState clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SelectionState copyWith(void Function(SelectionState) updates) =>
      super.copyWith((message) => updates(message as SelectionState))
          as SelectionState;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SelectionState create() => SelectionState._();
  @$core.override
  SelectionState createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SelectionState getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SelectionState>(create);
  static SelectionState? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get activeRow => $_getIZ(0);
  @$pb.TagNumber(1)
  set activeRow($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasActiveRow() => $_has(0);
  @$pb.TagNumber(1)
  void clearActiveRow() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get activeCol => $_getIZ(1);
  @$pb.TagNumber(2)
  set activeCol($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasActiveCol() => $_has(1);
  @$pb.TagNumber(2)
  void clearActiveCol() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbList<CellRange> get ranges => $_getList(2);

  @$pb.TagNumber(4)
  $core.int get topRow => $_getIZ(3);
  @$pb.TagNumber(4)
  set topRow($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTopRow() => $_has(3);
  @$pb.TagNumber(4)
  void clearTopRow() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get leftCol => $_getIZ(4);
  @$pb.TagNumber(5)
  set leftCol($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasLeftCol() => $_has(4);
  @$pb.TagNumber(5)
  void clearLeftCol() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get bottomRow => $_getIZ(5);
  @$pb.TagNumber(6)
  set bottomRow($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasBottomRow() => $_has(5);
  @$pb.TagNumber(6)
  void clearBottomRow() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get rightCol => $_getIZ(6);
  @$pb.TagNumber(7)
  set rightCol($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasRightCol() => $_has(6);
  @$pb.TagNumber(7)
  void clearRightCol() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get mouseRow => $_getIZ(7);
  @$pb.TagNumber(8)
  set mouseRow($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasMouseRow() => $_has(7);
  @$pb.TagNumber(8)
  void clearMouseRow() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get mouseCol => $_getIZ(8);
  @$pb.TagNumber(9)
  set mouseCol($core.int value) => $_setSignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasMouseCol() => $_has(8);
  @$pb.TagNumber(9)
  void clearMouseCol() => $_clearField(9);
}

class HighlightRegion extends $pb.GeneratedMessage {
  factory HighlightRegion({
    CellRange? range,
    HighlightStyle? style,
    $core.int? refId,
    $core.int? textStart,
    $core.int? textLength,
  }) {
    final result = create();
    if (range != null) result.range = range;
    if (style != null) result.style = style;
    if (refId != null) result.refId = refId;
    if (textStart != null) result.textStart = textStart;
    if (textLength != null) result.textLength = textLength;
    return result;
  }

  HighlightRegion._();

  factory HighlightRegion.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory HighlightRegion.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'HighlightRegion',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aOM<CellRange>(1, _omitFieldNames ? '' : 'range',
        subBuilder: CellRange.create)
    ..aOM<HighlightStyle>(2, _omitFieldNames ? '' : 'style',
        subBuilder: HighlightStyle.create)
    ..aI(3, _omitFieldNames ? '' : 'refId')
    ..aI(4, _omitFieldNames ? '' : 'textStart')
    ..aI(5, _omitFieldNames ? '' : 'textLength')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HighlightRegion clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HighlightRegion copyWith(void Function(HighlightRegion) updates) =>
      super.copyWith((message) => updates(message as HighlightRegion))
          as HighlightRegion;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static HighlightRegion create() => HighlightRegion._();
  @$core.override
  HighlightRegion createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static HighlightRegion getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<HighlightRegion>(create);
  static HighlightRegion? _defaultInstance;

  @$pb.TagNumber(1)
  CellRange get range => $_getN(0);
  @$pb.TagNumber(1)
  set range(CellRange value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasRange() => $_has(0);
  @$pb.TagNumber(1)
  void clearRange() => $_clearField(1);
  @$pb.TagNumber(1)
  CellRange ensureRange() => $_ensure(0);

  @$pb.TagNumber(2)
  HighlightStyle get style => $_getN(1);
  @$pb.TagNumber(2)
  set style(HighlightStyle value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasStyle() => $_has(1);
  @$pb.TagNumber(2)
  void clearStyle() => $_clearField(2);
  @$pb.TagNumber(2)
  HighlightStyle ensureStyle() => $_ensure(1);

  @$pb.TagNumber(3)
  $core.int get refId => $_getIZ(2);
  @$pb.TagNumber(3)
  set refId($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRefId() => $_has(2);
  @$pb.TagNumber(3)
  void clearRefId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get textStart => $_getIZ(3);
  @$pb.TagNumber(4)
  set textStart($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTextStart() => $_has(3);
  @$pb.TagNumber(4)
  void clearTextStart() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get textLength => $_getIZ(4);
  @$pb.TagNumber(5)
  set textLength($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTextLength() => $_has(4);
  @$pb.TagNumber(5)
  void clearTextLength() => $_clearField(5);
}

class EditSetHighlights extends $pb.GeneratedMessage {
  factory EditSetHighlights({
    $core.Iterable<HighlightRegion>? regions,
  }) {
    final result = create();
    if (regions != null) result.regions.addAll(regions);
    return result;
  }

  EditSetHighlights._();

  factory EditSetHighlights.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory EditSetHighlights.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EditSetHighlights',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..pPM<HighlightRegion>(1, _omitFieldNames ? '' : 'regions',
        subBuilder: HighlightRegion.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EditSetHighlights clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EditSetHighlights copyWith(void Function(EditSetHighlights) updates) =>
      super.copyWith((message) => updates(message as EditSetHighlights))
          as EditSetHighlights;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EditSetHighlights create() => EditSetHighlights._();
  @$core.override
  EditSetHighlights createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static EditSetHighlights getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EditSetHighlights>(create);
  static EditSetHighlights? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<HighlightRegion> get regions => $_getList(0);
}

enum EditCommand_Command {
  start,
  commit,
  cancel,
  setText,
  setSelection,
  finish,
  setHighlights,
  setPreedit,
  notSet
}

class EditCommand extends $pb.GeneratedMessage {
  factory EditCommand({
    $fixnum.Int64? gridId,
    EditStart? start,
    EditCommit? commit,
    EditCancel? cancel,
    EditSetText? setText,
    EditSetSelection? setSelection,
    EditFinish? finish,
    EditSetHighlights? setHighlights,
    EditSetPreedit? setPreedit,
  }) {
    final result = create();
    if (gridId != null) result.gridId = gridId;
    if (start != null) result.start = start;
    if (commit != null) result.commit = commit;
    if (cancel != null) result.cancel = cancel;
    if (setText != null) result.setText = setText;
    if (setSelection != null) result.setSelection = setSelection;
    if (finish != null) result.finish = finish;
    if (setHighlights != null) result.setHighlights = setHighlights;
    if (setPreedit != null) result.setPreedit = setPreedit;
    return result;
  }

  EditCommand._();

  factory EditCommand.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory EditCommand.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, EditCommand_Command>
      _EditCommand_CommandByTag = {
    2: EditCommand_Command.start,
    3: EditCommand_Command.commit,
    4: EditCommand_Command.cancel,
    5: EditCommand_Command.setText,
    6: EditCommand_Command.setSelection,
    7: EditCommand_Command.finish,
    8: EditCommand_Command.setHighlights,
    9: EditCommand_Command.setPreedit,
    0: EditCommand_Command.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EditCommand',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..oo(0, [2, 3, 4, 5, 6, 7, 8, 9])
    ..aInt64(1, _omitFieldNames ? '' : 'gridId')
    ..aOM<EditStart>(2, _omitFieldNames ? '' : 'start',
        subBuilder: EditStart.create)
    ..aOM<EditCommit>(3, _omitFieldNames ? '' : 'commit',
        subBuilder: EditCommit.create)
    ..aOM<EditCancel>(4, _omitFieldNames ? '' : 'cancel',
        subBuilder: EditCancel.create)
    ..aOM<EditSetText>(5, _omitFieldNames ? '' : 'setText',
        subBuilder: EditSetText.create)
    ..aOM<EditSetSelection>(6, _omitFieldNames ? '' : 'setSelection',
        subBuilder: EditSetSelection.create)
    ..aOM<EditFinish>(7, _omitFieldNames ? '' : 'finish',
        subBuilder: EditFinish.create)
    ..aOM<EditSetHighlights>(8, _omitFieldNames ? '' : 'setHighlights',
        subBuilder: EditSetHighlights.create)
    ..aOM<EditSetPreedit>(9, _omitFieldNames ? '' : 'setPreedit',
        subBuilder: EditSetPreedit.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EditCommand clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EditCommand copyWith(void Function(EditCommand) updates) =>
      super.copyWith((message) => updates(message as EditCommand))
          as EditCommand;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EditCommand create() => EditCommand._();
  @$core.override
  EditCommand createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static EditCommand getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EditCommand>(create);
  static EditCommand? _defaultInstance;

  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  @$pb.TagNumber(9)
  EditCommand_Command whichCommand() =>
      _EditCommand_CommandByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  @$pb.TagNumber(9)
  void clearCommand() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $fixnum.Int64 get gridId => $_getI64(0);
  @$pb.TagNumber(1)
  set gridId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGridId() => $_has(0);
  @$pb.TagNumber(1)
  void clearGridId() => $_clearField(1);

  @$pb.TagNumber(2)
  EditStart get start => $_getN(1);
  @$pb.TagNumber(2)
  set start(EditStart value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasStart() => $_has(1);
  @$pb.TagNumber(2)
  void clearStart() => $_clearField(2);
  @$pb.TagNumber(2)
  EditStart ensureStart() => $_ensure(1);

  @$pb.TagNumber(3)
  EditCommit get commit => $_getN(2);
  @$pb.TagNumber(3)
  set commit(EditCommit value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasCommit() => $_has(2);
  @$pb.TagNumber(3)
  void clearCommit() => $_clearField(3);
  @$pb.TagNumber(3)
  EditCommit ensureCommit() => $_ensure(2);

  @$pb.TagNumber(4)
  EditCancel get cancel => $_getN(3);
  @$pb.TagNumber(4)
  set cancel(EditCancel value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasCancel() => $_has(3);
  @$pb.TagNumber(4)
  void clearCancel() => $_clearField(4);
  @$pb.TagNumber(4)
  EditCancel ensureCancel() => $_ensure(3);

  @$pb.TagNumber(5)
  EditSetText get setText => $_getN(4);
  @$pb.TagNumber(5)
  set setText(EditSetText value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasSetText() => $_has(4);
  @$pb.TagNumber(5)
  void clearSetText() => $_clearField(5);
  @$pb.TagNumber(5)
  EditSetText ensureSetText() => $_ensure(4);

  @$pb.TagNumber(6)
  EditSetSelection get setSelection => $_getN(5);
  @$pb.TagNumber(6)
  set setSelection(EditSetSelection value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasSetSelection() => $_has(5);
  @$pb.TagNumber(6)
  void clearSetSelection() => $_clearField(6);
  @$pb.TagNumber(6)
  EditSetSelection ensureSetSelection() => $_ensure(5);

  @$pb.TagNumber(7)
  EditFinish get finish => $_getN(6);
  @$pb.TagNumber(7)
  set finish(EditFinish value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasFinish() => $_has(6);
  @$pb.TagNumber(7)
  void clearFinish() => $_clearField(7);
  @$pb.TagNumber(7)
  EditFinish ensureFinish() => $_ensure(6);

  @$pb.TagNumber(8)
  EditSetHighlights get setHighlights => $_getN(7);
  @$pb.TagNumber(8)
  set setHighlights(EditSetHighlights value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasSetHighlights() => $_has(7);
  @$pb.TagNumber(8)
  void clearSetHighlights() => $_clearField(8);
  @$pb.TagNumber(8)
  EditSetHighlights ensureSetHighlights() => $_ensure(7);

  @$pb.TagNumber(9)
  EditSetPreedit get setPreedit => $_getN(8);
  @$pb.TagNumber(9)
  set setPreedit(EditSetPreedit value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasSetPreedit() => $_has(8);
  @$pb.TagNumber(9)
  void clearSetPreedit() => $_clearField(9);
  @$pb.TagNumber(9)
  EditSetPreedit ensureSetPreedit() => $_ensure(8);
}

class EditStart extends $pb.GeneratedMessage {
  factory EditStart({
    $core.int? row,
    $core.int? col,
    $core.bool? selectAll,
    $core.bool? caretEnd,
    $core.String? seedText,
    $core.bool? formulaMode,
  }) {
    final result = create();
    if (row != null) result.row = row;
    if (col != null) result.col = col;
    if (selectAll != null) result.selectAll = selectAll;
    if (caretEnd != null) result.caretEnd = caretEnd;
    if (seedText != null) result.seedText = seedText;
    if (formulaMode != null) result.formulaMode = formulaMode;
    return result;
  }

  EditStart._();

  factory EditStart.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory EditStart.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EditStart',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'row')
    ..aI(2, _omitFieldNames ? '' : 'col')
    ..aOB(3, _omitFieldNames ? '' : 'selectAll')
    ..aOB(4, _omitFieldNames ? '' : 'caretEnd')
    ..aOS(5, _omitFieldNames ? '' : 'seedText')
    ..aOB(6, _omitFieldNames ? '' : 'formulaMode')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EditStart clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EditStart copyWith(void Function(EditStart) updates) =>
      super.copyWith((message) => updates(message as EditStart)) as EditStart;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EditStart create() => EditStart._();
  @$core.override
  EditStart createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static EditStart getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<EditStart>(create);
  static EditStart? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get row => $_getIZ(0);
  @$pb.TagNumber(1)
  set row($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRow() => $_has(0);
  @$pb.TagNumber(1)
  void clearRow() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get col => $_getIZ(1);
  @$pb.TagNumber(2)
  set col($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCol() => $_has(1);
  @$pb.TagNumber(2)
  void clearCol() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get selectAll => $_getBF(2);
  @$pb.TagNumber(3)
  set selectAll($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSelectAll() => $_has(2);
  @$pb.TagNumber(3)
  void clearSelectAll() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get caretEnd => $_getBF(3);
  @$pb.TagNumber(4)
  set caretEnd($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCaretEnd() => $_has(3);
  @$pb.TagNumber(4)
  void clearCaretEnd() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get seedText => $_getSZ(4);
  @$pb.TagNumber(5)
  set seedText($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSeedText() => $_has(4);
  @$pb.TagNumber(5)
  void clearSeedText() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get formulaMode => $_getBF(5);
  @$pb.TagNumber(6)
  set formulaMode($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasFormulaMode() => $_has(5);
  @$pb.TagNumber(6)
  void clearFormulaMode() => $_clearField(6);
}

class EditCommit extends $pb.GeneratedMessage {
  factory EditCommit({
    $core.String? text,
  }) {
    final result = create();
    if (text != null) result.text = text;
    return result;
  }

  EditCommit._();

  factory EditCommit.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory EditCommit.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EditCommit',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'text')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EditCommit clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EditCommit copyWith(void Function(EditCommit) updates) =>
      super.copyWith((message) => updates(message as EditCommit)) as EditCommit;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EditCommit create() => EditCommit._();
  @$core.override
  EditCommit createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static EditCommit getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EditCommit>(create);
  static EditCommit? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get text => $_getSZ(0);
  @$pb.TagNumber(1)
  set text($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasText() => $_has(0);
  @$pb.TagNumber(1)
  void clearText() => $_clearField(1);
}

class EditCancel extends $pb.GeneratedMessage {
  factory EditCancel() => create();

  EditCancel._();

  factory EditCancel.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory EditCancel.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EditCancel',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EditCancel clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EditCancel copyWith(void Function(EditCancel) updates) =>
      super.copyWith((message) => updates(message as EditCancel)) as EditCancel;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EditCancel create() => EditCancel._();
  @$core.override
  EditCancel createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static EditCancel getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EditCancel>(create);
  static EditCancel? _defaultInstance;
}

class EditSetText extends $pb.GeneratedMessage {
  factory EditSetText({
    $core.String? text,
  }) {
    final result = create();
    if (text != null) result.text = text;
    return result;
  }

  EditSetText._();

  factory EditSetText.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory EditSetText.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EditSetText',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'text')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EditSetText clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EditSetText copyWith(void Function(EditSetText) updates) =>
      super.copyWith((message) => updates(message as EditSetText))
          as EditSetText;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EditSetText create() => EditSetText._();
  @$core.override
  EditSetText createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static EditSetText getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EditSetText>(create);
  static EditSetText? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get text => $_getSZ(0);
  @$pb.TagNumber(1)
  set text($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasText() => $_has(0);
  @$pb.TagNumber(1)
  void clearText() => $_clearField(1);
}

class EditSetSelection extends $pb.GeneratedMessage {
  factory EditSetSelection({
    $core.int? start,
    $core.int? length,
  }) {
    final result = create();
    if (start != null) result.start = start;
    if (length != null) result.length = length;
    return result;
  }

  EditSetSelection._();

  factory EditSetSelection.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory EditSetSelection.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EditSetSelection',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'start')
    ..aI(2, _omitFieldNames ? '' : 'length')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EditSetSelection clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EditSetSelection copyWith(void Function(EditSetSelection) updates) =>
      super.copyWith((message) => updates(message as EditSetSelection))
          as EditSetSelection;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EditSetSelection create() => EditSetSelection._();
  @$core.override
  EditSetSelection createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static EditSetSelection getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EditSetSelection>(create);
  static EditSetSelection? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get start => $_getIZ(0);
  @$pb.TagNumber(1)
  set start($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasStart() => $_has(0);
  @$pb.TagNumber(1)
  void clearStart() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get length => $_getIZ(1);
  @$pb.TagNumber(2)
  set length($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLength() => $_has(1);
  @$pb.TagNumber(2)
  void clearLength() => $_clearField(2);
}

class EditSetPreedit extends $pb.GeneratedMessage {
  factory EditSetPreedit({
    $core.String? text,
    $core.int? cursor,
    $core.bool? commit,
  }) {
    final result = create();
    if (text != null) result.text = text;
    if (cursor != null) result.cursor = cursor;
    if (commit != null) result.commit = commit;
    return result;
  }

  EditSetPreedit._();

  factory EditSetPreedit.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory EditSetPreedit.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EditSetPreedit',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'text')
    ..aI(2, _omitFieldNames ? '' : 'cursor')
    ..aOB(3, _omitFieldNames ? '' : 'commit')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EditSetPreedit clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EditSetPreedit copyWith(void Function(EditSetPreedit) updates) =>
      super.copyWith((message) => updates(message as EditSetPreedit))
          as EditSetPreedit;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EditSetPreedit create() => EditSetPreedit._();
  @$core.override
  EditSetPreedit createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static EditSetPreedit getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EditSetPreedit>(create);
  static EditSetPreedit? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get text => $_getSZ(0);
  @$pb.TagNumber(1)
  set text($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasText() => $_has(0);
  @$pb.TagNumber(1)
  void clearText() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get cursor => $_getIZ(1);
  @$pb.TagNumber(2)
  set cursor($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCursor() => $_has(1);
  @$pb.TagNumber(2)
  void clearCursor() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get commit => $_getBF(2);
  @$pb.TagNumber(3)
  set commit($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCommit() => $_has(2);
  @$pb.TagNumber(3)
  void clearCommit() => $_clearField(3);
}

class EditFinish extends $pb.GeneratedMessage {
  factory EditFinish() => create();

  EditFinish._();

  factory EditFinish.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory EditFinish.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EditFinish',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EditFinish clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EditFinish copyWith(void Function(EditFinish) updates) =>
      super.copyWith((message) => updates(message as EditFinish)) as EditFinish;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EditFinish create() => EditFinish._();
  @$core.override
  EditFinish createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static EditFinish getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EditFinish>(create);
  static EditFinish? _defaultInstance;
}

class EditState extends $pb.GeneratedMessage {
  factory EditState({
    $core.bool? active,
    $core.int? row,
    $core.int? col,
    $core.String? text,
    $core.int? selStart,
    $core.int? selLength,
    $core.bool? composing,
    $core.String? preeditText,
    EditUiMode? uiMode,
  }) {
    final result = create();
    if (active != null) result.active = active;
    if (row != null) result.row = row;
    if (col != null) result.col = col;
    if (text != null) result.text = text;
    if (selStart != null) result.selStart = selStart;
    if (selLength != null) result.selLength = selLength;
    if (composing != null) result.composing = composing;
    if (preeditText != null) result.preeditText = preeditText;
    if (uiMode != null) result.uiMode = uiMode;
    return result;
  }

  EditState._();

  factory EditState.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory EditState.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EditState',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'active')
    ..aI(2, _omitFieldNames ? '' : 'row')
    ..aI(3, _omitFieldNames ? '' : 'col')
    ..aOS(4, _omitFieldNames ? '' : 'text')
    ..aI(5, _omitFieldNames ? '' : 'selStart')
    ..aI(6, _omitFieldNames ? '' : 'selLength')
    ..aOB(7, _omitFieldNames ? '' : 'composing')
    ..aOS(8, _omitFieldNames ? '' : 'preeditText')
    ..aE<EditUiMode>(9, _omitFieldNames ? '' : 'uiMode',
        enumValues: EditUiMode.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EditState clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EditState copyWith(void Function(EditState) updates) =>
      super.copyWith((message) => updates(message as EditState)) as EditState;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EditState create() => EditState._();
  @$core.override
  EditState createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static EditState getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<EditState>(create);
  static EditState? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get active => $_getBF(0);
  @$pb.TagNumber(1)
  set active($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasActive() => $_has(0);
  @$pb.TagNumber(1)
  void clearActive() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get row => $_getIZ(1);
  @$pb.TagNumber(2)
  set row($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRow() => $_has(1);
  @$pb.TagNumber(2)
  void clearRow() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get col => $_getIZ(2);
  @$pb.TagNumber(3)
  set col($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCol() => $_has(2);
  @$pb.TagNumber(3)
  void clearCol() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get text => $_getSZ(3);
  @$pb.TagNumber(4)
  set text($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasText() => $_has(3);
  @$pb.TagNumber(4)
  void clearText() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get selStart => $_getIZ(4);
  @$pb.TagNumber(5)
  set selStart($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSelStart() => $_has(4);
  @$pb.TagNumber(5)
  void clearSelStart() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get selLength => $_getIZ(5);
  @$pb.TagNumber(6)
  set selLength($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasSelLength() => $_has(5);
  @$pb.TagNumber(6)
  void clearSelLength() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.bool get composing => $_getBF(6);
  @$pb.TagNumber(7)
  set composing($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasComposing() => $_has(6);
  @$pb.TagNumber(7)
  void clearComposing() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get preeditText => $_getSZ(7);
  @$pb.TagNumber(8)
  set preeditText($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasPreeditText() => $_has(7);
  @$pb.TagNumber(8)
  void clearPreeditText() => $_clearField(8);

  @$pb.TagNumber(9)
  EditUiMode get uiMode => $_getN(8);
  @$pb.TagNumber(9)
  set uiMode(EditUiMode value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasUiMode() => $_has(8);
  @$pb.TagNumber(9)
  void clearUiMode() => $_clearField(9);
}

class SortColumn extends $pb.GeneratedMessage {
  factory SortColumn({
    $core.int? col,
    SortOrder? order,
    SortType? type,
  }) {
    final result = create();
    if (col != null) result.col = col;
    if (order != null) result.order = order;
    if (type != null) result.type = type;
    return result;
  }

  SortColumn._();

  factory SortColumn.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SortColumn.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SortColumn',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'col')
    ..aE<SortOrder>(2, _omitFieldNames ? '' : 'order',
        enumValues: SortOrder.values)
    ..aE<SortType>(3, _omitFieldNames ? '' : 'type',
        enumValues: SortType.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SortColumn clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SortColumn copyWith(void Function(SortColumn) updates) =>
      super.copyWith((message) => updates(message as SortColumn)) as SortColumn;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SortColumn create() => SortColumn._();
  @$core.override
  SortColumn createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SortColumn getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SortColumn>(create);
  static SortColumn? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get col => $_getIZ(0);
  @$pb.TagNumber(1)
  set col($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCol() => $_has(0);
  @$pb.TagNumber(1)
  void clearCol() => $_clearField(1);

  @$pb.TagNumber(2)
  SortOrder get order => $_getN(1);
  @$pb.TagNumber(2)
  set order(SortOrder value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasOrder() => $_has(1);
  @$pb.TagNumber(2)
  void clearOrder() => $_clearField(2);

  @$pb.TagNumber(3)
  SortType get type => $_getN(2);
  @$pb.TagNumber(3)
  set type(SortType value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasType() => $_has(2);
  @$pb.TagNumber(3)
  void clearType() => $_clearField(3);
}

class SortRequest extends $pb.GeneratedMessage {
  factory SortRequest({
    $fixnum.Int64? gridId,
    $core.Iterable<SortColumn>? sortColumns,
  }) {
    final result = create();
    if (gridId != null) result.gridId = gridId;
    if (sortColumns != null) result.sortColumns.addAll(sortColumns);
    return result;
  }

  SortRequest._();

  factory SortRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SortRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SortRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'gridId')
    ..pPM<SortColumn>(2, _omitFieldNames ? '' : 'sortColumns',
        subBuilder: SortColumn.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SortRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SortRequest copyWith(void Function(SortRequest) updates) =>
      super.copyWith((message) => updates(message as SortRequest))
          as SortRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SortRequest create() => SortRequest._();
  @$core.override
  SortRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SortRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SortRequest>(create);
  static SortRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get gridId => $_getI64(0);
  @$pb.TagNumber(1)
  set gridId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGridId() => $_has(0);
  @$pb.TagNumber(1)
  void clearGridId() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<SortColumn> get sortColumns => $_getList(1);
}

class SubtotalRequest extends $pb.GeneratedMessage {
  factory SubtotalRequest({
    $fixnum.Int64? gridId,
    AggregateType? aggregate,
    $core.int? groupOnCol,
    $core.int? aggregateCol,
    $core.String? caption,
    $core.int? background,
    $core.int? foreground,
    $core.bool? addOutline,
    Font? font,
  }) {
    final result = create();
    if (gridId != null) result.gridId = gridId;
    if (aggregate != null) result.aggregate = aggregate;
    if (groupOnCol != null) result.groupOnCol = groupOnCol;
    if (aggregateCol != null) result.aggregateCol = aggregateCol;
    if (caption != null) result.caption = caption;
    if (background != null) result.background = background;
    if (foreground != null) result.foreground = foreground;
    if (addOutline != null) result.addOutline = addOutline;
    if (font != null) result.font = font;
    return result;
  }

  SubtotalRequest._();

  factory SubtotalRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SubtotalRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SubtotalRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'gridId')
    ..aE<AggregateType>(2, _omitFieldNames ? '' : 'aggregate',
        enumValues: AggregateType.values)
    ..aI(3, _omitFieldNames ? '' : 'groupOnCol')
    ..aI(4, _omitFieldNames ? '' : 'aggregateCol')
    ..aOS(5, _omitFieldNames ? '' : 'caption')
    ..aI(6, _omitFieldNames ? '' : 'background', fieldType: $pb.PbFieldType.OU3)
    ..aI(7, _omitFieldNames ? '' : 'foreground', fieldType: $pb.PbFieldType.OU3)
    ..aOB(8, _omitFieldNames ? '' : 'addOutline')
    ..aOM<Font>(9, _omitFieldNames ? '' : 'font', subBuilder: Font.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SubtotalRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SubtotalRequest copyWith(void Function(SubtotalRequest) updates) =>
      super.copyWith((message) => updates(message as SubtotalRequest))
          as SubtotalRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SubtotalRequest create() => SubtotalRequest._();
  @$core.override
  SubtotalRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SubtotalRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SubtotalRequest>(create);
  static SubtotalRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get gridId => $_getI64(0);
  @$pb.TagNumber(1)
  set gridId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGridId() => $_has(0);
  @$pb.TagNumber(1)
  void clearGridId() => $_clearField(1);

  @$pb.TagNumber(2)
  AggregateType get aggregate => $_getN(1);
  @$pb.TagNumber(2)
  set aggregate(AggregateType value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasAggregate() => $_has(1);
  @$pb.TagNumber(2)
  void clearAggregate() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get groupOnCol => $_getIZ(2);
  @$pb.TagNumber(3)
  set groupOnCol($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasGroupOnCol() => $_has(2);
  @$pb.TagNumber(3)
  void clearGroupOnCol() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get aggregateCol => $_getIZ(3);
  @$pb.TagNumber(4)
  set aggregateCol($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAggregateCol() => $_has(3);
  @$pb.TagNumber(4)
  void clearAggregateCol() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get caption => $_getSZ(4);
  @$pb.TagNumber(5)
  set caption($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCaption() => $_has(4);
  @$pb.TagNumber(5)
  void clearCaption() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get background => $_getIZ(5);
  @$pb.TagNumber(6)
  set background($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasBackground() => $_has(5);
  @$pb.TagNumber(6)
  void clearBackground() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get foreground => $_getIZ(6);
  @$pb.TagNumber(7)
  set foreground($core.int value) => $_setUnsignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasForeground() => $_has(6);
  @$pb.TagNumber(7)
  void clearForeground() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.bool get addOutline => $_getBF(7);
  @$pb.TagNumber(8)
  set addOutline($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasAddOutline() => $_has(7);
  @$pb.TagNumber(8)
  void clearAddOutline() => $_clearField(8);

  @$pb.TagNumber(9)
  Font get font => $_getN(8);
  @$pb.TagNumber(9)
  set font(Font value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasFont() => $_has(8);
  @$pb.TagNumber(9)
  void clearFont() => $_clearField(9);
  @$pb.TagNumber(9)
  Font ensureFont() => $_ensure(8);
}

class SubtotalResult extends $pb.GeneratedMessage {
  factory SubtotalResult({
    $core.Iterable<$core.int>? rows,
  }) {
    final result = create();
    if (rows != null) result.rows.addAll(rows);
    return result;
  }

  SubtotalResult._();

  factory SubtotalResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SubtotalResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SubtotalResult',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..p<$core.int>(1, _omitFieldNames ? '' : 'rows', $pb.PbFieldType.K3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SubtotalResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SubtotalResult copyWith(void Function(SubtotalResult) updates) =>
      super.copyWith((message) => updates(message as SubtotalResult))
          as SubtotalResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SubtotalResult create() => SubtotalResult._();
  @$core.override
  SubtotalResult createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SubtotalResult getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SubtotalResult>(create);
  static SubtotalResult? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$core.int> get rows => $_getList(0);
}

class AutoSizeRequest extends $pb.GeneratedMessage {
  factory AutoSizeRequest({
    $fixnum.Int64? gridId,
    $core.int? colFrom,
    $core.int? colTo,
    $core.bool? equal,
    $core.int? maxWidth,
  }) {
    final result = create();
    if (gridId != null) result.gridId = gridId;
    if (colFrom != null) result.colFrom = colFrom;
    if (colTo != null) result.colTo = colTo;
    if (equal != null) result.equal = equal;
    if (maxWidth != null) result.maxWidth = maxWidth;
    return result;
  }

  AutoSizeRequest._();

  factory AutoSizeRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AutoSizeRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AutoSizeRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'gridId')
    ..aI(2, _omitFieldNames ? '' : 'colFrom')
    ..aI(3, _omitFieldNames ? '' : 'colTo')
    ..aOB(4, _omitFieldNames ? '' : 'equal')
    ..aI(5, _omitFieldNames ? '' : 'maxWidth')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AutoSizeRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AutoSizeRequest copyWith(void Function(AutoSizeRequest) updates) =>
      super.copyWith((message) => updates(message as AutoSizeRequest))
          as AutoSizeRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AutoSizeRequest create() => AutoSizeRequest._();
  @$core.override
  AutoSizeRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AutoSizeRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AutoSizeRequest>(create);
  static AutoSizeRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get gridId => $_getI64(0);
  @$pb.TagNumber(1)
  set gridId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGridId() => $_has(0);
  @$pb.TagNumber(1)
  void clearGridId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get colFrom => $_getIZ(1);
  @$pb.TagNumber(2)
  set colFrom($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasColFrom() => $_has(1);
  @$pb.TagNumber(2)
  void clearColFrom() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get colTo => $_getIZ(2);
  @$pb.TagNumber(3)
  set colTo($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasColTo() => $_has(2);
  @$pb.TagNumber(3)
  void clearColTo() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get equal => $_getBF(3);
  @$pb.TagNumber(4)
  set equal($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasEqual() => $_has(3);
  @$pb.TagNumber(4)
  void clearEqual() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get maxWidth => $_getIZ(4);
  @$pb.TagNumber(5)
  set maxWidth($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasMaxWidth() => $_has(4);
  @$pb.TagNumber(5)
  void clearMaxWidth() => $_clearField(5);
}

class OutlineRequest extends $pb.GeneratedMessage {
  factory OutlineRequest({
    $fixnum.Int64? gridId,
    $core.int? level,
  }) {
    final result = create();
    if (gridId != null) result.gridId = gridId;
    if (level != null) result.level = level;
    return result;
  }

  OutlineRequest._();

  factory OutlineRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory OutlineRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'OutlineRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'gridId')
    ..aI(2, _omitFieldNames ? '' : 'level')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OutlineRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OutlineRequest copyWith(void Function(OutlineRequest) updates) =>
      super.copyWith((message) => updates(message as OutlineRequest))
          as OutlineRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static OutlineRequest create() => OutlineRequest._();
  @$core.override
  OutlineRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static OutlineRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<OutlineRequest>(create);
  static OutlineRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get gridId => $_getI64(0);
  @$pb.TagNumber(1)
  set gridId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGridId() => $_has(0);
  @$pb.TagNumber(1)
  void clearGridId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get level => $_getIZ(1);
  @$pb.TagNumber(2)
  set level($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLevel() => $_has(1);
  @$pb.TagNumber(2)
  void clearLevel() => $_clearField(2);
}

class GetNodeRequest extends $pb.GeneratedMessage {
  factory GetNodeRequest({
    $fixnum.Int64? gridId,
    $core.int? row,
    NodeRelation? relation,
  }) {
    final result = create();
    if (gridId != null) result.gridId = gridId;
    if (row != null) result.row = row;
    if (relation != null) result.relation = relation;
    return result;
  }

  GetNodeRequest._();

  factory GetNodeRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetNodeRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetNodeRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'gridId')
    ..aI(2, _omitFieldNames ? '' : 'row')
    ..aE<NodeRelation>(3, _omitFieldNames ? '' : 'relation',
        enumValues: NodeRelation.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetNodeRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetNodeRequest copyWith(void Function(GetNodeRequest) updates) =>
      super.copyWith((message) => updates(message as GetNodeRequest))
          as GetNodeRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetNodeRequest create() => GetNodeRequest._();
  @$core.override
  GetNodeRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetNodeRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetNodeRequest>(create);
  static GetNodeRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get gridId => $_getI64(0);
  @$pb.TagNumber(1)
  set gridId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGridId() => $_has(0);
  @$pb.TagNumber(1)
  void clearGridId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get row => $_getIZ(1);
  @$pb.TagNumber(2)
  set row($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRow() => $_has(1);
  @$pb.TagNumber(2)
  void clearRow() => $_clearField(2);

  @$pb.TagNumber(3)
  NodeRelation get relation => $_getN(2);
  @$pb.TagNumber(3)
  set relation(NodeRelation value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasRelation() => $_has(2);
  @$pb.TagNumber(3)
  void clearRelation() => $_clearField(3);
}

class NodeInfo extends $pb.GeneratedMessage {
  factory NodeInfo({
    $core.int? row,
    $core.int? level,
    $core.bool? isExpanded,
    $core.int? childCount,
    $core.int? parentRow,
    $core.int? firstChild,
    $core.int? lastChild,
  }) {
    final result = create();
    if (row != null) result.row = row;
    if (level != null) result.level = level;
    if (isExpanded != null) result.isExpanded = isExpanded;
    if (childCount != null) result.childCount = childCount;
    if (parentRow != null) result.parentRow = parentRow;
    if (firstChild != null) result.firstChild = firstChild;
    if (lastChild != null) result.lastChild = lastChild;
    return result;
  }

  NodeInfo._();

  factory NodeInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory NodeInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'NodeInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'row')
    ..aI(2, _omitFieldNames ? '' : 'level')
    ..aOB(3, _omitFieldNames ? '' : 'isExpanded')
    ..aI(4, _omitFieldNames ? '' : 'childCount')
    ..aI(5, _omitFieldNames ? '' : 'parentRow')
    ..aI(6, _omitFieldNames ? '' : 'firstChild')
    ..aI(7, _omitFieldNames ? '' : 'lastChild')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NodeInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NodeInfo copyWith(void Function(NodeInfo) updates) =>
      super.copyWith((message) => updates(message as NodeInfo)) as NodeInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static NodeInfo create() => NodeInfo._();
  @$core.override
  NodeInfo createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static NodeInfo getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<NodeInfo>(create);
  static NodeInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get row => $_getIZ(0);
  @$pb.TagNumber(1)
  set row($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRow() => $_has(0);
  @$pb.TagNumber(1)
  void clearRow() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get level => $_getIZ(1);
  @$pb.TagNumber(2)
  set level($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLevel() => $_has(1);
  @$pb.TagNumber(2)
  void clearLevel() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get isExpanded => $_getBF(2);
  @$pb.TagNumber(3)
  set isExpanded($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasIsExpanded() => $_has(2);
  @$pb.TagNumber(3)
  void clearIsExpanded() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get childCount => $_getIZ(3);
  @$pb.TagNumber(4)
  set childCount($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasChildCount() => $_has(3);
  @$pb.TagNumber(4)
  void clearChildCount() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get parentRow => $_getIZ(4);
  @$pb.TagNumber(5)
  set parentRow($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasParentRow() => $_has(4);
  @$pb.TagNumber(5)
  void clearParentRow() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get firstChild => $_getIZ(5);
  @$pb.TagNumber(6)
  set firstChild($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasFirstChild() => $_has(5);
  @$pb.TagNumber(6)
  void clearFirstChild() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get lastChild => $_getIZ(6);
  @$pb.TagNumber(7)
  set lastChild($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasLastChild() => $_has(6);
  @$pb.TagNumber(7)
  void clearLastChild() => $_clearField(7);
}

enum FindRequest_Query { textQuery, regexQuery, notSet }

class FindRequest extends $pb.GeneratedMessage {
  factory FindRequest({
    $fixnum.Int64? gridId,
    $core.int? col,
    $core.int? startRow,
    TextQuery? textQuery,
    RegexQuery? regexQuery,
  }) {
    final result = create();
    if (gridId != null) result.gridId = gridId;
    if (col != null) result.col = col;
    if (startRow != null) result.startRow = startRow;
    if (textQuery != null) result.textQuery = textQuery;
    if (regexQuery != null) result.regexQuery = regexQuery;
    return result;
  }

  FindRequest._();

  factory FindRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory FindRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, FindRequest_Query> _FindRequest_QueryByTag =
      {
    4: FindRequest_Query.textQuery,
    5: FindRequest_Query.regexQuery,
    0: FindRequest_Query.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FindRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..oo(0, [4, 5])
    ..aInt64(1, _omitFieldNames ? '' : 'gridId')
    ..aI(2, _omitFieldNames ? '' : 'col')
    ..aI(3, _omitFieldNames ? '' : 'startRow')
    ..aOM<TextQuery>(4, _omitFieldNames ? '' : 'textQuery',
        subBuilder: TextQuery.create)
    ..aOM<RegexQuery>(5, _omitFieldNames ? '' : 'regexQuery',
        subBuilder: RegexQuery.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FindRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FindRequest copyWith(void Function(FindRequest) updates) =>
      super.copyWith((message) => updates(message as FindRequest))
          as FindRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FindRequest create() => FindRequest._();
  @$core.override
  FindRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static FindRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FindRequest>(create);
  static FindRequest? _defaultInstance;

  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  FindRequest_Query whichQuery() => _FindRequest_QueryByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  void clearQuery() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $fixnum.Int64 get gridId => $_getI64(0);
  @$pb.TagNumber(1)
  set gridId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGridId() => $_has(0);
  @$pb.TagNumber(1)
  void clearGridId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get col => $_getIZ(1);
  @$pb.TagNumber(2)
  set col($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCol() => $_has(1);
  @$pb.TagNumber(2)
  void clearCol() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get startRow => $_getIZ(2);
  @$pb.TagNumber(3)
  set startRow($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasStartRow() => $_has(2);
  @$pb.TagNumber(3)
  void clearStartRow() => $_clearField(3);

  @$pb.TagNumber(4)
  TextQuery get textQuery => $_getN(3);
  @$pb.TagNumber(4)
  set textQuery(TextQuery value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasTextQuery() => $_has(3);
  @$pb.TagNumber(4)
  void clearTextQuery() => $_clearField(4);
  @$pb.TagNumber(4)
  TextQuery ensureTextQuery() => $_ensure(3);

  @$pb.TagNumber(5)
  RegexQuery get regexQuery => $_getN(4);
  @$pb.TagNumber(5)
  set regexQuery(RegexQuery value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasRegexQuery() => $_has(4);
  @$pb.TagNumber(5)
  void clearRegexQuery() => $_clearField(5);
  @$pb.TagNumber(5)
  RegexQuery ensureRegexQuery() => $_ensure(4);
}

class TextQuery extends $pb.GeneratedMessage {
  factory TextQuery({
    $core.String? text,
    $core.bool? caseSensitive,
    $core.bool? fullMatch,
  }) {
    final result = create();
    if (text != null) result.text = text;
    if (caseSensitive != null) result.caseSensitive = caseSensitive;
    if (fullMatch != null) result.fullMatch = fullMatch;
    return result;
  }

  TextQuery._();

  factory TextQuery.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TextQuery.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TextQuery',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'text')
    ..aOB(2, _omitFieldNames ? '' : 'caseSensitive')
    ..aOB(3, _omitFieldNames ? '' : 'fullMatch')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TextQuery clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TextQuery copyWith(void Function(TextQuery) updates) =>
      super.copyWith((message) => updates(message as TextQuery)) as TextQuery;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TextQuery create() => TextQuery._();
  @$core.override
  TextQuery createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TextQuery getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TextQuery>(create);
  static TextQuery? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get text => $_getSZ(0);
  @$pb.TagNumber(1)
  set text($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasText() => $_has(0);
  @$pb.TagNumber(1)
  void clearText() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get caseSensitive => $_getBF(1);
  @$pb.TagNumber(2)
  set caseSensitive($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCaseSensitive() => $_has(1);
  @$pb.TagNumber(2)
  void clearCaseSensitive() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get fullMatch => $_getBF(2);
  @$pb.TagNumber(3)
  set fullMatch($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFullMatch() => $_has(2);
  @$pb.TagNumber(3)
  void clearFullMatch() => $_clearField(3);
}

class RegexQuery extends $pb.GeneratedMessage {
  factory RegexQuery({
    $core.String? pattern,
  }) {
    final result = create();
    if (pattern != null) result.pattern = pattern;
    return result;
  }

  RegexQuery._();

  factory RegexQuery.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RegexQuery.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RegexQuery',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'pattern')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegexQuery clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegexQuery copyWith(void Function(RegexQuery) updates) =>
      super.copyWith((message) => updates(message as RegexQuery)) as RegexQuery;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RegexQuery create() => RegexQuery._();
  @$core.override
  RegexQuery createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RegexQuery getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RegexQuery>(create);
  static RegexQuery? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get pattern => $_getSZ(0);
  @$pb.TagNumber(1)
  set pattern($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPattern() => $_has(0);
  @$pb.TagNumber(1)
  void clearPattern() => $_clearField(1);
}

class FindResponse extends $pb.GeneratedMessage {
  factory FindResponse({
    $core.int? row,
  }) {
    final result = create();
    if (row != null) result.row = row;
    return result;
  }

  FindResponse._();

  factory FindResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory FindResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FindResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'row')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FindResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FindResponse copyWith(void Function(FindResponse) updates) =>
      super.copyWith((message) => updates(message as FindResponse))
          as FindResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FindResponse create() => FindResponse._();
  @$core.override
  FindResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static FindResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FindResponse>(create);
  static FindResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get row => $_getIZ(0);
  @$pb.TagNumber(1)
  set row($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRow() => $_has(0);
  @$pb.TagNumber(1)
  void clearRow() => $_clearField(1);
}

class AggregateRequest extends $pb.GeneratedMessage {
  factory AggregateRequest({
    $fixnum.Int64? gridId,
    AggregateType? aggregate,
    $core.int? row1,
    $core.int? col1,
    $core.int? row2,
    $core.int? col2,
  }) {
    final result = create();
    if (gridId != null) result.gridId = gridId;
    if (aggregate != null) result.aggregate = aggregate;
    if (row1 != null) result.row1 = row1;
    if (col1 != null) result.col1 = col1;
    if (row2 != null) result.row2 = row2;
    if (col2 != null) result.col2 = col2;
    return result;
  }

  AggregateRequest._();

  factory AggregateRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AggregateRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AggregateRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'gridId')
    ..aE<AggregateType>(2, _omitFieldNames ? '' : 'aggregate',
        enumValues: AggregateType.values)
    ..aI(3, _omitFieldNames ? '' : 'row1')
    ..aI(4, _omitFieldNames ? '' : 'col1')
    ..aI(5, _omitFieldNames ? '' : 'row2')
    ..aI(6, _omitFieldNames ? '' : 'col2')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AggregateRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AggregateRequest copyWith(void Function(AggregateRequest) updates) =>
      super.copyWith((message) => updates(message as AggregateRequest))
          as AggregateRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AggregateRequest create() => AggregateRequest._();
  @$core.override
  AggregateRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AggregateRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AggregateRequest>(create);
  static AggregateRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get gridId => $_getI64(0);
  @$pb.TagNumber(1)
  set gridId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGridId() => $_has(0);
  @$pb.TagNumber(1)
  void clearGridId() => $_clearField(1);

  @$pb.TagNumber(2)
  AggregateType get aggregate => $_getN(1);
  @$pb.TagNumber(2)
  set aggregate(AggregateType value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasAggregate() => $_has(1);
  @$pb.TagNumber(2)
  void clearAggregate() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get row1 => $_getIZ(2);
  @$pb.TagNumber(3)
  set row1($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRow1() => $_has(2);
  @$pb.TagNumber(3)
  void clearRow1() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get col1 => $_getIZ(3);
  @$pb.TagNumber(4)
  set col1($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCol1() => $_has(3);
  @$pb.TagNumber(4)
  void clearCol1() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get row2 => $_getIZ(4);
  @$pb.TagNumber(5)
  set row2($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasRow2() => $_has(4);
  @$pb.TagNumber(5)
  void clearRow2() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get col2 => $_getIZ(5);
  @$pb.TagNumber(6)
  set col2($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCol2() => $_has(5);
  @$pb.TagNumber(6)
  void clearCol2() => $_clearField(6);
}

class AggregateResponse extends $pb.GeneratedMessage {
  factory AggregateResponse({
    $core.double? value,
  }) {
    final result = create();
    if (value != null) result.value = value;
    return result;
  }

  AggregateResponse._();

  factory AggregateResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AggregateResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AggregateResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aD(1, _omitFieldNames ? '' : 'value')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AggregateResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AggregateResponse copyWith(void Function(AggregateResponse) updates) =>
      super.copyWith((message) => updates(message as AggregateResponse))
          as AggregateResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AggregateResponse create() => AggregateResponse._();
  @$core.override
  AggregateResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AggregateResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AggregateResponse>(create);
  static AggregateResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.double get value => $_getN(0);
  @$pb.TagNumber(1)
  set value($core.double value) => $_setDouble(0, value);
  @$pb.TagNumber(1)
  $core.bool hasValue() => $_has(0);
  @$pb.TagNumber(1)
  void clearValue() => $_clearField(1);
}

class GetMergedRangeRequest extends $pb.GeneratedMessage {
  factory GetMergedRangeRequest({
    $fixnum.Int64? gridId,
    $core.int? row,
    $core.int? col,
  }) {
    final result = create();
    if (gridId != null) result.gridId = gridId;
    if (row != null) result.row = row;
    if (col != null) result.col = col;
    return result;
  }

  GetMergedRangeRequest._();

  factory GetMergedRangeRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetMergedRangeRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetMergedRangeRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'gridId')
    ..aI(2, _omitFieldNames ? '' : 'row')
    ..aI(3, _omitFieldNames ? '' : 'col')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetMergedRangeRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetMergedRangeRequest copyWith(
          void Function(GetMergedRangeRequest) updates) =>
      super.copyWith((message) => updates(message as GetMergedRangeRequest))
          as GetMergedRangeRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetMergedRangeRequest create() => GetMergedRangeRequest._();
  @$core.override
  GetMergedRangeRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetMergedRangeRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetMergedRangeRequest>(create);
  static GetMergedRangeRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get gridId => $_getI64(0);
  @$pb.TagNumber(1)
  set gridId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGridId() => $_has(0);
  @$pb.TagNumber(1)
  void clearGridId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get row => $_getIZ(1);
  @$pb.TagNumber(2)
  set row($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRow() => $_has(1);
  @$pb.TagNumber(2)
  void clearRow() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get col => $_getIZ(2);
  @$pb.TagNumber(3)
  set col($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCol() => $_has(2);
  @$pb.TagNumber(3)
  void clearCol() => $_clearField(3);
}

class MergeCellsRequest extends $pb.GeneratedMessage {
  factory MergeCellsRequest({
    $fixnum.Int64? gridId,
    CellRange? range,
  }) {
    final result = create();
    if (gridId != null) result.gridId = gridId;
    if (range != null) result.range = range;
    return result;
  }

  MergeCellsRequest._();

  factory MergeCellsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MergeCellsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MergeCellsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'gridId')
    ..aOM<CellRange>(2, _omitFieldNames ? '' : 'range',
        subBuilder: CellRange.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MergeCellsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MergeCellsRequest copyWith(void Function(MergeCellsRequest) updates) =>
      super.copyWith((message) => updates(message as MergeCellsRequest))
          as MergeCellsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MergeCellsRequest create() => MergeCellsRequest._();
  @$core.override
  MergeCellsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MergeCellsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MergeCellsRequest>(create);
  static MergeCellsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get gridId => $_getI64(0);
  @$pb.TagNumber(1)
  set gridId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGridId() => $_has(0);
  @$pb.TagNumber(1)
  void clearGridId() => $_clearField(1);

  @$pb.TagNumber(2)
  CellRange get range => $_getN(1);
  @$pb.TagNumber(2)
  set range(CellRange value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasRange() => $_has(1);
  @$pb.TagNumber(2)
  void clearRange() => $_clearField(2);
  @$pb.TagNumber(2)
  CellRange ensureRange() => $_ensure(1);
}

class UnmergeCellsRequest extends $pb.GeneratedMessage {
  factory UnmergeCellsRequest({
    $fixnum.Int64? gridId,
    CellRange? range,
  }) {
    final result = create();
    if (gridId != null) result.gridId = gridId;
    if (range != null) result.range = range;
    return result;
  }

  UnmergeCellsRequest._();

  factory UnmergeCellsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UnmergeCellsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UnmergeCellsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'gridId')
    ..aOM<CellRange>(2, _omitFieldNames ? '' : 'range',
        subBuilder: CellRange.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UnmergeCellsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UnmergeCellsRequest copyWith(void Function(UnmergeCellsRequest) updates) =>
      super.copyWith((message) => updates(message as UnmergeCellsRequest))
          as UnmergeCellsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UnmergeCellsRequest create() => UnmergeCellsRequest._();
  @$core.override
  UnmergeCellsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UnmergeCellsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UnmergeCellsRequest>(create);
  static UnmergeCellsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get gridId => $_getI64(0);
  @$pb.TagNumber(1)
  set gridId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGridId() => $_has(0);
  @$pb.TagNumber(1)
  void clearGridId() => $_clearField(1);

  @$pb.TagNumber(2)
  CellRange get range => $_getN(1);
  @$pb.TagNumber(2)
  set range(CellRange value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasRange() => $_has(1);
  @$pb.TagNumber(2)
  void clearRange() => $_clearField(2);
  @$pb.TagNumber(2)
  CellRange ensureRange() => $_ensure(1);
}

class MergedRegionsResponse extends $pb.GeneratedMessage {
  factory MergedRegionsResponse({
    $core.Iterable<CellRange>? ranges,
  }) {
    final result = create();
    if (ranges != null) result.ranges.addAll(ranges);
    return result;
  }

  MergedRegionsResponse._();

  factory MergedRegionsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MergedRegionsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MergedRegionsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..pPM<CellRange>(1, _omitFieldNames ? '' : 'ranges',
        subBuilder: CellRange.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MergedRegionsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MergedRegionsResponse copyWith(
          void Function(MergedRegionsResponse) updates) =>
      super.copyWith((message) => updates(message as MergedRegionsResponse))
          as MergedRegionsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MergedRegionsResponse create() => MergedRegionsResponse._();
  @$core.override
  MergedRegionsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MergedRegionsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MergedRegionsResponse>(create);
  static MergedRegionsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<CellRange> get ranges => $_getList(0);
}

class MemoryUsageResponse extends $pb.GeneratedMessage {
  factory MemoryUsageResponse({
    $fixnum.Int64? totalBytes,
    $fixnum.Int64? cellDataBytes,
    $fixnum.Int64? styleBytes,
    $fixnum.Int64? layoutBytes,
    $fixnum.Int64? columnBytes,
    $fixnum.Int64? rowBytes,
    $fixnum.Int64? selectionBytes,
    $fixnum.Int64? animationBytes,
    $fixnum.Int64? textEngineBytes,
    $fixnum.Int64? eventBytes,
    $fixnum.Int64? miscBytes,
    $core.int? cellCount,
    $core.int? rows,
    $core.int? cols,
  }) {
    final result = create();
    if (totalBytes != null) result.totalBytes = totalBytes;
    if (cellDataBytes != null) result.cellDataBytes = cellDataBytes;
    if (styleBytes != null) result.styleBytes = styleBytes;
    if (layoutBytes != null) result.layoutBytes = layoutBytes;
    if (columnBytes != null) result.columnBytes = columnBytes;
    if (rowBytes != null) result.rowBytes = rowBytes;
    if (selectionBytes != null) result.selectionBytes = selectionBytes;
    if (animationBytes != null) result.animationBytes = animationBytes;
    if (textEngineBytes != null) result.textEngineBytes = textEngineBytes;
    if (eventBytes != null) result.eventBytes = eventBytes;
    if (miscBytes != null) result.miscBytes = miscBytes;
    if (cellCount != null) result.cellCount = cellCount;
    if (rows != null) result.rows = rows;
    if (cols != null) result.cols = cols;
    return result;
  }

  MemoryUsageResponse._();

  factory MemoryUsageResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MemoryUsageResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MemoryUsageResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'totalBytes')
    ..aInt64(2, _omitFieldNames ? '' : 'cellDataBytes')
    ..aInt64(3, _omitFieldNames ? '' : 'styleBytes')
    ..aInt64(4, _omitFieldNames ? '' : 'layoutBytes')
    ..aInt64(5, _omitFieldNames ? '' : 'columnBytes')
    ..aInt64(6, _omitFieldNames ? '' : 'rowBytes')
    ..aInt64(7, _omitFieldNames ? '' : 'selectionBytes')
    ..aInt64(8, _omitFieldNames ? '' : 'animationBytes')
    ..aInt64(9, _omitFieldNames ? '' : 'textEngineBytes')
    ..aInt64(10, _omitFieldNames ? '' : 'eventBytes')
    ..aInt64(11, _omitFieldNames ? '' : 'miscBytes')
    ..aI(12, _omitFieldNames ? '' : 'cellCount')
    ..aI(13, _omitFieldNames ? '' : 'rows')
    ..aI(14, _omitFieldNames ? '' : 'cols')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MemoryUsageResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MemoryUsageResponse copyWith(void Function(MemoryUsageResponse) updates) =>
      super.copyWith((message) => updates(message as MemoryUsageResponse))
          as MemoryUsageResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MemoryUsageResponse create() => MemoryUsageResponse._();
  @$core.override
  MemoryUsageResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MemoryUsageResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MemoryUsageResponse>(create);
  static MemoryUsageResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get totalBytes => $_getI64(0);
  @$pb.TagNumber(1)
  set totalBytes($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTotalBytes() => $_has(0);
  @$pb.TagNumber(1)
  void clearTotalBytes() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get cellDataBytes => $_getI64(1);
  @$pb.TagNumber(2)
  set cellDataBytes($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCellDataBytes() => $_has(1);
  @$pb.TagNumber(2)
  void clearCellDataBytes() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get styleBytes => $_getI64(2);
  @$pb.TagNumber(3)
  set styleBytes($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasStyleBytes() => $_has(2);
  @$pb.TagNumber(3)
  void clearStyleBytes() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get layoutBytes => $_getI64(3);
  @$pb.TagNumber(4)
  set layoutBytes($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasLayoutBytes() => $_has(3);
  @$pb.TagNumber(4)
  void clearLayoutBytes() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get columnBytes => $_getI64(4);
  @$pb.TagNumber(5)
  set columnBytes($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasColumnBytes() => $_has(4);
  @$pb.TagNumber(5)
  void clearColumnBytes() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get rowBytes => $_getI64(5);
  @$pb.TagNumber(6)
  set rowBytes($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasRowBytes() => $_has(5);
  @$pb.TagNumber(6)
  void clearRowBytes() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get selectionBytes => $_getI64(6);
  @$pb.TagNumber(7)
  set selectionBytes($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasSelectionBytes() => $_has(6);
  @$pb.TagNumber(7)
  void clearSelectionBytes() => $_clearField(7);

  @$pb.TagNumber(8)
  $fixnum.Int64 get animationBytes => $_getI64(7);
  @$pb.TagNumber(8)
  set animationBytes($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasAnimationBytes() => $_has(7);
  @$pb.TagNumber(8)
  void clearAnimationBytes() => $_clearField(8);

  @$pb.TagNumber(9)
  $fixnum.Int64 get textEngineBytes => $_getI64(8);
  @$pb.TagNumber(9)
  set textEngineBytes($fixnum.Int64 value) => $_setInt64(8, value);
  @$pb.TagNumber(9)
  $core.bool hasTextEngineBytes() => $_has(8);
  @$pb.TagNumber(9)
  void clearTextEngineBytes() => $_clearField(9);

  @$pb.TagNumber(10)
  $fixnum.Int64 get eventBytes => $_getI64(9);
  @$pb.TagNumber(10)
  set eventBytes($fixnum.Int64 value) => $_setInt64(9, value);
  @$pb.TagNumber(10)
  $core.bool hasEventBytes() => $_has(9);
  @$pb.TagNumber(10)
  void clearEventBytes() => $_clearField(10);

  @$pb.TagNumber(11)
  $fixnum.Int64 get miscBytes => $_getI64(10);
  @$pb.TagNumber(11)
  set miscBytes($fixnum.Int64 value) => $_setInt64(10, value);
  @$pb.TagNumber(11)
  $core.bool hasMiscBytes() => $_has(10);
  @$pb.TagNumber(11)
  void clearMiscBytes() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.int get cellCount => $_getIZ(11);
  @$pb.TagNumber(12)
  set cellCount($core.int value) => $_setSignedInt32(11, value);
  @$pb.TagNumber(12)
  $core.bool hasCellCount() => $_has(11);
  @$pb.TagNumber(12)
  void clearCellCount() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.int get rows => $_getIZ(12);
  @$pb.TagNumber(13)
  set rows($core.int value) => $_setSignedInt32(12, value);
  @$pb.TagNumber(13)
  $core.bool hasRows() => $_has(12);
  @$pb.TagNumber(13)
  void clearRows() => $_clearField(13);

  @$pb.TagNumber(14)
  $core.int get cols => $_getIZ(13);
  @$pb.TagNumber(14)
  set cols($core.int value) => $_setSignedInt32(13, value);
  @$pb.TagNumber(14)
  $core.bool hasCols() => $_has(13);
  @$pb.TagNumber(14)
  void clearCols() => $_clearField(14);
}

enum ClipboardCommand_Command { copy, cut, paste, delete, notSet }

class ClipboardCommand extends $pb.GeneratedMessage {
  factory ClipboardCommand({
    $fixnum.Int64? gridId,
    ClipboardCopy? copy,
    ClipboardCut? cut,
    ClipboardPaste? paste,
    ClipboardDelete? delete,
  }) {
    final result = create();
    if (gridId != null) result.gridId = gridId;
    if (copy != null) result.copy = copy;
    if (cut != null) result.cut = cut;
    if (paste != null) result.paste = paste;
    if (delete != null) result.delete = delete;
    return result;
  }

  ClipboardCommand._();

  factory ClipboardCommand.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ClipboardCommand.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, ClipboardCommand_Command>
      _ClipboardCommand_CommandByTag = {
    2: ClipboardCommand_Command.copy,
    3: ClipboardCommand_Command.cut,
    4: ClipboardCommand_Command.paste,
    5: ClipboardCommand_Command.delete,
    0: ClipboardCommand_Command.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ClipboardCommand',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..oo(0, [2, 3, 4, 5])
    ..aInt64(1, _omitFieldNames ? '' : 'gridId')
    ..aOM<ClipboardCopy>(2, _omitFieldNames ? '' : 'copy',
        subBuilder: ClipboardCopy.create)
    ..aOM<ClipboardCut>(3, _omitFieldNames ? '' : 'cut',
        subBuilder: ClipboardCut.create)
    ..aOM<ClipboardPaste>(4, _omitFieldNames ? '' : 'paste',
        subBuilder: ClipboardPaste.create)
    ..aOM<ClipboardDelete>(5, _omitFieldNames ? '' : 'delete',
        subBuilder: ClipboardDelete.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClipboardCommand clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClipboardCommand copyWith(void Function(ClipboardCommand) updates) =>
      super.copyWith((message) => updates(message as ClipboardCommand))
          as ClipboardCommand;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ClipboardCommand create() => ClipboardCommand._();
  @$core.override
  ClipboardCommand createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ClipboardCommand getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClipboardCommand>(create);
  static ClipboardCommand? _defaultInstance;

  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  ClipboardCommand_Command whichCommand() =>
      _ClipboardCommand_CommandByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  void clearCommand() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $fixnum.Int64 get gridId => $_getI64(0);
  @$pb.TagNumber(1)
  set gridId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGridId() => $_has(0);
  @$pb.TagNumber(1)
  void clearGridId() => $_clearField(1);

  @$pb.TagNumber(2)
  ClipboardCopy get copy => $_getN(1);
  @$pb.TagNumber(2)
  set copy(ClipboardCopy value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasCopy() => $_has(1);
  @$pb.TagNumber(2)
  void clearCopy() => $_clearField(2);
  @$pb.TagNumber(2)
  ClipboardCopy ensureCopy() => $_ensure(1);

  @$pb.TagNumber(3)
  ClipboardCut get cut => $_getN(2);
  @$pb.TagNumber(3)
  set cut(ClipboardCut value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasCut() => $_has(2);
  @$pb.TagNumber(3)
  void clearCut() => $_clearField(3);
  @$pb.TagNumber(3)
  ClipboardCut ensureCut() => $_ensure(2);

  @$pb.TagNumber(4)
  ClipboardPaste get paste => $_getN(3);
  @$pb.TagNumber(4)
  set paste(ClipboardPaste value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasPaste() => $_has(3);
  @$pb.TagNumber(4)
  void clearPaste() => $_clearField(4);
  @$pb.TagNumber(4)
  ClipboardPaste ensurePaste() => $_ensure(3);

  @$pb.TagNumber(5)
  ClipboardDelete get delete => $_getN(4);
  @$pb.TagNumber(5)
  set delete(ClipboardDelete value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasDelete() => $_has(4);
  @$pb.TagNumber(5)
  void clearDelete() => $_clearField(5);
  @$pb.TagNumber(5)
  ClipboardDelete ensureDelete() => $_ensure(4);
}

class ClipboardCopy extends $pb.GeneratedMessage {
  factory ClipboardCopy() => create();

  ClipboardCopy._();

  factory ClipboardCopy.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ClipboardCopy.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ClipboardCopy',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClipboardCopy clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClipboardCopy copyWith(void Function(ClipboardCopy) updates) =>
      super.copyWith((message) => updates(message as ClipboardCopy))
          as ClipboardCopy;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ClipboardCopy create() => ClipboardCopy._();
  @$core.override
  ClipboardCopy createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ClipboardCopy getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClipboardCopy>(create);
  static ClipboardCopy? _defaultInstance;
}

class ClipboardCut extends $pb.GeneratedMessage {
  factory ClipboardCut() => create();

  ClipboardCut._();

  factory ClipboardCut.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ClipboardCut.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ClipboardCut',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClipboardCut clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClipboardCut copyWith(void Function(ClipboardCut) updates) =>
      super.copyWith((message) => updates(message as ClipboardCut))
          as ClipboardCut;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ClipboardCut create() => ClipboardCut._();
  @$core.override
  ClipboardCut createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ClipboardCut getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClipboardCut>(create);
  static ClipboardCut? _defaultInstance;
}

class ClipboardPaste extends $pb.GeneratedMessage {
  factory ClipboardPaste({
    $core.String? text,
    $core.List<$core.int>? richData,
  }) {
    final result = create();
    if (text != null) result.text = text;
    if (richData != null) result.richData = richData;
    return result;
  }

  ClipboardPaste._();

  factory ClipboardPaste.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ClipboardPaste.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ClipboardPaste',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'text')
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'richData', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClipboardPaste clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClipboardPaste copyWith(void Function(ClipboardPaste) updates) =>
      super.copyWith((message) => updates(message as ClipboardPaste))
          as ClipboardPaste;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ClipboardPaste create() => ClipboardPaste._();
  @$core.override
  ClipboardPaste createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ClipboardPaste getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClipboardPaste>(create);
  static ClipboardPaste? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get text => $_getSZ(0);
  @$pb.TagNumber(1)
  set text($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasText() => $_has(0);
  @$pb.TagNumber(1)
  void clearText() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get richData => $_getN(1);
  @$pb.TagNumber(2)
  set richData($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRichData() => $_has(1);
  @$pb.TagNumber(2)
  void clearRichData() => $_clearField(2);
}

class ClipboardDelete extends $pb.GeneratedMessage {
  factory ClipboardDelete() => create();

  ClipboardDelete._();

  factory ClipboardDelete.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ClipboardDelete.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ClipboardDelete',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClipboardDelete clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClipboardDelete copyWith(void Function(ClipboardDelete) updates) =>
      super.copyWith((message) => updates(message as ClipboardDelete))
          as ClipboardDelete;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ClipboardDelete create() => ClipboardDelete._();
  @$core.override
  ClipboardDelete createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ClipboardDelete getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClipboardDelete>(create);
  static ClipboardDelete? _defaultInstance;
}

class ClipboardResponse extends $pb.GeneratedMessage {
  factory ClipboardResponse({
    $core.String? text,
    $core.List<$core.int>? richData,
  }) {
    final result = create();
    if (text != null) result.text = text;
    if (richData != null) result.richData = richData;
    return result;
  }

  ClipboardResponse._();

  factory ClipboardResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ClipboardResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ClipboardResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'text')
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'richData', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClipboardResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClipboardResponse copyWith(void Function(ClipboardResponse) updates) =>
      super.copyWith((message) => updates(message as ClipboardResponse))
          as ClipboardResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ClipboardResponse create() => ClipboardResponse._();
  @$core.override
  ClipboardResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ClipboardResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClipboardResponse>(create);
  static ClipboardResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get text => $_getSZ(0);
  @$pb.TagNumber(1)
  set text($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasText() => $_has(0);
  @$pb.TagNumber(1)
  void clearText() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get richData => $_getN(1);
  @$pb.TagNumber(2)
  set richData($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRichData() => $_has(1);
  @$pb.TagNumber(2)
  void clearRichData() => $_clearField(2);
}

class ExportRequest extends $pb.GeneratedMessage {
  factory ExportRequest({
    $fixnum.Int64? gridId,
    ExportFormat? format,
    ExportScope? scope,
  }) {
    final result = create();
    if (gridId != null) result.gridId = gridId;
    if (format != null) result.format = format;
    if (scope != null) result.scope = scope;
    return result;
  }

  ExportRequest._();

  factory ExportRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ExportRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ExportRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'gridId')
    ..aE<ExportFormat>(2, _omitFieldNames ? '' : 'format',
        enumValues: ExportFormat.values)
    ..aE<ExportScope>(3, _omitFieldNames ? '' : 'scope',
        enumValues: ExportScope.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExportRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExportRequest copyWith(void Function(ExportRequest) updates) =>
      super.copyWith((message) => updates(message as ExportRequest))
          as ExportRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ExportRequest create() => ExportRequest._();
  @$core.override
  ExportRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ExportRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ExportRequest>(create);
  static ExportRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get gridId => $_getI64(0);
  @$pb.TagNumber(1)
  set gridId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGridId() => $_has(0);
  @$pb.TagNumber(1)
  void clearGridId() => $_clearField(1);

  @$pb.TagNumber(2)
  ExportFormat get format => $_getN(1);
  @$pb.TagNumber(2)
  set format(ExportFormat value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasFormat() => $_has(1);
  @$pb.TagNumber(2)
  void clearFormat() => $_clearField(2);

  @$pb.TagNumber(3)
  ExportScope get scope => $_getN(2);
  @$pb.TagNumber(3)
  set scope(ExportScope value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasScope() => $_has(2);
  @$pb.TagNumber(3)
  void clearScope() => $_clearField(3);
}

class ExportResponse extends $pb.GeneratedMessage {
  factory ExportResponse({
    $core.List<$core.int>? data,
    ExportFormat? format,
  }) {
    final result = create();
    if (data != null) result.data = data;
    if (format != null) result.format = format;
    return result;
  }

  ExportResponse._();

  factory ExportResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ExportResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ExportResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OY)
    ..aE<ExportFormat>(2, _omitFieldNames ? '' : 'format',
        enumValues: ExportFormat.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExportResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExportResponse copyWith(void Function(ExportResponse) updates) =>
      super.copyWith((message) => updates(message as ExportResponse))
          as ExportResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ExportResponse create() => ExportResponse._();
  @$core.override
  ExportResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ExportResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ExportResponse>(create);
  static ExportResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get data => $_getN(0);
  @$pb.TagNumber(1)
  set data($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasData() => $_has(0);
  @$pb.TagNumber(1)
  void clearData() => $_clearField(1);

  @$pb.TagNumber(2)
  ExportFormat get format => $_getN(1);
  @$pb.TagNumber(2)
  set format(ExportFormat value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasFormat() => $_has(1);
  @$pb.TagNumber(2)
  void clearFormat() => $_clearField(2);
}

class PrintRequest extends $pb.GeneratedMessage {
  factory PrintRequest({
    $fixnum.Int64? gridId,
    PrintOrientation? orientation,
    $core.int? marginLeft,
    $core.int? marginTop,
    $core.int? marginRight,
    $core.int? marginBottom,
    $core.String? header,
    $core.String? footer,
    $core.bool? showPageNumbers,
  }) {
    final result = create();
    if (gridId != null) result.gridId = gridId;
    if (orientation != null) result.orientation = orientation;
    if (marginLeft != null) result.marginLeft = marginLeft;
    if (marginTop != null) result.marginTop = marginTop;
    if (marginRight != null) result.marginRight = marginRight;
    if (marginBottom != null) result.marginBottom = marginBottom;
    if (header != null) result.header = header;
    if (footer != null) result.footer = footer;
    if (showPageNumbers != null) result.showPageNumbers = showPageNumbers;
    return result;
  }

  PrintRequest._();

  factory PrintRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PrintRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PrintRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'gridId')
    ..aE<PrintOrientation>(2, _omitFieldNames ? '' : 'orientation',
        enumValues: PrintOrientation.values)
    ..aI(3, _omitFieldNames ? '' : 'marginLeft')
    ..aI(4, _omitFieldNames ? '' : 'marginTop')
    ..aI(5, _omitFieldNames ? '' : 'marginRight')
    ..aI(6, _omitFieldNames ? '' : 'marginBottom')
    ..aOS(7, _omitFieldNames ? '' : 'header')
    ..aOS(8, _omitFieldNames ? '' : 'footer')
    ..aOB(9, _omitFieldNames ? '' : 'showPageNumbers')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PrintRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PrintRequest copyWith(void Function(PrintRequest) updates) =>
      super.copyWith((message) => updates(message as PrintRequest))
          as PrintRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PrintRequest create() => PrintRequest._();
  @$core.override
  PrintRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PrintRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PrintRequest>(create);
  static PrintRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get gridId => $_getI64(0);
  @$pb.TagNumber(1)
  set gridId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGridId() => $_has(0);
  @$pb.TagNumber(1)
  void clearGridId() => $_clearField(1);

  @$pb.TagNumber(2)
  PrintOrientation get orientation => $_getN(1);
  @$pb.TagNumber(2)
  set orientation(PrintOrientation value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasOrientation() => $_has(1);
  @$pb.TagNumber(2)
  void clearOrientation() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get marginLeft => $_getIZ(2);
  @$pb.TagNumber(3)
  set marginLeft($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMarginLeft() => $_has(2);
  @$pb.TagNumber(3)
  void clearMarginLeft() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get marginTop => $_getIZ(3);
  @$pb.TagNumber(4)
  set marginTop($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasMarginTop() => $_has(3);
  @$pb.TagNumber(4)
  void clearMarginTop() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get marginRight => $_getIZ(4);
  @$pb.TagNumber(5)
  set marginRight($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasMarginRight() => $_has(4);
  @$pb.TagNumber(5)
  void clearMarginRight() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get marginBottom => $_getIZ(5);
  @$pb.TagNumber(6)
  set marginBottom($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasMarginBottom() => $_has(5);
  @$pb.TagNumber(6)
  void clearMarginBottom() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get header => $_getSZ(6);
  @$pb.TagNumber(7)
  set header($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasHeader() => $_has(6);
  @$pb.TagNumber(7)
  void clearHeader() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get footer => $_getSZ(7);
  @$pb.TagNumber(8)
  set footer($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasFooter() => $_has(7);
  @$pb.TagNumber(8)
  void clearFooter() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.bool get showPageNumbers => $_getBF(8);
  @$pb.TagNumber(9)
  set showPageNumbers($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasShowPageNumbers() => $_has(8);
  @$pb.TagNumber(9)
  void clearShowPageNumbers() => $_clearField(9);
}

class PrintResponse extends $pb.GeneratedMessage {
  factory PrintResponse({
    $core.Iterable<PrintPage>? pages,
  }) {
    final result = create();
    if (pages != null) result.pages.addAll(pages);
    return result;
  }

  PrintResponse._();

  factory PrintResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PrintResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PrintResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..pPM<PrintPage>(1, _omitFieldNames ? '' : 'pages',
        subBuilder: PrintPage.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PrintResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PrintResponse copyWith(void Function(PrintResponse) updates) =>
      super.copyWith((message) => updates(message as PrintResponse))
          as PrintResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PrintResponse create() => PrintResponse._();
  @$core.override
  PrintResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PrintResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PrintResponse>(create);
  static PrintResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<PrintPage> get pages => $_getList(0);
}

class PrintPage extends $pb.GeneratedMessage {
  factory PrintPage({
    $core.int? pageNumber,
    $core.List<$core.int>? imageData,
    $core.int? width,
    $core.int? height,
  }) {
    final result = create();
    if (pageNumber != null) result.pageNumber = pageNumber;
    if (imageData != null) result.imageData = imageData;
    if (width != null) result.width = width;
    if (height != null) result.height = height;
    return result;
  }

  PrintPage._();

  factory PrintPage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PrintPage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PrintPage',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'pageNumber')
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'imageData', $pb.PbFieldType.OY)
    ..aI(3, _omitFieldNames ? '' : 'width')
    ..aI(4, _omitFieldNames ? '' : 'height')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PrintPage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PrintPage copyWith(void Function(PrintPage) updates) =>
      super.copyWith((message) => updates(message as PrintPage)) as PrintPage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PrintPage create() => PrintPage._();
  @$core.override
  PrintPage createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PrintPage getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PrintPage>(create);
  static PrintPage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get pageNumber => $_getIZ(0);
  @$pb.TagNumber(1)
  set pageNumber($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPageNumber() => $_has(0);
  @$pb.TagNumber(1)
  void clearPageNumber() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get imageData => $_getN(1);
  @$pb.TagNumber(2)
  set imageData($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasImageData() => $_has(1);
  @$pb.TagNumber(2)
  void clearImageData() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get width => $_getIZ(2);
  @$pb.TagNumber(3)
  set width($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasWidth() => $_has(2);
  @$pb.TagNumber(3)
  void clearWidth() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get height => $_getIZ(3);
  @$pb.TagNumber(4)
  set height($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasHeight() => $_has(3);
  @$pb.TagNumber(4)
  void clearHeight() => $_clearField(4);
}

class ArchiveRequest extends $pb.GeneratedMessage {
  factory ArchiveRequest({
    $fixnum.Int64? gridId,
    $core.String? name,
    ArchiveRequest_Action? action,
    $core.List<$core.int>? data,
  }) {
    final result = create();
    if (gridId != null) result.gridId = gridId;
    if (name != null) result.name = name;
    if (action != null) result.action = action;
    if (data != null) result.data = data;
    return result;
  }

  ArchiveRequest._();

  factory ArchiveRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ArchiveRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ArchiveRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'gridId')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aE<ArchiveRequest_Action>(3, _omitFieldNames ? '' : 'action',
        enumValues: ArchiveRequest_Action.values)
    ..a<$core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ArchiveRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ArchiveRequest copyWith(void Function(ArchiveRequest) updates) =>
      super.copyWith((message) => updates(message as ArchiveRequest))
          as ArchiveRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ArchiveRequest create() => ArchiveRequest._();
  @$core.override
  ArchiveRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ArchiveRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ArchiveRequest>(create);
  static ArchiveRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get gridId => $_getI64(0);
  @$pb.TagNumber(1)
  set gridId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGridId() => $_has(0);
  @$pb.TagNumber(1)
  void clearGridId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  ArchiveRequest_Action get action => $_getN(2);
  @$pb.TagNumber(3)
  set action(ArchiveRequest_Action value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasAction() => $_has(2);
  @$pb.TagNumber(3)
  void clearAction() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get data => $_getN(3);
  @$pb.TagNumber(4)
  set data($core.List<$core.int> value) => $_setBytes(3, value);
  @$pb.TagNumber(4)
  $core.bool hasData() => $_has(3);
  @$pb.TagNumber(4)
  void clearData() => $_clearField(4);
}

class ArchiveResponse extends $pb.GeneratedMessage {
  factory ArchiveResponse({
    $core.List<$core.int>? data,
    $core.Iterable<$core.String>? names,
  }) {
    final result = create();
    if (data != null) result.data = data;
    if (names != null) result.names.addAll(names);
    return result;
  }

  ArchiveResponse._();

  factory ArchiveResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ArchiveResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ArchiveResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OY)
    ..pPS(2, _omitFieldNames ? '' : 'names')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ArchiveResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ArchiveResponse copyWith(void Function(ArchiveResponse) updates) =>
      super.copyWith((message) => updates(message as ArchiveResponse))
          as ArchiveResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ArchiveResponse create() => ArchiveResponse._();
  @$core.override
  ArchiveResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ArchiveResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ArchiveResponse>(create);
  static ArchiveResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get data => $_getN(0);
  @$pb.TagNumber(1)
  set data($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasData() => $_has(0);
  @$pb.TagNumber(1)
  void clearData() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<$core.String> get names => $_getList(1);
}

class Empty extends $pb.GeneratedMessage {
  factory Empty() => create();

  Empty._();

  factory Empty.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Empty.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Empty',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Empty clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Empty copyWith(void Function(Empty) updates) =>
      super.copyWith((message) => updates(message as Empty)) as Empty;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Empty create() => Empty._();
  @$core.override
  Empty createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Empty getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Empty>(create);
  static Empty? _defaultInstance;
}

class GridHandle extends $pb.GeneratedMessage {
  factory GridHandle({
    $fixnum.Int64? id,
  }) {
    final result = create();
    if (id != null) result.id = id;
    return result;
  }

  GridHandle._();

  factory GridHandle.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GridHandle.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GridHandle',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GridHandle clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GridHandle copyWith(void Function(GridHandle) updates) =>
      super.copyWith((message) => updates(message as GridHandle)) as GridHandle;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GridHandle create() => GridHandle._();
  @$core.override
  GridHandle createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GridHandle getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GridHandle>(create);
  static GridHandle? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get id => $_getI64(0);
  @$pb.TagNumber(1)
  set id($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

class CreateRequest extends $pb.GeneratedMessage {
  factory CreateRequest({
    $core.int? viewportWidth,
    $core.int? viewportHeight,
    $core.double? scale,
    GridConfig? config,
  }) {
    final result = create();
    if (viewportWidth != null) result.viewportWidth = viewportWidth;
    if (viewportHeight != null) result.viewportHeight = viewportHeight;
    if (scale != null) result.scale = scale;
    if (config != null) result.config = config;
    return result;
  }

  CreateRequest._();

  factory CreateRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'viewportWidth')
    ..aI(2, _omitFieldNames ? '' : 'viewportHeight')
    ..aD(3, _omitFieldNames ? '' : 'scale', fieldType: $pb.PbFieldType.OF)
    ..aOM<GridConfig>(4, _omitFieldNames ? '' : 'config',
        subBuilder: GridConfig.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateRequest copyWith(void Function(CreateRequest) updates) =>
      super.copyWith((message) => updates(message as CreateRequest))
          as CreateRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateRequest create() => CreateRequest._();
  @$core.override
  CreateRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreateRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateRequest>(create);
  static CreateRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get viewportWidth => $_getIZ(0);
  @$pb.TagNumber(1)
  set viewportWidth($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasViewportWidth() => $_has(0);
  @$pb.TagNumber(1)
  void clearViewportWidth() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get viewportHeight => $_getIZ(1);
  @$pb.TagNumber(2)
  set viewportHeight($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasViewportHeight() => $_has(1);
  @$pb.TagNumber(2)
  void clearViewportHeight() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get scale => $_getN(2);
  @$pb.TagNumber(3)
  set scale($core.double value) => $_setFloat(2, value);
  @$pb.TagNumber(3)
  $core.bool hasScale() => $_has(2);
  @$pb.TagNumber(3)
  void clearScale() => $_clearField(3);

  @$pb.TagNumber(4)
  GridConfig get config => $_getN(3);
  @$pb.TagNumber(4)
  set config(GridConfig value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasConfig() => $_has(3);
  @$pb.TagNumber(4)
  void clearConfig() => $_clearField(4);
  @$pb.TagNumber(4)
  GridConfig ensureConfig() => $_ensure(3);
}

class CreateResponse extends $pb.GeneratedMessage {
  factory CreateResponse({
    GridHandle? handle,
    $core.Iterable<$core.String>? warnings,
  }) {
    final result = create();
    if (handle != null) result.handle = handle;
    if (warnings != null) result.warnings.addAll(warnings);
    return result;
  }

  CreateResponse._();

  factory CreateResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aOM<GridHandle>(1, _omitFieldNames ? '' : 'handle',
        subBuilder: GridHandle.create)
    ..pPS(2, _omitFieldNames ? '' : 'warnings')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateResponse copyWith(void Function(CreateResponse) updates) =>
      super.copyWith((message) => updates(message as CreateResponse))
          as CreateResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateResponse create() => CreateResponse._();
  @$core.override
  CreateResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreateResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateResponse>(create);
  static CreateResponse? _defaultInstance;

  @$pb.TagNumber(1)
  GridHandle get handle => $_getN(0);
  @$pb.TagNumber(1)
  set handle(GridHandle value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasHandle() => $_has(0);
  @$pb.TagNumber(1)
  void clearHandle() => $_clearField(1);
  @$pb.TagNumber(1)
  GridHandle ensureHandle() => $_ensure(0);

  @$pb.TagNumber(2)
  $pb.PbList<$core.String> get warnings => $_getList(1);
}

class ResizeViewportRequest extends $pb.GeneratedMessage {
  factory ResizeViewportRequest({
    $fixnum.Int64? gridId,
    $core.int? width,
    $core.int? height,
  }) {
    final result = create();
    if (gridId != null) result.gridId = gridId;
    if (width != null) result.width = width;
    if (height != null) result.height = height;
    return result;
  }

  ResizeViewportRequest._();

  factory ResizeViewportRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ResizeViewportRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ResizeViewportRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'gridId')
    ..aI(2, _omitFieldNames ? '' : 'width')
    ..aI(3, _omitFieldNames ? '' : 'height')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResizeViewportRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResizeViewportRequest copyWith(
          void Function(ResizeViewportRequest) updates) =>
      super.copyWith((message) => updates(message as ResizeViewportRequest))
          as ResizeViewportRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ResizeViewportRequest create() => ResizeViewportRequest._();
  @$core.override
  ResizeViewportRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ResizeViewportRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ResizeViewportRequest>(create);
  static ResizeViewportRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get gridId => $_getI64(0);
  @$pb.TagNumber(1)
  set gridId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGridId() => $_has(0);
  @$pb.TagNumber(1)
  void clearGridId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get width => $_getIZ(1);
  @$pb.TagNumber(2)
  set width($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasWidth() => $_has(1);
  @$pb.TagNumber(2)
  void clearWidth() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get height => $_getIZ(2);
  @$pb.TagNumber(3)
  set height($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasHeight() => $_has(2);
  @$pb.TagNumber(3)
  void clearHeight() => $_clearField(3);
}

class ShowCellRequest extends $pb.GeneratedMessage {
  factory ShowCellRequest({
    $fixnum.Int64? gridId,
    $core.int? row,
    $core.int? col,
  }) {
    final result = create();
    if (gridId != null) result.gridId = gridId;
    if (row != null) result.row = row;
    if (col != null) result.col = col;
    return result;
  }

  ShowCellRequest._();

  factory ShowCellRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ShowCellRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ShowCellRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'gridId')
    ..aI(2, _omitFieldNames ? '' : 'row')
    ..aI(3, _omitFieldNames ? '' : 'col')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ShowCellRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ShowCellRequest copyWith(void Function(ShowCellRequest) updates) =>
      super.copyWith((message) => updates(message as ShowCellRequest))
          as ShowCellRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ShowCellRequest create() => ShowCellRequest._();
  @$core.override
  ShowCellRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ShowCellRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ShowCellRequest>(create);
  static ShowCellRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get gridId => $_getI64(0);
  @$pb.TagNumber(1)
  set gridId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGridId() => $_has(0);
  @$pb.TagNumber(1)
  void clearGridId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get row => $_getIZ(1);
  @$pb.TagNumber(2)
  set row($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRow() => $_has(1);
  @$pb.TagNumber(2)
  void clearRow() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get col => $_getIZ(2);
  @$pb.TagNumber(3)
  set col($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCol() => $_has(2);
  @$pb.TagNumber(3)
  void clearCol() => $_clearField(3);
}

class SetRowRequest extends $pb.GeneratedMessage {
  factory SetRowRequest({
    $fixnum.Int64? gridId,
    $core.int? row,
  }) {
    final result = create();
    if (gridId != null) result.gridId = gridId;
    if (row != null) result.row = row;
    return result;
  }

  SetRowRequest._();

  factory SetRowRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SetRowRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetRowRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'gridId')
    ..aI(2, _omitFieldNames ? '' : 'row')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetRowRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetRowRequest copyWith(void Function(SetRowRequest) updates) =>
      super.copyWith((message) => updates(message as SetRowRequest))
          as SetRowRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetRowRequest create() => SetRowRequest._();
  @$core.override
  SetRowRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SetRowRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetRowRequest>(create);
  static SetRowRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get gridId => $_getI64(0);
  @$pb.TagNumber(1)
  set gridId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGridId() => $_has(0);
  @$pb.TagNumber(1)
  void clearGridId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get row => $_getIZ(1);
  @$pb.TagNumber(2)
  set row($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRow() => $_has(1);
  @$pb.TagNumber(2)
  void clearRow() => $_clearField(2);
}

class SetColRequest extends $pb.GeneratedMessage {
  factory SetColRequest({
    $fixnum.Int64? gridId,
    $core.int? col,
  }) {
    final result = create();
    if (gridId != null) result.gridId = gridId;
    if (col != null) result.col = col;
    return result;
  }

  SetColRequest._();

  factory SetColRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SetColRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetColRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'gridId')
    ..aI(2, _omitFieldNames ? '' : 'col')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetColRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetColRequest copyWith(void Function(SetColRequest) updates) =>
      super.copyWith((message) => updates(message as SetColRequest))
          as SetColRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetColRequest create() => SetColRequest._();
  @$core.override
  SetColRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SetColRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetColRequest>(create);
  static SetColRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get gridId => $_getI64(0);
  @$pb.TagNumber(1)
  set gridId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGridId() => $_has(0);
  @$pb.TagNumber(1)
  void clearGridId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get col => $_getIZ(1);
  @$pb.TagNumber(2)
  set col($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCol() => $_has(1);
  @$pb.TagNumber(2)
  void clearCol() => $_clearField(2);
}

class SetRedrawRequest extends $pb.GeneratedMessage {
  factory SetRedrawRequest({
    $fixnum.Int64? gridId,
    $core.bool? enabled,
  }) {
    final result = create();
    if (gridId != null) result.gridId = gridId;
    if (enabled != null) result.enabled = enabled;
    return result;
  }

  SetRedrawRequest._();

  factory SetRedrawRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SetRedrawRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetRedrawRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'gridId')
    ..aOB(2, _omitFieldNames ? '' : 'enabled')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetRedrawRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetRedrawRequest copyWith(void Function(SetRedrawRequest) updates) =>
      super.copyWith((message) => updates(message as SetRedrawRequest))
          as SetRedrawRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetRedrawRequest create() => SetRedrawRequest._();
  @$core.override
  SetRedrawRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SetRedrawRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetRedrawRequest>(create);
  static SetRedrawRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get gridId => $_getI64(0);
  @$pb.TagNumber(1)
  set gridId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGridId() => $_has(0);
  @$pb.TagNumber(1)
  void clearGridId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get enabled => $_getBF(1);
  @$pb.TagNumber(2)
  set enabled($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEnabled() => $_has(1);
  @$pb.TagNumber(2)
  void clearEnabled() => $_clearField(2);
}

class ConfigureRequest extends $pb.GeneratedMessage {
  factory ConfigureRequest({
    $fixnum.Int64? gridId,
    GridConfig? config,
  }) {
    final result = create();
    if (gridId != null) result.gridId = gridId;
    if (config != null) result.config = config;
    return result;
  }

  ConfigureRequest._();

  factory ConfigureRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ConfigureRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ConfigureRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'gridId')
    ..aOM<GridConfig>(2, _omitFieldNames ? '' : 'config',
        subBuilder: GridConfig.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConfigureRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConfigureRequest copyWith(void Function(ConfigureRequest) updates) =>
      super.copyWith((message) => updates(message as ConfigureRequest))
          as ConfigureRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ConfigureRequest create() => ConfigureRequest._();
  @$core.override
  ConfigureRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ConfigureRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ConfigureRequest>(create);
  static ConfigureRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get gridId => $_getI64(0);
  @$pb.TagNumber(1)
  set gridId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGridId() => $_has(0);
  @$pb.TagNumber(1)
  void clearGridId() => $_clearField(1);

  @$pb.TagNumber(2)
  GridConfig get config => $_getN(1);
  @$pb.TagNumber(2)
  set config(GridConfig value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasConfig() => $_has(1);
  @$pb.TagNumber(2)
  void clearConfig() => $_clearField(2);
  @$pb.TagNumber(2)
  GridConfig ensureConfig() => $_ensure(1);
}

class LoadFontDataRequest extends $pb.GeneratedMessage {
  factory LoadFontDataRequest({
    $core.List<$core.int>? data,
    $core.String? fontName,
    $core.Iterable<$core.String>? fontNames,
  }) {
    final result = create();
    if (data != null) result.data = data;
    if (fontName != null) result.fontName = fontName;
    if (fontNames != null) result.fontNames.addAll(fontNames);
    return result;
  }

  LoadFontDataRequest._();

  factory LoadFontDataRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory LoadFontDataRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LoadFontDataRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OY)
    ..aOS(2, _omitFieldNames ? '' : 'fontName')
    ..pPS(3, _omitFieldNames ? '' : 'fontNames')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoadFontDataRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoadFontDataRequest copyWith(void Function(LoadFontDataRequest) updates) =>
      super.copyWith((message) => updates(message as LoadFontDataRequest))
          as LoadFontDataRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LoadFontDataRequest create() => LoadFontDataRequest._();
  @$core.override
  LoadFontDataRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static LoadFontDataRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LoadFontDataRequest>(create);
  static LoadFontDataRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get data => $_getN(0);
  @$pb.TagNumber(1)
  set data($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasData() => $_has(0);
  @$pb.TagNumber(1)
  void clearData() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get fontName => $_getSZ(1);
  @$pb.TagNumber(2)
  set fontName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFontName() => $_has(1);
  @$pb.TagNumber(2)
  void clearFontName() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbList<$core.String> get fontNames => $_getList(2);
}

class LoadDemoRequest extends $pb.GeneratedMessage {
  factory LoadDemoRequest({
    $fixnum.Int64? gridId,
    $core.String? demo,
  }) {
    final result = create();
    if (gridId != null) result.gridId = gridId;
    if (demo != null) result.demo = demo;
    return result;
  }

  LoadDemoRequest._();

  factory LoadDemoRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory LoadDemoRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LoadDemoRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'gridId')
    ..aOS(2, _omitFieldNames ? '' : 'demo')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoadDemoRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoadDemoRequest copyWith(void Function(LoadDemoRequest) updates) =>
      super.copyWith((message) => updates(message as LoadDemoRequest))
          as LoadDemoRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LoadDemoRequest create() => LoadDemoRequest._();
  @$core.override
  LoadDemoRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static LoadDemoRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LoadDemoRequest>(create);
  static LoadDemoRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get gridId => $_getI64(0);
  @$pb.TagNumber(1)
  set gridId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGridId() => $_has(0);
  @$pb.TagNumber(1)
  void clearGridId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get demo => $_getSZ(1);
  @$pb.TagNumber(2)
  set demo($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDemo() => $_has(1);
  @$pb.TagNumber(2)
  void clearDemo() => $_clearField(2);
}

class GetDemoDataRequest extends $pb.GeneratedMessage {
  factory GetDemoDataRequest({
    $core.String? demo,
  }) {
    final result = create();
    if (demo != null) result.demo = demo;
    return result;
  }

  GetDemoDataRequest._();

  factory GetDemoDataRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetDemoDataRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetDemoDataRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'demo')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetDemoDataRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetDemoDataRequest copyWith(void Function(GetDemoDataRequest) updates) =>
      super.copyWith((message) => updates(message as GetDemoDataRequest))
          as GetDemoDataRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetDemoDataRequest create() => GetDemoDataRequest._();
  @$core.override
  GetDemoDataRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetDemoDataRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetDemoDataRequest>(create);
  static GetDemoDataRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get demo => $_getSZ(0);
  @$pb.TagNumber(1)
  set demo($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDemo() => $_has(0);
  @$pb.TagNumber(1)
  void clearDemo() => $_clearField(1);
}

class GetDemoDataResponse extends $pb.GeneratedMessage {
  factory GetDemoDataResponse({
    $core.String? demo,
    DemoDataFormat? format,
    $core.List<$core.int>? data,
  }) {
    final result = create();
    if (demo != null) result.demo = demo;
    if (format != null) result.format = format;
    if (data != null) result.data = data;
    return result;
  }

  GetDemoDataResponse._();

  factory GetDemoDataResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetDemoDataResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetDemoDataResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'demo')
    ..aE<DemoDataFormat>(2, _omitFieldNames ? '' : 'format',
        enumValues: DemoDataFormat.values)
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetDemoDataResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetDemoDataResponse copyWith(void Function(GetDemoDataResponse) updates) =>
      super.copyWith((message) => updates(message as GetDemoDataResponse))
          as GetDemoDataResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetDemoDataResponse create() => GetDemoDataResponse._();
  @$core.override
  GetDemoDataResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetDemoDataResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetDemoDataResponse>(create);
  static GetDemoDataResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get demo => $_getSZ(0);
  @$pb.TagNumber(1)
  set demo($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDemo() => $_has(0);
  @$pb.TagNumber(1)
  void clearDemo() => $_clearField(1);

  @$pb.TagNumber(2)
  DemoDataFormat get format => $_getN(1);
  @$pb.TagNumber(2)
  set format(DemoDataFormat value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasFormat() => $_has(1);
  @$pb.TagNumber(2)
  void clearFormat() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get data => $_getN(2);
  @$pb.TagNumber(3)
  set data($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasData() => $_has(2);
  @$pb.TagNumber(3)
  void clearData() => $_clearField(3);
}

enum RenderInput_Input {
  viewport,
  pointer,
  key,
  buffer,
  scroll,
  eventDecision,
  zoom,
  gpuSurface,
  notSet
}

class RenderInput extends $pb.GeneratedMessage {
  factory RenderInput({
    $fixnum.Int64? gridId,
    ViewportState? viewport,
    PointerEvent? pointer,
    KeyEvent? key,
    BufferReady? buffer,
    ScrollEvent? scroll,
    EventDecision? eventDecision,
    ZoomEvent? zoom,
    GpuSurfaceReady? gpuSurface,
  }) {
    final result = create();
    if (gridId != null) result.gridId = gridId;
    if (viewport != null) result.viewport = viewport;
    if (pointer != null) result.pointer = pointer;
    if (key != null) result.key = key;
    if (buffer != null) result.buffer = buffer;
    if (scroll != null) result.scroll = scroll;
    if (eventDecision != null) result.eventDecision = eventDecision;
    if (zoom != null) result.zoom = zoom;
    if (gpuSurface != null) result.gpuSurface = gpuSurface;
    return result;
  }

  RenderInput._();

  factory RenderInput.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RenderInput.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, RenderInput_Input> _RenderInput_InputByTag =
      {
    2: RenderInput_Input.viewport,
    3: RenderInput_Input.pointer,
    4: RenderInput_Input.key,
    5: RenderInput_Input.buffer,
    6: RenderInput_Input.scroll,
    7: RenderInput_Input.eventDecision,
    8: RenderInput_Input.zoom,
    9: RenderInput_Input.gpuSurface,
    0: RenderInput_Input.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RenderInput',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..oo(0, [2, 3, 4, 5, 6, 7, 8, 9])
    ..aInt64(1, _omitFieldNames ? '' : 'gridId')
    ..aOM<ViewportState>(2, _omitFieldNames ? '' : 'viewport',
        subBuilder: ViewportState.create)
    ..aOM<PointerEvent>(3, _omitFieldNames ? '' : 'pointer',
        subBuilder: PointerEvent.create)
    ..aOM<KeyEvent>(4, _omitFieldNames ? '' : 'key',
        subBuilder: KeyEvent.create)
    ..aOM<BufferReady>(5, _omitFieldNames ? '' : 'buffer',
        subBuilder: BufferReady.create)
    ..aOM<ScrollEvent>(6, _omitFieldNames ? '' : 'scroll',
        subBuilder: ScrollEvent.create)
    ..aOM<EventDecision>(7, _omitFieldNames ? '' : 'eventDecision',
        subBuilder: EventDecision.create)
    ..aOM<ZoomEvent>(8, _omitFieldNames ? '' : 'zoom',
        subBuilder: ZoomEvent.create)
    ..aOM<GpuSurfaceReady>(9, _omitFieldNames ? '' : 'gpuSurface',
        subBuilder: GpuSurfaceReady.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RenderInput clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RenderInput copyWith(void Function(RenderInput) updates) =>
      super.copyWith((message) => updates(message as RenderInput))
          as RenderInput;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RenderInput create() => RenderInput._();
  @$core.override
  RenderInput createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RenderInput getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RenderInput>(create);
  static RenderInput? _defaultInstance;

  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  @$pb.TagNumber(9)
  RenderInput_Input whichInput() => _RenderInput_InputByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  @$pb.TagNumber(9)
  void clearInput() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $fixnum.Int64 get gridId => $_getI64(0);
  @$pb.TagNumber(1)
  set gridId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGridId() => $_has(0);
  @$pb.TagNumber(1)
  void clearGridId() => $_clearField(1);

  @$pb.TagNumber(2)
  ViewportState get viewport => $_getN(1);
  @$pb.TagNumber(2)
  set viewport(ViewportState value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasViewport() => $_has(1);
  @$pb.TagNumber(2)
  void clearViewport() => $_clearField(2);
  @$pb.TagNumber(2)
  ViewportState ensureViewport() => $_ensure(1);

  @$pb.TagNumber(3)
  PointerEvent get pointer => $_getN(2);
  @$pb.TagNumber(3)
  set pointer(PointerEvent value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasPointer() => $_has(2);
  @$pb.TagNumber(3)
  void clearPointer() => $_clearField(3);
  @$pb.TagNumber(3)
  PointerEvent ensurePointer() => $_ensure(2);

  @$pb.TagNumber(4)
  KeyEvent get key => $_getN(3);
  @$pb.TagNumber(4)
  set key(KeyEvent value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasKey() => $_has(3);
  @$pb.TagNumber(4)
  void clearKey() => $_clearField(4);
  @$pb.TagNumber(4)
  KeyEvent ensureKey() => $_ensure(3);

  @$pb.TagNumber(5)
  BufferReady get buffer => $_getN(4);
  @$pb.TagNumber(5)
  set buffer(BufferReady value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasBuffer() => $_has(4);
  @$pb.TagNumber(5)
  void clearBuffer() => $_clearField(5);
  @$pb.TagNumber(5)
  BufferReady ensureBuffer() => $_ensure(4);

  @$pb.TagNumber(6)
  ScrollEvent get scroll => $_getN(5);
  @$pb.TagNumber(6)
  set scroll(ScrollEvent value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasScroll() => $_has(5);
  @$pb.TagNumber(6)
  void clearScroll() => $_clearField(6);
  @$pb.TagNumber(6)
  ScrollEvent ensureScroll() => $_ensure(5);

  @$pb.TagNumber(7)
  EventDecision get eventDecision => $_getN(6);
  @$pb.TagNumber(7)
  set eventDecision(EventDecision value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasEventDecision() => $_has(6);
  @$pb.TagNumber(7)
  void clearEventDecision() => $_clearField(7);
  @$pb.TagNumber(7)
  EventDecision ensureEventDecision() => $_ensure(6);

  @$pb.TagNumber(8)
  ZoomEvent get zoom => $_getN(7);
  @$pb.TagNumber(8)
  set zoom(ZoomEvent value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasZoom() => $_has(7);
  @$pb.TagNumber(8)
  void clearZoom() => $_clearField(8);
  @$pb.TagNumber(8)
  ZoomEvent ensureZoom() => $_ensure(7);

  @$pb.TagNumber(9)
  GpuSurfaceReady get gpuSurface => $_getN(8);
  @$pb.TagNumber(9)
  set gpuSurface(GpuSurfaceReady value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasGpuSurface() => $_has(8);
  @$pb.TagNumber(9)
  void clearGpuSurface() => $_clearField(9);
  @$pb.TagNumber(9)
  GpuSurfaceReady ensureGpuSurface() => $_ensure(8);
}

class ViewportState extends $pb.GeneratedMessage {
  factory ViewportState({
    $core.double? scrollX,
    $core.double? scrollY,
    $core.int? width,
    $core.int? height,
  }) {
    final result = create();
    if (scrollX != null) result.scrollX = scrollX;
    if (scrollY != null) result.scrollY = scrollY;
    if (width != null) result.width = width;
    if (height != null) result.height = height;
    return result;
  }

  ViewportState._();

  factory ViewportState.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ViewportState.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ViewportState',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aD(1, _omitFieldNames ? '' : 'scrollX', fieldType: $pb.PbFieldType.OF)
    ..aD(2, _omitFieldNames ? '' : 'scrollY', fieldType: $pb.PbFieldType.OF)
    ..aI(3, _omitFieldNames ? '' : 'width')
    ..aI(4, _omitFieldNames ? '' : 'height')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ViewportState clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ViewportState copyWith(void Function(ViewportState) updates) =>
      super.copyWith((message) => updates(message as ViewportState))
          as ViewportState;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ViewportState create() => ViewportState._();
  @$core.override
  ViewportState createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ViewportState getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ViewportState>(create);
  static ViewportState? _defaultInstance;

  @$pb.TagNumber(1)
  $core.double get scrollX => $_getN(0);
  @$pb.TagNumber(1)
  set scrollX($core.double value) => $_setFloat(0, value);
  @$pb.TagNumber(1)
  $core.bool hasScrollX() => $_has(0);
  @$pb.TagNumber(1)
  void clearScrollX() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.double get scrollY => $_getN(1);
  @$pb.TagNumber(2)
  set scrollY($core.double value) => $_setFloat(1, value);
  @$pb.TagNumber(2)
  $core.bool hasScrollY() => $_has(1);
  @$pb.TagNumber(2)
  void clearScrollY() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get width => $_getIZ(2);
  @$pb.TagNumber(3)
  set width($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasWidth() => $_has(2);
  @$pb.TagNumber(3)
  void clearWidth() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get height => $_getIZ(3);
  @$pb.TagNumber(4)
  set height($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasHeight() => $_has(3);
  @$pb.TagNumber(4)
  void clearHeight() => $_clearField(4);
}

class PointerEvent extends $pb.GeneratedMessage {
  factory PointerEvent({
    PointerEvent_Type? type,
    $core.double? x,
    $core.double? y,
    $core.int? modifier,
    $core.int? button,
    $core.bool? dblClick,
  }) {
    final result = create();
    if (type != null) result.type = type;
    if (x != null) result.x = x;
    if (y != null) result.y = y;
    if (modifier != null) result.modifier = modifier;
    if (button != null) result.button = button;
    if (dblClick != null) result.dblClick = dblClick;
    return result;
  }

  PointerEvent._();

  factory PointerEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PointerEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PointerEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aE<PointerEvent_Type>(1, _omitFieldNames ? '' : 'type',
        enumValues: PointerEvent_Type.values)
    ..aD(2, _omitFieldNames ? '' : 'x', fieldType: $pb.PbFieldType.OF)
    ..aD(3, _omitFieldNames ? '' : 'y', fieldType: $pb.PbFieldType.OF)
    ..aI(4, _omitFieldNames ? '' : 'modifier')
    ..aI(5, _omitFieldNames ? '' : 'button')
    ..aOB(6, _omitFieldNames ? '' : 'dblClick')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PointerEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PointerEvent copyWith(void Function(PointerEvent) updates) =>
      super.copyWith((message) => updates(message as PointerEvent))
          as PointerEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PointerEvent create() => PointerEvent._();
  @$core.override
  PointerEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PointerEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PointerEvent>(create);
  static PointerEvent? _defaultInstance;

  @$pb.TagNumber(1)
  PointerEvent_Type get type => $_getN(0);
  @$pb.TagNumber(1)
  set type(PointerEvent_Type value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasType() => $_has(0);
  @$pb.TagNumber(1)
  void clearType() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.double get x => $_getN(1);
  @$pb.TagNumber(2)
  set x($core.double value) => $_setFloat(1, value);
  @$pb.TagNumber(2)
  $core.bool hasX() => $_has(1);
  @$pb.TagNumber(2)
  void clearX() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get y => $_getN(2);
  @$pb.TagNumber(3)
  set y($core.double value) => $_setFloat(2, value);
  @$pb.TagNumber(3)
  $core.bool hasY() => $_has(2);
  @$pb.TagNumber(3)
  void clearY() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get modifier => $_getIZ(3);
  @$pb.TagNumber(4)
  set modifier($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasModifier() => $_has(3);
  @$pb.TagNumber(4)
  void clearModifier() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get button => $_getIZ(4);
  @$pb.TagNumber(5)
  set button($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasButton() => $_has(4);
  @$pb.TagNumber(5)
  void clearButton() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get dblClick => $_getBF(5);
  @$pb.TagNumber(6)
  set dblClick($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasDblClick() => $_has(5);
  @$pb.TagNumber(6)
  void clearDblClick() => $_clearField(6);
}

class ScrollEvent extends $pb.GeneratedMessage {
  factory ScrollEvent({
    $core.double? deltaX,
    $core.double? deltaY,
  }) {
    final result = create();
    if (deltaX != null) result.deltaX = deltaX;
    if (deltaY != null) result.deltaY = deltaY;
    return result;
  }

  ScrollEvent._();

  factory ScrollEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ScrollEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ScrollEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aD(1, _omitFieldNames ? '' : 'deltaX', fieldType: $pb.PbFieldType.OF)
    ..aD(2, _omitFieldNames ? '' : 'deltaY', fieldType: $pb.PbFieldType.OF)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ScrollEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ScrollEvent copyWith(void Function(ScrollEvent) updates) =>
      super.copyWith((message) => updates(message as ScrollEvent))
          as ScrollEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ScrollEvent create() => ScrollEvent._();
  @$core.override
  ScrollEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ScrollEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ScrollEvent>(create);
  static ScrollEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.double get deltaX => $_getN(0);
  @$pb.TagNumber(1)
  set deltaX($core.double value) => $_setFloat(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDeltaX() => $_has(0);
  @$pb.TagNumber(1)
  void clearDeltaX() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.double get deltaY => $_getN(1);
  @$pb.TagNumber(2)
  set deltaY($core.double value) => $_setFloat(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDeltaY() => $_has(1);
  @$pb.TagNumber(2)
  void clearDeltaY() => $_clearField(2);
}

class ZoomEvent extends $pb.GeneratedMessage {
  factory ZoomEvent({
    ZoomEvent_Phase? phase,
    $core.double? scale,
    $core.double? focalXPx,
    $core.double? focalYPx,
  }) {
    final result = create();
    if (phase != null) result.phase = phase;
    if (scale != null) result.scale = scale;
    if (focalXPx != null) result.focalXPx = focalXPx;
    if (focalYPx != null) result.focalYPx = focalYPx;
    return result;
  }

  ZoomEvent._();

  factory ZoomEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ZoomEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ZoomEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aE<ZoomEvent_Phase>(1, _omitFieldNames ? '' : 'phase',
        enumValues: ZoomEvent_Phase.values)
    ..aD(2, _omitFieldNames ? '' : 'scale', fieldType: $pb.PbFieldType.OF)
    ..aD(3, _omitFieldNames ? '' : 'focalXPx', fieldType: $pb.PbFieldType.OF)
    ..aD(4, _omitFieldNames ? '' : 'focalYPx', fieldType: $pb.PbFieldType.OF)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ZoomEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ZoomEvent copyWith(void Function(ZoomEvent) updates) =>
      super.copyWith((message) => updates(message as ZoomEvent)) as ZoomEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ZoomEvent create() => ZoomEvent._();
  @$core.override
  ZoomEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ZoomEvent getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ZoomEvent>(create);
  static ZoomEvent? _defaultInstance;

  @$pb.TagNumber(1)
  ZoomEvent_Phase get phase => $_getN(0);
  @$pb.TagNumber(1)
  set phase(ZoomEvent_Phase value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasPhase() => $_has(0);
  @$pb.TagNumber(1)
  void clearPhase() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.double get scale => $_getN(1);
  @$pb.TagNumber(2)
  set scale($core.double value) => $_setFloat(1, value);
  @$pb.TagNumber(2)
  $core.bool hasScale() => $_has(1);
  @$pb.TagNumber(2)
  void clearScale() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get focalXPx => $_getN(2);
  @$pb.TagNumber(3)
  set focalXPx($core.double value) => $_setFloat(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFocalXPx() => $_has(2);
  @$pb.TagNumber(3)
  void clearFocalXPx() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.double get focalYPx => $_getN(3);
  @$pb.TagNumber(4)
  set focalYPx($core.double value) => $_setFloat(3, value);
  @$pb.TagNumber(4)
  $core.bool hasFocalYPx() => $_has(3);
  @$pb.TagNumber(4)
  void clearFocalYPx() => $_clearField(4);
}

class KeyEvent extends $pb.GeneratedMessage {
  factory KeyEvent({
    KeyEvent_Type? type,
    $core.int? keyCode,
    $core.int? modifier,
    $core.String? character,
  }) {
    final result = create();
    if (type != null) result.type = type;
    if (keyCode != null) result.keyCode = keyCode;
    if (modifier != null) result.modifier = modifier;
    if (character != null) result.character = character;
    return result;
  }

  KeyEvent._();

  factory KeyEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory KeyEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'KeyEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aE<KeyEvent_Type>(1, _omitFieldNames ? '' : 'type',
        enumValues: KeyEvent_Type.values)
    ..aI(2, _omitFieldNames ? '' : 'keyCode')
    ..aI(3, _omitFieldNames ? '' : 'modifier')
    ..aOS(4, _omitFieldNames ? '' : 'character')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KeyEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KeyEvent copyWith(void Function(KeyEvent) updates) =>
      super.copyWith((message) => updates(message as KeyEvent)) as KeyEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static KeyEvent create() => KeyEvent._();
  @$core.override
  KeyEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static KeyEvent getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<KeyEvent>(create);
  static KeyEvent? _defaultInstance;

  @$pb.TagNumber(1)
  KeyEvent_Type get type => $_getN(0);
  @$pb.TagNumber(1)
  set type(KeyEvent_Type value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasType() => $_has(0);
  @$pb.TagNumber(1)
  void clearType() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get keyCode => $_getIZ(1);
  @$pb.TagNumber(2)
  set keyCode($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasKeyCode() => $_has(1);
  @$pb.TagNumber(2)
  void clearKeyCode() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get modifier => $_getIZ(2);
  @$pb.TagNumber(3)
  set modifier($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasModifier() => $_has(2);
  @$pb.TagNumber(3)
  void clearModifier() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get character => $_getSZ(3);
  @$pb.TagNumber(4)
  set character($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCharacter() => $_has(3);
  @$pb.TagNumber(4)
  void clearCharacter() => $_clearField(4);
}

class BufferReady extends $pb.GeneratedMessage {
  factory BufferReady({
    $fixnum.Int64? handle,
    $core.int? stride,
    $core.int? width,
    $core.int? height,
  }) {
    final result = create();
    if (handle != null) result.handle = handle;
    if (stride != null) result.stride = stride;
    if (width != null) result.width = width;
    if (height != null) result.height = height;
    return result;
  }

  BufferReady._();

  factory BufferReady.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BufferReady.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BufferReady',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'handle')
    ..aI(2, _omitFieldNames ? '' : 'stride')
    ..aI(3, _omitFieldNames ? '' : 'width')
    ..aI(4, _omitFieldNames ? '' : 'height')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BufferReady clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BufferReady copyWith(void Function(BufferReady) updates) =>
      super.copyWith((message) => updates(message as BufferReady))
          as BufferReady;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BufferReady create() => BufferReady._();
  @$core.override
  BufferReady createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BufferReady getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BufferReady>(create);
  static BufferReady? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get handle => $_getI64(0);
  @$pb.TagNumber(1)
  set handle($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasHandle() => $_has(0);
  @$pb.TagNumber(1)
  void clearHandle() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get stride => $_getIZ(1);
  @$pb.TagNumber(2)
  set stride($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasStride() => $_has(1);
  @$pb.TagNumber(2)
  void clearStride() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get width => $_getIZ(2);
  @$pb.TagNumber(3)
  set width($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasWidth() => $_has(2);
  @$pb.TagNumber(3)
  void clearWidth() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get height => $_getIZ(3);
  @$pb.TagNumber(4)
  set height($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasHeight() => $_has(3);
  @$pb.TagNumber(4)
  void clearHeight() => $_clearField(4);
}

class GpuSurfaceReady extends $pb.GeneratedMessage {
  factory GpuSurfaceReady({
    $fixnum.Int64? surfaceHandle,
    $core.int? width,
    $core.int? height,
  }) {
    final result = create();
    if (surfaceHandle != null) result.surfaceHandle = surfaceHandle;
    if (width != null) result.width = width;
    if (height != null) result.height = height;
    return result;
  }

  GpuSurfaceReady._();

  factory GpuSurfaceReady.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GpuSurfaceReady.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GpuSurfaceReady',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'surfaceHandle')
    ..aI(2, _omitFieldNames ? '' : 'width')
    ..aI(3, _omitFieldNames ? '' : 'height')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GpuSurfaceReady clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GpuSurfaceReady copyWith(void Function(GpuSurfaceReady) updates) =>
      super.copyWith((message) => updates(message as GpuSurfaceReady))
          as GpuSurfaceReady;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GpuSurfaceReady create() => GpuSurfaceReady._();
  @$core.override
  GpuSurfaceReady createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GpuSurfaceReady getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GpuSurfaceReady>(create);
  static GpuSurfaceReady? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get surfaceHandle => $_getI64(0);
  @$pb.TagNumber(1)
  set surfaceHandle($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSurfaceHandle() => $_has(0);
  @$pb.TagNumber(1)
  void clearSurfaceHandle() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get width => $_getIZ(1);
  @$pb.TagNumber(2)
  set width($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasWidth() => $_has(1);
  @$pb.TagNumber(2)
  void clearWidth() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get height => $_getIZ(2);
  @$pb.TagNumber(3)
  set height($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasHeight() => $_has(2);
  @$pb.TagNumber(3)
  void clearHeight() => $_clearField(3);
}

class EventDecision extends $pb.GeneratedMessage {
  factory EventDecision({
    $fixnum.Int64? gridId,
    $fixnum.Int64? eventId,
    $core.bool? cancel,
  }) {
    final result = create();
    if (gridId != null) result.gridId = gridId;
    if (eventId != null) result.eventId = eventId;
    if (cancel != null) result.cancel = cancel;
    return result;
  }

  EventDecision._();

  factory EventDecision.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory EventDecision.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EventDecision',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'gridId')
    ..aInt64(2, _omitFieldNames ? '' : 'eventId')
    ..aOB(3, _omitFieldNames ? '' : 'cancel')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EventDecision clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EventDecision copyWith(void Function(EventDecision) updates) =>
      super.copyWith((message) => updates(message as EventDecision))
          as EventDecision;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EventDecision create() => EventDecision._();
  @$core.override
  EventDecision createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static EventDecision getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EventDecision>(create);
  static EventDecision? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get gridId => $_getI64(0);
  @$pb.TagNumber(1)
  set gridId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGridId() => $_has(0);
  @$pb.TagNumber(1)
  void clearGridId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get eventId => $_getI64(1);
  @$pb.TagNumber(2)
  set eventId($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEventId() => $_has(1);
  @$pb.TagNumber(2)
  void clearEventId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get cancel => $_getBF(2);
  @$pb.TagNumber(3)
  set cancel($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCancel() => $_has(2);
  @$pb.TagNumber(3)
  void clearCancel() => $_clearField(3);
}

enum RenderOutput_Event {
  frameDone,
  selection,
  cursor,
  editRequest,
  dropdownRequest,
  tooltipRequest,
  gpuFrameDone,
  notSet
}

class RenderOutput extends $pb.GeneratedMessage {
  factory RenderOutput({
    $core.bool? rendered,
    FrameDone? frameDone,
    SelectionUpdate? selection,
    CursorChange? cursor,
    EditRequest? editRequest,
    DropdownRequest? dropdownRequest,
    TooltipRequest? tooltipRequest,
    GpuFrameDone? gpuFrameDone,
  }) {
    final result = create();
    if (rendered != null) result.rendered = rendered;
    if (frameDone != null) result.frameDone = frameDone;
    if (selection != null) result.selection = selection;
    if (cursor != null) result.cursor = cursor;
    if (editRequest != null) result.editRequest = editRequest;
    if (dropdownRequest != null) result.dropdownRequest = dropdownRequest;
    if (tooltipRequest != null) result.tooltipRequest = tooltipRequest;
    if (gpuFrameDone != null) result.gpuFrameDone = gpuFrameDone;
    return result;
  }

  RenderOutput._();

  factory RenderOutput.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RenderOutput.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, RenderOutput_Event>
      _RenderOutput_EventByTag = {
    2: RenderOutput_Event.frameDone,
    3: RenderOutput_Event.selection,
    4: RenderOutput_Event.cursor,
    5: RenderOutput_Event.editRequest,
    6: RenderOutput_Event.dropdownRequest,
    7: RenderOutput_Event.tooltipRequest,
    8: RenderOutput_Event.gpuFrameDone,
    0: RenderOutput_Event.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RenderOutput',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..oo(0, [2, 3, 4, 5, 6, 7, 8])
    ..aOB(1, _omitFieldNames ? '' : 'rendered')
    ..aOM<FrameDone>(2, _omitFieldNames ? '' : 'frameDone',
        subBuilder: FrameDone.create)
    ..aOM<SelectionUpdate>(3, _omitFieldNames ? '' : 'selection',
        subBuilder: SelectionUpdate.create)
    ..aOM<CursorChange>(4, _omitFieldNames ? '' : 'cursor',
        subBuilder: CursorChange.create)
    ..aOM<EditRequest>(5, _omitFieldNames ? '' : 'editRequest',
        subBuilder: EditRequest.create)
    ..aOM<DropdownRequest>(6, _omitFieldNames ? '' : 'dropdownRequest',
        subBuilder: DropdownRequest.create)
    ..aOM<TooltipRequest>(7, _omitFieldNames ? '' : 'tooltipRequest',
        subBuilder: TooltipRequest.create)
    ..aOM<GpuFrameDone>(8, _omitFieldNames ? '' : 'gpuFrameDone',
        subBuilder: GpuFrameDone.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RenderOutput clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RenderOutput copyWith(void Function(RenderOutput) updates) =>
      super.copyWith((message) => updates(message as RenderOutput))
          as RenderOutput;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RenderOutput create() => RenderOutput._();
  @$core.override
  RenderOutput createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RenderOutput getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RenderOutput>(create);
  static RenderOutput? _defaultInstance;

  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  RenderOutput_Event whichEvent() => _RenderOutput_EventByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  void clearEvent() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $core.bool get rendered => $_getBF(0);
  @$pb.TagNumber(1)
  set rendered($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRendered() => $_has(0);
  @$pb.TagNumber(1)
  void clearRendered() => $_clearField(1);

  @$pb.TagNumber(2)
  FrameDone get frameDone => $_getN(1);
  @$pb.TagNumber(2)
  set frameDone(FrameDone value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasFrameDone() => $_has(1);
  @$pb.TagNumber(2)
  void clearFrameDone() => $_clearField(2);
  @$pb.TagNumber(2)
  FrameDone ensureFrameDone() => $_ensure(1);

  @$pb.TagNumber(3)
  SelectionUpdate get selection => $_getN(2);
  @$pb.TagNumber(3)
  set selection(SelectionUpdate value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasSelection() => $_has(2);
  @$pb.TagNumber(3)
  void clearSelection() => $_clearField(3);
  @$pb.TagNumber(3)
  SelectionUpdate ensureSelection() => $_ensure(2);

  @$pb.TagNumber(4)
  CursorChange get cursor => $_getN(3);
  @$pb.TagNumber(4)
  set cursor(CursorChange value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasCursor() => $_has(3);
  @$pb.TagNumber(4)
  void clearCursor() => $_clearField(4);
  @$pb.TagNumber(4)
  CursorChange ensureCursor() => $_ensure(3);

  @$pb.TagNumber(5)
  EditRequest get editRequest => $_getN(4);
  @$pb.TagNumber(5)
  set editRequest(EditRequest value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasEditRequest() => $_has(4);
  @$pb.TagNumber(5)
  void clearEditRequest() => $_clearField(5);
  @$pb.TagNumber(5)
  EditRequest ensureEditRequest() => $_ensure(4);

  @$pb.TagNumber(6)
  DropdownRequest get dropdownRequest => $_getN(5);
  @$pb.TagNumber(6)
  set dropdownRequest(DropdownRequest value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasDropdownRequest() => $_has(5);
  @$pb.TagNumber(6)
  void clearDropdownRequest() => $_clearField(6);
  @$pb.TagNumber(6)
  DropdownRequest ensureDropdownRequest() => $_ensure(5);

  @$pb.TagNumber(7)
  TooltipRequest get tooltipRequest => $_getN(6);
  @$pb.TagNumber(7)
  set tooltipRequest(TooltipRequest value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasTooltipRequest() => $_has(6);
  @$pb.TagNumber(7)
  void clearTooltipRequest() => $_clearField(7);
  @$pb.TagNumber(7)
  TooltipRequest ensureTooltipRequest() => $_ensure(6);

  @$pb.TagNumber(8)
  GpuFrameDone get gpuFrameDone => $_getN(7);
  @$pb.TagNumber(8)
  set gpuFrameDone(GpuFrameDone value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasGpuFrameDone() => $_has(7);
  @$pb.TagNumber(8)
  void clearGpuFrameDone() => $_clearField(8);
  @$pb.TagNumber(8)
  GpuFrameDone ensureGpuFrameDone() => $_ensure(7);
}

class FrameDone extends $pb.GeneratedMessage {
  factory FrameDone({
    $fixnum.Int64? handle,
    $core.int? dirtyX,
    $core.int? dirtyY,
    $core.int? dirtyW,
    $core.int? dirtyH,
    FrameMetrics? metrics,
  }) {
    final result = create();
    if (handle != null) result.handle = handle;
    if (dirtyX != null) result.dirtyX = dirtyX;
    if (dirtyY != null) result.dirtyY = dirtyY;
    if (dirtyW != null) result.dirtyW = dirtyW;
    if (dirtyH != null) result.dirtyH = dirtyH;
    if (metrics != null) result.metrics = metrics;
    return result;
  }

  FrameDone._();

  factory FrameDone.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory FrameDone.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FrameDone',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'handle')
    ..aI(2, _omitFieldNames ? '' : 'dirtyX')
    ..aI(3, _omitFieldNames ? '' : 'dirtyY')
    ..aI(4, _omitFieldNames ? '' : 'dirtyW')
    ..aI(5, _omitFieldNames ? '' : 'dirtyH')
    ..aOM<FrameMetrics>(6, _omitFieldNames ? '' : 'metrics',
        subBuilder: FrameMetrics.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FrameDone clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FrameDone copyWith(void Function(FrameDone) updates) =>
      super.copyWith((message) => updates(message as FrameDone)) as FrameDone;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FrameDone create() => FrameDone._();
  @$core.override
  FrameDone createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static FrameDone getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<FrameDone>(create);
  static FrameDone? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get handle => $_getI64(0);
  @$pb.TagNumber(1)
  set handle($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasHandle() => $_has(0);
  @$pb.TagNumber(1)
  void clearHandle() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get dirtyX => $_getIZ(1);
  @$pb.TagNumber(2)
  set dirtyX($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDirtyX() => $_has(1);
  @$pb.TagNumber(2)
  void clearDirtyX() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get dirtyY => $_getIZ(2);
  @$pb.TagNumber(3)
  set dirtyY($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDirtyY() => $_has(2);
  @$pb.TagNumber(3)
  void clearDirtyY() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get dirtyW => $_getIZ(3);
  @$pb.TagNumber(4)
  set dirtyW($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDirtyW() => $_has(3);
  @$pb.TagNumber(4)
  void clearDirtyW() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get dirtyH => $_getIZ(4);
  @$pb.TagNumber(5)
  set dirtyH($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDirtyH() => $_has(4);
  @$pb.TagNumber(5)
  void clearDirtyH() => $_clearField(5);

  @$pb.TagNumber(6)
  FrameMetrics get metrics => $_getN(5);
  @$pb.TagNumber(6)
  set metrics(FrameMetrics value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasMetrics() => $_has(5);
  @$pb.TagNumber(6)
  void clearMetrics() => $_clearField(6);
  @$pb.TagNumber(6)
  FrameMetrics ensureMetrics() => $_ensure(5);
}

class GpuFrameDone extends $pb.GeneratedMessage {
  factory GpuFrameDone({
    $core.int? dirtyX,
    $core.int? dirtyY,
    $core.int? dirtyW,
    $core.int? dirtyH,
    FrameMetrics? metrics,
  }) {
    final result = create();
    if (dirtyX != null) result.dirtyX = dirtyX;
    if (dirtyY != null) result.dirtyY = dirtyY;
    if (dirtyW != null) result.dirtyW = dirtyW;
    if (dirtyH != null) result.dirtyH = dirtyH;
    if (metrics != null) result.metrics = metrics;
    return result;
  }

  GpuFrameDone._();

  factory GpuFrameDone.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GpuFrameDone.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GpuFrameDone',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'dirtyX')
    ..aI(2, _omitFieldNames ? '' : 'dirtyY')
    ..aI(3, _omitFieldNames ? '' : 'dirtyW')
    ..aI(4, _omitFieldNames ? '' : 'dirtyH')
    ..aOM<FrameMetrics>(5, _omitFieldNames ? '' : 'metrics',
        subBuilder: FrameMetrics.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GpuFrameDone clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GpuFrameDone copyWith(void Function(GpuFrameDone) updates) =>
      super.copyWith((message) => updates(message as GpuFrameDone))
          as GpuFrameDone;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GpuFrameDone create() => GpuFrameDone._();
  @$core.override
  GpuFrameDone createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GpuFrameDone getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GpuFrameDone>(create);
  static GpuFrameDone? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get dirtyX => $_getIZ(0);
  @$pb.TagNumber(1)
  set dirtyX($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDirtyX() => $_has(0);
  @$pb.TagNumber(1)
  void clearDirtyX() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get dirtyY => $_getIZ(1);
  @$pb.TagNumber(2)
  set dirtyY($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDirtyY() => $_has(1);
  @$pb.TagNumber(2)
  void clearDirtyY() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get dirtyW => $_getIZ(2);
  @$pb.TagNumber(3)
  set dirtyW($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDirtyW() => $_has(2);
  @$pb.TagNumber(3)
  void clearDirtyW() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get dirtyH => $_getIZ(3);
  @$pb.TagNumber(4)
  set dirtyH($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDirtyH() => $_has(3);
  @$pb.TagNumber(4)
  void clearDirtyH() => $_clearField(4);

  @$pb.TagNumber(5)
  FrameMetrics get metrics => $_getN(4);
  @$pb.TagNumber(5)
  set metrics(FrameMetrics value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasMetrics() => $_has(4);
  @$pb.TagNumber(5)
  void clearMetrics() => $_clearField(5);
  @$pb.TagNumber(5)
  FrameMetrics ensureMetrics() => $_ensure(4);
}

class FrameMetrics extends $pb.GeneratedMessage {
  factory FrameMetrics({
    $core.double? frameTimeMs,
    $core.double? fps,
    $core.Iterable<$core.double>? layerTimesUs,
    $core.Iterable<$core.int>? zoneCellCounts,
    $core.int? instanceCount,
  }) {
    final result = create();
    if (frameTimeMs != null) result.frameTimeMs = frameTimeMs;
    if (fps != null) result.fps = fps;
    if (layerTimesUs != null) result.layerTimesUs.addAll(layerTimesUs);
    if (zoneCellCounts != null) result.zoneCellCounts.addAll(zoneCellCounts);
    if (instanceCount != null) result.instanceCount = instanceCount;
    return result;
  }

  FrameMetrics._();

  factory FrameMetrics.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory FrameMetrics.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FrameMetrics',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aD(1, _omitFieldNames ? '' : 'frameTimeMs', fieldType: $pb.PbFieldType.OF)
    ..aD(2, _omitFieldNames ? '' : 'fps', fieldType: $pb.PbFieldType.OF)
    ..p<$core.double>(
        3, _omitFieldNames ? '' : 'layerTimesUs', $pb.PbFieldType.KF)
    ..p<$core.int>(
        4, _omitFieldNames ? '' : 'zoneCellCounts', $pb.PbFieldType.KU3)
    ..aI(5, _omitFieldNames ? '' : 'instanceCount')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FrameMetrics clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FrameMetrics copyWith(void Function(FrameMetrics) updates) =>
      super.copyWith((message) => updates(message as FrameMetrics))
          as FrameMetrics;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FrameMetrics create() => FrameMetrics._();
  @$core.override
  FrameMetrics createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static FrameMetrics getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FrameMetrics>(create);
  static FrameMetrics? _defaultInstance;

  @$pb.TagNumber(1)
  $core.double get frameTimeMs => $_getN(0);
  @$pb.TagNumber(1)
  set frameTimeMs($core.double value) => $_setFloat(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFrameTimeMs() => $_has(0);
  @$pb.TagNumber(1)
  void clearFrameTimeMs() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.double get fps => $_getN(1);
  @$pb.TagNumber(2)
  set fps($core.double value) => $_setFloat(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFps() => $_has(1);
  @$pb.TagNumber(2)
  void clearFps() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbList<$core.double> get layerTimesUs => $_getList(2);

  @$pb.TagNumber(4)
  $pb.PbList<$core.int> get zoneCellCounts => $_getList(3);

  @$pb.TagNumber(5)
  $core.int get instanceCount => $_getIZ(4);
  @$pb.TagNumber(5)
  set instanceCount($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasInstanceCount() => $_has(4);
  @$pb.TagNumber(5)
  void clearInstanceCount() => $_clearField(5);
}

class SelectionUpdate extends $pb.GeneratedMessage {
  factory SelectionUpdate({
    $core.int? activeRow,
    $core.int? activeCol,
    $core.Iterable<CellRange>? ranges,
  }) {
    final result = create();
    if (activeRow != null) result.activeRow = activeRow;
    if (activeCol != null) result.activeCol = activeCol;
    if (ranges != null) result.ranges.addAll(ranges);
    return result;
  }

  SelectionUpdate._();

  factory SelectionUpdate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SelectionUpdate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SelectionUpdate',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'activeRow')
    ..aI(2, _omitFieldNames ? '' : 'activeCol')
    ..pPM<CellRange>(3, _omitFieldNames ? '' : 'ranges',
        subBuilder: CellRange.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SelectionUpdate clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SelectionUpdate copyWith(void Function(SelectionUpdate) updates) =>
      super.copyWith((message) => updates(message as SelectionUpdate))
          as SelectionUpdate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SelectionUpdate create() => SelectionUpdate._();
  @$core.override
  SelectionUpdate createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SelectionUpdate getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SelectionUpdate>(create);
  static SelectionUpdate? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get activeRow => $_getIZ(0);
  @$pb.TagNumber(1)
  set activeRow($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasActiveRow() => $_has(0);
  @$pb.TagNumber(1)
  void clearActiveRow() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get activeCol => $_getIZ(1);
  @$pb.TagNumber(2)
  set activeCol($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasActiveCol() => $_has(1);
  @$pb.TagNumber(2)
  void clearActiveCol() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbList<CellRange> get ranges => $_getList(2);
}

class CursorChange extends $pb.GeneratedMessage {
  factory CursorChange({
    CursorChange_CursorType? cursor,
  }) {
    final result = create();
    if (cursor != null) result.cursor = cursor;
    return result;
  }

  CursorChange._();

  factory CursorChange.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CursorChange.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CursorChange',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aE<CursorChange_CursorType>(1, _omitFieldNames ? '' : 'cursor',
        enumValues: CursorChange_CursorType.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CursorChange clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CursorChange copyWith(void Function(CursorChange) updates) =>
      super.copyWith((message) => updates(message as CursorChange))
          as CursorChange;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CursorChange create() => CursorChange._();
  @$core.override
  CursorChange createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CursorChange getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CursorChange>(create);
  static CursorChange? _defaultInstance;

  @$pb.TagNumber(1)
  CursorChange_CursorType get cursor => $_getN(0);
  @$pb.TagNumber(1)
  set cursor(CursorChange_CursorType value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasCursor() => $_has(0);
  @$pb.TagNumber(1)
  void clearCursor() => $_clearField(1);
}

class EditRequest extends $pb.GeneratedMessage {
  factory EditRequest({
    $core.int? row,
    $core.int? col,
    $core.double? x,
    $core.double? y,
    $core.double? width,
    $core.double? height,
    $core.String? currentValue,
    $core.String? editMask,
    $core.int? maxLength,
    $core.int? selStart,
    $core.int? selLength,
    EditUiMode? uiMode,
  }) {
    final result = create();
    if (row != null) result.row = row;
    if (col != null) result.col = col;
    if (x != null) result.x = x;
    if (y != null) result.y = y;
    if (width != null) result.width = width;
    if (height != null) result.height = height;
    if (currentValue != null) result.currentValue = currentValue;
    if (editMask != null) result.editMask = editMask;
    if (maxLength != null) result.maxLength = maxLength;
    if (selStart != null) result.selStart = selStart;
    if (selLength != null) result.selLength = selLength;
    if (uiMode != null) result.uiMode = uiMode;
    return result;
  }

  EditRequest._();

  factory EditRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory EditRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EditRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'row')
    ..aI(2, _omitFieldNames ? '' : 'col')
    ..aD(3, _omitFieldNames ? '' : 'x', fieldType: $pb.PbFieldType.OF)
    ..aD(4, _omitFieldNames ? '' : 'y', fieldType: $pb.PbFieldType.OF)
    ..aD(5, _omitFieldNames ? '' : 'width', fieldType: $pb.PbFieldType.OF)
    ..aD(6, _omitFieldNames ? '' : 'height', fieldType: $pb.PbFieldType.OF)
    ..aOS(7, _omitFieldNames ? '' : 'currentValue')
    ..aOS(8, _omitFieldNames ? '' : 'editMask')
    ..aI(9, _omitFieldNames ? '' : 'maxLength')
    ..aI(10, _omitFieldNames ? '' : 'selStart')
    ..aI(11, _omitFieldNames ? '' : 'selLength')
    ..aE<EditUiMode>(12, _omitFieldNames ? '' : 'uiMode',
        enumValues: EditUiMode.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EditRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EditRequest copyWith(void Function(EditRequest) updates) =>
      super.copyWith((message) => updates(message as EditRequest))
          as EditRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EditRequest create() => EditRequest._();
  @$core.override
  EditRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static EditRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EditRequest>(create);
  static EditRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get row => $_getIZ(0);
  @$pb.TagNumber(1)
  set row($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRow() => $_has(0);
  @$pb.TagNumber(1)
  void clearRow() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get col => $_getIZ(1);
  @$pb.TagNumber(2)
  set col($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCol() => $_has(1);
  @$pb.TagNumber(2)
  void clearCol() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get x => $_getN(2);
  @$pb.TagNumber(3)
  set x($core.double value) => $_setFloat(2, value);
  @$pb.TagNumber(3)
  $core.bool hasX() => $_has(2);
  @$pb.TagNumber(3)
  void clearX() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.double get y => $_getN(3);
  @$pb.TagNumber(4)
  set y($core.double value) => $_setFloat(3, value);
  @$pb.TagNumber(4)
  $core.bool hasY() => $_has(3);
  @$pb.TagNumber(4)
  void clearY() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.double get width => $_getN(4);
  @$pb.TagNumber(5)
  set width($core.double value) => $_setFloat(4, value);
  @$pb.TagNumber(5)
  $core.bool hasWidth() => $_has(4);
  @$pb.TagNumber(5)
  void clearWidth() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.double get height => $_getN(5);
  @$pb.TagNumber(6)
  set height($core.double value) => $_setFloat(5, value);
  @$pb.TagNumber(6)
  $core.bool hasHeight() => $_has(5);
  @$pb.TagNumber(6)
  void clearHeight() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get currentValue => $_getSZ(6);
  @$pb.TagNumber(7)
  set currentValue($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasCurrentValue() => $_has(6);
  @$pb.TagNumber(7)
  void clearCurrentValue() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get editMask => $_getSZ(7);
  @$pb.TagNumber(8)
  set editMask($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasEditMask() => $_has(7);
  @$pb.TagNumber(8)
  void clearEditMask() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get maxLength => $_getIZ(8);
  @$pb.TagNumber(9)
  set maxLength($core.int value) => $_setSignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasMaxLength() => $_has(8);
  @$pb.TagNumber(9)
  void clearMaxLength() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.int get selStart => $_getIZ(9);
  @$pb.TagNumber(10)
  set selStart($core.int value) => $_setSignedInt32(9, value);
  @$pb.TagNumber(10)
  $core.bool hasSelStart() => $_has(9);
  @$pb.TagNumber(10)
  void clearSelStart() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.int get selLength => $_getIZ(10);
  @$pb.TagNumber(11)
  set selLength($core.int value) => $_setSignedInt32(10, value);
  @$pb.TagNumber(11)
  $core.bool hasSelLength() => $_has(10);
  @$pb.TagNumber(11)
  void clearSelLength() => $_clearField(11);

  @$pb.TagNumber(12)
  EditUiMode get uiMode => $_getN(11);
  @$pb.TagNumber(12)
  set uiMode(EditUiMode value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasUiMode() => $_has(11);
  @$pb.TagNumber(12)
  void clearUiMode() => $_clearField(12);
}

class DropdownRequest extends $pb.GeneratedMessage {
  factory DropdownRequest({
    $core.int? row,
    $core.int? col,
    $core.double? x,
    $core.double? y,
    $core.double? width,
    $core.double? height,
    $core.Iterable<$core.String>? items,
    $core.int? selected,
    $core.bool? editable,
  }) {
    final result = create();
    if (row != null) result.row = row;
    if (col != null) result.col = col;
    if (x != null) result.x = x;
    if (y != null) result.y = y;
    if (width != null) result.width = width;
    if (height != null) result.height = height;
    if (items != null) result.items.addAll(items);
    if (selected != null) result.selected = selected;
    if (editable != null) result.editable = editable;
    return result;
  }

  DropdownRequest._();

  factory DropdownRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DropdownRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DropdownRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'row')
    ..aI(2, _omitFieldNames ? '' : 'col')
    ..aD(3, _omitFieldNames ? '' : 'x', fieldType: $pb.PbFieldType.OF)
    ..aD(4, _omitFieldNames ? '' : 'y', fieldType: $pb.PbFieldType.OF)
    ..aD(5, _omitFieldNames ? '' : 'width', fieldType: $pb.PbFieldType.OF)
    ..aD(6, _omitFieldNames ? '' : 'height', fieldType: $pb.PbFieldType.OF)
    ..pPS(7, _omitFieldNames ? '' : 'items')
    ..aI(8, _omitFieldNames ? '' : 'selected')
    ..aOB(9, _omitFieldNames ? '' : 'editable')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DropdownRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DropdownRequest copyWith(void Function(DropdownRequest) updates) =>
      super.copyWith((message) => updates(message as DropdownRequest))
          as DropdownRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DropdownRequest create() => DropdownRequest._();
  @$core.override
  DropdownRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DropdownRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DropdownRequest>(create);
  static DropdownRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get row => $_getIZ(0);
  @$pb.TagNumber(1)
  set row($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRow() => $_has(0);
  @$pb.TagNumber(1)
  void clearRow() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get col => $_getIZ(1);
  @$pb.TagNumber(2)
  set col($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCol() => $_has(1);
  @$pb.TagNumber(2)
  void clearCol() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get x => $_getN(2);
  @$pb.TagNumber(3)
  set x($core.double value) => $_setFloat(2, value);
  @$pb.TagNumber(3)
  $core.bool hasX() => $_has(2);
  @$pb.TagNumber(3)
  void clearX() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.double get y => $_getN(3);
  @$pb.TagNumber(4)
  set y($core.double value) => $_setFloat(3, value);
  @$pb.TagNumber(4)
  $core.bool hasY() => $_has(3);
  @$pb.TagNumber(4)
  void clearY() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.double get width => $_getN(4);
  @$pb.TagNumber(5)
  set width($core.double value) => $_setFloat(4, value);
  @$pb.TagNumber(5)
  $core.bool hasWidth() => $_has(4);
  @$pb.TagNumber(5)
  void clearWidth() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.double get height => $_getN(5);
  @$pb.TagNumber(6)
  set height($core.double value) => $_setFloat(5, value);
  @$pb.TagNumber(6)
  $core.bool hasHeight() => $_has(5);
  @$pb.TagNumber(6)
  void clearHeight() => $_clearField(6);

  @$pb.TagNumber(7)
  $pb.PbList<$core.String> get items => $_getList(6);

  @$pb.TagNumber(8)
  $core.int get selected => $_getIZ(7);
  @$pb.TagNumber(8)
  set selected($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasSelected() => $_has(7);
  @$pb.TagNumber(8)
  void clearSelected() => $_clearField(8);

  /// True if free-form text entry is allowed.
  @$pb.TagNumber(9)
  $core.bool get editable => $_getBF(8);
  @$pb.TagNumber(9)
  set editable($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasEditable() => $_has(8);
  @$pb.TagNumber(9)
  void clearEditable() => $_clearField(9);
}

class TooltipRequest extends $pb.GeneratedMessage {
  factory TooltipRequest({
    $core.double? x,
    $core.double? y,
    $core.String? text,
  }) {
    final result = create();
    if (x != null) result.x = x;
    if (y != null) result.y = y;
    if (text != null) result.text = text;
    return result;
  }

  TooltipRequest._();

  factory TooltipRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TooltipRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TooltipRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aD(1, _omitFieldNames ? '' : 'x', fieldType: $pb.PbFieldType.OF)
    ..aD(2, _omitFieldNames ? '' : 'y', fieldType: $pb.PbFieldType.OF)
    ..aOS(3, _omitFieldNames ? '' : 'text')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TooltipRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TooltipRequest copyWith(void Function(TooltipRequest) updates) =>
      super.copyWith((message) => updates(message as TooltipRequest))
          as TooltipRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TooltipRequest create() => TooltipRequest._();
  @$core.override
  TooltipRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TooltipRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TooltipRequest>(create);
  static TooltipRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.double get x => $_getN(0);
  @$pb.TagNumber(1)
  set x($core.double value) => $_setFloat(0, value);
  @$pb.TagNumber(1)
  $core.bool hasX() => $_has(0);
  @$pb.TagNumber(1)
  void clearX() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.double get y => $_getN(1);
  @$pb.TagNumber(2)
  set y($core.double value) => $_setFloat(1, value);
  @$pb.TagNumber(2)
  $core.bool hasY() => $_has(1);
  @$pb.TagNumber(2)
  void clearY() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get text => $_getSZ(2);
  @$pb.TagNumber(3)
  set text($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasText() => $_has(2);
  @$pb.TagNumber(3)
  void clearText() => $_clearField(3);
}

enum GridEvent_Event {
  cellFocusChanging,
  cellFocusChanged,
  selectionChanging,
  selectionChanged,
  enterCell,
  leaveCell,
  beforeEdit,
  startEdit,
  afterEdit,
  cellEditValidate,
  cellEditChange,
  keyDownEdit,
  keyPressEdit,
  keyUpEdit,
  cellEditConfigureStyle,
  cellEditConfigureWindow,
  dropdownClosed,
  dropdownOpened,
  cellChanged,
  rowStatusChange,
  beforeSort,
  afterSort,
  compare,
  beforeNodeToggle,
  afterNodeToggle,
  beforeScroll,
  afterScroll,
  scrollTooltip,
  beforeUserResize,
  afterUserResize,
  afterUserFreeze,
  beforeMoveColumn,
  afterMoveColumn,
  beforeMoveRow,
  afterMoveRow,
  beforeMouseDown,
  mouseDown,
  mouseUp,
  mouseMove,
  click,
  dblClick,
  keyDown,
  keyPress,
  keyUp,
  customRenderCell,
  dragStart,
  dragOver,
  dragDrop,
  dragComplete,
  typeAheadStarted,
  typeAheadEnded,
  dataRefreshing,
  dataRefreshed,
  filterData,
  error,
  beforePageBreak,
  startPage,
  getHeaderRow,
  pullToRefreshTriggered,
  pullToRefreshCanceled,
  notSet
}

class GridEvent extends $pb.GeneratedMessage {
  factory GridEvent({
    $fixnum.Int64? gridId,
    CellFocusChangingEvent? cellFocusChanging,
    CellFocusChangedEvent? cellFocusChanged,
    SelectionChangingEvent? selectionChanging,
    SelectionChangedEvent? selectionChanged,
    EnterCellEvent? enterCell,
    LeaveCellEvent? leaveCell,
    BeforeEditEvent? beforeEdit,
    StartEditEvent? startEdit,
    AfterEditEvent? afterEdit,
    CellEditValidateEvent? cellEditValidate,
    CellEditChangeEvent? cellEditChange,
    KeyDownEditEvent? keyDownEdit,
    KeyPressEditEvent? keyPressEdit,
    KeyUpEditEvent? keyUpEdit,
    CellEditConfigureStyleEvent? cellEditConfigureStyle,
    CellEditConfigureWindowEvent? cellEditConfigureWindow,
    DropdownClosedEvent? dropdownClosed,
    DropdownOpenedEvent? dropdownOpened,
    CellChangedEvent? cellChanged,
    RowStatusChangeEvent? rowStatusChange,
    BeforeSortEvent? beforeSort,
    AfterSortEvent? afterSort,
    CompareEvent? compare,
    BeforeNodeToggleEvent? beforeNodeToggle,
    AfterNodeToggleEvent? afterNodeToggle,
    BeforeScrollEvent? beforeScroll,
    AfterScrollEvent? afterScroll,
    ScrollTooltipEvent? scrollTooltip,
    BeforeUserResizeEvent? beforeUserResize,
    AfterUserResizeEvent? afterUserResize,
    AfterUserFreezeEvent? afterUserFreeze,
    BeforeMoveColumnEvent? beforeMoveColumn,
    AfterMoveColumnEvent? afterMoveColumn,
    BeforeMoveRowEvent? beforeMoveRow,
    AfterMoveRowEvent? afterMoveRow,
    BeforeMouseDownEvent? beforeMouseDown,
    MouseDownEvent? mouseDown,
    MouseUpEvent? mouseUp,
    MouseMoveEvent? mouseMove,
    ClickEvent? click,
    DblClickEvent? dblClick,
    KeyDownEvent? keyDown,
    KeyPressEvent? keyPress,
    KeyUpEvent? keyUp,
    CustomRenderCellEvent? customRenderCell,
    DragStartEvent? dragStart,
    DragOverEvent? dragOver,
    DragDropEvent? dragDrop,
    DragCompleteEvent? dragComplete,
    TypeAheadStartedEvent? typeAheadStarted,
    TypeAheadEndedEvent? typeAheadEnded,
    DataRefreshingEvent? dataRefreshing,
    DataRefreshedEvent? dataRefreshed,
    FilterDataEvent? filterData,
    ErrorEvent? error,
    BeforePageBreakEvent? beforePageBreak,
    StartPageEvent? startPage,
    GetHeaderRowEvent? getHeaderRow,
    PullToRefreshTriggeredEvent? pullToRefreshTriggered,
    PullToRefreshCanceledEvent? pullToRefreshCanceled,
    $fixnum.Int64? eventId,
  }) {
    final result = create();
    if (gridId != null) result.gridId = gridId;
    if (cellFocusChanging != null) result.cellFocusChanging = cellFocusChanging;
    if (cellFocusChanged != null) result.cellFocusChanged = cellFocusChanged;
    if (selectionChanging != null) result.selectionChanging = selectionChanging;
    if (selectionChanged != null) result.selectionChanged = selectionChanged;
    if (enterCell != null) result.enterCell = enterCell;
    if (leaveCell != null) result.leaveCell = leaveCell;
    if (beforeEdit != null) result.beforeEdit = beforeEdit;
    if (startEdit != null) result.startEdit = startEdit;
    if (afterEdit != null) result.afterEdit = afterEdit;
    if (cellEditValidate != null) result.cellEditValidate = cellEditValidate;
    if (cellEditChange != null) result.cellEditChange = cellEditChange;
    if (keyDownEdit != null) result.keyDownEdit = keyDownEdit;
    if (keyPressEdit != null) result.keyPressEdit = keyPressEdit;
    if (keyUpEdit != null) result.keyUpEdit = keyUpEdit;
    if (cellEditConfigureStyle != null)
      result.cellEditConfigureStyle = cellEditConfigureStyle;
    if (cellEditConfigureWindow != null)
      result.cellEditConfigureWindow = cellEditConfigureWindow;
    if (dropdownClosed != null) result.dropdownClosed = dropdownClosed;
    if (dropdownOpened != null) result.dropdownOpened = dropdownOpened;
    if (cellChanged != null) result.cellChanged = cellChanged;
    if (rowStatusChange != null) result.rowStatusChange = rowStatusChange;
    if (beforeSort != null) result.beforeSort = beforeSort;
    if (afterSort != null) result.afterSort = afterSort;
    if (compare != null) result.compare = compare;
    if (beforeNodeToggle != null) result.beforeNodeToggle = beforeNodeToggle;
    if (afterNodeToggle != null) result.afterNodeToggle = afterNodeToggle;
    if (beforeScroll != null) result.beforeScroll = beforeScroll;
    if (afterScroll != null) result.afterScroll = afterScroll;
    if (scrollTooltip != null) result.scrollTooltip = scrollTooltip;
    if (beforeUserResize != null) result.beforeUserResize = beforeUserResize;
    if (afterUserResize != null) result.afterUserResize = afterUserResize;
    if (afterUserFreeze != null) result.afterUserFreeze = afterUserFreeze;
    if (beforeMoveColumn != null) result.beforeMoveColumn = beforeMoveColumn;
    if (afterMoveColumn != null) result.afterMoveColumn = afterMoveColumn;
    if (beforeMoveRow != null) result.beforeMoveRow = beforeMoveRow;
    if (afterMoveRow != null) result.afterMoveRow = afterMoveRow;
    if (beforeMouseDown != null) result.beforeMouseDown = beforeMouseDown;
    if (mouseDown != null) result.mouseDown = mouseDown;
    if (mouseUp != null) result.mouseUp = mouseUp;
    if (mouseMove != null) result.mouseMove = mouseMove;
    if (click != null) result.click = click;
    if (dblClick != null) result.dblClick = dblClick;
    if (keyDown != null) result.keyDown = keyDown;
    if (keyPress != null) result.keyPress = keyPress;
    if (keyUp != null) result.keyUp = keyUp;
    if (customRenderCell != null) result.customRenderCell = customRenderCell;
    if (dragStart != null) result.dragStart = dragStart;
    if (dragOver != null) result.dragOver = dragOver;
    if (dragDrop != null) result.dragDrop = dragDrop;
    if (dragComplete != null) result.dragComplete = dragComplete;
    if (typeAheadStarted != null) result.typeAheadStarted = typeAheadStarted;
    if (typeAheadEnded != null) result.typeAheadEnded = typeAheadEnded;
    if (dataRefreshing != null) result.dataRefreshing = dataRefreshing;
    if (dataRefreshed != null) result.dataRefreshed = dataRefreshed;
    if (filterData != null) result.filterData = filterData;
    if (error != null) result.error = error;
    if (beforePageBreak != null) result.beforePageBreak = beforePageBreak;
    if (startPage != null) result.startPage = startPage;
    if (getHeaderRow != null) result.getHeaderRow = getHeaderRow;
    if (pullToRefreshTriggered != null)
      result.pullToRefreshTriggered = pullToRefreshTriggered;
    if (pullToRefreshCanceled != null)
      result.pullToRefreshCanceled = pullToRefreshCanceled;
    if (eventId != null) result.eventId = eventId;
    return result;
  }

  GridEvent._();

  factory GridEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GridEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, GridEvent_Event> _GridEvent_EventByTag = {
    2: GridEvent_Event.cellFocusChanging,
    3: GridEvent_Event.cellFocusChanged,
    4: GridEvent_Event.selectionChanging,
    5: GridEvent_Event.selectionChanged,
    6: GridEvent_Event.enterCell,
    7: GridEvent_Event.leaveCell,
    8: GridEvent_Event.beforeEdit,
    9: GridEvent_Event.startEdit,
    10: GridEvent_Event.afterEdit,
    11: GridEvent_Event.cellEditValidate,
    12: GridEvent_Event.cellEditChange,
    14: GridEvent_Event.keyDownEdit,
    15: GridEvent_Event.keyPressEdit,
    16: GridEvent_Event.keyUpEdit,
    17: GridEvent_Event.cellEditConfigureStyle,
    18: GridEvent_Event.cellEditConfigureWindow,
    19: GridEvent_Event.dropdownClosed,
    20: GridEvent_Event.dropdownOpened,
    21: GridEvent_Event.cellChanged,
    22: GridEvent_Event.rowStatusChange,
    23: GridEvent_Event.beforeSort,
    24: GridEvent_Event.afterSort,
    25: GridEvent_Event.compare,
    26: GridEvent_Event.beforeNodeToggle,
    27: GridEvent_Event.afterNodeToggle,
    28: GridEvent_Event.beforeScroll,
    29: GridEvent_Event.afterScroll,
    30: GridEvent_Event.scrollTooltip,
    31: GridEvent_Event.beforeUserResize,
    32: GridEvent_Event.afterUserResize,
    33: GridEvent_Event.afterUserFreeze,
    34: GridEvent_Event.beforeMoveColumn,
    35: GridEvent_Event.afterMoveColumn,
    36: GridEvent_Event.beforeMoveRow,
    37: GridEvent_Event.afterMoveRow,
    38: GridEvent_Event.beforeMouseDown,
    39: GridEvent_Event.mouseDown,
    40: GridEvent_Event.mouseUp,
    41: GridEvent_Event.mouseMove,
    42: GridEvent_Event.click,
    43: GridEvent_Event.dblClick,
    44: GridEvent_Event.keyDown,
    45: GridEvent_Event.keyPress,
    46: GridEvent_Event.keyUp,
    47: GridEvent_Event.customRenderCell,
    48: GridEvent_Event.dragStart,
    49: GridEvent_Event.dragOver,
    50: GridEvent_Event.dragDrop,
    51: GridEvent_Event.dragComplete,
    52: GridEvent_Event.typeAheadStarted,
    53: GridEvent_Event.typeAheadEnded,
    54: GridEvent_Event.dataRefreshing,
    55: GridEvent_Event.dataRefreshed,
    56: GridEvent_Event.filterData,
    57: GridEvent_Event.error,
    58: GridEvent_Event.beforePageBreak,
    59: GridEvent_Event.startPage,
    60: GridEvent_Event.getHeaderRow,
    61: GridEvent_Event.pullToRefreshTriggered,
    62: GridEvent_Event.pullToRefreshCanceled,
    0: GridEvent_Event.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GridEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..oo(0, [
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      11,
      12,
      14,
      15,
      16,
      17,
      18,
      19,
      20,
      21,
      22,
      23,
      24,
      25,
      26,
      27,
      28,
      29,
      30,
      31,
      32,
      33,
      34,
      35,
      36,
      37,
      38,
      39,
      40,
      41,
      42,
      43,
      44,
      45,
      46,
      47,
      48,
      49,
      50,
      51,
      52,
      53,
      54,
      55,
      56,
      57,
      58,
      59,
      60,
      61,
      62
    ])
    ..aInt64(1, _omitFieldNames ? '' : 'gridId')
    ..aOM<CellFocusChangingEvent>(2, _omitFieldNames ? '' : 'cellFocusChanging',
        subBuilder: CellFocusChangingEvent.create)
    ..aOM<CellFocusChangedEvent>(3, _omitFieldNames ? '' : 'cellFocusChanged',
        subBuilder: CellFocusChangedEvent.create)
    ..aOM<SelectionChangingEvent>(4, _omitFieldNames ? '' : 'selectionChanging',
        subBuilder: SelectionChangingEvent.create)
    ..aOM<SelectionChangedEvent>(5, _omitFieldNames ? '' : 'selectionChanged',
        subBuilder: SelectionChangedEvent.create)
    ..aOM<EnterCellEvent>(6, _omitFieldNames ? '' : 'enterCell',
        subBuilder: EnterCellEvent.create)
    ..aOM<LeaveCellEvent>(7, _omitFieldNames ? '' : 'leaveCell',
        subBuilder: LeaveCellEvent.create)
    ..aOM<BeforeEditEvent>(8, _omitFieldNames ? '' : 'beforeEdit',
        subBuilder: BeforeEditEvent.create)
    ..aOM<StartEditEvent>(9, _omitFieldNames ? '' : 'startEdit',
        subBuilder: StartEditEvent.create)
    ..aOM<AfterEditEvent>(10, _omitFieldNames ? '' : 'afterEdit',
        subBuilder: AfterEditEvent.create)
    ..aOM<CellEditValidateEvent>(11, _omitFieldNames ? '' : 'cellEditValidate',
        subBuilder: CellEditValidateEvent.create)
    ..aOM<CellEditChangeEvent>(12, _omitFieldNames ? '' : 'cellEditChange',
        subBuilder: CellEditChangeEvent.create)
    ..aOM<KeyDownEditEvent>(14, _omitFieldNames ? '' : 'keyDownEdit',
        subBuilder: KeyDownEditEvent.create)
    ..aOM<KeyPressEditEvent>(15, _omitFieldNames ? '' : 'keyPressEdit',
        subBuilder: KeyPressEditEvent.create)
    ..aOM<KeyUpEditEvent>(16, _omitFieldNames ? '' : 'keyUpEdit',
        subBuilder: KeyUpEditEvent.create)
    ..aOM<CellEditConfigureStyleEvent>(
        17, _omitFieldNames ? '' : 'cellEditConfigureStyle',
        subBuilder: CellEditConfigureStyleEvent.create)
    ..aOM<CellEditConfigureWindowEvent>(
        18, _omitFieldNames ? '' : 'cellEditConfigureWindow',
        subBuilder: CellEditConfigureWindowEvent.create)
    ..aOM<DropdownClosedEvent>(19, _omitFieldNames ? '' : 'dropdownClosed',
        subBuilder: DropdownClosedEvent.create)
    ..aOM<DropdownOpenedEvent>(20, _omitFieldNames ? '' : 'dropdownOpened',
        subBuilder: DropdownOpenedEvent.create)
    ..aOM<CellChangedEvent>(21, _omitFieldNames ? '' : 'cellChanged',
        subBuilder: CellChangedEvent.create)
    ..aOM<RowStatusChangeEvent>(22, _omitFieldNames ? '' : 'rowStatusChange',
        subBuilder: RowStatusChangeEvent.create)
    ..aOM<BeforeSortEvent>(23, _omitFieldNames ? '' : 'beforeSort',
        subBuilder: BeforeSortEvent.create)
    ..aOM<AfterSortEvent>(24, _omitFieldNames ? '' : 'afterSort',
        subBuilder: AfterSortEvent.create)
    ..aOM<CompareEvent>(25, _omitFieldNames ? '' : 'compare',
        subBuilder: CompareEvent.create)
    ..aOM<BeforeNodeToggleEvent>(26, _omitFieldNames ? '' : 'beforeNodeToggle',
        subBuilder: BeforeNodeToggleEvent.create)
    ..aOM<AfterNodeToggleEvent>(27, _omitFieldNames ? '' : 'afterNodeToggle',
        subBuilder: AfterNodeToggleEvent.create)
    ..aOM<BeforeScrollEvent>(28, _omitFieldNames ? '' : 'beforeScroll',
        subBuilder: BeforeScrollEvent.create)
    ..aOM<AfterScrollEvent>(29, _omitFieldNames ? '' : 'afterScroll',
        subBuilder: AfterScrollEvent.create)
    ..aOM<ScrollTooltipEvent>(30, _omitFieldNames ? '' : 'scrollTooltip',
        subBuilder: ScrollTooltipEvent.create)
    ..aOM<BeforeUserResizeEvent>(31, _omitFieldNames ? '' : 'beforeUserResize',
        subBuilder: BeforeUserResizeEvent.create)
    ..aOM<AfterUserResizeEvent>(32, _omitFieldNames ? '' : 'afterUserResize',
        subBuilder: AfterUserResizeEvent.create)
    ..aOM<AfterUserFreezeEvent>(33, _omitFieldNames ? '' : 'afterUserFreeze',
        subBuilder: AfterUserFreezeEvent.create)
    ..aOM<BeforeMoveColumnEvent>(34, _omitFieldNames ? '' : 'beforeMoveColumn',
        subBuilder: BeforeMoveColumnEvent.create)
    ..aOM<AfterMoveColumnEvent>(35, _omitFieldNames ? '' : 'afterMoveColumn',
        subBuilder: AfterMoveColumnEvent.create)
    ..aOM<BeforeMoveRowEvent>(36, _omitFieldNames ? '' : 'beforeMoveRow',
        subBuilder: BeforeMoveRowEvent.create)
    ..aOM<AfterMoveRowEvent>(37, _omitFieldNames ? '' : 'afterMoveRow',
        subBuilder: AfterMoveRowEvent.create)
    ..aOM<BeforeMouseDownEvent>(38, _omitFieldNames ? '' : 'beforeMouseDown',
        subBuilder: BeforeMouseDownEvent.create)
    ..aOM<MouseDownEvent>(39, _omitFieldNames ? '' : 'mouseDown',
        subBuilder: MouseDownEvent.create)
    ..aOM<MouseUpEvent>(40, _omitFieldNames ? '' : 'mouseUp',
        subBuilder: MouseUpEvent.create)
    ..aOM<MouseMoveEvent>(41, _omitFieldNames ? '' : 'mouseMove',
        subBuilder: MouseMoveEvent.create)
    ..aOM<ClickEvent>(42, _omitFieldNames ? '' : 'click',
        subBuilder: ClickEvent.create)
    ..aOM<DblClickEvent>(43, _omitFieldNames ? '' : 'dblClick',
        subBuilder: DblClickEvent.create)
    ..aOM<KeyDownEvent>(44, _omitFieldNames ? '' : 'keyDown',
        subBuilder: KeyDownEvent.create)
    ..aOM<KeyPressEvent>(45, _omitFieldNames ? '' : 'keyPress',
        subBuilder: KeyPressEvent.create)
    ..aOM<KeyUpEvent>(46, _omitFieldNames ? '' : 'keyUp',
        subBuilder: KeyUpEvent.create)
    ..aOM<CustomRenderCellEvent>(47, _omitFieldNames ? '' : 'customRenderCell',
        subBuilder: CustomRenderCellEvent.create)
    ..aOM<DragStartEvent>(48, _omitFieldNames ? '' : 'dragStart',
        subBuilder: DragStartEvent.create)
    ..aOM<DragOverEvent>(49, _omitFieldNames ? '' : 'dragOver',
        subBuilder: DragOverEvent.create)
    ..aOM<DragDropEvent>(50, _omitFieldNames ? '' : 'dragDrop',
        subBuilder: DragDropEvent.create)
    ..aOM<DragCompleteEvent>(51, _omitFieldNames ? '' : 'dragComplete',
        subBuilder: DragCompleteEvent.create)
    ..aOM<TypeAheadStartedEvent>(52, _omitFieldNames ? '' : 'typeAheadStarted',
        subBuilder: TypeAheadStartedEvent.create)
    ..aOM<TypeAheadEndedEvent>(53, _omitFieldNames ? '' : 'typeAheadEnded',
        subBuilder: TypeAheadEndedEvent.create)
    ..aOM<DataRefreshingEvent>(54, _omitFieldNames ? '' : 'dataRefreshing',
        subBuilder: DataRefreshingEvent.create)
    ..aOM<DataRefreshedEvent>(55, _omitFieldNames ? '' : 'dataRefreshed',
        subBuilder: DataRefreshedEvent.create)
    ..aOM<FilterDataEvent>(56, _omitFieldNames ? '' : 'filterData',
        subBuilder: FilterDataEvent.create)
    ..aOM<ErrorEvent>(57, _omitFieldNames ? '' : 'error',
        subBuilder: ErrorEvent.create)
    ..aOM<BeforePageBreakEvent>(58, _omitFieldNames ? '' : 'beforePageBreak',
        subBuilder: BeforePageBreakEvent.create)
    ..aOM<StartPageEvent>(59, _omitFieldNames ? '' : 'startPage',
        subBuilder: StartPageEvent.create)
    ..aOM<GetHeaderRowEvent>(60, _omitFieldNames ? '' : 'getHeaderRow',
        subBuilder: GetHeaderRowEvent.create)
    ..aOM<PullToRefreshTriggeredEvent>(
        61, _omitFieldNames ? '' : 'pullToRefreshTriggered',
        subBuilder: PullToRefreshTriggeredEvent.create)
    ..aOM<PullToRefreshCanceledEvent>(
        62, _omitFieldNames ? '' : 'pullToRefreshCanceled',
        subBuilder: PullToRefreshCanceledEvent.create)
    ..aInt64(100, _omitFieldNames ? '' : 'eventId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GridEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GridEvent copyWith(void Function(GridEvent) updates) =>
      super.copyWith((message) => updates(message as GridEvent)) as GridEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GridEvent create() => GridEvent._();
  @$core.override
  GridEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GridEvent getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GridEvent>(create);
  static GridEvent? _defaultInstance;

  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  @$pb.TagNumber(9)
  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  @$pb.TagNumber(14)
  @$pb.TagNumber(15)
  @$pb.TagNumber(16)
  @$pb.TagNumber(17)
  @$pb.TagNumber(18)
  @$pb.TagNumber(19)
  @$pb.TagNumber(20)
  @$pb.TagNumber(21)
  @$pb.TagNumber(22)
  @$pb.TagNumber(23)
  @$pb.TagNumber(24)
  @$pb.TagNumber(25)
  @$pb.TagNumber(26)
  @$pb.TagNumber(27)
  @$pb.TagNumber(28)
  @$pb.TagNumber(29)
  @$pb.TagNumber(30)
  @$pb.TagNumber(31)
  @$pb.TagNumber(32)
  @$pb.TagNumber(33)
  @$pb.TagNumber(34)
  @$pb.TagNumber(35)
  @$pb.TagNumber(36)
  @$pb.TagNumber(37)
  @$pb.TagNumber(38)
  @$pb.TagNumber(39)
  @$pb.TagNumber(40)
  @$pb.TagNumber(41)
  @$pb.TagNumber(42)
  @$pb.TagNumber(43)
  @$pb.TagNumber(44)
  @$pb.TagNumber(45)
  @$pb.TagNumber(46)
  @$pb.TagNumber(47)
  @$pb.TagNumber(48)
  @$pb.TagNumber(49)
  @$pb.TagNumber(50)
  @$pb.TagNumber(51)
  @$pb.TagNumber(52)
  @$pb.TagNumber(53)
  @$pb.TagNumber(54)
  @$pb.TagNumber(55)
  @$pb.TagNumber(56)
  @$pb.TagNumber(57)
  @$pb.TagNumber(58)
  @$pb.TagNumber(59)
  @$pb.TagNumber(60)
  @$pb.TagNumber(61)
  @$pb.TagNumber(62)
  GridEvent_Event whichEvent() => _GridEvent_EventByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  @$pb.TagNumber(9)
  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  @$pb.TagNumber(14)
  @$pb.TagNumber(15)
  @$pb.TagNumber(16)
  @$pb.TagNumber(17)
  @$pb.TagNumber(18)
  @$pb.TagNumber(19)
  @$pb.TagNumber(20)
  @$pb.TagNumber(21)
  @$pb.TagNumber(22)
  @$pb.TagNumber(23)
  @$pb.TagNumber(24)
  @$pb.TagNumber(25)
  @$pb.TagNumber(26)
  @$pb.TagNumber(27)
  @$pb.TagNumber(28)
  @$pb.TagNumber(29)
  @$pb.TagNumber(30)
  @$pb.TagNumber(31)
  @$pb.TagNumber(32)
  @$pb.TagNumber(33)
  @$pb.TagNumber(34)
  @$pb.TagNumber(35)
  @$pb.TagNumber(36)
  @$pb.TagNumber(37)
  @$pb.TagNumber(38)
  @$pb.TagNumber(39)
  @$pb.TagNumber(40)
  @$pb.TagNumber(41)
  @$pb.TagNumber(42)
  @$pb.TagNumber(43)
  @$pb.TagNumber(44)
  @$pb.TagNumber(45)
  @$pb.TagNumber(46)
  @$pb.TagNumber(47)
  @$pb.TagNumber(48)
  @$pb.TagNumber(49)
  @$pb.TagNumber(50)
  @$pb.TagNumber(51)
  @$pb.TagNumber(52)
  @$pb.TagNumber(53)
  @$pb.TagNumber(54)
  @$pb.TagNumber(55)
  @$pb.TagNumber(56)
  @$pb.TagNumber(57)
  @$pb.TagNumber(58)
  @$pb.TagNumber(59)
  @$pb.TagNumber(60)
  @$pb.TagNumber(61)
  @$pb.TagNumber(62)
  void clearEvent() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $fixnum.Int64 get gridId => $_getI64(0);
  @$pb.TagNumber(1)
  set gridId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGridId() => $_has(0);
  @$pb.TagNumber(1)
  void clearGridId() => $_clearField(1);

  /// Navigation
  @$pb.TagNumber(2)
  CellFocusChangingEvent get cellFocusChanging => $_getN(1);
  @$pb.TagNumber(2)
  set cellFocusChanging(CellFocusChangingEvent value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasCellFocusChanging() => $_has(1);
  @$pb.TagNumber(2)
  void clearCellFocusChanging() => $_clearField(2);
  @$pb.TagNumber(2)
  CellFocusChangingEvent ensureCellFocusChanging() => $_ensure(1);

  @$pb.TagNumber(3)
  CellFocusChangedEvent get cellFocusChanged => $_getN(2);
  @$pb.TagNumber(3)
  set cellFocusChanged(CellFocusChangedEvent value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasCellFocusChanged() => $_has(2);
  @$pb.TagNumber(3)
  void clearCellFocusChanged() => $_clearField(3);
  @$pb.TagNumber(3)
  CellFocusChangedEvent ensureCellFocusChanged() => $_ensure(2);

  @$pb.TagNumber(4)
  SelectionChangingEvent get selectionChanging => $_getN(3);
  @$pb.TagNumber(4)
  set selectionChanging(SelectionChangingEvent value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasSelectionChanging() => $_has(3);
  @$pb.TagNumber(4)
  void clearSelectionChanging() => $_clearField(4);
  @$pb.TagNumber(4)
  SelectionChangingEvent ensureSelectionChanging() => $_ensure(3);

  @$pb.TagNumber(5)
  SelectionChangedEvent get selectionChanged => $_getN(4);
  @$pb.TagNumber(5)
  set selectionChanged(SelectionChangedEvent value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasSelectionChanged() => $_has(4);
  @$pb.TagNumber(5)
  void clearSelectionChanged() => $_clearField(5);
  @$pb.TagNumber(5)
  SelectionChangedEvent ensureSelectionChanged() => $_ensure(4);

  @$pb.TagNumber(6)
  EnterCellEvent get enterCell => $_getN(5);
  @$pb.TagNumber(6)
  set enterCell(EnterCellEvent value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasEnterCell() => $_has(5);
  @$pb.TagNumber(6)
  void clearEnterCell() => $_clearField(6);
  @$pb.TagNumber(6)
  EnterCellEvent ensureEnterCell() => $_ensure(5);

  @$pb.TagNumber(7)
  LeaveCellEvent get leaveCell => $_getN(6);
  @$pb.TagNumber(7)
  set leaveCell(LeaveCellEvent value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasLeaveCell() => $_has(6);
  @$pb.TagNumber(7)
  void clearLeaveCell() => $_clearField(7);
  @$pb.TagNumber(7)
  LeaveCellEvent ensureLeaveCell() => $_ensure(6);

  /// Editing
  @$pb.TagNumber(8)
  BeforeEditEvent get beforeEdit => $_getN(7);
  @$pb.TagNumber(8)
  set beforeEdit(BeforeEditEvent value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasBeforeEdit() => $_has(7);
  @$pb.TagNumber(8)
  void clearBeforeEdit() => $_clearField(8);
  @$pb.TagNumber(8)
  BeforeEditEvent ensureBeforeEdit() => $_ensure(7);

  @$pb.TagNumber(9)
  StartEditEvent get startEdit => $_getN(8);
  @$pb.TagNumber(9)
  set startEdit(StartEditEvent value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasStartEdit() => $_has(8);
  @$pb.TagNumber(9)
  void clearStartEdit() => $_clearField(9);
  @$pb.TagNumber(9)
  StartEditEvent ensureStartEdit() => $_ensure(8);

  @$pb.TagNumber(10)
  AfterEditEvent get afterEdit => $_getN(9);
  @$pb.TagNumber(10)
  set afterEdit(AfterEditEvent value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasAfterEdit() => $_has(9);
  @$pb.TagNumber(10)
  void clearAfterEdit() => $_clearField(10);
  @$pb.TagNumber(10)
  AfterEditEvent ensureAfterEdit() => $_ensure(9);

  @$pb.TagNumber(11)
  CellEditValidateEvent get cellEditValidate => $_getN(10);
  @$pb.TagNumber(11)
  set cellEditValidate(CellEditValidateEvent value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasCellEditValidate() => $_has(10);
  @$pb.TagNumber(11)
  void clearCellEditValidate() => $_clearField(11);
  @$pb.TagNumber(11)
  CellEditValidateEvent ensureCellEditValidate() => $_ensure(10);

  @$pb.TagNumber(12)
  CellEditChangeEvent get cellEditChange => $_getN(11);
  @$pb.TagNumber(12)
  set cellEditChange(CellEditChangeEvent value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasCellEditChange() => $_has(11);
  @$pb.TagNumber(12)
  void clearCellEditChange() => $_clearField(12);
  @$pb.TagNumber(12)
  CellEditChangeEvent ensureCellEditChange() => $_ensure(11);

  @$pb.TagNumber(14)
  KeyDownEditEvent get keyDownEdit => $_getN(12);
  @$pb.TagNumber(14)
  set keyDownEdit(KeyDownEditEvent value) => $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasKeyDownEdit() => $_has(12);
  @$pb.TagNumber(14)
  void clearKeyDownEdit() => $_clearField(14);
  @$pb.TagNumber(14)
  KeyDownEditEvent ensureKeyDownEdit() => $_ensure(12);

  @$pb.TagNumber(15)
  KeyPressEditEvent get keyPressEdit => $_getN(13);
  @$pb.TagNumber(15)
  set keyPressEdit(KeyPressEditEvent value) => $_setField(15, value);
  @$pb.TagNumber(15)
  $core.bool hasKeyPressEdit() => $_has(13);
  @$pb.TagNumber(15)
  void clearKeyPressEdit() => $_clearField(15);
  @$pb.TagNumber(15)
  KeyPressEditEvent ensureKeyPressEdit() => $_ensure(13);

  @$pb.TagNumber(16)
  KeyUpEditEvent get keyUpEdit => $_getN(14);
  @$pb.TagNumber(16)
  set keyUpEdit(KeyUpEditEvent value) => $_setField(16, value);
  @$pb.TagNumber(16)
  $core.bool hasKeyUpEdit() => $_has(14);
  @$pb.TagNumber(16)
  void clearKeyUpEdit() => $_clearField(16);
  @$pb.TagNumber(16)
  KeyUpEditEvent ensureKeyUpEdit() => $_ensure(14);

  @$pb.TagNumber(17)
  CellEditConfigureStyleEvent get cellEditConfigureStyle => $_getN(15);
  @$pb.TagNumber(17)
  set cellEditConfigureStyle(CellEditConfigureStyleEvent value) =>
      $_setField(17, value);
  @$pb.TagNumber(17)
  $core.bool hasCellEditConfigureStyle() => $_has(15);
  @$pb.TagNumber(17)
  void clearCellEditConfigureStyle() => $_clearField(17);
  @$pb.TagNumber(17)
  CellEditConfigureStyleEvent ensureCellEditConfigureStyle() => $_ensure(15);

  @$pb.TagNumber(18)
  CellEditConfigureWindowEvent get cellEditConfigureWindow => $_getN(16);
  @$pb.TagNumber(18)
  set cellEditConfigureWindow(CellEditConfigureWindowEvent value) =>
      $_setField(18, value);
  @$pb.TagNumber(18)
  $core.bool hasCellEditConfigureWindow() => $_has(16);
  @$pb.TagNumber(18)
  void clearCellEditConfigureWindow() => $_clearField(18);
  @$pb.TagNumber(18)
  CellEditConfigureWindowEvent ensureCellEditConfigureWindow() => $_ensure(16);

  @$pb.TagNumber(19)
  DropdownClosedEvent get dropdownClosed => $_getN(17);
  @$pb.TagNumber(19)
  set dropdownClosed(DropdownClosedEvent value) => $_setField(19, value);
  @$pb.TagNumber(19)
  $core.bool hasDropdownClosed() => $_has(17);
  @$pb.TagNumber(19)
  void clearDropdownClosed() => $_clearField(19);
  @$pb.TagNumber(19)
  DropdownClosedEvent ensureDropdownClosed() => $_ensure(17);

  @$pb.TagNumber(20)
  DropdownOpenedEvent get dropdownOpened => $_getN(18);
  @$pb.TagNumber(20)
  set dropdownOpened(DropdownOpenedEvent value) => $_setField(20, value);
  @$pb.TagNumber(20)
  $core.bool hasDropdownOpened() => $_has(18);
  @$pb.TagNumber(20)
  void clearDropdownOpened() => $_clearField(20);
  @$pb.TagNumber(20)
  DropdownOpenedEvent ensureDropdownOpened() => $_ensure(18);

  /// Data
  @$pb.TagNumber(21)
  CellChangedEvent get cellChanged => $_getN(19);
  @$pb.TagNumber(21)
  set cellChanged(CellChangedEvent value) => $_setField(21, value);
  @$pb.TagNumber(21)
  $core.bool hasCellChanged() => $_has(19);
  @$pb.TagNumber(21)
  void clearCellChanged() => $_clearField(21);
  @$pb.TagNumber(21)
  CellChangedEvent ensureCellChanged() => $_ensure(19);

  @$pb.TagNumber(22)
  RowStatusChangeEvent get rowStatusChange => $_getN(20);
  @$pb.TagNumber(22)
  set rowStatusChange(RowStatusChangeEvent value) => $_setField(22, value);
  @$pb.TagNumber(22)
  $core.bool hasRowStatusChange() => $_has(20);
  @$pb.TagNumber(22)
  void clearRowStatusChange() => $_clearField(22);
  @$pb.TagNumber(22)
  RowStatusChangeEvent ensureRowStatusChange() => $_ensure(20);

  /// Sort
  @$pb.TagNumber(23)
  BeforeSortEvent get beforeSort => $_getN(21);
  @$pb.TagNumber(23)
  set beforeSort(BeforeSortEvent value) => $_setField(23, value);
  @$pb.TagNumber(23)
  $core.bool hasBeforeSort() => $_has(21);
  @$pb.TagNumber(23)
  void clearBeforeSort() => $_clearField(23);
  @$pb.TagNumber(23)
  BeforeSortEvent ensureBeforeSort() => $_ensure(21);

  @$pb.TagNumber(24)
  AfterSortEvent get afterSort => $_getN(22);
  @$pb.TagNumber(24)
  set afterSort(AfterSortEvent value) => $_setField(24, value);
  @$pb.TagNumber(24)
  $core.bool hasAfterSort() => $_has(22);
  @$pb.TagNumber(24)
  void clearAfterSort() => $_clearField(24);
  @$pb.TagNumber(24)
  AfterSortEvent ensureAfterSort() => $_ensure(22);

  @$pb.TagNumber(25)
  CompareEvent get compare => $_getN(23);
  @$pb.TagNumber(25)
  set compare(CompareEvent value) => $_setField(25, value);
  @$pb.TagNumber(25)
  $core.bool hasCompare() => $_has(23);
  @$pb.TagNumber(25)
  void clearCompare() => $_clearField(25);
  @$pb.TagNumber(25)
  CompareEvent ensureCompare() => $_ensure(23);

  /// Outline
  @$pb.TagNumber(26)
  BeforeNodeToggleEvent get beforeNodeToggle => $_getN(24);
  @$pb.TagNumber(26)
  set beforeNodeToggle(BeforeNodeToggleEvent value) => $_setField(26, value);
  @$pb.TagNumber(26)
  $core.bool hasBeforeNodeToggle() => $_has(24);
  @$pb.TagNumber(26)
  void clearBeforeNodeToggle() => $_clearField(26);
  @$pb.TagNumber(26)
  BeforeNodeToggleEvent ensureBeforeNodeToggle() => $_ensure(24);

  @$pb.TagNumber(27)
  AfterNodeToggleEvent get afterNodeToggle => $_getN(25);
  @$pb.TagNumber(27)
  set afterNodeToggle(AfterNodeToggleEvent value) => $_setField(27, value);
  @$pb.TagNumber(27)
  $core.bool hasAfterNodeToggle() => $_has(25);
  @$pb.TagNumber(27)
  void clearAfterNodeToggle() => $_clearField(27);
  @$pb.TagNumber(27)
  AfterNodeToggleEvent ensureAfterNodeToggle() => $_ensure(25);

  /// Scroll
  @$pb.TagNumber(28)
  BeforeScrollEvent get beforeScroll => $_getN(26);
  @$pb.TagNumber(28)
  set beforeScroll(BeforeScrollEvent value) => $_setField(28, value);
  @$pb.TagNumber(28)
  $core.bool hasBeforeScroll() => $_has(26);
  @$pb.TagNumber(28)
  void clearBeforeScroll() => $_clearField(28);
  @$pb.TagNumber(28)
  BeforeScrollEvent ensureBeforeScroll() => $_ensure(26);

  @$pb.TagNumber(29)
  AfterScrollEvent get afterScroll => $_getN(27);
  @$pb.TagNumber(29)
  set afterScroll(AfterScrollEvent value) => $_setField(29, value);
  @$pb.TagNumber(29)
  $core.bool hasAfterScroll() => $_has(27);
  @$pb.TagNumber(29)
  void clearAfterScroll() => $_clearField(29);
  @$pb.TagNumber(29)
  AfterScrollEvent ensureAfterScroll() => $_ensure(27);

  @$pb.TagNumber(30)
  ScrollTooltipEvent get scrollTooltip => $_getN(28);
  @$pb.TagNumber(30)
  set scrollTooltip(ScrollTooltipEvent value) => $_setField(30, value);
  @$pb.TagNumber(30)
  $core.bool hasScrollTooltip() => $_has(28);
  @$pb.TagNumber(30)
  void clearScrollTooltip() => $_clearField(30);
  @$pb.TagNumber(30)
  ScrollTooltipEvent ensureScrollTooltip() => $_ensure(28);

  /// Resize & Freeze
  @$pb.TagNumber(31)
  BeforeUserResizeEvent get beforeUserResize => $_getN(29);
  @$pb.TagNumber(31)
  set beforeUserResize(BeforeUserResizeEvent value) => $_setField(31, value);
  @$pb.TagNumber(31)
  $core.bool hasBeforeUserResize() => $_has(29);
  @$pb.TagNumber(31)
  void clearBeforeUserResize() => $_clearField(31);
  @$pb.TagNumber(31)
  BeforeUserResizeEvent ensureBeforeUserResize() => $_ensure(29);

  @$pb.TagNumber(32)
  AfterUserResizeEvent get afterUserResize => $_getN(30);
  @$pb.TagNumber(32)
  set afterUserResize(AfterUserResizeEvent value) => $_setField(32, value);
  @$pb.TagNumber(32)
  $core.bool hasAfterUserResize() => $_has(30);
  @$pb.TagNumber(32)
  void clearAfterUserResize() => $_clearField(32);
  @$pb.TagNumber(32)
  AfterUserResizeEvent ensureAfterUserResize() => $_ensure(30);

  @$pb.TagNumber(33)
  AfterUserFreezeEvent get afterUserFreeze => $_getN(31);
  @$pb.TagNumber(33)
  set afterUserFreeze(AfterUserFreezeEvent value) => $_setField(33, value);
  @$pb.TagNumber(33)
  $core.bool hasAfterUserFreeze() => $_has(31);
  @$pb.TagNumber(33)
  void clearAfterUserFreeze() => $_clearField(33);
  @$pb.TagNumber(33)
  AfterUserFreezeEvent ensureAfterUserFreeze() => $_ensure(31);

  /// Column/Row move
  @$pb.TagNumber(34)
  BeforeMoveColumnEvent get beforeMoveColumn => $_getN(32);
  @$pb.TagNumber(34)
  set beforeMoveColumn(BeforeMoveColumnEvent value) => $_setField(34, value);
  @$pb.TagNumber(34)
  $core.bool hasBeforeMoveColumn() => $_has(32);
  @$pb.TagNumber(34)
  void clearBeforeMoveColumn() => $_clearField(34);
  @$pb.TagNumber(34)
  BeforeMoveColumnEvent ensureBeforeMoveColumn() => $_ensure(32);

  @$pb.TagNumber(35)
  AfterMoveColumnEvent get afterMoveColumn => $_getN(33);
  @$pb.TagNumber(35)
  set afterMoveColumn(AfterMoveColumnEvent value) => $_setField(35, value);
  @$pb.TagNumber(35)
  $core.bool hasAfterMoveColumn() => $_has(33);
  @$pb.TagNumber(35)
  void clearAfterMoveColumn() => $_clearField(35);
  @$pb.TagNumber(35)
  AfterMoveColumnEvent ensureAfterMoveColumn() => $_ensure(33);

  @$pb.TagNumber(36)
  BeforeMoveRowEvent get beforeMoveRow => $_getN(34);
  @$pb.TagNumber(36)
  set beforeMoveRow(BeforeMoveRowEvent value) => $_setField(36, value);
  @$pb.TagNumber(36)
  $core.bool hasBeforeMoveRow() => $_has(34);
  @$pb.TagNumber(36)
  void clearBeforeMoveRow() => $_clearField(36);
  @$pb.TagNumber(36)
  BeforeMoveRowEvent ensureBeforeMoveRow() => $_ensure(34);

  @$pb.TagNumber(37)
  AfterMoveRowEvent get afterMoveRow => $_getN(35);
  @$pb.TagNumber(37)
  set afterMoveRow(AfterMoveRowEvent value) => $_setField(37, value);
  @$pb.TagNumber(37)
  $core.bool hasAfterMoveRow() => $_has(35);
  @$pb.TagNumber(37)
  void clearAfterMoveRow() => $_clearField(37);
  @$pb.TagNumber(37)
  AfterMoveRowEvent ensureAfterMoveRow() => $_ensure(35);

  /// Mouse
  @$pb.TagNumber(38)
  BeforeMouseDownEvent get beforeMouseDown => $_getN(36);
  @$pb.TagNumber(38)
  set beforeMouseDown(BeforeMouseDownEvent value) => $_setField(38, value);
  @$pb.TagNumber(38)
  $core.bool hasBeforeMouseDown() => $_has(36);
  @$pb.TagNumber(38)
  void clearBeforeMouseDown() => $_clearField(38);
  @$pb.TagNumber(38)
  BeforeMouseDownEvent ensureBeforeMouseDown() => $_ensure(36);

  @$pb.TagNumber(39)
  MouseDownEvent get mouseDown => $_getN(37);
  @$pb.TagNumber(39)
  set mouseDown(MouseDownEvent value) => $_setField(39, value);
  @$pb.TagNumber(39)
  $core.bool hasMouseDown() => $_has(37);
  @$pb.TagNumber(39)
  void clearMouseDown() => $_clearField(39);
  @$pb.TagNumber(39)
  MouseDownEvent ensureMouseDown() => $_ensure(37);

  @$pb.TagNumber(40)
  MouseUpEvent get mouseUp => $_getN(38);
  @$pb.TagNumber(40)
  set mouseUp(MouseUpEvent value) => $_setField(40, value);
  @$pb.TagNumber(40)
  $core.bool hasMouseUp() => $_has(38);
  @$pb.TagNumber(40)
  void clearMouseUp() => $_clearField(40);
  @$pb.TagNumber(40)
  MouseUpEvent ensureMouseUp() => $_ensure(38);

  @$pb.TagNumber(41)
  MouseMoveEvent get mouseMove => $_getN(39);
  @$pb.TagNumber(41)
  set mouseMove(MouseMoveEvent value) => $_setField(41, value);
  @$pb.TagNumber(41)
  $core.bool hasMouseMove() => $_has(39);
  @$pb.TagNumber(41)
  void clearMouseMove() => $_clearField(41);
  @$pb.TagNumber(41)
  MouseMoveEvent ensureMouseMove() => $_ensure(39);

  @$pb.TagNumber(42)
  ClickEvent get click => $_getN(40);
  @$pb.TagNumber(42)
  set click(ClickEvent value) => $_setField(42, value);
  @$pb.TagNumber(42)
  $core.bool hasClick() => $_has(40);
  @$pb.TagNumber(42)
  void clearClick() => $_clearField(42);
  @$pb.TagNumber(42)
  ClickEvent ensureClick() => $_ensure(40);

  @$pb.TagNumber(43)
  DblClickEvent get dblClick => $_getN(41);
  @$pb.TagNumber(43)
  set dblClick(DblClickEvent value) => $_setField(43, value);
  @$pb.TagNumber(43)
  $core.bool hasDblClick() => $_has(41);
  @$pb.TagNumber(43)
  void clearDblClick() => $_clearField(43);
  @$pb.TagNumber(43)
  DblClickEvent ensureDblClick() => $_ensure(41);

  /// Keyboard
  @$pb.TagNumber(44)
  KeyDownEvent get keyDown => $_getN(42);
  @$pb.TagNumber(44)
  set keyDown(KeyDownEvent value) => $_setField(44, value);
  @$pb.TagNumber(44)
  $core.bool hasKeyDown() => $_has(42);
  @$pb.TagNumber(44)
  void clearKeyDown() => $_clearField(44);
  @$pb.TagNumber(44)
  KeyDownEvent ensureKeyDown() => $_ensure(42);

  @$pb.TagNumber(45)
  KeyPressEvent get keyPress => $_getN(43);
  @$pb.TagNumber(45)
  set keyPress(KeyPressEvent value) => $_setField(45, value);
  @$pb.TagNumber(45)
  $core.bool hasKeyPress() => $_has(43);
  @$pb.TagNumber(45)
  void clearKeyPress() => $_clearField(45);
  @$pb.TagNumber(45)
  KeyPressEvent ensureKeyPress() => $_ensure(43);

  @$pb.TagNumber(46)
  KeyUpEvent get keyUp => $_getN(44);
  @$pb.TagNumber(46)
  set keyUp(KeyUpEvent value) => $_setField(46, value);
  @$pb.TagNumber(46)
  $core.bool hasKeyUp() => $_has(44);
  @$pb.TagNumber(46)
  void clearKeyUp() => $_clearField(46);
  @$pb.TagNumber(46)
  KeyUpEvent ensureKeyUp() => $_ensure(44);

  /// Drawing
  @$pb.TagNumber(47)
  CustomRenderCellEvent get customRenderCell => $_getN(45);
  @$pb.TagNumber(47)
  set customRenderCell(CustomRenderCellEvent value) => $_setField(47, value);
  @$pb.TagNumber(47)
  $core.bool hasCustomRenderCell() => $_has(45);
  @$pb.TagNumber(47)
  void clearCustomRenderCell() => $_clearField(47);
  @$pb.TagNumber(47)
  CustomRenderCellEvent ensureCustomRenderCell() => $_ensure(45);

  /// Drag & Drop
  @$pb.TagNumber(48)
  DragStartEvent get dragStart => $_getN(46);
  @$pb.TagNumber(48)
  set dragStart(DragStartEvent value) => $_setField(48, value);
  @$pb.TagNumber(48)
  $core.bool hasDragStart() => $_has(46);
  @$pb.TagNumber(48)
  void clearDragStart() => $_clearField(48);
  @$pb.TagNumber(48)
  DragStartEvent ensureDragStart() => $_ensure(46);

  @$pb.TagNumber(49)
  DragOverEvent get dragOver => $_getN(47);
  @$pb.TagNumber(49)
  set dragOver(DragOverEvent value) => $_setField(49, value);
  @$pb.TagNumber(49)
  $core.bool hasDragOver() => $_has(47);
  @$pb.TagNumber(49)
  void clearDragOver() => $_clearField(49);
  @$pb.TagNumber(49)
  DragOverEvent ensureDragOver() => $_ensure(47);

  @$pb.TagNumber(50)
  DragDropEvent get dragDrop => $_getN(48);
  @$pb.TagNumber(50)
  set dragDrop(DragDropEvent value) => $_setField(50, value);
  @$pb.TagNumber(50)
  $core.bool hasDragDrop() => $_has(48);
  @$pb.TagNumber(50)
  void clearDragDrop() => $_clearField(50);
  @$pb.TagNumber(50)
  DragDropEvent ensureDragDrop() => $_ensure(48);

  @$pb.TagNumber(51)
  DragCompleteEvent get dragComplete => $_getN(49);
  @$pb.TagNumber(51)
  set dragComplete(DragCompleteEvent value) => $_setField(51, value);
  @$pb.TagNumber(51)
  $core.bool hasDragComplete() => $_has(49);
  @$pb.TagNumber(51)
  void clearDragComplete() => $_clearField(51);
  @$pb.TagNumber(51)
  DragCompleteEvent ensureDragComplete() => $_ensure(49);

  /// Search
  @$pb.TagNumber(52)
  TypeAheadStartedEvent get typeAheadStarted => $_getN(50);
  @$pb.TagNumber(52)
  set typeAheadStarted(TypeAheadStartedEvent value) => $_setField(52, value);
  @$pb.TagNumber(52)
  $core.bool hasTypeAheadStarted() => $_has(50);
  @$pb.TagNumber(52)
  void clearTypeAheadStarted() => $_clearField(52);
  @$pb.TagNumber(52)
  TypeAheadStartedEvent ensureTypeAheadStarted() => $_ensure(50);

  @$pb.TagNumber(53)
  TypeAheadEndedEvent get typeAheadEnded => $_getN(51);
  @$pb.TagNumber(53)
  set typeAheadEnded(TypeAheadEndedEvent value) => $_setField(53, value);
  @$pb.TagNumber(53)
  $core.bool hasTypeAheadEnded() => $_has(51);
  @$pb.TagNumber(53)
  void clearTypeAheadEnded() => $_clearField(53);
  @$pb.TagNumber(53)
  TypeAheadEndedEvent ensureTypeAheadEnded() => $_ensure(51);

  /// Data refresh
  @$pb.TagNumber(54)
  DataRefreshingEvent get dataRefreshing => $_getN(52);
  @$pb.TagNumber(54)
  set dataRefreshing(DataRefreshingEvent value) => $_setField(54, value);
  @$pb.TagNumber(54)
  $core.bool hasDataRefreshing() => $_has(52);
  @$pb.TagNumber(54)
  void clearDataRefreshing() => $_clearField(54);
  @$pb.TagNumber(54)
  DataRefreshingEvent ensureDataRefreshing() => $_ensure(52);

  @$pb.TagNumber(55)
  DataRefreshedEvent get dataRefreshed => $_getN(53);
  @$pb.TagNumber(55)
  set dataRefreshed(DataRefreshedEvent value) => $_setField(55, value);
  @$pb.TagNumber(55)
  $core.bool hasDataRefreshed() => $_has(53);
  @$pb.TagNumber(55)
  void clearDataRefreshed() => $_clearField(55);
  @$pb.TagNumber(55)
  DataRefreshedEvent ensureDataRefreshed() => $_ensure(53);

  @$pb.TagNumber(56)
  FilterDataEvent get filterData => $_getN(54);
  @$pb.TagNumber(56)
  set filterData(FilterDataEvent value) => $_setField(56, value);
  @$pb.TagNumber(56)
  $core.bool hasFilterData() => $_has(54);
  @$pb.TagNumber(56)
  void clearFilterData() => $_clearField(56);
  @$pb.TagNumber(56)
  FilterDataEvent ensureFilterData() => $_ensure(54);

  /// Error
  @$pb.TagNumber(57)
  ErrorEvent get error => $_getN(55);
  @$pb.TagNumber(57)
  set error(ErrorEvent value) => $_setField(57, value);
  @$pb.TagNumber(57)
  $core.bool hasError() => $_has(55);
  @$pb.TagNumber(57)
  void clearError() => $_clearField(57);
  @$pb.TagNumber(57)
  ErrorEvent ensureError() => $_ensure(55);

  /// Print
  @$pb.TagNumber(58)
  BeforePageBreakEvent get beforePageBreak => $_getN(56);
  @$pb.TagNumber(58)
  set beforePageBreak(BeforePageBreakEvent value) => $_setField(58, value);
  @$pb.TagNumber(58)
  $core.bool hasBeforePageBreak() => $_has(56);
  @$pb.TagNumber(58)
  void clearBeforePageBreak() => $_clearField(58);
  @$pb.TagNumber(58)
  BeforePageBreakEvent ensureBeforePageBreak() => $_ensure(56);

  @$pb.TagNumber(59)
  StartPageEvent get startPage => $_getN(57);
  @$pb.TagNumber(59)
  set startPage(StartPageEvent value) => $_setField(59, value);
  @$pb.TagNumber(59)
  $core.bool hasStartPage() => $_has(57);
  @$pb.TagNumber(59)
  void clearStartPage() => $_clearField(59);
  @$pb.TagNumber(59)
  StartPageEvent ensureStartPage() => $_ensure(57);

  @$pb.TagNumber(60)
  GetHeaderRowEvent get getHeaderRow => $_getN(58);
  @$pb.TagNumber(60)
  set getHeaderRow(GetHeaderRowEvent value) => $_setField(60, value);
  @$pb.TagNumber(60)
  $core.bool hasGetHeaderRow() => $_has(58);
  @$pb.TagNumber(60)
  void clearGetHeaderRow() => $_clearField(60);
  @$pb.TagNumber(60)
  GetHeaderRowEvent ensureGetHeaderRow() => $_ensure(58);

  /// Pull to refresh
  @$pb.TagNumber(61)
  PullToRefreshTriggeredEvent get pullToRefreshTriggered => $_getN(59);
  @$pb.TagNumber(61)
  set pullToRefreshTriggered(PullToRefreshTriggeredEvent value) =>
      $_setField(61, value);
  @$pb.TagNumber(61)
  $core.bool hasPullToRefreshTriggered() => $_has(59);
  @$pb.TagNumber(61)
  void clearPullToRefreshTriggered() => $_clearField(61);
  @$pb.TagNumber(61)
  PullToRefreshTriggeredEvent ensurePullToRefreshTriggered() => $_ensure(59);

  @$pb.TagNumber(62)
  PullToRefreshCanceledEvent get pullToRefreshCanceled => $_getN(60);
  @$pb.TagNumber(62)
  set pullToRefreshCanceled(PullToRefreshCanceledEvent value) =>
      $_setField(62, value);
  @$pb.TagNumber(62)
  $core.bool hasPullToRefreshCanceled() => $_has(60);
  @$pb.TagNumber(62)
  void clearPullToRefreshCanceled() => $_clearField(62);
  @$pb.TagNumber(62)
  PullToRefreshCanceledEvent ensurePullToRefreshCanceled() => $_ensure(60);

  @$pb.TagNumber(100)
  $fixnum.Int64 get eventId => $_getI64(61);
  @$pb.TagNumber(100)
  set eventId($fixnum.Int64 value) => $_setInt64(61, value);
  @$pb.TagNumber(100)
  $core.bool hasEventId() => $_has(61);
  @$pb.TagNumber(100)
  void clearEventId() => $_clearField(100);
}

/// ── Navigation Events ──
class CellFocusChangingEvent extends $pb.GeneratedMessage {
  factory CellFocusChangingEvent({
    $core.int? oldRow,
    $core.int? oldCol,
    $core.int? newRow,
    $core.int? newCol,
  }) {
    final result = create();
    if (oldRow != null) result.oldRow = oldRow;
    if (oldCol != null) result.oldCol = oldCol;
    if (newRow != null) result.newRow = newRow;
    if (newCol != null) result.newCol = newCol;
    return result;
  }

  CellFocusChangingEvent._();

  factory CellFocusChangingEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CellFocusChangingEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CellFocusChangingEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'oldRow')
    ..aI(2, _omitFieldNames ? '' : 'oldCol')
    ..aI(3, _omitFieldNames ? '' : 'newRow')
    ..aI(4, _omitFieldNames ? '' : 'newCol')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CellFocusChangingEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CellFocusChangingEvent copyWith(
          void Function(CellFocusChangingEvent) updates) =>
      super.copyWith((message) => updates(message as CellFocusChangingEvent))
          as CellFocusChangingEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CellFocusChangingEvent create() => CellFocusChangingEvent._();
  @$core.override
  CellFocusChangingEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CellFocusChangingEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CellFocusChangingEvent>(create);
  static CellFocusChangingEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get oldRow => $_getIZ(0);
  @$pb.TagNumber(1)
  set oldRow($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOldRow() => $_has(0);
  @$pb.TagNumber(1)
  void clearOldRow() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get oldCol => $_getIZ(1);
  @$pb.TagNumber(2)
  set oldCol($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasOldCol() => $_has(1);
  @$pb.TagNumber(2)
  void clearOldCol() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get newRow => $_getIZ(2);
  @$pb.TagNumber(3)
  set newRow($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasNewRow() => $_has(2);
  @$pb.TagNumber(3)
  void clearNewRow() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get newCol => $_getIZ(3);
  @$pb.TagNumber(4)
  set newCol($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasNewCol() => $_has(3);
  @$pb.TagNumber(4)
  void clearNewCol() => $_clearField(4);
}

class CellFocusChangedEvent extends $pb.GeneratedMessage {
  factory CellFocusChangedEvent({
    $core.int? oldRow,
    $core.int? oldCol,
    $core.int? newRow,
    $core.int? newCol,
  }) {
    final result = create();
    if (oldRow != null) result.oldRow = oldRow;
    if (oldCol != null) result.oldCol = oldCol;
    if (newRow != null) result.newRow = newRow;
    if (newCol != null) result.newCol = newCol;
    return result;
  }

  CellFocusChangedEvent._();

  factory CellFocusChangedEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CellFocusChangedEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CellFocusChangedEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'oldRow')
    ..aI(2, _omitFieldNames ? '' : 'oldCol')
    ..aI(3, _omitFieldNames ? '' : 'newRow')
    ..aI(4, _omitFieldNames ? '' : 'newCol')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CellFocusChangedEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CellFocusChangedEvent copyWith(
          void Function(CellFocusChangedEvent) updates) =>
      super.copyWith((message) => updates(message as CellFocusChangedEvent))
          as CellFocusChangedEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CellFocusChangedEvent create() => CellFocusChangedEvent._();
  @$core.override
  CellFocusChangedEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CellFocusChangedEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CellFocusChangedEvent>(create);
  static CellFocusChangedEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get oldRow => $_getIZ(0);
  @$pb.TagNumber(1)
  set oldRow($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOldRow() => $_has(0);
  @$pb.TagNumber(1)
  void clearOldRow() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get oldCol => $_getIZ(1);
  @$pb.TagNumber(2)
  set oldCol($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasOldCol() => $_has(1);
  @$pb.TagNumber(2)
  void clearOldCol() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get newRow => $_getIZ(2);
  @$pb.TagNumber(3)
  set newRow($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasNewRow() => $_has(2);
  @$pb.TagNumber(3)
  void clearNewRow() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get newCol => $_getIZ(3);
  @$pb.TagNumber(4)
  set newCol($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasNewCol() => $_has(3);
  @$pb.TagNumber(4)
  void clearNewCol() => $_clearField(4);
}

class SelectionChangingEvent extends $pb.GeneratedMessage {
  factory SelectionChangingEvent({
    $core.Iterable<CellRange>? oldRanges,
    $core.Iterable<CellRange>? newRanges,
    $core.int? activeRow,
    $core.int? activeCol,
  }) {
    final result = create();
    if (oldRanges != null) result.oldRanges.addAll(oldRanges);
    if (newRanges != null) result.newRanges.addAll(newRanges);
    if (activeRow != null) result.activeRow = activeRow;
    if (activeCol != null) result.activeCol = activeCol;
    return result;
  }

  SelectionChangingEvent._();

  factory SelectionChangingEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SelectionChangingEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SelectionChangingEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..pPM<CellRange>(1, _omitFieldNames ? '' : 'oldRanges',
        subBuilder: CellRange.create)
    ..pPM<CellRange>(2, _omitFieldNames ? '' : 'newRanges',
        subBuilder: CellRange.create)
    ..aI(3, _omitFieldNames ? '' : 'activeRow')
    ..aI(4, _omitFieldNames ? '' : 'activeCol')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SelectionChangingEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SelectionChangingEvent copyWith(
          void Function(SelectionChangingEvent) updates) =>
      super.copyWith((message) => updates(message as SelectionChangingEvent))
          as SelectionChangingEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SelectionChangingEvent create() => SelectionChangingEvent._();
  @$core.override
  SelectionChangingEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SelectionChangingEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SelectionChangingEvent>(create);
  static SelectionChangingEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<CellRange> get oldRanges => $_getList(0);

  @$pb.TagNumber(2)
  $pb.PbList<CellRange> get newRanges => $_getList(1);

  @$pb.TagNumber(3)
  $core.int get activeRow => $_getIZ(2);
  @$pb.TagNumber(3)
  set activeRow($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasActiveRow() => $_has(2);
  @$pb.TagNumber(3)
  void clearActiveRow() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get activeCol => $_getIZ(3);
  @$pb.TagNumber(4)
  set activeCol($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasActiveCol() => $_has(3);
  @$pb.TagNumber(4)
  void clearActiveCol() => $_clearField(4);
}

class SelectionChangedEvent extends $pb.GeneratedMessage {
  factory SelectionChangedEvent({
    $core.Iterable<CellRange>? oldRanges,
    $core.Iterable<CellRange>? newRanges,
    $core.int? activeRow,
    $core.int? activeCol,
  }) {
    final result = create();
    if (oldRanges != null) result.oldRanges.addAll(oldRanges);
    if (newRanges != null) result.newRanges.addAll(newRanges);
    if (activeRow != null) result.activeRow = activeRow;
    if (activeCol != null) result.activeCol = activeCol;
    return result;
  }

  SelectionChangedEvent._();

  factory SelectionChangedEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SelectionChangedEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SelectionChangedEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..pPM<CellRange>(1, _omitFieldNames ? '' : 'oldRanges',
        subBuilder: CellRange.create)
    ..pPM<CellRange>(2, _omitFieldNames ? '' : 'newRanges',
        subBuilder: CellRange.create)
    ..aI(3, _omitFieldNames ? '' : 'activeRow')
    ..aI(4, _omitFieldNames ? '' : 'activeCol')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SelectionChangedEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SelectionChangedEvent copyWith(
          void Function(SelectionChangedEvent) updates) =>
      super.copyWith((message) => updates(message as SelectionChangedEvent))
          as SelectionChangedEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SelectionChangedEvent create() => SelectionChangedEvent._();
  @$core.override
  SelectionChangedEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SelectionChangedEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SelectionChangedEvent>(create);
  static SelectionChangedEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<CellRange> get oldRanges => $_getList(0);

  @$pb.TagNumber(2)
  $pb.PbList<CellRange> get newRanges => $_getList(1);

  @$pb.TagNumber(3)
  $core.int get activeRow => $_getIZ(2);
  @$pb.TagNumber(3)
  set activeRow($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasActiveRow() => $_has(2);
  @$pb.TagNumber(3)
  void clearActiveRow() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get activeCol => $_getIZ(3);
  @$pb.TagNumber(4)
  set activeCol($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasActiveCol() => $_has(3);
  @$pb.TagNumber(4)
  void clearActiveCol() => $_clearField(4);
}

class EnterCellEvent extends $pb.GeneratedMessage {
  factory EnterCellEvent({
    $core.int? row,
    $core.int? col,
  }) {
    final result = create();
    if (row != null) result.row = row;
    if (col != null) result.col = col;
    return result;
  }

  EnterCellEvent._();

  factory EnterCellEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory EnterCellEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EnterCellEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'row')
    ..aI(2, _omitFieldNames ? '' : 'col')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EnterCellEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EnterCellEvent copyWith(void Function(EnterCellEvent) updates) =>
      super.copyWith((message) => updates(message as EnterCellEvent))
          as EnterCellEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EnterCellEvent create() => EnterCellEvent._();
  @$core.override
  EnterCellEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static EnterCellEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EnterCellEvent>(create);
  static EnterCellEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get row => $_getIZ(0);
  @$pb.TagNumber(1)
  set row($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRow() => $_has(0);
  @$pb.TagNumber(1)
  void clearRow() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get col => $_getIZ(1);
  @$pb.TagNumber(2)
  set col($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCol() => $_has(1);
  @$pb.TagNumber(2)
  void clearCol() => $_clearField(2);
}

class LeaveCellEvent extends $pb.GeneratedMessage {
  factory LeaveCellEvent({
    $core.int? row,
    $core.int? col,
  }) {
    final result = create();
    if (row != null) result.row = row;
    if (col != null) result.col = col;
    return result;
  }

  LeaveCellEvent._();

  factory LeaveCellEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory LeaveCellEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LeaveCellEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'row')
    ..aI(2, _omitFieldNames ? '' : 'col')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LeaveCellEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LeaveCellEvent copyWith(void Function(LeaveCellEvent) updates) =>
      super.copyWith((message) => updates(message as LeaveCellEvent))
          as LeaveCellEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LeaveCellEvent create() => LeaveCellEvent._();
  @$core.override
  LeaveCellEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static LeaveCellEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LeaveCellEvent>(create);
  static LeaveCellEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get row => $_getIZ(0);
  @$pb.TagNumber(1)
  set row($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRow() => $_has(0);
  @$pb.TagNumber(1)
  void clearRow() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get col => $_getIZ(1);
  @$pb.TagNumber(2)
  set col($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCol() => $_has(1);
  @$pb.TagNumber(2)
  void clearCol() => $_clearField(2);
}

/// ── Edit Events ──
class BeforeEditEvent extends $pb.GeneratedMessage {
  factory BeforeEditEvent({
    $core.int? row,
    $core.int? col,
  }) {
    final result = create();
    if (row != null) result.row = row;
    if (col != null) result.col = col;
    return result;
  }

  BeforeEditEvent._();

  factory BeforeEditEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BeforeEditEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BeforeEditEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'row')
    ..aI(2, _omitFieldNames ? '' : 'col')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BeforeEditEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BeforeEditEvent copyWith(void Function(BeforeEditEvent) updates) =>
      super.copyWith((message) => updates(message as BeforeEditEvent))
          as BeforeEditEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BeforeEditEvent create() => BeforeEditEvent._();
  @$core.override
  BeforeEditEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BeforeEditEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BeforeEditEvent>(create);
  static BeforeEditEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get row => $_getIZ(0);
  @$pb.TagNumber(1)
  set row($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRow() => $_has(0);
  @$pb.TagNumber(1)
  void clearRow() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get col => $_getIZ(1);
  @$pb.TagNumber(2)
  set col($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCol() => $_has(1);
  @$pb.TagNumber(2)
  void clearCol() => $_clearField(2);
}

class StartEditEvent extends $pb.GeneratedMessage {
  factory StartEditEvent({
    $core.int? row,
    $core.int? col,
  }) {
    final result = create();
    if (row != null) result.row = row;
    if (col != null) result.col = col;
    return result;
  }

  StartEditEvent._();

  factory StartEditEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StartEditEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StartEditEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'row')
    ..aI(2, _omitFieldNames ? '' : 'col')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StartEditEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StartEditEvent copyWith(void Function(StartEditEvent) updates) =>
      super.copyWith((message) => updates(message as StartEditEvent))
          as StartEditEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StartEditEvent create() => StartEditEvent._();
  @$core.override
  StartEditEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StartEditEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StartEditEvent>(create);
  static StartEditEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get row => $_getIZ(0);
  @$pb.TagNumber(1)
  set row($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRow() => $_has(0);
  @$pb.TagNumber(1)
  void clearRow() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get col => $_getIZ(1);
  @$pb.TagNumber(2)
  set col($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCol() => $_has(1);
  @$pb.TagNumber(2)
  void clearCol() => $_clearField(2);
}

class AfterEditEvent extends $pb.GeneratedMessage {
  factory AfterEditEvent({
    $core.int? row,
    $core.int? col,
    $core.String? oldText,
    $core.String? newText,
  }) {
    final result = create();
    if (row != null) result.row = row;
    if (col != null) result.col = col;
    if (oldText != null) result.oldText = oldText;
    if (newText != null) result.newText = newText;
    return result;
  }

  AfterEditEvent._();

  factory AfterEditEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AfterEditEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AfterEditEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'row')
    ..aI(2, _omitFieldNames ? '' : 'col')
    ..aOS(3, _omitFieldNames ? '' : 'oldText')
    ..aOS(4, _omitFieldNames ? '' : 'newText')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AfterEditEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AfterEditEvent copyWith(void Function(AfterEditEvent) updates) =>
      super.copyWith((message) => updates(message as AfterEditEvent))
          as AfterEditEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AfterEditEvent create() => AfterEditEvent._();
  @$core.override
  AfterEditEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AfterEditEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AfterEditEvent>(create);
  static AfterEditEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get row => $_getIZ(0);
  @$pb.TagNumber(1)
  set row($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRow() => $_has(0);
  @$pb.TagNumber(1)
  void clearRow() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get col => $_getIZ(1);
  @$pb.TagNumber(2)
  set col($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCol() => $_has(1);
  @$pb.TagNumber(2)
  void clearCol() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get oldText => $_getSZ(2);
  @$pb.TagNumber(3)
  set oldText($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasOldText() => $_has(2);
  @$pb.TagNumber(3)
  void clearOldText() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get newText => $_getSZ(3);
  @$pb.TagNumber(4)
  set newText($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasNewText() => $_has(3);
  @$pb.TagNumber(4)
  void clearNewText() => $_clearField(4);
}

class CellEditValidateEvent extends $pb.GeneratedMessage {
  factory CellEditValidateEvent({
    $core.int? row,
    $core.int? col,
    $core.String? editText,
  }) {
    final result = create();
    if (row != null) result.row = row;
    if (col != null) result.col = col;
    if (editText != null) result.editText = editText;
    return result;
  }

  CellEditValidateEvent._();

  factory CellEditValidateEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CellEditValidateEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CellEditValidateEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'row')
    ..aI(2, _omitFieldNames ? '' : 'col')
    ..aOS(3, _omitFieldNames ? '' : 'editText')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CellEditValidateEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CellEditValidateEvent copyWith(
          void Function(CellEditValidateEvent) updates) =>
      super.copyWith((message) => updates(message as CellEditValidateEvent))
          as CellEditValidateEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CellEditValidateEvent create() => CellEditValidateEvent._();
  @$core.override
  CellEditValidateEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CellEditValidateEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CellEditValidateEvent>(create);
  static CellEditValidateEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get row => $_getIZ(0);
  @$pb.TagNumber(1)
  set row($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRow() => $_has(0);
  @$pb.TagNumber(1)
  void clearRow() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get col => $_getIZ(1);
  @$pb.TagNumber(2)
  set col($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCol() => $_has(1);
  @$pb.TagNumber(2)
  void clearCol() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get editText => $_getSZ(2);
  @$pb.TagNumber(3)
  set editText($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasEditText() => $_has(2);
  @$pb.TagNumber(3)
  void clearEditText() => $_clearField(3);
}

class CellEditChangeEvent extends $pb.GeneratedMessage {
  factory CellEditChangeEvent({
    $core.String? text,
  }) {
    final result = create();
    if (text != null) result.text = text;
    return result;
  }

  CellEditChangeEvent._();

  factory CellEditChangeEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CellEditChangeEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CellEditChangeEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'text')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CellEditChangeEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CellEditChangeEvent copyWith(void Function(CellEditChangeEvent) updates) =>
      super.copyWith((message) => updates(message as CellEditChangeEvent))
          as CellEditChangeEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CellEditChangeEvent create() => CellEditChangeEvent._();
  @$core.override
  CellEditChangeEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CellEditChangeEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CellEditChangeEvent>(create);
  static CellEditChangeEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get text => $_getSZ(0);
  @$pb.TagNumber(1)
  set text($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasText() => $_has(0);
  @$pb.TagNumber(1)
  void clearText() => $_clearField(1);
}

class KeyDownEditEvent extends $pb.GeneratedMessage {
  factory KeyDownEditEvent({
    $core.int? keyCode,
    $core.int? modifier,
  }) {
    final result = create();
    if (keyCode != null) result.keyCode = keyCode;
    if (modifier != null) result.modifier = modifier;
    return result;
  }

  KeyDownEditEvent._();

  factory KeyDownEditEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory KeyDownEditEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'KeyDownEditEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'keyCode')
    ..aI(2, _omitFieldNames ? '' : 'modifier')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KeyDownEditEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KeyDownEditEvent copyWith(void Function(KeyDownEditEvent) updates) =>
      super.copyWith((message) => updates(message as KeyDownEditEvent))
          as KeyDownEditEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static KeyDownEditEvent create() => KeyDownEditEvent._();
  @$core.override
  KeyDownEditEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static KeyDownEditEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<KeyDownEditEvent>(create);
  static KeyDownEditEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get keyCode => $_getIZ(0);
  @$pb.TagNumber(1)
  set keyCode($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasKeyCode() => $_has(0);
  @$pb.TagNumber(1)
  void clearKeyCode() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get modifier => $_getIZ(1);
  @$pb.TagNumber(2)
  set modifier($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasModifier() => $_has(1);
  @$pb.TagNumber(2)
  void clearModifier() => $_clearField(2);
}

class KeyPressEditEvent extends $pb.GeneratedMessage {
  factory KeyPressEditEvent({
    $core.int? keyAscii,
  }) {
    final result = create();
    if (keyAscii != null) result.keyAscii = keyAscii;
    return result;
  }

  KeyPressEditEvent._();

  factory KeyPressEditEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory KeyPressEditEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'KeyPressEditEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'keyAscii')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KeyPressEditEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KeyPressEditEvent copyWith(void Function(KeyPressEditEvent) updates) =>
      super.copyWith((message) => updates(message as KeyPressEditEvent))
          as KeyPressEditEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static KeyPressEditEvent create() => KeyPressEditEvent._();
  @$core.override
  KeyPressEditEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static KeyPressEditEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<KeyPressEditEvent>(create);
  static KeyPressEditEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get keyAscii => $_getIZ(0);
  @$pb.TagNumber(1)
  set keyAscii($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasKeyAscii() => $_has(0);
  @$pb.TagNumber(1)
  void clearKeyAscii() => $_clearField(1);
}

class KeyUpEditEvent extends $pb.GeneratedMessage {
  factory KeyUpEditEvent({
    $core.int? keyCode,
    $core.int? modifier,
  }) {
    final result = create();
    if (keyCode != null) result.keyCode = keyCode;
    if (modifier != null) result.modifier = modifier;
    return result;
  }

  KeyUpEditEvent._();

  factory KeyUpEditEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory KeyUpEditEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'KeyUpEditEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'keyCode')
    ..aI(2, _omitFieldNames ? '' : 'modifier')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KeyUpEditEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KeyUpEditEvent copyWith(void Function(KeyUpEditEvent) updates) =>
      super.copyWith((message) => updates(message as KeyUpEditEvent))
          as KeyUpEditEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static KeyUpEditEvent create() => KeyUpEditEvent._();
  @$core.override
  KeyUpEditEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static KeyUpEditEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<KeyUpEditEvent>(create);
  static KeyUpEditEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get keyCode => $_getIZ(0);
  @$pb.TagNumber(1)
  set keyCode($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasKeyCode() => $_has(0);
  @$pb.TagNumber(1)
  void clearKeyCode() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get modifier => $_getIZ(1);
  @$pb.TagNumber(2)
  set modifier($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasModifier() => $_has(1);
  @$pb.TagNumber(2)
  void clearModifier() => $_clearField(2);
}

class CellEditConfigureStyleEvent extends $pb.GeneratedMessage {
  factory CellEditConfigureStyleEvent({
    $core.int? row,
    $core.int? col,
  }) {
    final result = create();
    if (row != null) result.row = row;
    if (col != null) result.col = col;
    return result;
  }

  CellEditConfigureStyleEvent._();

  factory CellEditConfigureStyleEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CellEditConfigureStyleEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CellEditConfigureStyleEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'row')
    ..aI(2, _omitFieldNames ? '' : 'col')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CellEditConfigureStyleEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CellEditConfigureStyleEvent copyWith(
          void Function(CellEditConfigureStyleEvent) updates) =>
      super.copyWith(
              (message) => updates(message as CellEditConfigureStyleEvent))
          as CellEditConfigureStyleEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CellEditConfigureStyleEvent create() =>
      CellEditConfigureStyleEvent._();
  @$core.override
  CellEditConfigureStyleEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CellEditConfigureStyleEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CellEditConfigureStyleEvent>(create);
  static CellEditConfigureStyleEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get row => $_getIZ(0);
  @$pb.TagNumber(1)
  set row($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRow() => $_has(0);
  @$pb.TagNumber(1)
  void clearRow() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get col => $_getIZ(1);
  @$pb.TagNumber(2)
  set col($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCol() => $_has(1);
  @$pb.TagNumber(2)
  void clearCol() => $_clearField(2);
}

class CellEditConfigureWindowEvent extends $pb.GeneratedMessage {
  factory CellEditConfigureWindowEvent({
    $core.int? row,
    $core.int? col,
  }) {
    final result = create();
    if (row != null) result.row = row;
    if (col != null) result.col = col;
    return result;
  }

  CellEditConfigureWindowEvent._();

  factory CellEditConfigureWindowEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CellEditConfigureWindowEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CellEditConfigureWindowEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'row')
    ..aI(2, _omitFieldNames ? '' : 'col')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CellEditConfigureWindowEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CellEditConfigureWindowEvent copyWith(
          void Function(CellEditConfigureWindowEvent) updates) =>
      super.copyWith(
              (message) => updates(message as CellEditConfigureWindowEvent))
          as CellEditConfigureWindowEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CellEditConfigureWindowEvent create() =>
      CellEditConfigureWindowEvent._();
  @$core.override
  CellEditConfigureWindowEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CellEditConfigureWindowEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CellEditConfigureWindowEvent>(create);
  static CellEditConfigureWindowEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get row => $_getIZ(0);
  @$pb.TagNumber(1)
  set row($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRow() => $_has(0);
  @$pb.TagNumber(1)
  void clearRow() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get col => $_getIZ(1);
  @$pb.TagNumber(2)
  set col($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCol() => $_has(1);
  @$pb.TagNumber(2)
  void clearCol() => $_clearField(2);
}

class DropdownClosedEvent extends $pb.GeneratedMessage {
  factory DropdownClosedEvent() => create();

  DropdownClosedEvent._();

  factory DropdownClosedEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DropdownClosedEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DropdownClosedEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DropdownClosedEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DropdownClosedEvent copyWith(void Function(DropdownClosedEvent) updates) =>
      super.copyWith((message) => updates(message as DropdownClosedEvent))
          as DropdownClosedEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DropdownClosedEvent create() => DropdownClosedEvent._();
  @$core.override
  DropdownClosedEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DropdownClosedEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DropdownClosedEvent>(create);
  static DropdownClosedEvent? _defaultInstance;
}

class DropdownOpenedEvent extends $pb.GeneratedMessage {
  factory DropdownOpenedEvent() => create();

  DropdownOpenedEvent._();

  factory DropdownOpenedEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DropdownOpenedEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DropdownOpenedEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DropdownOpenedEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DropdownOpenedEvent copyWith(void Function(DropdownOpenedEvent) updates) =>
      super.copyWith((message) => updates(message as DropdownOpenedEvent))
          as DropdownOpenedEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DropdownOpenedEvent create() => DropdownOpenedEvent._();
  @$core.override
  DropdownOpenedEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DropdownOpenedEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DropdownOpenedEvent>(create);
  static DropdownOpenedEvent? _defaultInstance;
}

/// ── Data Events ──
class CellChangedEvent extends $pb.GeneratedMessage {
  factory CellChangedEvent({
    $core.int? row,
    $core.int? col,
    $core.String? oldText,
    $core.String? newText,
  }) {
    final result = create();
    if (row != null) result.row = row;
    if (col != null) result.col = col;
    if (oldText != null) result.oldText = oldText;
    if (newText != null) result.newText = newText;
    return result;
  }

  CellChangedEvent._();

  factory CellChangedEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CellChangedEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CellChangedEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'row')
    ..aI(2, _omitFieldNames ? '' : 'col')
    ..aOS(3, _omitFieldNames ? '' : 'oldText')
    ..aOS(4, _omitFieldNames ? '' : 'newText')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CellChangedEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CellChangedEvent copyWith(void Function(CellChangedEvent) updates) =>
      super.copyWith((message) => updates(message as CellChangedEvent))
          as CellChangedEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CellChangedEvent create() => CellChangedEvent._();
  @$core.override
  CellChangedEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CellChangedEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CellChangedEvent>(create);
  static CellChangedEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get row => $_getIZ(0);
  @$pb.TagNumber(1)
  set row($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRow() => $_has(0);
  @$pb.TagNumber(1)
  void clearRow() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get col => $_getIZ(1);
  @$pb.TagNumber(2)
  set col($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCol() => $_has(1);
  @$pb.TagNumber(2)
  void clearCol() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get oldText => $_getSZ(2);
  @$pb.TagNumber(3)
  set oldText($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasOldText() => $_has(2);
  @$pb.TagNumber(3)
  void clearOldText() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get newText => $_getSZ(3);
  @$pb.TagNumber(4)
  set newText($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasNewText() => $_has(3);
  @$pb.TagNumber(4)
  void clearNewText() => $_clearField(4);
}

class RowStatusChangeEvent extends $pb.GeneratedMessage {
  factory RowStatusChangeEvent({
    $core.int? row,
    $core.int? status,
  }) {
    final result = create();
    if (row != null) result.row = row;
    if (status != null) result.status = status;
    return result;
  }

  RowStatusChangeEvent._();

  factory RowStatusChangeEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RowStatusChangeEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RowStatusChangeEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'row')
    ..aI(2, _omitFieldNames ? '' : 'status')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RowStatusChangeEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RowStatusChangeEvent copyWith(void Function(RowStatusChangeEvent) updates) =>
      super.copyWith((message) => updates(message as RowStatusChangeEvent))
          as RowStatusChangeEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RowStatusChangeEvent create() => RowStatusChangeEvent._();
  @$core.override
  RowStatusChangeEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RowStatusChangeEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RowStatusChangeEvent>(create);
  static RowStatusChangeEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get row => $_getIZ(0);
  @$pb.TagNumber(1)
  set row($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRow() => $_has(0);
  @$pb.TagNumber(1)
  void clearRow() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get status => $_getIZ(1);
  @$pb.TagNumber(2)
  set status($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasStatus() => $_has(1);
  @$pb.TagNumber(2)
  void clearStatus() => $_clearField(2);
}

/// ── Sort Events ──
class BeforeSortEvent extends $pb.GeneratedMessage {
  factory BeforeSortEvent({
    $core.int? col,
  }) {
    final result = create();
    if (col != null) result.col = col;
    return result;
  }

  BeforeSortEvent._();

  factory BeforeSortEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BeforeSortEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BeforeSortEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'col')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BeforeSortEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BeforeSortEvent copyWith(void Function(BeforeSortEvent) updates) =>
      super.copyWith((message) => updates(message as BeforeSortEvent))
          as BeforeSortEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BeforeSortEvent create() => BeforeSortEvent._();
  @$core.override
  BeforeSortEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BeforeSortEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BeforeSortEvent>(create);
  static BeforeSortEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get col => $_getIZ(0);
  @$pb.TagNumber(1)
  set col($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCol() => $_has(0);
  @$pb.TagNumber(1)
  void clearCol() => $_clearField(1);
}

class AfterSortEvent extends $pb.GeneratedMessage {
  factory AfterSortEvent({
    $core.int? col,
  }) {
    final result = create();
    if (col != null) result.col = col;
    return result;
  }

  AfterSortEvent._();

  factory AfterSortEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AfterSortEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AfterSortEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'col')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AfterSortEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AfterSortEvent copyWith(void Function(AfterSortEvent) updates) =>
      super.copyWith((message) => updates(message as AfterSortEvent))
          as AfterSortEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AfterSortEvent create() => AfterSortEvent._();
  @$core.override
  AfterSortEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AfterSortEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AfterSortEvent>(create);
  static AfterSortEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get col => $_getIZ(0);
  @$pb.TagNumber(1)
  set col($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCol() => $_has(0);
  @$pb.TagNumber(1)
  void clearCol() => $_clearField(1);
}

class CompareEvent extends $pb.GeneratedMessage {
  factory CompareEvent({
    $core.int? row1,
    $core.int? row2,
    $core.int? col,
    $core.int? result,
  }) {
    final result$ = create();
    if (row1 != null) result$.row1 = row1;
    if (row2 != null) result$.row2 = row2;
    if (col != null) result$.col = col;
    if (result != null) result$.result = result;
    return result$;
  }

  CompareEvent._();

  factory CompareEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CompareEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CompareEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'row1')
    ..aI(2, _omitFieldNames ? '' : 'row2')
    ..aI(3, _omitFieldNames ? '' : 'col')
    ..aI(4, _omitFieldNames ? '' : 'result')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CompareEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CompareEvent copyWith(void Function(CompareEvent) updates) =>
      super.copyWith((message) => updates(message as CompareEvent))
          as CompareEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CompareEvent create() => CompareEvent._();
  @$core.override
  CompareEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CompareEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CompareEvent>(create);
  static CompareEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get row1 => $_getIZ(0);
  @$pb.TagNumber(1)
  set row1($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRow1() => $_has(0);
  @$pb.TagNumber(1)
  void clearRow1() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get row2 => $_getIZ(1);
  @$pb.TagNumber(2)
  set row2($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRow2() => $_has(1);
  @$pb.TagNumber(2)
  void clearRow2() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get col => $_getIZ(2);
  @$pb.TagNumber(3)
  set col($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCol() => $_has(2);
  @$pb.TagNumber(3)
  void clearCol() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get result => $_getIZ(3);
  @$pb.TagNumber(4)
  set result($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasResult() => $_has(3);
  @$pb.TagNumber(4)
  void clearResult() => $_clearField(4);
}

/// ── Outline Events ──
class BeforeNodeToggleEvent extends $pb.GeneratedMessage {
  factory BeforeNodeToggleEvent({
    $core.int? row,
    $core.bool? collapse,
  }) {
    final result = create();
    if (row != null) result.row = row;
    if (collapse != null) result.collapse = collapse;
    return result;
  }

  BeforeNodeToggleEvent._();

  factory BeforeNodeToggleEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BeforeNodeToggleEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BeforeNodeToggleEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'row')
    ..aOB(2, _omitFieldNames ? '' : 'collapse')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BeforeNodeToggleEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BeforeNodeToggleEvent copyWith(
          void Function(BeforeNodeToggleEvent) updates) =>
      super.copyWith((message) => updates(message as BeforeNodeToggleEvent))
          as BeforeNodeToggleEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BeforeNodeToggleEvent create() => BeforeNodeToggleEvent._();
  @$core.override
  BeforeNodeToggleEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BeforeNodeToggleEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BeforeNodeToggleEvent>(create);
  static BeforeNodeToggleEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get row => $_getIZ(0);
  @$pb.TagNumber(1)
  set row($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRow() => $_has(0);
  @$pb.TagNumber(1)
  void clearRow() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get collapse => $_getBF(1);
  @$pb.TagNumber(2)
  set collapse($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCollapse() => $_has(1);
  @$pb.TagNumber(2)
  void clearCollapse() => $_clearField(2);
}

class AfterNodeToggleEvent extends $pb.GeneratedMessage {
  factory AfterNodeToggleEvent({
    $core.int? row,
    $core.bool? collapse,
  }) {
    final result = create();
    if (row != null) result.row = row;
    if (collapse != null) result.collapse = collapse;
    return result;
  }

  AfterNodeToggleEvent._();

  factory AfterNodeToggleEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AfterNodeToggleEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AfterNodeToggleEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'row')
    ..aOB(2, _omitFieldNames ? '' : 'collapse')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AfterNodeToggleEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AfterNodeToggleEvent copyWith(void Function(AfterNodeToggleEvent) updates) =>
      super.copyWith((message) => updates(message as AfterNodeToggleEvent))
          as AfterNodeToggleEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AfterNodeToggleEvent create() => AfterNodeToggleEvent._();
  @$core.override
  AfterNodeToggleEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AfterNodeToggleEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AfterNodeToggleEvent>(create);
  static AfterNodeToggleEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get row => $_getIZ(0);
  @$pb.TagNumber(1)
  set row($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRow() => $_has(0);
  @$pb.TagNumber(1)
  void clearRow() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get collapse => $_getBF(1);
  @$pb.TagNumber(2)
  set collapse($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCollapse() => $_has(1);
  @$pb.TagNumber(2)
  void clearCollapse() => $_clearField(2);
}

/// ── Scroll Events ──
class BeforeScrollEvent extends $pb.GeneratedMessage {
  factory BeforeScrollEvent({
    $core.int? oldTopRow,
    $core.int? oldLeftCol,
    $core.int? newTopRow,
    $core.int? newLeftCol,
  }) {
    final result = create();
    if (oldTopRow != null) result.oldTopRow = oldTopRow;
    if (oldLeftCol != null) result.oldLeftCol = oldLeftCol;
    if (newTopRow != null) result.newTopRow = newTopRow;
    if (newLeftCol != null) result.newLeftCol = newLeftCol;
    return result;
  }

  BeforeScrollEvent._();

  factory BeforeScrollEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BeforeScrollEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BeforeScrollEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'oldTopRow')
    ..aI(2, _omitFieldNames ? '' : 'oldLeftCol')
    ..aI(3, _omitFieldNames ? '' : 'newTopRow')
    ..aI(4, _omitFieldNames ? '' : 'newLeftCol')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BeforeScrollEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BeforeScrollEvent copyWith(void Function(BeforeScrollEvent) updates) =>
      super.copyWith((message) => updates(message as BeforeScrollEvent))
          as BeforeScrollEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BeforeScrollEvent create() => BeforeScrollEvent._();
  @$core.override
  BeforeScrollEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BeforeScrollEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BeforeScrollEvent>(create);
  static BeforeScrollEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get oldTopRow => $_getIZ(0);
  @$pb.TagNumber(1)
  set oldTopRow($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOldTopRow() => $_has(0);
  @$pb.TagNumber(1)
  void clearOldTopRow() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get oldLeftCol => $_getIZ(1);
  @$pb.TagNumber(2)
  set oldLeftCol($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasOldLeftCol() => $_has(1);
  @$pb.TagNumber(2)
  void clearOldLeftCol() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get newTopRow => $_getIZ(2);
  @$pb.TagNumber(3)
  set newTopRow($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasNewTopRow() => $_has(2);
  @$pb.TagNumber(3)
  void clearNewTopRow() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get newLeftCol => $_getIZ(3);
  @$pb.TagNumber(4)
  set newLeftCol($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasNewLeftCol() => $_has(3);
  @$pb.TagNumber(4)
  void clearNewLeftCol() => $_clearField(4);
}

class AfterScrollEvent extends $pb.GeneratedMessage {
  factory AfterScrollEvent({
    $core.int? oldTopRow,
    $core.int? oldLeftCol,
    $core.int? newTopRow,
    $core.int? newLeftCol,
  }) {
    final result = create();
    if (oldTopRow != null) result.oldTopRow = oldTopRow;
    if (oldLeftCol != null) result.oldLeftCol = oldLeftCol;
    if (newTopRow != null) result.newTopRow = newTopRow;
    if (newLeftCol != null) result.newLeftCol = newLeftCol;
    return result;
  }

  AfterScrollEvent._();

  factory AfterScrollEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AfterScrollEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AfterScrollEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'oldTopRow')
    ..aI(2, _omitFieldNames ? '' : 'oldLeftCol')
    ..aI(3, _omitFieldNames ? '' : 'newTopRow')
    ..aI(4, _omitFieldNames ? '' : 'newLeftCol')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AfterScrollEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AfterScrollEvent copyWith(void Function(AfterScrollEvent) updates) =>
      super.copyWith((message) => updates(message as AfterScrollEvent))
          as AfterScrollEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AfterScrollEvent create() => AfterScrollEvent._();
  @$core.override
  AfterScrollEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AfterScrollEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AfterScrollEvent>(create);
  static AfterScrollEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get oldTopRow => $_getIZ(0);
  @$pb.TagNumber(1)
  set oldTopRow($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOldTopRow() => $_has(0);
  @$pb.TagNumber(1)
  void clearOldTopRow() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get oldLeftCol => $_getIZ(1);
  @$pb.TagNumber(2)
  set oldLeftCol($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasOldLeftCol() => $_has(1);
  @$pb.TagNumber(2)
  void clearOldLeftCol() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get newTopRow => $_getIZ(2);
  @$pb.TagNumber(3)
  set newTopRow($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasNewTopRow() => $_has(2);
  @$pb.TagNumber(3)
  void clearNewTopRow() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get newLeftCol => $_getIZ(3);
  @$pb.TagNumber(4)
  set newLeftCol($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasNewLeftCol() => $_has(3);
  @$pb.TagNumber(4)
  void clearNewLeftCol() => $_clearField(4);
}

class ScrollTooltipEvent extends $pb.GeneratedMessage {
  factory ScrollTooltipEvent({
    $core.String? text,
  }) {
    final result = create();
    if (text != null) result.text = text;
    return result;
  }

  ScrollTooltipEvent._();

  factory ScrollTooltipEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ScrollTooltipEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ScrollTooltipEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'text')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ScrollTooltipEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ScrollTooltipEvent copyWith(void Function(ScrollTooltipEvent) updates) =>
      super.copyWith((message) => updates(message as ScrollTooltipEvent))
          as ScrollTooltipEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ScrollTooltipEvent create() => ScrollTooltipEvent._();
  @$core.override
  ScrollTooltipEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ScrollTooltipEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ScrollTooltipEvent>(create);
  static ScrollTooltipEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get text => $_getSZ(0);
  @$pb.TagNumber(1)
  set text($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasText() => $_has(0);
  @$pb.TagNumber(1)
  void clearText() => $_clearField(1);
}

/// ── Resize & Freeze Events ──
class BeforeUserResizeEvent extends $pb.GeneratedMessage {
  factory BeforeUserResizeEvent({
    $core.int? row,
    $core.int? col,
  }) {
    final result = create();
    if (row != null) result.row = row;
    if (col != null) result.col = col;
    return result;
  }

  BeforeUserResizeEvent._();

  factory BeforeUserResizeEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BeforeUserResizeEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BeforeUserResizeEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'row')
    ..aI(2, _omitFieldNames ? '' : 'col')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BeforeUserResizeEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BeforeUserResizeEvent copyWith(
          void Function(BeforeUserResizeEvent) updates) =>
      super.copyWith((message) => updates(message as BeforeUserResizeEvent))
          as BeforeUserResizeEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BeforeUserResizeEvent create() => BeforeUserResizeEvent._();
  @$core.override
  BeforeUserResizeEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BeforeUserResizeEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BeforeUserResizeEvent>(create);
  static BeforeUserResizeEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get row => $_getIZ(0);
  @$pb.TagNumber(1)
  set row($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRow() => $_has(0);
  @$pb.TagNumber(1)
  void clearRow() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get col => $_getIZ(1);
  @$pb.TagNumber(2)
  set col($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCol() => $_has(1);
  @$pb.TagNumber(2)
  void clearCol() => $_clearField(2);
}

class AfterUserResizeEvent extends $pb.GeneratedMessage {
  factory AfterUserResizeEvent({
    $core.int? row,
    $core.int? col,
  }) {
    final result = create();
    if (row != null) result.row = row;
    if (col != null) result.col = col;
    return result;
  }

  AfterUserResizeEvent._();

  factory AfterUserResizeEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AfterUserResizeEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AfterUserResizeEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'row')
    ..aI(2, _omitFieldNames ? '' : 'col')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AfterUserResizeEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AfterUserResizeEvent copyWith(void Function(AfterUserResizeEvent) updates) =>
      super.copyWith((message) => updates(message as AfterUserResizeEvent))
          as AfterUserResizeEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AfterUserResizeEvent create() => AfterUserResizeEvent._();
  @$core.override
  AfterUserResizeEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AfterUserResizeEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AfterUserResizeEvent>(create);
  static AfterUserResizeEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get row => $_getIZ(0);
  @$pb.TagNumber(1)
  set row($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRow() => $_has(0);
  @$pb.TagNumber(1)
  void clearRow() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get col => $_getIZ(1);
  @$pb.TagNumber(2)
  set col($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCol() => $_has(1);
  @$pb.TagNumber(2)
  void clearCol() => $_clearField(2);
}

class AfterUserFreezeEvent extends $pb.GeneratedMessage {
  factory AfterUserFreezeEvent({
    $core.int? frozenRows,
    $core.int? frozenCols,
  }) {
    final result = create();
    if (frozenRows != null) result.frozenRows = frozenRows;
    if (frozenCols != null) result.frozenCols = frozenCols;
    return result;
  }

  AfterUserFreezeEvent._();

  factory AfterUserFreezeEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AfterUserFreezeEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AfterUserFreezeEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'frozenRows')
    ..aI(2, _omitFieldNames ? '' : 'frozenCols')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AfterUserFreezeEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AfterUserFreezeEvent copyWith(void Function(AfterUserFreezeEvent) updates) =>
      super.copyWith((message) => updates(message as AfterUserFreezeEvent))
          as AfterUserFreezeEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AfterUserFreezeEvent create() => AfterUserFreezeEvent._();
  @$core.override
  AfterUserFreezeEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AfterUserFreezeEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AfterUserFreezeEvent>(create);
  static AfterUserFreezeEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get frozenRows => $_getIZ(0);
  @$pb.TagNumber(1)
  set frozenRows($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFrozenRows() => $_has(0);
  @$pb.TagNumber(1)
  void clearFrozenRows() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get frozenCols => $_getIZ(1);
  @$pb.TagNumber(2)
  set frozenCols($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFrozenCols() => $_has(1);
  @$pb.TagNumber(2)
  void clearFrozenCols() => $_clearField(2);
}

/// ── Move Events ──
class BeforeMoveColumnEvent extends $pb.GeneratedMessage {
  factory BeforeMoveColumnEvent({
    $core.int? col,
    $core.int? newPosition,
  }) {
    final result = create();
    if (col != null) result.col = col;
    if (newPosition != null) result.newPosition = newPosition;
    return result;
  }

  BeforeMoveColumnEvent._();

  factory BeforeMoveColumnEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BeforeMoveColumnEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BeforeMoveColumnEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'col')
    ..aI(2, _omitFieldNames ? '' : 'newPosition')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BeforeMoveColumnEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BeforeMoveColumnEvent copyWith(
          void Function(BeforeMoveColumnEvent) updates) =>
      super.copyWith((message) => updates(message as BeforeMoveColumnEvent))
          as BeforeMoveColumnEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BeforeMoveColumnEvent create() => BeforeMoveColumnEvent._();
  @$core.override
  BeforeMoveColumnEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BeforeMoveColumnEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BeforeMoveColumnEvent>(create);
  static BeforeMoveColumnEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get col => $_getIZ(0);
  @$pb.TagNumber(1)
  set col($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCol() => $_has(0);
  @$pb.TagNumber(1)
  void clearCol() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get newPosition => $_getIZ(1);
  @$pb.TagNumber(2)
  set newPosition($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasNewPosition() => $_has(1);
  @$pb.TagNumber(2)
  void clearNewPosition() => $_clearField(2);
}

class AfterMoveColumnEvent extends $pb.GeneratedMessage {
  factory AfterMoveColumnEvent({
    $core.int? col,
    $core.int? oldPosition,
  }) {
    final result = create();
    if (col != null) result.col = col;
    if (oldPosition != null) result.oldPosition = oldPosition;
    return result;
  }

  AfterMoveColumnEvent._();

  factory AfterMoveColumnEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AfterMoveColumnEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AfterMoveColumnEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'col')
    ..aI(2, _omitFieldNames ? '' : 'oldPosition')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AfterMoveColumnEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AfterMoveColumnEvent copyWith(void Function(AfterMoveColumnEvent) updates) =>
      super.copyWith((message) => updates(message as AfterMoveColumnEvent))
          as AfterMoveColumnEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AfterMoveColumnEvent create() => AfterMoveColumnEvent._();
  @$core.override
  AfterMoveColumnEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AfterMoveColumnEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AfterMoveColumnEvent>(create);
  static AfterMoveColumnEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get col => $_getIZ(0);
  @$pb.TagNumber(1)
  set col($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCol() => $_has(0);
  @$pb.TagNumber(1)
  void clearCol() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get oldPosition => $_getIZ(1);
  @$pb.TagNumber(2)
  set oldPosition($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasOldPosition() => $_has(1);
  @$pb.TagNumber(2)
  void clearOldPosition() => $_clearField(2);
}

class BeforeMoveRowEvent extends $pb.GeneratedMessage {
  factory BeforeMoveRowEvent({
    $core.int? row,
    $core.int? newPosition,
  }) {
    final result = create();
    if (row != null) result.row = row;
    if (newPosition != null) result.newPosition = newPosition;
    return result;
  }

  BeforeMoveRowEvent._();

  factory BeforeMoveRowEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BeforeMoveRowEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BeforeMoveRowEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'row')
    ..aI(2, _omitFieldNames ? '' : 'newPosition')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BeforeMoveRowEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BeforeMoveRowEvent copyWith(void Function(BeforeMoveRowEvent) updates) =>
      super.copyWith((message) => updates(message as BeforeMoveRowEvent))
          as BeforeMoveRowEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BeforeMoveRowEvent create() => BeforeMoveRowEvent._();
  @$core.override
  BeforeMoveRowEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BeforeMoveRowEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BeforeMoveRowEvent>(create);
  static BeforeMoveRowEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get row => $_getIZ(0);
  @$pb.TagNumber(1)
  set row($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRow() => $_has(0);
  @$pb.TagNumber(1)
  void clearRow() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get newPosition => $_getIZ(1);
  @$pb.TagNumber(2)
  set newPosition($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasNewPosition() => $_has(1);
  @$pb.TagNumber(2)
  void clearNewPosition() => $_clearField(2);
}

class AfterMoveRowEvent extends $pb.GeneratedMessage {
  factory AfterMoveRowEvent({
    $core.int? row,
    $core.int? oldPosition,
  }) {
    final result = create();
    if (row != null) result.row = row;
    if (oldPosition != null) result.oldPosition = oldPosition;
    return result;
  }

  AfterMoveRowEvent._();

  factory AfterMoveRowEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AfterMoveRowEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AfterMoveRowEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'row')
    ..aI(2, _omitFieldNames ? '' : 'oldPosition')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AfterMoveRowEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AfterMoveRowEvent copyWith(void Function(AfterMoveRowEvent) updates) =>
      super.copyWith((message) => updates(message as AfterMoveRowEvent))
          as AfterMoveRowEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AfterMoveRowEvent create() => AfterMoveRowEvent._();
  @$core.override
  AfterMoveRowEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AfterMoveRowEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AfterMoveRowEvent>(create);
  static AfterMoveRowEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get row => $_getIZ(0);
  @$pb.TagNumber(1)
  set row($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRow() => $_has(0);
  @$pb.TagNumber(1)
  void clearRow() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get oldPosition => $_getIZ(1);
  @$pb.TagNumber(2)
  set oldPosition($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasOldPosition() => $_has(1);
  @$pb.TagNumber(2)
  void clearOldPosition() => $_clearField(2);
}

/// ── Mouse Events ──
class BeforeMouseDownEvent extends $pb.GeneratedMessage {
  factory BeforeMouseDownEvent({
    $core.int? row,
    $core.int? col,
  }) {
    final result = create();
    if (row != null) result.row = row;
    if (col != null) result.col = col;
    return result;
  }

  BeforeMouseDownEvent._();

  factory BeforeMouseDownEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BeforeMouseDownEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BeforeMouseDownEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'row')
    ..aI(2, _omitFieldNames ? '' : 'col')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BeforeMouseDownEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BeforeMouseDownEvent copyWith(void Function(BeforeMouseDownEvent) updates) =>
      super.copyWith((message) => updates(message as BeforeMouseDownEvent))
          as BeforeMouseDownEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BeforeMouseDownEvent create() => BeforeMouseDownEvent._();
  @$core.override
  BeforeMouseDownEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BeforeMouseDownEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BeforeMouseDownEvent>(create);
  static BeforeMouseDownEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get row => $_getIZ(0);
  @$pb.TagNumber(1)
  set row($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRow() => $_has(0);
  @$pb.TagNumber(1)
  void clearRow() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get col => $_getIZ(1);
  @$pb.TagNumber(2)
  set col($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCol() => $_has(1);
  @$pb.TagNumber(2)
  void clearCol() => $_clearField(2);
}

class MouseDownEvent extends $pb.GeneratedMessage {
  factory MouseDownEvent({
    $core.int? button,
    $core.int? modifier,
    $core.double? x,
    $core.double? y,
  }) {
    final result = create();
    if (button != null) result.button = button;
    if (modifier != null) result.modifier = modifier;
    if (x != null) result.x = x;
    if (y != null) result.y = y;
    return result;
  }

  MouseDownEvent._();

  factory MouseDownEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MouseDownEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MouseDownEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'button')
    ..aI(2, _omitFieldNames ? '' : 'modifier')
    ..aD(3, _omitFieldNames ? '' : 'x', fieldType: $pb.PbFieldType.OF)
    ..aD(4, _omitFieldNames ? '' : 'y', fieldType: $pb.PbFieldType.OF)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MouseDownEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MouseDownEvent copyWith(void Function(MouseDownEvent) updates) =>
      super.copyWith((message) => updates(message as MouseDownEvent))
          as MouseDownEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MouseDownEvent create() => MouseDownEvent._();
  @$core.override
  MouseDownEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MouseDownEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MouseDownEvent>(create);
  static MouseDownEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get button => $_getIZ(0);
  @$pb.TagNumber(1)
  set button($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasButton() => $_has(0);
  @$pb.TagNumber(1)
  void clearButton() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get modifier => $_getIZ(1);
  @$pb.TagNumber(2)
  set modifier($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasModifier() => $_has(1);
  @$pb.TagNumber(2)
  void clearModifier() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get x => $_getN(2);
  @$pb.TagNumber(3)
  set x($core.double value) => $_setFloat(2, value);
  @$pb.TagNumber(3)
  $core.bool hasX() => $_has(2);
  @$pb.TagNumber(3)
  void clearX() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.double get y => $_getN(3);
  @$pb.TagNumber(4)
  set y($core.double value) => $_setFloat(3, value);
  @$pb.TagNumber(4)
  $core.bool hasY() => $_has(3);
  @$pb.TagNumber(4)
  void clearY() => $_clearField(4);
}

class MouseUpEvent extends $pb.GeneratedMessage {
  factory MouseUpEvent({
    $core.int? button,
    $core.int? modifier,
    $core.double? x,
    $core.double? y,
  }) {
    final result = create();
    if (button != null) result.button = button;
    if (modifier != null) result.modifier = modifier;
    if (x != null) result.x = x;
    if (y != null) result.y = y;
    return result;
  }

  MouseUpEvent._();

  factory MouseUpEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MouseUpEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MouseUpEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'button')
    ..aI(2, _omitFieldNames ? '' : 'modifier')
    ..aD(3, _omitFieldNames ? '' : 'x', fieldType: $pb.PbFieldType.OF)
    ..aD(4, _omitFieldNames ? '' : 'y', fieldType: $pb.PbFieldType.OF)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MouseUpEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MouseUpEvent copyWith(void Function(MouseUpEvent) updates) =>
      super.copyWith((message) => updates(message as MouseUpEvent))
          as MouseUpEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MouseUpEvent create() => MouseUpEvent._();
  @$core.override
  MouseUpEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MouseUpEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MouseUpEvent>(create);
  static MouseUpEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get button => $_getIZ(0);
  @$pb.TagNumber(1)
  set button($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasButton() => $_has(0);
  @$pb.TagNumber(1)
  void clearButton() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get modifier => $_getIZ(1);
  @$pb.TagNumber(2)
  set modifier($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasModifier() => $_has(1);
  @$pb.TagNumber(2)
  void clearModifier() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get x => $_getN(2);
  @$pb.TagNumber(3)
  set x($core.double value) => $_setFloat(2, value);
  @$pb.TagNumber(3)
  $core.bool hasX() => $_has(2);
  @$pb.TagNumber(3)
  void clearX() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.double get y => $_getN(3);
  @$pb.TagNumber(4)
  set y($core.double value) => $_setFloat(3, value);
  @$pb.TagNumber(4)
  $core.bool hasY() => $_has(3);
  @$pb.TagNumber(4)
  void clearY() => $_clearField(4);
}

class MouseMoveEvent extends $pb.GeneratedMessage {
  factory MouseMoveEvent({
    $core.int? button,
    $core.int? modifier,
    $core.double? x,
    $core.double? y,
  }) {
    final result = create();
    if (button != null) result.button = button;
    if (modifier != null) result.modifier = modifier;
    if (x != null) result.x = x;
    if (y != null) result.y = y;
    return result;
  }

  MouseMoveEvent._();

  factory MouseMoveEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MouseMoveEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MouseMoveEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'button')
    ..aI(2, _omitFieldNames ? '' : 'modifier')
    ..aD(3, _omitFieldNames ? '' : 'x', fieldType: $pb.PbFieldType.OF)
    ..aD(4, _omitFieldNames ? '' : 'y', fieldType: $pb.PbFieldType.OF)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MouseMoveEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MouseMoveEvent copyWith(void Function(MouseMoveEvent) updates) =>
      super.copyWith((message) => updates(message as MouseMoveEvent))
          as MouseMoveEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MouseMoveEvent create() => MouseMoveEvent._();
  @$core.override
  MouseMoveEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MouseMoveEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MouseMoveEvent>(create);
  static MouseMoveEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get button => $_getIZ(0);
  @$pb.TagNumber(1)
  set button($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasButton() => $_has(0);
  @$pb.TagNumber(1)
  void clearButton() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get modifier => $_getIZ(1);
  @$pb.TagNumber(2)
  set modifier($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasModifier() => $_has(1);
  @$pb.TagNumber(2)
  void clearModifier() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get x => $_getN(2);
  @$pb.TagNumber(3)
  set x($core.double value) => $_setFloat(2, value);
  @$pb.TagNumber(3)
  $core.bool hasX() => $_has(2);
  @$pb.TagNumber(3)
  void clearX() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.double get y => $_getN(3);
  @$pb.TagNumber(4)
  set y($core.double value) => $_setFloat(3, value);
  @$pb.TagNumber(4)
  $core.bool hasY() => $_has(3);
  @$pb.TagNumber(4)
  void clearY() => $_clearField(4);
}

class ClickEvent extends $pb.GeneratedMessage {
  factory ClickEvent({
    $core.int? row,
    $core.int? col,
    CellHitArea? hitArea,
    CellInteraction? interaction,
  }) {
    final result = create();
    if (row != null) result.row = row;
    if (col != null) result.col = col;
    if (hitArea != null) result.hitArea = hitArea;
    if (interaction != null) result.interaction = interaction;
    return result;
  }

  ClickEvent._();

  factory ClickEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ClickEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ClickEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'row')
    ..aI(2, _omitFieldNames ? '' : 'col')
    ..aE<CellHitArea>(3, _omitFieldNames ? '' : 'hitArea',
        enumValues: CellHitArea.values)
    ..aE<CellInteraction>(4, _omitFieldNames ? '' : 'interaction',
        enumValues: CellInteraction.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClickEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClickEvent copyWith(void Function(ClickEvent) updates) =>
      super.copyWith((message) => updates(message as ClickEvent)) as ClickEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ClickEvent create() => ClickEvent._();
  @$core.override
  ClickEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ClickEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClickEvent>(create);
  static ClickEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get row => $_getIZ(0);
  @$pb.TagNumber(1)
  set row($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRow() => $_has(0);
  @$pb.TagNumber(1)
  void clearRow() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get col => $_getIZ(1);
  @$pb.TagNumber(2)
  set col($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCol() => $_has(1);
  @$pb.TagNumber(2)
  void clearCol() => $_clearField(2);

  @$pb.TagNumber(3)
  CellHitArea get hitArea => $_getN(2);
  @$pb.TagNumber(3)
  set hitArea(CellHitArea value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasHitArea() => $_has(2);
  @$pb.TagNumber(3)
  void clearHitArea() => $_clearField(3);

  @$pb.TagNumber(4)
  CellInteraction get interaction => $_getN(3);
  @$pb.TagNumber(4)
  set interaction(CellInteraction value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasInteraction() => $_has(3);
  @$pb.TagNumber(4)
  void clearInteraction() => $_clearField(4);
}

class DblClickEvent extends $pb.GeneratedMessage {
  factory DblClickEvent({
    $core.int? row,
    $core.int? col,
  }) {
    final result = create();
    if (row != null) result.row = row;
    if (col != null) result.col = col;
    return result;
  }

  DblClickEvent._();

  factory DblClickEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DblClickEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DblClickEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'row')
    ..aI(2, _omitFieldNames ? '' : 'col')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DblClickEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DblClickEvent copyWith(void Function(DblClickEvent) updates) =>
      super.copyWith((message) => updates(message as DblClickEvent))
          as DblClickEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DblClickEvent create() => DblClickEvent._();
  @$core.override
  DblClickEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DblClickEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DblClickEvent>(create);
  static DblClickEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get row => $_getIZ(0);
  @$pb.TagNumber(1)
  set row($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRow() => $_has(0);
  @$pb.TagNumber(1)
  void clearRow() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get col => $_getIZ(1);
  @$pb.TagNumber(2)
  set col($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCol() => $_has(1);
  @$pb.TagNumber(2)
  void clearCol() => $_clearField(2);
}

/// ── Keyboard Events ──
class KeyDownEvent extends $pb.GeneratedMessage {
  factory KeyDownEvent({
    $core.int? keyCode,
    $core.int? modifier,
  }) {
    final result = create();
    if (keyCode != null) result.keyCode = keyCode;
    if (modifier != null) result.modifier = modifier;
    return result;
  }

  KeyDownEvent._();

  factory KeyDownEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory KeyDownEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'KeyDownEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'keyCode')
    ..aI(2, _omitFieldNames ? '' : 'modifier')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KeyDownEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KeyDownEvent copyWith(void Function(KeyDownEvent) updates) =>
      super.copyWith((message) => updates(message as KeyDownEvent))
          as KeyDownEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static KeyDownEvent create() => KeyDownEvent._();
  @$core.override
  KeyDownEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static KeyDownEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<KeyDownEvent>(create);
  static KeyDownEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get keyCode => $_getIZ(0);
  @$pb.TagNumber(1)
  set keyCode($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasKeyCode() => $_has(0);
  @$pb.TagNumber(1)
  void clearKeyCode() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get modifier => $_getIZ(1);
  @$pb.TagNumber(2)
  set modifier($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasModifier() => $_has(1);
  @$pb.TagNumber(2)
  void clearModifier() => $_clearField(2);
}

class KeyPressEvent extends $pb.GeneratedMessage {
  factory KeyPressEvent({
    $core.int? keyAscii,
  }) {
    final result = create();
    if (keyAscii != null) result.keyAscii = keyAscii;
    return result;
  }

  KeyPressEvent._();

  factory KeyPressEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory KeyPressEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'KeyPressEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'keyAscii')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KeyPressEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KeyPressEvent copyWith(void Function(KeyPressEvent) updates) =>
      super.copyWith((message) => updates(message as KeyPressEvent))
          as KeyPressEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static KeyPressEvent create() => KeyPressEvent._();
  @$core.override
  KeyPressEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static KeyPressEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<KeyPressEvent>(create);
  static KeyPressEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get keyAscii => $_getIZ(0);
  @$pb.TagNumber(1)
  set keyAscii($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasKeyAscii() => $_has(0);
  @$pb.TagNumber(1)
  void clearKeyAscii() => $_clearField(1);
}

class KeyUpEvent extends $pb.GeneratedMessage {
  factory KeyUpEvent({
    $core.int? keyCode,
    $core.int? modifier,
  }) {
    final result = create();
    if (keyCode != null) result.keyCode = keyCode;
    if (modifier != null) result.modifier = modifier;
    return result;
  }

  KeyUpEvent._();

  factory KeyUpEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory KeyUpEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'KeyUpEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'keyCode')
    ..aI(2, _omitFieldNames ? '' : 'modifier')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KeyUpEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KeyUpEvent copyWith(void Function(KeyUpEvent) updates) =>
      super.copyWith((message) => updates(message as KeyUpEvent)) as KeyUpEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static KeyUpEvent create() => KeyUpEvent._();
  @$core.override
  KeyUpEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static KeyUpEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<KeyUpEvent>(create);
  static KeyUpEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get keyCode => $_getIZ(0);
  @$pb.TagNumber(1)
  set keyCode($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasKeyCode() => $_has(0);
  @$pb.TagNumber(1)
  void clearKeyCode() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get modifier => $_getIZ(1);
  @$pb.TagNumber(2)
  set modifier($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasModifier() => $_has(1);
  @$pb.TagNumber(2)
  void clearModifier() => $_clearField(2);
}

/// ── Draw Events ──
class CustomRenderCellEvent extends $pb.GeneratedMessage {
  factory CustomRenderCellEvent({
    $core.int? row,
    $core.int? col,
    $core.double? x,
    $core.double? y,
    $core.double? width,
    $core.double? height,
    $core.String? text,
    CellStyle? style,
    $core.bool? done,
  }) {
    final result = create();
    if (row != null) result.row = row;
    if (col != null) result.col = col;
    if (x != null) result.x = x;
    if (y != null) result.y = y;
    if (width != null) result.width = width;
    if (height != null) result.height = height;
    if (text != null) result.text = text;
    if (style != null) result.style = style;
    if (done != null) result.done = done;
    return result;
  }

  CustomRenderCellEvent._();

  factory CustomRenderCellEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CustomRenderCellEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CustomRenderCellEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'row')
    ..aI(2, _omitFieldNames ? '' : 'col')
    ..aD(3, _omitFieldNames ? '' : 'x', fieldType: $pb.PbFieldType.OF)
    ..aD(4, _omitFieldNames ? '' : 'y', fieldType: $pb.PbFieldType.OF)
    ..aD(5, _omitFieldNames ? '' : 'width', fieldType: $pb.PbFieldType.OF)
    ..aD(6, _omitFieldNames ? '' : 'height', fieldType: $pb.PbFieldType.OF)
    ..aOS(7, _omitFieldNames ? '' : 'text')
    ..aOM<CellStyle>(8, _omitFieldNames ? '' : 'style',
        subBuilder: CellStyle.create)
    ..aOB(9, _omitFieldNames ? '' : 'done')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CustomRenderCellEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CustomRenderCellEvent copyWith(
          void Function(CustomRenderCellEvent) updates) =>
      super.copyWith((message) => updates(message as CustomRenderCellEvent))
          as CustomRenderCellEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CustomRenderCellEvent create() => CustomRenderCellEvent._();
  @$core.override
  CustomRenderCellEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CustomRenderCellEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CustomRenderCellEvent>(create);
  static CustomRenderCellEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get row => $_getIZ(0);
  @$pb.TagNumber(1)
  set row($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRow() => $_has(0);
  @$pb.TagNumber(1)
  void clearRow() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get col => $_getIZ(1);
  @$pb.TagNumber(2)
  set col($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCol() => $_has(1);
  @$pb.TagNumber(2)
  void clearCol() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get x => $_getN(2);
  @$pb.TagNumber(3)
  set x($core.double value) => $_setFloat(2, value);
  @$pb.TagNumber(3)
  $core.bool hasX() => $_has(2);
  @$pb.TagNumber(3)
  void clearX() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.double get y => $_getN(3);
  @$pb.TagNumber(4)
  set y($core.double value) => $_setFloat(3, value);
  @$pb.TagNumber(4)
  $core.bool hasY() => $_has(3);
  @$pb.TagNumber(4)
  void clearY() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.double get width => $_getN(4);
  @$pb.TagNumber(5)
  set width($core.double value) => $_setFloat(4, value);
  @$pb.TagNumber(5)
  $core.bool hasWidth() => $_has(4);
  @$pb.TagNumber(5)
  void clearWidth() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.double get height => $_getN(5);
  @$pb.TagNumber(6)
  set height($core.double value) => $_setFloat(5, value);
  @$pb.TagNumber(6)
  $core.bool hasHeight() => $_has(5);
  @$pb.TagNumber(6)
  void clearHeight() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get text => $_getSZ(6);
  @$pb.TagNumber(7)
  set text($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasText() => $_has(6);
  @$pb.TagNumber(7)
  void clearText() => $_clearField(7);

  @$pb.TagNumber(8)
  CellStyle get style => $_getN(7);
  @$pb.TagNumber(8)
  set style(CellStyle value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasStyle() => $_has(7);
  @$pb.TagNumber(8)
  void clearStyle() => $_clearField(8);
  @$pb.TagNumber(8)
  CellStyle ensureStyle() => $_ensure(7);

  @$pb.TagNumber(9)
  $core.bool get done => $_getBF(8);
  @$pb.TagNumber(9)
  set done($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasDone() => $_has(8);
  @$pb.TagNumber(9)
  void clearDone() => $_clearField(9);
}

/// ── Drag & Drop Events ──
class DragStartEvent extends $pb.GeneratedMessage {
  factory DragStartEvent({
    $core.int? row,
    $core.int? col,
  }) {
    final result = create();
    if (row != null) result.row = row;
    if (col != null) result.col = col;
    return result;
  }

  DragStartEvent._();

  factory DragStartEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DragStartEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DragStartEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'row')
    ..aI(2, _omitFieldNames ? '' : 'col')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DragStartEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DragStartEvent copyWith(void Function(DragStartEvent) updates) =>
      super.copyWith((message) => updates(message as DragStartEvent))
          as DragStartEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DragStartEvent create() => DragStartEvent._();
  @$core.override
  DragStartEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DragStartEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DragStartEvent>(create);
  static DragStartEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get row => $_getIZ(0);
  @$pb.TagNumber(1)
  set row($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRow() => $_has(0);
  @$pb.TagNumber(1)
  void clearRow() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get col => $_getIZ(1);
  @$pb.TagNumber(2)
  set col($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCol() => $_has(1);
  @$pb.TagNumber(2)
  void clearCol() => $_clearField(2);
}

class DragOverEvent extends $pb.GeneratedMessage {
  factory DragOverEvent({
    $core.int? row,
    $core.int? col,
    $core.double? x,
    $core.double? y,
  }) {
    final result = create();
    if (row != null) result.row = row;
    if (col != null) result.col = col;
    if (x != null) result.x = x;
    if (y != null) result.y = y;
    return result;
  }

  DragOverEvent._();

  factory DragOverEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DragOverEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DragOverEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'row')
    ..aI(2, _omitFieldNames ? '' : 'col')
    ..aD(3, _omitFieldNames ? '' : 'x', fieldType: $pb.PbFieldType.OF)
    ..aD(4, _omitFieldNames ? '' : 'y', fieldType: $pb.PbFieldType.OF)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DragOverEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DragOverEvent copyWith(void Function(DragOverEvent) updates) =>
      super.copyWith((message) => updates(message as DragOverEvent))
          as DragOverEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DragOverEvent create() => DragOverEvent._();
  @$core.override
  DragOverEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DragOverEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DragOverEvent>(create);
  static DragOverEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get row => $_getIZ(0);
  @$pb.TagNumber(1)
  set row($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRow() => $_has(0);
  @$pb.TagNumber(1)
  void clearRow() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get col => $_getIZ(1);
  @$pb.TagNumber(2)
  set col($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCol() => $_has(1);
  @$pb.TagNumber(2)
  void clearCol() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get x => $_getN(2);
  @$pb.TagNumber(3)
  set x($core.double value) => $_setFloat(2, value);
  @$pb.TagNumber(3)
  $core.bool hasX() => $_has(2);
  @$pb.TagNumber(3)
  void clearX() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.double get y => $_getN(3);
  @$pb.TagNumber(4)
  set y($core.double value) => $_setFloat(3, value);
  @$pb.TagNumber(4)
  $core.bool hasY() => $_has(3);
  @$pb.TagNumber(4)
  void clearY() => $_clearField(4);
}

class DragDropEvent extends $pb.GeneratedMessage {
  factory DragDropEvent({
    $core.int? row,
    $core.int? col,
  }) {
    final result = create();
    if (row != null) result.row = row;
    if (col != null) result.col = col;
    return result;
  }

  DragDropEvent._();

  factory DragDropEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DragDropEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DragDropEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'row')
    ..aI(2, _omitFieldNames ? '' : 'col')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DragDropEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DragDropEvent copyWith(void Function(DragDropEvent) updates) =>
      super.copyWith((message) => updates(message as DragDropEvent))
          as DragDropEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DragDropEvent create() => DragDropEvent._();
  @$core.override
  DragDropEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DragDropEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DragDropEvent>(create);
  static DragDropEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get row => $_getIZ(0);
  @$pb.TagNumber(1)
  set row($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRow() => $_has(0);
  @$pb.TagNumber(1)
  void clearRow() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get col => $_getIZ(1);
  @$pb.TagNumber(2)
  set col($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCol() => $_has(1);
  @$pb.TagNumber(2)
  void clearCol() => $_clearField(2);
}

class DragCompleteEvent extends $pb.GeneratedMessage {
  factory DragCompleteEvent({
    $core.bool? success,
  }) {
    final result = create();
    if (success != null) result.success = success;
    return result;
  }

  DragCompleteEvent._();

  factory DragCompleteEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DragCompleteEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DragCompleteEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DragCompleteEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DragCompleteEvent copyWith(void Function(DragCompleteEvent) updates) =>
      super.copyWith((message) => updates(message as DragCompleteEvent))
          as DragCompleteEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DragCompleteEvent create() => DragCompleteEvent._();
  @$core.override
  DragCompleteEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DragCompleteEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DragCompleteEvent>(create);
  static DragCompleteEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => $_clearField(1);
}

/// ── Search Events ──
class TypeAheadStartedEvent extends $pb.GeneratedMessage {
  factory TypeAheadStartedEvent({
    $core.int? col,
    $core.String? text,
  }) {
    final result = create();
    if (col != null) result.col = col;
    if (text != null) result.text = text;
    return result;
  }

  TypeAheadStartedEvent._();

  factory TypeAheadStartedEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TypeAheadStartedEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TypeAheadStartedEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'col')
    ..aOS(2, _omitFieldNames ? '' : 'text')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TypeAheadStartedEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TypeAheadStartedEvent copyWith(
          void Function(TypeAheadStartedEvent) updates) =>
      super.copyWith((message) => updates(message as TypeAheadStartedEvent))
          as TypeAheadStartedEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TypeAheadStartedEvent create() => TypeAheadStartedEvent._();
  @$core.override
  TypeAheadStartedEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TypeAheadStartedEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TypeAheadStartedEvent>(create);
  static TypeAheadStartedEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get col => $_getIZ(0);
  @$pb.TagNumber(1)
  set col($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCol() => $_has(0);
  @$pb.TagNumber(1)
  void clearCol() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get text => $_getSZ(1);
  @$pb.TagNumber(2)
  set text($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasText() => $_has(1);
  @$pb.TagNumber(2)
  void clearText() => $_clearField(2);
}

class TypeAheadEndedEvent extends $pb.GeneratedMessage {
  factory TypeAheadEndedEvent() => create();

  TypeAheadEndedEvent._();

  factory TypeAheadEndedEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TypeAheadEndedEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TypeAheadEndedEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TypeAheadEndedEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TypeAheadEndedEvent copyWith(void Function(TypeAheadEndedEvent) updates) =>
      super.copyWith((message) => updates(message as TypeAheadEndedEvent))
          as TypeAheadEndedEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TypeAheadEndedEvent create() => TypeAheadEndedEvent._();
  @$core.override
  TypeAheadEndedEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TypeAheadEndedEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TypeAheadEndedEvent>(create);
  static TypeAheadEndedEvent? _defaultInstance;
}

/// ── Data Refresh Events ──
class DataRefreshingEvent extends $pb.GeneratedMessage {
  factory DataRefreshingEvent() => create();

  DataRefreshingEvent._();

  factory DataRefreshingEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DataRefreshingEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DataRefreshingEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DataRefreshingEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DataRefreshingEvent copyWith(void Function(DataRefreshingEvent) updates) =>
      super.copyWith((message) => updates(message as DataRefreshingEvent))
          as DataRefreshingEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DataRefreshingEvent create() => DataRefreshingEvent._();
  @$core.override
  DataRefreshingEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DataRefreshingEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DataRefreshingEvent>(create);
  static DataRefreshingEvent? _defaultInstance;
}

class DataRefreshedEvent extends $pb.GeneratedMessage {
  factory DataRefreshedEvent() => create();

  DataRefreshedEvent._();

  factory DataRefreshedEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DataRefreshedEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DataRefreshedEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DataRefreshedEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DataRefreshedEvent copyWith(void Function(DataRefreshedEvent) updates) =>
      super.copyWith((message) => updates(message as DataRefreshedEvent))
          as DataRefreshedEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DataRefreshedEvent create() => DataRefreshedEvent._();
  @$core.override
  DataRefreshedEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DataRefreshedEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DataRefreshedEvent>(create);
  static DataRefreshedEvent? _defaultInstance;
}

class FilterDataEvent extends $pb.GeneratedMessage {
  factory FilterDataEvent({
    $core.int? row,
    $core.int? col,
    $core.String? text,
  }) {
    final result = create();
    if (row != null) result.row = row;
    if (col != null) result.col = col;
    if (text != null) result.text = text;
    return result;
  }

  FilterDataEvent._();

  factory FilterDataEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory FilterDataEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FilterDataEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'row')
    ..aI(2, _omitFieldNames ? '' : 'col')
    ..aOS(3, _omitFieldNames ? '' : 'text')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FilterDataEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FilterDataEvent copyWith(void Function(FilterDataEvent) updates) =>
      super.copyWith((message) => updates(message as FilterDataEvent))
          as FilterDataEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FilterDataEvent create() => FilterDataEvent._();
  @$core.override
  FilterDataEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static FilterDataEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FilterDataEvent>(create);
  static FilterDataEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get row => $_getIZ(0);
  @$pb.TagNumber(1)
  set row($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRow() => $_has(0);
  @$pb.TagNumber(1)
  void clearRow() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get col => $_getIZ(1);
  @$pb.TagNumber(2)
  set col($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCol() => $_has(1);
  @$pb.TagNumber(2)
  void clearCol() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get text => $_getSZ(2);
  @$pb.TagNumber(3)
  set text($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasText() => $_has(2);
  @$pb.TagNumber(3)
  void clearText() => $_clearField(3);
}

/// ── Pull to Refresh Events ──
class PullToRefreshTriggeredEvent extends $pb.GeneratedMessage {
  factory PullToRefreshTriggeredEvent() => create();

  PullToRefreshTriggeredEvent._();

  factory PullToRefreshTriggeredEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PullToRefreshTriggeredEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PullToRefreshTriggeredEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PullToRefreshTriggeredEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PullToRefreshTriggeredEvent copyWith(
          void Function(PullToRefreshTriggeredEvent) updates) =>
      super.copyWith(
              (message) => updates(message as PullToRefreshTriggeredEvent))
          as PullToRefreshTriggeredEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PullToRefreshTriggeredEvent create() =>
      PullToRefreshTriggeredEvent._();
  @$core.override
  PullToRefreshTriggeredEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PullToRefreshTriggeredEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PullToRefreshTriggeredEvent>(create);
  static PullToRefreshTriggeredEvent? _defaultInstance;
}

class PullToRefreshCanceledEvent extends $pb.GeneratedMessage {
  factory PullToRefreshCanceledEvent() => create();

  PullToRefreshCanceledEvent._();

  factory PullToRefreshCanceledEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PullToRefreshCanceledEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PullToRefreshCanceledEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PullToRefreshCanceledEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PullToRefreshCanceledEvent copyWith(
          void Function(PullToRefreshCanceledEvent) updates) =>
      super.copyWith(
              (message) => updates(message as PullToRefreshCanceledEvent))
          as PullToRefreshCanceledEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PullToRefreshCanceledEvent create() => PullToRefreshCanceledEvent._();
  @$core.override
  PullToRefreshCanceledEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PullToRefreshCanceledEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PullToRefreshCanceledEvent>(create);
  static PullToRefreshCanceledEvent? _defaultInstance;
}

/// ── Error Events ──
class ErrorEvent extends $pb.GeneratedMessage {
  factory ErrorEvent({
    $core.int? code,
    $core.String? message,
  }) {
    final result = create();
    if (code != null) result.code = code;
    if (message != null) result.message = message;
    return result;
  }

  ErrorEvent._();

  factory ErrorEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ErrorEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ErrorEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'code')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ErrorEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ErrorEvent copyWith(void Function(ErrorEvent) updates) =>
      super.copyWith((message) => updates(message as ErrorEvent)) as ErrorEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ErrorEvent create() => ErrorEvent._();
  @$core.override
  ErrorEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ErrorEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ErrorEvent>(create);
  static ErrorEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get code => $_getIZ(0);
  @$pb.TagNumber(1)
  set code($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCode() => $_has(0);
  @$pb.TagNumber(1)
  void clearCode() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => $_clearField(2);
}

/// ── Print Events ──
class BeforePageBreakEvent extends $pb.GeneratedMessage {
  factory BeforePageBreakEvent({
    $core.int? row,
  }) {
    final result = create();
    if (row != null) result.row = row;
    return result;
  }

  BeforePageBreakEvent._();

  factory BeforePageBreakEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BeforePageBreakEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BeforePageBreakEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'row')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BeforePageBreakEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BeforePageBreakEvent copyWith(void Function(BeforePageBreakEvent) updates) =>
      super.copyWith((message) => updates(message as BeforePageBreakEvent))
          as BeforePageBreakEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BeforePageBreakEvent create() => BeforePageBreakEvent._();
  @$core.override
  BeforePageBreakEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BeforePageBreakEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BeforePageBreakEvent>(create);
  static BeforePageBreakEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get row => $_getIZ(0);
  @$pb.TagNumber(1)
  set row($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRow() => $_has(0);
  @$pb.TagNumber(1)
  void clearRow() => $_clearField(1);
}

class StartPageEvent extends $pb.GeneratedMessage {
  factory StartPageEvent({
    $core.int? page,
  }) {
    final result = create();
    if (page != null) result.page = page;
    return result;
  }

  StartPageEvent._();

  factory StartPageEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StartPageEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StartPageEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'page')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StartPageEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StartPageEvent copyWith(void Function(StartPageEvent) updates) =>
      super.copyWith((message) => updates(message as StartPageEvent))
          as StartPageEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StartPageEvent create() => StartPageEvent._();
  @$core.override
  StartPageEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StartPageEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StartPageEvent>(create);
  static StartPageEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get page => $_getIZ(0);
  @$pb.TagNumber(1)
  set page($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPage() => $_has(0);
  @$pb.TagNumber(1)
  void clearPage() => $_clearField(1);
}

class GetHeaderRowEvent extends $pb.GeneratedMessage {
  factory GetHeaderRowEvent({
    $core.int? page,
  }) {
    final result = create();
    if (page != null) result.page = page;
    return result;
  }

  GetHeaderRowEvent._();

  factory GetHeaderRowEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetHeaderRowEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetHeaderRowEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'volvoxgrid.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'page')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetHeaderRowEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetHeaderRowEvent copyWith(void Function(GetHeaderRowEvent) updates) =>
      super.copyWith((message) => updates(message as GetHeaderRowEvent))
          as GetHeaderRowEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetHeaderRowEvent create() => GetHeaderRowEvent._();
  @$core.override
  GetHeaderRowEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetHeaderRowEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetHeaderRowEvent>(create);
  static GetHeaderRowEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get page => $_getIZ(0);
  @$pb.TagNumber(1)
  set page($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPage() => $_has(0);
  @$pb.TagNumber(1)
  void clearPage() => $_clearField(1);
}

class VolvoxGridServiceApi {
  final $pb.RpcClient _client;

  VolvoxGridServiceApi(this._client);

  /// ── Lifecycle ──
  $async.Future<CreateResponse> create_(
          $pb.ClientContext? ctx, CreateRequest request) =>
      _client.invoke<CreateResponse>(
          ctx, 'VolvoxGridService', 'Create', request, CreateResponse());
  $async.Future<Empty> destroy($pb.ClientContext? ctx, GridHandle request) =>
      _client.invoke<Empty>(
          ctx, 'VolvoxGridService', 'Destroy', request, Empty());

  /// ── Configuration ──
  $async.Future<Empty> configure(
          $pb.ClientContext? ctx, ConfigureRequest request) =>
      _client.invoke<Empty>(
          ctx, 'VolvoxGridService', 'Configure', request, Empty());
  $async.Future<GridConfig> getConfig(
          $pb.ClientContext? ctx, GridHandle request) =>
      _client.invoke<GridConfig>(
          ctx, 'VolvoxGridService', 'GetConfig', request, GridConfig());
  $async.Future<Empty> loadFontData(
          $pb.ClientContext? ctx, LoadFontDataRequest request) =>
      _client.invoke<Empty>(
          ctx, 'VolvoxGridService', 'LoadFontData', request, Empty());

  /// ── Structure ──
  $async.Future<Empty> defineColumns(
          $pb.ClientContext? ctx, DefineColumnsRequest request) =>
      _client.invoke<Empty>(
          ctx, 'VolvoxGridService', 'DefineColumns', request, Empty());
  $async.Future<DefineColumnsRequest> getSchema(
          $pb.ClientContext? ctx, GridHandle request) =>
      _client.invoke<DefineColumnsRequest>(ctx, 'VolvoxGridService',
          'GetSchema', request, DefineColumnsRequest());
  $async.Future<Empty> defineRows(
          $pb.ClientContext? ctx, DefineRowsRequest request) =>
      _client.invoke<Empty>(
          ctx, 'VolvoxGridService', 'DefineRows', request, Empty());
  $async.Future<Empty> insertRows(
          $pb.ClientContext? ctx, InsertRowsRequest request) =>
      _client.invoke<Empty>(
          ctx, 'VolvoxGridService', 'InsertRows', request, Empty());
  $async.Future<Empty> removeRows(
          $pb.ClientContext? ctx, RemoveRowsRequest request) =>
      _client.invoke<Empty>(
          ctx, 'VolvoxGridService', 'RemoveRows', request, Empty());
  $async.Future<Empty> moveColumn(
          $pb.ClientContext? ctx, MoveColumnRequest request) =>
      _client.invoke<Empty>(
          ctx, 'VolvoxGridService', 'MoveColumn', request, Empty());
  $async.Future<Empty> moveRow(
          $pb.ClientContext? ctx, MoveRowRequest request) =>
      _client.invoke<Empty>(
          ctx, 'VolvoxGridService', 'MoveRow', request, Empty());

  /// ── Data ──
  $async.Future<WriteResult> updateCells(
          $pb.ClientContext? ctx, UpdateCellsRequest request) =>
      _client.invoke<WriteResult>(
          ctx, 'VolvoxGridService', 'UpdateCells', request, WriteResult());
  $async.Future<CellsResponse> getCells(
          $pb.ClientContext? ctx, GetCellsRequest request) =>
      _client.invoke<CellsResponse>(
          ctx, 'VolvoxGridService', 'GetCells', request, CellsResponse());
  $async.Future<WriteResult> loadTable(
          $pb.ClientContext? ctx, LoadTableRequest request) =>
      _client.invoke<WriteResult>(
          ctx, 'VolvoxGridService', 'LoadTable', request, WriteResult());
  $async.Future<LoadDataResult> loadData(
          $pb.ClientContext? ctx, LoadDataRequest request) =>
      _client.invoke<LoadDataResult>(
          ctx, 'VolvoxGridService', 'LoadData', request, LoadDataResult());
  $async.Future<Empty> clear_($pb.ClientContext? ctx, ClearRequest request) =>
      _client.invoke<Empty>(
          ctx, 'VolvoxGridService', 'Clear', request, Empty());

  /// ── Selection ──
  $async.Future<Empty> select($pb.ClientContext? ctx, SelectRequest request) =>
      _client.invoke<Empty>(
          ctx, 'VolvoxGridService', 'Select', request, Empty());
  $async.Future<SelectionState> getSelection(
          $pb.ClientContext? ctx, GridHandle request) =>
      _client.invoke<SelectionState>(
          ctx, 'VolvoxGridService', 'GetSelection', request, SelectionState());
  $async.Future<Empty> showCell(
          $pb.ClientContext? ctx, ShowCellRequest request) =>
      _client.invoke<Empty>(
          ctx, 'VolvoxGridService', 'ShowCell', request, Empty());
  $async.Future<Empty> setTopRow(
          $pb.ClientContext? ctx, SetRowRequest request) =>
      _client.invoke<Empty>(
          ctx, 'VolvoxGridService', 'SetTopRow', request, Empty());
  $async.Future<Empty> setLeftCol(
          $pb.ClientContext? ctx, SetColRequest request) =>
      _client.invoke<Empty>(
          ctx, 'VolvoxGridService', 'SetLeftCol', request, Empty());

  /// ── Editing ──
  $async.Future<EditState> edit($pb.ClientContext? ctx, EditCommand request) =>
      _client.invoke<EditState>(
          ctx, 'VolvoxGridService', 'Edit', request, EditState());

  /// ── Actions ──
  $async.Future<Empty> sort($pb.ClientContext? ctx, SortRequest request) =>
      _client.invoke<Empty>(ctx, 'VolvoxGridService', 'Sort', request, Empty());
  $async.Future<SubtotalResult> subtotal(
          $pb.ClientContext? ctx, SubtotalRequest request) =>
      _client.invoke<SubtotalResult>(
          ctx, 'VolvoxGridService', 'Subtotal', request, SubtotalResult());
  $async.Future<Empty> autoSize(
          $pb.ClientContext? ctx, AutoSizeRequest request) =>
      _client.invoke<Empty>(
          ctx, 'VolvoxGridService', 'AutoSize', request, Empty());
  $async.Future<Empty> outline(
          $pb.ClientContext? ctx, OutlineRequest request) =>
      _client.invoke<Empty>(
          ctx, 'VolvoxGridService', 'Outline', request, Empty());
  $async.Future<NodeInfo> getNode(
          $pb.ClientContext? ctx, GetNodeRequest request) =>
      _client.invoke<NodeInfo>(
          ctx, 'VolvoxGridService', 'GetNode', request, NodeInfo());
  $async.Future<FindResponse> find(
          $pb.ClientContext? ctx, FindRequest request) =>
      _client.invoke<FindResponse>(
          ctx, 'VolvoxGridService', 'Find', request, FindResponse());
  $async.Future<AggregateResponse> aggregate(
          $pb.ClientContext? ctx, AggregateRequest request) =>
      _client.invoke<AggregateResponse>(
          ctx, 'VolvoxGridService', 'Aggregate', request, AggregateResponse());
  $async.Future<CellRange> getMergedRange(
          $pb.ClientContext? ctx, GetMergedRangeRequest request) =>
      _client.invoke<CellRange>(
          ctx, 'VolvoxGridService', 'GetMergedRange', request, CellRange());
  $async.Future<Empty> mergeCells(
          $pb.ClientContext? ctx, MergeCellsRequest request) =>
      _client.invoke<Empty>(
          ctx, 'VolvoxGridService', 'MergeCells', request, Empty());
  $async.Future<Empty> unmergeCells(
          $pb.ClientContext? ctx, UnmergeCellsRequest request) =>
      _client.invoke<Empty>(
          ctx, 'VolvoxGridService', 'UnmergeCells', request, Empty());
  $async.Future<MergedRegionsResponse> getMergedRegions(
          $pb.ClientContext? ctx, GridHandle request) =>
      _client.invoke<MergedRegionsResponse>(ctx, 'VolvoxGridService',
          'GetMergedRegions', request, MergedRegionsResponse());
  $async.Future<MemoryUsageResponse> getMemoryUsage(
          $pb.ClientContext? ctx, GridHandle request) =>
      _client.invoke<MemoryUsageResponse>(ctx, 'VolvoxGridService',
          'GetMemoryUsage', request, MemoryUsageResponse());

  /// ── Clipboard ──
  $async.Future<ClipboardResponse> clipboard(
          $pb.ClientContext? ctx, ClipboardCommand request) =>
      _client.invoke<ClipboardResponse>(
          ctx, 'VolvoxGridService', 'Clipboard', request, ClipboardResponse());

  /// ── Export / Print / Archive ──
  $async.Future<ExportResponse> export(
          $pb.ClientContext? ctx, ExportRequest request) =>
      _client.invoke<ExportResponse>(
          ctx, 'VolvoxGridService', 'Export', request, ExportResponse());
  $async.Future<PrintResponse> print(
          $pb.ClientContext? ctx, PrintRequest request) =>
      _client.invoke<PrintResponse>(
          ctx, 'VolvoxGridService', 'Print', request, PrintResponse());
  $async.Future<ArchiveResponse> archive(
          $pb.ClientContext? ctx, ArchiveRequest request) =>
      _client.invoke<ArchiveResponse>(
          ctx, 'VolvoxGridService', 'Archive', request, ArchiveResponse());

  /// ── Render Control ──
  $async.Future<Empty> resizeViewport(
          $pb.ClientContext? ctx, ResizeViewportRequest request) =>
      _client.invoke<Empty>(
          ctx, 'VolvoxGridService', 'ResizeViewport', request, Empty());
  $async.Future<Empty> setRedraw(
          $pb.ClientContext? ctx, SetRedrawRequest request) =>
      _client.invoke<Empty>(
          ctx, 'VolvoxGridService', 'SetRedraw', request, Empty());
  $async.Future<Empty> refresh($pb.ClientContext? ctx, GridHandle request) =>
      _client.invoke<Empty>(
          ctx, 'VolvoxGridService', 'Refresh', request, Empty());

  /// ── Demo ──
  $async.Future<Empty> loadDemo(
          $pb.ClientContext? ctx, LoadDemoRequest request) =>
      _client.invoke<Empty>(
          ctx, 'VolvoxGridService', 'LoadDemo', request, Empty());
  $async.Future<GetDemoDataResponse> getDemoData(
          $pb.ClientContext? ctx, GetDemoDataRequest request) =>
      _client.invoke<GetDemoDataResponse>(ctx, 'VolvoxGridService',
          'GetDemoData', request, GetDemoDataResponse());

  /// ── Streaming ──
  $async.Future<RenderOutput> renderSession(
          $pb.ClientContext? ctx, RenderInput request) =>
      _client.invoke<RenderOutput>(
          ctx, 'VolvoxGridService', 'RenderSession', request, RenderOutput());
  $async.Future<GridEvent> eventStream(
          $pb.ClientContext? ctx, GridHandle request) =>
      _client.invoke<GridEvent>(
          ctx, 'VolvoxGridService', 'EventStream', request, GridEvent());
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
