using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using Volvoxgrid.V1;

namespace VolvoxGrid.DotNet
{
    public sealed class VolvoxGridTerminalShortcut
    {
        public string Action { get; set; }

        public byte? CtrlKey { get; set; }

        public int? FunctionKey { get; set; }
    }

    public sealed class VolvoxGridTerminalActionOutcome
    {
        public bool Quit { get; set; }

        public bool ChromeDirty { get; set; }
    }

    public sealed class VolvoxGridTerminalHostInputOutcome
    {
        public byte[] ForwardedInput { get; set; }

        public bool ChromeDirty { get; set; }

        public bool Render { get; set; }

        public bool Quit { get; set; }
    }

    public sealed class VolvoxGridTerminalRunOptions
    {
        private IList<VolvoxGridTerminalShortcut> _shortcuts = new List<VolvoxGridTerminalShortcut>();

        public int MinWidth { get; set; } = 20;

        public int MinHeight { get; set; } = 6;

        public int HeaderRows { get; set; } = 1;

        public int FooterRows { get; set; } = 1;

        public int FrameDelayMs { get; set; } = 16;

        public IList<VolvoxGridTerminalShortcut> Shortcuts
        {
            get { return _shortcuts; }
            set { _shortcuts = value ?? new List<VolvoxGridTerminalShortcut>(); }
        }
    }

    public interface IVolvoxGridTerminalController
    {
        VolvoxGridTerminalSession EnsureSession(int viewportWidth, int viewportHeight);

        EditState GetCurrentEditState();

        void CancelActiveEdit();

        VolvoxGridTerminalActionOutcome HandleAction(string action, int viewportWidth, int viewportHeight);

        void DrawChrome(VolvoxGridTerminalHost terminal, int width, int height, string mode);
    }

    public interface IVolvoxGridTerminalHostInputHandler
    {
        VolvoxGridTerminalHostInputOutcome HandleHostInput(
            byte[] input,
            EditState editState,
            int viewportWidth,
            int viewportHeight);
    }

    public sealed class VolvoxGridTerminalDebugPanelContext
    {
        public int Width { get; set; }

        public int Height { get; set; }

        public int ViewportHeight { get; set; }

        public string Mode { get; set; }

        public EditState EditState { get; set; }

        public VolvoxGridTerminalCapabilities Capabilities { get; set; }

        public TimeSpan RenderDuration { get; set; }

        public double RenderFps { get; set; }

        public VolvoxGridTerminalFrame Frame { get; set; }
    }

    public interface IVolvoxGridTerminalDebugPanelProvider
    {
        bool DebugPanelVisible { get; }

        int DebugPanelRows { get; }

        void ToggleDebugPanel();

        IList<string> GetDebugPanelLines(VolvoxGridTerminalDebugPanelContext context);
    }

    public sealed class VolvoxGridTerminalHost : IDisposable
    {
        public const string ActionToggleDebugPanel = "toggle-debug-panel";

        private const ulong LinuxTioCgWinSz = 0x5413;
        private const ulong MacOsTioCgWinSz = 0x40087468;

        private readonly Stream _stdout;
        private readonly byte[] _readBuffer;
        private readonly string _savedSttyState;
        private readonly VolvoxGridTerminalCapabilities _capabilities;
        private readonly Queue<byte[]> _pendingInput = new Queue<byte[]>();
        private readonly object _inputLock = new object();
        private readonly object _errorLock = new object();
        private readonly AutoResetEvent _wakeEvent = new AutoResetEvent(false);
        private readonly Thread _inputThread;
#if NET6_0_OR_GREATER
        private readonly PosixSignalRegistration _winchRegistration;
#else
        private readonly Thread _resizeThread;
#endif
        private Exception _pendingError;
        private volatile bool _resizePending;
        private volatile bool _closeRequested;
        private bool _disposed;

        private const int ErrNoEintr = 4;
        private const int ErrNoEagain = 11;

        public VolvoxGridTerminalHost()
        {
            if (OperatingSystem.IsWindows())
            {
                throw new PlatformNotSupportedException("The thin terminal sample currently supports Unix-like terminals only.");
            }

            _stdout = Console.OpenStandardOutput();
            _readBuffer = new byte[2048];
            _savedSttyState = RunStty("-g", captureOutput: true).Trim();
            RunStty("cbreak -echo -ixon min 1 time 0", captureOutput: false);
            _capabilities = DetectTerminalCapabilitiesCore();
            _inputThread = new Thread(ReadLoop)
            {
                IsBackground = true,
                Name = "volvoxgrid-dotnet-tui-input",
            };
            _inputThread.Start();
#if NET6_0_OR_GREATER
            _winchRegistration = PosixSignalRegistration.Create(PosixSignal.SIGWINCH, context =>
            {
                context.Cancel = true;
                if (_closeRequested)
                {
                    return;
                }
                _resizePending = true;
                SignalWake();
            });
#else
            _resizeThread = new Thread(ResizeLoop)
            {
                IsBackground = true,
                Name = "volvoxgrid-dotnet-tui-resize",
            };
            _resizeThread.Start();
#endif
        }

        public int Width
        {
            get
            {
                int cols;
                int rows;
                if (TryGetUnixTerminalSize(out cols, out rows))
                {
                    return cols;
                }

                try
                {
                    return Math.Max(1, Console.WindowWidth);
                }
                catch
                {
                    return 80;
                }
            }
        }

        public int Height
        {
            get
            {
                int cols;
                int rows;
                if (TryGetUnixTerminalSize(out cols, out rows))
                {
                    return rows;
                }

                try
                {
                    return Math.Max(1, Console.WindowHeight);
                }
                catch
                {
                    return 24;
                }
            }
        }

        public VolvoxGridTerminalCapabilities DetectCapabilities()
        {
            return new VolvoxGridTerminalCapabilities
            {
                ColorLevel = _capabilities.ColorLevel,
                SgrMouse = _capabilities.SgrMouse,
                FocusEvents = _capabilities.FocusEvents,
                BracketedPaste = _capabilities.BracketedPaste,
            };
        }

        public byte[] ReadInput()
        {
            List<byte> bytes = new List<byte>();
            lock (_inputLock)
            {
                while (_pendingInput.Count > 0)
                {
                    bytes.AddRange(_pendingInput.Dequeue());
                }
            }
            return bytes.ToArray();
        }

        public void Write(byte[] buffer, int count)
        {
            if (buffer == null || count <= 0)
            {
                return;
            }

            _stdout.Write(buffer, 0, Math.Min(count, buffer.Length));
            _stdout.Flush();
        }

        public void WriteText(string text)
        {
            byte[] bytes = Encoding.UTF8.GetBytes(text ?? string.Empty);
            _stdout.Write(bytes, 0, bytes.Length);
            _stdout.Flush();
        }

        public void Dispose()
        {
            if (_disposed)
            {
                return;
            }

            _disposed = true;
            _closeRequested = true;
            SignalWake();

            try
            {
#if NET6_0_OR_GREATER
                _winchRegistration.Dispose();
#endif
            }
            catch
            {
            }

            try
            {
                WriteText("\x1b[0m\x1b[?25h\x1b[?1006l\x1b[?1002l\x1b[?1000l\x1b[?1004l\x1b[?2004l");
            }
            catch
            {
            }

            try
            {
                if (!string.IsNullOrEmpty(_savedSttyState))
                {
                    RunStty(_savedSttyState, captureOutput: false);
                }
            }
            catch
            {
            }
        }

        private void ReadLoop()
        {
            while (!_closeRequested)
            {
                int count = (int)read(0, _readBuffer, (nuint)_readBuffer.Length);
                if (count > 0)
                {
                    byte[] data = new byte[count];
                    Buffer.BlockCopy(_readBuffer, 0, data, 0, count);
                    lock (_inputLock)
                    {
                        _pendingInput.Enqueue(data);
                    }
                    SignalWake();
                    continue;
                }

                if (_closeRequested)
                {
                    return;
                }

                int errno = Marshal.GetLastWin32Error();
                if (count < 0 && (errno == ErrNoEintr || errno == ErrNoEagain))
                {
                    continue;
                }

                if (count == 0)
                {
                    SetPendingError(new EndOfStreamException("Terminal input stream closed."));
                }
                else
                {
                    SetPendingError(new IOException("Terminal input read failed with errno " + errno + "."));
                }
                return;
            }
        }

#if !NET6_0_OR_GREATER
        private void ResizeLoop()
        {
            int lastWidth = Width;
            int lastHeight = Height;

            while (!_closeRequested)
            {
                Thread.Sleep(100);
                if (_closeRequested)
                {
                    return;
                }

                int width = Width;
                int height = Height;
                if (width == lastWidth && height == lastHeight)
                {
                    continue;
                }

                lastWidth = width;
                lastHeight = height;
                _resizePending = true;
                SignalWake();
            }
        }
#endif

        private void SetPendingError(Exception error)
        {
            lock (_errorLock)
            {
                if (_pendingError == null)
                {
                    _pendingError = error;
                }
            }
            SignalWake();
        }

        private Exception TakePendingError()
        {
            lock (_errorLock)
            {
                Exception error = _pendingError;
                _pendingError = null;
                return error;
            }
        }

        private bool ConsumeResize()
        {
            if (!_resizePending)
            {
                return false;
            }
            _resizePending = false;
            return true;
        }

        private bool WaitForEvent(int timeoutMs)
        {
            return _wakeEvent.WaitOne(timeoutMs < 0 ? Timeout.Infinite : timeoutMs);
        }

        private void SignalWake()
        {
            try
            {
                _wakeEvent.Set();
            }
            catch (ObjectDisposedException)
            {
            }
        }

        public static void Run(
            VolvoxGridTerminalHost terminal,
            IVolvoxGridTerminalController controller,
            VolvoxGridTerminalRunOptions options)
        {
            if (terminal == null)
            {
                throw new ArgumentNullException("terminal");
            }
            if (controller == null)
            {
                throw new ArgumentNullException("controller");
            }

            VolvoxGridTerminalRunOptions normalizedOptions = NormalizeOptions(options);
            ShortcutRouter router = new ShortcutRouter(WithBuiltInShortcuts(normalizedOptions.Shortcuts));
            IVolvoxGridTerminalHostInputHandler hostInputHandler = controller as IVolvoxGridTerminalHostInputHandler;
            IVolvoxGridTerminalDebugPanelProvider debugPanel = controller as IVolvoxGridTerminalDebugPanelProvider;
            bool cancelled = false;
            int lastWidth = -1;
            int lastHeight = -1;
            bool chromeDirty = true;
            VolvoxGridTerminalSession session = null;
            bool needRender = true;
            bool animate = false;
            TimeSpan renderDuration = TimeSpan.Zero;
            double renderFps = 0.0;

            ConsoleCancelEventHandler cancelHandler = (sender, args) =>
            {
                args.Cancel = true;
                cancelled = true;
                terminal.SignalWake();
            };

            Console.CancelKeyPress += cancelHandler;
            try
            {
                while (!cancelled)
                {
                    if (needRender)
                    {
                        ChromeLayout layout = CalculateLayout(terminal, normalizedOptions, debugPanel);
                        int width = layout.Width;
                        int height = layout.Height;
                        int viewportHeight = layout.ViewportHeight;
                        if (width != lastWidth || height != lastHeight)
                        {
                            lastWidth = width;
                            lastHeight = height;
                            chromeDirty = true;
                        }

                        session = controller.EnsureSession(width, viewportHeight);
                        if (session == null)
                        {
                            throw new InvalidOperationException("EnsureSession returned null.");
                        }
                        VolvoxGridTerminalCapabilities capabilities = terminal.DetectCapabilities();
                        session.SetCapabilities(capabilities);
                        session.SetViewport(0, layout.HeaderRows, width, viewportHeight, fullscreen: false);

                        EditState editState = controller.GetCurrentEditState();
                        string mode = ModeLabel(editState);
                        if (chromeDirty)
                        {
                            controller.DrawChrome(terminal, width, height, mode);
                            chromeDirty = false;
                        }

                        Stopwatch renderWatch = Stopwatch.StartNew();
                        VolvoxGridTerminalFrame frame = session.Render();
                        renderWatch.Stop();
                        renderDuration = renderWatch.Elapsed;
                        renderFps = UpdateRenderFps(renderFps, renderDuration);
                        terminal.Write(frame.Buffer, frame.BytesWritten);
                        if (debugPanel != null && debugPanel.DebugPanelVisible)
                        {
                            IList<string> lines = debugPanel.GetDebugPanelLines(new VolvoxGridTerminalDebugPanelContext
                            {
                                Width = width,
                                Height = height,
                                ViewportHeight = viewportHeight,
                                Mode = mode,
                                EditState = editState,
                                Capabilities = capabilities,
                                RenderDuration = renderDuration,
                                RenderFps = renderFps,
                                Frame = frame,
                            });
                            WriteDebugPanel(terminal, normalizedOptions.HeaderRows, width, GetDebugPanelRows(debugPanel), lines);
                        }
                        needRender = false;
                        animate = frame != null && frame.Rendered;
                        continue;
                    }

                    int waitMs = animate && normalizedOptions.FrameDelayMs > 0
                        ? normalizedOptions.FrameDelayMs
                        : Timeout.Infinite;
                    bool signaled = terminal.WaitForEvent(waitMs);
                    if (!signaled)
                    {
                        if (animate)
                        {
                            needRender = true;
                        }
                        continue;
                    }
                    if (cancelled)
                    {
                        continue;
                    }

                    Exception pendingError = terminal.TakePendingError();
                    if (pendingError != null)
                    {
                        throw pendingError;
                    }

                    bool resized = terminal.ConsumeResize();
                    if (resized)
                    {
                        chromeDirty = true;
                        needRender = true;
                        animate = false;
                    }

                    byte[] input = terminal.ReadInput();
                    if (input.Length == 0)
                    {
                        continue;
                    }

                    ChromeLayout inputLayout = CalculateLayout(terminal, normalizedOptions, debugPanel);
                    int inputWidth = inputLayout.Width;
                    int inputHeight = inputLayout.Height;
                    int inputViewportHeight = inputLayout.ViewportHeight;
                    if (inputWidth != lastWidth || inputHeight != lastHeight)
                    {
                        lastWidth = inputWidth;
                        lastHeight = inputHeight;
                        chromeDirty = true;
                    }

                    session = controller.EnsureSession(inputWidth, inputViewportHeight);
                    if (session == null)
                    {
                        throw new InvalidOperationException("EnsureSession returned null.");
                    }
                    session.SetCapabilities(terminal.DetectCapabilities());
                    session.SetViewport(0, inputLayout.HeaderRows, inputWidth, inputViewportHeight, fullscreen: false);

                    ShortcutResult shortcutResult = router.Filter(input);
                    byte[] forwardedInput = shortcutResult.ForwardedInput;
                    if (hostInputHandler != null && forwardedInput.Length > 0)
                    {
                        EditState editState = controller.GetCurrentEditState();
                        VolvoxGridTerminalHostInputOutcome hostOutcome =
                            hostInputHandler.HandleHostInput(forwardedInput, editState, inputWidth, inputViewportHeight)
                            ?? new VolvoxGridTerminalHostInputOutcome();
                        forwardedInput = hostOutcome.ForwardedInput ?? Array.Empty<byte>();
                        if (hostOutcome.ChromeDirty)
                        {
                            chromeDirty = true;
                        }
                        if (hostOutcome.Render)
                        {
                            needRender = true;
                        }
                        if (hostOutcome.Quit)
                        {
                            cancelled = true;
                        }
                    }
                    if (cancelled)
                    {
                        continue;
                    }

                    if (forwardedInput.Length > 0)
                    {
                        session.SendInputBytes(forwardedInput, forwardedInput.Length);
                        needRender = true;
                    }

                    if (shortcutResult.Action == ActionToggleDebugPanel)
                    {
                        if (debugPanel != null)
                        {
                            debugPanel.ToggleDebugPanel();
                            chromeDirty = true;
                            needRender = true;
                        }
                    }
                    else if (shortcutResult.Action != null)
                    {
                        controller.CancelActiveEdit();
                        VolvoxGridTerminalActionOutcome outcome =
                            controller.HandleAction(shortcutResult.Action, inputWidth, inputViewportHeight)
                            ?? new VolvoxGridTerminalActionOutcome();
                        if (outcome.ChromeDirty)
                        {
                            chromeDirty = true;
                        }
                        if (outcome.Quit)
                        {
                            cancelled = true;
                            continue;
                        }

                        session = controller.EnsureSession(inputWidth, inputViewportHeight);
                        if (session == null)
                        {
                            throw new InvalidOperationException("EnsureSession returned null.");
                        }
                        session.SetCapabilities(terminal.DetectCapabilities());
                        session.SetViewport(0, inputLayout.HeaderRows, inputWidth, inputViewportHeight, fullscreen: false);
                        needRender = true;
                    }

                    if (chromeDirty)
                    {
                        needRender = true;
                    }
                    animate = false;
                }
            }
            finally
            {
                Console.CancelKeyPress -= cancelHandler;
                if (session != null)
                {
                    try
                    {
                        VolvoxGridTerminalFrame frame = session.Shutdown();
                        terminal.Write(frame.Buffer, frame.BytesWritten);
                    }
                    catch
                    {
                    }
                }
            }
        }

        public static string ModeLabel(EditState state)
        {
            if (state == null || !state.Active)
            {
                return "Ready";
            }
            return state.UiMode == EditUiMode.EDIT_UI_MODE_EDIT ? "Edit" : "Enter";
        }

        private static VolvoxGridTerminalRunOptions NormalizeOptions(VolvoxGridTerminalRunOptions options)
        {
            if (options == null)
            {
                return new VolvoxGridTerminalRunOptions();
            }
            if (options.MinWidth <= 0)
            {
                options.MinWidth = 20;
            }
            if (options.MinHeight <= 0)
            {
                options.MinHeight = 6;
            }
            if (options.HeaderRows < 0)
            {
                options.HeaderRows = 1;
            }
            if (options.FooterRows < 0)
            {
                options.FooterRows = 1;
            }
            if (options.FrameDelayMs < 0)
            {
                options.FrameDelayMs = 16;
            }
            return options;
        }

        private static IList<VolvoxGridTerminalShortcut> WithBuiltInShortcuts(IList<VolvoxGridTerminalShortcut> shortcuts)
        {
            List<VolvoxGridTerminalShortcut> all = new List<VolvoxGridTerminalShortcut>((shortcuts == null ? 0 : shortcuts.Count) + 1);
            all.Add(new VolvoxGridTerminalShortcut
            {
                Action = ActionToggleDebugPanel,
                FunctionKey = 12,
            });
            if (shortcuts != null)
            {
                for (int i = 0; i < shortcuts.Count; i += 1)
                {
                    all.Add(shortcuts[i]);
                }
            }
            return all;
        }

        private static ChromeLayout CalculateLayout(
            VolvoxGridTerminalHost terminal,
            VolvoxGridTerminalRunOptions options,
            IVolvoxGridTerminalDebugPanelProvider debugPanel)
        {
            int width = Math.Max(options.MinWidth, terminal.Width);
            int height = Math.Max(options.MinHeight, terminal.Height);
            int headerRows = Math.Max(0, options.HeaderRows);
            int footerRows = Math.Max(0, options.FooterRows);
            if (debugPanel != null && debugPanel.DebugPanelVisible)
            {
                headerRows += GetDebugPanelRows(debugPanel);
            }
            return new ChromeLayout
            {
                Width = width,
                Height = height,
                HeaderRows = headerRows,
                FooterRows = footerRows,
                ViewportHeight = Math.Max(1, height - headerRows - footerRows),
            };
        }

        private static double UpdateRenderFps(double current, TimeSpan renderDuration)
        {
            if (renderDuration <= TimeSpan.Zero)
            {
                return current;
            }
            double inst = 1.0 / renderDuration.TotalSeconds;
            if (current <= 0.0)
            {
                return inst;
            }
            return current * 0.9 + inst * 0.1;
        }

        private static int GetDebugPanelRows(IVolvoxGridTerminalDebugPanelProvider debugPanel)
        {
            if (debugPanel == null)
            {
                return 0;
            }
            return Math.Max(1, debugPanel.DebugPanelRows);
        }

        private static void WriteDebugPanel(
            VolvoxGridTerminalHost terminal,
            int baseHeaderRows,
            int width,
            int rows,
            IList<string> lines)
        {
            StringBuilder builder = new StringBuilder();
            for (int i = 0; i < rows; i += 1)
            {
                string line = lines != null && i < lines.Count ? lines[i] : string.Empty;
                int row = Math.Max(1, baseHeaderRows + 1 + i);
                builder.Append("\x1b[").Append(row).Append(";1H\x1b[0m").Append(FitChromeLine(line, width));
            }
            terminal.WriteText(builder.ToString());
        }

        private static string FitChromeLine(string text, int width)
        {
            string value = text ?? string.Empty;
            if (width <= 0)
            {
                return string.Empty;
            }
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

        private static VolvoxGridTerminalCapabilities DetectTerminalCapabilitiesCore()
        {
            string term = (Environment.GetEnvironmentVariable("TERM") ?? string.Empty).ToLowerInvariant();
            string colorTerm = (Environment.GetEnvironmentVariable("COLORTERM") ?? string.Empty).ToLowerInvariant();

            VolvoxGridTerminalColorLevel colorLevel;
            if (colorTerm.Contains("truecolor") || colorTerm.Contains("24bit"))
            {
                colorLevel = VolvoxGridTerminalColorLevel.Truecolor;
            }
            else if (term.Contains("256color"))
            {
                colorLevel = VolvoxGridTerminalColorLevel.Indexed256;
            }
            else
            {
                colorLevel = VolvoxGridTerminalColorLevel.Ansi16;
            }

            return new VolvoxGridTerminalCapabilities
            {
                ColorLevel = colorLevel,
                SgrMouse = true,
                FocusEvents = true,
                BracketedPaste = true,
            };
        }

        private static string RunStty(string arguments, bool captureOutput)
        {
            var startInfo = new ProcessStartInfo("stty", arguments)
            {
                UseShellExecute = false,
                RedirectStandardError = true,
                RedirectStandardOutput = captureOutput,
            };

            using (var process = Process.Start(startInfo))
            {
                string output = captureOutput ? process.StandardOutput.ReadToEnd() : string.Empty;
                process.WaitForExit();
                if (process.ExitCode != 0)
                {
                    string error = process.StandardError.ReadToEnd();
                    throw new InvalidOperationException("stty " + arguments + " failed: " + error);
                }
                return output ?? string.Empty;
            }
        }

        private static bool TryGetUnixTerminalSize(out int cols, out int rows)
        {
            cols = 0;
            rows = 0;

            ulong request;
            if (OperatingSystem.IsMacOS())
            {
                request = MacOsTioCgWinSz;
            }
            else if (OperatingSystem.IsLinux())
            {
                request = LinuxTioCgWinSz;
            }
            else
            {
                return false;
            }

            WinSize size;
            if (ioctl(1, request, out size) != 0)
            {
                return false;
            }
            if (size.Columns <= 1 || size.Rows <= 1)
            {
                return false;
            }

            cols = size.Columns;
            rows = size.Rows;
            return true;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct WinSize
        {
            public ushort Rows;
            public ushort Columns;
            public ushort XPixels;
            public ushort YPixels;
        }

        [DllImport("libc", SetLastError = true)]
        private static extern int ioctl(int fd, ulong request, out WinSize size);

        [DllImport("libc", SetLastError = true)]
        private static extern nint read(int fd, byte[] buffer, nuint count);

        private sealed class ChromeLayout
        {
            public int Width;
            public int Height;
            public int HeaderRows;
            public int FooterRows;
            public int ViewportHeight;
        }

        private sealed class ShortcutRouter
        {
            private readonly IList<VolvoxGridTerminalShortcut> _shortcuts;
            private readonly List<byte> _pending = new List<byte>();

            public ShortcutRouter(IList<VolvoxGridTerminalShortcut> shortcuts)
            {
                _shortcuts = shortcuts ?? new List<VolvoxGridTerminalShortcut>();
            }

            public ShortcutResult Filter(byte[] input)
            {
                byte[] mergedInput = MergePending(input);
                if (mergedInput.Length == 0)
                {
                    return ShortcutResult.Empty;
                }

                List<byte> forwarded = new List<byte>(mergedInput.Length);
                int index = 0;
                while (index < mergedInput.Length)
                {
                    byte value = mergedInput[index];
                    string ctrlAction = MatchCtrl(value);
                    if (ctrlAction != null)
                    {
                        return new ShortcutResult(forwarded.ToArray(), ctrlAction);
                    }

                    if (value == 0x1B)
                    {
                        int functionKey;
                        EscapeActionState state = TryDecodeFunctionKey(mergedInput, index, out functionKey, out int consumed);
                        if (state == EscapeActionState.NeedMoreData)
                        {
                            SavePending(mergedInput, index);
                            return new ShortcutResult(forwarded.ToArray(), null);
                        }
                        if (state == EscapeActionState.Matched)
                        {
                            string functionAction = MatchFunctionKey(functionKey);
                            if (functionAction != null)
                            {
                                return new ShortcutResult(forwarded.ToArray(), functionAction);
                            }

                            forwarded.AddRange(new ArraySegment<byte>(mergedInput, index, consumed));
                            index += consumed;
                            continue;
                        }

                        int forwardedConsumed = CopyEscapeSequence(mergedInput, index, forwarded);
                        if (forwardedConsumed <= 0)
                        {
                            SavePending(mergedInput, index);
                            return new ShortcutResult(forwarded.ToArray(), null);
                        }
                        index += forwardedConsumed;
                        continue;
                    }

                    forwarded.Add(value);
                    index += 1;
                }

                return new ShortcutResult(forwarded.ToArray(), null);
            }

            private byte[] MergePending(byte[] input)
            {
                if (_pending.Count == 0)
                {
                    return input ?? Array.Empty<byte>();
                }

                int inputLength = input == null ? 0 : input.Length;
                byte[] merged = new byte[_pending.Count + inputLength];
                _pending.CopyTo(merged, 0);
                if (inputLength > 0)
                {
                    Buffer.BlockCopy(input, 0, merged, _pending.Count, inputLength);
                }
                _pending.Clear();
                return merged;
            }

            private void SavePending(byte[] input, int start)
            {
                _pending.Clear();
                for (int index = start; index < input.Length; index += 1)
                {
                    _pending.Add(input[index]);
                }
            }

            private string MatchCtrl(byte value)
            {
                for (int i = 0; i < _shortcuts.Count; i += 1)
                {
                    VolvoxGridTerminalShortcut shortcut = _shortcuts[i];
                    if (shortcut == null || string.IsNullOrWhiteSpace(shortcut.Action) || !shortcut.CtrlKey.HasValue)
                    {
                        continue;
                    }
                    if (shortcut.CtrlKey.Value == value)
                    {
                        return shortcut.Action;
                    }
                }
                return null;
            }

            private string MatchFunctionKey(int functionKey)
            {
                for (int i = 0; i < _shortcuts.Count; i += 1)
                {
                    VolvoxGridTerminalShortcut shortcut = _shortcuts[i];
                    if (shortcut == null || string.IsNullOrWhiteSpace(shortcut.Action) || !shortcut.FunctionKey.HasValue)
                    {
                        continue;
                    }
                    if (shortcut.FunctionKey.Value == functionKey)
                    {
                        return shortcut.Action;
                    }
                }
                return null;
            }

            private static EscapeActionState TryDecodeFunctionKey(
                byte[] input,
                int start,
                out int functionKey,
                out int consumed)
            {
                functionKey = 0;
                consumed = 0;
                int remaining = input.Length - start;
                if (remaining <= 1)
                {
                    return EscapeActionState.NoMatch;
                }

                byte second = input[start + 1];
                if (second == (byte)'O')
                {
                    if (remaining < 3)
                    {
                        return EscapeActionState.NeedMoreData;
                    }
                    consumed = 3;
                    switch (input[start + 2])
                    {
                        case (byte)'P':
                            functionKey = 1;
                            return EscapeActionState.Matched;
                        case (byte)'Q':
                            functionKey = 2;
                            return EscapeActionState.Matched;
                        case (byte)'R':
                            functionKey = 3;
                            return EscapeActionState.Matched;
                        case (byte)'S':
                            functionKey = 4;
                            return EscapeActionState.Matched;
                        default:
                            return EscapeActionState.NoMatch;
                    }
                }

                if (second != (byte)'[')
                {
                    consumed = 2;
                    return EscapeActionState.NoMatch;
                }

                int index = start + 2;
                while (index < input.Length)
                {
                    byte value = input[index];
                    if (IsEscapeTerminator(value))
                    {
                        index += 1;
                        break;
                    }
                    index += 1;
                }

                if (index > input.Length)
                {
                    return EscapeActionState.NeedMoreData;
                }
                if (index == input.Length && !IsEscapeTerminator(input[index - 1]))
                {
                    return EscapeActionState.NeedMoreData;
                }

                consumed = index - start;
                if (input[index - 1] != (byte)'~')
                {
                    return EscapeActionState.NoMatch;
                }

                string payload = Encoding.ASCII.GetString(input, start + 2, consumed - 3);
                int separator = payload.IndexOf(';');
                string first = separator >= 0 ? payload.Substring(0, separator) : payload;
                if (!int.TryParse(first, out int code))
                {
                    return EscapeActionState.NoMatch;
                }

                switch (code)
                {
                    case 11:
                        functionKey = 1;
                        return EscapeActionState.Matched;
                    case 12:
                        functionKey = 2;
                        return EscapeActionState.Matched;
                    case 13:
                        functionKey = 3;
                        return EscapeActionState.Matched;
                    case 14:
                        functionKey = 4;
                        return EscapeActionState.Matched;
                    case 15:
                        functionKey = 5;
                        return EscapeActionState.Matched;
                    case 17:
                        functionKey = 6;
                        return EscapeActionState.Matched;
                    case 18:
                        functionKey = 7;
                        return EscapeActionState.Matched;
                    case 19:
                        functionKey = 8;
                        return EscapeActionState.Matched;
                    case 20:
                        functionKey = 9;
                        return EscapeActionState.Matched;
                    case 21:
                        functionKey = 10;
                        return EscapeActionState.Matched;
                    case 23:
                        functionKey = 11;
                        return EscapeActionState.Matched;
                    case 24:
                        functionKey = 12;
                        return EscapeActionState.Matched;
                    default:
                        return EscapeActionState.NoMatch;
                }
            }

            private static int CopyEscapeSequence(byte[] input, int start, List<byte> forwarded)
            {
                int remaining = input.Length - start;
                if (remaining <= 0)
                {
                    return 0;
                }

                if (remaining == 1)
                {
                    forwarded.Add(input[start]);
                    return 1;
                }

                byte second = input[start + 1];
                if (second == (byte)'O')
                {
                    if (remaining < 3)
                    {
                        return 0;
                    }
                    forwarded.Add(input[start]);
                    forwarded.Add(second);
                    forwarded.Add(input[start + 2]);
                    return 3;
                }

                if (second != (byte)'[')
                {
                    forwarded.Add(input[start]);
                    forwarded.Add(second);
                    return 2;
                }

                int index = start + 2;
                while (index < input.Length)
                {
                    byte value = input[index];
                    if (IsEscapeTerminator(value))
                    {
                        index += 1;
                        break;
                    }
                    index += 1;
                }
                if (index > input.Length)
                {
                    return 0;
                }
                if (index == input.Length && !IsEscapeTerminator(input[index - 1]))
                {
                    return 0;
                }

                int consumed = index - start;
                for (int i = 0; i < consumed; i += 1)
                {
                    forwarded.Add(input[start + i]);
                }
                return consumed;
            }

            private static bool IsEscapeTerminator(byte value)
            {
                return (value >= (byte)'A' && value <= (byte)'Z')
                    || (value >= (byte)'a' && value <= (byte)'z')
                    || value == (byte)'~';
            }
        }

        private enum EscapeActionState
        {
            NoMatch,
            Matched,
            NeedMoreData,
        }

        private sealed class ShortcutResult
        {
            public static readonly ShortcutResult Empty = new ShortcutResult(Array.Empty<byte>(), null);

            public ShortcutResult(byte[] forwardedInput, string action)
            {
                ForwardedInput = forwardedInput ?? Array.Empty<byte>();
                Action = action;
            }

            public byte[] ForwardedInput { get; private set; }

            public string Action { get; private set; }
        }
    }
}
