using System;
using System.Collections.Generic;
using VolvoxGrid.DotNet.Internal.ProtoLite;

namespace VolvoxGrid.DotNet.Internal
{
    internal sealed class ProtoLiteCodec : IProtoCodec
    {
        public byte[] EncodeCreateRequest(int viewportWidth, int viewportHeight, float scale)
        {
            var writer = new ProtoWriter();
            writer.WriteInt32(1, viewportWidth);
            writer.WriteInt32(2, viewportHeight);
            writer.WriteFloat(3, scale);
            return writer.ToArray();
        }

        public long DecodeGridHandle(byte[] payload)
        {
            var reader = new ProtoReader(payload);
            long id = 0;

            int field;
            ProtoWireType wire;
            while (reader.TryReadTag(out field, out wire))
            {
                if (field == 1 && wire == ProtoWireType.Varint)
                {
                    id = reader.ReadInt64();
                }
                else
                {
                    reader.SkipField(wire);
                }
            }

            return id;
        }

        public byte[] EncodeGridHandle(long gridId)
        {
            var writer = new ProtoWriter();
            writer.WriteInt64(1, gridId);
            return writer.ToArray();
        }

        public byte[] EncodeConfigureRequest(long gridId, VolvoxGridConfigData configData)
        {
            var configDataOrDefault = configData ?? new VolvoxGridConfigData();
            var writer = new ProtoWriter();
            writer.WriteInt64(1, gridId);
            writer.WriteMessage(2, cfg =>
            {
                if (configDataOrDefault.Layout != null)
                {
                    var layout = configDataOrDefault.Layout;
                    cfg.WriteMessage(1, l =>
                    {
                        if (layout.Rows.HasValue) l.WriteInt32(1, layout.Rows.Value);
                        if (layout.Cols.HasValue) l.WriteInt32(2, layout.Cols.Value);
                        if (layout.FixedRows.HasValue) l.WriteInt32(3, layout.FixedRows.Value);
                        if (layout.FixedCols.HasValue) l.WriteInt32(4, layout.FixedCols.Value);
                        if (layout.FrozenRows.HasValue) l.WriteInt32(5, layout.FrozenRows.Value);
                        if (layout.FrozenCols.HasValue) l.WriteInt32(6, layout.FrozenCols.Value);
                        if (layout.DefaultRowHeight.HasValue) l.WriteInt32(7, layout.DefaultRowHeight.Value);
                        if (layout.DefaultColWidth.HasValue) l.WriteInt32(8, layout.DefaultColWidth.Value);
                    });
                }

                if (configDataOrDefault.Selection != null)
                {
                    var sel = configDataOrDefault.Selection;
                    cfg.WriteMessage(3, s =>
                    {
                        if (sel.Mode.HasValue) s.WriteInt32(1, (int)sel.Mode.Value);
                        if (sel.SelectionVisibility.HasValue) s.WriteInt32(3, (int)sel.SelectionVisibility.Value);
                        if (sel.AllowSelection.HasValue) s.WriteBool(4, sel.AllowSelection.Value);
                        if (sel.HoverMode.HasValue) s.WriteInt32(7, (int)sel.HoverMode.Value);
                    });
                }

                if (configDataOrDefault.Editing != null)
                {
                    var edit = configDataOrDefault.Editing;
                    cfg.WriteMessage(4, e =>
                    {
                        if (edit.EditTrigger.HasValue) e.WriteInt32(1, (int)edit.EditTrigger.Value);
                    });
                }

                if (configDataOrDefault.Scrolling != null)
                {
                    var scroll = configDataOrDefault.Scrolling;
                    cfg.WriteMessage(5, s =>
                    {
                        if (scroll.Scrollbars.HasValue) s.WriteInt32(1, (int)scroll.Scrollbars.Value);
                        if (scroll.FlingEnabled.HasValue) s.WriteBool(4, scroll.FlingEnabled.Value);
                        if (scroll.FlingImpulseGain.HasValue) s.WriteFloat(5, scroll.FlingImpulseGain.Value);
                        if (scroll.FlingFriction.HasValue) s.WriteFloat(6, scroll.FlingFriction.Value);
                        if (scroll.FastScroll.HasValue) s.WriteBool(8, scroll.FastScroll.Value);
                    });
                }

                if (configDataOrDefault.Outline != null)
                {
                    var outline = configDataOrDefault.Outline;
                    cfg.WriteMessage(6, o =>
                    {
                        if (outline.TreeIndicator.HasValue) o.WriteInt32(1, (int)outline.TreeIndicator.Value);
                        if (outline.TreeColumn.HasValue) o.WriteInt32(2, outline.TreeColumn.Value);
                    });
                }

                if (configDataOrDefault.Span != null)
                {
                    var span = configDataOrDefault.Span;
                    cfg.WriteMessage(7, s =>
                    {
                        if (span.CellSpan.HasValue) s.WriteInt32(1, (int)span.CellSpan.Value);
                    });
                }

                if (configDataOrDefault.Interaction != null)
                {
                    var interaction = configDataOrDefault.Interaction;
                    cfg.WriteMessage(8, i =>
                    {
                        if (interaction.AllowUserResizing.HasValue) i.WriteInt32(1, (int)interaction.AllowUserResizing.Value);
                        if (interaction.HeaderFeatures.HasValue) i.WriteInt32(10, (int)interaction.HeaderFeatures.Value);
                    });
                }

                if (configDataOrDefault.Rendering != null)
                {
                    var rendering = configDataOrDefault.Rendering;
                    cfg.WriteMessage(9, r =>
                    {
                        if (rendering.RendererMode.HasValue) r.WriteInt32(1, ToProtoRendererMode(rendering.RendererMode.Value));
                        if (rendering.DebugOverlay.HasValue) r.WriteBool(2, rendering.DebugOverlay.Value);
                        if (rendering.AnimationEnabled.HasValue) r.WriteBool(3, rendering.AnimationEnabled.Value);
                        if (rendering.AnimationDurationMs.HasValue) r.WriteInt32(4, rendering.AnimationDurationMs.Value);
                        if (rendering.TextLayoutCacheCap.HasValue) r.WriteInt32(5, rendering.TextLayoutCacheCap.Value);
                    });
                }

                if (configDataOrDefault.IndicatorBands != null)
                {
                    var bands = configDataOrDefault.IndicatorBands;
                    cfg.WriteMessage(11, b =>
                    {
                        if (bands.RowIndicatorStart != null) b.WriteMessage(1, slot => EncodeRowIndicatorConfig(slot, bands.RowIndicatorStart));
                        if (bands.RowIndicatorEnd != null) b.WriteMessage(2, slot => EncodeRowIndicatorConfig(slot, bands.RowIndicatorEnd));
                        if (bands.ColIndicatorTop != null) b.WriteMessage(3, slot => EncodeColIndicatorConfig(slot, bands.ColIndicatorTop));
                        if (bands.ColIndicatorBottom != null) b.WriteMessage(4, slot => EncodeColIndicatorConfig(slot, bands.ColIndicatorBottom));
                        if (bands.CornerTopStart != null) b.WriteMessage(5, slot => EncodeCornerIndicatorConfig(slot, bands.CornerTopStart));
                        if (bands.CornerTopEnd != null) b.WriteMessage(6, slot => EncodeCornerIndicatorConfig(slot, bands.CornerTopEnd));
                        if (bands.CornerBottomStart != null) b.WriteMessage(7, slot => EncodeCornerIndicatorConfig(slot, bands.CornerBottomStart));
                        if (bands.CornerBottomEnd != null) b.WriteMessage(8, slot => EncodeCornerIndicatorConfig(slot, bands.CornerBottomEnd));
                    });
                }
            });

            return writer.ToArray();
        }

        public byte[] EncodeGetConfigRequest(long gridId)
        {
            return EncodeGridHandle(gridId);
        }

        public VolvoxGridConfigData DecodeGridConfig(byte[] payload)
        {
            var result = new VolvoxGridConfigData();
            var reader = new ProtoReader(payload);
            int field;
            ProtoWireType wire;
            while (reader.TryReadTag(out field, out wire))
            {
                if (wire != ProtoWireType.LengthDelimited)
                {
                    reader.SkipField(wire);
                    continue;
                }

                var bytes = reader.ReadLengthDelimited();
                switch (field)
                {
                    case 1:
                        DecodeLayoutConfig(result.Layout, bytes);
                        break;
                    case 3:
                        DecodeSelectionConfig(result.Selection, bytes);
                        break;
                    case 4:
                        DecodeEditConfig(result.Editing, bytes);
                        break;
                    case 5:
                        DecodeScrollConfig(result.Scrolling, bytes);
                        break;
                    case 6:
                        DecodeOutlineConfig(result.Outline, bytes);
                        break;
                    case 7:
                        DecodeSpanConfig(result.Span, bytes);
                        break;
                    case 8:
                        DecodeInteractionConfig(result.Interaction, bytes);
                        break;
                    case 9:
                        DecodeRenderConfig(result.Rendering, bytes);
                        break;
                    case 11:
                        DecodeIndicatorBandsConfig(result.IndicatorBands, bytes);
                        break;
                }
            }
            return result;
        }

        public byte[] EncodeConfigureRequest(
            long gridId,
            bool editable,
            bool multiSelect,
            bool debugOverlay,
            bool hoverEnabled,
            bool flingEnabled,
            VolvoxGridRendererMode rendererMode)
        {
            var config = new VolvoxGridConfigData();
            config.Selection.Mode = multiSelect ? VolvoxSelectionMode.Listbox : VolvoxSelectionMode.Free;
            config.Selection.SelectionVisibility = VolvoxSelectionVisibility.Always;
            config.Selection.AllowSelection = true;
            config.Selection.HoverMode = hoverEnabled ? (uint)7 : 0;
            config.Editing.EditTrigger = editable ? VolvoxEditTrigger.KeyClick : VolvoxEditTrigger.None;
            config.Scrolling.Scrollbars = VolvoxScrollBarsMode.Both;
            config.Scrolling.FlingEnabled = flingEnabled;
            config.Scrolling.FastScroll = true;
            config.Rendering.RendererMode = rendererMode;
            config.Rendering.DebugOverlay = debugOverlay;
            return EncodeConfigureRequest(gridId, config);
        }

        public byte[] EncodeConfigureFlingRequest(
            long gridId,
            bool flingEnabled,
            float? flingImpulseGain,
            float? flingFriction)
        {
            var writer = new ProtoWriter();
            writer.WriteInt64(1, gridId);
            writer.WriteMessage(2, config =>
            {
                config.WriteMessage(5, scrolling =>
                {
                    scrolling.WriteBool(4, flingEnabled); // fling_enabled
                    if (flingImpulseGain.HasValue)
                    {
                        scrolling.WriteFloat(5, flingImpulseGain.Value); // fling_impulse_gain
                    }

                    if (flingFriction.HasValue)
                    {
                        scrolling.WriteFloat(6, flingFriction.Value); // fling_friction
                    }
                });
            });

            return writer.ToArray();
        }

        public byte[] EncodeDefineColumnsRequest(long gridId, IList<VolvoxColumnDefinition> columns)
        {
            var writer = new ProtoWriter();
            writer.WriteInt64(1, gridId);

            if (columns != null)
            {
                for (int i = 0; i < columns.Count; i++)
                {
                    var column = columns[i];
                    if (column == null) continue;
                    writer.WriteMessage(2, c =>
                    {
                        c.WriteInt32(1, column.Index);
                        if (column.Width.HasValue) c.WriteInt32(2, column.Width.Value);
                        if (column.MinWidth.HasValue) c.WriteInt32(3, column.MinWidth.Value);
                        if (column.MaxWidth.HasValue) c.WriteInt32(4, column.MaxWidth.Value);
                        if (column.Caption != null) c.WriteString(5, column.Caption);
                        if (column.Alignment.HasValue) c.WriteInt32(6, (int)column.Alignment.Value);
                        if (column.FixedAlignment.HasValue) c.WriteInt32(7, (int)column.FixedAlignment.Value);
                        if (column.DataType.HasValue) c.WriteInt32(8, (int)column.DataType.Value);
                        if (column.Format != null) c.WriteString(9, column.Format);
                        if (column.Key != null) c.WriteString(10, column.Key);
                        if (column.SortOrder != VolvoxSortOrder.None) c.WriteInt32(11, ToProtoSort(column.SortOrder));
                        if (column.DropdownItems != null) c.WriteString(12, column.DropdownItems);
                        if (column.EditMask != null) c.WriteString(13, column.EditMask);
                        if (column.Indent.HasValue) c.WriteInt32(14, column.Indent.Value);
                        c.WriteBool(15, column.Hidden);
                        c.WriteBool(16, column.Span);
                        if (column.Sticky.HasValue) c.WriteInt32(19, (int)column.Sticky.Value);
                    });
                }
            }

            return writer.ToArray();
        }

        public byte[] EncodeDefineRowsRequest(long gridId, IList<VolvoxRowDefinition> rows)
        {
            var writer = new ProtoWriter();
            writer.WriteInt64(1, gridId);

            if (rows != null)
            {
                for (int i = 0; i < rows.Count; i++)
                {
                    var row = rows[i];
                    if (row == null) continue;
                    writer.WriteMessage(2, r =>
                    {
                        r.WriteInt32(1, row.Index);
                        if (row.Height.HasValue) r.WriteInt32(2, row.Height.Value);
                        r.WriteBool(3, row.Hidden);
                        r.WriteBool(4, row.IsSubtotal);
                        if (row.OutlineLevel.HasValue) r.WriteInt32(5, row.OutlineLevel.Value);
                        r.WriteBool(6, row.IsCollapsed);
                        r.WriteBool(9, row.Span);
                        if (row.Pin.HasValue) r.WriteInt32(10, (int)row.Pin.Value);
                        if (row.Sticky.HasValue) r.WriteInt32(11, (int)row.Sticky.Value);
                    });
                }
            }

            return writer.ToArray();
        }

        public byte[] EncodeInsertRowsRequest(long gridId, int index, int count, IList<string> text)
        {
            var writer = new ProtoWriter();
            writer.WriteInt64(1, gridId);
            writer.WriteInt32(2, index);
            writer.WriteInt32(3, count);
            if (text != null)
            {
                for (int i = 0; i < text.Count; i++)
                {
                    writer.WriteString(4, text[i] ?? string.Empty);
                }
            }

            return writer.ToArray();
        }

        public byte[] EncodeRemoveRowsRequest(long gridId, int index, int count)
        {
            var writer = new ProtoWriter();
            writer.WriteInt64(1, gridId);
            writer.WriteInt32(2, index);
            writer.WriteInt32(3, count);
            return writer.ToArray();
        }

        public byte[] EncodeMoveColumnRequest(long gridId, int col, int position)
        {
            var writer = new ProtoWriter();
            writer.WriteInt64(1, gridId);
            writer.WriteInt32(2, col);
            writer.WriteInt32(3, position);
            return writer.ToArray();
        }

        public byte[] EncodeMoveRowRequest(long gridId, int row, int position)
        {
            var writer = new ProtoWriter();
            writer.WriteInt64(1, gridId);
            writer.WriteInt32(2, row);
            writer.WriteInt32(3, position);
            return writer.ToArray();
        }

        public byte[] EncodeLoadTableRequest(long gridId, int rows, int cols, IList<VolvoxCellValueData> values, bool atomic)
        {
            var writer = new ProtoWriter();
            writer.WriteInt64(1, gridId);
            writer.WriteInt32(2, rows);
            writer.WriteInt32(3, cols);

            if (values != null)
            {
                for (int i = 0; i < values.Count; i++)
                {
                    writer.WriteMessageBytes(4, EncodeCellValue(values[i]));
                }
            }

            writer.WriteBool(5, atomic);
            return writer.ToArray();
        }

        public byte[] EncodeUpdateCellsRequest(long gridId, IList<VolvoxCellUpdateData> updates, bool atomic)
        {
            var writer = new ProtoWriter();
            writer.WriteInt64(1, gridId);
            if (updates != null)
            {
                for (int i = 0; i < updates.Count; i++)
                {
                    var update = updates[i];
                    if (update == null) continue;
                    writer.WriteMessage(2, cell =>
                    {
                        cell.WriteInt32(1, update.Row);
                        cell.WriteInt32(2, update.Col);
                        if (update.Value != null) cell.WriteMessageBytes(3, EncodeCellValue(update.Value));
                        if (update.Style != null) cell.WriteMessageBytes(4, EncodeCellStyle(update.Style));
                        if (update.Checked.HasValue) cell.WriteInt32(5, (int)update.Checked.Value);
                        if (update.DropdownItems != null) cell.WriteString(9, update.DropdownItems);
                    });
                }
            }

            writer.WriteBool(3, atomic);
            return writer.ToArray();
        }

        public byte[] EncodeGetCellsRequest(long gridId, int row1, int col1, int row2, int col2, bool includeStyle, bool includeChecked, bool includeTyped)
        {
            var writer = new ProtoWriter();
            writer.WriteInt64(1, gridId);
            writer.WriteInt32(2, row1);
            writer.WriteInt32(3, col1);
            writer.WriteInt32(4, row2);
            writer.WriteInt32(5, col2);
            writer.WriteBool(6, includeStyle);
            writer.WriteBool(7, includeChecked);
            writer.WriteBool(8, includeTyped);
            return writer.ToArray();
        }

        public List<VolvoxCellUpdateData> DecodeCellsResponse(byte[] payload)
        {
            var result = new List<VolvoxCellUpdateData>();
            var reader = new ProtoReader(payload);
            int field;
            ProtoWireType wire;
            while (reader.TryReadTag(out field, out wire))
            {
                if (field == 1 && wire == ProtoWireType.LengthDelimited)
                {
                    var cellBytes = reader.ReadLengthDelimited();
                    var cellReader = new ProtoReader(cellBytes);
                    var cell = new VolvoxCellUpdateData();

                    int cellField;
                    ProtoWireType cellWire;
                    while (cellReader.TryReadTag(out cellField, out cellWire))
                    {
                        switch (cellField)
                        {
                            case 1:
                                if (cellWire == ProtoWireType.Varint) cell.Row = cellReader.ReadInt32();
                                else cellReader.SkipField(cellWire);
                                break;
                            case 2:
                                if (cellWire == ProtoWireType.Varint) cell.Col = cellReader.ReadInt32();
                                else cellReader.SkipField(cellWire);
                                break;
                            case 3:
                                if (cellWire == ProtoWireType.LengthDelimited) cell.Value = DecodeCellValue(cellReader.ReadLengthDelimited());
                                else cellReader.SkipField(cellWire);
                                break;
                            case 4:
                                if (cellWire == ProtoWireType.LengthDelimited) cell.Style = DecodeCellStyle(cellReader.ReadLengthDelimited());
                                else cellReader.SkipField(cellWire);
                                break;
                            case 5:
                                if (cellWire == ProtoWireType.Varint) cell.Checked = (VolvoxCheckedState)cellReader.ReadInt32();
                                else cellReader.SkipField(cellWire);
                                break;
                            default:
                                cellReader.SkipField(cellWire);
                                break;
                        }
                    }

                    if (cell.Value == null)
                    {
                        cell.Value = new VolvoxCellValueData { Kind = VolvoxCellValueKind.Text, TextValue = string.Empty };
                    }

                    result.Add(cell);
                }
                else
                {
                    reader.SkipField(wire);
                }
            }

            return result;
        }

        public byte[] EncodeClearRequest(long gridId, VolvoxClearScope scope, VolvoxClearRegion region)
        {
            var writer = new ProtoWriter();
            writer.WriteInt64(1, gridId);
            writer.WriteInt32(2, (int)scope);
            writer.WriteInt32(3, (int)region);
            return writer.ToArray();
        }

        public byte[] EncodeSelectRequest(long gridId, int activeRow, int activeCol, IList<VolvoxCellRangeData> ranges, bool? show)
        {
            var writer = new ProtoWriter();
            writer.WriteInt64(1, gridId);
            writer.WriteInt32(2, activeRow);
            writer.WriteInt32(3, activeCol);

            if (ranges != null)
            {
                for (int i = 0; i < ranges.Count; i++)
                {
                    writer.WriteMessageBytes(4, EncodeRange(ranges[i]));
                }
            }

            if (show.HasValue)
            {
                writer.WriteBool(5, show.Value);
            }

            return writer.ToArray();
        }

        public byte[] EncodeClearSelectionRequest(long gridId)
        {
            var writer = new ProtoWriter();
            writer.WriteInt64(1, gridId);
            writer.WriteInt32(2, 3); // CLEAR_SELECTION
            writer.WriteInt32(3, 0); // CLEAR_SCROLLABLE
            return writer.ToArray();
        }

        public VolvoxSelectionStateData DecodeSelectionState(byte[] payload)
        {
            var result = new VolvoxSelectionStateData();
            var reader = new ProtoReader(payload);

            int field;
            ProtoWireType wire;
            while (reader.TryReadTag(out field, out wire))
            {
                switch (field)
                {
                    case 1:
                        if (wire == ProtoWireType.Varint)
                        {
                            result.ActiveRow = reader.ReadInt32();
                        }
                        else
                        {
                            reader.SkipField(wire);
                        }
                        break;
                    case 2:
                        if (wire == ProtoWireType.Varint)
                        {
                            result.ActiveCol = reader.ReadInt32();
                        }
                        else
                        {
                            reader.SkipField(wire);
                        }
                        break;
                    case 3:
                        if (wire == ProtoWireType.LengthDelimited)
                        {
                            var rangeBytes = reader.ReadLengthDelimited();
                            result.Ranges.Add(DecodeRange(rangeBytes));
                        }
                        else
                        {
                            reader.SkipField(wire);
                        }
                        break;
                    case 4:
                        if (wire == ProtoWireType.Varint)
                        {
                            result.TopRow = reader.ReadInt32();
                        }
                        else
                        {
                            reader.SkipField(wire);
                        }
                        break;
                    case 5:
                        if (wire == ProtoWireType.Varint)
                        {
                            result.LeftCol = reader.ReadInt32();
                        }
                        else
                        {
                            reader.SkipField(wire);
                        }
                        break;
                    case 6:
                        if (wire == ProtoWireType.Varint)
                        {
                            result.BottomRow = reader.ReadInt32();
                        }
                        else
                        {
                            reader.SkipField(wire);
                        }
                        break;
                    case 7:
                        if (wire == ProtoWireType.Varint)
                        {
                            result.RightCol = reader.ReadInt32();
                        }
                        else
                        {
                            reader.SkipField(wire);
                        }
                        break;
                    default:
                        reader.SkipField(wire);
                        break;
                }
            }

            return result;
        }

        public byte[] EncodeSortRequest(long gridId, IList<VolvoxSortColumn> sorts)
        {
            var writer = new ProtoWriter();
            writer.WriteInt64(1, gridId);

            if (sorts != null)
            {
                for (int i = 0; i < sorts.Count; i++)
                {
                    var sort = sorts[i];
                    if (sort == null) continue;
                    writer.WriteMessage(2, s =>
                    {
                        s.WriteInt32(1, sort.ColumnIndex);
                        s.WriteInt32(2, ToProtoSort(sort.SortOrder));
                    });
                }
            }

            return writer.ToArray();
        }

        public byte[] EncodeSubtotalRequest(long gridId, VolvoxAggregateType aggregate, int groupOnCol, int aggregateCol, string caption, uint backColor, uint foreColor, bool addOutline)
        {
            var writer = new ProtoWriter();
            writer.WriteInt64(1, gridId);
            writer.WriteInt32(2, (int)aggregate);
            writer.WriteInt32(3, groupOnCol);
            writer.WriteInt32(4, aggregateCol);
            writer.WriteString(5, caption ?? string.Empty);
            writer.WriteInt32(6, unchecked((int)backColor));
            writer.WriteInt32(7, unchecked((int)foreColor));
            writer.WriteBool(8, addOutline);
            return writer.ToArray();
        }

        public byte[] EncodeAutoSizeRequest(long gridId, int colFrom, int colTo, bool equal, int maxWidth)
        {
            var writer = new ProtoWriter();
            writer.WriteInt64(1, gridId);
            writer.WriteInt32(2, colFrom);
            writer.WriteInt32(3, colTo);
            writer.WriteBool(4, equal);
            writer.WriteInt32(5, maxWidth);
            return writer.ToArray();
        }

        public byte[] EncodeOutlineRequest(long gridId, int level)
        {
            var writer = new ProtoWriter();
            writer.WriteInt64(1, gridId);
            writer.WriteInt32(2, level);
            return writer.ToArray();
        }

        public byte[] EncodeGetNodeRequest(long gridId, int row, VolvoxNodeRelation? relation)
        {
            var writer = new ProtoWriter();
            writer.WriteInt64(1, gridId);
            writer.WriteInt32(2, row);
            if (relation.HasValue) writer.WriteInt32(3, (int)relation.Value);
            return writer.ToArray();
        }

        public VolvoxNodeInfoData DecodeNodeInfo(byte[] payload)
        {
            var info = new VolvoxNodeInfoData();
            var reader = new ProtoReader(payload);
            int field;
            ProtoWireType wire;
            while (reader.TryReadTag(out field, out wire))
            {
                switch (field)
                {
                    case 1:
                        if (wire == ProtoWireType.Varint) info.Row = reader.ReadInt32();
                        else reader.SkipField(wire);
                        break;
                    case 2:
                        if (wire == ProtoWireType.Varint) info.Level = reader.ReadInt32();
                        else reader.SkipField(wire);
                        break;
                    case 3:
                        if (wire == ProtoWireType.Varint) info.IsExpanded = reader.ReadBool();
                        else reader.SkipField(wire);
                        break;
                    case 4:
                        if (wire == ProtoWireType.Varint) info.ChildCount = reader.ReadInt32();
                        else reader.SkipField(wire);
                        break;
                    case 5:
                        if (wire == ProtoWireType.Varint) info.ParentRow = reader.ReadInt32();
                        else reader.SkipField(wire);
                        break;
                    default:
                        reader.SkipField(wire);
                        break;
                }
            }

            return info;
        }

        public byte[] EncodeFindRequest(long gridId, int col, int startRow, string text, bool caseSensitive, bool fullMatch, string regex)
        {
            var writer = new ProtoWriter();
            writer.WriteInt64(1, gridId);
            writer.WriteInt32(2, col);
            writer.WriteInt32(3, startRow);
            if (!string.IsNullOrEmpty(regex))
            {
                writer.WriteMessage(5, r => r.WriteString(1, regex));
            }
            else
            {
                writer.WriteMessage(4, t =>
                {
                    t.WriteString(1, text ?? string.Empty);
                    t.WriteBool(2, caseSensitive);
                    t.WriteBool(3, fullMatch);
                });
            }

            return writer.ToArray();
        }

        public int DecodeFindResponse(byte[] payload)
        {
            var reader = new ProtoReader(payload);
            int field;
            ProtoWireType wire;
            while (reader.TryReadTag(out field, out wire))
            {
                if (field == 1 && wire == ProtoWireType.Varint) return reader.ReadInt32();
                reader.SkipField(wire);
            }

            return -1;
        }

        public byte[] EncodeAggregateRequest(long gridId, VolvoxAggregateType aggregate, int row1, int col1, int row2, int col2)
        {
            var writer = new ProtoWriter();
            writer.WriteInt64(1, gridId);
            writer.WriteInt32(2, (int)aggregate);
            writer.WriteInt32(3, row1);
            writer.WriteInt32(4, col1);
            writer.WriteInt32(5, row2);
            writer.WriteInt32(6, col2);
            return writer.ToArray();
        }

        public double DecodeAggregateResponse(byte[] payload)
        {
            var reader = new ProtoReader(payload);
            int field;
            ProtoWireType wire;
            while (reader.TryReadTag(out field, out wire))
            {
                if (field == 1 && wire == ProtoWireType.Fixed64) return reader.ReadDouble();
                reader.SkipField(wire);
            }

            return 0d;
        }

        public byte[] EncodeGetMergedRangeRequest(long gridId, int row, int col)
        {
            var writer = new ProtoWriter();
            writer.WriteInt64(1, gridId);
            writer.WriteInt32(2, row);
            writer.WriteInt32(3, col);
            return writer.ToArray();
        }

        public VolvoxCellRangeData DecodeCellRange(byte[] payload)
        {
            return DecodeRange(payload);
        }

        public byte[] EncodeMergeCellsRequest(long gridId, VolvoxCellRangeData range)
        {
            var writer = new ProtoWriter();
            writer.WriteInt64(1, gridId);
            writer.WriteMessageBytes(2, EncodeRange(range));
            return writer.ToArray();
        }

        public byte[] EncodeUnmergeCellsRequest(long gridId, VolvoxCellRangeData range)
        {
            var writer = new ProtoWriter();
            writer.WriteInt64(1, gridId);
            writer.WriteMessageBytes(2, EncodeRange(range));
            return writer.ToArray();
        }

        public List<VolvoxCellRangeData> DecodeMergedRegionsResponse(byte[] payload)
        {
            var ranges = new List<VolvoxCellRangeData>();
            var reader = new ProtoReader(payload);
            int field;
            ProtoWireType wire;
            while (reader.TryReadTag(out field, out wire))
            {
                if (field == 1 && wire == ProtoWireType.LengthDelimited)
                {
                    ranges.Add(DecodeRange(reader.ReadLengthDelimited()));
                }
                else
                {
                    reader.SkipField(wire);
                }
            }

            return ranges;
        }

        public byte[] EncodeEditCommandStart(long gridId, int row, int col, bool? selectAll, bool? caretEnd, string seedText)
        {
            var writer = new ProtoWriter();
            writer.WriteInt64(1, gridId);
            writer.WriteMessage(2, start =>
            {
                start.WriteInt32(1, row);
                start.WriteInt32(2, col);
                if (selectAll.HasValue) start.WriteBool(3, selectAll.Value);
                if (caretEnd.HasValue) start.WriteBool(4, caretEnd.Value);
                if (seedText != null) start.WriteString(5, seedText);
            });
            return writer.ToArray();
        }

        public byte[] EncodeEditCommandCommit(long gridId, string text)
        {
            var writer = new ProtoWriter();
            writer.WriteInt64(1, gridId);
            writer.WriteMessage(3, commit =>
            {
                if (text != null) commit.WriteString(1, text);
            });
            return writer.ToArray();
        }

        public byte[] EncodeEditCommandCancel(long gridId)
        {
            var writer = new ProtoWriter();
            writer.WriteInt64(1, gridId);
            writer.WriteMessage(4, _ => { });
            return writer.ToArray();
        }

        public byte[] EncodeClipboardRequest(long gridId, string action, string pasteText)
        {
            var writer = new ProtoWriter();
            writer.WriteInt64(1, gridId);

            switch ((action ?? string.Empty).ToLowerInvariant())
            {
                case "copy":
                    writer.WriteMessage(2, _ => { });
                    break;
                case "cut":
                    writer.WriteMessage(3, _ => { });
                    break;
                case "paste":
                    writer.WriteMessage(4, paste => paste.WriteString(1, pasteText ?? string.Empty));
                    break;
                case "delete":
                    writer.WriteMessage(5, _ => { });
                    break;
            }

            return writer.ToArray();
        }

        public VolvoxClipboardResponseData DecodeClipboardResponse(byte[] payload)
        {
            var result = new VolvoxClipboardResponseData();
            var reader = new ProtoReader(payload);
            int field;
            ProtoWireType wire;
            while (reader.TryReadTag(out field, out wire))
            {
                switch (field)
                {
                    case 1:
                        if (wire == ProtoWireType.LengthDelimited) result.Text = reader.ReadString();
                        else reader.SkipField(wire);
                        break;
                    case 2:
                        if (wire == ProtoWireType.LengthDelimited) result.RichData = reader.ReadLengthDelimited();
                        else reader.SkipField(wire);
                        break;
                    default:
                        reader.SkipField(wire);
                        break;
                }
            }

            return result;
        }

        public byte[] EncodeExportRequest(long gridId, VolvoxExportFormat format, VolvoxExportScope scope)
        {
            var writer = new ProtoWriter();
            writer.WriteInt64(1, gridId);
            writer.WriteInt32(2, (int)format);
            writer.WriteInt32(3, (int)scope);
            return writer.ToArray();
        }

        public VolvoxExportResponseData DecodeExportResponse(byte[] payload)
        {
            var result = new VolvoxExportResponseData { Data = new byte[0], Format = VolvoxExportFormat.Binary };
            var reader = new ProtoReader(payload);
            int field;
            ProtoWireType wire;
            while (reader.TryReadTag(out field, out wire))
            {
                switch (field)
                {
                    case 1:
                        if (wire == ProtoWireType.LengthDelimited) result.Data = reader.ReadLengthDelimited();
                        else reader.SkipField(wire);
                        break;
                    case 2:
                        if (wire == ProtoWireType.Varint) result.Format = (VolvoxExportFormat)reader.ReadInt32();
                        else reader.SkipField(wire);
                        break;
                    default:
                        reader.SkipField(wire);
                        break;
                }
            }

            return result;
        }

        public byte[] EncodeImportRequest(long gridId, byte[] data, VolvoxExportFormat format, VolvoxExportScope scope)
        {
            var writer = new ProtoWriter();
            writer.WriteInt64(1, gridId);
            writer.WriteBytes(2, data ?? new byte[0]);
            writer.WriteInt32(3, (int)format);
            writer.WriteInt32(4, (int)scope);
            return writer.ToArray();
        }

        public byte[] EncodePrintRequest(long gridId, bool landscape, int marginL, int marginT, int marginR, int marginB, string header, string footer, bool showPageNumbers)
        {
            var writer = new ProtoWriter();
            writer.WriteInt64(1, gridId);
            writer.WriteInt32(2, landscape ? 1 : 0);
            writer.WriteInt32(3, marginL);
            writer.WriteInt32(4, marginT);
            writer.WriteInt32(5, marginR);
            writer.WriteInt32(6, marginB);
            writer.WriteString(7, header ?? string.Empty);
            writer.WriteString(8, footer ?? string.Empty);
            writer.WriteBool(9, showPageNumbers);
            return writer.ToArray();
        }

        public byte[] EncodeArchiveRequest(long gridId, VolvoxArchiveAction action, string name, byte[] data)
        {
            var writer = new ProtoWriter();
            writer.WriteInt64(1, gridId);
            writer.WriteString(2, name ?? string.Empty);
            writer.WriteInt32(3, (int)action);
            if (data != null) writer.WriteBytes(4, data);
            return writer.ToArray();
        }

        public VolvoxArchiveResponseData DecodeArchiveResponse(byte[] payload)
        {
            var result = new VolvoxArchiveResponseData();
            var reader = new ProtoReader(payload);
            int field;
            ProtoWireType wire;
            while (reader.TryReadTag(out field, out wire))
            {
                switch (field)
                {
                    case 1:
                        if (wire == ProtoWireType.LengthDelimited) result.Data = reader.ReadLengthDelimited();
                        else reader.SkipField(wire);
                        break;
                    case 2:
                        if (wire == ProtoWireType.LengthDelimited) result.Names.Add(reader.ReadString());
                        else reader.SkipField(wire);
                        break;
                    default:
                        reader.SkipField(wire);
                        break;
                }
            }

            return result;
        }

        public byte[] EncodeLoadDemoRequest(long gridId, string demo)
        {
            var writer = new ProtoWriter();
            writer.WriteInt64(1, gridId);
            writer.WriteString(2, demo ?? string.Empty);
            return writer.ToArray();
        }

        public byte[] EncodeSetRedrawRequest(long gridId, bool enabled)
        {
            var writer = new ProtoWriter();
            writer.WriteInt64(1, gridId);
            writer.WriteBool(2, enabled);
            return writer.ToArray();
        }

        public byte[] EncodeResizeViewportRequest(long gridId, int width, int height)
        {
            var writer = new ProtoWriter();
            writer.WriteInt64(1, gridId);
            writer.WriteInt32(2, width);
            writer.WriteInt32(3, height);
            return writer.ToArray();
        }

        public byte[] EncodeRenderInputBufferReady(long gridId, long handle, int stride, int width, int height)
        {
            var writer = new ProtoWriter();
            writer.WriteInt64(1, gridId);
            writer.WriteMessage(5, buffer =>
            {
                buffer.WriteInt64(1, handle);
                buffer.WriteInt32(2, stride);
                buffer.WriteInt32(3, width);
                buffer.WriteInt32(4, height);
            });
            return writer.ToArray();
        }

        public byte[] EncodeRenderInputPointer(long gridId, VolvoxPointerType type, float x, float y, int modifier, int button, bool dblClick)
        {
            var writer = new ProtoWriter();
            writer.WriteInt64(1, gridId);
            writer.WriteMessage(3, pointer =>
            {
                pointer.WriteInt32(1, (int)type);
                pointer.WriteFloat(2, x);
                pointer.WriteFloat(3, y);
                pointer.WriteInt32(4, modifier);
                pointer.WriteInt32(5, button);
                pointer.WriteBool(6, dblClick);
            });
            return writer.ToArray();
        }

        public byte[] EncodeRenderInputKey(long gridId, VolvoxKeyType type, int keyCode, int modifier, string character)
        {
            var writer = new ProtoWriter();
            writer.WriteInt64(1, gridId);
            writer.WriteMessage(4, key =>
            {
                key.WriteInt32(1, (int)type);
                key.WriteInt32(2, keyCode);
                key.WriteInt32(3, modifier);
                key.WriteString(4, character ?? string.Empty);
            });
            return writer.ToArray();
        }

        public byte[] EncodeRenderInputScroll(long gridId, float deltaX, float deltaY)
        {
            var writer = new ProtoWriter();
            writer.WriteInt64(1, gridId);
            writer.WriteMessage(6, scroll =>
            {
                scroll.WriteFloat(1, deltaX);
                scroll.WriteFloat(2, deltaY);
            });
            return writer.ToArray();
        }

        public byte[] EncodeRenderInputEventDecision(long gridId, long eventId, bool cancel)
        {
            var writer = new ProtoWriter();
            writer.WriteInt64(1, gridId);
            writer.WriteMessage(7, decision =>
            {
                decision.WriteInt64(1, gridId);
                decision.WriteInt64(2, eventId);
                decision.WriteBool(3, cancel);
            });
            return writer.ToArray();
        }

        public VolvoxRenderOutputData DecodeRenderOutput(byte[] payload)
        {
            try
            {
                return DecodeRenderOutputCore(payload);
            }
            catch (System.IO.InvalidDataException)
            {
                byte[] recovered;
                if (TryRecoverFramedPayload(payload, out recovered))
                {
                    return DecodeRenderOutputCore(recovered);
                }

                throw;
            }
        }

        private static VolvoxRenderOutputData DecodeRenderOutputCore(byte[] payload)
        {
            var result = new VolvoxRenderOutputData();
            var reader = new ProtoReader(payload);

            int field;
            ProtoWireType wire;
            while (reader.TryReadTag(out field, out wire))
            {
                switch (field)
                {
                    case 1:
                        if (wire == ProtoWireType.Varint)
                        {
                            result.Rendered = reader.ReadBool();
                        }
                        else
                        {
                            reader.SkipField(wire);
                        }
                        break;

                    case 2:
                        if (wire == ProtoWireType.LengthDelimited)
                        {
                            result.FrameDone = DecodeFrameDone(reader.ReadLengthDelimited());
                        }
                        else
                        {
                            reader.SkipField(wire);
                        }
                        break;

                    default:
                        reader.SkipField(wire);
                        break;
                }
            }

            return result;
        }

        public VolvoxGridEventData DecodeGridEvent(byte[] payload)
        {
            try
            {
                return DecodeGridEventCore(payload);
            }
            catch (System.IO.InvalidDataException)
            {
                byte[] recovered;
                if (TryRecoverFramedPayload(payload, out recovered))
                {
                    return DecodeGridEventCore(recovered);
                }

                throw;
            }
        }

        private static VolvoxGridEventData DecodeGridEventCore(byte[] payload)
        {
            var data = new VolvoxGridEventData { Kind = VolvoxGridEventKind.Unknown };
            var reader = new ProtoReader(payload);

            int field;
            ProtoWireType wire;
            while (reader.TryReadTag(out field, out wire))
            {
                switch (field)
                {
                    case 1:
                        if (wire == ProtoWireType.Varint)
                        {
                            data.GridId = reader.ReadInt64();
                        }
                        else
                        {
                            reader.SkipField(wire);
                        }
                        break;

                    case 100:
                        if (wire == ProtoWireType.Varint)
                        {
                            data.EventId = reader.ReadInt64();
                        }
                        else
                        {
                            reader.SkipField(wire);
                        }
                        break;

                    case 3:
                        if (wire == ProtoWireType.LengthDelimited)
                        {
                            DecodeCellFocusChanged(data, reader.ReadLengthDelimited());
                        }
                        else
                        {
                            reader.SkipField(wire);
                        }
                        break;

                    case 5:
                        if (wire == ProtoWireType.LengthDelimited)
                        {
                            DecodeSelectionChanged(data, reader.ReadLengthDelimited());
                        }
                        else
                        {
                            reader.SkipField(wire);
                        }
                        break;

                    case 21:
                        if (wire == ProtoWireType.LengthDelimited)
                        {
                            DecodeCellChanged(data, reader.ReadLengthDelimited());
                        }
                        else
                        {
                            reader.SkipField(wire);
                        }
                        break;

                    case 8:
                        if (wire == ProtoWireType.LengthDelimited)
                        {
                            DecodeBeforeEdit(data, reader.ReadLengthDelimited());
                        }
                        else
                        {
                            reader.SkipField(wire);
                        }
                        break;

                    case 11:
                        if (wire == ProtoWireType.LengthDelimited)
                        {
                            DecodeCellEditValidate(data, reader.ReadLengthDelimited());
                        }
                        else
                        {
                            reader.SkipField(wire);
                        }
                        break;

                    default:
                        reader.SkipField(wire);
                        break;
                }
            }

            return data;
        }

        private static void DecodeCellFocusChanged(VolvoxGridEventData data, byte[] payload)
        {
            data.Kind = VolvoxGridEventKind.CellFocusChanged;
            var reader = new ProtoReader(payload);
            int field;
            ProtoWireType wire;
            while (reader.TryReadTag(out field, out wire))
            {
                switch (field)
                {
                    case 1:
                        data.OldRow = reader.ReadInt32();
                        break;
                    case 2:
                        data.OldCol = reader.ReadInt32();
                        break;
                    case 3:
                        data.NewRow = reader.ReadInt32();
                        break;
                    case 4:
                        data.NewCol = reader.ReadInt32();
                        break;
                    default:
                        reader.SkipField(wire);
                        break;
                }
            }
        }

        private static void DecodeSelectionChanged(VolvoxGridEventData data, byte[] payload)
        {
            data.Kind = VolvoxGridEventKind.SelectionChanged;
            var reader = new ProtoReader(payload);
            int field;
            ProtoWireType wire;
            while (reader.TryReadTag(out field, out wire))
            {
                switch (field)
                {
                    case 3:
                        data.ActiveRow = reader.ReadInt32();
                        break;
                    case 4:
                        data.ActiveCol = reader.ReadInt32();
                        break;
                    default:
                        reader.SkipField(wire);
                        break;
                }
            }
        }

        private static void DecodeCellChanged(VolvoxGridEventData data, byte[] payload)
        {
            data.Kind = VolvoxGridEventKind.CellChanged;
            var reader = new ProtoReader(payload);
            int field;
            ProtoWireType wire;
            while (reader.TryReadTag(out field, out wire))
            {
                switch (field)
                {
                    case 1:
                        data.Row = reader.ReadInt32();
                        break;
                    case 2:
                        data.Col = reader.ReadInt32();
                        break;
                    case 3:
                        data.OldText = reader.ReadString();
                        break;
                    case 4:
                        data.NewText = reader.ReadString();
                        break;
                    default:
                        reader.SkipField(wire);
                        break;
                }
            }
        }

        private static void DecodeBeforeEdit(VolvoxGridEventData data, byte[] payload)
        {
            data.Kind = VolvoxGridEventKind.BeforeEdit;
            data.IsCancelable = true;
            var reader = new ProtoReader(payload);
            int field;
            ProtoWireType wire;
            while (reader.TryReadTag(out field, out wire))
            {
                switch (field)
                {
                    case 1:
                        data.Row = reader.ReadInt32();
                        break;
                    case 2:
                        data.Col = reader.ReadInt32();
                        break;
                    default:
                        reader.SkipField(wire);
                        break;
                }
            }
        }

        private static void DecodeCellEditValidate(VolvoxGridEventData data, byte[] payload)
        {
            data.Kind = VolvoxGridEventKind.CellEditValidate;
            data.IsCancelable = true;
            var reader = new ProtoReader(payload);
            int field;
            ProtoWireType wire;
            while (reader.TryReadTag(out field, out wire))
            {
                switch (field)
                {
                    case 1:
                        data.Row = reader.ReadInt32();
                        break;
                    case 2:
                        data.Col = reader.ReadInt32();
                        break;
                    case 3:
                        data.EditText = reader.ReadString();
                        break;
                    default:
                        reader.SkipField(wire);
                        break;
                }
            }
        }

        private static VolvoxFrameDoneData DecodeFrameDone(byte[] payload)
        {
            var data = new VolvoxFrameDoneData();
            var reader = new ProtoReader(payload);

            int field;
            ProtoWireType wire;
            while (reader.TryReadTag(out field, out wire))
            {
                switch (field)
                {
                    case 1:
                        if (wire == ProtoWireType.Varint)
                        {
                            data.Handle = reader.ReadInt64();
                        }
                        else
                        {
                            reader.SkipField(wire);
                        }
                        break;
                    case 2:
                        if (wire == ProtoWireType.Varint)
                        {
                            data.DirtyX = reader.ReadInt32();
                        }
                        else
                        {
                            reader.SkipField(wire);
                        }
                        break;
                    case 3:
                        if (wire == ProtoWireType.Varint)
                        {
                            data.DirtyY = reader.ReadInt32();
                        }
                        else
                        {
                            reader.SkipField(wire);
                        }
                        break;
                    case 4:
                        if (wire == ProtoWireType.Varint)
                        {
                            data.DirtyW = reader.ReadInt32();
                        }
                        else
                        {
                            reader.SkipField(wire);
                        }
                        break;
                    case 5:
                        if (wire == ProtoWireType.Varint)
                        {
                            data.DirtyH = reader.ReadInt32();
                        }
                        else
                        {
                            reader.SkipField(wire);
                        }
                        break;
                    default:
                        reader.SkipField(wire);
                        break;
                }
            }

            return data;
        }

        private static bool TryRecoverFramedPayload(byte[] payload, out byte[] recovered)
        {
            recovered = null;
            if (payload == null || payload.Length == 0)
            {
                return false;
            }

            // Some hosts prefix stream packets with a 1-byte status.
            if (payload.Length > 1 && payload[0] == 0)
            {
                recovered = new byte[payload.Length - 1];
                Buffer.BlockCopy(payload, 1, recovered, 0, recovered.Length);
                return true;
            }

            // gRPC envelope: 1-byte compressed flag + 4-byte big-endian length.
            if (payload.Length >= 5 && (payload[0] == 0 || payload[0] == 1))
            {
                int len =
                    (payload[1] << 24) |
                    (payload[2] << 16) |
                    (payload[3] << 8) |
                    payload[4];

                if (len > 0 && len <= payload.Length - 5)
                {
                    recovered = new byte[len];
                    Buffer.BlockCopy(payload, 5, recovered, 0, len);
                    return true;
                }
            }

            return false;
        }

        private static VolvoxCellRangeData DecodeRange(byte[] payload)
        {
            var range = new VolvoxCellRangeData();
            var reader = new ProtoReader(payload);

            int field;
            ProtoWireType wire;
            while (reader.TryReadTag(out field, out wire))
            {
                switch (field)
                {
                    case 1:
                        if (wire == ProtoWireType.Varint) range.Row1 = reader.ReadInt32();
                        else reader.SkipField(wire);
                        break;
                    case 2:
                        if (wire == ProtoWireType.Varint) range.Col1 = reader.ReadInt32();
                        else reader.SkipField(wire);
                        break;
                    case 3:
                        if (wire == ProtoWireType.Varint) range.Row2 = reader.ReadInt32();
                        else reader.SkipField(wire);
                        break;
                    case 4:
                        if (wire == ProtoWireType.Varint) range.Col2 = reader.ReadInt32();
                        else reader.SkipField(wire);
                        break;
                    default:
                        reader.SkipField(wire);
                        break;
                }
            }

            return range;
        }

        private static byte[] EncodeRange(VolvoxCellRangeData range)
        {
            var normalized = range ?? new VolvoxCellRangeData();
            var writer = new ProtoWriter();
            writer.WriteInt32(1, normalized.Row1);
            writer.WriteInt32(2, normalized.Col1);
            writer.WriteInt32(3, normalized.Row2);
            writer.WriteInt32(4, normalized.Col2);
            return writer.ToArray();
        }

        private static int ToProtoSort(VolvoxSortOrder order)
        {
            return (int)order;
        }

        private static int ToProtoRendererMode(VolvoxGridRendererMode mode)
        {
            switch (mode)
            {
                case VolvoxGridRendererMode.Cpu:
                    return 1;
                case VolvoxGridRendererMode.Gpu:
                    return 2;
                case VolvoxGridRendererMode.GpuVulkan:
                    return 3;
                case VolvoxGridRendererMode.GpuGles:
                    return 4;
                default:
                    return 0;
            }
        }

        private static VolvoxGridRendererMode FromProtoRendererMode(int mode)
        {
            switch (mode)
            {
                case 1:
                    return VolvoxGridRendererMode.Cpu;
                case 2:
                    return VolvoxGridRendererMode.Gpu;
                case 3:
                    return VolvoxGridRendererMode.GpuVulkan;
                case 4:
                    return VolvoxGridRendererMode.GpuGles;
                default:
                    return VolvoxGridRendererMode.Auto;
            }
        }

        private static void DecodeLayoutConfig(VolvoxLayoutConfigData layout, byte[] payload)
        {
            if (layout == null || payload == null) return;
            var reader = new ProtoReader(payload);
            int field;
            ProtoWireType wire;
            while (reader.TryReadTag(out field, out wire))
            {
                if (wire != ProtoWireType.Varint)
                {
                    reader.SkipField(wire);
                    continue;
                }

                switch (field)
                {
                    case 1: layout.Rows = reader.ReadInt32(); break;
                    case 2: layout.Cols = reader.ReadInt32(); break;
                    case 3: layout.FixedRows = reader.ReadInt32(); break;
                    case 4: layout.FixedCols = reader.ReadInt32(); break;
                    case 5: layout.FrozenRows = reader.ReadInt32(); break;
                    case 6: layout.FrozenCols = reader.ReadInt32(); break;
                    case 7: layout.DefaultRowHeight = reader.ReadInt32(); break;
                    case 8: layout.DefaultColWidth = reader.ReadInt32(); break;
                    default: reader.SkipField(wire); break;
                }
            }
        }

        private static void DecodeSelectionConfig(VolvoxSelectionConfigData selection, byte[] payload)
        {
            if (selection == null || payload == null) return;
            var reader = new ProtoReader(payload);
            int field;
            ProtoWireType wire;
            while (reader.TryReadTag(out field, out wire))
            {
                switch (field)
                {
                    case 1:
                        if (wire == ProtoWireType.Varint) selection.Mode = (VolvoxSelectionMode)reader.ReadInt32();
                        else reader.SkipField(wire);
                        break;
                    case 3:
                        if (wire == ProtoWireType.Varint) selection.SelectionVisibility = (VolvoxSelectionVisibility)reader.ReadInt32();
                        else reader.SkipField(wire);
                        break;
                    case 4:
                        if (wire == ProtoWireType.Varint) selection.AllowSelection = reader.ReadBool();
                        else reader.SkipField(wire);
                        break;
                    case 7:
                        if (wire == ProtoWireType.Varint) selection.HoverMode = unchecked((uint)reader.ReadInt32());
                        else reader.SkipField(wire);
                        break;
                    default:
                        reader.SkipField(wire);
                        break;
                }
            }
        }

        private static void DecodeEditConfig(VolvoxEditConfigData editing, byte[] payload)
        {
            if (editing == null || payload == null) return;
            var reader = new ProtoReader(payload);
            int field;
            ProtoWireType wire;
            while (reader.TryReadTag(out field, out wire))
            {
                if (field == 1 && wire == ProtoWireType.Varint) editing.EditTrigger = (VolvoxEditTrigger)reader.ReadInt32();
                else reader.SkipField(wire);
            }
        }

        private static void DecodeScrollConfig(VolvoxScrollConfigData scrolling, byte[] payload)
        {
            if (scrolling == null || payload == null) return;
            var reader = new ProtoReader(payload);
            int field;
            ProtoWireType wire;
            while (reader.TryReadTag(out field, out wire))
            {
                switch (field)
                {
                    case 1:
                        if (wire == ProtoWireType.Varint) scrolling.Scrollbars = (VolvoxScrollBarsMode)reader.ReadInt32();
                        else reader.SkipField(wire);
                        break;
                    case 4:
                        if (wire == ProtoWireType.Varint) scrolling.FlingEnabled = reader.ReadBool();
                        else reader.SkipField(wire);
                        break;
                    case 5:
                        if (wire == ProtoWireType.Fixed32) scrolling.FlingImpulseGain = reader.ReadFloat();
                        else reader.SkipField(wire);
                        break;
                    case 6:
                        if (wire == ProtoWireType.Fixed32) scrolling.FlingFriction = reader.ReadFloat();
                        else reader.SkipField(wire);
                        break;
                    case 8:
                        if (wire == ProtoWireType.Varint) scrolling.FastScroll = reader.ReadBool();
                        else reader.SkipField(wire);
                        break;
                    default:
                        reader.SkipField(wire);
                        break;
                }
            }
        }

        private static void DecodeOutlineConfig(VolvoxOutlineConfigData outline, byte[] payload)
        {
            if (outline == null || payload == null) return;
            var reader = new ProtoReader(payload);
            int field;
            ProtoWireType wire;
            while (reader.TryReadTag(out field, out wire))
            {
                switch (field)
                {
                    case 1:
                        if (wire == ProtoWireType.Varint) outline.TreeIndicator = (VolvoxTreeIndicatorStyle)reader.ReadInt32();
                        else reader.SkipField(wire);
                        break;
                    case 2:
                        if (wire == ProtoWireType.Varint) outline.TreeColumn = reader.ReadInt32();
                        else reader.SkipField(wire);
                        break;
                    default:
                        reader.SkipField(wire);
                        break;
                }
            }
        }

        private static void DecodeSpanConfig(VolvoxSpanConfigData span, byte[] payload)
        {
            if (span == null || payload == null) return;
            var reader = new ProtoReader(payload);
            int field;
            ProtoWireType wire;
            while (reader.TryReadTag(out field, out wire))
            {
                if (field == 1 && wire == ProtoWireType.Varint) span.CellSpan = (VolvoxCellSpanMode)reader.ReadInt32();
                else reader.SkipField(wire);
            }
        }

        private static void DecodeInteractionConfig(VolvoxInteractionConfigData interaction, byte[] payload)
        {
            if (interaction == null || payload == null) return;
            var reader = new ProtoReader(payload);
            int field;
            ProtoWireType wire;
            while (reader.TryReadTag(out field, out wire))
            {
                switch (field)
                {
                    case 1:
                        if (wire == ProtoWireType.Varint) interaction.AllowUserResizing = (VolvoxAllowUserResizingMode)reader.ReadInt32();
                        else reader.SkipField(wire);
                        break;
                    case 10:
                        if (wire == ProtoWireType.Varint) interaction.HeaderFeatures = (VolvoxHeaderFeatures)reader.ReadInt32();
                        else reader.SkipField(wire);
                        break;
                    default:
                        reader.SkipField(wire);
                        break;
                }
            }
        }

        private static void DecodeRenderConfig(VolvoxRenderConfigData rendering, byte[] payload)
        {
            if (rendering == null || payload == null) return;
            var reader = new ProtoReader(payload);
            int field;
            ProtoWireType wire;
            while (reader.TryReadTag(out field, out wire))
            {
                switch (field)
                {
                    case 1:
                        if (wire == ProtoWireType.Varint) rendering.RendererMode = FromProtoRendererMode(reader.ReadInt32());
                        else reader.SkipField(wire);
                        break;
                    case 2:
                        if (wire == ProtoWireType.Varint) rendering.DebugOverlay = reader.ReadBool();
                        else reader.SkipField(wire);
                        break;
                    case 3:
                        if (wire == ProtoWireType.Varint) rendering.AnimationEnabled = reader.ReadBool();
                        else reader.SkipField(wire);
                        break;
                    case 4:
                        if (wire == ProtoWireType.Varint) rendering.AnimationDurationMs = reader.ReadInt32();
                        else reader.SkipField(wire);
                        break;
                    case 5:
                        if (wire == ProtoWireType.Varint) rendering.TextLayoutCacheCap = reader.ReadInt32();
                        else reader.SkipField(wire);
                        break;
                    default:
                        reader.SkipField(wire);
                        break;
                }
            }
        }

        private static void EncodeRowIndicatorConfig(ProtoWriter writer, VolvoxRowIndicatorConfigData data)
        {
            if (data.Visible.HasValue) writer.WriteBool(1, data.Visible.Value);
            if (data.WidthPx.HasValue) writer.WriteInt32(2, data.WidthPx.Value);
            if (data.ModeBits.HasValue) writer.WriteInt32(3, (int)data.ModeBits.Value);
            if (data.BackColor.HasValue) writer.WriteInt32(4, unchecked((int)data.BackColor.Value));
            if (data.ForeColor.HasValue) writer.WriteInt32(5, unchecked((int)data.ForeColor.Value));
            if (data.GridLines.HasValue) writer.WriteInt32(6, data.GridLines.Value);
            if (data.GridColor.HasValue) writer.WriteInt32(7, unchecked((int)data.GridColor.Value));
            if (data.AutoSize.HasValue) writer.WriteBool(8, data.AutoSize.Value);
            if (data.AllowResize.HasValue) writer.WriteBool(9, data.AllowResize.Value);
            if (data.AllowSelect.HasValue) writer.WriteBool(10, data.AllowSelect.Value);
            if (data.AllowReorder.HasValue) writer.WriteBool(11, data.AllowReorder.Value);
            foreach (var slot in data.Slots)
            {
                if (slot == null) continue;
                writer.WriteMessage(12, s =>
                {
                    if (slot.Kind.HasValue) s.WriteInt32(1, (int)slot.Kind.Value);
                    if (slot.WidthPx.HasValue) s.WriteInt32(2, slot.WidthPx.Value);
                    if (slot.Visible.HasValue) s.WriteBool(3, slot.Visible.Value);
                    if (slot.CustomKey != null) s.WriteString(4, slot.CustomKey);
                    if (slot.Data != null) s.WriteBytes(5, slot.Data);
                });
            }
        }

        private static void EncodeColIndicatorConfig(ProtoWriter writer, VolvoxColIndicatorConfigData data)
        {
            if (data.Visible.HasValue) writer.WriteBool(1, data.Visible.Value);
            if (data.DefaultRowHeightPx.HasValue) writer.WriteInt32(2, data.DefaultRowHeightPx.Value);
            if (data.BandRows.HasValue) writer.WriteInt32(3, data.BandRows.Value);
            if (data.ModeBits.HasValue) writer.WriteInt32(4, (int)data.ModeBits.Value);
            if (data.BackColor.HasValue) writer.WriteInt32(5, unchecked((int)data.BackColor.Value));
            if (data.ForeColor.HasValue) writer.WriteInt32(6, unchecked((int)data.ForeColor.Value));
            if (data.GridLines.HasValue) writer.WriteInt32(7, data.GridLines.Value);
            if (data.GridColor.HasValue) writer.WriteInt32(8, unchecked((int)data.GridColor.Value));
            if (data.AutoSize.HasValue) writer.WriteBool(9, data.AutoSize.Value);
            if (data.AllowResize.HasValue) writer.WriteBool(10, data.AllowResize.Value);
            if (data.AllowReorder.HasValue) writer.WriteBool(11, data.AllowReorder.Value);
            if (data.AllowMenu.HasValue) writer.WriteBool(12, data.AllowMenu.Value);
            foreach (var row in data.RowDefs)
            {
                if (row == null) continue;
                writer.WriteMessage(13, r =>
                {
                    if (row.Index.HasValue) r.WriteInt32(1, row.Index.Value);
                    if (row.HeightPx.HasValue) r.WriteInt32(2, row.HeightPx.Value);
                });
            }
            foreach (var cell in data.Cells)
            {
                if (cell == null) continue;
                writer.WriteMessage(14, c =>
                {
                    if (cell.Row1.HasValue) c.WriteInt32(1, cell.Row1.Value);
                    if (cell.Row2.HasValue) c.WriteInt32(2, cell.Row2.Value);
                    if (cell.Col1.HasValue) c.WriteInt32(3, cell.Col1.Value);
                    if (cell.Col2.HasValue) c.WriteInt32(4, cell.Col2.Value);
                    if (cell.Text != null) c.WriteString(5, cell.Text);
                    if (cell.ModeBits.HasValue) c.WriteInt32(6, (int)cell.ModeBits.Value);
                    if (cell.CustomKey != null) c.WriteString(7, cell.CustomKey);
                    if (cell.Data != null) c.WriteBytes(8, cell.Data);
                });
            }
        }

        private static void EncodeCornerIndicatorConfig(ProtoWriter writer, VolvoxCornerIndicatorConfigData data)
        {
            if (data.Visible.HasValue) writer.WriteBool(1, data.Visible.Value);
            if (data.ModeBits.HasValue) writer.WriteInt32(2, unchecked((int)data.ModeBits.Value));
            if (data.BackColor.HasValue) writer.WriteInt32(3, unchecked((int)data.BackColor.Value));
            if (data.ForeColor.HasValue) writer.WriteInt32(4, unchecked((int)data.ForeColor.Value));
            if (data.CustomKey != null) writer.WriteString(5, data.CustomKey);
            if (data.Data != null) writer.WriteBytes(6, data.Data);
        }

        private static void DecodeIndicatorBandsConfig(VolvoxIndicatorBandsConfigData bands, byte[] payload)
        {
            if (bands == null || payload == null) return;
            var reader = new ProtoReader(payload);
            int field;
            ProtoWireType wire;
            while (reader.TryReadTag(out field, out wire))
            {
                if (wire != ProtoWireType.LengthDelimited)
                {
                    reader.SkipField(wire);
                    continue;
                }

                var bytes = reader.ReadLengthDelimited();
                switch (field)
                {
                    case 1: DecodeRowIndicatorConfig(bands.RowIndicatorStart, bytes); break;
                    case 2: DecodeRowIndicatorConfig(bands.RowIndicatorEnd, bytes); break;
                    case 3: DecodeColIndicatorConfig(bands.ColIndicatorTop, bytes); break;
                    case 4: DecodeColIndicatorConfig(bands.ColIndicatorBottom, bytes); break;
                    case 5: DecodeCornerIndicatorConfig(bands.CornerTopStart, bytes); break;
                    case 6: DecodeCornerIndicatorConfig(bands.CornerTopEnd, bytes); break;
                    case 7: DecodeCornerIndicatorConfig(bands.CornerBottomStart, bytes); break;
                    case 8: DecodeCornerIndicatorConfig(bands.CornerBottomEnd, bytes); break;
                    default: break;
                }
            }
        }

        private static void DecodeRowIndicatorConfig(VolvoxRowIndicatorConfigData data, byte[] payload)
        {
            if (data == null || payload == null) return;
            var reader = new ProtoReader(payload);
            int field;
            ProtoWireType wire;
            while (reader.TryReadTag(out field, out wire))
            {
                switch (field)
                {
                    case 1: if (wire == ProtoWireType.Varint) data.Visible = reader.ReadBool(); else reader.SkipField(wire); break;
                    case 2: if (wire == ProtoWireType.Varint) data.WidthPx = reader.ReadInt32(); else reader.SkipField(wire); break;
                    case 3: if (wire == ProtoWireType.Varint) data.ModeBits = (VolvoxRowIndicatorMode)reader.ReadInt32(); else reader.SkipField(wire); break;
                    case 4: if (wire == ProtoWireType.Varint) data.BackColor = unchecked((uint)reader.ReadInt32()); else reader.SkipField(wire); break;
                    case 5: if (wire == ProtoWireType.Varint) data.ForeColor = unchecked((uint)reader.ReadInt32()); else reader.SkipField(wire); break;
                    case 6: if (wire == ProtoWireType.Varint) data.GridLines = reader.ReadInt32(); else reader.SkipField(wire); break;
                    case 7: if (wire == ProtoWireType.Varint) data.GridColor = unchecked((uint)reader.ReadInt32()); else reader.SkipField(wire); break;
                    case 8: if (wire == ProtoWireType.Varint) data.AutoSize = reader.ReadBool(); else reader.SkipField(wire); break;
                    case 9: if (wire == ProtoWireType.Varint) data.AllowResize = reader.ReadBool(); else reader.SkipField(wire); break;
                    case 10: if (wire == ProtoWireType.Varint) data.AllowSelect = reader.ReadBool(); else reader.SkipField(wire); break;
                    case 11: if (wire == ProtoWireType.Varint) data.AllowReorder = reader.ReadBool(); else reader.SkipField(wire); break;
                    case 12:
                        if (wire == ProtoWireType.LengthDelimited)
                        {
                            var slot = new VolvoxRowIndicatorSlotData();
                            DecodeRowIndicatorSlot(slot, reader.ReadLengthDelimited());
                            data.Slots.Add(slot);
                        }
                        else reader.SkipField(wire);
                        break;
                    default:
                        reader.SkipField(wire);
                        break;
                }
            }
        }

        private static void DecodeRowIndicatorSlot(VolvoxRowIndicatorSlotData slot, byte[] payload)
        {
            if (slot == null || payload == null) return;
            var reader = new ProtoReader(payload);
            int field;
            ProtoWireType wire;
            while (reader.TryReadTag(out field, out wire))
            {
                switch (field)
                {
                    case 1: if (wire == ProtoWireType.Varint) slot.Kind = (VolvoxRowIndicatorSlotKind)reader.ReadInt32(); else reader.SkipField(wire); break;
                    case 2: if (wire == ProtoWireType.Varint) slot.WidthPx = reader.ReadInt32(); else reader.SkipField(wire); break;
                    case 3: if (wire == ProtoWireType.Varint) slot.Visible = reader.ReadBool(); else reader.SkipField(wire); break;
                    case 4: if (wire == ProtoWireType.LengthDelimited) slot.CustomKey = reader.ReadString(); else reader.SkipField(wire); break;
                    case 5: if (wire == ProtoWireType.LengthDelimited) slot.Data = reader.ReadLengthDelimited(); else reader.SkipField(wire); break;
                    default: reader.SkipField(wire); break;
                }
            }
        }

        private static void DecodeColIndicatorConfig(VolvoxColIndicatorConfigData data, byte[] payload)
        {
            if (data == null || payload == null) return;
            var reader = new ProtoReader(payload);
            int field;
            ProtoWireType wire;
            while (reader.TryReadTag(out field, out wire))
            {
                switch (field)
                {
                    case 1: if (wire == ProtoWireType.Varint) data.Visible = reader.ReadBool(); else reader.SkipField(wire); break;
                    case 2: if (wire == ProtoWireType.Varint) data.DefaultRowHeightPx = reader.ReadInt32(); else reader.SkipField(wire); break;
                    case 3: if (wire == ProtoWireType.Varint) data.BandRows = reader.ReadInt32(); else reader.SkipField(wire); break;
                    case 4: if (wire == ProtoWireType.Varint) data.ModeBits = (VolvoxColIndicatorCellMode)reader.ReadInt32(); else reader.SkipField(wire); break;
                    case 5: if (wire == ProtoWireType.Varint) data.BackColor = unchecked((uint)reader.ReadInt32()); else reader.SkipField(wire); break;
                    case 6: if (wire == ProtoWireType.Varint) data.ForeColor = unchecked((uint)reader.ReadInt32()); else reader.SkipField(wire); break;
                    case 7: if (wire == ProtoWireType.Varint) data.GridLines = reader.ReadInt32(); else reader.SkipField(wire); break;
                    case 8: if (wire == ProtoWireType.Varint) data.GridColor = unchecked((uint)reader.ReadInt32()); else reader.SkipField(wire); break;
                    case 9: if (wire == ProtoWireType.Varint) data.AutoSize = reader.ReadBool(); else reader.SkipField(wire); break;
                    case 10: if (wire == ProtoWireType.Varint) data.AllowResize = reader.ReadBool(); else reader.SkipField(wire); break;
                    case 11: if (wire == ProtoWireType.Varint) data.AllowReorder = reader.ReadBool(); else reader.SkipField(wire); break;
                    case 12: if (wire == ProtoWireType.Varint) data.AllowMenu = reader.ReadBool(); else reader.SkipField(wire); break;
                    case 13:
                        if (wire == ProtoWireType.LengthDelimited)
                        {
                            var row = new VolvoxColIndicatorRowDefData();
                            DecodeColIndicatorRowDef(row, reader.ReadLengthDelimited());
                            data.RowDefs.Add(row);
                        }
                        else reader.SkipField(wire);
                        break;
                    case 14:
                        if (wire == ProtoWireType.LengthDelimited)
                        {
                            var cell = new VolvoxColIndicatorCellData();
                            DecodeColIndicatorCell(cell, reader.ReadLengthDelimited());
                            data.Cells.Add(cell);
                        }
                        else reader.SkipField(wire);
                        break;
                    default:
                        reader.SkipField(wire);
                        break;
                }
            }
        }

        private static void DecodeColIndicatorRowDef(VolvoxColIndicatorRowDefData row, byte[] payload)
        {
            if (row == null || payload == null) return;
            var reader = new ProtoReader(payload);
            int field;
            ProtoWireType wire;
            while (reader.TryReadTag(out field, out wire))
            {
                switch (field)
                {
                    case 1: if (wire == ProtoWireType.Varint) row.Index = reader.ReadInt32(); else reader.SkipField(wire); break;
                    case 2: if (wire == ProtoWireType.Varint) row.HeightPx = reader.ReadInt32(); else reader.SkipField(wire); break;
                    default: reader.SkipField(wire); break;
                }
            }
        }

        private static void DecodeColIndicatorCell(VolvoxColIndicatorCellData cell, byte[] payload)
        {
            if (cell == null || payload == null) return;
            var reader = new ProtoReader(payload);
            int field;
            ProtoWireType wire;
            while (reader.TryReadTag(out field, out wire))
            {
                switch (field)
                {
                    case 1: if (wire == ProtoWireType.Varint) cell.Row1 = reader.ReadInt32(); else reader.SkipField(wire); break;
                    case 2: if (wire == ProtoWireType.Varint) cell.Row2 = reader.ReadInt32(); else reader.SkipField(wire); break;
                    case 3: if (wire == ProtoWireType.Varint) cell.Col1 = reader.ReadInt32(); else reader.SkipField(wire); break;
                    case 4: if (wire == ProtoWireType.Varint) cell.Col2 = reader.ReadInt32(); else reader.SkipField(wire); break;
                    case 5: if (wire == ProtoWireType.LengthDelimited) cell.Text = reader.ReadString(); else reader.SkipField(wire); break;
                    case 6: if (wire == ProtoWireType.Varint) cell.ModeBits = (VolvoxColIndicatorCellMode)reader.ReadInt32(); else reader.SkipField(wire); break;
                    case 7: if (wire == ProtoWireType.LengthDelimited) cell.CustomKey = reader.ReadString(); else reader.SkipField(wire); break;
                    case 8: if (wire == ProtoWireType.LengthDelimited) cell.Data = reader.ReadLengthDelimited(); else reader.SkipField(wire); break;
                    default: reader.SkipField(wire); break;
                }
            }
        }

        private static void DecodeCornerIndicatorConfig(VolvoxCornerIndicatorConfigData data, byte[] payload)
        {
            if (data == null || payload == null) return;
            var reader = new ProtoReader(payload);
            int field;
            ProtoWireType wire;
            while (reader.TryReadTag(out field, out wire))
            {
                switch (field)
                {
                    case 1: if (wire == ProtoWireType.Varint) data.Visible = reader.ReadBool(); else reader.SkipField(wire); break;
                    case 2: if (wire == ProtoWireType.Varint) data.ModeBits = unchecked((uint)reader.ReadInt32()); else reader.SkipField(wire); break;
                    case 3: if (wire == ProtoWireType.Varint) data.BackColor = unchecked((uint)reader.ReadInt32()); else reader.SkipField(wire); break;
                    case 4: if (wire == ProtoWireType.Varint) data.ForeColor = unchecked((uint)reader.ReadInt32()); else reader.SkipField(wire); break;
                    case 5: if (wire == ProtoWireType.LengthDelimited) data.CustomKey = reader.ReadString(); else reader.SkipField(wire); break;
                    case 6: if (wire == ProtoWireType.LengthDelimited) data.Data = reader.ReadLengthDelimited(); else reader.SkipField(wire); break;
                    default: reader.SkipField(wire); break;
                }
            }
        }

        private static byte[] EncodeCellStyle(VolvoxCellStyleOverride style)
        {
            var s = style ?? new VolvoxCellStyleOverride();
            var writer = new ProtoWriter();
            if (s.BackColor.HasValue) writer.WriteInt32(1, unchecked((int)s.BackColor.Value));
            if (s.ForeColor.HasValue) writer.WriteInt32(2, unchecked((int)s.ForeColor.Value));
            if (s.Alignment.HasValue) writer.WriteInt32(3, (int)s.Alignment.Value);
            if (s.TextEffect.HasValue) writer.WriteInt32(4, (int)s.TextEffect.Value);
            if (s.FontName != null) writer.WriteString(5, s.FontName);
            if (s.FontSize.HasValue) writer.WriteFloat(6, s.FontSize.Value);
            if (s.FontBold.HasValue) writer.WriteBool(7, s.FontBold.Value);
            if (s.FontItalic.HasValue) writer.WriteBool(8, s.FontItalic.Value);
            if (s.FontUnderline.HasValue) writer.WriteBool(9, s.FontUnderline.Value);
            if (s.FontStrikethrough.HasValue) writer.WriteBool(10, s.FontStrikethrough.Value);
            if (s.FontWidth.HasValue) writer.WriteFloat(11, s.FontWidth.Value);
            if (s.ProgressColor.HasValue) writer.WriteInt32(12, unchecked((int)s.ProgressColor.Value));
            if (s.ProgressPercent.HasValue) writer.WriteFloat(13, s.ProgressPercent.Value);
            if (s.Border.HasValue) writer.WriteInt32(14, (int)s.Border.Value);
            if (s.BorderColor.HasValue) writer.WriteInt32(15, unchecked((int)s.BorderColor.Value));
            return writer.ToArray();
        }

        private static VolvoxCellStyleOverride DecodeCellStyle(byte[] payload)
        {
            var style = new VolvoxCellStyleOverride();
            var reader = new ProtoReader(payload);
            int field;
            ProtoWireType wire;
            while (reader.TryReadTag(out field, out wire))
            {
                switch (field)
                {
                    case 1:
                        if (wire == ProtoWireType.Varint) style.BackColor = unchecked((uint)reader.ReadInt32());
                        else reader.SkipField(wire);
                        break;
                    case 2:
                        if (wire == ProtoWireType.Varint) style.ForeColor = unchecked((uint)reader.ReadInt32());
                        else reader.SkipField(wire);
                        break;
                    case 3:
                        if (wire == ProtoWireType.Varint) style.Alignment = (VolvoxAlign)reader.ReadInt32();
                        else reader.SkipField(wire);
                        break;
                    case 4:
                        if (wire == ProtoWireType.Varint) style.TextEffect = (VolvoxTextEffect)reader.ReadInt32();
                        else reader.SkipField(wire);
                        break;
                    case 5:
                        if (wire == ProtoWireType.LengthDelimited) style.FontName = reader.ReadString();
                        else reader.SkipField(wire);
                        break;
                    case 6:
                        if (wire == ProtoWireType.Fixed32) style.FontSize = reader.ReadFloat();
                        else reader.SkipField(wire);
                        break;
                    case 7:
                        if (wire == ProtoWireType.Varint) style.FontBold = reader.ReadBool();
                        else reader.SkipField(wire);
                        break;
                    case 8:
                        if (wire == ProtoWireType.Varint) style.FontItalic = reader.ReadBool();
                        else reader.SkipField(wire);
                        break;
                    case 9:
                        if (wire == ProtoWireType.Varint) style.FontUnderline = reader.ReadBool();
                        else reader.SkipField(wire);
                        break;
                    case 10:
                        if (wire == ProtoWireType.Varint) style.FontStrikethrough = reader.ReadBool();
                        else reader.SkipField(wire);
                        break;
                    case 11:
                        if (wire == ProtoWireType.Fixed32) style.FontWidth = reader.ReadFloat();
                        else reader.SkipField(wire);
                        break;
                    case 12:
                        if (wire == ProtoWireType.Varint) style.ProgressColor = unchecked((uint)reader.ReadInt32());
                        else reader.SkipField(wire);
                        break;
                    case 13:
                        if (wire == ProtoWireType.Fixed32) style.ProgressPercent = reader.ReadFloat();
                        else reader.SkipField(wire);
                        break;
                    case 14:
                        if (wire == ProtoWireType.Varint) style.Border = (VolvoxBorderStyle)reader.ReadInt32();
                        else reader.SkipField(wire);
                        break;
                    case 15:
                        if (wire == ProtoWireType.Varint) style.BorderColor = unchecked((uint)reader.ReadInt32());
                        else reader.SkipField(wire);
                        break;
                    default:
                        reader.SkipField(wire);
                        break;
                }
            }

            return style;
        }

        private static byte[] EncodeCellValue(VolvoxCellValueData value)
        {
            var normalized = value ?? new VolvoxCellValueData { Kind = VolvoxCellValueKind.Text, TextValue = string.Empty };
            var writer = new ProtoWriter();
            switch (normalized.Kind)
            {
                case VolvoxCellValueKind.Boolean:
                    writer.WriteBool(3, normalized.BoolValue);
                    break;
                case VolvoxCellValueKind.Number:
                    writer.WriteDouble(2, normalized.NumberValue);
                    break;
                case VolvoxCellValueKind.Bytes:
                    writer.WriteBytes(4, normalized.BytesValue ?? new byte[0]);
                    break;
                case VolvoxCellValueKind.Timestamp:
                    writer.WriteInt64(5, normalized.TimestampValue);
                    break;
                default:
                    writer.WriteString(1, normalized.TextValue ?? string.Empty);
                    break;
            }

            return writer.ToArray();
        }

        private static VolvoxCellValueData DecodeCellValue(byte[] payload)
        {
            var value = new VolvoxCellValueData { Kind = VolvoxCellValueKind.Text, TextValue = string.Empty };
            var reader = new ProtoReader(payload);
            int field;
            ProtoWireType wire;
            while (reader.TryReadTag(out field, out wire))
            {
                switch (field)
                {
                    case 1:
                        if (wire == ProtoWireType.LengthDelimited)
                        {
                            value.Kind = VolvoxCellValueKind.Text;
                            value.TextValue = reader.ReadString();
                        }
                        else
                        {
                            reader.SkipField(wire);
                        }
                        break;
                    case 2:
                        if (wire == ProtoWireType.Fixed64)
                        {
                            value.Kind = VolvoxCellValueKind.Number;
                            value.NumberValue = reader.ReadDouble();
                        }
                        else
                        {
                            reader.SkipField(wire);
                        }
                        break;
                    case 3:
                        if (wire == ProtoWireType.Varint)
                        {
                            value.Kind = VolvoxCellValueKind.Boolean;
                            value.BoolValue = reader.ReadBool();
                        }
                        else
                        {
                            reader.SkipField(wire);
                        }
                        break;
                    case 4:
                        if (wire == ProtoWireType.LengthDelimited)
                        {
                            value.Kind = VolvoxCellValueKind.Bytes;
                            value.BytesValue = reader.ReadLengthDelimited();
                        }
                        else
                        {
                            reader.SkipField(wire);
                        }
                        break;
                    case 5:
                        if (wire == ProtoWireType.Varint)
                        {
                            value.Kind = VolvoxCellValueKind.Timestamp;
                            value.TimestampValue = reader.ReadInt64();
                        }
                        else
                        {
                            reader.SkipField(wire);
                        }
                        break;
                    default:
                        reader.SkipField(wire);
                        break;
                }
            }

            return value;
        }
    }
}
