using System;
using System.Buffers;
using System.Collections.Generic;
using System.Globalization;
using System.Text;
using VolvoxGrid.DotNet;
using Volvoxgrid.V1;

namespace VolvoxGrid.DotNet.TuiSample
{
    internal static partial class Program
    {
        private const string ActionQuit = "quit";
        private const string ActionSwitchSales = "switch-sales";
        private const string ActionSwitchHierarchy = "switch-hierarchy";
        private const string ActionSwitchStress = "switch-stress";

        private sealed class SearchState
        {
            public bool PromptActive;
            public string Prompt = string.Empty;
            public string LastQuery = string.Empty;
            public SearchResult LastResult;
            public string Status = string.Empty;
        }

        private sealed class SearchResult
        {
            public int Row;
            public int Col;
        }

        private sealed class DemoController : IDisposable, IVolvoxGridTerminalController, IVolvoxGridTerminalHostInputHandler, IVolvoxGridTerminalDebugPanelProvider
        {
            private readonly Dictionary<DemoKind, DemoInstance> _instances = new Dictionary<DemoKind, DemoInstance>();
            private readonly SearchState _search = new SearchState();
            private DemoKind _currentDemo;
            private DemoKind? _activeDemo;
            private VolvoxGridTerminalSession _session;
            private bool _debugPanel;

            public DemoController(DemoKind demo)
            {
                _currentDemo = demo;
            }

            public void Dispose()
            {
                if (_session != null)
                {
                    _session.Dispose();
                    _session = null;
                }
                foreach (KeyValuePair<DemoKind, DemoInstance> entry in _instances)
                {
                    entry.Value.Dispose();
                }
                _instances.Clear();
            }

            public VolvoxGridTerminalSession EnsureSession(int viewportWidth, int viewportHeight)
            {
                if (_session != null && _activeDemo.HasValue && _activeDemo.Value == _currentDemo)
                {
                    return _session;
                }

                if (_session != null)
                {
                    _session.Dispose();
                    _session = null;
                }

                if (!_instances.TryGetValue(_currentDemo, out DemoInstance instance))
                {
                    instance = BuildDemo(_currentDemo, viewportWidth, viewportHeight);
                    SyncDebugPanelConfig(instance);
                    _instances[_currentDemo] = instance;
                }

                _session = instance.Client.OpenTerminalSession();
                _activeDemo = _currentDemo;
                return _session;
            }

            public EditState GetCurrentEditState()
            {
                DemoInstance instance = GetActiveInstance();
                return instance == null ? new EditState() : instance.Client.GetEditState();
            }

            public void CancelActiveEdit()
            {
                DemoInstance instance = GetActiveInstance();
                if (instance == null)
                {
                    return;
                }

                EditState state = instance.Client.GetEditState();
                if (state != null && state.Active)
                {
                    instance.Client.CancelEdit();
                }
            }

            public VolvoxGridTerminalActionOutcome HandleAction(string action, int viewportWidth, int viewportHeight)
            {
                switch (action)
                {
                    case ActionQuit:
                        return new VolvoxGridTerminalActionOutcome { Quit = true };
                    case ActionSwitchSales:
                        return SwitchDemo(DemoKind.Sales);
                    case ActionSwitchHierarchy:
                        return SwitchDemo(DemoKind.Hierarchy);
                    case ActionSwitchStress:
                        return SwitchDemo(DemoKind.Stress);
                    default:
                        return new VolvoxGridTerminalActionOutcome();
                }
            }

            public VolvoxGridTerminalHostInputOutcome HandleHostInput(
                byte[] input,
                EditState editState,
                int viewportWidth,
                int viewportHeight)
            {
                if (_search.PromptActive)
                {
                    return HandleSearchPromptInput(input);
                }
                if (editState != null && editState.Active)
                {
                    return new VolvoxGridTerminalHostInputOutcome { ForwardedInput = input ?? Array.Empty<byte>() };
                }
                if (input == null || input.Length == 0 || HasEscapeByte(input) || input.Length != 1)
                {
                    return new VolvoxGridTerminalHostInputOutcome { ForwardedInput = input ?? Array.Empty<byte>() };
                }

                switch (input[0])
                {
                    case (byte)'/':
                        _search.PromptActive = true;
                        _search.Prompt = string.Empty;
                        _search.Status = "Search";
                        return new VolvoxGridTerminalHostInputOutcome { ChromeDirty = true, Render = true };
                    case (byte)'n':
                        RunSearch(forward: true, repeat: true);
                        return new VolvoxGridTerminalHostInputOutcome { ChromeDirty = true, Render = true };
                    case (byte)'N':
                        RunSearch(forward: false, repeat: true);
                        return new VolvoxGridTerminalHostInputOutcome { ChromeDirty = true, Render = true };
                    default:
                        return new VolvoxGridTerminalHostInputOutcome { ForwardedInput = input };
                }
            }

            public void DrawChrome(VolvoxGridTerminalHost terminal, int width, int height, string mode)
            {
                string header = PadLine(" VolvoxGrid TUI  |  Demo: " + DemoTitle(_currentDemo), width);
                string footer = PadLine(FooterText(mode), width);

                StringBuilder builder = new StringBuilder(width * 2 + 64);
                builder.Append("\x1b[1;1H\x1b[0m");
                builder.Append(header);
                builder.Append("\x1b[").Append(height).Append(";1H\x1b[0m");
                builder.Append(footer);
                terminal.WriteText(builder.ToString());
            }

            public bool DebugPanelVisible
            {
                get { return _debugPanel; }
            }

            public int DebugPanelRows
            {
                get { return 5; }
            }

            public void ToggleDebugPanel()
            {
                _debugPanel = !_debugPanel;
                SyncDebugPanelConfig(GetActiveInstance());
            }

            public IList<string> GetDebugPanelLines(VolvoxGridTerminalDebugPanelContext context)
            {
                DemoInstance instance = GetActiveInstance();
                string selectionText = "--";
                string topText = "--";
                string bottomText = "--";
                string mouseText = "--";
                string activeColumn = "--";
                long gridId = 0L;
                int rowCount = 0;
                int colCount = 0;
                string selectionSpan = "--";
                string searchStatus = string.IsNullOrEmpty(_search.Status) ? "none" : _search.Status;
                string searchQuery = DebugCompactText(_search.PromptActive ? _search.Prompt : _search.LastQuery, 24);
                string searchHit = DebugSearchResultLabel(_search.LastResult);
                if (instance != null && instance.Client != null)
                {
                    SelectionState selection = instance.Client.GetSelection();
                    selectionText = DebugCellLabel(selection.ActiveRow, selection.ActiveCol);
                    topText = DebugCellLabel(selection.TopRow, selection.LeftCol);
                    bottomText = DebugCellLabel(selection.BottomRow, selection.RightCol);
                    mouseText = DebugCellLabel(selection.MouseRow, selection.MouseCol);
                    selectionSpan = DebugSelectionSpanLabel(selection);
                    if (selection.ActiveCol >= 0)
                    {
                        activeColumn = DebugCompactText(instance.ColumnLabel(selection.ActiveCol), 18);
                    }
                    gridId = instance.Client.GridId;
                    rowCount = instance.Rows;
                    colCount = instance.Columns == null ? 0 : instance.Columns.Count;
                }
                return new List<string>
                {
                    string.Format(
                        CultureInfo.InvariantCulture,
                        " DBG cur={0} active={1} cache={2} | grid={3} session={4} | mode={5} | term={6}{7}{8}{9} | size={10}x{11} vp={12}",
                        DemoTitle(_currentDemo),
                        DebugActiveDemoLabel(_activeDemo),
                        _instances.Count,
                        gridId,
                        DebugSessionState(_session, _activeDemo, _currentDemo),
                        DebugModeLabel(context == null ? null : context.Mode),
                        DebugColorLevel(context == null ? null : context.Capabilities),
                        DebugFlag(context != null && context.Capabilities != null && context.Capabilities.SgrMouse, " mouse"),
                        DebugFlag(context != null && context.Capabilities != null && context.Capabilities.FocusEvents, " focus"),
                        DebugFlag(context != null && context.Capabilities != null && context.Capabilities.BracketedPaste, " paste"),
                        context == null ? 0 : context.Width,
                        context == null ? 0 : context.Height,
                        context == null ? 0 : context.ViewportHeight),
                    string.Format(
                        CultureInfo.InvariantCulture,
                        " FRAME kind={0} rendered={1} bytes={2} | DATA rows={3} cols={4} | sel={5}({6}) tl={7} br={8} span={9} mouse={10}",
                        DebugFrameKind(context == null ? null : context.Frame),
                        context != null && context.Frame != null && context.Frame.Rendered,
                        context == null || context.Frame == null ? 0 : context.Frame.BytesWritten,
                        rowCount,
                        colCount,
                        selectionText,
                        activeColumn,
                        topText,
                        bottomText,
                        selectionSpan,
                        mouseText),
                    string.Format(
                        CultureInfo.InvariantCulture,
                        " FIND prompt={0} query={1} hit={2} | status={3}",
                        _search.PromptActive,
                        searchQuery,
                        searchHit,
                        DebugCompactText(searchStatus, 40)),
                    string.Format(
                        CultureInfo.InvariantCulture,
                        " EDIT active={0} cell={1} ui={2} sel={3} composing={4} | text={5} | pre={6}",
                        DebugEditActive(context == null ? null : context.EditState),
                        DebugEditCellLabel(context == null ? null : context.EditState),
                        DebugEditUiMode(context == null ? null : context.EditState),
                        DebugEditSelectionLabel(context == null ? null : context.EditState),
                        DebugEditComposing(context == null ? null : context.EditState),
                        DebugEditTextLabel(context == null ? null : context.EditState),
                        DebugEditPreeditLabel(context == null ? null : context.EditState)),
                    string.Format(
                        CultureInfo.InvariantCulture,
                        " PERF host={0:0.0}ms {1:0}fps | eng={2} | inst={3} | layers={4} | zones={5}",
                        context == null ? 0.0 : context.RenderDuration.TotalMilliseconds,
                        context == null ? 0.0 : context.RenderFps,
                        DebugMetricsPerfLabel(context == null ? null : context.Frame),
                        DebugMetricsInstanceLabel(context == null ? null : context.Frame),
                        DebugMetricsLayerLabel(context == null ? null : context.Frame),
                        DebugMetricsZones(context == null ? null : context.Frame)),
                };
            }

            private DemoInstance GetActiveInstance()
            {
                if (!_activeDemo.HasValue)
                {
                    return null;
                }

                return _instances.TryGetValue(_activeDemo.Value, out DemoInstance instance) ? instance : null;
            }

            private void SyncDebugPanelConfig(DemoInstance instance)
            {
                if (instance == null || instance.Client == null)
                {
                    return;
                }
                instance.Client.Configure(new GridConfig
                {
                    Rendering = new RenderConfig
                    {
                        LayerProfiling = _debugPanel,
                    },
                });
            }

            private string FooterText(string mode)
            {
                if (_search.PromptActive)
                {
                    return " /"
                        + (_search.Prompt ?? string.Empty)
                        + "_  |  Enter search  Esc cancel  |  current: "
                        + DemoTitle(_currentDemo)
                        + "  |  mode: "
                        + (mode ?? "Ready");
                }

                string footer =
                    " hjkl Move  Enter/F2/i Edit  Ins AutoStart  F6 Sales  F7 Hierarchy  F8 Stress  F12 Debug  Ctrl+Q Quit"
                    + "  / Search  n/N Next/Prev  |  current: "
                    + DemoTitle(_currentDemo)
                    + "  |  mode: "
                    + (mode ?? "Ready");
                if (!string.IsNullOrEmpty(_search.Status))
                {
                    footer += "  |  " + _search.Status;
                }
                return footer;
            }

            private VolvoxGridTerminalHostInputOutcome HandleSearchPromptInput(byte[] input)
            {
                VolvoxGridTerminalHostInputOutcome result = new VolvoxGridTerminalHostInputOutcome
                {
                    ChromeDirty = true,
                    Render = true,
                };
                if (input == null || input.Length == 0)
                {
                    return result;
                }

                int index = 0;
                while (index < input.Length)
                {
                    byte value = input[index];
                    switch (value)
                    {
                        case 0x1B:
                            _search.PromptActive = false;
                            _search.Prompt = string.Empty;
                            _search.Status = "Search cancelled";
                            return result;
                        case 0x08:
                        case 0x7F:
                            _search.Prompt = TrimLastRune(_search.Prompt);
                            index += 1;
                            continue;
                        case (byte)'\r':
                        case (byte)'\n':
                            string query = (_search.Prompt ?? string.Empty).Trim();
                            _search.PromptActive = false;
                            _search.Prompt = string.Empty;
                            if (query.Length == 0)
                            {
                                _search.LastQuery = string.Empty;
                                _search.LastResult = null;
                                _search.Status = "Search cleared";
                                return result;
                            }
                            _search.LastQuery = query;
                            RunSearch(forward: true, repeat: false);
                            return result;
                        default:
                            if (value < 0x20)
                            {
                                index += 1;
                                continue;
                            }
                            OperationStatus status = Rune.DecodeFromUtf8(input.AsSpan(index), out Rune rune, out int consumed);
                            if (status != OperationStatus.Done || consumed <= 0)
                            {
                                index += 1;
                                continue;
                            }
                            _search.Prompt += rune.ToString();
                            index += consumed;
                            continue;
                    }
                }

                return result;
            }

            private void RunSearch(bool forward, bool repeat)
            {
                DemoInstance instance = GetActiveInstance();
                if (instance == null || instance.Client == null)
                {
                    _search.Status = "Search unavailable";
                    return;
                }

                string query = (_search.LastQuery ?? string.Empty).Trim();
                if (query.Length == 0)
                {
                    _search.Status = "Search: no active query";
                    return;
                }

                SelectionState selection = instance.Client.GetSelection();
                int startRow = selection.ActiveRow;
                int startCol = selection.ActiveCol;
                if (repeat && _search.LastResult != null)
                {
                    startRow = _search.LastResult.Row;
                    startCol = _search.LastResult.Col;
                }
                else if (forward)
                {
                    startCol -= 1;
                }
                else
                {
                    startCol += 1;
                }

                SearchResult match;
                bool wrapped;
                bool found = FindMatch(instance, query, forward, startRow, startCol, out match, out wrapped);
                if (!found || match == null)
                {
                    _search.LastResult = null;
                    _search.Status = "Search: no matches for \"" + query + "\"";
                    return;
                }

                instance.Client.SelectCell(match.Row, match.Col, true);
                _search.LastResult = match;

                string prefix = "Search";
                if (wrapped)
                {
                    prefix = forward
                        ? "Search hit bottom, continuing at top"
                        : "Search hit top, continuing at bottom";
                }
                _search.Status = prefix + ": " + instance.ColumnLabel(match.Col) + " row " + (match.Row + 1);
            }

            private bool FindMatch(
                DemoInstance instance,
                string query,
                bool forward,
                int startRow,
                int startCol,
                out SearchResult match,
                out bool wrapped)
            {
                wrapped = false;
                if (forward)
                {
                    if (FindMatchForward(instance, query, startRow, startCol, out match))
                    {
                        return true;
                    }
                    wrapped = FindMatchForward(instance, query, 0, -1, out match);
                    return wrapped;
                }

                if (FindMatchBackward(instance, query, startRow, startCol, out match))
                {
                    return true;
                }
                wrapped = FindMatchBackward(instance, query, instance.Rows - 1, instance.Columns.Count, out match);
                return wrapped;
            }

            private bool FindMatchForward(
                DemoInstance instance,
                string query,
                int startRow,
                int startCol,
                out SearchResult match)
            {
                match = null;
                if (instance.Rows <= 0)
                {
                    return false;
                }
                if (startRow < 0)
                {
                    startRow = 0;
                }
                if (startRow >= instance.Rows)
                {
                    return false;
                }

                List<int> cols = MatchingColumnsOnRow(instance, query, startRow);
                for (int i = 0; i < cols.Count; i += 1)
                {
                    if (cols[i] > startCol)
                    {
                        match = new SearchResult { Row = startRow, Col = cols[i] };
                        return true;
                    }
                }

                int row = instance.Client.FindByText(query, -1, startRow + 1, false, false);
                if (row < 0 || row >= instance.Rows)
                {
                    return false;
                }
                cols = MatchingColumnsOnRow(instance, query, row);
                if (cols.Count == 0)
                {
                    return false;
                }
                match = new SearchResult { Row = row, Col = cols[0] };
                return true;
            }

            private bool FindMatchBackward(
                DemoInstance instance,
                string query,
                int startRow,
                int startCol,
                out SearchResult match)
            {
                match = null;
                if (instance.Rows <= 0)
                {
                    return false;
                }
                if (startRow >= instance.Rows)
                {
                    startRow = instance.Rows - 1;
                }
                if (startRow < 0)
                {
                    return false;
                }

                List<int> cols = MatchingColumnsOnRow(instance, query, startRow);
                for (int index = cols.Count - 1; index >= 0; index -= 1)
                {
                    if (cols[index] < startCol)
                    {
                        match = new SearchResult { Row = startRow, Col = cols[index] };
                        return true;
                    }
                }

                SearchResult last = null;
                for (int row = 0; row < startRow;)
                {
                    int matchRow = instance.Client.FindByText(query, -1, row, false, false);
                    if (matchRow < 0 || matchRow >= startRow)
                    {
                        break;
                    }

                    List<int> matchCols = MatchingColumnsOnRow(instance, query, matchRow);
                    if (matchCols.Count > 0)
                    {
                        last = new SearchResult { Row = matchRow, Col = matchCols[matchCols.Count - 1] };
                    }
                    row = matchRow + 1;
                }

                match = last;
                return match != null;
            }

            private List<int> MatchingColumnsOnRow(DemoInstance instance, string query, int row)
            {
                List<int> matches = new List<int>(instance.Columns.Count);
                foreach (ColumnDef column in instance.Columns)
                {
                    if (column == null)
                    {
                        continue;
                    }
                    int matchRow = instance.Client.FindByText(query, column.Index, row, false, false);
                    if (matchRow == row)
                    {
                        matches.Add(column.Index);
                    }
                }
                return matches;
            }

            private VolvoxGridTerminalActionOutcome SwitchDemo(DemoKind nextDemo)
            {
                if (_currentDemo == nextDemo)
                {
                    return new VolvoxGridTerminalActionOutcome();
                }

                _currentDemo = nextDemo;
                _search.PromptActive = false;
                _search.Prompt = string.Empty;
                _search.LastResult = null;
                _search.Status = string.Empty;
                return new VolvoxGridTerminalActionOutcome { ChromeDirty = true };
            }
        }

        private static VolvoxGridTerminalRunOptions CreateRunOptions()
        {
            return new VolvoxGridTerminalRunOptions
            {
                Shortcuts = new List<VolvoxGridTerminalShortcut>
                {
                    new VolvoxGridTerminalShortcut { Action = ActionQuit, CtrlKey = 0x03 },
                    new VolvoxGridTerminalShortcut { Action = ActionQuit, CtrlKey = 0x11 },
                    new VolvoxGridTerminalShortcut { Action = ActionSwitchSales, FunctionKey = 6 },
                    new VolvoxGridTerminalShortcut { Action = ActionSwitchHierarchy, FunctionKey = 7 },
                    new VolvoxGridTerminalShortcut { Action = ActionSwitchStress, FunctionKey = 8 },
                },
            };
        }

        private static string PadLine(string text, int width)
        {
            string value = text ?? string.Empty;
            if (value.Length > width)
            {
                return value.Substring(0, width);
            }
            if (value.Length < width)
            {
                return value.PadRight(width);
            }
            return value;
        }

        private static string TrimLastRune(string text)
        {
            if (string.IsNullOrEmpty(text))
            {
                return string.Empty;
            }

            int length = text.Length;
            if (length >= 2 && char.IsLowSurrogate(text[length - 1]) && char.IsHighSurrogate(text[length - 2]))
            {
                return text.Substring(0, length - 2);
            }
            return text.Substring(0, length - 1);
        }

        private static bool HasEscapeByte(byte[] data)
        {
            if (data == null)
            {
                return false;
            }

            for (int i = 0; i < data.Length; i += 1)
            {
                if (data[i] == 0x1B)
                {
                    return true;
                }
            }
            return false;
        }

        private static string DebugColorLevel(VolvoxGridTerminalCapabilities capabilities)
        {
            if (capabilities == null)
            {
                return "AUTO";
            }
            switch (capabilities.ColorLevel)
            {
                case VolvoxGridTerminalColorLevel.Truecolor:
                    return "TC";
                case VolvoxGridTerminalColorLevel.Indexed256:
                    return "256";
                case VolvoxGridTerminalColorLevel.Ansi16:
                    return "16";
                default:
                    return "AUTO";
            }
        }

        private static string DebugCellLabel(int row, int col)
        {
            if (row < 0 || col < 0)
            {
                return "--";
            }
            return "R" + (row + 1) + "C" + (col + 1);
        }

        private static string DebugFlag(bool enabled, string label)
        {
            return enabled ? label : string.Empty;
        }

        private static string DebugSessionState(
            VolvoxGridTerminalSession session,
            DemoKind? activeDemo,
            DemoKind currentDemo)
        {
            if (session == null)
            {
                return "none";
            }
            if (!activeDemo.HasValue || activeDemo.Value != currentDemo)
            {
                return "stale";
            }
            return "live";
        }

        private static string DebugActiveDemoLabel(DemoKind? activeDemo)
        {
            return activeDemo.HasValue ? DemoTitle(activeDemo.Value) : "--";
        }

        private static string DebugModeLabel(string mode)
        {
            return string.IsNullOrWhiteSpace(mode) ? "Ready" : mode;
        }

        private static string DebugSelectionSpanLabel(SelectionState selection)
        {
            if (selection == null)
            {
                return "--";
            }
            int rows = selection.BottomRow - selection.TopRow + 1;
            int cols = selection.RightCol - selection.LeftCol + 1;
            if (rows <= 0 || cols <= 0)
            {
                return "--";
            }
            return rows.ToString(CultureInfo.InvariantCulture)
                + "x"
                + cols.ToString(CultureInfo.InvariantCulture);
        }

        private static string DebugSearchResultLabel(SearchResult result)
        {
            return result == null ? "--" : DebugCellLabel(result.Row, result.Col);
        }

        private static string DebugCompactText(string text, int limit)
        {
            string clean = (text ?? string.Empty).Replace('\n', ' ').Replace('\r', ' ').Trim();
            if (clean.Length == 0)
            {
                return "\"\"";
            }
            if (clean.Length <= limit || limit <= 1)
            {
                return "\"" + clean + "\"";
            }
            if (limit <= 3)
            {
                return "\"" + clean.Substring(0, limit) + "\"";
            }
            return "\"" + clean.Substring(0, limit - 3) + "...\"";
        }

        private static bool DebugEditActive(EditState state)
        {
            return state != null && state.Active;
        }

        private static string DebugEditCellLabel(EditState state)
        {
            if (!DebugEditActive(state))
            {
                return "--";
            }
            return DebugCellLabel(state.Row, state.Col);
        }

        private static string DebugEditSelectionLabel(EditState state)
        {
            if (!DebugEditActive(state))
            {
                return "--";
            }
            return state.SelStart.ToString(CultureInfo.InvariantCulture)
                + "+"
                + state.SelLength.ToString(CultureInfo.InvariantCulture);
        }

        private static bool DebugEditComposing(EditState state)
        {
            return state != null && state.Composing;
        }

        private static string DebugEditUiMode(EditState state)
        {
            if (!DebugEditActive(state))
            {
                return "--";
            }
            return state.UiMode == EditUiMode.EDIT_UI_MODE_EDIT ? "EDIT" : "ENTER";
        }

        private static string DebugEditTextLabel(EditState state)
        {
            return !DebugEditActive(state) ? "--" : DebugCompactText(state.Text, 20);
        }

        private static string DebugEditPreeditLabel(EditState state)
        {
            return !DebugEditActive(state) ? "--" : DebugCompactText(state.PreeditText, 16);
        }

        private static string DebugFrameKind(VolvoxGridTerminalFrame frame)
        {
            if (frame == null)
            {
                return "NONE";
            }
            switch (frame.Kind)
            {
                case VolvoxGridTerminalRenderKind.SessionStart:
                    return "START";
                case VolvoxGridTerminalRenderKind.SessionEnd:
                    return "END";
                default:
                    return "FRAME";
            }
        }

        private static float DebugMetricsFrameMs(VolvoxGridTerminalFrame frame)
        {
            return frame == null || frame.Metrics == null ? 0f : frame.Metrics.FrameTimeMs;
        }

        private static string DebugMetricsPerfLabel(VolvoxGridTerminalFrame frame)
        {
            if (frame == null || frame.Metrics == null)
            {
                return "n/a";
            }
            return string.Format(CultureInfo.InvariantCulture, "{0:0.0}ms {1:0}fps", frame.Metrics.FrameTimeMs, frame.Metrics.Fps);
        }

        private static float DebugMetricsFps(VolvoxGridTerminalFrame frame)
        {
            return frame == null || frame.Metrics == null ? 0f : frame.Metrics.Fps;
        }

        private static string DebugMetricsInstanceLabel(VolvoxGridTerminalFrame frame)
        {
            if (frame == null || frame.Metrics == null)
            {
                return "--";
            }
            return frame.Metrics.InstanceCount.ToString(CultureInfo.InvariantCulture);
        }

        private static int DebugMetricsInstanceCount(VolvoxGridTerminalFrame frame)
        {
            return frame == null || frame.Metrics == null ? 0 : frame.Metrics.InstanceCount;
        }

        private static string DebugMetricsLayerLabel(VolvoxGridTerminalFrame frame)
        {
            if (frame == null || frame.Metrics == null)
            {
                return "--";
            }
            return string.Format(CultureInfo.InvariantCulture, "{0:0}us", DebugMetricsLayerTotalUs(frame));
        }

        private static float DebugMetricsLayerTotalUs(VolvoxGridTerminalFrame frame)
        {
            if (frame == null || frame.Metrics == null || frame.Metrics.LayerTimesUs == null)
            {
                return 0f;
            }
            float total = 0f;
            for (int i = 0; i < frame.Metrics.LayerTimesUs.Count; i += 1)
            {
                total += frame.Metrics.LayerTimesUs[i];
            }
            return total;
        }

        private static string DebugMetricsZones(VolvoxGridTerminalFrame frame)
        {
            if (frame == null || frame.Metrics == null || frame.Metrics.ZoneCellCounts == null || frame.Metrics.ZoneCellCounts.Count < 4)
            {
                return "--";
            }
            return string.Format(
                CultureInfo.InvariantCulture,
                "{0}/{1}/{2}/{3}",
                frame.Metrics.ZoneCellCounts[0],
                frame.Metrics.ZoneCellCounts[1],
                frame.Metrics.ZoneCellCounts[2],
                frame.Metrics.ZoneCellCounts[3]);
        }
    }
}
