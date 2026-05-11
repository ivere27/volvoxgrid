using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.Drawing.Text;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;
using Volvoxgrid.V1;

namespace VolvoxGrid.DotNet.Internal
{
    internal sealed class RenderHostCpu : Control
    {
        private const int WmMouseHWheel = 0x020E;
        private const int WmImeStartComposition = 0x010D;
        private const int WmImeComposition = 0x010F;
        private const int WmImeEndComposition = 0x010E;
        private const int WmImeChar = 0x0286;
        private const int GcsCompStr = 0x0008;
        private const int GcsResultStr = 0x0800;
        private const uint NativeSurfaceKindWin32 = 3;
        private const float WheelScrollGain = 3.0f;
        private const float HostFlingImpulseGain = 0.75f;
        private const float HostFlingDamping = 0.86f;
        private const float HostFlingMinVelocity = 0.08f;
        private const float HostFlingMaxVelocity = 36.0f;
        private const int HostFlingFrameMillis = 16;
        private const long FramePacingConfigRefreshMs = 250;
        private static readonly Color EditOverlayBorderColor = Color.FromArgb(0x2D, 0x6C, 0xDF);
        private static readonly string[] ImeFriendlyFontFamilies = new[]
        {
            "Noto Sans CJK KR",
            "Noto Sans CJK JP",
            "Noto Sans CJK SC",
            "Noto Sans CJK TC",
            "Noto Sans CJK HK",
            "NanumGothic",
            "Malgun Gothic",
            "Microsoft YaHei UI",
            "Microsoft YaHei",
            "Meiryo UI",
            "Meiryo",
            "Droid Sans Fallback",
            "Arial Unicode MS",
            "DejaVu Sans",
        };
        private static readonly object InstalledFontFamiliesSync = new object();
        private static HashSet<string> _installedFontFamilies;

        private readonly object _sendLock = new object();
        private readonly object _frameLock = new object();

        private VolvoxClient _client;
        private long _gridId;
        private Func<GridEvent, bool?> _eventHandler;
        private Func<GridEvent, int?> _compareHandler;

        private SynurangReflectionStream _renderStream;
        private SynurangReflectionStream _eventStream;
        private Thread _renderThread;
        private Thread _eventThread;

        private bool _running;
        private bool _pendingFrame;
        private bool _followupFrame;
        private bool _decisionChannelRequested;
        private bool _decisionChannelHandshakeSent;
        private FramePacingMode _framePacingMode = FramePacingMode.FRAME_PACING_MODE_PLATFORM;
        private long _framePacingConfigLastRefreshTick;
        private RendererMode _rendererMode = RendererMode.RENDERER_CPU;
        private IntPtr _gpuSurfaceDescriptor;
        private IntPtr _gpuSurfaceWindow;

        private byte[] _pixelBuffer;
        private byte[] _blitBuffer;
        private GCHandle _pixelBufferHandle;
        private Bitmap _bitmap;
        private int _bufferWidth;
        private int _bufferHeight;
        private readonly List<RetiredBuffers> _retiredBuffers = new List<RetiredBuffers>();
        private readonly Panel _editOverlayHost;
        private readonly TextBox _editOverlay;
        private Volvoxgrid.V1.SelectionMode _selectionMode = Volvoxgrid.V1.SelectionMode.SELECTION_FREE;
        private bool _engineEditing;
        private CursorType _engineCursorType = CursorType.CURSOR_DEFAULT;
        private bool _suppressEditOverlayTextChanged;
        private bool _suppressEditOverlayCommit;
        private int _editOverlayRow = -1;
        private int _editOverlayCol = -1;
        private EditUiMode _editOverlayUiMode = EditUiMode.EDIT_UI_MODE_ENTER;
        private bool _multiRangeDragActive;
        private readonly List<CellRange> _multiRangeBaseRanges = new List<CellRange>();
        private int _multiRangeAnchorRow = -1;
        private int _multiRangeAnchorCol = -1;
        private int _multiRangeDragRow = -1;
        private int _multiRangeDragCol = -1;
        private System.Drawing.Font _editOverlayResolvedFont;
        private string _editOverlayResolvedFontFamily = string.Empty;
        private float _editOverlayResolvedFontSize;
        private FontStyle _editOverlayResolvedFontStyle;
        private GraphicsUnit _editOverlayResolvedFontUnit;
        private readonly object _flingLock = new object();
        private Thread _flingThread;
        private bool _hostFlingEnabled = true;
        private bool _flingActive;
        private float _flingVelocityX;
        private float _flingVelocityY;

        internal Func<int, int, HorizontalAlignment> ResolveEditAlignment { get; set; }
        internal Func<int, int, System.Windows.Forms.Padding> ResolveEditPadding { get; set; }

        private static PointerEvent_Type PointerDownEvent
        {
            get
            {
                return PointerEvent_Type.DOWN;
            }
        }

        private static PointerEvent_Type PointerUpEvent
        {
            get
            {
                return PointerEvent_Type.UP;
            }
        }

        private static PointerEvent_Type PointerMoveEvent
        {
            get
            {
                return PointerEvent_Type.MOVE;
            }
        }

        private static KeyEvent_Type KeyDownEvent
        {
            get
            {
                return KeyEvent_Type.KEY_DOWN;
            }
        }

        private static KeyEvent_Type KeyUpEvent
        {
            get
            {
                return KeyEvent_Type.KEY_UP;
            }
        }

        private static KeyEvent_Type KeyPressEvent
        {
            get
            {
                return KeyEvent_Type.KEY_PRESS;
            }
        }

        [DllImport("imm32.dll")]
        private static extern IntPtr ImmGetContext(IntPtr hWnd);

        [DllImport("imm32.dll")]
        private static extern bool ImmReleaseContext(IntPtr hWnd, IntPtr hImc);

        [DllImport("imm32.dll", CharSet = CharSet.Unicode)]
        private static extern int ImmGetCompositionString(IntPtr hImc, int dwIndex, byte[] lpBuf, int dwBufLen);

        public RenderHostCpu()
        {
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.UserPaint, true);
            TabStop = true;
            BackColor = Color.White;

            _editOverlayHost = new Panel
            {
                Visible = false,
                BackColor = Color.White,
                Margin = System.Windows.Forms.Padding.Empty,
                Padding = System.Windows.Forms.Padding.Empty,
                TabStop = false,
            };
            _editOverlayHost.Paint += EditOverlayHost_Paint;

            _editOverlay = new TextBox
            {
                Visible = true,
                Multiline = true,
                AutoSize = false,
                BorderStyle = System.Windows.Forms.BorderStyle.None,
                AcceptsReturn = false,
                AcceptsTab = false,
                WordWrap = false,
                ScrollBars = ScrollBars.None,
                ShortcutsEnabled = true,
                ImeMode = ImeMode.On,
                Margin = System.Windows.Forms.Padding.Empty,
            };
            _editOverlay.TextChanged += EditOverlay_TextChanged;
            _editOverlay.KeyDown += EditOverlay_KeyDown;
            _editOverlay.KeyUp += EditOverlay_SelectionChanged;
            _editOverlay.MouseUp += EditOverlay_SelectionChanged;
            _editOverlay.LostFocus += EditOverlay_LostFocus;
            _editOverlayHost.Controls.Add(_editOverlay);
            Controls.Add(_editOverlayHost);
        }

        public bool HostFlingEnabled
        {
            get
            {
                lock (_flingLock)
                {
                    return _hostFlingEnabled;
                }
            }
            set
            {
                lock (_flingLock)
                {
                    _hostFlingEnabled = value;
                }
                if (!value)
                {
                    StopHostFling();
                }
            }
        }

        public bool IsGpuSupported
        {
            get
            {
                return _client != null
                    && _client.SupportsGpuRenderer
                    && _client.SupportsNativeSurfaceDescriptor
                    && IsWindowsPlatform();
            }
        }

        public void SetRendererMode(VolvoxGridRendererMode mode)
        {
            RendererMode mapped = (RendererMode)mode;
            bool wasGpuActive = IsGpuRendererMode(_rendererMode);
            bool nextGpuActive = IsGpuRendererMode(mapped);

            _rendererMode = mapped;

            if (wasGpuActive && !nextGpuActive)
            {
                SendGpuSurfaceDestroyed();
                ReleaseGpuSurfaceDescriptor();
                ResizeBuffers(Math.Max(1, ClientSize.Width), Math.Max(1, ClientSize.Height));
            }

            RequestFrame();
        }

        public void CancelHostFling()
        {
            StopHostFling();
        }

        protected override bool IsInputKey(Keys keyData)
        {
            switch (keyData & Keys.KeyCode)
            {
                case Keys.Left:
                case Keys.Right:
                case Keys.Up:
                case Keys.Down:
                case Keys.Enter:
                case Keys.Escape:
                case Keys.Tab:
                case Keys.Home:
                case Keys.End:
                case Keys.PageUp:
                case Keys.PageDown:
                    return true;
                default:
                    return base.IsInputKey(keyData);
            }
        }

        public Volvoxgrid.V1.SelectionMode SelectionMode
        {
            get { return _selectionMode; }
            set
            {
                _selectionMode = value;
                if (value != Volvoxgrid.V1.SelectionMode.SELECTION_MULTI_RANGE)
                {
                    ClearMultiRangeDrag();
                }
            }
        }

        public void Attach(
            VolvoxClient client,
            long gridId,
            Func<GridEvent, bool?> eventHandler,
            Func<GridEvent, int?> compareHandler = null)
        {
            if (client == null)
            {
                throw new ArgumentNullException("client");
            }

            Detach();

            _client = client;
            _gridId = gridId;
            _eventHandler = eventHandler;
            _compareHandler = compareHandler;

            ResizeBuffers(Math.Max(1, ClientSize.Width), Math.Max(1, ClientSize.Height));

            _renderStream = _client.OpenRenderSession();
            _eventStream = _client.OpenEventStream(gridId);

            _running = true;
            _decisionChannelHandshakeSent = false;
            EnsureDecisionChannelEnabled();
            StartRenderThread();
            StartEventThread();
            RequestFrame();
        }

        public bool Detach()
        {
            _running = false;
            _pendingFrame = false;
            _followupFrame = false;
            _decisionChannelHandshakeSent = false;
            StopHostFling();
            _framePacingConfigLastRefreshTick = 0;
            ClearMultiRangeDrag();

            var renderStream = _renderStream;
            var eventStream = _eventStream;
            var renderThread = _renderThread;
            var eventThread = _eventThread;

            _renderStream = null;
            _eventStream = null;

            try
            {
                renderStream?.CloseSend();
            }
            catch
            {
                // Best effort.
            }

            try
            {
                eventStream?.CloseSend();
            }
            catch
            {
                // Best effort.
            }

            try
            {
                renderStream?.Dispose();
            }
            catch
            {
                // Best effort.
            }

            try
            {
                eventStream?.Dispose();
            }
            catch
            {
                // Best effort.
            }

            bool renderStopped = TryJoinThread(renderThread, 2000);
            bool eventStopped = TryJoinThread(eventThread, 2000);
            if (!renderStopped)
            {
                Debug.WriteLine("Volvox Detach: render thread did not stop before timeout.");
            }
            if (!eventStopped)
            {
                Debug.WriteLine("Volvox Detach: event thread did not stop before timeout.");
            }

            _renderThread = null;
            _eventThread = null;
            _eventHandler = null;
            _compareHandler = null;
            ReleaseGpuSurfaceDescriptor();
            HideEditOverlay(false);
            return renderStopped && eventStopped;
        }

        public void RequestFrame()
        {
            if (!_running || _client == null || _renderStream == null || _gridId == 0)
            {
                return;
            }

            lock (_frameLock)
            {
                if (_pendingFrame)
                {
                    _followupFrame = true;
                    return;
                }

                _pendingFrame = true;
            }

            SendFrameReady();
        }

        public void EnableEventDecisionChannel()
        {
            _decisionChannelRequested = true;
            EnsureDecisionChannelEnabled();
        }

        public void SendEventDecision(long eventId, bool cancel)
        {
            if (!_running || _client == null || _renderStream == null || _gridId == 0 || eventId == 0)
            {
                return;
            }

            var payload = _client.EncodeRenderInputEventDecision(_gridId, eventId, cancel);
            SendRenderInput(payload);
            RequestFrame();
        }

        public void SendCompareResponse(long requestId, int result)
        {
            if (!_running || _client == null || _renderStream == null || _gridId == 0 || requestId == 0)
            {
                return;
            }

            var payload = _client.EncodeRenderInputCompareResponse(_gridId, requestId, result);
            SendRenderInput(payload);
        }

        private void EnsureDecisionChannelEnabled()
        {
            if (!_decisionChannelRequested
                || _decisionChannelHandshakeSent
                || !_running
                || _client == null
                || _renderStream == null
                || _gridId == 0)
            {
                return;
            }

            var payload = _client.EncodeRenderInputEventDecision(_gridId, 0, false);
            SendRenderInput(payload);
            _decisionChannelHandshakeSent = true;
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing)
            {
                Detach();
                ReleaseBuffers();
                ResetEditOverlayResolvedFont();
            }

            base.Dispose(disposing);
        }

        protected override void OnHandleDestroyed(EventArgs e)
        {
            SendGpuSurfaceDestroyed();
            ReleaseGpuSurfaceDescriptor();
            base.OnHandleDestroyed(e);
        }

        protected override void OnResize(EventArgs e)
        {
            base.OnResize(e);

            if (_client == null || _gridId == 0)
            {
                return;
            }

            int width = Math.Max(1, ClientSize.Width);
            int height = Math.Max(1, ClientSize.Height);

            // Wine/WinForms can raise redundant resize/layout notifications
            // without an actual size change; don't turn those into clean
            // viewport resizes and follow-up render requests.
            if (width == _bufferWidth && height == _bufferHeight)
            {
                return;
            }

            if (!IsGpuRenderActive())
            {
                ResizeBuffers(width, height);
            }
            _client.ResizeViewport(_gridId, width, height);
            RequestFrame();
        }

        protected override void OnMouseDown(MouseEventArgs e)
        {
            base.OnMouseDown(e);
            Focus();
            if (TryBeginMultiRangeSelection(e))
            {
                RequestFrame();
                return;
            }
            SendPointer(PointerDownEvent, e, e.Clicks >= 2);
            RequestFrame();
        }

        protected override void OnMouseUp(MouseEventArgs e)
        {
            base.OnMouseUp(e);
            if (_multiRangeDragActive)
            {
                TryUpdateMultiRangeSelection(e);
                ClearMultiRangeDrag();
                RequestFrame();
                return;
            }
            SendPointer(PointerUpEvent, e, false);
            RequestFrame();
        }

        protected override void OnMouseMove(MouseEventArgs e)
        {
            base.OnMouseMove(e);
            if (_multiRangeDragActive)
            {
                if (TryUpdateMultiRangeSelection(e))
                {
                    RequestFrame();
                }
                return;
            }
            SendPointer(PointerMoveEvent, e, false);
            RequestFrame();
        }

        protected override void OnMouseWheel(MouseEventArgs e)
        {
            base.OnMouseWheel(e);
            bool horizontal = (ModifierKeys & Keys.Shift) == Keys.Shift;
            float dy = horizontal ? 0.0f : (-(float)e.Delta / 120.0f * WheelScrollGain);
            float dx = horizontal ? ((float)e.Delta / 120.0f * WheelScrollGain) : 0.0f;
            SendScroll(dx, dy, true);
            BoostHostFling(dx, dy);
        }

        protected override void WndProc(ref Message m)
        {
            if (m.Msg == WmMouseHWheel)
            {
                base.WndProc(ref m);

                if (_client != null && _gridId != 0)
                {
                    int delta = GetWheelDeltaWParam(m.WParam);
                    if (delta != 0)
                    {
                        float dx = (float)delta / 120.0f * WheelScrollGain;
                        SendScroll(dx, 0.0f, true);
                        BoostHostFling(dx, 0.0f);
                    }
                }
                return;
            }

            if (m.Msg == WmImeStartComposition)
            {
                if (_editOverlayHost.Visible)
                {
                    base.WndProc(ref m);
                    return;
                }
                if (_client != null && _gridId != 0 && !_engineEditing)
                {
                    TryBeginImeEdit();
                }
                base.WndProc(ref m);
                return;
            }

            if (m.Msg == WmImeComposition)
            {
                if (_editOverlayHost.Visible)
                {
                    base.WndProc(ref m);
                    return;
                }
                if (_client != null && _gridId != 0)
                {
                    IntPtr hImc = ImmGetContext(Handle);
                    if (hImc != IntPtr.Zero)
                    {
                        try
                        {
                            // Check for result string (committed text)
                            if ((m.LParam.ToInt32() & GcsResultStr) != 0)
                            {
                                string result = GetImmString(hImc, GcsResultStr);
                                if (!string.IsNullOrEmpty(result))
                                {
                                    _client.EditSetPreedit(_gridId, result, result.Length, true);
                                    RequestFrame();
                                }
                            }

                            // Check for composition string (preedit)
                            if ((m.LParam.ToInt32() & GcsCompStr) != 0)
                            {
                                string comp = GetImmString(hImc, GcsCompStr);
                                _client.EditSetPreedit(_gridId, comp ?? string.Empty, (comp ?? string.Empty).Length, false);
                                RequestFrame();
                            }
                        }
                        finally
                        {
                            ImmReleaseContext(Handle, hImc);
                        }
                    }
                }
                base.WndProc(ref m);
                return;
            }

            if (m.Msg == WmImeEndComposition)
            {
                if (_editOverlayHost.Visible)
                {
                    base.WndProc(ref m);
                    return;
                }
                if (_client != null && _gridId != 0)
                {
                    // Clear preedit state
                    _client.EditSetPreedit(_gridId, string.Empty, 0, false);
                    RequestFrame();
                }
                base.WndProc(ref m);
                return;
            }

            if (m.Msg == WmImeChar)
            {
                if (_editOverlayHost.Visible)
                {
                    base.WndProc(ref m);
                    return;
                }
                // Suppress WM_IME_CHAR — committed text is handled via WM_IME_COMPOSITION GCS_RESULTSTR.
                // Without this, WM_CHAR would fire for each committed character, causing duplicate input.
                return;
            }
            base.WndProc(ref m);
        }

        private void TryBeginImeEdit()
        {
            try
            {
                var selection = _client.GetSelection(_gridId);
                if (selection == null || selection.ActiveRow < 0 || selection.ActiveCol < 0)
                {
                    return;
                }

                // IME composition should start a clean edit session for the
                // active cell without injecting a synthetic printable key.
                _client.EditStart(_gridId, selection.ActiveRow, selection.ActiveCol, EditStartReason.EDIT_START_IME_COMPOSITION, string.Empty);
                _engineEditing = true;
                RequestFrame();
            }
            catch
            {
                // Best effort: let the IME message continue even if the host
                // cannot begin editing yet.
            }
        }

        private static string GetImmString(IntPtr hImc, int dwIndex)
        {
            int byteLen = ImmGetCompositionString(hImc, dwIndex, null, 0);
            if (byteLen <= 0) return string.Empty;
            byte[] buf = new byte[byteLen];
            ImmGetCompositionString(hImc, dwIndex, buf, byteLen);
            return System.Text.Encoding.Unicode.GetString(buf, 0, byteLen);
        }

        protected override void OnKeyDown(KeyEventArgs e)
        {
            if (_editOverlayHost.Visible)
            {
                base.OnKeyDown(e);
                return;
            }
            if (TryHandleClipboardShortcut(e))
            {
                e.SuppressKeyPress = true;
                e.Handled = true;
                return;
            }
            base.OnKeyDown(e);
            var payload = _client.EncodeRenderInputKey(_gridId, KeyDownEvent, (int)e.KeyCode, GetModifiers(), string.Empty);
            SendRenderInput(payload);
            RequestFrame();
        }

        protected override void OnKeyUp(KeyEventArgs e)
        {
            if (_editOverlayHost.Visible)
            {
                base.OnKeyUp(e);
                return;
            }
            base.OnKeyUp(e);
            var payload = _client.EncodeRenderInputKey(_gridId, KeyUpEvent, (int)e.KeyCode, GetModifiers(), string.Empty);
            SendRenderInput(payload);
            RequestFrame();
        }

        protected override void OnKeyPress(KeyPressEventArgs e)
        {
            if (_editOverlayHost.Visible)
            {
                base.OnKeyPress(e);
                return;
            }
            base.OnKeyPress(e);
            var payload = _client.EncodeRenderInputKey(_gridId, KeyPressEvent, e.KeyChar, GetModifiers(), e.KeyChar.ToString());
            SendRenderInput(payload);
            RequestFrame();
        }

        protected override void OnPaintBackground(PaintEventArgs e)
        {
            if (IsGpuRenderActive())
            {
                return;
            }

            base.OnPaintBackground(e);
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            if (IsGpuRenderActive())
            {
                return;
            }

            base.OnPaint(e);

            if (_bitmap == null)
            {
                e.Graphics.Clear(Color.WhiteSmoke);
                return;
            }

            lock (_frameLock)
            {
                if (_bitmap != null)
                {
                    e.Graphics.DrawImageUnscaled(_bitmap, 0, 0);
                }
            }
        }

        private void StartRenderThread()
        {
            _renderThread = new Thread(() =>
            {
                while (_running)
                {
                    byte[] payload;
                    try
                    {
                        payload = _renderStream.Recv();
                    }
                    catch
                    {
                        break;
                    }

                    if (payload == null)
                    {
                        break;
                    }

                    RenderOutput output;
                    try
                    {
                        output = _client.DecodeRenderOutput(payload);
                    }
                    catch (Exception ex)
                    {
                        Debug.WriteLine("Volvox render decode error: " + ex.Message);
                        continue;
                    }

                    try
                    {
                        HandleRenderOutput(output);
                    }
                    catch (Exception ex)
                    {
                        Debug.WriteLine("Volvox render pipeline error: " + ex);
                        lock (_frameLock)
                        {
                            _pendingFrame = false;
                            _followupFrame = false;
                        }
                    }
                }
            });
            _renderThread.IsBackground = true;
            _renderThread.Name = "volvoxgrid-dotnet-render";
            _renderThread.Start();
        }

        private void StartEventThread()
        {
            _eventThread = new Thread(() =>
            {
                while (_running)
                {
                    byte[] payload;
                    try
                    {
                        payload = _eventStream.Recv();
                    }
                    catch
                    {
                        break;
                    }

                    if (payload == null)
                    {
                        break;
                    }

                    GridEvent evt;
                    try
                    {
                        evt = _client.DecodeGridEvent(payload);
                    }
                    catch (Exception ex)
                    {
                        Debug.WriteLine("Volvox event decode error: " + ex.Message);
                        continue;
                    }

                    if (evt.EventCase == GridEvent.EventOneofCase.Compare)
                    {
                        int result = DispatchCompareEvent(evt).GetValueOrDefault(0);
                        if (evt.Compare != null)
                        {
                            SendCompareResponse(evt.Compare.RequestId, result);
                        }
                        continue;
                    }

                    bool? cancel = DispatchEvent(evt);
                    if (cancel.HasValue && evt.EventId != 0)
                    {
                        SendEventDecision(evt.EventId, cancel.Value);
                    }
                }
            });
            _eventThread.IsBackground = true;
            _eventThread.Name = "volvoxgrid-dotnet-events";
            _eventThread.Start();
        }

        private bool? DispatchEvent(GridEvent evt)
        {
            if (evt != null && evt.EventCase == GridEvent.EventOneofCase.StartEdit)
            {
                _engineEditing = true;
            }
            else if (evt != null && evt.EventCase == GridEvent.EventOneofCase.AfterEdit)
            {
                _engineEditing = false;
                BeginInvokeHideEditOverlay(false);
            }

            if (_eventHandler == null)
            {
                return null;
            }

            if (IsHandleCreated && InvokeRequired)
            {
                try
                {
                    return (bool?)Invoke(new Func<GridEvent, bool?>(DispatchEvent), evt);
                }
                catch
                {
                    return null;
                }
            }

            return _eventHandler(evt);
        }

        private int? DispatchCompareEvent(GridEvent evt)
        {
            if (_compareHandler == null)
            {
                return 0;
            }

            if (IsHandleCreated && InvokeRequired)
            {
                try
                {
                    return (int?)Invoke(new Func<GridEvent, int?>(DispatchCompareEvent), evt);
                }
                catch
                {
                    return 0;
                }
            }

            return _compareHandler(evt);
        }

        private void HandleRenderOutput(RenderOutput output)
        {
            if (output == null)
            {
                return;
            }

            if (output.EditorStarted != null)
            {
                BeginInvokeShowEditOverlay(output.EditorStarted);
            }
            else if (output.EditorUpdated != null)
            {
                BeginInvokeUpdateEditOverlay(output.EditorUpdated);
            }
            else if (output.Cursor != null)
            {
                BeginInvokeApplyEngineCursor(output.Cursor.Cursor);
            }
            else if (output.EditorEnded != null)
            {
                _engineEditing = false;
                BeginInvokeHideEditOverlay(false);
            }

            if (output.Rendered && output.FrameDone != null)
            {
                BlitFrame(output.FrameDone);
            }

            bool frameCompleted = output.FrameDone != null || output.GpuFrameDone != null;
            bool shouldRequestFollowupNow = false;
            bool shouldScheduleFollowup = false;
            List<RetiredBuffers> retiredToFree = null;
            lock (_frameLock)
            {
                if (frameCompleted)
                {
                    _pendingFrame = false;
                    if (_followupFrame)
                    {
                        _followupFrame = false;
                        shouldRequestFollowupNow = true;
                    }
                    else if (output.Rendered)
                    {
                        shouldScheduleFollowup = true;
                    }

                    if (_retiredBuffers.Count > 0)
                    {
                        retiredToFree = new List<RetiredBuffers>(_retiredBuffers);
                        _retiredBuffers.Clear();
                    }
                }
            }

            if (retiredToFree != null)
            {
                for (int i = 0; i < retiredToFree.Count; i++)
                {
                    FreeRetiredBuffers(retiredToFree[i]);
                }
            }

            if (shouldRequestFollowupNow)
            {
                RequestFrame();
            }
            else if (shouldScheduleFollowup)
            {
                ScheduleFollowupFrame();
            }
        }

        private void RefreshFramePacingConfigIfStale()
        {
            if (_client == null || _gridId == 0)
            {
                return;
            }
            long now = GetMonotonicMilliseconds();
            if (now - _framePacingConfigLastRefreshTick < FramePacingConfigRefreshMs)
            {
                return;
            }

            try
            {
                var config = _client.GetConfig(_gridId);
                var rendering = config.Rendering ?? new RenderConfig();
                _framePacingMode = rendering.HasFramePacingMode
                    ? rendering.FramePacingMode
                    : FramePacingMode.FRAME_PACING_MODE_PLATFORM;
            }
            catch
            {
                _framePacingMode = FramePacingMode.FRAME_PACING_MODE_PLATFORM;
            }
            finally
            {
                _framePacingConfigLastRefreshTick = now;
            }
        }

        private static long GetMonotonicMilliseconds()
        {
            return (long)(Stopwatch.GetTimestamp() * 1000.0 / Stopwatch.Frequency);
        }

        private void ScheduleFollowupFrame()
        {
            if (!_running || _client == null || _renderStream == null || _gridId == 0)
            {
                return;
            }

            RefreshFramePacingConfigIfStale();
            if (_framePacingMode == FramePacingMode.FRAME_PACING_MODE_UNLIMITED)
            {
                RequestFrame();
                return;
            }
        }

        private void SendFrameReady()
        {
            if (IsGpuRenderActive())
            {
                SendGpuSurfaceReady();
                return;
            }

            SendBufferReady();
        }

        private void SendBufferReady()
        {
            if (!_pixelBufferHandle.IsAllocated || _bufferWidth <= 0 || _bufferHeight <= 0)
            {
                lock (_frameLock)
                {
                    _pendingFrame = false;
                }
                return;
            }

            long ptr = _pixelBufferHandle.AddrOfPinnedObject().ToInt64();
            var payload = _client.EncodeRenderInputBufferReady(_gridId, ptr, _bufferWidth * 4, _bufferWidth, _bufferHeight);
            SendRenderInput(payload);
        }

        private void SendGpuSurfaceReady()
        {
            if (!IsGpuSupported || !IsHandleCreated || ClientSize.Width <= 0 || ClientSize.Height <= 0)
            {
                lock (_frameLock)
                {
                    _pendingFrame = false;
                }
                return;
            }

            IntPtr descriptor = EnsureGpuSurfaceDescriptor();
            if (descriptor == IntPtr.Zero)
            {
                lock (_frameLock)
                {
                    _pendingFrame = false;
                }
                return;
            }

            int width = Math.Max(1, ClientSize.Width);
            int height = Math.Max(1, ClientSize.Height);
            var payload = _client.EncodeRenderInputGpuSurfaceReady(_gridId, descriptor.ToInt64(), width, height);
            SendRenderInput(payload);
        }

        private void SendGpuSurfaceDestroyed()
        {
            if (_client == null || _renderStream == null || _gridId == 0)
            {
                return;
            }

            try
            {
                var payload = _client.EncodeRenderInputGpuSurfaceReady(_gridId, 0L, 0, 0);
                SendRenderInput(payload);
            }
            catch
            {
                // Best effort while switching renderers or shutting down.
            }
        }

        private IntPtr EnsureGpuSurfaceDescriptor()
        {
            IntPtr hwnd = Handle;
            if (hwnd == IntPtr.Zero)
            {
                return IntPtr.Zero;
            }

            if (_gpuSurfaceDescriptor != IntPtr.Zero && _gpuSurfaceWindow == hwnd)
            {
                return _gpuSurfaceDescriptor;
            }

            ReleaseGpuSurfaceDescriptor();
            ulong window = unchecked((ulong)hwnd.ToInt64());
            _gpuSurfaceDescriptor = _client.CreateNativeSurfaceDescriptor(
                NativeSurfaceKindWin32,
                0,
                IntPtr.Zero,
                IntPtr.Zero,
                window);
            _gpuSurfaceWindow = _gpuSurfaceDescriptor == IntPtr.Zero ? IntPtr.Zero : hwnd;
            return _gpuSurfaceDescriptor;
        }

        private void ReleaseGpuSurfaceDescriptor()
        {
            IntPtr descriptor = _gpuSurfaceDescriptor;
            _gpuSurfaceDescriptor = IntPtr.Zero;
            _gpuSurfaceWindow = IntPtr.Zero;

            if (descriptor == IntPtr.Zero || _client == null)
            {
                return;
            }

            try
            {
                _client.FreeNativeSurfaceDescriptor(descriptor);
            }
            catch
            {
                // Best effort during shutdown.
            }
        }

        private bool IsGpuRenderActive()
        {
            return IsGpuRendererMode(_rendererMode);
        }

        private static bool IsGpuRendererMode(RendererMode mode)
        {
            switch (mode)
            {
                case RendererMode.RENDERER_GPU:
                case RendererMode.RENDERER_GPU_VULKAN:
                case RendererMode.RENDERER_GPU_GLES:
                case RendererMode.RENDERER_GPU_DX12:
                case RendererMode.RENDERER_GPU_METAL:
                case RendererMode.RENDERER_GPU_OPENGL:
                    return true;
                default:
                    return false;
            }
        }

        private static bool IsWindowsPlatform()
        {
            PlatformID platform = Environment.OSVersion.Platform;
            return platform == PlatformID.Win32NT
                || platform == PlatformID.Win32S
                || platform == PlatformID.Win32Windows
                || platform == PlatformID.WinCE;
        }

        private void SendScroll(float dx, float dy, bool requestFrame)
        {
            if (_client == null || _gridId == 0)
            {
                return;
            }

            var payload = _client.EncodeRenderInputScroll(_gridId, dx, dy);
            SendRenderInput(payload);
            if (requestFrame)
            {
                RequestFrame();
            }
        }

        private void BoostHostFling(float dx, float dy)
        {
            if (!HostFlingEnabled || (Math.Abs(dx) < 0.001f && Math.Abs(dy) < 0.001f))
            {
                return;
            }

            bool startThread = false;
            lock (_flingLock)
            {
                _flingVelocityX = ClampFloat(_flingVelocityX + dx * HostFlingImpulseGain, -HostFlingMaxVelocity, HostFlingMaxVelocity);
                _flingVelocityY = ClampFloat(_flingVelocityY + dy * HostFlingImpulseGain, -HostFlingMaxVelocity, HostFlingMaxVelocity);
                if (!_flingActive)
                {
                    _flingActive = true;
                    startThread = true;
                }
            }

            if (startThread)
            {
                _flingThread = new Thread(RunHostFlingLoop);
                _flingThread.IsBackground = true;
                _flingThread.Name = "volvoxgrid-dotnet-fling";
                _flingThread.Start();
            }
        }

        private void RunHostFlingLoop()
        {
            while (true)
            {
                float dx;
                float dy;

                lock (_flingLock)
                {
                    if (!_flingActive || !_hostFlingEnabled || !_running)
                    {
                        _flingActive = false;
                        _flingVelocityX = 0.0f;
                        _flingVelocityY = 0.0f;
                        _flingThread = null;
                        return;
                    }

                    _flingVelocityX *= HostFlingDamping;
                    _flingVelocityY *= HostFlingDamping;

                    if (Math.Abs(_flingVelocityX) < HostFlingMinVelocity
                        && Math.Abs(_flingVelocityY) < HostFlingMinVelocity)
                    {
                        _flingActive = false;
                        _flingVelocityX = 0.0f;
                        _flingVelocityY = 0.0f;
                        _flingThread = null;
                        return;
                    }

                    dx = _flingVelocityX;
                    dy = _flingVelocityY;
                }

                SendScroll(dx, dy, true);
                Thread.Sleep(HostFlingFrameMillis);
            }
        }

        private void StopHostFling()
        {
            Thread thread;
            lock (_flingLock)
            {
                _flingActive = false;
                _flingVelocityX = 0.0f;
                _flingVelocityY = 0.0f;
                thread = _flingThread;
                _flingThread = null;
            }

            if (thread != null && thread != Thread.CurrentThread)
            {
                try
                {
                    thread.Join(100);
                }
                catch
                {
                    // Best effort.
                }
            }
        }

        private static float ClampFloat(float value, float min, float max)
        {
            if (value < min)
            {
                return min;
            }
            if (value > max)
            {
                return max;
            }
            return value;
        }

        private void SendPointer(PointerEvent_Type type, MouseEventArgs e, bool dblClick)
        {
            SendPointer(type, e.X, e.Y, GetModifiers(), MapMouseButton(e), dblClick);
        }

        private void SendPointer(PointerEvent_Type type, int x, int y, int modifier, int button, bool dblClick)
        {
            if (_client == null || _gridId == 0)
            {
                return;
            }

            var payload = _client.EncodeRenderInputPointer(_gridId, type, x, y, modifier, button, dblClick);
            SendRenderInput(payload);
        }

        private static int MapMouseButton(MouseEventArgs e)
        {
            MouseButtons button = e.Button != MouseButtons.None ? e.Button : Control.MouseButtons;
            if ((button & MouseButtons.Left) == MouseButtons.Left)
            {
                return 1;
            }

            if ((button & MouseButtons.Middle) == MouseButtons.Middle)
            {
                return 2;
            }

            if ((button & MouseButtons.Right) == MouseButtons.Right)
            {
                return 3;
            }

            return 0;
        }

        private bool TryBeginMultiRangeSelection(MouseEventArgs e)
        {
            if (!IsAdditiveMultiRangeGesture(e) || _client == null || _gridId == 0)
            {
                return false;
            }

            try
            {
                SelectionState state = UpdateMouseSelectionState(e);
                if (!HasValidMouseCell(state))
                {
                    return false;
                }

                _multiRangeBaseRanges.Clear();
                _multiRangeBaseRanges.AddRange(SnapshotMultiRangeBaseRanges(state, state.MouseRow, state.MouseCol));
                _multiRangeAnchorRow = state.MouseRow;
                _multiRangeAnchorCol = state.MouseCol;
                _multiRangeDragRow = state.MouseRow;
                _multiRangeDragCol = state.MouseCol;
                _multiRangeDragActive = true;
                ApplyMultiRangeSelection(_multiRangeDragRow, _multiRangeDragCol);
                return true;
            }
            catch
            {
                ClearMultiRangeDrag();
                return false;
            }
        }

        private bool TryUpdateMultiRangeSelection(MouseEventArgs e)
        {
            if (!_multiRangeDragActive || _client == null || _gridId == 0)
            {
                return false;
            }

            try
            {
                SelectionState state = UpdateMouseSelectionState(e);
                if (HasValidMouseCell(state))
                {
                    _multiRangeDragRow = state.MouseRow;
                    _multiRangeDragCol = state.MouseCol;
                }

                ApplyMultiRangeSelection(_multiRangeDragRow, _multiRangeDragCol);
                return true;
            }
            catch
            {
                return false;
            }
        }

        private bool IsAdditiveMultiRangeGesture(MouseEventArgs e)
        {
            return _selectionMode == Volvoxgrid.V1.SelectionMode.SELECTION_MULTI_RANGE
                && (e.Button & MouseButtons.Left) == MouseButtons.Left
                && (Control.ModifierKeys & Keys.Control) == Keys.Control;
        }

        private SelectionState UpdateMouseSelectionState(MouseEventArgs e)
        {
            SendPointer(PointerMoveEvent, e.X, e.Y, GetModifiers(), 0, false);
            return _client.GetSelection(_gridId);
        }

        private static bool HasValidMouseCell(SelectionState state)
        {
            return state != null && state.MouseRow >= 0 && state.MouseCol >= 0;
        }

        private static List<CellRange> SnapshotMultiRangeBaseRanges(SelectionState state, int anchorRow, int anchorCol)
        {
            var ranges = new List<CellRange>();
            if (state == null)
            {
                return ranges;
            }

            if (state.Ranges == null || state.Ranges.Count == 0)
            {
                if (state.ActiveRow >= 0 && state.ActiveCol >= 0)
                {
                    ranges.Add(new CellRange
                    {
                        Row1 = state.ActiveRow,
                        Col1 = state.ActiveCol,
                        Row2 = state.ActiveRow,
                        Col2 = state.ActiveCol,
                    });
                }
                return ranges;
            }

            for (int i = 0; i < state.Ranges.Count; i++)
            {
                CellRange range = state.Ranges[i];
                if (range.Row1 == anchorRow
                    && range.Col1 == anchorCol
                    && range.Row2 == anchorRow
                    && range.Col2 == anchorCol)
                {
                    continue;
                }

                ranges.Add(new CellRange
                {
                    Row1 = range.Row1,
                    Col1 = range.Col1,
                    Row2 = range.Row2,
                    Col2 = range.Col2,
                });
            }

            return ranges;
        }

        private void ApplyMultiRangeSelection(int targetRow, int targetCol)
        {
            if (_client == null || _gridId == 0 || _multiRangeAnchorRow < 0 || _multiRangeAnchorCol < 0)
            {
                return;
            }

            var ranges = new List<CellRange>(_multiRangeBaseRanges.Count + 1);
            for (int i = 0; i < _multiRangeBaseRanges.Count; i++)
            {
                CellRange range = _multiRangeBaseRanges[i];
                ranges.Add(new CellRange
                {
                    Row1 = range.Row1,
                    Col1 = range.Col1,
                    Row2 = range.Row2,
                    Col2 = range.Col2,
                });
            }

            var nextRange = new CellRange
            {
                Row1 = Math.Min(_multiRangeAnchorRow, targetRow),
                Col1 = Math.Min(_multiRangeAnchorCol, targetCol),
                Row2 = Math.Max(_multiRangeAnchorRow, targetRow),
                Col2 = Math.Max(_multiRangeAnchorCol, targetCol),
            };

            bool exists = false;
            for (int i = 0; i < ranges.Count; i++)
            {
                CellRange range = ranges[i];
                if (range.Row1 == nextRange.Row1
                    && range.Col1 == nextRange.Col1
                    && range.Row2 == nextRange.Row2
                    && range.Col2 == nextRange.Col2)
                {
                    exists = true;
                    break;
                }
            }

            if (!exists)
            {
                ranges.Add(nextRange);
            }

            _client.Select(_gridId, targetRow, targetCol, ranges, true);
        }

        private void ClearMultiRangeDrag()
        {
            _multiRangeDragActive = false;
            _multiRangeBaseRanges.Clear();
            _multiRangeAnchorRow = -1;
            _multiRangeAnchorCol = -1;
            _multiRangeDragRow = -1;
            _multiRangeDragCol = -1;
        }

        private void SendRenderInput(byte[] payload)
        {
            try
            {
                lock (_sendLock)
                {
                    _renderStream?.Send(payload);
                }
            }
            catch
            {
                lock (_frameLock)
                {
                    _pendingFrame = false;
                }
            }
        }

        private void ResizeBuffers(int width, int height)
        {
            lock (_frameLock)
            {
                RetiredBuffers retired = default(RetiredBuffers);
                bool hasRetired = _pixelBufferHandle.IsAllocated || _bitmap != null;
                if (hasRetired)
                {
                    retired = new RetiredBuffers
                    {
                        PixelBufferHandle = _pixelBufferHandle,
                        Bitmap = _bitmap,
                    };
                }

                _bufferWidth = width;
                _bufferHeight = height;
                _bitmap = null;
                _pixelBufferHandle = default(GCHandle);
                _pixelBuffer = null;
                _blitBuffer = null;

                _pixelBuffer = new byte[width * height * 4];
                _blitBuffer = new byte[width * height * 4];
                _pixelBufferHandle = GCHandle.Alloc(_pixelBuffer, GCHandleType.Pinned);
                _bitmap = new Bitmap(width, height, PixelFormat.Format32bppArgb);

                if (hasRetired)
                {
                    if (_pendingFrame)
                    {
                        _retiredBuffers.Add(retired);
                    }
                    else
                    {
                        FreeRetiredBuffers(retired);
                    }
                }
            }
        }

        private void ReleaseBuffers()
        {
            List<RetiredBuffers> retiredToFree = null;
            RetiredBuffers current = default(RetiredBuffers);
            bool hasCurrent = false;

            lock (_frameLock)
            {
                if (_pixelBufferHandle.IsAllocated || _bitmap != null)
                {
                    current = new RetiredBuffers
                    {
                        PixelBufferHandle = _pixelBufferHandle,
                        Bitmap = _bitmap,
                    };
                    hasCurrent = true;
                }

                if (_retiredBuffers.Count > 0)
                {
                    retiredToFree = new List<RetiredBuffers>(_retiredBuffers);
                    _retiredBuffers.Clear();
                }

                _bitmap = null;
                _pixelBufferHandle = default(GCHandle);
                _pixelBuffer = null;
                _blitBuffer = null;
                _bufferWidth = 0;
                _bufferHeight = 0;
            }

            if (hasCurrent)
            {
                FreeRetiredBuffers(current);
            }

            if (retiredToFree != null)
            {
                for (int i = 0; i < retiredToFree.Count; i++)
                {
                    FreeRetiredBuffers(retiredToFree[i]);
                }
            }
        }

        private void BlitFrame(FrameDone frame)
        {
            bool blitted = false;
            lock (_frameLock)
            {
                var bitmap = _bitmap;
                var src = _pixelBuffer;
                var dst = _blitBuffer;
                if (bitmap == null || src == null || dst == null)
                {
                    return;
                }

                int width = Math.Min(_bufferWidth, bitmap.Width);
                int height = Math.Min(_bufferHeight, bitmap.Height);
                if (width <= 0 || height <= 0)
                {
                    return;
                }

                int srcStride = _bufferWidth * 4;
                int copyStride = width * 4;
                int requiredSrcBytes = _bufferWidth * _bufferHeight * 4;
                int requiredDstBytes = width * height * 4;
                if (requiredSrcBytes <= 0 || requiredDstBytes <= 0)
                {
                    return;
                }

                if (src.Length < requiredSrcBytes || dst.Length < requiredDstBytes)
                {
                    Debug.WriteLine("Volvox BlitFrame skipped: buffer size mismatch.");
                    return;
                }

                // Engine CPU frames are RGBA; GDI+ bitmap bytes are BGRA.
                for (int y = 0; y < height; y++)
                {
                    int srcRow = y * srcStride;
                    int dstRow = y * copyStride;
                    for (int x = 0; x < copyStride; x += 4)
                    {
                        int s = srcRow + x;
                        int d = dstRow + x;
                        dst[d] = src[s + 2];
                        dst[d + 1] = src[s + 1];
                        dst[d + 2] = src[s];
                        dst[d + 3] = src[s + 3];
                    }
                }

                BitmapData data = null;
                try
                {
                    var rect = new Rectangle(0, 0, width, height);
                    data = bitmap.LockBits(rect, ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
                    int absStride = Math.Abs(data.Stride);
                    if (absStride < copyStride)
                    {
                        Debug.WriteLine("Volvox BlitFrame skipped: destination stride too small.");
                        return;
                    }

                    if (data.Stride == copyStride)
                    {
                        Marshal.Copy(dst, 0, data.Scan0, requiredDstBytes);
                    }
                    else if (data.Stride > 0)
                    {
                        for (int y = 0; y < height; y++)
                        {
                            IntPtr rowPtr = IntPtr.Add(data.Scan0, y * data.Stride);
                            Marshal.Copy(dst, y * copyStride, rowPtr, copyStride);
                        }
                    }
                    else
                    {
                        for (int y = 0; y < height; y++)
                        {
                            int reversedY = (height - 1) - y;
                            IntPtr rowPtr = IntPtr.Add(data.Scan0, reversedY * absStride);
                            Marshal.Copy(dst, y * copyStride, rowPtr, copyStride);
                        }
                    }

                    blitted = true;
                }
                catch (Exception ex)
                {
                    Debug.WriteLine("Volvox BlitFrame failed: " + ex.Message);
                }
                finally
                {
                    if (data != null)
                    {
                        try
                        {
                            bitmap.UnlockBits(data);
                        }
                        catch (Exception ex)
                        {
                            Debug.WriteLine("Volvox UnlockBits failed: " + ex.Message);
                        }
                    }
                }
            }

            if (blitted)
            {
                InvalidateDirty(frame);
            }
        }

        private void InvalidateDirty(FrameDone frame)
        {
            if (frame == null)
            {
                BeginInvokeInvalidate(null);
                return;
            }

            int dirtyW = Math.Max(0, frame.DirtyW);
            int dirtyH = Math.Max(0, frame.DirtyH);
            if (dirtyW > 0 && dirtyH > 0)
            {
                var dirty = new Rectangle(
                    Math.Max(0, frame.DirtyX),
                    Math.Max(0, frame.DirtyY),
                    dirtyW,
                    dirtyH);
                BeginInvokeInvalidate(dirty);
                return;
            }

            BeginInvokeInvalidate(null);
        }

        private static bool TryJoinThread(Thread thread, int timeoutMs)
        {
            if (thread == null || thread == Thread.CurrentThread)
            {
                return true;
            }

            if (!thread.IsAlive)
            {
                return true;
            }

            try
            {
                return thread.Join(timeoutMs);
            }
            catch
            {
                return false;
            }
        }

        private static int GetWheelDeltaWParam(IntPtr wParam)
        {
            long v = wParam.ToInt64();
            return (short)((v >> 16) & 0xFFFF);
        }

        private void BeginInvokeInvalidate(Rectangle? dirty)
        {
            if (!IsHandleCreated)
            {
                return;
            }

            if (InvokeRequired)
            {
                BeginInvoke(new MethodInvoker(() =>
                {
                    if (dirty.HasValue)
                    {
                        Invalidate(dirty.Value);
                    }
                    else
                    {
                        Invalidate();
                    }
                }));
            }
            else
            {
                if (dirty.HasValue)
                {
                    Invalidate(dirty.Value);
                }
                else
                {
                    Invalidate();
                }
            }
        }

        private void BeginInvokeShowEditOverlay(EditorSessionStarted request)
        {
            if (request == null || !IsHandleCreated)
            {
                return;
            }

            if (InvokeRequired)
            {
                BeginInvoke(new MethodInvoker(() => ShowEditOverlay(request)));
            }
            else
            {
                ShowEditOverlay(request);
            }
        }

        private void BeginInvokeHideEditOverlay(bool focusHost)
        {
            if (!IsHandleCreated)
            {
                return;
            }

            if (InvokeRequired)
            {
                BeginInvoke(new MethodInvoker(() => HideEditOverlay(focusHost)));
            }
            else
            {
                HideEditOverlay(focusHost);
            }
        }

        private void BeginInvokeUpdateEditOverlay(EditorSessionUpdated update)
        {
            if (update == null || !IsHandleCreated)
            {
                return;
            }

            if (InvokeRequired)
            {
                BeginInvoke(new MethodInvoker(() => UpdateEditOverlay(update)));
            }
            else
            {
                UpdateEditOverlay(update);
            }
        }

        private void BeginInvokeApplyEngineCursor(CursorType cursorType)
        {
            if (_engineCursorType == cursorType)
            {
                return;
            }

            _engineCursorType = cursorType;
            var cursor = WinFormsCursorFor(cursorType);
            if (!IsHandleCreated)
            {
                return;
            }

            if (InvokeRequired)
            {
                BeginInvoke(new MethodInvoker(() =>
                {
                    if (_engineCursorType == cursorType)
                    {
                        Cursor = cursor;
                    }
                }));
            }
            else
            {
                Cursor = cursor;
            }
        }

        private static System.Windows.Forms.Cursor WinFormsCursorFor(CursorType cursorType)
        {
            switch (cursorType)
            {
                case CursorType.CURSOR_RESIZE_COL:
                    return Cursors.SizeWE;
                case CursorType.CURSOR_RESIZE_ROW:
                    return Cursors.SizeNS;
                case CursorType.CURSOR_MOVE_COL:
                case CursorType.CURSOR_MOVE_ROW:
                    return Cursors.SizeAll;
                case CursorType.CURSOR_TEXT:
                    return Cursors.IBeam;
                case CursorType.CURSOR_HAND:
                case CursorType.CURSOR_COPY:
                    return Cursors.Hand;
                case CursorType.CURSOR_WAIT:
                    return Cursors.WaitCursor;
                case CursorType.CURSOR_NOT_ALLOWED:
                    return Cursors.No;
                case CursorType.CURSOR_CROSSHAIR:
                    return Cursors.Cross;
                case CursorType.CURSOR_DEFAULT:
                default:
                    return Cursors.Default;
            }
        }

        private static string EditorValueToText(EditorValue value)
        {
            if (value == null)
            {
                return string.Empty;
            }
            if (value.HasEditText)
            {
                return value.EditText ?? string.Empty;
            }
            if (value.Value == null)
            {
                return string.Empty;
            }
            switch (value.Value.ValueCase)
            {
                case CellValue.ValueOneofCase.Text:
                    return value.Value.Text ?? string.Empty;
                case CellValue.ValueOneofCase.Number:
                    return value.Value.Number.ToString(System.Globalization.CultureInfo.InvariantCulture);
                case CellValue.ValueOneofCase.Flag:
                    return value.Value.Flag ? "true" : "false";
                case CellValue.ValueOneofCase.Timestamp:
                    return value.Value.Timestamp.ToString(System.Globalization.CultureInfo.InvariantCulture);
                default:
                    return string.Empty;
            }
        }

        private void ShowEditOverlay(EditorSessionStarted request)
        {
            var session = request?.Session;
            if (session == null || _client == null || _gridId == 0)
            {
                return;
            }
            // Engine-drawn editor: host MUST NOT mount an overlay.
            if (session.Editor != null && session.Editor.Presentation == EditorPresentation.EDITOR_CANVAS)
            {
                _engineEditing = true;
                if (_editOverlayHost.Visible)
                {
                    HideEditOverlay(false);
                }
                if (IsHandleCreated && !Focused)
                {
                    Focus();
                }
                return;
            }
            if (session.ViewportRect == null)
            {
                return;
            }

            _engineEditing = true;
            int x = Math.Max(0, (int)Math.Round(session.ViewportRect.X));
            int y = Math.Max(0, (int)Math.Round(session.ViewportRect.Y));
            int w = Math.Max(1, (int)Math.Round(session.ViewportRect.Width));
            int h = Math.Max(1, (int)Math.Round(session.ViewportRect.Height));
            bool sameCell = _editOverlayHost.Visible && _editOverlayRow == session.Row && _editOverlayCol == session.Col;
            System.Windows.Forms.Padding editPadding = ResolveEditPadding != null
                ? ResolveEditPadding(session.Row, session.Col)
                : System.Windows.Forms.Padding.Empty;
            editPadding = new System.Windows.Forms.Padding(
                Math.Max(0, editPadding.Left),
                Math.Max(0, editPadding.Top),
                Math.Max(0, editPadding.Right),
                Math.Max(0, editPadding.Bottom));
            int innerX = editPadding.Left;
            int innerY = editPadding.Top;
            int innerW = Math.Max(1, w - editPadding.Left - editPadding.Right);
            int innerH = Math.Max(1, h - editPadding.Top - editPadding.Bottom);

            _editOverlayRow = session.Row;
            _editOverlayCol = session.Col;
            _editOverlayUiMode = session.UiMode;
            _editOverlay.Font = ResolveEditOverlayFont(Font);
            _editOverlayHost.Bounds = new Rectangle(x, y, w, h);
            _editOverlay.Bounds = new Rectangle(innerX, innerY, innerW, innerH);
            int maxLength = session.Editor != null && session.Editor.Text != null
                ? session.Editor.Text.MaxLength
                : 0;
            _editOverlay.MaxLength = maxLength > 0 ? maxLength : 0;
            _editOverlay.TextAlign = ResolveEditAlignment != null
                ? ResolveEditAlignment(session.Row, session.Col)
                : HorizontalAlignment.Left;

            if (!sameCell)
            {
                string text = EditorValueToText(session.Value);
                int selectionStart = session.Selection != null ? session.Selection.Start : 0;
                int selectionLength = session.Selection != null ? session.Selection.Length : text.Length;
                int start = ScalarIndexToCodeUnitIndex(text, selectionStart);
                int end = ScalarIndexToCodeUnitIndex(text, selectionStart + selectionLength);
                start = Math.Max(0, Math.Min(text.Length, start));
                end = Math.Max(start, Math.Min(text.Length, end));

                _suppressEditOverlayTextChanged = true;
                try
                {
                    _editOverlay.Text = text;
                    _editOverlay.SelectionStart = start;
                    _editOverlay.SelectionLength = end - start;
                }
                finally
                {
                    _suppressEditOverlayTextChanged = false;
                }
            }

            if (!_editOverlayHost.Visible)
            {
                _editOverlayHost.Show();
            }
            _editOverlayHost.BringToFront();
            if (!_editOverlay.Focused)
            {
                _editOverlay.Focus();
            }
            SyncEditOverlaySelectionToEngine();
        }

        private void UpdateEditOverlay(EditorSessionUpdated update)
        {
            if (update == null)
            {
                return;
            }
            if (update.HasVisible && !update.Visible)
            {
                HideEditOverlay(false);
                return;
            }
            if (!_editOverlayHost.Visible)
            {
                return;
            }
            if (update.ViewportRect != null)
            {
                int x = Math.Max(0, (int)Math.Round(update.ViewportRect.X));
                int y = Math.Max(0, (int)Math.Round(update.ViewportRect.Y));
                int w = Math.Max(1, (int)Math.Round(update.ViewportRect.Width));
                int h = Math.Max(1, (int)Math.Round(update.ViewportRect.Height));
                System.Windows.Forms.Padding editPadding = ResolveEditPadding != null
                    ? ResolveEditPadding(_editOverlayRow, _editOverlayCol)
                    : System.Windows.Forms.Padding.Empty;
                editPadding = new System.Windows.Forms.Padding(
                    Math.Max(0, editPadding.Left),
                    Math.Max(0, editPadding.Top),
                    Math.Max(0, editPadding.Right),
                    Math.Max(0, editPadding.Bottom));
                int innerW = Math.Max(1, w - editPadding.Left - editPadding.Right);
                int innerH = Math.Max(1, h - editPadding.Top - editPadding.Bottom);
                _editOverlayHost.Bounds = new Rectangle(x, y, w, h);
                _editOverlay.Bounds = new Rectangle(editPadding.Left, editPadding.Top, innerW, innerH);
            }
            if (update.Value != null)
            {
                _suppressEditOverlayTextChanged = true;
                try
                {
                    _editOverlay.Text = EditorValueToText(update.Value);
                }
                finally
                {
                    _suppressEditOverlayTextChanged = false;
                }
            }
            if (update.Selection != null)
            {
                string text = _editOverlay.Text ?? string.Empty;
                int start = ScalarIndexToCodeUnitIndex(text, update.Selection.Start);
                int end = ScalarIndexToCodeUnitIndex(text, update.Selection.Start + update.Selection.Length);
                start = Math.Max(0, Math.Min(text.Length, start));
                end = Math.Max(start, Math.Min(text.Length, end));
                _editOverlay.SelectionStart = start;
                _editOverlay.SelectionLength = end - start;
            }
        }

        private void EditOverlayHost_Paint(object sender, PaintEventArgs e)
        {
            Rectangle borderRect = _editOverlayHost.ClientRectangle;
            if (borderRect.Width <= 0 || borderRect.Height <= 0)
            {
                return;
            }

            ControlPaint.DrawBorder(
                e.Graphics,
                borderRect,
                EditOverlayBorderColor,
                ButtonBorderStyle.Solid);
        }

        private void HideEditOverlay(bool focusHost)
        {
            _suppressEditOverlayCommit = true;
            try
            {
                if (_editOverlayHost.Visible)
                {
                    _editOverlayHost.Hide();
                }
                _editOverlayRow = -1;
                _editOverlayCol = -1;
                _editOverlayUiMode = EditUiMode.EDIT_UI_MODE_ENTER;
            }
            finally
            {
                _suppressEditOverlayCommit = false;
            }

            if (focusHost && IsHandleCreated)
            {
                Focus();
            }
        }

        private void EditOverlay_TextChanged(object sender, EventArgs e)
        {
            if (_suppressEditOverlayTextChanged || _client == null || _gridId == 0 || !_editOverlayHost.Visible)
            {
                return;
            }

            try
            {
                _client.EditSetText(_gridId, _editOverlay.Text);
                SyncEditOverlaySelectionToEngine();
                RequestFrame();
            }
            catch
            {
            }
        }

        private void EditOverlay_KeyDown(object sender, KeyEventArgs e)
        {
            if (_client == null || _gridId == 0 || !_editOverlayHost.Visible)
            {
                return;
            }

            switch (e.KeyCode)
            {
                case Keys.Escape:
                    e.SuppressKeyPress = true;
                    e.Handled = true;
                    CancelEditOverlay();
                    return;
                case Keys.Tab:
                    e.SuppressKeyPress = true;
                    e.Handled = true;
                    CommitEditOverlay((int)Keys.Tab, GetModifierBits(e));
                    return;
                case Keys.Enter:
                    if (e.Alt)
                    {
                        e.SuppressKeyPress = true;
                        e.Handled = true;
                        _editOverlay.SelectedText = "\n";
                        SyncEditOverlaySelectionToEngine();
                        return;
                    }
                    e.SuppressKeyPress = true;
                    e.Handled = true;
                    CommitEditOverlay(e.Shift ? (int)Keys.Up : (int)Keys.Down, 0);
                    return;
                case Keys.Left:
                case Keys.Right:
                case Keys.Up:
                case Keys.Down:
                    if ((_editOverlay.Text ?? string.Empty).Contains("\n"))
                    {
                        break;
                    }
                    if (_editOverlayUiMode != EditUiMode.EDIT_UI_MODE_EDIT)
                    {
                        e.SuppressKeyPress = true;
                        e.Handled = true;
                        CommitEditOverlay((int)e.KeyCode, 0);
                        return;
                    }
                    if (e.KeyCode == Keys.Up)
                    {
                        e.SuppressKeyPress = true;
                        e.Handled = true;
                        _editOverlay.SelectionStart = 0;
                        _editOverlay.SelectionLength = 0;
                        SyncEditOverlaySelectionToEngine();
                        return;
                    }
                    if (e.KeyCode == Keys.Down)
                    {
                        e.SuppressKeyPress = true;
                        e.Handled = true;
                        int end = (_editOverlay.Text ?? string.Empty).Length;
                        _editOverlay.SelectionStart = end;
                        _editOverlay.SelectionLength = 0;
                        SyncEditOverlaySelectionToEngine();
                        return;
                    }
                    break;
            }
        }

        private bool TryHandleClipboardShortcut(KeyEventArgs e)
        {
            if (e == null || _client == null || _gridId == 0 || !e.Control || e.Alt)
            {
                return false;
            }

            try
            {
                switch (e.KeyCode)
                {
                    case Keys.C:
                    {
                        ClipboardResponse response = _client.Clipboard(_gridId, "copy", null);
                        SetSystemClipboardText(response != null ? response.Text : string.Empty);
                        return true;
                    }
                    case Keys.X:
                    {
                        ClipboardResponse response = _client.Clipboard(_gridId, "cut", null);
                        SetSystemClipboardText(response != null ? response.Text : string.Empty);
                        RequestFrame();
                        return true;
                    }
                    case Keys.V:
                    {
                        string text = GetSystemClipboardText();
                        if (text != null)
                        {
                            _client.Clipboard(_gridId, "paste", text);
                            RequestFrame();
                        }
                        return true;
                    }
                    default:
                        return false;
                }
            }
            catch
            {
                return false;
            }
        }

        private static void SetSystemClipboardText(string text)
        {
            if (string.IsNullOrEmpty(text))
            {
                System.Windows.Forms.Clipboard.Clear();
                return;
            }
            System.Windows.Forms.Clipboard.SetText(text, TextDataFormat.UnicodeText);
        }

        private static string GetSystemClipboardText()
        {
            return System.Windows.Forms.Clipboard.ContainsText(TextDataFormat.UnicodeText)
                ? System.Windows.Forms.Clipboard.GetText(TextDataFormat.UnicodeText)
                : null;
        }

        private void EditOverlay_SelectionChanged(object sender, EventArgs e)
        {
            SyncEditOverlaySelectionToEngine();
        }

        private void EditOverlay_LostFocus(object sender, EventArgs e)
        {
            if (_suppressEditOverlayCommit || !_editOverlayHost.Visible)
            {
                return;
            }
            CommitEditOverlay(null, 0);
        }

        private void CommitEditOverlay(int? navigateKeyCode, int navigateModifier)
        {
            if (_client == null || _gridId == 0 || !_editOverlayHost.Visible)
            {
                return;
            }

            bool stillEditing = true;
            try
            {
                _client.EditCommit(_gridId, _editOverlay.Text);
                RequestFrame();
                EditState state = _client.GetEditState(_gridId);
                stillEditing = state != null && state.Active;
            }
            catch
            {
                stillEditing = true;
            }

            if (stillEditing)
            {
                _engineEditing = true;
                if (!_editOverlay.Focused)
                {
                    _editOverlay.Focus();
                }
                return;
            }

            _engineEditing = false;
            HideEditOverlay(false);
            if (navigateKeyCode.HasValue)
            {
                Focus();
                SendSyntheticKey(navigateKeyCode.Value, navigateModifier);
                RequestFrame();
            }
            else
            {
                Focus();
            }
        }

        private void CancelEditOverlay()
        {
            if (_client == null || _gridId == 0 || !_editOverlayHost.Visible)
            {
                return;
            }

            bool stillEditing = false;
            try
            {
                _client.EditCancel(_gridId);
                RequestFrame();
                EditState state = _client.GetEditState(_gridId);
                stillEditing = state != null && state.Active;
            }
            catch
            {
                stillEditing = false;
            }

            _engineEditing = stillEditing;
            if (stillEditing)
            {
                if (!_editOverlay.Focused)
                {
                    _editOverlay.Focus();
                }
                return;
            }

            HideEditOverlay(true);
        }

        private void SyncEditOverlaySelectionToEngine()
        {
            if (_client == null || _gridId == 0 || !_editOverlayHost.Visible)
            {
                return;
            }

            try
            {
                string text = _editOverlay.Text ?? string.Empty;
                int startUnits = Math.Max(0, Math.Min(text.Length, _editOverlay.SelectionStart));
                int endUnits = Math.Max(startUnits, Math.Min(text.Length, startUnits + _editOverlay.SelectionLength));
                int start = CodeUnitIndexToScalarIndex(text, startUnits);
                int end = CodeUnitIndexToScalarIndex(text, endUnits);
                _client.EditSetSelection(_gridId, start, Math.Max(0, end - start));
            }
            catch
            {
            }
        }

        private void SendSyntheticKey(int keyCode, int modifier)
        {
            if (_client == null || _gridId == 0)
            {
                return;
            }

            SendRenderInput(_client.EncodeRenderInputKey(_gridId, KeyDownEvent, keyCode, modifier, string.Empty));
            SendRenderInput(_client.EncodeRenderInputKey(_gridId, KeyUpEvent, keyCode, modifier, string.Empty));
        }

        private static int GetModifierBits(KeyEventArgs e)
        {
            int mod = 0;
            if (e.Shift) mod |= 1;
            if (e.Control) mod |= 2;
            if (e.Alt) mod |= 4;
            return mod;
        }

        private static bool IsWineProcess()
        {
            return !string.IsNullOrEmpty(Environment.GetEnvironmentVariable("WINEPREFIX"));
        }

        private static HashSet<string> GetInstalledFontFamilies()
        {
            lock (InstalledFontFamiliesSync)
            {
                if (_installedFontFamilies != null)
                {
                    return _installedFontFamilies;
                }

                var families = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
                try
                {
                    var collection = new InstalledFontCollection();
                    foreach (FontFamily family in collection.Families)
                    {
                        if (family != null && !string.IsNullOrEmpty(family.Name))
                        {
                            families.Add(family.Name);
                        }
                    }
                }
                catch
                {
                }

                if (families.Count == 0)
                {
                    families.Add(SystemFonts.DefaultFont.FontFamily.Name);
                }

                _installedFontFamilies = families;
                return _installedFontFamilies;
            }
        }

        private static string ResolveEditOverlayFontFamily(System.Drawing.Font baseFont)
        {
            string preferred = baseFont != null && baseFont.FontFamily != null
                ? baseFont.FontFamily.Name
                : string.Empty;
            HashSet<string> installed = GetInstalledFontFamilies();

            if (IsWineProcess())
            {
                for (int i = 0; i < ImeFriendlyFontFamilies.Length; i++)
                {
                    string candidate = ImeFriendlyFontFamilies[i];
                    if (installed.Contains(candidate))
                    {
                        return candidate;
                    }
                }
            }

            if (!string.IsNullOrEmpty(preferred) && installed.Contains(preferred))
            {
                return preferred;
            }

            for (int i = 0; i < ImeFriendlyFontFamilies.Length; i++)
            {
                string candidate = ImeFriendlyFontFamilies[i];
                if (installed.Contains(candidate))
                {
                    return candidate;
                }
            }

            return SystemFonts.DefaultFont.FontFamily.Name;
        }

        private System.Drawing.Font ResolveEditOverlayFont(System.Drawing.Font baseFont)
        {
            System.Drawing.Font fallbackBaseFont = baseFont ?? SystemFonts.DefaultFont;
            string resolvedFamily = ResolveEditOverlayFontFamily(fallbackBaseFont);
            if (string.Equals(resolvedFamily, fallbackBaseFont.FontFamily.Name, StringComparison.OrdinalIgnoreCase))
            {
                return fallbackBaseFont;
            }

            if (_editOverlayResolvedFont != null
                && string.Equals(_editOverlayResolvedFontFamily, resolvedFamily, StringComparison.OrdinalIgnoreCase)
                && Math.Abs(_editOverlayResolvedFontSize - fallbackBaseFont.Size) < 0.01f
                && _editOverlayResolvedFontStyle == fallbackBaseFont.Style
                && _editOverlayResolvedFontUnit == fallbackBaseFont.Unit)
            {
                return _editOverlayResolvedFont;
            }

            ResetEditOverlayResolvedFont();
            try
            {
                _editOverlayResolvedFont = new System.Drawing.Font(
                    resolvedFamily,
                    fallbackBaseFont.Size,
                    fallbackBaseFont.Style,
                    fallbackBaseFont.Unit,
                    fallbackBaseFont.GdiCharSet,
                    fallbackBaseFont.GdiVerticalFont);
                _editOverlayResolvedFontFamily = resolvedFamily;
                _editOverlayResolvedFontSize = fallbackBaseFont.Size;
                _editOverlayResolvedFontStyle = fallbackBaseFont.Style;
                _editOverlayResolvedFontUnit = fallbackBaseFont.Unit;
                return _editOverlayResolvedFont;
            }
            catch
            {
                ResetEditOverlayResolvedFont();
                return fallbackBaseFont;
            }
        }

        private void ResetEditOverlayResolvedFont()
        {
            if (_editOverlayResolvedFont != null)
            {
                _editOverlayResolvedFont.Dispose();
                _editOverlayResolvedFont = null;
            }
            _editOverlayResolvedFontFamily = string.Empty;
            _editOverlayResolvedFontSize = 0f;
            _editOverlayResolvedFontStyle = FontStyle.Regular;
            _editOverlayResolvedFontUnit = GraphicsUnit.World;
        }

        private static int GetModifiers()
        {
            int mod = 0;
            Keys keys = Control.ModifierKeys;
            if ((keys & Keys.Shift) == Keys.Shift)
            {
                mod |= 1;
            }

            if ((keys & Keys.Control) == Keys.Control)
            {
                mod |= 2;
            }

            if ((keys & Keys.Alt) == Keys.Alt)
            {
                mod |= 4;
            }

            return mod;
        }

        private static int ScalarIndexToCodeUnitIndex(string text, int scalarIndex)
        {
            string value = text ?? string.Empty;
            int remaining = Math.Max(0, scalarIndex);
            int i = 0;
            while (i < value.Length && remaining > 0)
            {
                if (char.IsHighSurrogate(value, i) && i + 1 < value.Length && char.IsLowSurrogate(value, i + 1))
                {
                    i += 2;
                }
                else
                {
                    i += 1;
                }
                remaining--;
            }
            return i;
        }

        private static int CodeUnitIndexToScalarIndex(string text, int codeUnitIndex)
        {
            string value = text ?? string.Empty;
            int limit = Math.Max(0, Math.Min(value.Length, codeUnitIndex));
            int i = 0;
            int scalars = 0;
            while (i < limit)
            {
                if (char.IsHighSurrogate(value, i) && i + 1 < limit && char.IsLowSurrogate(value, i + 1))
                {
                    i += 2;
                }
                else
                {
                    i += 1;
                }
                scalars++;
            }
            return scalars;
        }

        private static void FreeRetiredBuffers(RetiredBuffers retired)
        {
            if (retired.Bitmap != null)
            {
                try
                {
                    retired.Bitmap.Dispose();
                }
                catch
                {
                }
            }

            if (retired.PixelBufferHandle.IsAllocated)
            {
                try
                {
                    retired.PixelBufferHandle.Free();
                }
                catch
                {
                }
            }
        }

        private struct RetiredBuffers
        {
            public GCHandle PixelBufferHandle;
            public Bitmap Bitmap;
        }
    }
}
