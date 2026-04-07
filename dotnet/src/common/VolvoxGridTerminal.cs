using System;
using System.Runtime.InteropServices;
using VolvoxGrid.DotNet.Internal;
using Volvoxgrid.V1;

namespace VolvoxGrid.DotNet
{
    public enum VolvoxGridTerminalColorLevel
    {
        Auto = 0,
        Truecolor = 1,
        Indexed256 = 2,
        Ansi16 = 3,
    }

    public enum VolvoxGridTerminalRenderKind
    {
        Frame = 0,
        SessionStart = 1,
        SessionEnd = 2,
    }

    public sealed class VolvoxGridTerminalCapabilities
    {
        public VolvoxGridTerminalColorLevel ColorLevel { get; set; }

        public bool SgrMouse { get; set; } = true;

        public bool FocusEvents { get; set; } = true;

        public bool BracketedPaste { get; set; } = true;

        internal TerminalCapabilities ToProto()
        {
            return new TerminalCapabilities
            {
                ColorLevel = (TerminalColorLevel)ColorLevel,
                SgrMouse = SgrMouse,
                FocusEvents = FocusEvents,
                BracketedPaste = BracketedPaste,
            };
        }
    }

    public sealed class VolvoxGridTerminalFrame
    {
        private readonly byte[] _buffer;

        internal VolvoxGridTerminalFrame(
            byte[] buffer,
            int bytesWritten,
            bool rendered,
            VolvoxGridTerminalRenderKind kind,
            FrameMetrics metrics)
        {
            _buffer = buffer ?? new byte[0];
            BytesWritten = Math.Max(0, bytesWritten);
            Rendered = rendered;
            Kind = kind;
            Metrics = metrics;
        }

        public byte[] Buffer
        {
            get { return _buffer; }
        }

        public int BytesWritten { get; private set; }

        public bool Rendered { get; private set; }

        public VolvoxGridTerminalRenderKind Kind { get; private set; }

        public FrameMetrics Metrics { get; private set; }
    }

    public sealed class VolvoxGridTerminalSession : IDisposable
    {
        private const int DefaultBufferCapacity = 32 * 1024;

        private readonly VolvoxClient _client;
        private readonly long _gridId;
        private readonly SynurangReflectionStream _renderStream;
        private readonly object _sendLock = new object();
        private readonly object _renderLock = new object();

        private VolvoxGridTerminalCapabilities _capabilities = new VolvoxGridTerminalCapabilities();
        private bool _capabilitiesDirty = true;
        private byte[] _buffer = new byte[0];
        private GCHandle _bufferHandle;
        private int _originX;
        private int _originY;
        private int _width;
        private int _height;
        private bool _fullscreen;
        private bool _viewportDirty = true;
        private FrameMetrics _lastMetrics;
        private bool _disposed;

        internal VolvoxGridTerminalSession(VolvoxClient client, long gridId)
        {
            if (client == null)
            {
                throw new ArgumentNullException("client");
            }
            if (gridId == 0)
            {
                throw new ArgumentOutOfRangeException("gridId");
            }

            _client = client;
            _gridId = gridId;
            _renderStream = _client.OpenRenderSession();
        }

        public long GridId
        {
            get
            {
                EnsureNotDisposed();
                return _gridId;
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

        public void SetCapabilities(VolvoxGridTerminalCapabilities capabilities)
        {
            EnsureNotDisposed();
            _capabilities = capabilities ?? new VolvoxGridTerminalCapabilities();
            _capabilitiesDirty = true;
        }

        public void SetViewport(int originX, int originY, int width, int height, bool fullscreen)
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

            if (_originX == originX
                && _originY == originY
                && _width == width
                && _height == height
                && _fullscreen == fullscreen
                && !_viewportDirty)
            {
                return;
            }

            _originX = Math.Max(0, originX);
            _originY = Math.Max(0, originY);
            _width = width;
            _height = height;
            _fullscreen = fullscreen;
            _viewportDirty = true;
        }

        public void SendInputBytes(byte[] data, int count)
        {
            SendInputBytes(data, 0, count);
        }

        public void SendInputBytes(byte[] data, int offset, int count)
        {
            EnsureNotDisposed();
            if (data == null)
            {
                throw new ArgumentNullException("data");
            }
            if (offset < 0 || count < 0 || offset + count > data.Length)
            {
                throw new ArgumentOutOfRangeException("offset");
            }
            if (count == 0)
            {
                return;
            }

            byte[] payload;
            if (offset == 0 && count == data.Length)
            {
                payload = data;
            }
            else
            {
                payload = new byte[count];
                Buffer.BlockCopy(data, offset, payload, 0, count);
            }

            SendInput(new RenderInput
            {
                GridId = _gridId,
                TerminalInput = new TerminalInputBytes
                {
                    Data = payload,
                },
            });
        }

        public VolvoxGridTerminalFrame Render()
        {
            EnsureNotDisposed();
            if (_width <= 0 || _height <= 0)
            {
                throw new InvalidOperationException("SetViewport must be called before Render.");
            }

            lock (_renderLock)
            {
                EnsureTerminalStateSent();

                while (true)
                {
                    EnsureBuffer(DefaultBufferCapacity);
                    VolvoxGridTerminalFrame frame = RequestFrame();
                    if (frame.BytesWritten > 0 || frame.Kind != VolvoxGridTerminalRenderKind.Frame)
                    {
                        return frame;
                    }
                    return frame;
                }
            }
        }

        public VolvoxGridTerminalFrame Shutdown()
        {
            EnsureNotDisposed();
            lock (_renderLock)
            {
                SendInput(new RenderInput
                {
                    GridId = _gridId,
                    TerminalCommand = new TerminalCommand
                    {
                        Kind = TerminalCommand_Kind.TERMINAL_COMMAND_EXIT,
                    },
                });

                while (true)
                {
                    EnsureBuffer(256);
                    VolvoxGridTerminalFrame frame = RequestFrame();
                    if (frame.Kind == VolvoxGridTerminalRenderKind.SessionEnd || frame.BytesWritten > 0)
                    {
                        return frame;
                    }
                    return frame;
                }
            }
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
                _renderStream.Dispose();
            }
            catch
            {
            }
            ReleaseBuffer();
        }

        private void EnsureTerminalStateSent()
        {
            if (_capabilitiesDirty)
            {
                SendInput(new RenderInput
                {
                    GridId = _gridId,
                    TerminalCapabilities = _capabilities.ToProto(),
                });
                _capabilitiesDirty = false;
            }

            if (_viewportDirty)
            {
                SendInput(new RenderInput
                {
                    GridId = _gridId,
                    TerminalViewport = new TerminalViewport
                    {
                        OriginX = _originX,
                        OriginY = _originY,
                        Width = _width,
                        Height = _height,
                        Fullscreen = _fullscreen,
                    },
                });
                _viewportDirty = false;
            }
        }

        private VolvoxGridTerminalFrame RequestFrame()
        {
            while (true)
            {
                IntPtr bufferPtr = _bufferHandle.AddrOfPinnedObject();
                long handle = bufferPtr.ToInt64();

                lock (_sendLock)
                {
                    _renderStream.Send(
                        new RenderInput
                        {
                            GridId = _gridId,
                            Buffer = new BufferReady
                            {
                                Handle = handle,
                                Capacity = _buffer.Length,
                                Width = _width,
                                Height = _height,
                            },
                        }.ToByteArray());
                }

                while (true)
                {
                    byte[] payload = _renderStream.Recv();
                    if (payload == null)
                    {
                        throw new InvalidOperationException("VolvoxGrid terminal render stream closed.");
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
                        if (output.FrameDone.RequiredCapacity > _buffer.Length)
                        {
                            EnsureBuffer(output.FrameDone.RequiredCapacity);
                            break;
                        }

                        _lastMetrics = output.FrameDone.Metrics;
                        return new VolvoxGridTerminalFrame(
                            _buffer,
                            output.FrameDone.BytesWritten,
                            output.Rendered,
                            (VolvoxGridTerminalRenderKind)output.FrameDone.FrameKind,
                            output.FrameDone.Metrics);
                    }
                }
            }
        }

        private void SendInput(RenderInput input)
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
                throw new ArgumentException("RenderInput.GridId does not match the terminal session grid.");
            }

            lock (_sendLock)
            {
                _renderStream.Send(input.ToByteArray());
            }
        }

        private void EnsureBuffer(int capacity)
        {
            int target = Math.Max(DefaultBufferCapacity, capacity);
            if (_buffer.Length >= target)
            {
                return;
            }

            ReleaseBuffer();
            _buffer = new byte[target];
            _bufferHandle = GCHandle.Alloc(_buffer, GCHandleType.Pinned);
        }

        private void ReleaseBuffer()
        {
            if (_bufferHandle.IsAllocated)
            {
                _bufferHandle.Free();
            }
            _buffer = new byte[0];
        }

        private void EnsureNotDisposed()
        {
            if (_disposed)
            {
                throw new ObjectDisposedException("VolvoxGridTerminalSession");
            }
        }
    }
}
