using System;
using System.Collections.Generic;
using Google.Protobuf;
using Volvoxgrid.V1;

namespace VolvoxGrid.DotNet.Internal
{
    internal sealed class ModernProtoCodec : IProtoCodec
    {
        public byte[] EncodeCreateRequest(int viewportWidth, int viewportHeight, float scale)
        {
            var req = new CreateRequest
            {
                ViewportWidth = viewportWidth,
                ViewportHeight = viewportHeight,
                Scale = scale,
            };
            return req.ToByteArray();
        }

        public long DecodeGridHandle(byte[] payload)
        {
            return CreateResponse.Parser.ParseFrom(payload).Handle?.Id ?? 0L;
        }

        public byte[] EncodeGridHandle(long gridId)
        {
            return new GridHandle { Id = gridId }.ToByteArray();
        }

        public byte[] EncodeConfigureRequest(long gridId, VolvoxGridConfigData config)
        {
            var req = new ConfigureRequest
            {
                GridId = gridId,
                Config = MapConfig(config),
            };
            return req.ToByteArray();
        }

        public byte[] EncodeGetConfigRequest(long gridId)
        {
            return EncodeGridHandle(gridId);
        }

        public VolvoxGridConfigData DecodeGridConfig(byte[] payload)
        {
            var config = GridConfig.Parser.ParseFrom(payload);
            return UnmapConfig(config);
        }

        public byte[] EncodeDefineColumnsRequest(long gridId, IList<VolvoxColumnDefinition> columns)
        {
            var req = new DefineColumnsRequest { GridId = gridId };
            foreach (var col in columns)
            {
                var def = new ColumnDef
                {
                    Index = col.Index,
                    Caption = col.Caption ?? string.Empty,
                    Key = col.Key ?? string.Empty,
                    Hidden = col.Hidden,
                    Span = col.Span,
                };
                if (col.Width.HasValue) def.Width = col.Width.Value;
                if (col.MinWidth.HasValue) def.MinWidth = col.MinWidth.Value;
                if (col.MaxWidth.HasValue) def.MaxWidth = col.MaxWidth.Value;
                if (col.Alignment.HasValue) def.Alignment = (Align)col.Alignment.Value;
                if (col.FixedAlignment.HasValue) def.FixedAlignment = (Align)col.FixedAlignment.Value;
                if (col.DataType.HasValue) def.DataType = (ColumnDataType)col.DataType.Value;
                if (col.Format != null) def.Format = col.Format;
                if (col.SortOrder != VolvoxSortOrder.None) def.Sort = (SortOrder)col.SortOrder;
                if (col.DropdownItems != null) def.DropdownItems = col.DropdownItems;
                if (col.EditMask != null) def.EditMask = col.EditMask;
                if (col.Indent.HasValue) def.Indent = col.Indent.Value;
                if (col.Sticky.HasValue) def.Sticky = (StickyEdge)col.Sticky.Value;
                req.Columns.Add(def);
            }
            return req.ToByteArray();
        }

        public byte[] EncodeDefineRowsRequest(long gridId, IList<VolvoxRowDefinition> rows)
        {
            var req = new DefineRowsRequest { GridId = gridId };
            foreach (var row in rows)
            {
                var def = new RowDef
                {
                    Index = row.Index,
                    Hidden = row.Hidden,
                    IsSubtotal = row.IsSubtotal,
                    IsCollapsed = row.IsCollapsed,
                    Span = row.Span,
                };
                if (row.Height.HasValue) def.Height = row.Height.Value;
                if (row.OutlineLevel.HasValue) def.OutlineLevel = row.OutlineLevel.Value;
                if (row.Pin.HasValue) def.Pin = (PinPosition)row.Pin.Value;
                if (row.Sticky.HasValue) def.Sticky = (StickyEdge)row.Sticky.Value;
                req.Rows.Add(def);
            }
            return req.ToByteArray();
        }

        public byte[] EncodeInsertRowsRequest(long gridId, int index, int count, IList<string> text)
        {
            var req = new InsertRowsRequest
            {
                GridId = gridId,
                Index = index,
                Count = count,
            };
            if (text != null) req.Text.AddRange(text);
            return req.ToByteArray();
        }

        public byte[] EncodeRemoveRowsRequest(long gridId, int index, int count)
        {
            return new RemoveRowsRequest { GridId = gridId, Index = index, Count = count }.ToByteArray();
        }

        public byte[] EncodeMoveColumnRequest(long gridId, int col, int position)
        {
            return new MoveColumnRequest { GridId = gridId, Col = col, Position = position }.ToByteArray();
        }

        public byte[] EncodeMoveRowRequest(long gridId, int row, int position)
        {
            return new MoveRowRequest { GridId = gridId, Row = row, Position = position }.ToByteArray();
        }

        public byte[] EncodeLoadTableRequest(long gridId, int rows, int cols, IList<VolvoxCellValueData> values, bool atomic)
        {
            var req = new LoadTableRequest
            {
                GridId = gridId,
                Rows = rows,
                Cols = cols,
                Atomic = atomic,
            };
            foreach (var v in values) req.Values.Add(ToProtoCellValue(v));
            return req.ToByteArray();
        }

        public byte[] EncodeUpdateCellsRequest(long gridId, IList<VolvoxCellUpdateData> updates, bool atomic)
        {
            var req = new UpdateCellsRequest
            {
                GridId = gridId,
                Atomic = atomic,
            };
            foreach (var up in updates)
            {
                var cell = new CellUpdate
                {
                    Row = up.Row,
                    Col = up.Col,
                };
                if (up.Value != null) cell.Value = ToProtoCellValue(up.Value);
                if (up.Style != null) cell.Style = MapCellStyle(up.Style);
                if (up.Checked.HasValue) cell.Checked = (CheckedState)up.Checked.Value;
                if (up.DropdownItems != null) cell.DropdownItems = up.DropdownItems;
                req.Cells.Add(cell);
            }
            return req.ToByteArray();
        }

        public byte[] EncodeGetCellsRequest(long gridId, int row1, int col1, int row2, int col2, bool includeStyle, bool includeChecked, bool includeTyped)
        {
            return new GetCellsRequest
            {
                GridId = gridId,
                Row1 = row1,
                Col1 = col1,
                Row2 = row2,
                Col2 = col2,
                IncludeStyle = includeStyle,
                IncludeChecked = includeChecked,
                IncludeTyped = includeTyped,
            }.ToByteArray();
        }

        public List<VolvoxCellUpdateData> DecodeCellsResponse(byte[] payload)
        {
            var resp = CellsResponse.Parser.ParseFrom(payload);
            var list = new List<VolvoxCellUpdateData>();
            foreach (var cell in resp.Cells)
            {
                list.Add(new VolvoxCellUpdateData
                {
                    Row = cell.Row,
                    Col = cell.Col,
                    Value = FromProtoCellValue(cell.Value),
                    Checked = (VolvoxCheckedState)cell.Checked,
                    Style = cell.Style != null ? UnmapCellStyle(cell.Style) : null,
                });
            }
            return list;
        }

        public byte[] EncodeClearRequest(long gridId, VolvoxClearScope scope, VolvoxClearRegion region)
        {
            return new ClearRequest { GridId = gridId, Scope = (ClearScope)scope, Region = (ClearRegion)region }.ToByteArray();
        }

        public byte[] EncodeSelectRequest(long gridId, int activeRow, int activeCol, IList<VolvoxCellRangeData> ranges, bool? show)
        {
            var req = new SelectRequest
            {
                GridId = gridId,
                ActiveRow = activeRow,
                ActiveCol = activeCol,
            };
            if (show.HasValue) req.Show = show.Value;
            foreach (var r in ranges)
            {
                req.Ranges.Add(new CellRange { Row1 = r.Row1, Col1 = r.Col1, Row2 = r.Row2, Col2 = r.Col2 });
            }
            return req.ToByteArray();
        }

        public byte[] EncodeShowCellRequest(long gridId, int row, int col)
        {
            return new ShowCellRequest { GridId = gridId, Row = row, Col = col }.ToByteArray();
        }

        public byte[] EncodeSetTopRowRequest(long gridId, int row)
        {
            return new SetRowRequest { GridId = gridId, Row = row }.ToByteArray();
        }

        public byte[] EncodeSetLeftColRequest(long gridId, int col)
        {
            return new SetColRequest { GridId = gridId, Col = col }.ToByteArray();
        }

        public VolvoxSelectionStateData DecodeSelectionState(byte[] payload)
        {
            var state = SelectionState.Parser.ParseFrom(payload);
            var data = new VolvoxSelectionStateData
            {
                ActiveRow = state.ActiveRow,
                ActiveCol = state.ActiveCol,
                TopRow = state.TopRow,
                LeftCol = state.LeftCol,
                BottomRow = state.BottomRow,
                RightCol = state.RightCol,
                MouseRow = state.MouseRow,
                MouseCol = state.MouseCol,
            };
            foreach (var r in state.Ranges)
            {
                data.Ranges.Add(new VolvoxCellRangeData { Row1 = r.Row1, Col1 = r.Col1, Row2 = r.Row2, Col2 = r.Col2 });
            }
            return data;
        }

        public byte[] EncodeSortRequest(long gridId, IList<VolvoxSortColumn> sorts)
        {
            var req = new SortRequest { GridId = gridId };
            foreach (var s in sorts)
            {
                req.SortColumns.Add(new SortColumn { Col = s.ColumnIndex, Order = (SortOrder)s.SortOrder });
            }
            return req.ToByteArray();
        }

        public byte[] EncodeSubtotalRequest(long gridId, VolvoxAggregateType aggregate, int groupOnCol, int aggregateCol, string caption, uint backColor, uint foreColor, bool addOutline)
        {
            return new SubtotalRequest
            {
                GridId = gridId,
                Aggregate = (AggregateType)aggregate,
                GroupOnCol = groupOnCol,
                AggregateCol = aggregateCol,
                Caption = caption ?? string.Empty,
                BackColor = backColor,
                ForeColor = foreColor,
                AddOutline = addOutline,
            }.ToByteArray();
        }

        public byte[] EncodeAutoSizeRequest(long gridId, int colFrom, int colTo, bool equal, int maxWidth)
        {
            return new AutoSizeRequest { GridId = gridId, ColFrom = colFrom, ColTo = colTo, Equal = equal, MaxWidth = maxWidth }.ToByteArray();
        }

        public byte[] EncodeOutlineRequest(long gridId, int level)
        {
            return new OutlineRequest { GridId = gridId, Level = level }.ToByteArray();
        }

        public byte[] EncodeGetNodeRequest(long gridId, int row, VolvoxNodeRelation? relation)
        {
            var req = new GetNodeRequest { GridId = gridId, Row = row };
            if (relation.HasValue) req.Relation = (NodeRelation)relation.Value;
            return req.ToByteArray();
        }

        public VolvoxNodeInfoData DecodeNodeInfo(byte[] payload)
        {
            var info = NodeInfo.Parser.ParseFrom(payload);
            return new VolvoxNodeInfoData
            {
                Row = info.Row,
                Level = info.Level,
                IsExpanded = info.IsExpanded,
                ChildCount = info.ChildCount,
                ParentRow = info.ParentRow,
            };
        }

        public byte[] EncodeFindRequest(long gridId, int col, int startRow, string text, bool caseSensitive, bool fullMatch, string regex)
        {
            var req = new FindRequest { GridId = gridId, Col = col, StartRow = startRow };
            if (regex != null)
            {
                req.RegexQuery = new RegexQuery { Pattern = regex };
            }
            else
            {
                req.TextQuery = new TextQuery { Text = text ?? string.Empty, CaseSensitive = caseSensitive, FullMatch = fullMatch };
            }
            return req.ToByteArray();
        }

        public int DecodeFindResponse(byte[] payload)
        {
            return FindResponse.Parser.ParseFrom(payload).Row;
        }

        public byte[] EncodeAggregateRequest(long gridId, VolvoxAggregateType aggregate, int row1, int col1, int row2, int col2)
        {
            return new AggregateRequest
            {
                GridId = gridId,
                Aggregate = (AggregateType)aggregate,
                Row1 = row1,
                Col1 = col1,
                Row2 = row2,
                Col2 = col2,
            }.ToByteArray();
        }

        public double DecodeAggregateResponse(byte[] payload)
        {
            return AggregateResponse.Parser.ParseFrom(payload).Value;
        }

        public byte[] EncodeGetMergedRangeRequest(long gridId, int row, int col)
        {
            return new GetMergedRangeRequest { GridId = gridId, Row = row, Col = col }.ToByteArray();
        }

        public VolvoxCellRangeData DecodeCellRange(byte[] payload)
        {
            var r = CellRange.Parser.ParseFrom(payload);
            return new VolvoxCellRangeData { Row1 = r.Row1, Col1 = r.Col1, Row2 = r.Row2, Col2 = r.Col2 };
        }

        public byte[] EncodeMergeCellsRequest(long gridId, VolvoxCellRangeData range)
        {
            return new MergeCellsRequest { GridId = gridId, Range = new CellRange { Row1 = range.Row1, Col1 = range.Col1, Row2 = range.Row2, Col2 = range.Col2 } }.ToByteArray();
        }

        public byte[] EncodeUnmergeCellsRequest(long gridId, VolvoxCellRangeData range)
        {
            return new UnmergeCellsRequest { GridId = gridId, Range = new CellRange { Row1 = range.Row1, Col1 = range.Col1, Row2 = range.Row2, Col2 = range.Col2 } }.ToByteArray();
        }

        public List<VolvoxCellRangeData> DecodeMergedRegionsResponse(byte[] payload)
        {
            var resp = MergedRegionsResponse.Parser.ParseFrom(payload);
            var list = new List<VolvoxCellRangeData>();
            foreach (var r in resp.Ranges)
            {
                list.Add(new VolvoxCellRangeData { Row1 = r.Row1, Col1 = r.Col1, Row2 = r.Row2, Col2 = r.Col2 });
            }
            return list;
        }

        public byte[] EncodeEditCommandStart(long gridId, int row, int col, bool? selectAll, bool? caretEnd, string seedText)
        {
            var cmd = new EditCommand { GridId = gridId, Start = new EditStart { Row = row, Col = col } };
            if (selectAll.HasValue) cmd.Start.SelectAll = selectAll.Value;
            if (caretEnd.HasValue) cmd.Start.CaretEnd = caretEnd.Value;
            if (seedText != null) cmd.Start.SeedText = seedText;
            return cmd.ToByteArray();
        }

        public byte[] EncodeEditCommandCommit(long gridId, string text)
        {
            var cmd = new EditCommand { GridId = gridId, Commit = new EditCommit() };
            if (text != null) cmd.Commit.Text = text;
            return cmd.ToByteArray();
        }

        public byte[] EncodeEditCommandCancel(long gridId)
        {
            return new EditCommand { GridId = gridId, Cancel = new EditCancel() }.ToByteArray();
        }

        public byte[] EncodeClipboardRequest(long gridId, string action, string pasteText)
        {
            var cmd = new ClipboardCommand { GridId = gridId };
            switch (action.ToLowerInvariant())
            {
                case "copy": cmd.Copy = new ClipboardCopy(); break;
                case "cut": cmd.Cut = new ClipboardCut(); break;
                case "paste": cmd.Paste = new ClipboardPaste { Text = pasteText ?? string.Empty }; break;
                case "delete": cmd.Delete = new ClipboardDelete(); break;
            }
            return cmd.ToByteArray();
        }

        public VolvoxClipboardResponseData DecodeClipboardResponse(byte[] payload)
        {
            var resp = ClipboardResponse.Parser.ParseFrom(payload);
            return new VolvoxClipboardResponseData { Text = resp.Text, RichData = resp.RichData.ToByteArray() };
        }

        public byte[] EncodeExportRequest(long gridId, VolvoxExportFormat format, VolvoxExportScope scope)
        {
            return new ExportRequest { GridId = gridId, Format = (ExportFormat)format, Scope = (ExportScope)scope }.ToByteArray();
        }

        public VolvoxExportResponseData DecodeExportResponse(byte[] payload)
        {
            var resp = ExportResponse.Parser.ParseFrom(payload);
            return new VolvoxExportResponseData { Data = resp.Data.ToByteArray(), Format = (VolvoxExportFormat)resp.Format };
        }

        public byte[] EncodeImportRequest(long gridId, byte[] data, VolvoxExportFormat format, VolvoxExportScope scope)
        {
            return new ImportRequest { GridId = gridId, Data = ByteString.CopyFrom(data ?? Array.Empty<byte>()), Format = (ExportFormat)format, Scope = (ExportScope)scope }.ToByteArray();
        }

        public byte[] EncodePrintRequest(long gridId, bool landscape, int marginL, int marginT, int marginR, int marginB, string header, string footer, bool showPageNumbers)
        {
            return new PrintRequest
            {
                GridId = gridId,
                Orientation = landscape ? PrintOrientation.PrintLandscape : PrintOrientation.PrintPortrait,
                MarginLeft = marginL, MarginTop = marginT, MarginRight = marginR, MarginBottom = marginB,
                Header = header ?? string.Empty, Footer = footer ?? string.Empty,
                ShowPageNumbers = showPageNumbers,
            }.ToByteArray();
        }

        public byte[] EncodeArchiveRequest(long gridId, VolvoxArchiveAction action, string name, byte[] data)
        {
            var req = new ArchiveRequest { GridId = gridId, Action = (ArchiveRequest.Types.Action)action, Name = name ?? string.Empty };
            if (data != null) req.Data = ByteString.CopyFrom(data);
            return req.ToByteArray();
        }

        public VolvoxArchiveResponseData DecodeArchiveResponse(byte[] payload)
        {
            var resp = ArchiveResponse.Parser.ParseFrom(payload);
            var result = new VolvoxArchiveResponseData { Data = resp.Data.ToByteArray() };
            result.Names.AddRange(resp.Names);
            return result;
        }

        public byte[] EncodeLoadDemoRequest(long gridId, string demo)
        {
            return new LoadDemoRequest { GridId = gridId, Demo = demo ?? string.Empty }.ToByteArray();
        }

        public byte[] EncodeSetRedrawRequest(long gridId, bool enabled)
        {
            return new SetRedrawRequest { GridId = gridId, Enabled = enabled }.ToByteArray();
        }

        public byte[] EncodeResizeViewportRequest(long gridId, int width, int height)
        {
            return new ResizeViewportRequest { GridId = gridId, Width = width, Height = height }.ToByteArray();
        }

        public byte[] EncodeRenderInputBufferReady(long gridId, long handle, int stride, int width, int height)
        {
            var input = new RenderInput
            {
                GridId = gridId,
                Buffer = new BufferReady { Handle = handle, Stride = stride, Width = width, Height = height },
            };
            return input.ToByteArray();
        }

        public byte[] EncodeRenderInputPointer(long gridId, VolvoxPointerType type, float x, float y, int modifier, int button, bool dblClick)
        {
            var input = new RenderInput
            {
                GridId = gridId,
                Pointer = new PointerEvent { Type = (PointerEvent.Types.Type)type, X = x, Y = y, Modifier = modifier, Button = button, DblClick = dblClick },
            };
            return input.ToByteArray();
        }

        public byte[] EncodeRenderInputKey(long gridId, VolvoxKeyType type, int keyCode, int modifier, string character)
        {
            var input = new RenderInput
            {
                GridId = gridId,
                Key = new KeyEvent { Type = (KeyEvent.Types.Type)type, KeyCode = keyCode, Modifier = modifier, Character = character ?? string.Empty },
            };
            return input.ToByteArray();
        }

        public byte[] EncodeRenderInputScroll(long gridId, float deltaX, float deltaY)
        {
            var input = new RenderInput { GridId = gridId, Scroll = new ScrollEvent { DeltaX = deltaX, DeltaY = deltaY } };
            return input.ToByteArray();
        }

        public byte[] EncodeRenderInputEventDecision(long gridId, long eventId, bool cancel)
        {
            var input = new RenderInput { GridId = gridId, EventDecision = new EventDecision { GridId = gridId, EventId = eventId, Cancel = cancel } };
            return input.ToByteArray();
        }

        public VolvoxRenderOutputData DecodeRenderOutput(byte[] payload)
        {
            var output = RenderOutput.Parser.ParseFrom(payload);
            var result = new VolvoxRenderOutputData { Rendered = output.Rendered };
            if (output.EventCase == RenderOutput.EventOneofCase.FrameDone)
            {
                result.FrameDone = new VolvoxFrameDoneData
                {
                    Handle = output.FrameDone.Handle,
                    DirtyX = output.FrameDone.DirtyX, DirtyY = output.FrameDone.DirtyY,
                    DirtyW = output.FrameDone.DirtyW, DirtyH = output.FrameDone.DirtyH,
                };
            }
            return result;
        }

        public VolvoxGridEventData DecodeGridEvent(byte[] payload)
        {
            var evt = GridEvent.Parser.ParseFrom(payload);
            var data = new VolvoxGridEventData { GridId = evt.GridId, EventId = evt.EventId, Kind = VolvoxGridEventKind.Unknown };
            switch (evt.EventCase)
            {
                case GridEvent.EventOneofCase.CellFocusChanged:
                    data.Kind = VolvoxGridEventKind.CellFocusChanged;
                    data.OldRow = evt.CellFocusChanged.OldRow; data.OldCol = evt.CellFocusChanged.OldCol;
                    data.NewRow = evt.CellFocusChanged.NewRow; data.NewCol = evt.CellFocusChanged.NewCol;
                    break;
                case GridEvent.EventOneofCase.SelectionChanged:
                    data.Kind = VolvoxGridEventKind.SelectionChanged;
                    data.ActiveRow = evt.SelectionChanged.ActiveRow; data.ActiveCol = evt.SelectionChanged.ActiveCol;
                    break;
                case GridEvent.EventOneofCase.CellChanged:
                    data.Kind = VolvoxGridEventKind.CellChanged;
                    data.Row = evt.CellChanged.Row; data.Col = evt.CellChanged.Col;
                    data.OldText = evt.CellChanged.OldText; data.NewText = evt.CellChanged.NewText;
                    break;
                case GridEvent.EventOneofCase.BeforeEdit:
                    data.Kind = VolvoxGridEventKind.BeforeEdit; data.Row = evt.BeforeEdit.Row; data.Col = evt.BeforeEdit.Col; data.IsCancelable = true;
                    break;
                case GridEvent.EventOneofCase.CellEditValidate:
                    data.Kind = VolvoxGridEventKind.CellEditValidate; data.Row = evt.CellEditValidate.Row; data.Col = evt.CellEditValidate.Col;
                    data.EditText = evt.CellEditValidate.EditText; data.IsCancelable = true;
                    break;
                case GridEvent.EventOneofCase.BeforeSort:
                    data.Kind = VolvoxGridEventKind.BeforeSort; data.Col = evt.BeforeSort.Col; data.IsCancelable = true;
                    break;
            }
            return data;
        }

        private GridConfig MapConfig(VolvoxGridConfigData config)
        {
            var res = new GridConfig();
            if (config.Layout != null)
            {
                res.Layout = new LayoutConfig();
                if (config.Layout.Rows.HasValue) res.Layout.Rows = config.Layout.Rows.Value;
                if (config.Layout.Cols.HasValue) res.Layout.Cols = config.Layout.Cols.Value;
                if (config.Layout.FixedRows.HasValue) res.Layout.FixedRows = config.Layout.FixedRows.Value;
                if (config.Layout.FixedCols.HasValue) res.Layout.FixedCols = config.Layout.FixedCols.Value;
                if (config.Layout.FrozenRows.HasValue) res.Layout.FrozenRows = config.Layout.FrozenRows.Value;
                if (config.Layout.FrozenCols.HasValue) res.Layout.FrozenCols = config.Layout.FrozenCols.Value;
                if (config.Layout.DefaultRowHeight.HasValue) res.Layout.DefaultRowHeight = config.Layout.DefaultRowHeight.Value;
                if (config.Layout.DefaultColWidth.HasValue) res.Layout.DefaultColWidth = config.Layout.DefaultColWidth.Value;
            }
            if (config.Selection != null)
            {
                res.Selection = new SelectionConfig();
                if (config.Selection.Mode.HasValue) res.Selection.Mode = (SelectionMode)config.Selection.Mode.Value;
                if (config.Selection.SelectionVisibility.HasValue) res.Selection.Visibility = (SelectionVisibility)config.Selection.SelectionVisibility.Value;
                if (config.Selection.AllowSelection.HasValue) res.Selection.Allow = config.Selection.AllowSelection.Value;
                if (config.Selection.HoverMask.HasValue) res.Selection.Hover = MapHoverConfig(config.Selection.HoverMask.Value);
            }
            if (config.Editing != null)
            {
                res.Editing = new EditConfig();
                if (config.Editing.EditTrigger.HasValue) res.Editing.Trigger = (EditTrigger)config.Editing.EditTrigger.Value;
            }
            if (config.Scrolling != null)
            {
                res.Scrolling = new ScrollConfig();
                if (config.Scrolling.Scrollbars.HasValue) res.Scrolling.Scrollbars = (ScrollBarsMode)config.Scrolling.Scrollbars.Value;
                if (config.Scrolling.FlingEnabled.HasValue) res.Scrolling.FlingEnabled = config.Scrolling.FlingEnabled.Value;
                if (config.Scrolling.FlingImpulseGain.HasValue) res.Scrolling.FlingImpulseGain = config.Scrolling.FlingImpulseGain.Value;
                if (config.Scrolling.FlingFriction.HasValue) res.Scrolling.FlingFriction = config.Scrolling.FlingFriction.Value;
                if (config.Scrolling.FastScroll.HasValue) res.Scrolling.FastScroll = config.Scrolling.FastScroll.Value;
            }
            if (config.Outline != null)
            {
                res.Outline = new OutlineConfig();
                if (config.Outline.TreeIndicator.HasValue) res.Outline.TreeIndicator = (TreeIndicatorStyle)config.Outline.TreeIndicator.Value;
                if (config.Outline.TreeColumn.HasValue) res.Outline.TreeColumn = config.Outline.TreeColumn.Value;
            }
            if (config.Span != null)
            {
                res.Span = new SpanConfig();
                if (config.Span.CellSpan.HasValue) res.Span.CellSpan = (CellSpanMode)config.Span.CellSpan.Value;
            }
            if (config.Interaction != null)
            {
                res.Interaction = new InteractionConfig();
                if (config.Interaction.ResizePolicy.HasValue) res.Interaction.Resize = MapResizePolicy(config.Interaction.ResizePolicy.Value);
                if (config.Interaction.HeaderFeatures.HasValue) res.Interaction.HeaderFeatures = MapHeaderFeatures(config.Interaction.HeaderFeatures.Value);
            }
            if (config.Rendering != null)
            {
                res.Rendering = new RenderConfig();
                if (config.Rendering.RendererMode.HasValue) res.Rendering.RendererMode = (RendererMode)config.Rendering.RendererMode.Value;
                if (config.Rendering.DebugOverlay.HasValue) res.Rendering.DebugOverlay = config.Rendering.DebugOverlay.Value;
                if (config.Rendering.AnimationEnabled.HasValue) res.Rendering.AnimationEnabled = config.Rendering.AnimationEnabled.Value;
                if (config.Rendering.AnimationDurationMs.HasValue) res.Rendering.AnimationDurationMs = config.Rendering.AnimationDurationMs.Value;
                if (config.Rendering.TextLayoutCacheCap.HasValue) res.Rendering.TextLayoutCacheCap = config.Rendering.TextLayoutCacheCap.Value;
            }
            if (config.Indicators != null)
            {
                res.Indicators = MapIndicators(config.Indicators);
            }
            return res;
        }

        private VolvoxGridConfigData UnmapConfig(GridConfig c)
        {
            var res = new VolvoxGridConfigData();
            if (c.Layout != null)
            {
                res.Layout.Rows = c.Layout.Rows; res.Layout.Cols = c.Layout.Cols;
                res.Layout.FixedRows = c.Layout.FixedRows; res.Layout.FixedCols = c.Layout.FixedCols;
                res.Layout.FrozenRows = c.Layout.FrozenRows; res.Layout.FrozenCols = c.Layout.FrozenCols;
                res.Layout.DefaultRowHeight = c.Layout.DefaultRowHeight; res.Layout.DefaultColWidth = c.Layout.DefaultColWidth;
            }
            if (c.Selection != null)
            {
                if (c.Selection.HasMode) res.Selection.Mode = (VolvoxSelectionMode)c.Selection.Mode;
                if (c.Selection.HasVisibility) res.Selection.SelectionVisibility = (VolvoxSelectionVisibility)c.Selection.Visibility;
                if (c.Selection.HasAllow) res.Selection.AllowSelection = c.Selection.Allow;
                if (c.Selection.Hover != null) res.Selection.HoverMask = UnmapHoverConfig(c.Selection.Hover);
            }
            if (c.Editing != null && c.Editing.HasTrigger) res.Editing.EditTrigger = (VolvoxEditTrigger)c.Editing.Trigger;
            if (c.Scrolling != null)
            {
                res.Scrolling.Scrollbars = (VolvoxScrollBarsMode)c.Scrolling.Scrollbars;
                res.Scrolling.FlingEnabled = c.Scrolling.FlingEnabled;
                res.Scrolling.FlingImpulseGain = c.Scrolling.FlingImpulseGain;
                res.Scrolling.FlingFriction = c.Scrolling.FlingFriction;
                res.Scrolling.FastScroll = c.Scrolling.FastScroll;
            }
            if (c.Outline != null)
            {
                res.Outline.TreeIndicator = (VolvoxTreeIndicatorStyle)c.Outline.TreeIndicator;
                res.Outline.TreeColumn = c.Outline.TreeColumn;
            }
            if (c.Span != null) res.Span.CellSpan = (VolvoxCellSpanMode)c.Span.CellSpan;
            if (c.Interaction != null)
            {
                if (c.Interaction.Resize != null) res.Interaction.ResizePolicy = UnmapResizePolicy(c.Interaction.Resize);
                if (c.Interaction.HeaderFeatures != null) res.Interaction.HeaderFeatures = UnmapHeaderFeatures(c.Interaction.HeaderFeatures);
            }
            if (c.Rendering != null)
            {
                res.Rendering.RendererMode = (VolvoxGridRendererMode)c.Rendering.RendererMode;
                res.Rendering.DebugOverlay = c.Rendering.DebugOverlay;
                res.Rendering.AnimationEnabled = c.Rendering.AnimationEnabled;
                res.Rendering.AnimationDurationMs = c.Rendering.AnimationDurationMs;
                res.Rendering.TextLayoutCacheCap = c.Rendering.TextLayoutCacheCap;
            }
            if (c.Indicators != null)
            {
                res.Indicators = UnmapIndicators(c.Indicators);
            }
            return res;
        }

        private static IndicatorsConfig MapIndicators(VolvoxIndicatorsConfigData data)
        {
            if (data == null) return null;
            return new IndicatorsConfig
            {
                RowIndicatorStart = MapRowIndicator(data.RowIndicatorStart),
                RowIndicatorEnd = MapRowIndicator(data.RowIndicatorEnd),
                ColIndicatorTop = MapColIndicator(data.ColIndicatorTop),
                ColIndicatorBottom = MapColIndicator(data.ColIndicatorBottom),
                CornerTopStart = MapCornerIndicator(data.CornerTopStart),
                CornerTopEnd = MapCornerIndicator(data.CornerTopEnd),
                CornerBottomStart = MapCornerIndicator(data.CornerBottomStart),
                CornerBottomEnd = MapCornerIndicator(data.CornerBottomEnd),
            };
        }

        private static VolvoxIndicatorsConfigData UnmapIndicators(IndicatorsConfig data)
        {
            if (data == null) return null;
            return new VolvoxIndicatorsConfigData
            {
                RowIndicatorStart = UnmapRowIndicator(data.RowIndicatorStart),
                RowIndicatorEnd = UnmapRowIndicator(data.RowIndicatorEnd),
                ColIndicatorTop = UnmapColIndicator(data.ColIndicatorTop),
                ColIndicatorBottom = UnmapColIndicator(data.ColIndicatorBottom),
                CornerTopStart = UnmapCornerIndicator(data.CornerTopStart),
                CornerTopEnd = UnmapCornerIndicator(data.CornerTopEnd),
                CornerBottomStart = UnmapCornerIndicator(data.CornerBottomStart),
                CornerBottomEnd = UnmapCornerIndicator(data.CornerBottomEnd),
            };
        }

        private static RowIndicatorConfig MapRowIndicator(VolvoxRowIndicatorConfigData data)
        {
            if (data == null) return null;
            var res = new RowIndicatorConfig();
            if (data.Visible.HasValue) res.Visible = data.Visible.Value;
            if (data.WidthPx.HasValue) res.WidthPx = data.WidthPx.Value;
            if (data.ModeBits.HasValue) res.ModeBits = (uint)data.ModeBits.Value;
            if (data.BackColor.HasValue) res.BackColor = data.BackColor.Value;
            if (data.ForeColor.HasValue) res.ForeColor = data.ForeColor.Value;
            if (data.GridLines.HasValue) res.GridLines = (GridLineStyle)data.GridLines.Value;
            if (data.GridColor.HasValue) res.GridColor = data.GridColor.Value;
            if (data.AutoSize.HasValue) res.AutoSize = data.AutoSize.Value;
            if (data.AllowResize.HasValue) res.AllowResize = data.AllowResize.Value;
            if (data.AllowSelect.HasValue) res.AllowSelect = data.AllowSelect.Value;
            if (data.AllowReorder.HasValue) res.AllowReorder = data.AllowReorder.Value;
            foreach (var slot in data.Slots)
            {
                if (slot == null) continue;
                var mapped = new RowIndicatorSlot();
                if (slot.Kind.HasValue) mapped.Kind = (RowIndicatorSlotKind)slot.Kind.Value;
                if (slot.WidthPx.HasValue) mapped.WidthPx = slot.WidthPx.Value;
                if (slot.Visible.HasValue) mapped.Visible = slot.Visible.Value;
                if (slot.CustomKey != null) mapped.CustomKey = slot.CustomKey;
                if (slot.Data != null) mapped.Data = Google.Protobuf.ByteString.CopyFrom(slot.Data);
                res.Slots.Add(mapped);
            }
            return res;
        }

        private static VolvoxRowIndicatorConfigData UnmapRowIndicator(RowIndicatorConfig data)
        {
            if (data == null) return null;
            var res = new VolvoxRowIndicatorConfigData
            {
                Visible = data.HasVisible ? (bool?)data.Visible : null,
                WidthPx = data.HasWidthPx ? (int?)data.WidthPx : null,
                ModeBits = data.HasModeBits ? (VolvoxRowIndicatorMode?)(int)data.ModeBits : null,
                BackColor = data.HasBackColor ? (uint?)data.BackColor : null,
                ForeColor = data.HasForeColor ? (uint?)data.ForeColor : null,
                GridLines = data.HasGridLines ? (int?)data.GridLines : null,
                GridColor = data.HasGridColor ? (uint?)data.GridColor : null,
                AutoSize = data.HasAutoSize ? (bool?)data.AutoSize : null,
                AllowResize = data.HasAllowResize ? (bool?)data.AllowResize : null,
                AllowSelect = data.HasAllowSelect ? (bool?)data.AllowSelect : null,
                AllowReorder = data.HasAllowReorder ? (bool?)data.AllowReorder : null,
            };
            foreach (var slot in data.Slots)
            {
                res.Slots.Add(new VolvoxRowIndicatorSlotData
                {
                    Kind = slot.HasKind ? (VolvoxRowIndicatorSlotKind?)(int)slot.Kind : null,
                    WidthPx = slot.HasWidthPx ? (int?)slot.WidthPx : null,
                    Visible = slot.HasVisible ? (bool?)slot.Visible : null,
                    CustomKey = slot.CustomKey,
                    Data = slot.Data.IsEmpty ? null : slot.Data.ToByteArray(),
                });
            }
            return res;
        }

        private static ColIndicatorConfig MapColIndicator(VolvoxColIndicatorConfigData data)
        {
            if (data == null) return null;
            var res = new ColIndicatorConfig();
            if (data.Visible.HasValue) res.Visible = data.Visible.Value;
            if (data.DefaultRowHeightPx.HasValue) res.DefaultRowHeightPx = data.DefaultRowHeightPx.Value;
            if (data.BandRows.HasValue) res.BandRows = data.BandRows.Value;
            if (data.ModeBits.HasValue) res.ModeBits = (uint)data.ModeBits.Value;
            if (data.BackColor.HasValue) res.BackColor = data.BackColor.Value;
            if (data.ForeColor.HasValue) res.ForeColor = data.ForeColor.Value;
            if (data.GridLines.HasValue) res.GridLines = (GridLineStyle)data.GridLines.Value;
            if (data.GridColor.HasValue) res.GridColor = data.GridColor.Value;
            if (data.AutoSize.HasValue) res.AutoSize = data.AutoSize.Value;
            if (data.AllowResize.HasValue) res.AllowResize = data.AllowResize.Value;
            if (data.AllowReorder.HasValue) res.AllowReorder = data.AllowReorder.Value;
            if (data.AllowMenu.HasValue) res.AllowMenu = data.AllowMenu.Value;
            foreach (var row in data.RowDefs)
            {
                if (row == null) continue;
                var mapped = new ColIndicatorRowDef();
                if (row.Index.HasValue) mapped.Index = row.Index.Value;
                if (row.HeightPx.HasValue) mapped.HeightPx = row.HeightPx.Value;
                res.RowDefs.Add(mapped);
            }
            foreach (var cell in data.Cells)
            {
                if (cell == null) continue;
                var mapped = new ColIndicatorCell();
                if (cell.Row1.HasValue) mapped.Row1 = cell.Row1.Value;
                if (cell.Row2.HasValue) mapped.Row2 = cell.Row2.Value;
                if (cell.Col1.HasValue) mapped.Col1 = cell.Col1.Value;
                if (cell.Col2.HasValue) mapped.Col2 = cell.Col2.Value;
                if (cell.Text != null) mapped.Text = cell.Text;
                if (cell.ModeBits.HasValue) mapped.ModeBits = (uint)cell.ModeBits.Value;
                if (cell.CustomKey != null) mapped.CustomKey = cell.CustomKey;
                if (cell.Data != null) mapped.Data = Google.Protobuf.ByteString.CopyFrom(cell.Data);
                res.Cells.Add(mapped);
            }
            return res;
        }

        private static VolvoxColIndicatorConfigData UnmapColIndicator(ColIndicatorConfig data)
        {
            if (data == null) return null;
            var res = new VolvoxColIndicatorConfigData
            {
                Visible = data.HasVisible ? (bool?)data.Visible : null,
                DefaultRowHeightPx = data.HasDefaultRowHeightPx ? (int?)data.DefaultRowHeightPx : null,
                BandRows = data.HasBandRows ? (int?)data.BandRows : null,
                ModeBits = data.HasModeBits ? (VolvoxColIndicatorCellMode?)(int)data.ModeBits : null,
                BackColor = data.HasBackColor ? (uint?)data.BackColor : null,
                ForeColor = data.HasForeColor ? (uint?)data.ForeColor : null,
                GridLines = data.HasGridLines ? (int?)data.GridLines : null,
                GridColor = data.HasGridColor ? (uint?)data.GridColor : null,
                AutoSize = data.HasAutoSize ? (bool?)data.AutoSize : null,
                AllowResize = data.HasAllowResize ? (bool?)data.AllowResize : null,
                AllowReorder = data.HasAllowReorder ? (bool?)data.AllowReorder : null,
                AllowMenu = data.HasAllowMenu ? (bool?)data.AllowMenu : null,
            };
            foreach (var row in data.RowDefs)
            {
                res.RowDefs.Add(new VolvoxColIndicatorRowDefData
                {
                    Index = row.HasIndex ? (int?)row.Index : null,
                    HeightPx = row.HasHeightPx ? (int?)row.HeightPx : null,
                });
            }
            foreach (var cell in data.Cells)
            {
                res.Cells.Add(new VolvoxColIndicatorCellData
                {
                    Row1 = cell.HasRow1 ? (int?)cell.Row1 : null,
                    Row2 = cell.HasRow2 ? (int?)cell.Row2 : null,
                    Col1 = cell.HasCol1 ? (int?)cell.Col1 : null,
                    Col2 = cell.HasCol2 ? (int?)cell.Col2 : null,
                    Text = cell.Text,
                    ModeBits = cell.HasModeBits ? (VolvoxColIndicatorCellMode?)(int)cell.ModeBits : null,
                    CustomKey = cell.CustomKey,
                    Data = cell.Data.IsEmpty ? null : cell.Data.ToByteArray(),
                });
            }
            return res;
        }

        private static CornerIndicatorConfig MapCornerIndicator(VolvoxCornerIndicatorConfigData data)
        {
            if (data == null) return null;
            var res = new CornerIndicatorConfig();
            if (data.Visible.HasValue) res.Visible = data.Visible.Value;
            if (data.ModeBits.HasValue) res.ModeBits = data.ModeBits.Value;
            if (data.BackColor.HasValue) res.BackColor = data.BackColor.Value;
            if (data.ForeColor.HasValue) res.ForeColor = data.ForeColor.Value;
            if (data.CustomKey != null) res.CustomKey = data.CustomKey;
            if (data.Data != null) res.Data = Google.Protobuf.ByteString.CopyFrom(data.Data);
            return res;
        }

        private static VolvoxCornerIndicatorConfigData UnmapCornerIndicator(CornerIndicatorConfig data)
        {
            if (data == null) return null;
            return new VolvoxCornerIndicatorConfigData
            {
                Visible = data.HasVisible ? (bool?)data.Visible : null,
                ModeBits = data.HasModeBits ? (uint?)data.ModeBits : null,
                BackColor = data.HasBackColor ? (uint?)data.BackColor : null,
                ForeColor = data.HasForeColor ? (uint?)data.ForeColor : null,
                CustomKey = data.CustomKey,
                Data = data.Data.IsEmpty ? null : data.Data.ToByteArray(),
            };
        }

        private static HoverConfig MapHoverConfig(uint hoverMode)
        {
            return new HoverConfig
            {
                Row = (hoverMode & 1u) != 0,
                Column = (hoverMode & 2u) != 0,
                Cell = (hoverMode & 4u) != 0,
            };
        }

        private static uint UnmapHoverConfig(HoverConfig hover)
        {
            uint mode = 0;
            if (hover != null)
            {
                if (hover.HasRow && hover.Row) mode |= 1u;
                if (hover.HasColumn && hover.Column) mode |= 2u;
                if (hover.HasCell && hover.Cell) mode |= 4u;
            }
            return mode;
        }

        private static ResizePolicy MapResizePolicy(VolvoxResizePolicyMode mode)
        {
            bool columns;
            bool rows;
            bool uniform;
            DecodeResizePolicyMode(mode, out columns, out rows, out uniform);
            return new ResizePolicy
            {
                Columns = columns,
                Rows = rows,
                Uniform = uniform,
            };
        }

        private static VolvoxResizePolicyMode UnmapResizePolicy(ResizePolicy policy)
        {
            bool columns = policy != null && policy.HasColumns && policy.Columns;
            bool rows = policy != null && policy.HasRows && policy.Rows;
            bool uniform = policy != null && policy.HasUniform && policy.Uniform;
            return EncodeResizePolicyMode(columns, rows, uniform);
        }

        private static HeaderFeatures MapHeaderFeatures(VolvoxHeaderFeatures features)
        {
            int bits = (int)features;
            return new HeaderFeatures
            {
                Sort = (bits & 1) != 0,
                Reorder = (bits & 2) != 0,
                Chooser = (bits & 4) != 0,
            };
        }

        private static VolvoxHeaderFeatures UnmapHeaderFeatures(HeaderFeatures features)
        {
            int bits = 0;
            if (features != null)
            {
                if (features.HasSort && features.Sort) bits |= 1;
                if (features.HasReorder && features.Reorder) bits |= 2;
                if (features.HasChooser && features.Chooser) bits |= 4;
            }
            return (VolvoxHeaderFeatures)bits;
        }

        private static void DecodeResizePolicyMode(VolvoxResizePolicyMode mode, out bool columns, out bool rows, out bool uniform)
        {
            columns = false;
            rows = false;
            uniform = false;

            switch (mode)
            {
                case VolvoxResizePolicyMode.Columns:
                    columns = true;
                    break;
                case VolvoxResizePolicyMode.Rows:
                    rows = true;
                    break;
                case VolvoxResizePolicyMode.Both:
                    columns = true;
                    rows = true;
                    break;
                case VolvoxResizePolicyMode.ColumnsUniform:
                    columns = true;
                    uniform = true;
                    break;
                case VolvoxResizePolicyMode.RowsUniform:
                    rows = true;
                    uniform = true;
                    break;
                case VolvoxResizePolicyMode.BothUniform:
                    columns = true;
                    rows = true;
                    uniform = true;
                    break;
            }
        }

        private static VolvoxResizePolicyMode EncodeResizePolicyMode(bool columns, bool rows, bool uniform)
        {
            if (columns && rows) return uniform ? VolvoxResizePolicyMode.BothUniform : VolvoxResizePolicyMode.Both;
            if (columns) return uniform ? VolvoxResizePolicyMode.ColumnsUniform : VolvoxResizePolicyMode.Columns;
            if (rows) return uniform ? VolvoxResizePolicyMode.RowsUniform : VolvoxResizePolicyMode.Rows;
            return VolvoxResizePolicyMode.None;
        }

        private static Border UnmapFirstBorder(Borders borders)
        {
            if (borders == null) return null;
            return borders.All ?? borders.Top ?? borders.Right ?? borders.Bottom ?? borders.Left;
        }

        private CellStyle MapCellStyle(VolvoxCellStylePatch s)
        {
            var res = new CellStyle();
            if (s.BackColor.HasValue) res.Background = s.BackColor.Value;
            if (s.ForeColor.HasValue) res.Foreground = s.ForeColor.Value;
            if (s.Alignment.HasValue) res.Align = (Align)s.Alignment.Value;
            if (s.TextEffect.HasValue) res.TextEffect = (TextEffect)s.TextEffect.Value;
            if (s.ProgressColor.HasValue) res.ProgressColor = s.ProgressColor.Value;
            if (s.ProgressPercent.HasValue) res.Progress = s.ProgressPercent.Value;
            if (s.FontName != null || s.FontSize.HasValue || s.FontBold.HasValue || s.FontItalic.HasValue || s.FontUnderline.HasValue || s.FontStrikethrough.HasValue || s.FontWidth.HasValue)
            {
                var font = new Font();
                if (s.FontName != null) font.Family = s.FontName;
                if (s.FontSize.HasValue) font.Size = s.FontSize.Value;
                if (s.FontBold.HasValue) font.Bold = s.FontBold.Value;
                if (s.FontItalic.HasValue) font.Italic = s.FontItalic.Value;
                if (s.FontUnderline.HasValue) font.Underline = s.FontUnderline.Value;
                if (s.FontStrikethrough.HasValue) font.Strikethrough = s.FontStrikethrough.Value;
                if (s.FontWidth.HasValue) font.Width = s.FontWidth.Value;
                res.Font = font;
            }
            if (s.Border.HasValue || s.BorderColor.HasValue)
            {
                var border = new Border();
                if (s.Border.HasValue) border.Style = (BorderStyle)s.Border.Value;
                if (s.BorderColor.HasValue) border.Color = s.BorderColor.Value;
                res.Borders = new Borders { All = border };
            }
            return res;
        }

        private VolvoxCellStylePatch UnmapCellStyle(CellStyle s)
        {
            var result = new VolvoxCellStylePatch
            {
                BackColor = s.HasBackground ? (uint?)s.Background : null,
                ForeColor = s.HasForeground ? (uint?)s.Foreground : null,
                Alignment = s.HasAlign ? (VolvoxAlign?)s.Align : null,
                TextEffect = s.HasTextEffect ? (VolvoxTextEffect?)s.TextEffect : null,
                FontName = s.Font != null && s.Font.HasFamily ? s.Font.Family : null,
                FontSize = s.Font != null && s.Font.HasSize ? (float?)s.Font.Size : null,
                FontBold = s.Font != null && s.Font.HasBold ? (bool?)s.Font.Bold : null,
                FontItalic = s.Font != null && s.Font.HasItalic ? (bool?)s.Font.Italic : null,
                FontUnderline = s.Font != null && s.Font.HasUnderline ? (bool?)s.Font.Underline : null,
                FontStrikethrough = s.Font != null && s.Font.HasStrikethrough ? (bool?)s.Font.Strikethrough : null,
                FontWidth = s.Font != null && s.Font.HasWidth ? (float?)s.Font.Width : null,
                ProgressColor = s.HasProgressColor ? (uint?)s.ProgressColor : null,
                ProgressPercent = s.HasProgress ? (float?)s.Progress : null,
            };

            var border = UnmapFirstBorder(s.Borders);
            if (border != null)
            {
                result.Border = border.HasStyle ? (VolvoxBorderStyle?)border.Style : null;
                result.BorderColor = border.HasColor ? (uint?)border.Color : null;
            }

            return result;
        }

        private static CellValue ToProtoCellValue(VolvoxCellValueData value)
        {
            var cell = new CellValue();
            switch (value.Kind)
            {
                case VolvoxCellValueKind.Boolean: cell.Flag = value.BoolValue; break;
                case VolvoxCellValueKind.Number: cell.Number = value.NumberValue; break;
                case VolvoxCellValueKind.Bytes: cell.Data = ByteString.CopyFrom(value.BytesValue ?? Array.Empty<byte>()); break;
                case VolvoxCellValueKind.Timestamp: cell.Timestamp = value.TimestampValue; break;
                default: cell.Text = value.TextValue ?? string.Empty; break;
            }
            return cell;
        }

        private static VolvoxCellValueData FromProtoCellValue(CellValue v)
        {
            var data = new VolvoxCellValueData();
            switch (v.ValueCase)
            {
                case CellValue.ValueOneofCase.Text: data.Kind = VolvoxCellValueKind.Text; data.TextValue = v.Text; break;
                case CellValue.ValueOneofCase.Number: data.Kind = VolvoxCellValueKind.Number; data.NumberValue = v.Number; break;
                case CellValue.ValueOneofCase.Flag: data.Kind = VolvoxCellValueKind.Boolean; data.BoolValue = v.Flag; break;
                case CellValue.ValueOneofCase.Data: data.Kind = VolvoxCellValueKind.Bytes; data.BytesValue = v.Data.ToByteArray(); break;
                case CellValue.ValueOneofCase.Timestamp: data.Kind = VolvoxCellValueKind.Timestamp; data.TimestampValue = v.Timestamp; break;
            }
            return data;
        }
    }
}
