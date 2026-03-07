using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;

namespace VolvoxGrid.DotNet.Internal
{
    internal sealed class RenderHostCpu : Control
    {
        private const int WmMouseHWheel = 0x020E;

        private readonly object _sendLock = new object();
        private readonly object _frameLock = new object();

        private VolvoxClient _client;
        private long _gridId;
        private Func<VolvoxGridEventData, bool?> _eventHandler;

        private SynurangReflectionStream _renderStream;
        private SynurangReflectionStream _eventStream;
        private Thread _renderThread;
        private Thread _eventThread;

        private bool _running;
        private bool _pendingFrame;
        private bool _followupFrame;

        private byte[] _pixelBuffer;
        private byte[] _blitBuffer;
        private GCHandle _pixelBufferHandle;
        private Bitmap _bitmap;
        private int _bufferWidth;
        private int _bufferHeight;
        private readonly List<RetiredBuffers> _retiredBuffers = new List<RetiredBuffers>();
        private VolvoxSelectionMode _selectionMode = VolvoxSelectionMode.Free;
        private bool _multiRangeDragActive;
        private readonly List<VolvoxCellRangeData> _multiRangeBaseRanges = new List<VolvoxCellRangeData>();
        private int _multiRangeAnchorRow = -1;
        private int _multiRangeAnchorCol = -1;
        private int _multiRangeDragRow = -1;
        private int _multiRangeDragCol = -1;

        public RenderHostCpu()
        {
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.UserPaint, true);
            TabStop = true;
            BackColor = Color.White;
        }

        public VolvoxSelectionMode SelectionMode
        {
            get { return _selectionMode; }
            set
            {
                _selectionMode = value;
                if (value != VolvoxSelectionMode.MultiRange)
                {
                    ClearMultiRangeDrag();
                }
            }
        }

        public void Attach(VolvoxClient client, long gridId, Func<VolvoxGridEventData, bool?> eventHandler)
        {
            if (client == null)
            {
                throw new ArgumentNullException("client");
            }

            Detach();

            _client = client;
            _gridId = gridId;
            _eventHandler = eventHandler;

            ResizeBuffers(Math.Max(1, ClientSize.Width), Math.Max(1, ClientSize.Height));

            _renderStream = _client.OpenRenderSession();
            _eventStream = _client.OpenEventStream(gridId);

            _running = true;
            StartRenderThread();
            StartEventThread();
            RequestFrame();
        }

        public bool Detach()
        {
            _running = false;
            _pendingFrame = false;
            _followupFrame = false;
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

            SendBufferReady();
        }

        public void SendEventDecision(long eventId, bool cancel)
        {
            if (!_running || _client == null || _renderStream == null || _gridId == 0 || eventId == 0)
            {
                return;
            }

            var payload = _client.EncodeRenderInputEventDecision(_gridId, eventId, cancel);
            SendRenderInput(payload);
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing)
            {
                Detach();
                ReleaseBuffers();
            }

            base.Dispose(disposing);
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

            ResizeBuffers(width, height);
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
            SendPointer(VolvoxPointerType.Down, e, e.Clicks >= 2);
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
            SendPointer(VolvoxPointerType.Up, e, false);
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
            SendPointer(VolvoxPointerType.Move, e, false);
            RequestFrame();
        }

        protected override void OnMouseWheel(MouseEventArgs e)
        {
            base.OnMouseWheel(e);
            bool horizontal = (ModifierKeys & Keys.Shift) == Keys.Shift;
            float dy = horizontal ? 0.0f : (-(float)e.Delta / 120.0f * 3.0f);
            float dx = horizontal ? ((float)e.Delta / 120.0f * 3.0f) : 0.0f;
            var payload = _client.EncodeRenderInputScroll(_gridId, dx, dy);
            SendRenderInput(payload);
            RequestFrame();
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
                        float dx = (float)delta / 120.0f * 3.0f;
                        var payload = _client.EncodeRenderInputScroll(_gridId, dx, 0.0f);
                        SendRenderInput(payload);
                        RequestFrame();
                    }
                }
                return;
            }

            base.WndProc(ref m);
        }

        protected override void OnKeyDown(KeyEventArgs e)
        {
            base.OnKeyDown(e);
            var payload = _client.EncodeRenderInputKey(_gridId, VolvoxKeyType.KeyDown, (int)e.KeyCode, GetModifiers(), string.Empty);
            SendRenderInput(payload);
            RequestFrame();
        }

        protected override void OnKeyUp(KeyEventArgs e)
        {
            base.OnKeyUp(e);
            var payload = _client.EncodeRenderInputKey(_gridId, VolvoxKeyType.KeyUp, (int)e.KeyCode, GetModifiers(), string.Empty);
            SendRenderInput(payload);
            RequestFrame();
        }

        protected override void OnKeyPress(KeyPressEventArgs e)
        {
            base.OnKeyPress(e);
            var payload = _client.EncodeRenderInputKey(_gridId, VolvoxKeyType.KeyPress, e.KeyChar, GetModifiers(), e.KeyChar.ToString());
            SendRenderInput(payload);
            RequestFrame();
        }

        protected override void OnPaint(PaintEventArgs e)
        {
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

                    VolvoxRenderOutputData output;
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

                    VolvoxGridEventData evt;
                    try
                    {
                        evt = _client.DecodeGridEvent(payload);
                    }
                    catch (Exception ex)
                    {
                        Debug.WriteLine("Volvox event decode error: " + ex.Message);
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

        private bool? DispatchEvent(VolvoxGridEventData evt)
        {
            if (_eventHandler == null)
            {
                return null;
            }

            if (IsHandleCreated && InvokeRequired)
            {
                try
                {
                    return (bool?)Invoke(new Func<VolvoxGridEventData, bool?>(DispatchEvent), evt);
                }
                catch
                {
                    return null;
                }
            }

            return _eventHandler(evt);
        }

        private void HandleRenderOutput(VolvoxRenderOutputData output)
        {
            if (output == null)
            {
                return;
            }

            if (output.Rendered && output.FrameDone != null)
            {
                BlitFrame(output.FrameDone);
            }

            bool shouldRequestAnother = false;
            List<RetiredBuffers> retiredToFree = null;
            lock (_frameLock)
            {
                if (output.FrameDone != null)
                {
                    _pendingFrame = false;
                    if (_followupFrame)
                    {
                        _followupFrame = false;
                        shouldRequestAnother = true;
                    }
                    else if (output.Rendered)
                    {
                        shouldRequestAnother = true;
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

            if (shouldRequestAnother)
            {
                RequestFrame();
            }
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

        private void SendPointer(VolvoxPointerType type, MouseEventArgs e, bool dblClick)
        {
            SendPointer(type, e.X, e.Y, GetModifiers(), MapMouseButton(e), dblClick);
        }

        private void SendPointer(VolvoxPointerType type, int x, int y, int modifier, int button, bool dblClick)
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
                VolvoxSelectionStateData state = UpdateMouseSelectionState(e);
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
                VolvoxSelectionStateData state = UpdateMouseSelectionState(e);
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
            return _selectionMode == VolvoxSelectionMode.MultiRange
                && (e.Button & MouseButtons.Left) == MouseButtons.Left
                && (Control.ModifierKeys & Keys.Control) == Keys.Control;
        }

        private VolvoxSelectionStateData UpdateMouseSelectionState(MouseEventArgs e)
        {
            SendPointer(VolvoxPointerType.Move, e.X, e.Y, GetModifiers(), 0, false);
            return _client.GetSelection(_gridId);
        }

        private static bool HasValidMouseCell(VolvoxSelectionStateData state)
        {
            return state != null && state.MouseRow >= 0 && state.MouseCol >= 0;
        }

        private static List<VolvoxCellRangeData> SnapshotMultiRangeBaseRanges(VolvoxSelectionStateData state, int anchorRow, int anchorCol)
        {
            var ranges = new List<VolvoxCellRangeData>();
            if (state == null)
            {
                return ranges;
            }

            if (state.Ranges == null || state.Ranges.Count == 0)
            {
                if (state.ActiveRow >= 0 && state.ActiveCol >= 0)
                {
                    ranges.Add(new VolvoxCellRangeData
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
                VolvoxCellRangeData range = state.Ranges[i];
                if (range.Row1 == anchorRow
                    && range.Col1 == anchorCol
                    && range.Row2 == anchorRow
                    && range.Col2 == anchorCol)
                {
                    continue;
                }

                ranges.Add(new VolvoxCellRangeData
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

            var ranges = new List<VolvoxCellRangeData>(_multiRangeBaseRanges.Count + 1);
            for (int i = 0; i < _multiRangeBaseRanges.Count; i++)
            {
                VolvoxCellRangeData range = _multiRangeBaseRanges[i];
                ranges.Add(new VolvoxCellRangeData
                {
                    Row1 = range.Row1,
                    Col1 = range.Col1,
                    Row2 = range.Row2,
                    Col2 = range.Col2,
                });
            }

            var nextRange = new VolvoxCellRangeData
            {
                Row1 = Math.Min(_multiRangeAnchorRow, targetRow),
                Col1 = Math.Min(_multiRangeAnchorCol, targetCol),
                Row2 = Math.Max(_multiRangeAnchorRow, targetRow),
                Col2 = Math.Max(_multiRangeAnchorCol, targetCol),
            };

            bool exists = false;
            for (int i = 0; i < ranges.Count; i++)
            {
                VolvoxCellRangeData range = ranges[i];
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

        private void BlitFrame(VolvoxFrameDoneData frame)
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

        private void InvalidateDirty(VolvoxFrameDoneData frame)
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
