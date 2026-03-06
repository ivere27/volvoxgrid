using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;

namespace VolvoxGrid.DotNet.Internal
{
    internal sealed class SynurangReflectionHost : IDisposable
    {
        [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
        internal delegate IntPtr SynInvokeDelegate(
            [MarshalAs(UnmanagedType.LPStr)] string method,
            IntPtr data,
            int dataLen,
            out int respLen);

        [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
        internal delegate ulong SynStreamOpenDelegate([MarshalAs(UnmanagedType.LPStr)] string method);

        [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
        internal delegate int SynStreamSendDelegate(ulong handle, IntPtr data, int dataLen);

        [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
        internal delegate IntPtr SynStreamRecvDelegate(ulong handle, out int respLen, out int status);

        [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
        internal delegate void SynStreamCloseSendDelegate(ulong handle);

        [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
        internal delegate void SynStreamCloseDelegate(ulong handle);

        [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
        internal delegate void SynFreeDelegate(IntPtr ptr);

        private readonly IntPtr _module;
        private readonly SynInvokeDelegate _invoke;
        private readonly SynStreamOpenDelegate _openStream;
        private readonly SynStreamSendDelegate _streamSend;
        private readonly SynStreamRecvDelegate _streamRecv;
        private readonly SynStreamCloseSendDelegate _streamCloseSend;
        private readonly SynStreamCloseDelegate _streamClose;
        private readonly SynFreeDelegate _free;

        private bool _disposed;

        private SynurangReflectionHost(
            IntPtr module,
            SynInvokeDelegate invoke,
            SynStreamOpenDelegate openStream,
            SynStreamSendDelegate streamSend,
            SynStreamRecvDelegate streamRecv,
            SynStreamCloseSendDelegate streamCloseSend,
            SynStreamCloseDelegate streamClose,
            SynFreeDelegate free)
        {
            _module = module;
            _invoke = invoke;
            _openStream = openStream;
            _streamSend = streamSend;
            _streamRecv = streamRecv;
            _streamCloseSend = streamCloseSend;
            _streamClose = streamClose;
            _free = free;
        }

        public static SynurangReflectionHost Load(string pluginPath)
        {
            if (string.IsNullOrEmpty(pluginPath))
            {
                throw new ArgumentException("Plugin path must be provided.", "pluginPath");
            }

            string pluginDir = Path.GetDirectoryName(pluginPath);
            if (!string.IsNullOrEmpty(pluginDir))
            {
                // Ensure dependent DLLs next to the plugin can be resolved by LoadLibrary.
                SetDllDirectory(pluginDir);
            }

            IntPtr module = LoadLibrary(pluginPath);
            if (module == IntPtr.Zero)
            {
                throw new InvalidOperationException("Failed to load plugin library: " + pluginPath);
            }

            try
            {
                IntPtr invokePtr = GetRequiredExport(module, "Synurang_Invoke_VolvoxGridService");
                IntPtr openPtr = GetRequiredExport(module, "Synurang_Stream_VolvoxGridService_Open");
                IntPtr sendPtr = GetRequiredExport(module, "Synurang_Stream_Send");
                IntPtr recvPtr = GetRequiredExport(module, "Synurang_Stream_Recv");
                IntPtr closeSendPtr = GetRequiredExport(module, "Synurang_Stream_CloseSend");
                IntPtr closePtr = GetRequiredExport(module, "Synurang_Stream_Close");
                IntPtr freePtr = GetRequiredExport(module, "Synurang_Free");

                var invoke = (SynInvokeDelegate)Marshal.GetDelegateForFunctionPointer(invokePtr, typeof(SynInvokeDelegate));
                var open = (SynStreamOpenDelegate)Marshal.GetDelegateForFunctionPointer(openPtr, typeof(SynStreamOpenDelegate));
                var send = (SynStreamSendDelegate)Marshal.GetDelegateForFunctionPointer(sendPtr, typeof(SynStreamSendDelegate));
                var recv = (SynStreamRecvDelegate)Marshal.GetDelegateForFunctionPointer(recvPtr, typeof(SynStreamRecvDelegate));
                var closeSend = (SynStreamCloseSendDelegate)Marshal.GetDelegateForFunctionPointer(closeSendPtr, typeof(SynStreamCloseSendDelegate));
                var close = (SynStreamCloseDelegate)Marshal.GetDelegateForFunctionPointer(closePtr, typeof(SynStreamCloseDelegate));
                var free = (SynFreeDelegate)Marshal.GetDelegateForFunctionPointer(freePtr, typeof(SynFreeDelegate));

                return new SynurangReflectionHost(module, invoke, open, send, recv, closeSend, close, free);
            }
            catch
            {
                FreeLibrary(module);
                throw;
            }
        }

        public byte[] Invoke(string service, string methodPath, byte[] payload)
        {
            EnsureNotDisposed();
            string method = methodPath ?? string.Empty;

            IntPtr dataPtr = IntPtr.Zero;
            try
            {
                int dataLen = payload == null ? 0 : payload.Length;
                if (dataLen > 0)
                {
                    dataPtr = Marshal.AllocHGlobal(dataLen);
                    Marshal.Copy(payload, 0, dataPtr, dataLen);
                }

                int respLen;
                IntPtr respPtr = _invoke(method, dataPtr, dataLen, out respLen);
                if (respPtr == IntPtr.Zero || respLen <= 0)
                {
                    return new byte[0];
                }

                byte[] responseWithStatus = CopyAndFreeResponse(respPtr, respLen);
                if (responseWithStatus.Length == 0)
                {
                    return new byte[0];
                }

                byte status = responseWithStatus[0];
                if (status == 0)
                {
                    int bodyLen = responseWithStatus.Length - 1;
                    if (bodyLen <= 0)
                    {
                        return new byte[0];
                    }

                    var body = new byte[bodyLen];
                    Buffer.BlockCopy(responseWithStatus, 1, body, 0, bodyLen);
                    return body;
                }

                string message = responseWithStatus.Length > 1
                    ? Encoding.UTF8.GetString(responseWithStatus, 1, responseWithStatus.Length - 1)
                    : "Unknown plugin error";
                throw new InvalidOperationException("Synurang invoke failed for method " + method + ": " + message);
            }
            finally
            {
                if (dataPtr != IntPtr.Zero)
                {
                    Marshal.FreeHGlobal(dataPtr);
                }
            }
        }

        public SynurangReflectionStream OpenStream(string service, string methodPath)
        {
            EnsureNotDisposed();
            string method = methodPath ?? string.Empty;
            ulong handle = _openStream(method);
            if (handle == 0)
            {
                throw new InvalidOperationException("Synurang openStream failed for method " + method);
            }

            return new SynurangReflectionStream(
                handle,
                _streamSend,
                _streamRecv,
                _streamCloseSend,
                _streamClose,
                _free);
        }

        public void Dispose()
        {
            if (_disposed)
            {
                return;
            }

            _disposed = true;
            if (_module != IntPtr.Zero)
            {
                if (ShouldFreeLibraryOnDispose())
                {
                    FreeLibrary(_module);
                }
            }
        }

        private byte[] CopyAndFreeResponse(IntPtr ptr, int len)
        {
            try
            {
                byte[] buffer = new byte[len];
                Marshal.Copy(ptr, buffer, 0, len);
                return buffer;
            }
            finally
            {
                _free(ptr);
            }
        }

        private void EnsureNotDisposed()
        {
            if (_disposed)
            {
                throw new ObjectDisposedException("SynurangReflectionHost");
            }
        }

        private static IntPtr GetRequiredExport(IntPtr module, string name)
        {
            IntPtr proc = GetProcAddress(module, name);
            if (proc == IntPtr.Zero)
            {
                throw new MissingMethodException("Missing required plugin export: " + name);
            }

            return proc;
        }

        [DllImport("kernel32", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern IntPtr LoadLibrary(string lpFileName);

        [DllImport("kernel32", CharSet = CharSet.Ansi, SetLastError = true)]
        private static extern IntPtr GetProcAddress(IntPtr hModule, string procName);

        [DllImport("kernel32", SetLastError = true)]
        private static extern bool FreeLibrary(IntPtr hModule);

        [DllImport("kernel32", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern bool SetDllDirectory(string lpPathName);

        private static bool ShouldFreeLibraryOnDispose()
        {
            // Under Wine Mono we observed execute faults during plugin unload when native worker
            // threads are still parking in Win32 synchronization shims. Keep the module loaded
            // for process lifetime by default on Mono; allow explicit opt-in unload for debugging.
            if (Environment.GetEnvironmentVariable("VOLVOXGRID_FORCE_FREE_LIBRARY") == "1")
            {
                return true;
            }

            return Type.GetType("Mono.Runtime") == null;
        }
    }

    internal sealed class SynurangReflectionStream : IDisposable
    {
        private readonly ulong _handle;
        private readonly SynurangReflectionHost.SynStreamSendDelegate _send;
        private readonly SynurangReflectionHost.SynStreamRecvDelegate _recv;
        private readonly SynurangReflectionHost.SynStreamCloseSendDelegate _closeSend;
        private readonly SynurangReflectionHost.SynStreamCloseDelegate _close;
        private readonly SynurangReflectionHost.SynFreeDelegate _free;
        private bool _disposed;

        public SynurangReflectionStream(
            ulong handle,
            SynurangReflectionHost.SynStreamSendDelegate send,
            SynurangReflectionHost.SynStreamRecvDelegate recv,
            SynurangReflectionHost.SynStreamCloseSendDelegate closeSend,
            SynurangReflectionHost.SynStreamCloseDelegate close,
            SynurangReflectionHost.SynFreeDelegate free)
        {
            _handle = handle;
            _send = send;
            _recv = recv;
            _closeSend = closeSend;
            _close = close;
            _free = free;
        }

        public void Send(byte[] payload)
        {
            EnsureNotDisposed();
            int len = payload == null ? 0 : payload.Length;
            IntPtr dataPtr = IntPtr.Zero;
            try
            {
                if (len > 0)
                {
                    dataPtr = Marshal.AllocHGlobal(len);
                    Marshal.Copy(payload, 0, dataPtr, len);
                }

                int rc = _send(_handle, dataPtr, len);
                if (rc != 0)
                {
                    throw new InvalidOperationException("Synurang stream send failed with status " + rc);
                }
            }
            finally
            {
                if (dataPtr != IntPtr.Zero)
                {
                    Marshal.FreeHGlobal(dataPtr);
                }
            }
        }

        public byte[] Recv()
        {
            EnsureNotDisposed();
            int respLen;
            int status;
            IntPtr ptr = _recv(_handle, out respLen, out status);

            if (status == 1)
            {
                return null;
            }

            if (status != 0)
            {
                throw new InvalidOperationException("Synurang stream recv failed with status " + status);
            }

            if (ptr == IntPtr.Zero || respLen <= 0)
            {
                return new byte[0];
            }

            try
            {
                byte[] data = new byte[respLen];
                Marshal.Copy(ptr, data, 0, respLen);
                return NormalizeStreamPayload(data);
            }
            finally
            {
                _free(ptr);
            }
        }

        private static byte[] NormalizeStreamPayload(byte[] data)
        {
            if (data == null || data.Length == 0)
            {
                return new byte[0];
            }

            // Stream payloads from the generated Rust bridge are status-prefixed:
            // [status:1][protobuf payload or utf8 error].
            byte marker = data[0];
            if (marker <= 0x07)
            {
                if (marker == 0)
                {
                    if (data.Length == 1)
                    {
                        return new byte[0];
                    }

                    byte[] payload = new byte[data.Length - 1];
                    Buffer.BlockCopy(data, 1, payload, 0, payload.Length);
                    return payload;
                }

                string message = data.Length > 1
                    ? Encoding.UTF8.GetString(data, 1, data.Length - 1)
                    : "Unknown stream error";
                throw new InvalidOperationException(
                    "Synurang stream recv returned status " + marker + ": " + message);
            }

            return data;
        }

        public void CloseSend()
        {
            EnsureNotDisposed();
            _closeSend(_handle);
        }

        public void Dispose()
        {
            if (_disposed)
            {
                return;
            }

            _disposed = true;
            _close(_handle);
        }

        private void EnsureNotDisposed()
        {
            if (_disposed)
            {
                throw new ObjectDisposedException("SynurangReflectionStream");
            }
        }
    }
}
