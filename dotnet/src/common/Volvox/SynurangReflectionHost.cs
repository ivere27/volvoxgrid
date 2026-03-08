using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;

namespace VolvoxGrid.DotNet.Internal
{
    internal sealed class SynurangReflectionHost : IDisposable
    {
        internal sealed class SynurangFfiException : InvalidOperationException
        {
            public int Code { get; private set; }
            public int GrpcCode { get; private set; }
            public byte[] Payload { get; private set; }

            public SynurangFfiException(string message, int code, int grpcCode, byte[] payload)
                : base(message)
            {
                Code = code;
                GrpcCode = grpcCode;
                Payload = payload ?? new byte[0];
            }
        }

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
                if (respLen < 0)
                {
                    int errorLen = -respLen;
                    byte[] errorPayload = CopyAndFreeResponse(respPtr, errorLen);
                    throw DecodeFfiError(
                        errorPayload,
                        "Synurang invoke failed for method " + method);
                }

                if (respPtr == IntPtr.Zero)
                {
                    if (respLen == 0)
                    {
                        return new byte[0];
                    }

                    throw new InvalidOperationException(
                        "Synurang invoke failed for method " + method + ": plugin returned null");
                }

                if (respLen == 0)
                {
                    _free(respPtr);
                    return new byte[0];
                }

                return NormalizeUnaryPayload(
                    method,
                    CopyAndFreeResponse(respPtr, respLen));
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
                if (ptr == IntPtr.Zero || len <= 0)
                {
                    return new byte[0];
                }

                byte[] buffer = new byte[len];
                Marshal.Copy(ptr, buffer, 0, len);
                return buffer;
            }
            finally
            {
                if (ptr != IntPtr.Zero)
                {
                    _free(ptr);
                }
            }
        }

        private static byte[] NormalizeUnaryPayload(string method, byte[] payload)
        {
            if (payload == null || payload.Length == 0)
            {
                return new byte[0];
            }

            byte marker = payload[0];
            if (!LooksLikeLegacyFramedPayload(marker))
            {
                return payload;
            }

            byte[] body = SliceLegacyFrameBody(payload);
            if (marker == 0)
            {
                return body;
            }

            throw DecodeFfiError(
                body,
                "Synurang invoke failed for method " + method);
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

        internal static SynurangFfiException DecodeFfiError(byte[] payload, string context)
        {
            int code = 0;
            int grpcCode = 2;
            string message = null;
            int offset = 0;

            while (offset < payload.Length)
            {
                ulong tag = ReadVarint(payload, ref offset);
                if (tag == 0)
                {
                    break;
                }

                int field = (int)(tag >> 3);
                int wire = (int)(tag & 0x07);

                if (field == 1 && wire == 0)
                {
                    code = unchecked((int)ReadVarint(payload, ref offset));
                    continue;
                }

                if (field == 2 && wire == 2)
                {
                    int length = (int)ReadVarint(payload, ref offset);
                    if (length < 0 || offset + length > payload.Length)
                    {
                        offset = payload.Length;
                        break;
                    }

                    message = Encoding.UTF8.GetString(payload, offset, length);
                    offset += length;
                    continue;
                }

                if (field == 3 && wire == 0)
                {
                    grpcCode = unchecked((int)ReadVarint(payload, ref offset));
                    continue;
                }

                offset = SkipField(payload, offset, wire);
            }

            if (message == null)
            {
                message = payload.Length == 0 ? "Unknown plugin error" : Encoding.UTF8.GetString(payload);
            }

            return new SynurangFfiException(context + ": " + message, code, grpcCode, payload);
        }

        internal static bool LooksLikeLegacyFramedPayload(byte marker)
        {
            // Valid protobuf payloads never begin with field number 0, so marker values 0..7
            // are reserved for the legacy status-prefixed transport.
            return marker <= 0x07;
        }

        internal static byte[] SliceLegacyFrameBody(byte[] payload)
        {
            if (payload == null || payload.Length <= 1)
            {
                return new byte[0];
            }

            byte[] body = new byte[payload.Length - 1];
            Buffer.BlockCopy(payload, 1, body, 0, body.Length);
            return body;
        }

        private static ulong ReadVarint(byte[] payload, ref int offset)
        {
            ulong value = 0;
            int shift = 0;
            while (offset < payload.Length && shift < 64)
            {
                byte b = payload[offset++];
                value |= ((ulong)(b & 0x7f)) << shift;
                if ((b & 0x80) == 0)
                {
                    return value;
                }

                shift += 7;
            }

            offset = payload.Length;
            return 0;
        }

        private static int SkipField(byte[] payload, int offset, int wireType)
        {
            if (wireType == 0)
            {
                ReadVarint(payload, ref offset);
                return offset;
            }

            if (wireType == 2)
            {
                ulong length = ReadVarint(payload, ref offset);
                if (length > int.MaxValue)
                {
                    return payload.Length;
                }

                int next = offset + (int)length;
                if (next < offset || next > payload.Length)
                {
                    return payload.Length;
                }

                return next;
            }

            if (wireType == 1)
            {
                int next = offset + 8;
                return next > payload.Length ? payload.Length : next;
            }

            if (wireType == 5)
            {
                int next = offset + 4;
                return next > payload.Length ? payload.Length : next;
            }

            return payload.Length;
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
                if (ptr != IntPtr.Zero)
                {
                    _free(ptr);
                }
                return null;
            }

            if (status < 0)
            {
                byte[] errorPayload = CopyAndFreeResponse(ptr, respLen, _free);
                throw SynurangReflectionHost.DecodeFfiError(
                    errorPayload,
                    "Synurang stream recv failed");
            }

            if (status != 0)
            {
                if (ptr != IntPtr.Zero)
                {
                    _free(ptr);
                }
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

            byte marker = data[0];
            if (!SynurangReflectionHost.LooksLikeLegacyFramedPayload(marker))
            {
                return data;
            }

            byte[] body = SynurangReflectionHost.SliceLegacyFrameBody(data);
            if (marker == 0)
            {
                return body;
            }

            throw SynurangReflectionHost.DecodeFfiError(
                body,
                "Synurang stream recv failed");
        }

        private static byte[] CopyAndFreeResponse(
            IntPtr ptr,
            int len,
            SynurangReflectionHost.SynFreeDelegate free)
        {
            try
            {
                if (ptr == IntPtr.Zero || len <= 0)
                {
                    return new byte[0];
                }

                byte[] buffer = new byte[len];
                Marshal.Copy(ptr, buffer, 0, len);
                return buffer;
            }
            finally
            {
                if (ptr != IntPtr.Zero)
                {
                    free(ptr);
                }
            }
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
