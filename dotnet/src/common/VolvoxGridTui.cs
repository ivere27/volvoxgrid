using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using VolvoxGrid.DotNet.Internal;
using Volvoxgrid.V1;

namespace VolvoxGrid.DotNet
{
    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    public struct VolvoxGridTuiCell
    {
        public const byte AttrBold = 1;
        public const byte AttrItalic = 1 << 1;
        public const byte AttrUnderline = 1 << 2;
        public const byte AttrReverse = 1 << 3;
        public const uint ResetColor = 0x01000000;
        public const uint ResetBackground = ResetColor;

        public uint Codepoint;
        public uint Foreground;
        public uint Background;
        public byte Attributes;

        public static int ByteSize
        {
            get { return Marshal.SizeOf(typeof(VolvoxGridTuiCell)); }
        }

        public string Text
        {
            get
            {
                if (Codepoint == 0)
                {
                    return " ";
                }

                try
                {
                    return char.ConvertFromUtf32(unchecked((int)Codepoint));
                }
                catch
                {
                    return " ";
                }
            }
        }

        public override string ToString()
        {
            return Text;
        }
    }

    public sealed class VolvoxGridTuiFrame
    {
        private readonly VolvoxGridTuiCell[] _cells;

        internal VolvoxGridTuiFrame(
            VolvoxGridTuiCell[] cells,
            int width,
            int height,
            int stride,
            bool rendered,
            int dirtyX,
            int dirtyY,
            int dirtyW,
            int dirtyH,
            FrameMetrics metrics)
        {
            _cells = cells ?? new VolvoxGridTuiCell[0];
            Width = width;
            Height = height;
            Stride = stride;
            Rendered = rendered;
            DirtyX = dirtyX;
            DirtyY = dirtyY;
            DirtyW = dirtyW;
            DirtyH = dirtyH;
            Metrics = metrics;
        }

        public VolvoxGridTuiCell[] Cells
        {
            get { return _cells; }
        }

        public int Width { get; private set; }

        public int Height { get; private set; }

        public int Stride { get; private set; }

        public bool Rendered { get; private set; }

        public int DirtyX { get; private set; }

        public int DirtyY { get; private set; }

        public int DirtyW { get; private set; }

        public int DirtyH { get; private set; }

        public FrameMetrics Metrics { get; private set; }

        public VolvoxGridTuiCell GetCell(int row, int col)
        {
            if (row < 0 || row >= Height)
            {
                throw new ArgumentOutOfRangeException("row");
            }
            if (col < 0 || col >= Width)
            {
                throw new ArgumentOutOfRangeException("col");
            }

            return _cells[row * Stride + col];
        }

        public string GetRowText(int row)
        {
            if (row < 0 || row >= Height)
            {
                throw new ArgumentOutOfRangeException("row");
            }

            var builder = new StringBuilder(Width);
            int start = row * Stride;
            for (int col = 0; col < Width; col += 1)
            {
                builder.Append(_cells[start + col].Text);
            }
            return builder.ToString();
        }
    }

    public sealed class VolvoxGridTuiSession : IDisposable
    {
        private const int ExpectedCellSize = 13;
        public const int RendererModeValue = 5;

        private readonly Internal.VolvoxClient _client;
        private readonly long _gridId;
        private readonly SynurangReflectionStream _renderStream;
        private readonly SynurangReflectionStream _eventStream;
        private readonly object _sendLock = new object();
        private readonly object _renderLock = new object();
        private readonly object _queueLock = new object();
        private readonly Queue<GridEvent> _gridEvents = new Queue<GridEvent>();
        private readonly Queue<RenderOutput> _renderOutputs = new Queue<RenderOutput>();

        private Thread _eventThread;
        private VolvoxGridTuiCell[] _buffer = new VolvoxGridTuiCell[0];
        private GCHandle _bufferHandle;
        private int _width;
        private int _height;
        private bool _viewportNeedsSync = true;
        private FrameMetrics _lastMetrics;
        private bool _decisionChannelRequested;
        private bool _decisionChannelHandshakeSent;
        private bool _disposed;

        internal VolvoxGridTuiSession(Internal.VolvoxClient client, long gridId)
        {
            if (client == null)
            {
                throw new ArgumentNullException("client");
            }
            if (gridId == 0)
            {
                throw new ArgumentOutOfRangeException("gridId");
            }
            if (VolvoxGridTuiCell.ByteSize != ExpectedCellSize)
            {
                throw new InvalidOperationException(
                    "VolvoxGridTuiCell ABI mismatch: expected "
                    + ExpectedCellSize
                    + " bytes but got "
                    + VolvoxGridTuiCell.ByteSize
                    + ".");
            }

            _client = client;
            _gridId = gridId;
            _renderStream = _client.OpenRenderSession();
            _eventStream = _client.OpenEventStream(gridId);
            _eventThread = new Thread(EventLoop);
            _eventThread.IsBackground = true;
            _eventThread.Name = "volvoxgrid-dotnet-tui-events";
            _eventThread.Start();
        }

        public long GridId
        {
            get
            {
                EnsureNotDisposed();
                return _gridId;
            }
        }

        public int ViewportWidth
        {
            get
            {
                EnsureNotDisposed();
                return _width;
            }
        }

        public int ViewportHeight
        {
            get
            {
                EnsureNotDisposed();
                return _height;
            }
        }

        public FrameMetrics LastMetrics
        {
            get
            {
                EnsureNotDisposed();
                return _lastMetrics;
            }
        }

        public void EnableEventDecisionChannel()
        {
            EnsureNotDisposed();
            _decisionChannelRequested = true;
            EnsureDecisionChannelEnabled();
        }

        public void SendEventDecision(long eventId, bool cancel)
        {
            EnsureNotDisposed();
            SendInput(new RenderInput
            {
                GridId = _gridId,
                EventDecision = new EventDecision
                {
                    GridId = _gridId,
                    EventId = eventId,
                    Cancel = cancel,
                },
            });
        }

        public void SendInput(RenderInput input)
        {
            EnsureNotDisposed();
            if (input == null)
            {
                throw new ArgumentNullException("input");
            }

            if (input.GridId == 0)
            {
                input.GridId = _gridId;
            }
            else if (input.GridId != _gridId)
            {
                throw new ArgumentException("RenderInput.GridId does not match the TUI session grid.");
            }

            lock (_sendLock)
            {
                _renderStream.Send(input.ToByteArray());
            }
        }

        public void SendPointer(
            PointerEvent_Type type,
            float viewportX,
            float viewportY,
            int modifier = 0,
            int button = 0,
            bool dblClick = false)
        {
            SendInput(new RenderInput
            {
                GridId = _gridId,
                Pointer = new PointerEvent
                {
                    Type = type,
                    X = viewportX,
                    Y = viewportY,
                    Modifier = modifier,
                    Button = button,
                    DblClick = dblClick,
                },
            });
        }

        public void SendKey(
            KeyEvent_Type type,
            int keyCode,
            int modifier = 0,
            string character = null)
        {
            SendInput(new RenderInput
            {
                GridId = _gridId,
                Key = new KeyEvent
                {
                    Type = type,
                    KeyCode = keyCode,
                    Modifier = modifier,
                    Character = character ?? string.Empty,
                },
            });
        }

        public void SendScroll(float deltaX, float deltaY)
        {
            SendInput(new RenderInput
            {
                GridId = _gridId,
                Scroll = new ScrollEvent
                {
                    DeltaX = deltaX,
                    DeltaY = deltaY,
                },
            });
        }

        public VolvoxGridTuiFrame Render(int width, int height)
        {
            EnsureNotDisposed();
            if (width <= 0)
            {
                throw new ArgumentOutOfRangeException("width");
            }
            if (height <= 0)
            {
                throw new ArgumentOutOfRangeException("height");
            }

            lock (_renderLock)
            {
                EnsureBuffer(width, height);
                EnsureDecisionChannelEnabled();
                SyncViewport(width, height);

                IntPtr bufferPtr = _bufferHandle.AddrOfPinnedObject();
                var handle = bufferPtr.ToInt64();
                lock (_sendLock)
                {
                    _renderStream.Send(
                        new RenderInput
                        {
                            GridId = _gridId,
                            Buffer = new BufferReady
                            {
                                Handle = handle,
                                Stride = width * VolvoxGridTuiCell.ByteSize,
                                Width = width,
                                Height = height,
                            },
                        }.ToByteArray());
                }

                while (true)
                {
                    byte[] payload = _renderStream.Recv();
                    if (payload == null)
                    {
                        throw new InvalidOperationException("VolvoxGrid TUI render stream closed.");
                    }
                    if (payload.Length == 0)
                    {
                        continue;
                    }

                    RenderOutput output = RenderOutput.ParseFrom(payload);
                    if (output != null
                        && output.EventCase == RenderOutput.EventOneofCase.FrameDone
                        && output.FrameDone != null
                        && output.FrameDone.Handle == handle)
                    {
                        _lastMetrics = output.FrameDone.Metrics;
                        return new VolvoxGridTuiFrame(
                            _buffer,
                            width,
                            height,
                            width,
                            output.Rendered,
                            output.FrameDone.DirtyX,
                            output.FrameDone.DirtyY,
                            output.FrameDone.DirtyW,
                            output.FrameDone.DirtyH,
                            output.FrameDone.Metrics);
                    }

                    if (output != null && output.EventCase != RenderOutput.EventOneofCase.None)
                    {
                        lock (_queueLock)
                        {
                            _renderOutputs.Enqueue(output);
                        }
                    }
                }
            }
        }

        public bool TryDequeueGridEvent(out GridEvent gridEvent)
        {
            EnsureNotDisposed();
            lock (_queueLock)
            {
                if (_gridEvents.Count > 0)
                {
                    gridEvent = _gridEvents.Dequeue();
                    return true;
                }
            }

            gridEvent = null;
            return false;
        }

        public bool TryDequeueRenderOutput(out RenderOutput renderOutput)
        {
            EnsureNotDisposed();
            lock (_queueLock)
            {
                if (_renderOutputs.Count > 0)
                {
                    renderOutput = _renderOutputs.Dequeue();
                    return true;
                }
            }

            renderOutput = null;
            return false;
        }

        public void Dispose()
        {
            if (_disposed)
            {
                return;
            }

            _disposed = true;

            try
            {
                _renderStream.CloseSend();
            }
            catch
            {
            }

            try
            {
                _eventStream.CloseSend();
            }
            catch
            {
            }

            try
            {
                _renderStream.Dispose();
            }
            catch
            {
            }

            try
            {
                _eventStream.Dispose();
            }
            catch
            {
            }

            if (_eventThread != null)
            {
                try
                {
                    _eventThread.Join(2000);
                }
                catch
                {
                }
                _eventThread = null;
            }

            ReleaseBuffer();
        }

        private void EnsureDecisionChannelEnabled()
        {
            if (!_decisionChannelRequested || _decisionChannelHandshakeSent)
            {
                return;
            }

            SendEventDecision(0, false);
            _decisionChannelHandshakeSent = true;
        }

        private void SyncViewport(int width, int height)
        {
            if (_width == width && _height == height && !_viewportNeedsSync)
            {
                return;
            }

            _width = width;
            _height = height;
            _viewportNeedsSync = false;

            lock (_sendLock)
            {
                _renderStream.Send(
                    new RenderInput
                    {
                        GridId = _gridId,
                        Viewport = new ViewportState
                        {
                            ScrollX = 0.0f,
                            ScrollY = 0.0f,
                            Width = width,
                            Height = height,
                        },
                    }.ToByteArray());
            }
        }

        private void EnsureBuffer(int width, int height)
        {
            int needed = checked(width * height);
            if (_buffer.Length == needed)
            {
                return;
            }

            ReleaseBuffer();
            _buffer = new VolvoxGridTuiCell[needed];
            _bufferHandle = GCHandle.Alloc(_buffer, GCHandleType.Pinned);
        }

        private void ReleaseBuffer()
        {
            if (_bufferHandle.IsAllocated)
            {
                _bufferHandle.Free();
            }
            _buffer = new VolvoxGridTuiCell[0];
        }

        private void EventLoop()
        {
            try
            {
                while (!_disposed)
                {
                    byte[] payload = _eventStream.Recv();
                    if (payload == null)
                    {
                        break;
                    }
                    if (payload.Length == 0)
                    {
                        continue;
                    }

                    GridEvent gridEvent = GridEvent.ParseFrom(payload);
                    if (gridEvent == null)
                    {
                        continue;
                    }

                    lock (_queueLock)
                    {
                        _gridEvents.Enqueue(gridEvent);
                    }
                }
            }
            catch
            {
            }
        }

        private void EnsureNotDisposed()
        {
            if (_disposed)
            {
                throw new ObjectDisposedException("VolvoxGridTuiSession");
            }
        }
    }
}
