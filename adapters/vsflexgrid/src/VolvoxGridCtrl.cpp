// VolvoxGridCtrl.cpp -- ATL control implementation for Volvox VolvoxGrid
//
// Bridges the COM/ActiveX surface to the Rust VolvoxGrid engine via
// Synurang's C++ PluginHost and the generated FFI client layer.

#include "VolvoxGridCtrl.h"

#include <comutil.h>  // _bstr_t
#include <algorithm>

using namespace volvoxgrid::legacy;

// ═══════════════════════════════════════════════════════════════════
// Plugin path -- relative to the DLL location
// ═══════════════════════════════════════════════════════════════════

static std::string GetPluginPath()
{
    char modulePath[MAX_PATH] = {};
    HMODULE hMod = nullptr;
    GetModuleHandleExA(
        GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS |
        GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
        reinterpret_cast<LPCSTR>(&GetPluginPath), &hMod);
    GetModuleFileNameA(hMod, modulePath, MAX_PATH);

    std::string path(modulePath);
    auto pos = path.find_last_of("\\/");
    if (pos != std::string::npos)
        path = path.substr(0, pos + 1);

    // Plugin DLL expected next to the ActiveX DLL
    return path + "volvoxgrid_plugin.dll";
}

static void PopulateResizePolicy(ResizePolicy* policy, FlexAllowUserResizing mode)
{
    if (!policy) return;

    switch (mode) {
    case flexResizeColumns:
        policy->set_columns(true);
        break;
    case flexResizeRows:
        policy->set_rows(true);
        break;
    case flexResizeBoth:
        policy->set_columns(true);
        policy->set_rows(true);
        break;
    case flexResizeColumnsUniform:
        policy->set_columns(true);
        policy->set_uniform(true);
        break;
    case flexResizeRowsUniform:
        policy->set_rows(true);
        policy->set_uniform(true);
        break;
    case flexResizeBothUniform:
        policy->set_columns(true);
        policy->set_rows(true);
        policy->set_uniform(true);
        break;
    case flexResizeNone:
    default:
        break;
    }
}

// ═══════════════════════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════════════════════

std::string CVolvoxGridCtrl::BstrToUtf8(BSTR bstr)
{
    if (!bstr) return "";
    int len = SysStringLen(bstr);
    if (len == 0) return "";
    int utf8Len = WideCharToMultiByte(CP_UTF8, 0, bstr, len, nullptr, 0, nullptr, nullptr);
    std::string result(utf8Len, '\0');
    WideCharToMultiByte(CP_UTF8, 0, bstr, len, &result[0], utf8Len, nullptr, nullptr);
    return result;
}

CComBSTR CVolvoxGridCtrl::Utf8ToBstr(const std::string& s)
{
    if (s.empty()) return CComBSTR(L"");
    int wLen = MultiByteToWideChar(CP_UTF8, 0, s.c_str(), (int)s.size(), nullptr, 0);
    CComBSTR bstr(wLen);
    MultiByteToWideChar(CP_UTF8, 0, s.c_str(), (int)s.size(), bstr.m_str, wLen);
    return bstr;
}

GridHandle CVolvoxGridCtrl::MakeHandle() const
{
    GridHandle h;
    h.set_id(m_gridId);
    return h;
}

std::vector<uint8_t> CVolvoxGridCtrl::InvokePlugin(
    const std::string& method, const std::vector<uint8_t>& data)
{
    return m_pluginHost.invoke("VolvoxGridService", method, data);
}

void CVolvoxGridCtrl::RefreshCachedStyle()
{
    if (!m_styleDirty) return;

    auto handle = MakeHandle();
    std::string serialized = handle.SerializeAsString();
    std::vector<uint8_t> data(serialized.begin(), serialized.end());

    auto resp = InvokePlugin("/volvoxgrid.activex.VolvoxGridService/GetGridStyle", data);
    if (resp.size() > 1 && resp[0] == 0) {
        m_cachedStyle.ParseFromArray(resp.data() + 1, (int)resp.size() - 1);
    }
    m_styleDirty = false;
}

// ═══════════════════════════════════════════════════════════════════
// Lifecycle
// ═══════════════════════════════════════════════════════════════════

HRESULT CVolvoxGridCtrl::FinalConstruct()
{
    try {
        // Load the Volvox VolvoxGrid plugin
        std::string pluginPath = GetPluginPath();
        m_pluginHost = synurang::PluginHost::load(pluginPath);

        // Create a grid with default dimensions
        CreateGridRequest req;
        req.set_viewport_width(400);
        req.set_viewport_height(300);
        req.set_rows(10);
        req.set_cols(5);
        req.set_fixed_rows(1);
        req.set_fixed_cols(0);

        std::string serialized = req.SerializeAsString();
        std::vector<uint8_t> data(serialized.begin(), serialized.end());
        auto resp = InvokePlugin("/volvoxgrid.activex.VolvoxGridService/CreateGrid", data);

        if (resp.size() > 1 && resp[0] == 0) {
            GridHandle handle;
            handle.ParseFromArray(resp.data() + 1, (int)resp.size() - 1);
            m_gridId = handle.id();
        } else {
            return E_FAIL;
        }

        // Open the render session stream
        m_renderStream = m_pluginHost.open_stream(
            "VolvoxGridService",
            "/volvoxgrid.activex.VolvoxGridService/RenderSession");

        // Open the event stream
        m_eventStream = m_pluginHost.open_stream(
            "VolvoxGridService",
            "/volvoxgrid.activex.VolvoxGridService/EventStream");

        // Send GridHandle to event stream to start receiving events
        auto handleMsg = MakeHandle();
        std::string handleData = handleMsg.SerializeAsString();
        std::vector<uint8_t> evtData(handleData.begin(), handleData.end());
        m_eventStream->send(evtData);

        // Start polling the event stream
        StartEventThread();

        // Initialize the bitmap info header
        ZeroMemory(&m_bmi, sizeof(m_bmi));
        m_bmi.bmiHeader.biSize        = sizeof(BITMAPINFOHEADER);
        m_bmi.bmiHeader.biPlanes      = 1;
        m_bmi.bmiHeader.biBitCount    = 32;
        m_bmi.bmiHeader.biCompression = BI_RGB;

        return S_OK;
    } catch (const synurang::FfiError& e) {
        // Plugin load failed -- return error but allow the control to exist
        OutputDebugStringA(e.what());
        return E_FAIL;
    }
}

void CVolvoxGridCtrl::FinalRelease()
{
    StopEventThread();

    // Close streams
    if (m_renderStream) {
        m_renderStream->close();
        m_renderStream.reset();
    }
    if (m_eventStream) {
        m_eventStream->close();
        m_eventStream.reset();
    }

    // Destroy the grid
    if (m_gridId != 0) {
        auto handle = MakeHandle();
        std::string serialized = handle.SerializeAsString();
        std::vector<uint8_t> data(serialized.begin(), serialized.end());
        InvokePlugin("/volvoxgrid.activex.VolvoxGridService/DestroyGrid", data);
        m_gridId = 0;
    }

    // Close plugin
    m_pluginHost.close();
}

// ═══════════════════════════════════════════════════════════════════
// Rendering
// ═══════════════════════════════════════════════════════════════════

HRESULT CVolvoxGridCtrl::OnDraw(ATL_DRAWINFO& di)
{
    RECT& rc = *(RECT*)di.prcBounds;
    HDC hdc  = di.hdcDraw;

    if (m_pixelBuffer.empty() || m_width <= 0 || m_height <= 0) {
        // No frame rendered yet -- fill with background
        HBRUSH hBrush = CreateSolidBrush(RGB(255, 255, 255));
        FillRect(hdc, &rc, hBrush);
        DeleteObject(hBrush);
        return S_OK;
    }

    // Blit the pixel buffer to the device context
    m_bmi.bmiHeader.biWidth  = m_width;
    m_bmi.bmiHeader.biHeight = -m_height;  // top-down

    SetDIBitsToDevice(
        hdc,
        rc.left, rc.top,
        m_width, m_height,
        0, 0,
        0, m_height,
        m_pixelBuffer.data(),
        &m_bmi,
        DIB_RGB_COLORS);

    return S_OK;
}

void CVolvoxGridCtrl::RequestFrame()
{
    if (!m_renderStream || m_width <= 0 || m_height <= 0) return;

    // Send a viewport state to request a frame
    RenderInput input;
    input.set_grid_id(m_gridId);
    auto* vp = input.mutable_viewport();
    vp->set_width(m_width);
    vp->set_height(m_height);
    vp->set_scroll_x(0);
    vp->set_scroll_y(0);

    std::string serialized = input.SerializeAsString();
    std::vector<uint8_t> data(serialized.begin(), serialized.end());
    m_renderStream->send(data);

    // Receive the render output
    bool eof = false;
    auto resp = m_renderStream->recv(eof);
    if (!eof && resp.size() > 1 && resp[0] == 0) {
        RenderOutput output;
        if (output.ParseFromArray(resp.data() + 1, (int)resp.size() - 1)) {
            ProcessRenderOutput(output);
        }
    }
}

void CVolvoxGridCtrl::ProcessRenderOutput(const RenderOutput& output)
{
    if (output.has_frame_done()) {
        // The frame is ready in the shared buffer; invalidate to trigger repaint
        if (m_hWnd) {
            InvalidateRect(m_hWnd, nullptr, FALSE);
        }
    }
    if (output.has_selection()) {
        const auto& sel = output.selection();
        Fire_AfterRowColChange();
    }
}

// ═══════════════════════════════════════════════════════════════════
// Event Thread
// ═══════════════════════════════════════════════════════════════════

void CVolvoxGridCtrl::StartEventThread()
{
    m_eventThreadRunning = true;
    m_eventThread = std::thread([this]() {
        while (m_eventThreadRunning) {
            if (!m_eventStream) break;

            bool eof = false;
            auto resp = m_eventStream->recv(eof);
            if (eof) break;

            if (resp.size() > 1 && resp[0] == 0) {
                GridEvent evt;
                if (evt.ParseFromArray(resp.data() + 1, (int)resp.size() - 1)) {
                    // Post events to the control's window thread
                    // For simplicity, directly fire (caller must ensure STA)
                    if (evt.has_before_row_col_change()) {
                        auto& e = evt.before_row_col_change();
                        VARIANT_BOOL cancel = VARIANT_FALSE;
                        Fire_BeforeRowColChange(
                            e.old_row(), e.old_col(),
                            e.new_row(), e.new_col(), &cancel);
                    }
                    else if (evt.has_after_row_col_change()) {
                        Fire_AfterRowColChange();
                    }
                    else if (evt.has_before_edit()) {
                        auto& e = evt.before_edit();
                        VARIANT_BOOL cancel = VARIANT_FALSE;
                        Fire_BeforeEdit(e.row(), e.col(), &cancel);
                    }
                    else if (evt.has_after_edit()) {
                        auto& e = evt.after_edit();
                        Fire_AfterEdit(e.row(), e.col());
                    }
                    else if (evt.has_before_sort()) {
                        auto& e = evt.before_sort();
                        VARIANT_BOOL cancel = VARIANT_FALSE;
                        Fire_BeforeSort(e.col(), &cancel);
                    }
                    else if (evt.has_after_sort()) {
                        Fire_AfterSort();
                    }
                    else if (evt.has_click_event()) {
                        Fire_Click();
                    }
                    else if (evt.has_dbl_click_event()) {
                        Fire_DblClick();
                    }
                    else if (evt.has_key_down()) {
                        auto& e = evt.key_down();
                        Fire_KeyDown(e.key_code(), e.modifier());
                    }
                    else if (evt.has_key_press()) {
                        Fire_KeyPress(evt.key_press().key_ascii());
                    }
                    else if (evt.has_key_up()) {
                        auto& e = evt.key_up();
                        Fire_KeyUp(e.key_code(), e.modifier());
                    }
                    else if (evt.has_cell_changed()) {
                        auto& e = evt.cell_changed();
                        Fire_CellChanged(e.row(), e.col());
                    }
                    else if (evt.has_after_scroll()) {
                        Fire_Scroll();
                    }
                }
            }
        }
    });
}

void CVolvoxGridCtrl::StopEventThread()
{
    m_eventThreadRunning = false;
    if (m_eventThread.joinable()) {
        // Close the event stream to unblock recv
        if (m_eventStream) {
            m_eventStream->close_send();
        }
        m_eventThread.join();
    }
}

// ═══════════════════════════════════════════════════════════════════
// Message Handlers
// ═══════════════════════════════════════════════════════════════════

LRESULT CVolvoxGridCtrl::OnPaint(UINT, WPARAM, LPARAM, BOOL& bHandled)
{
    // Let ATL's default handler call OnDraw
    bHandled = FALSE;
    return 0;
}

LRESULT CVolvoxGridCtrl::OnSize(UINT, WPARAM, LPARAM lParam, BOOL& bHandled)
{
    m_width  = LOWORD(lParam);
    m_height = HIWORD(lParam);

    if (m_width > 0 && m_height > 0) {
        // Resize pixel buffer
        m_pixelBuffer.resize(m_width * m_height * 4, 0);

        // Notify the engine of the new viewport size
        ResizeViewportRequest req;
        req.set_grid_id(m_gridId);
        req.set_width(m_width);
        req.set_height(m_height);

        std::string serialized = req.SerializeAsString();
        std::vector<uint8_t> data(serialized.begin(), serialized.end());
        InvokePlugin("/volvoxgrid.activex.VolvoxGridService/ResizeViewport", data);

        // Request a new frame
        RequestFrame();
    }

    bHandled = TRUE;
    return 0;
}

LRESULT CVolvoxGridCtrl::OnEraseBkgnd(UINT, WPARAM, LPARAM, BOOL& bHandled)
{
    // Suppress background erase to avoid flicker
    bHandled = TRUE;
    return 1;
}

LRESULT CVolvoxGridCtrl::OnSetFocus(UINT, WPARAM, LPARAM, BOOL& bHandled)
{
    bHandled = FALSE;
    return 0;
}

LRESULT CVolvoxGridCtrl::OnKillFocus(UINT, WPARAM, LPARAM, BOOL& bHandled)
{
    bHandled = FALSE;
    return 0;
}

LRESULT CVolvoxGridCtrl::OnTimer(UINT, WPARAM, LPARAM, BOOL& bHandled)
{
    bHandled = FALSE;
    return 0;
}

// ═══════════════════════════════════════════════════════════════════
// Mouse Handlers
// ═══════════════════════════════════════════════════════════════════

static int GetModifiers()
{
    int mod = 0;
    if (GetKeyState(VK_SHIFT)   & 0x8000) mod |= 1;
    if (GetKeyState(VK_CONTROL) & 0x8000) mod |= 2;
    if (GetKeyState(VK_MENU)    & 0x8000) mod |= 4;
    return mod;
}

void CVolvoxGridCtrl::SendPointerEvent(
    PointerEvent::Type type, float x, float y,
    int modifier, int button, bool dblClick)
{
    if (!m_renderStream) return;

    RenderInput input;
    input.set_grid_id(m_gridId);
    auto* pe = input.mutable_pointer();
    pe->set_type(type);
    pe->set_x(x);
    pe->set_y(y);
    pe->set_modifier(modifier);
    pe->set_button(button);
    pe->set_dbl_click(dblClick);

    std::string serialized = input.SerializeAsString();
    std::vector<uint8_t> data(serialized.begin(), serialized.end());
    m_renderStream->send(data);

    // Read response
    bool eof = false;
    auto resp = m_renderStream->recv(eof);
    if (!eof && resp.size() > 1 && resp[0] == 0) {
        RenderOutput output;
        if (output.ParseFromArray(resp.data() + 1, (int)resp.size() - 1)) {
            ProcessRenderOutput(output);
        }
    }
}

LRESULT CVolvoxGridCtrl::OnLButtonDown(UINT, WPARAM wParam, LPARAM lParam, BOOL& bHandled)
{
    SetCapture(m_hWnd);
    float x = (float)GET_X_LPARAM(lParam);
    float y = (float)GET_Y_LPARAM(lParam);
    SendPointerEvent(PointerEvent::DOWN, x, y, GetModifiers(), 0);
    Fire_MouseDown(1, GetModifiers(), x, y);
    bHandled = TRUE;
    return 0;
}

LRESULT CVolvoxGridCtrl::OnLButtonUp(UINT, WPARAM wParam, LPARAM lParam, BOOL& bHandled)
{
    ReleaseCapture();
    float x = (float)GET_X_LPARAM(lParam);
    float y = (float)GET_Y_LPARAM(lParam);
    SendPointerEvent(PointerEvent::UP, x, y, GetModifiers(), 0);
    Fire_MouseUp(1, GetModifiers(), x, y);
    Fire_Click();
    bHandled = TRUE;
    return 0;
}

LRESULT CVolvoxGridCtrl::OnLButtonDblClk(UINT, WPARAM wParam, LPARAM lParam, BOOL& bHandled)
{
    float x = (float)GET_X_LPARAM(lParam);
    float y = (float)GET_Y_LPARAM(lParam);
    SendPointerEvent(PointerEvent::DOWN, x, y, GetModifiers(), 0, true);
    Fire_DblClick();
    bHandled = TRUE;
    return 0;
}

LRESULT CVolvoxGridCtrl::OnRButtonDown(UINT, WPARAM wParam, LPARAM lParam, BOOL& bHandled)
{
    float x = (float)GET_X_LPARAM(lParam);
    float y = (float)GET_Y_LPARAM(lParam);
    SendPointerEvent(PointerEvent::DOWN, x, y, GetModifiers(), 2);
    Fire_MouseDown(2, GetModifiers(), x, y);
    bHandled = TRUE;
    return 0;
}

LRESULT CVolvoxGridCtrl::OnMouseMove(UINT, WPARAM wParam, LPARAM lParam, BOOL& bHandled)
{
    float x = (float)GET_X_LPARAM(lParam);
    float y = (float)GET_Y_LPARAM(lParam);
    SendPointerEvent(PointerEvent::MOVE, x, y, GetModifiers(), 0);
    Fire_MouseMove(0, GetModifiers(), x, y);
    bHandled = TRUE;
    return 0;
}

LRESULT CVolvoxGridCtrl::OnMouseWheel(UINT, WPARAM wParam, LPARAM lParam, BOOL& bHandled)
{
    short delta = GET_WHEEL_DELTA_WPARAM(wParam);
    float dy = (float)delta / WHEEL_DELTA * -3.0f;  // 3 rows per notch
    SendScrollEvent(0.0f, dy);
    bHandled = TRUE;
    return 0;
}

void CVolvoxGridCtrl::SendScrollEvent(float dx, float dy)
{
    if (!m_renderStream) return;

    RenderInput input;
    input.set_grid_id(m_gridId);
    auto* se = input.mutable_scroll();
    se->set_delta_x(dx);
    se->set_delta_y(dy);

    std::string serialized = input.SerializeAsString();
    std::vector<uint8_t> data(serialized.begin(), serialized.end());
    m_renderStream->send(data);

    bool eof = false;
    auto resp = m_renderStream->recv(eof);
    if (!eof && resp.size() > 1 && resp[0] == 0) {
        RenderOutput output;
        if (output.ParseFromArray(resp.data() + 1, (int)resp.size() - 1)) {
            ProcessRenderOutput(output);
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// Keyboard Handlers
// ═══════════════════════════════════════════════════════════════════

void CVolvoxGridCtrl::SendKeyEvent(
    KeyEvent::Type type, int keyCode, int modifier,
    const std::string& character)
{
    if (!m_renderStream) return;

    RenderInput input;
    input.set_grid_id(m_gridId);
    auto* ke = input.mutable_key();
    ke->set_type(type);
    ke->set_key_code(keyCode);
    ke->set_modifier(modifier);
    if (!character.empty()) ke->set_character(character);

    std::string serialized = input.SerializeAsString();
    std::vector<uint8_t> data(serialized.begin(), serialized.end());
    m_renderStream->send(data);

    bool eof = false;
    auto resp = m_renderStream->recv(eof);
    if (!eof && resp.size() > 1 && resp[0] == 0) {
        RenderOutput output;
        if (output.ParseFromArray(resp.data() + 1, (int)resp.size() - 1)) {
            ProcessRenderOutput(output);
        }
    }
}

LRESULT CVolvoxGridCtrl::OnKeyDown(UINT, WPARAM wParam, LPARAM, BOOL& bHandled)
{
    int keyCode = (int)wParam;
    int mod = GetModifiers();
    SendKeyEvent(KeyEvent::KEY_DOWN, keyCode, mod);
    Fire_KeyDown(keyCode, mod);
    bHandled = TRUE;
    return 0;
}

LRESULT CVolvoxGridCtrl::OnKeyUp(UINT, WPARAM wParam, LPARAM, BOOL& bHandled)
{
    int keyCode = (int)wParam;
    int mod = GetModifiers();
    SendKeyEvent(KeyEvent::KEY_UP, keyCode, mod);
    Fire_KeyUp(keyCode, mod);
    bHandled = TRUE;
    return 0;
}

LRESULT CVolvoxGridCtrl::OnChar(UINT, WPARAM wParam, LPARAM, BOOL& bHandled)
{
    wchar_t ch = (wchar_t)wParam;
    char utf8[8] = {};
    WideCharToMultiByte(CP_UTF8, 0, &ch, 1, utf8, sizeof(utf8), nullptr, nullptr);
    SendKeyEvent(KeyEvent::KEY_PRESS, (int)ch, GetModifiers(), utf8);
    Fire_KeyPress((long)ch);
    bHandled = TRUE;
    return 0;
}

// ═══════════════════════════════════════════════════════════════════
// IVolvoxGrid Property Implementations
// ═══════════════════════════════════════════════════════════════════

// Macro to reduce boilerplate for get-int32-property
#define IMPL_GET_INT32_PROP(PropName, Method)                         \
    STDMETHODIMP CVolvoxGridCtrl::get_##PropName(long* pVal) {          \
        if (!pVal) return E_POINTER;                                  \
        auto h = MakeHandle();                                        \
        std::string s = h.SerializeAsString();                        \
        std::vector<uint8_t> data(s.begin(), s.end());                \
        auto resp = InvokePlugin(                                     \
            "/volvoxgrid.activex.VolvoxGridService/" Method, data);            \
        if (resp.size() > 1 && resp[0] == 0) {                       \
            Int32Value val;                                           \
            if (val.ParseFromArray(resp.data()+1,(int)resp.size()-1)) \
                *pVal = val.value();                                  \
        }                                                             \
        return S_OK;                                                  \
    }

IMPL_GET_INT32_PROP(Rows, "GetRows")
IMPL_GET_INT32_PROP(Cols, "GetCols")
IMPL_GET_INT32_PROP(Row,  "GetRow")
IMPL_GET_INT32_PROP(Col,  "GetCol")
IMPL_GET_INT32_PROP(MouseRow, "GetMouseRow")
IMPL_GET_INT32_PROP(MouseCol, "GetMouseCol")

#undef IMPL_GET_INT32_PROP

STDMETHODIMP CVolvoxGridCtrl::put_Rows(long newVal)
{
    SetRowsRequest req;
    req.set_grid_id(m_gridId);
    req.set_rows(newVal);
    std::string s = req.SerializeAsString();
    std::vector<uint8_t> data(s.begin(), s.end());
    InvokePlugin("/volvoxgrid.activex.VolvoxGridService/SetRows", data);
    RequestFrame();
    return S_OK;
}

STDMETHODIMP CVolvoxGridCtrl::put_Cols(long newVal)
{
    SetColsRequest req;
    req.set_grid_id(m_gridId);
    req.set_cols(newVal);
    std::string s = req.SerializeAsString();
    std::vector<uint8_t> data(s.begin(), s.end());
    InvokePlugin("/volvoxgrid.activex.VolvoxGridService/SetCols", data);
    RequestFrame();
    return S_OK;
}

STDMETHODIMP CVolvoxGridCtrl::get_FixedRows(long* pVal)
{
    if (!pVal) return E_POINTER;
    *pVal = m_fixedRows;
    return S_OK;
}

STDMETHODIMP CVolvoxGridCtrl::put_FixedRows(long newVal)
{
    SetFixedRowsRequest req;
    req.set_grid_id(m_gridId);
    req.set_fixed_rows(newVal);
    std::string s = req.SerializeAsString();
    std::vector<uint8_t> data(s.begin(), s.end());
    InvokePlugin("/volvoxgrid.activex.VolvoxGridService/SetFixedRows", data);
    m_fixedRows = std::max<long>(0, newVal);
    RequestFrame();
    return S_OK;
}

STDMETHODIMP CVolvoxGridCtrl::get_FixedCols(long* pVal)
{
    if (!pVal) return E_POINTER;
    *pVal = 0;  // default, should be cached
    return S_OK;
}

STDMETHODIMP CVolvoxGridCtrl::put_FixedCols(long newVal)
{
    SetFixedColsRequest req;
    req.set_grid_id(m_gridId);
    req.set_fixed_cols(newVal);
    std::string s = req.SerializeAsString();
    std::vector<uint8_t> data(s.begin(), s.end());
    InvokePlugin("/volvoxgrid.activex.VolvoxGridService/SetFixedCols", data);
    RequestFrame();
    return S_OK;
}

STDMETHODIMP CVolvoxGridCtrl::put_Row(long newVal)
{
    SetRowRequest req;
    req.set_grid_id(m_gridId);
    req.set_row(newVal);
    std::string s = req.SerializeAsString();
    std::vector<uint8_t> data(s.begin(), s.end());
    InvokePlugin("/volvoxgrid.activex.VolvoxGridService/SetRow", data);
    RequestFrame();
    return S_OK;
}

STDMETHODIMP CVolvoxGridCtrl::put_Col(long newVal)
{
    SetColRequest req;
    req.set_grid_id(m_gridId);
    req.set_col(newVal);
    std::string s = req.SerializeAsString();
    std::vector<uint8_t> data(s.begin(), s.end());
    InvokePlugin("/volvoxgrid.activex.VolvoxGridService/SetCol", data);
    RequestFrame();
    return S_OK;
}

STDMETHODIMP CVolvoxGridCtrl::get_RowSel(long* pVal)
{
    if (!pVal) return E_POINTER;
    auto h = MakeHandle();
    std::string s = h.SerializeAsString();
    std::vector<uint8_t> data(s.begin(), s.end());
    auto resp = InvokePlugin("/volvoxgrid.activex.VolvoxGridService/GetSelection", data);
    if (resp.size() > 1 && resp[0] == 0) {
        SelectionRange sel;
        if (sel.ParseFromArray(resp.data()+1, (int)resp.size()-1))
            *pVal = sel.row2();
    }
    return S_OK;
}

STDMETHODIMP CVolvoxGridCtrl::put_RowSel(long newVal)
{
    SetRowSelRequest req;
    req.set_grid_id(m_gridId);
    req.set_row_sel(newVal);
    std::string s = req.SerializeAsString();
    std::vector<uint8_t> data(s.begin(), s.end());
    InvokePlugin("/volvoxgrid.activex.VolvoxGridService/SetRowSel", data);
    RequestFrame();
    return S_OK;
}

STDMETHODIMP CVolvoxGridCtrl::get_ColSel(long* pVal)
{
    if (!pVal) return E_POINTER;
    auto h = MakeHandle();
    std::string s = h.SerializeAsString();
    std::vector<uint8_t> data(s.begin(), s.end());
    auto resp = InvokePlugin("/volvoxgrid.activex.VolvoxGridService/GetSelection", data);
    if (resp.size() > 1 && resp[0] == 0) {
        SelectionRange sel;
        if (sel.ParseFromArray(resp.data()+1, (int)resp.size()-1))
            *pVal = sel.col2();
    }
    return S_OK;
}

STDMETHODIMP CVolvoxGridCtrl::put_ColSel(long newVal)
{
    SetColSelRequest req;
    req.set_grid_id(m_gridId);
    req.set_col_sel(newVal);
    std::string s = req.SerializeAsString();
    std::vector<uint8_t> data(s.begin(), s.end());
    InvokePlugin("/volvoxgrid.activex.VolvoxGridService/SetColSel", data);
    RequestFrame();
    return S_OK;
}

// --- Selection Mode ---

STDMETHODIMP CVolvoxGridCtrl::get_SelectionMode(FlexSelectionMode* pVal)
{
    if (!pVal) return E_POINTER;
    *pVal = m_selectionMode;
    return S_OK;
}

STDMETHODIMP CVolvoxGridCtrl::put_SelectionMode(FlexSelectionMode newVal)
{
    m_selectionMode = newVal;
    SetSelectionModeRequest req;
    req.set_grid_id(m_gridId);
    req.set_mode(static_cast<SelectionMode>(newVal));
    std::string s = req.SerializeAsString();
    std::vector<uint8_t> data(s.begin(), s.end());
    InvokePlugin("/volvoxgrid.activex.VolvoxGridService/SetSelectionMode", data);
    RequestFrame();
    return S_OK;
}

STDMETHODIMP CVolvoxGridCtrl::get_HighLight(FlexHighLight* pVal)
{
    if (!pVal) return E_POINTER;
    *pVal = m_highLight;
    return S_OK;
}

STDMETHODIMP CVolvoxGridCtrl::put_HighLight(FlexHighLight newVal)
{
    m_highLight = newVal;
    SetHighLightRequest req;
    req.set_grid_id(m_gridId);
    req.set_style(static_cast<HighLightStyle>(newVal));
    std::string s = req.SerializeAsString();
    std::vector<uint8_t> data(s.begin(), s.end());
    InvokePlugin("/volvoxgrid.activex.VolvoxGridService/SetHighLight", data);
    RequestFrame();
    return S_OK;
}

STDMETHODIMP CVolvoxGridCtrl::get_FocusRect(FlexFocusRect* pVal)
{
    if (!pVal) return E_POINTER;
    *pVal = m_focusRect;
    return S_OK;
}

STDMETHODIMP CVolvoxGridCtrl::put_FocusRect(FlexFocusRect newVal)
{
    m_focusRect = newVal;
    SetFocusRectRequest req;
    req.set_grid_id(m_gridId);
    req.set_style(static_cast<FocusRectStyle>(newVal));
    std::string s = req.SerializeAsString();
    std::vector<uint8_t> data(s.begin(), s.end());
    InvokePlugin("/volvoxgrid.activex.VolvoxGridService/SetFocusRect", data);
    RequestFrame();
    return S_OK;
}

// --- Colors ---

// Helper macro for color properties via GridStyle
#define IMPL_COLOR_PROP(PropName, StyleField)                              \
    STDMETHODIMP CVolvoxGridCtrl::get_##PropName(OLE_COLOR* pVal) {          \
        if (!pVal) return E_POINTER;                                       \
        RefreshCachedStyle();                                              \
        *pVal = (OLE_COLOR)m_cachedStyle.StyleField();                     \
        return S_OK;                                                       \
    }                                                                      \
    STDMETHODIMP CVolvoxGridCtrl::put_##PropName(OLE_COLOR newVal) {         \
        RefreshCachedStyle();                                              \
        m_cachedStyle.set_##StyleField((uint32_t)newVal);                   \
        SetGridStyleRequest req;                                           \
        req.set_grid_id(m_gridId);                                         \
        *req.mutable_style() = m_cachedStyle;                              \
        std::string s = req.SerializeAsString();                           \
        std::vector<uint8_t> data(s.begin(), s.end());                     \
        InvokePlugin("/volvoxgrid.activex.VolvoxGridService/SetGridStyle", data);   \
        m_styleDirty = true;                                               \
        RequestFrame();                                                    \
        return S_OK;                                                       \
    }

IMPL_COLOR_PROP(BackColor,      back_color)
IMPL_COLOR_PROP(ForeColor,      fore_color)
IMPL_COLOR_PROP(GridColor,      grid_color)
IMPL_COLOR_PROP(BackColorFixed, back_color_fixed)
IMPL_COLOR_PROP(ForeColorFixed, fore_color_fixed)
IMPL_COLOR_PROP(BackColorSel,   back_color_sel)
IMPL_COLOR_PROP(ForeColorSel,   fore_color_sel)

#undef IMPL_COLOR_PROP

// --- Grid Lines ---

STDMETHODIMP CVolvoxGridCtrl::get_GridLines(VolvoxGridLines* pVal)
{
    if (!pVal) return E_POINTER;
    RefreshCachedStyle();
    *pVal = static_cast<VolvoxGridLines>(m_cachedStyle.grid_lines());
    return S_OK;
}

STDMETHODIMP CVolvoxGridCtrl::put_GridLines(VolvoxGridLines newVal)
{
    RefreshCachedStyle();
    m_cachedStyle.set_grid_lines(static_cast<GridLinesMode>(newVal));
    SetGridStyleRequest req;
    req.set_grid_id(m_gridId);
    *req.mutable_style() = m_cachedStyle;
    std::string s = req.SerializeAsString();
    std::vector<uint8_t> data(s.begin(), s.end());
    InvokePlugin("/volvoxgrid.activex.VolvoxGridService/SetGridStyle", data);
    m_styleDirty = true;
    RequestFrame();
    return S_OK;
}

// --- Editing ---

STDMETHODIMP CVolvoxGridCtrl::get_Editable(FlexEditableMode* pVal)
{
    if (!pVal) return E_POINTER;
    *pVal = m_editable;
    return S_OK;
}

STDMETHODIMP CVolvoxGridCtrl::put_Editable(FlexEditableMode newVal)
{
    m_editable = newVal;
    SetEditableRequest req;
    req.set_grid_id(m_gridId);
    req.set_mode(static_cast<EditableMode>(newVal));
    std::string s = req.SerializeAsString();
    std::vector<uint8_t> data(s.begin(), s.end());
    InvokePlugin("/volvoxgrid.activex.VolvoxGridService/SetEditable", data);
    return S_OK;
}

// --- Text (current cell) ---

STDMETHODIMP CVolvoxGridCtrl::get_Text(BSTR* pVal)
{
    if (!pVal) return E_POINTER;
    GetTextRequest req;
    req.set_grid_id(m_gridId);
    std::string s = req.SerializeAsString();
    std::vector<uint8_t> data(s.begin(), s.end());
    auto resp = InvokePlugin("/volvoxgrid.activex.VolvoxGridService/GetText", data);
    if (resp.size() > 1 && resp[0] == 0) {
        StringValue val;
        if (val.ParseFromArray(resp.data()+1, (int)resp.size()-1)) {
            CComBSTR bstr = Utf8ToBstr(val.value());
            *pVal = bstr.Detach();
        }
    }
    return S_OK;
}

STDMETHODIMP CVolvoxGridCtrl::put_Text(BSTR newVal)
{
    SetTextRequest req;
    req.set_grid_id(m_gridId);
    req.set_text(BstrToUtf8(newVal));
    std::string s = req.SerializeAsString();
    std::vector<uint8_t> data(s.begin(), s.end());
    InvokePlugin("/volvoxgrid.activex.VolvoxGridService/SetText", data);
    RequestFrame();
    return S_OK;
}

// --- MergeCells ---

STDMETHODIMP CVolvoxGridCtrl::get_MergeCells(FlexMergeCells* pVal)
{
    if (!pVal) return E_POINTER;
    *pVal = m_mergeCells;
    return S_OK;
}

STDMETHODIMP CVolvoxGridCtrl::put_MergeCells(FlexMergeCells newVal)
{
    m_mergeCells = newVal;
    SetMergeCellsRequest req;
    req.set_grid_id(m_gridId);
    req.set_mode(static_cast<MergeCellsMode>(newVal));
    std::string s = req.SerializeAsString();
    std::vector<uint8_t> data(s.begin(), s.end());
    InvokePlugin("/volvoxgrid.activex.VolvoxGridService/SetMergeCells", data);
    RequestFrame();
    return S_OK;
}

// --- WordWrap ---

STDMETHODIMP CVolvoxGridCtrl::get_WordWrap(VARIANT_BOOL* pVal)
{
    if (!pVal) return E_POINTER;
    *pVal = m_wordWrap;
    return S_OK;
}

STDMETHODIMP CVolvoxGridCtrl::put_WordWrap(VARIANT_BOOL newVal)
{
    m_wordWrap = newVal;
    SetBoolProp req;
    req.set_grid_id(m_gridId);
    req.set_value(newVal != VARIANT_FALSE);
    std::string s = req.SerializeAsString();
    std::vector<uint8_t> data(s.begin(), s.end());
    InvokePlugin("/volvoxgrid.activex.VolvoxGridService/SetWordWrap", data);
    RequestFrame();
    return S_OK;
}

// --- Frozen ---

STDMETHODIMP CVolvoxGridCtrl::get_FrozenRows(long* pVal)
{
    if (!pVal) return E_POINTER;
    *pVal = m_frozenRows;
    return S_OK;
}

STDMETHODIMP CVolvoxGridCtrl::put_FrozenRows(long newVal)
{
    m_frozenRows = newVal;
    SetFrozenRowsRequest req;
    req.set_grid_id(m_gridId);
    req.set_frozen_rows(newVal);
    std::string s = req.SerializeAsString();
    std::vector<uint8_t> data(s.begin(), s.end());
    InvokePlugin("/volvoxgrid.activex.VolvoxGridService/SetFrozenRows", data);
    RequestFrame();
    return S_OK;
}

STDMETHODIMP CVolvoxGridCtrl::get_FrozenCols(long* pVal)
{
    if (!pVal) return E_POINTER;
    *pVal = m_frozenCols;
    return S_OK;
}

STDMETHODIMP CVolvoxGridCtrl::put_FrozenCols(long newVal)
{
    m_frozenCols = newVal;
    SetFrozenColsRequest req;
    req.set_grid_id(m_gridId);
    req.set_frozen_cols(newVal);
    std::string s = req.SerializeAsString();
    std::vector<uint8_t> data(s.begin(), s.end());
    InvokePlugin("/volvoxgrid.activex.VolvoxGridService/SetFrozenCols", data);
    RequestFrame();
    return S_OK;
}

// --- AllowUserResizing ---

STDMETHODIMP CVolvoxGridCtrl::get_AllowUserResizing(FlexAllowUserResizing* pVal)
{
    if (!pVal) return E_POINTER;
    *pVal = m_allowUserResizing;
    return S_OK;
}

STDMETHODIMP CVolvoxGridCtrl::put_AllowUserResizing(FlexAllowUserResizing newVal)
{
    m_allowUserResizing = newVal;
    SetResizePolicyRequest req;
    req.set_grid_id(m_gridId);
    PopulateResizePolicy(req.mutable_policy(), newVal);
    std::string s = req.SerializeAsString();
    std::vector<uint8_t> data(s.begin(), s.end());
    InvokePlugin("/volvoxgrid.activex.VolvoxGridService/SetResizePolicy", data);
    RequestFrame();
    return S_OK;
}

// --- Clipboard ---

STDMETHODIMP CVolvoxGridCtrl::get_Clip(BSTR* pVal)
{
    if (!pVal) return E_POINTER;
    GetClipRequest req;
    req.set_grid_id(m_gridId);
    std::string s = req.SerializeAsString();
    std::vector<uint8_t> data(s.begin(), s.end());
    auto resp = InvokePlugin("/volvoxgrid.activex.VolvoxGridService/GetClip", data);
    if (resp.size() > 1 && resp[0] == 0) {
        StringValue val;
        if (val.ParseFromArray(resp.data()+1, (int)resp.size()-1)) {
            CComBSTR bstr = Utf8ToBstr(val.value());
            *pVal = bstr.Detach();
        }
    }
    return S_OK;
}

STDMETHODIMP CVolvoxGridCtrl::put_Clip(BSTR newVal)
{
    SetClipRequest req;
    req.set_grid_id(m_gridId);
    req.set_clip(BstrToUtf8(newVal));
    std::string s = req.SerializeAsString();
    std::vector<uint8_t> data(s.begin(), s.end());
    InvokePlugin("/volvoxgrid.activex.VolvoxGridService/SetClip", data);
    RequestFrame();
    return S_OK;
}

// --- Redraw ---

STDMETHODIMP CVolvoxGridCtrl::get_Redraw(VARIANT_BOOL* pVal)
{
    if (!pVal) return E_POINTER;
    *pVal = VARIANT_TRUE;
    return S_OK;
}

STDMETHODIMP CVolvoxGridCtrl::put_Redraw(VARIANT_BOOL newVal)
{
    SetBoolProp req;
    req.set_grid_id(m_gridId);
    req.set_value(newVal != VARIANT_FALSE);
    std::string s = req.SerializeAsString();
    std::vector<uint8_t> data(s.begin(), s.end());
    InvokePlugin("/volvoxgrid.activex.VolvoxGridService/SetRedraw", data);
    if (newVal != VARIANT_FALSE) {
        RequestFrame();
    }
    return S_OK;
}

// --- AutoResize ---

STDMETHODIMP CVolvoxGridCtrl::get_AutoResize(VARIANT_BOOL* pVal)
{
    if (!pVal) return E_POINTER;
    *pVal = m_autoResize;
    return S_OK;
}

STDMETHODIMP CVolvoxGridCtrl::put_AutoResize(VARIANT_BOOL newVal)
{
    m_autoResize = newVal;
    return S_OK;
}

// ═══════════════════════════════════════════════════════════════════
// IVolvoxGrid Methods
// ═══════════════════════════════════════════════════════════════════

STDMETHODIMP CVolvoxGridCtrl::SetTextMatrix(long row, long col, BSTR text)
{
    SetTextMatrixRequest req;
    req.set_grid_id(m_gridId);
    req.set_row(row);
    req.set_col(col);
    req.set_text(BstrToUtf8(text));
    std::string s = req.SerializeAsString();
    std::vector<uint8_t> data(s.begin(), s.end());
    InvokePlugin("/volvoxgrid.activex.VolvoxGridService/SetTextMatrix", data);
    return S_OK;
}

STDMETHODIMP CVolvoxGridCtrl::GetTextMatrix(long row, long col, BSTR* pText)
{
    if (!pText) return E_POINTER;
    GetTextMatrixRequest req;
    req.set_grid_id(m_gridId);
    req.set_row(row);
    req.set_col(col);
    std::string s = req.SerializeAsString();
    std::vector<uint8_t> data(s.begin(), s.end());
    auto resp = InvokePlugin("/volvoxgrid.activex.VolvoxGridService/GetTextMatrix", data);
    if (resp.size() > 1 && resp[0] == 0) {
        StringValue val;
        if (val.ParseFromArray(resp.data()+1, (int)resp.size()-1)) {
            CComBSTR bstr = Utf8ToBstr(val.value());
            *pText = bstr.Detach();
        }
    }
    return S_OK;
}

STDMETHODIMP CVolvoxGridCtrl::Sort(FlexSortOrder order)
{
    SortRequest req;
    req.set_grid_id(m_gridId);
    auto* sortCol = req.add_sort_columns();
    sortCol->set_col(-1);  // apply to the current/selected column scope
    sortCol->set_order(static_cast<FlexSortSpec>(order));
    std::string s = req.SerializeAsString();
    std::vector<uint8_t> data(s.begin(), s.end());
    InvokePlugin("/volvoxgrid.activex.VolvoxGridService/Sort", data);
    RequestFrame();
    return S_OK;
}

STDMETHODIMP CVolvoxGridCtrl::AutoSize(long colFrom, long colTo)
{
    AutoSizeRequest req;
    req.set_grid_id(m_gridId);
    req.set_col_from(colFrom);
    req.set_col_to(colTo);
    std::string s = req.SerializeAsString();
    std::vector<uint8_t> data(s.begin(), s.end());
    InvokePlugin("/volvoxgrid.activex.VolvoxGridService/AutoSize", data);
    RequestFrame();
    return S_OK;
}

STDMETHODIMP CVolvoxGridCtrl::Subtotal(
    FlexAggregateType aggType, long groupOnCol,
    long aggregateCol, BSTR caption)
{
    SubtotalRequest req;
    req.set_grid_id(m_gridId);
    req.set_aggregate(static_cast<AggregateType>(aggType));
    req.set_group_on_col(groupOnCol);
    req.set_aggregate_col(aggregateCol);
    req.set_caption(BstrToUtf8(caption));
    std::string s = req.SerializeAsString();
    std::vector<uint8_t> data(s.begin(), s.end());
    InvokePlugin("/volvoxgrid.activex.VolvoxGridService/Subtotal", data);
    RequestFrame();
    return S_OK;
}

STDMETHODIMP CVolvoxGridCtrl::Clear(FlexClearScope scope)
{
    ClearRequest req;
    req.set_grid_id(m_gridId);
    req.set_scope(static_cast<ClearScope>(scope));
    req.set_region(CLEAR_SCROLLABLE);
    std::string s = req.SerializeAsString();
    std::vector<uint8_t> data(s.begin(), s.end());
    InvokePlugin("/volvoxgrid.activex.VolvoxGridService/Clear", data);
    RequestFrame();
    return S_OK;
}

STDMETHODIMP CVolvoxGridCtrl::SaveGrid(BSTR path, FlexSaveFormat fmt)
{
    // Save the grid data to the plugin, then write to file
    SaveGridRequest req;
    req.set_grid_id(m_gridId);
    req.set_format(static_cast<SaveGridFormat>(fmt));
    req.set_scope(SAVE_ALL);
    std::string s = req.SerializeAsString();
    std::vector<uint8_t> data(s.begin(), s.end());
    auto resp = InvokePlugin("/volvoxgrid.activex.VolvoxGridService/SaveGrid", data);

    if (resp.size() > 1 && resp[0] == 0) {
        GridData gridData;
        if (gridData.ParseFromArray(resp.data()+1, (int)resp.size()-1)) {
            // Write to file
            std::string filePath = BstrToUtf8(path);
            FILE* f = fopen(filePath.c_str(), "wb");
            if (f) {
                fwrite(gridData.data().data(), 1, gridData.data().size(), f);
                fclose(f);
            } else {
                return E_FAIL;
            }
        }
    }
    return S_OK;
}

STDMETHODIMP CVolvoxGridCtrl::LoadGrid(BSTR path, FlexSaveFormat fmt)
{
    std::string filePath = BstrToUtf8(path);
    FILE* f = fopen(filePath.c_str(), "rb");
    if (!f) return E_FAIL;

    fseek(f, 0, SEEK_END);
    long size = ftell(f);
    fseek(f, 0, SEEK_SET);

    std::string fileData(size, '\0');
    fread(&fileData[0], 1, size, f);
    fclose(f);

    LoadGridRequest req;
    req.set_grid_id(m_gridId);
    req.set_data(fileData);
    req.set_format(static_cast<SaveGridFormat>(fmt));
    req.set_scope(SAVE_ALL);
    std::string s = req.SerializeAsString();
    std::vector<uint8_t> data(s.begin(), s.end());
    InvokePlugin("/volvoxgrid.activex.VolvoxGridService/LoadGrid", data);
    RequestFrame();
    return S_OK;
}

STDMETHODIMP CVolvoxGridCtrl::AddItem(BSTR item, long index)
{
    AddItemRequest req;
    req.set_grid_id(m_gridId);
    req.set_item(BstrToUtf8(item));
    req.set_index(index);
    std::string s = req.SerializeAsString();
    std::vector<uint8_t> data(s.begin(), s.end());
    InvokePlugin("/volvoxgrid.activex.VolvoxGridService/AddItem", data);
    RequestFrame();
    return S_OK;
}

STDMETHODIMP CVolvoxGridCtrl::RemoveItem(long index)
{
    RemoveItemRequest req;
    req.set_grid_id(m_gridId);
    req.set_index(index);
    std::string s = req.SerializeAsString();
    std::vector<uint8_t> data(s.begin(), s.end());
    InvokePlugin("/volvoxgrid.activex.VolvoxGridService/RemoveItem", data);
    RequestFrame();
    return S_OK;
}

STDMETHODIMP CVolvoxGridCtrl::Select(long row1, long col1, long row2, long col2)
{
    SelectRequest req;
    req.set_grid_id(m_gridId);
    req.set_row1(row1);
    req.set_col1(col1);
    req.set_row2(row2);
    req.set_col2(col2);
    std::string s = req.SerializeAsString();
    std::vector<uint8_t> data(s.begin(), s.end());
    InvokePlugin("/volvoxgrid.activex.VolvoxGridService/Select", data);
    RequestFrame();
    return S_OK;
}

STDMETHODIMP CVolvoxGridCtrl::Refresh()
{
    if (m_dataSource) {
        return DataRefresh();
    }
    auto h = MakeHandle();
    std::string s = h.SerializeAsString();
    std::vector<uint8_t> data(s.begin(), s.end());
    InvokePlugin("/volvoxgrid.activex.VolvoxGridService/Refresh", data);
    RequestFrame();
    return S_OK;
}

// --- ColWidth, RowHeight, ColAlignment (indexed properties) ---

STDMETHODIMP CVolvoxGridCtrl::get_ColWidth(long col, long* pVal)
{
    if (!pVal) return E_POINTER;
    RowColIndex req;
    req.set_grid_id(m_gridId);
    req.set_index(col);
    std::string s = req.SerializeAsString();
    std::vector<uint8_t> data(s.begin(), s.end());
    auto resp = InvokePlugin("/volvoxgrid.activex.VolvoxGridService/GetColWidth", data);
    if (resp.size() > 1 && resp[0] == 0) {
        Int32Value val;
        if (val.ParseFromArray(resp.data()+1, (int)resp.size()-1))
            *pVal = val.value();
    }
    return S_OK;
}

STDMETHODIMP CVolvoxGridCtrl::put_ColWidth(long col, long newVal)
{
    SetColWidthRequest req;
    req.set_grid_id(m_gridId);
    req.set_col(col);
    req.set_width(newVal);
    std::string s = req.SerializeAsString();
    std::vector<uint8_t> data(s.begin(), s.end());
    InvokePlugin("/volvoxgrid.activex.VolvoxGridService/SetColWidth", data);
    RequestFrame();
    return S_OK;
}

STDMETHODIMP CVolvoxGridCtrl::get_RowHeight(long row, long* pVal)
{
    if (!pVal) return E_POINTER;
    RowColIndex req;
    req.set_grid_id(m_gridId);
    req.set_index(row);
    std::string s = req.SerializeAsString();
    std::vector<uint8_t> data(s.begin(), s.end());
    auto resp = InvokePlugin("/volvoxgrid.activex.VolvoxGridService/GetRowHeight", data);
    if (resp.size() > 1 && resp[0] == 0) {
        Int32Value val;
        if (val.ParseFromArray(resp.data()+1, (int)resp.size()-1))
            *pVal = val.value();
    }
    return S_OK;
}

STDMETHODIMP CVolvoxGridCtrl::put_RowHeight(long row, long newVal)
{
    SetRowHeightRequest req;
    req.set_grid_id(m_gridId);
    req.set_row(row);
    req.set_height(newVal);
    std::string s = req.SerializeAsString();
    std::vector<uint8_t> data(s.begin(), s.end());
    InvokePlugin("/volvoxgrid.activex.VolvoxGridService/SetRowHeight", data);
    RequestFrame();
    return S_OK;
}

STDMETHODIMP CVolvoxGridCtrl::get_ColAlignment(long col, FlexAlign* pVal)
{
    if (!pVal) return E_POINTER;
    *pVal = flexAlignGeneral;  // default
    return S_OK;
}

STDMETHODIMP CVolvoxGridCtrl::put_ColAlignment(long col, FlexAlign newVal)
{
    SetColAlignmentRequest req;
    req.set_grid_id(m_gridId);
    req.set_col(col);
    req.set_alignment(static_cast<Align>(newVal));
    std::string s = req.SerializeAsString();
    std::vector<uint8_t> data(s.begin(), s.end());
    InvokePlugin("/volvoxgrid.activex.VolvoxGridService/SetColAlignment", data);
    RequestFrame();
    return S_OK;
}

STDMETHODIMP CVolvoxGridCtrl::SetColFormat(long col, BSTR format)
{
    SetColFormatRequest req;
    req.set_grid_id(m_gridId);
    req.set_col(col);
    req.set_format(BstrToUtf8(format));
    std::string s = req.SerializeAsString();
    std::vector<uint8_t> data(s.begin(), s.end());
    InvokePlugin("/volvoxgrid.activex.VolvoxGridService/SetColFormat", data);
    RequestFrame();
    return S_OK;
}

STDMETHODIMP CVolvoxGridCtrl::SetColSort(long col, FlexSortOrder order)
{
    SetColSortRequest req;
    req.set_grid_id(m_gridId);
    req.set_col(col);
    req.set_order(static_cast<FlexSortSpec>(order));
    std::string s = req.SerializeAsString();
    std::vector<uint8_t> data(s.begin(), s.end());
    InvokePlugin("/volvoxgrid.activex.VolvoxGridService/SetColSort", data);
    return S_OK;
}

// --- Data Source (delegated to ADOAdapter.cpp) ---

STDMETHODIMP CVolvoxGridCtrl::get_DataSource(IDispatch** pVal)
{
    if (!pVal) return E_POINTER;
    *pVal = nullptr;
    return m_dataSource.CopyTo(pVal);
}

STDMETHODIMP CVolvoxGridCtrl::putref_DataSource(IDispatch* pDataSource)
{
    m_dataSource = pDataSource;
    if (m_dataMode != 0) {
        VARIANT_BOOL cancel = VARIANT_FALSE;
        Fire_BeforeDataRefresh(&cancel);
        if (cancel != VARIANT_FALSE) {
            return S_OK;
        }
    }
    extern HRESULT ADOAdapter_BindDataSource(CVolvoxGridCtrl* ctrl, IDispatch* pDataSource, BSTR dataMember);
    HRESULT hr = ADOAdapter_BindDataSource(this, pDataSource, m_dataMember);
    if (SUCCEEDED(hr)) {
        RequestFrame();
    }
    if (SUCCEEDED(hr) && m_dataMode != 0) {
        Fire_AfterDataRefresh();
    }
    return hr;
}

STDMETHODIMP CVolvoxGridCtrl::get_DataMember(BSTR* pVal)
{
    if (!pVal) return E_POINTER;
    *pVal = m_dataMember.Copy();
    return S_OK;
}

STDMETHODIMP CVolvoxGridCtrl::put_DataMember(BSTR newVal)
{
    m_dataMember = newVal;
    if (m_dataSource) {
        return DataRefresh();
    }
    return S_OK;
}

STDMETHODIMP CVolvoxGridCtrl::get_DataMode(FlexDataMode* pVal)
{
    if (!pVal) return E_POINTER;
    *pVal = static_cast<FlexDataMode>(m_dataMode);
    return S_OK;
}

STDMETHODIMP CVolvoxGridCtrl::put_DataMode(FlexDataMode newVal)
{
    m_dataMode = static_cast<long>(newVal);
    SetInt32Prop req;
    req.set_grid_id(m_gridId);
    req.set_value(m_dataMode);
    std::string s = req.SerializeAsString();
    std::vector<uint8_t> data(s.begin(), s.end());
    InvokePlugin("/volvoxgrid.activex.VolvoxGridService/SetDataMode", data);
    return S_OK;
}

STDMETHODIMP CVolvoxGridCtrl::get_VirtualData(VARIANT_BOOL* pVal)
{
    if (!pVal) return E_POINTER;
    *pVal = m_virtualData;
    return S_OK;
}

STDMETHODIMP CVolvoxGridCtrl::put_VirtualData(VARIANT_BOOL newVal)
{
    m_virtualData = newVal != VARIANT_FALSE ? VARIANT_TRUE : VARIANT_FALSE;
    SetBoolProp req;
    req.set_grid_id(m_gridId);
    req.set_value(m_virtualData != VARIANT_FALSE);
    std::string s = req.SerializeAsString();
    std::vector<uint8_t> data(s.begin(), s.end());
    InvokePlugin("/volvoxgrid.activex.VolvoxGridService/SetVirtualData", data);
    return S_OK;
}

STDMETHODIMP CVolvoxGridCtrl::DataRefresh()
{
    if (m_dataMode != 0) {
        VARIANT_BOOL cancel = VARIANT_FALSE;
        Fire_BeforeDataRefresh(&cancel);
        if (cancel != VARIANT_FALSE) {
            return S_OK;
        }
    }

    extern HRESULT ADOAdapter_BindDataSource(CVolvoxGridCtrl* ctrl, IDispatch* pDataSource, BSTR dataMember);
    HRESULT hr = ADOAdapter_BindDataSource(this, m_dataSource, m_dataMember);

    auto h = MakeHandle();
    std::string s = h.SerializeAsString();
    std::vector<uint8_t> data(s.begin(), s.end());
    InvokePlugin("/volvoxgrid.activex.VolvoxGridService/DataRefresh", data);
    RequestFrame();

    if (SUCCEEDED(hr) && m_dataMode != 0) {
        Fire_AfterDataRefresh();
    }
    return hr;
}

// ═══════════════════════════════════════════════════════════════════
// Event Firing via Connection Points
// ═══════════════════════════════════════════════════════════════════

// Helper to iterate all connected sinks and invoke a dispid
#define FIRE_EVENT_IMPL(method, dispid, ...)                                  \
    void CVolvoxGridCtrl::Fire_##method(__VA_ARGS__)                            \
    {                                                                         \
        /* Iterate connection point sinks */                                  \
        IConnectionPointImpl<CVolvoxGridCtrl, &DIID__DVolvoxGridEvents>* pCP =    \
            this;                                                             \
        int nConnections = pCP->m_vec.GetSize();                              \
        for (int i = 0; i < nConnections; i++) {                              \
            CComPtr<IUnknown> pUnk = pCP->m_vec.GetAt(i);                     \
            if (!pUnk) continue;                                              \
            CComPtr<IDispatch> pDisp;                                         \
            pUnk->QueryInterface(IID_IDispatch, (void**)&pDisp);              \
            if (!pDisp) continue;                                             \
            /* Build DISPPARAMS and invoke */                                  \

// For simplicity, implement the most important events directly:

void CVolvoxGridCtrl::Fire_BeforeRowColChange(
    long oldRow, long oldCol, long newRow, long newCol, VARIANT_BOOL* cancel)
{
    IConnectionPointImpl<CVolvoxGridCtrl, &DIID__DVolvoxGridEvents>* pCP = this;
    int nConnections = pCP->m_vec.GetSize();
    for (int i = 0; i < nConnections; i++) {
        CComPtr<IUnknown> pUnk = pCP->m_vec.GetAt(i);
        if (!pUnk) continue;
        CComPtr<IDispatch> pDisp;
        pUnk->QueryInterface(IID_IDispatch, (void**)&pDisp);
        if (!pDisp) continue;

        VARIANT args[5];
        VariantInit(&args[4]); args[4].vt = VT_I4; args[4].lVal = oldRow;
        VariantInit(&args[3]); args[3].vt = VT_I4; args[3].lVal = oldCol;
        VariantInit(&args[2]); args[2].vt = VT_I4; args[2].lVal = newRow;
        VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = newCol;
        VariantInit(&args[0]); args[0].vt = VT_BYREF | VT_BOOL; args[0].pboolVal = cancel;

        DISPPARAMS dp = { args, nullptr, 5, 0 };
        pDisp->Invoke(1, IID_NULL, LOCALE_USER_DEFAULT, DISPATCH_METHOD, &dp, nullptr, nullptr, nullptr);
    }
}

void CVolvoxGridCtrl::Fire_AfterRowColChange()
{
    IConnectionPointImpl<CVolvoxGridCtrl, &DIID__DVolvoxGridEvents>* pCP = this;
    int nConnections = pCP->m_vec.GetSize();
    for (int i = 0; i < nConnections; i++) {
        CComPtr<IUnknown> pUnk = pCP->m_vec.GetAt(i);
        if (!pUnk) continue;
        CComPtr<IDispatch> pDisp;
        pUnk->QueryInterface(IID_IDispatch, (void**)&pDisp);
        if (!pDisp) continue;

        DISPPARAMS dp = { nullptr, nullptr, 0, 0 };
        pDisp->Invoke(2, IID_NULL, LOCALE_USER_DEFAULT, DISPATCH_METHOD, &dp, nullptr, nullptr, nullptr);
    }
}

void CVolvoxGridCtrl::Fire_BeforeEdit(long row, long col, VARIANT_BOOL* cancel)
{
    IConnectionPointImpl<CVolvoxGridCtrl, &DIID__DVolvoxGridEvents>* pCP = this;
    int nConnections = pCP->m_vec.GetSize();
    for (int i = 0; i < nConnections; i++) {
        CComPtr<IUnknown> pUnk = pCP->m_vec.GetAt(i);
        if (!pUnk) continue;
        CComPtr<IDispatch> pDisp;
        pUnk->QueryInterface(IID_IDispatch, (void**)&pDisp);
        if (!pDisp) continue;

        VARIANT args[3];
        VariantInit(&args[2]); args[2].vt = VT_I4; args[2].lVal = row;
        VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = col;
        VariantInit(&args[0]); args[0].vt = VT_BYREF | VT_BOOL; args[0].pboolVal = cancel;

        DISPPARAMS dp = { args, nullptr, 3, 0 };
        pDisp->Invoke(3, IID_NULL, LOCALE_USER_DEFAULT, DISPATCH_METHOD, &dp, nullptr, nullptr, nullptr);
    }
}

void CVolvoxGridCtrl::Fire_AfterEdit(long row, long col)
{
    IConnectionPointImpl<CVolvoxGridCtrl, &DIID__DVolvoxGridEvents>* pCP = this;
    int nConnections = pCP->m_vec.GetSize();
    for (int i = 0; i < nConnections; i++) {
        CComPtr<IUnknown> pUnk = pCP->m_vec.GetAt(i);
        if (!pUnk) continue;
        CComPtr<IDispatch> pDisp;
        pUnk->QueryInterface(IID_IDispatch, (void**)&pDisp);
        if (!pDisp) continue;

        VARIANT args[2];
        VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = row;
        VariantInit(&args[0]); args[0].vt = VT_I4; args[0].lVal = col;

        DISPPARAMS dp = { args, nullptr, 2, 0 };
        pDisp->Invoke(4, IID_NULL, LOCALE_USER_DEFAULT, DISPATCH_METHOD, &dp, nullptr, nullptr, nullptr);
    }
}

void CVolvoxGridCtrl::Fire_BeforeSort(long col, VARIANT_BOOL* cancel)
{
    IConnectionPointImpl<CVolvoxGridCtrl, &DIID__DVolvoxGridEvents>* pCP = this;
    int nConnections = pCP->m_vec.GetSize();
    for (int i = 0; i < nConnections; i++) {
        CComPtr<IUnknown> pUnk = pCP->m_vec.GetAt(i);
        if (!pUnk) continue;
        CComPtr<IDispatch> pDisp;
        pUnk->QueryInterface(IID_IDispatch, (void**)&pDisp);
        if (!pDisp) continue;

        VARIANT args[2];
        VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = col;
        VariantInit(&args[0]); args[0].vt = VT_BYREF | VT_BOOL; args[0].pboolVal = cancel;

        DISPPARAMS dp = { args, nullptr, 2, 0 };
        pDisp->Invoke(5, IID_NULL, LOCALE_USER_DEFAULT, DISPATCH_METHOD, &dp, nullptr, nullptr, nullptr);
    }
}

void CVolvoxGridCtrl::Fire_AfterSort()
{
    IConnectionPointImpl<CVolvoxGridCtrl, &DIID__DVolvoxGridEvents>* pCP = this;
    int nConnections = pCP->m_vec.GetSize();
    for (int i = 0; i < nConnections; i++) {
        CComPtr<IUnknown> pUnk = pCP->m_vec.GetAt(i);
        if (!pUnk) continue;
        CComPtr<IDispatch> pDisp;
        pUnk->QueryInterface(IID_IDispatch, (void**)&pDisp);
        if (!pDisp) continue;

        DISPPARAMS dp = { nullptr, nullptr, 0, 0 };
        pDisp->Invoke(6, IID_NULL, LOCALE_USER_DEFAULT, DISPATCH_METHOD, &dp, nullptr, nullptr, nullptr);
    }
}

void CVolvoxGridCtrl::Fire_BeforeDataRefresh(VARIANT_BOOL* cancel)
{
    IConnectionPointImpl<CVolvoxGridCtrl, &DIID__DVolvoxGridEvents>* pCP = this;
    int nConnections = pCP->m_vec.GetSize();
    for (int i = 0; i < nConnections; i++) {
        CComPtr<IUnknown> pUnk = pCP->m_vec.GetAt(i);
        if (!pUnk) continue;
        CComPtr<IDispatch> pDisp;
        pUnk->QueryInterface(IID_IDispatch, (void**)&pDisp);
        if (!pDisp) continue;

        VARIANT args[1];
        VariantInit(&args[0]); args[0].vt = VT_BYREF | VT_BOOL; args[0].pboolVal = cancel;

        DISPPARAMS dp = { args, nullptr, 1, 0 };
        pDisp->Invoke(22, IID_NULL, LOCALE_USER_DEFAULT, DISPATCH_METHOD, &dp, nullptr, nullptr, nullptr);
    }
}

void CVolvoxGridCtrl::Fire_AfterDataRefresh()
{
    IConnectionPointImpl<CVolvoxGridCtrl, &DIID__DVolvoxGridEvents>* pCP = this;
    int nConnections = pCP->m_vec.GetSize();
    for (int i = 0; i < nConnections; i++) {
        CComPtr<IUnknown> pUnk = pCP->m_vec.GetAt(i);
        if (!pUnk) continue;
        CComPtr<IDispatch> pDisp;
        pUnk->QueryInterface(IID_IDispatch, (void**)&pDisp);
        if (!pDisp) continue;

        DISPPARAMS dp = { nullptr, nullptr, 0, 0 };
        pDisp->Invoke(23, IID_NULL, LOCALE_USER_DEFAULT, DISPATCH_METHOD, &dp, nullptr, nullptr, nullptr);
    }
}

// Simple events (no parameters or trivial)

#define FIRE_SIMPLE_EVENT(Name, DispId)                                        \
    void CVolvoxGridCtrl::Fire_##Name() {                                        \
        IConnectionPointImpl<CVolvoxGridCtrl, &DIID__DVolvoxGridEvents>* pCP =     \
            this;                                                              \
        int n = pCP->m_vec.GetSize();                                          \
        for (int i = 0; i < n; i++) {                                          \
            CComPtr<IUnknown> pUnk = pCP->m_vec.GetAt(i);                      \
            if (!pUnk) continue;                                               \
            CComPtr<IDispatch> pDisp;                                          \
            pUnk->QueryInterface(IID_IDispatch, (void**)&pDisp);               \
            if (!pDisp) continue;                                              \
            DISPPARAMS dp = { nullptr, nullptr, 0, 0 };                        \
            pDisp->Invoke(DispId, IID_NULL, LOCALE_USER_DEFAULT,               \
                          DISPATCH_METHOD, &dp, nullptr, nullptr, nullptr);    \
        }                                                                      \
    }

FIRE_SIMPLE_EVENT(Click,    7)
FIRE_SIMPLE_EVENT(DblClick, 8)
FIRE_SIMPLE_EVENT(Scroll,  20)

#undef FIRE_SIMPLE_EVENT

void CVolvoxGridCtrl::Fire_KeyDown(long keyCode, long shift)
{
    IConnectionPointImpl<CVolvoxGridCtrl, &DIID__DVolvoxGridEvents>* pCP = this;
    int n = pCP->m_vec.GetSize();
    for (int i = 0; i < n; i++) {
        CComPtr<IUnknown> pUnk = pCP->m_vec.GetAt(i);
        if (!pUnk) continue;
        CComPtr<IDispatch> pDisp;
        pUnk->QueryInterface(IID_IDispatch, (void**)&pDisp);
        if (!pDisp) continue;

        VARIANT args[2];
        VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = keyCode;
        VariantInit(&args[0]); args[0].vt = VT_I4; args[0].lVal = shift;

        DISPPARAMS dp = { args, nullptr, 2, 0 };
        pDisp->Invoke(9, IID_NULL, LOCALE_USER_DEFAULT, DISPATCH_METHOD, &dp, nullptr, nullptr, nullptr);
    }
}

void CVolvoxGridCtrl::Fire_KeyPress(long keyAscii)
{
    IConnectionPointImpl<CVolvoxGridCtrl, &DIID__DVolvoxGridEvents>* pCP = this;
    int n = pCP->m_vec.GetSize();
    for (int i = 0; i < n; i++) {
        CComPtr<IUnknown> pUnk = pCP->m_vec.GetAt(i);
        if (!pUnk) continue;
        CComPtr<IDispatch> pDisp;
        pUnk->QueryInterface(IID_IDispatch, (void**)&pDisp);
        if (!pDisp) continue;

        VARIANT args[1];
        VariantInit(&args[0]); args[0].vt = VT_I4; args[0].lVal = keyAscii;

        DISPPARAMS dp = { args, nullptr, 1, 0 };
        pDisp->Invoke(10, IID_NULL, LOCALE_USER_DEFAULT, DISPATCH_METHOD, &dp, nullptr, nullptr, nullptr);
    }
}

void CVolvoxGridCtrl::Fire_KeyUp(long keyCode, long shift)
{
    IConnectionPointImpl<CVolvoxGridCtrl, &DIID__DVolvoxGridEvents>* pCP = this;
    int n = pCP->m_vec.GetSize();
    for (int i = 0; i < n; i++) {
        CComPtr<IUnknown> pUnk = pCP->m_vec.GetAt(i);
        if (!pUnk) continue;
        CComPtr<IDispatch> pDisp;
        pUnk->QueryInterface(IID_IDispatch, (void**)&pDisp);
        if (!pDisp) continue;

        VARIANT args[2];
        VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = keyCode;
        VariantInit(&args[0]); args[0].vt = VT_I4; args[0].lVal = shift;

        DISPPARAMS dp = { args, nullptr, 2, 0 };
        pDisp->Invoke(11, IID_NULL, LOCALE_USER_DEFAULT, DISPATCH_METHOD, &dp, nullptr, nullptr, nullptr);
    }
}

// Mouse events with 4 params: button, shift, x, y

#define FIRE_MOUSE_EVENT(Name, DispId)                                         \
    void CVolvoxGridCtrl::Fire_##Name(                                           \
        long button, long shift, float x, float y) {                           \
        IConnectionPointImpl<CVolvoxGridCtrl, &DIID__DVolvoxGridEvents>* pCP =     \
            this;                                                              \
        int n = pCP->m_vec.GetSize();                                          \
        for (int i = 0; i < n; i++) {                                          \
            CComPtr<IUnknown> pUnk = pCP->m_vec.GetAt(i);                      \
            if (!pUnk) continue;                                               \
            CComPtr<IDispatch> pDisp;                                          \
            pUnk->QueryInterface(IID_IDispatch, (void**)&pDisp);               \
            if (!pDisp) continue;                                              \
            VARIANT args[4];                                                   \
            VariantInit(&args[3]); args[3].vt=VT_I4; args[3].lVal=button;      \
            VariantInit(&args[2]); args[2].vt=VT_I4; args[2].lVal=shift;       \
            VariantInit(&args[1]); args[1].vt=VT_R4; args[1].fltVal=x;         \
            VariantInit(&args[0]); args[0].vt=VT_R4; args[0].fltVal=y;         \
            DISPPARAMS dp = { args, nullptr, 4, 0 };                           \
            pDisp->Invoke(DispId, IID_NULL, LOCALE_USER_DEFAULT,               \
                          DISPATCH_METHOD, &dp, nullptr, nullptr, nullptr);    \
        }                                                                      \
    }

FIRE_MOUSE_EVENT(MouseDown, 12)
FIRE_MOUSE_EVENT(MouseUp,   13)
FIRE_MOUSE_EVENT(MouseMove, 14)

#undef FIRE_MOUSE_EVENT

void CVolvoxGridCtrl::Fire_CellChanged(long row, long col)
{
    IConnectionPointImpl<CVolvoxGridCtrl, &DIID__DVolvoxGridEvents>* pCP = this;
    int n = pCP->m_vec.GetSize();
    for (int i = 0; i < n; i++) {
        CComPtr<IUnknown> pUnk = pCP->m_vec.GetAt(i);
        if (!pUnk) continue;
        CComPtr<IDispatch> pDisp;
        pUnk->QueryInterface(IID_IDispatch, (void**)&pDisp);
        if (!pDisp) continue;

        VARIANT args[2];
        VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = row;
        VariantInit(&args[0]); args[0].vt = VT_I4; args[0].lVal = col;

        DISPPARAMS dp = { args, nullptr, 2, 0 };
        pDisp->Invoke(19, IID_NULL, LOCALE_USER_DEFAULT, DISPATCH_METHOD, &dp, nullptr, nullptr, nullptr);
    }
}
