use std::ffi::{CStr, CString};
use std::path::Path;
use std::sync::{
    atomic::{AtomicBool, Ordering},
    Arc, Mutex,
};

type InvokeFunc = unsafe extern "C" fn(*const i8, *const u8, i32, *mut i32) -> *mut u8;
type FreeFunc = unsafe extern "C" fn(*mut u8);
type StreamOpenFunc = unsafe extern "C" fn(*const i8) -> u64;
type StreamSendFunc = unsafe extern "C" fn(u64, *const u8, i32) -> i32;
type StreamRecvFunc = unsafe extern "C" fn(u64, *mut i32, *mut i32) -> *mut u8;
type StreamCloseSendFunc = unsafe extern "C" fn(u64);
type StreamCloseFunc = unsafe extern "C" fn(u64);

pub struct PluginLibrary {
    handle: *mut libc::c_void,
    free_fn: FreeFunc,
    invoke_fn: InvokeFunc,
    stream_open_fn: StreamOpenFunc,
    stream_send_fn: StreamSendFunc,
    stream_recv_fn: StreamRecvFunc,
    stream_close_send_fn: StreamCloseSendFunc,
    stream_close_fn: StreamCloseFunc,
}

pub struct PluginStream {
    plugin: Arc<PluginLibrary>,
    handle: u64,
    closed: AtomicBool,
    send_lock: Mutex<()>,
}

unsafe impl Send for PluginLibrary {}
unsafe impl Sync for PluginLibrary {}
unsafe impl Send for PluginStream {}
unsafe impl Sync for PluginStream {}

impl PluginLibrary {
    pub fn load(path: &str) -> Result<Arc<Self>, String> {
        let c_path = CString::new(path).map_err(|_| format!("invalid plugin path: {path}"))?;
        let handle = unsafe { libc::dlopen(c_path.as_ptr(), libc::RTLD_LAZY) };
        if handle.is_null() {
            return Err(last_dlerror().unwrap_or_else(|| "dlopen failed".to_string()));
        }

        let free_fn = match lookup_symbol::<FreeFunc>(handle, "Synurang_Free") {
            Ok(symbol) => symbol,
            Err(err) => {
                unsafe { libc::dlclose(handle) };
                return Err(err);
            }
        };
        let invoke_fn =
            match lookup_symbol::<InvokeFunc>(handle, "Synurang_Invoke_VolvoxGridService") {
                Ok(symbol) => symbol,
                Err(err) => {
                    unsafe { libc::dlclose(handle) };
                    return Err(err);
                }
            };
        let stream_open_fn =
            match lookup_symbol::<StreamOpenFunc>(handle, "Synurang_Stream_VolvoxGridService_Open")
            {
                Ok(symbol) => symbol,
                Err(err) => {
                    unsafe { libc::dlclose(handle) };
                    return Err(err);
                }
            };
        let stream_send_fn = match lookup_symbol::<StreamSendFunc>(handle, "Synurang_Stream_Send") {
            Ok(symbol) => symbol,
            Err(err) => {
                unsafe { libc::dlclose(handle) };
                return Err(err);
            }
        };
        let stream_recv_fn = match lookup_symbol::<StreamRecvFunc>(handle, "Synurang_Stream_Recv") {
            Ok(symbol) => symbol,
            Err(err) => {
                unsafe { libc::dlclose(handle) };
                return Err(err);
            }
        };
        let stream_close_send_fn =
            match lookup_symbol::<StreamCloseSendFunc>(handle, "Synurang_Stream_CloseSend") {
                Ok(symbol) => symbol,
                Err(err) => {
                    unsafe { libc::dlclose(handle) };
                    return Err(err);
                }
            };
        let stream_close_fn =
            match lookup_symbol::<StreamCloseFunc>(handle, "Synurang_Stream_Close") {
                Ok(symbol) => symbol,
                Err(err) => {
                    unsafe { libc::dlclose(handle) };
                    return Err(err);
                }
            };

        Ok(Arc::new(Self {
            handle,
            free_fn,
            invoke_fn,
            stream_open_fn,
            stream_send_fn,
            stream_recv_fn,
            stream_close_send_fn,
            stream_close_fn,
        }))
    }

    pub fn invoke_raw(&self, method: &str, data: &[u8]) -> Result<Vec<u8>, String> {
        let c_method = CString::new(method).map_err(|_| format!("invalid method: {method}"))?;
        let mut resp_len = 0i32;
        let resp = unsafe {
            (self.invoke_fn)(
                c_method.as_ptr(),
                if data.is_empty() {
                    std::ptr::null()
                } else {
                    data.as_ptr()
                },
                data.len() as i32,
                &mut resp_len,
            )
        };

        if resp.is_null() {
            if resp_len == 0 {
                return Ok(Vec::new());
            }
            return Err(format!("plugin returned null for {method}"));
        }

        let copy_len = if resp_len < 0 { -resp_len } else { resp_len } as usize;
        let result = unsafe { std::slice::from_raw_parts(resp, copy_len).to_vec() };
        unsafe { (self.free_fn)(resp) };

        if resp_len < 0 {
            return Err(format_ffi_error(&result));
        }

        Ok(result)
    }

    pub fn open_stream(self: &Arc<Self>, method: &str) -> Result<Arc<PluginStream>, String> {
        let c_method = CString::new(method).map_err(|_| format!("invalid method: {method}"))?;
        let handle = unsafe { (self.stream_open_fn)(c_method.as_ptr()) };
        if handle == 0 {
            return Err(format!("failed to open stream for {method}"));
        }

        Ok(Arc::new(PluginStream {
            plugin: Arc::clone(self),
            handle,
            closed: AtomicBool::new(false),
            send_lock: Mutex::new(()),
        }))
    }
}

impl Drop for PluginLibrary {
    fn drop(&mut self) {
        unsafe {
            libc::dlclose(self.handle);
        }
    }
}

impl PluginStream {
    pub fn send_raw(&self, data: &[u8]) -> Result<(), String> {
        if self.closed.load(Ordering::SeqCst) {
            return Err("stream is closed".to_string());
        }

        let _guard = self.send_lock.lock().unwrap();
        let rc = unsafe {
            (self.plugin.stream_send_fn)(
                self.handle,
                if data.is_empty() {
                    std::ptr::null()
                } else {
                    data.as_ptr()
                },
                data.len() as i32,
            )
        };
        if rc != 0 {
            return Err(format!("stream send failed with code {rc}"));
        }
        Ok(())
    }

    pub fn recv_raw(&self) -> Result<Option<Vec<u8>>, String> {
        if self.closed.load(Ordering::SeqCst) {
            return Ok(None);
        }

        let mut resp_len = 0i32;
        let mut status = 0i32;
        let resp = unsafe { (self.plugin.stream_recv_fn)(self.handle, &mut resp_len, &mut status) };

        match status {
            0 => {
                if resp.is_null() {
                    if resp_len == 0 {
                        return Ok(Some(Vec::new()));
                    }
                    return Err("plugin returned null stream payload".to_string());
                }
                let result =
                    unsafe { std::slice::from_raw_parts(resp, resp_len as usize).to_vec() };
                unsafe { (self.plugin.free_fn)(resp) };
                Ok(Some(result))
            }
            1 => {
                if !resp.is_null() {
                    unsafe { (self.plugin.free_fn)(resp) };
                }
                Ok(None)
            }
            code if code < 0 => {
                if !resp.is_null() && resp_len > 0 {
                    let payload =
                        unsafe { std::slice::from_raw_parts(resp, resp_len as usize).to_vec() };
                    unsafe { (self.plugin.free_fn)(resp) };
                    return Err(format_ffi_error(&payload));
                }
                if !resp.is_null() {
                    unsafe { (self.plugin.free_fn)(resp) };
                }
                Err(format!("plugin stream error {code}"))
            }
            code => {
                if !resp.is_null() {
                    unsafe { (self.plugin.free_fn)(resp) };
                }
                Err(format!("stream transport error {code}"))
            }
        }
    }

    pub fn close_send(&self) {
        if !self.closed.load(Ordering::SeqCst) {
            unsafe { (self.plugin.stream_close_send_fn)(self.handle) };
        }
    }

    pub fn close(&self) {
        if self.closed.swap(true, Ordering::SeqCst) {
            return;
        }
        unsafe {
            (self.plugin.stream_close_fn)(self.handle);
        }
    }
}

impl Drop for PluginStream {
    fn drop(&mut self) {
        self.close();
    }
}

pub fn resolve_default_plugin_path() -> String {
    if let Ok(path) = std::env::var("VOLVOXGRID_PLUGIN_PATH") {
        let trimmed = path.trim();
        if !trimmed.is_empty() {
            return trimmed.to_string();
        }
    }

    let candidates = [
        "target/debug/libvolvoxgrid_plugin.so",
        "target/release/libvolvoxgrid_plugin.so",
        "../target/debug/libvolvoxgrid_plugin.so",
        "../target/release/libvolvoxgrid_plugin.so",
        "plugin/target/debug/libvolvoxgrid_plugin.so",
        "plugin/target/release/libvolvoxgrid_plugin.so",
        "../plugin/target/debug/libvolvoxgrid_plugin.so",
        "../plugin/target/release/libvolvoxgrid_plugin.so",
    ];
    for candidate in candidates {
        if Path::new(candidate).exists() {
            return candidate.to_string();
        }
    }
    "target/debug/libvolvoxgrid_plugin.so".to_string()
}

fn lookup_symbol<T>(handle: *mut libc::c_void, name: &str) -> Result<T, String> {
    let c_name = CString::new(name).map_err(|_| format!("invalid symbol name: {name}"))?;
    let ptr = unsafe { libc::dlsym(handle, c_name.as_ptr()) };
    if ptr.is_null() {
        return Err(last_dlerror().unwrap_or_else(|| format!("missing symbol {name}")));
    }
    Ok(unsafe { std::mem::transmute_copy(&ptr) })
}

fn last_dlerror() -> Option<String> {
    let err = unsafe { libc::dlerror() };
    if err.is_null() {
        None
    } else {
        Some(
            unsafe { CStr::from_ptr(err) }
                .to_string_lossy()
                .into_owned(),
        )
    }
}

fn format_ffi_error(payload: &[u8]) -> String {
    let info = decode_ffi_error_payload(payload);
    if info.code == 0 && info.grpc_code == 0 {
        info.message
    } else {
        format!(
            "{} (code={}, grpc={})",
            info.message, info.code, info.grpc_code
        )
    }
}

struct DecodedFfiError {
    message: String,
    code: i32,
    grpc_code: i32,
}

fn decode_ffi_error_payload(payload: &[u8]) -> DecodedFfiError {
    let mut index = 0usize;
    let mut code = 0i32;
    let mut grpc_code = 0i32;
    let mut message = None;

    while index < payload.len() {
        let Some(tag) = read_varint(payload, &mut index) else {
            break;
        };
        if tag == 0 {
            break;
        }
        let field = tag >> 3;
        let wire = tag & 0x07;
        match field {
            1 if wire == 0 => {
                let Some(value) = read_varint(payload, &mut index) else {
                    break;
                };
                code = value as i32;
            }
            2 if wire == 2 => {
                let Some(len) = read_varint(payload, &mut index) else {
                    break;
                };
                let len = len as usize;
                if index + len > payload.len() {
                    break;
                }
                message = Some(String::from_utf8_lossy(&payload[index..index + len]).into_owned());
                index += len;
            }
            3 if wire == 0 => {
                let Some(value) = read_varint(payload, &mut index) else {
                    break;
                };
                grpc_code = value as i32;
            }
            _ => skip_field(payload, &mut index, wire),
        }
    }

    DecodedFfiError {
        message: message.unwrap_or_else(|| String::from_utf8_lossy(payload).into_owned()),
        code,
        grpc_code,
    }
}

fn read_varint(data: &[u8], index: &mut usize) -> Option<u64> {
    let mut value = 0u64;
    let mut shift = 0u32;
    while *index < data.len() && shift < 64 {
        let b = data[*index];
        *index += 1;
        value |= ((b & 0x7f) as u64) << shift;
        if (b & 0x80) == 0 {
            return Some(value);
        }
        shift += 7;
    }
    None
}

fn skip_field(data: &[u8], index: &mut usize, wire_type: u64) {
    match wire_type {
        0 => {
            let _ = read_varint(data, index);
        }
        2 => {
            if let Some(len) = read_varint(data, index) {
                let next = index.saturating_add(len as usize);
                *index = next.min(data.len());
            } else {
                *index = data.len();
            }
        }
        _ => {
            *index = data.len();
        }
    }
}
