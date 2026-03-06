// VolvoxGridCtrl.h -- ATL control class for Volvox VolvoxGrid ActiveX
//
// Wraps the Rust VolvoxGrid engine via Synurang's C++ PluginHost + FFI client,
// presenting a COM/ActiveX surface usable from VBA and VB6.

#ifndef FLEXGRID_CTRL_H
#define FLEXGRID_CTRL_H

#pragma once

#include <atlbase.h>
#include <atlcom.h>
#include <atlctl.h>
#include <atlhost.h>

#include <vector>
#include <string>
#include <memory>
#include <thread>
#include <atomic>

#include "resource.h"
#include "VolvoxGrid_i.h"  // MIDL-generated: IID_IVolvoxGrid, CLSID_VolvoxGrid, etc.

#include <synurang/plugin_host.hpp>
#include "volvoxgrid_ffi.h"  // Generated FFI client

// ═══════════════════════════════════════════════════════════════════
// GUIDs (must match VolvoxGrid.idl)
// ═══════════════════════════════════════════════════════════════════

// CLSID_VolvoxGrid  = {D0B6E7F4-BA51-4C8D-CF9E-4A6B8C0D1E2F}
// IID_IVolvoxGrid   = {A7F3B4C1-8E2D-4F5A-9C6B-1D3E5F7A8B9C}
// DIID__DVolvoxGridEvents = {B8F4C5D2-9E3F-4A6B-AD7C-2E4F6A8B9C0D}
// LIBID_VolvoxGridLib     = {C9A5D6E3-AF40-4B7C-BE8D-3F5A7B9C0D1E}

// ═══════════════════════════════════════════════════════════════════
// CVolvoxGridCtrl
// ═══════════════════════════════════════════════════════════════════

class ATL_NO_VTABLE CVolvoxGridCtrl :
    public CComObjectRootEx<CComSingleThreadModel>,
    public CComCoClass<CVolvoxGridCtrl, &CLSID_VolvoxGrid>,
    public IDispatchImpl<IVolvoxGrid, &IID_IVolvoxGrid, &LIBID_VolvoxGridLib>,
    public IOleControlImpl<CVolvoxGridCtrl>,
    public IOleObjectImpl<CVolvoxGridCtrl>,
    public IOleInPlaceActiveObjectImpl<CVolvoxGridCtrl>,
    public IViewObjectExImpl<CVolvoxGridCtrl>,
    public IOleInPlaceObjectWindowlessImpl<CVolvoxGridCtrl>,
    public IConnectionPointContainerImpl<CVolvoxGridCtrl>,
    public IConnectionPointImpl<CVolvoxGridCtrl, &DIID__DVolvoxGridEvents>,
    public IPersistStreamInitImpl<CVolvoxGridCtrl>,
    public ISpecifyPropertyPagesImpl<CVolvoxGridCtrl>,
    public IQuickActivateImpl<CVolvoxGridCtrl>,
    public IDataObjectImpl<CVolvoxGridCtrl>,
    public IProvideClassInfo2Impl<&CLSID_VolvoxGrid, &DIID__DVolvoxGridEvents, &LIBID_VolvoxGridLib>,
    public CComControl<CVolvoxGridCtrl>
{
public:
    CVolvoxGridCtrl() = default;

    DECLARE_REGISTRY_RESOURCEID(IDR_FLEXGRIDCTRL)
    DECLARE_NOT_AGGREGATABLE(CVolvoxGridCtrl)

    BEGIN_COM_MAP(CVolvoxGridCtrl)
        COM_INTERFACE_ENTRY(IVolvoxGrid)
        COM_INTERFACE_ENTRY(IDispatch)
        COM_INTERFACE_ENTRY(IOleControl)
        COM_INTERFACE_ENTRY(IOleObject)
        COM_INTERFACE_ENTRY(IOleInPlaceActiveObject)
        COM_INTERFACE_ENTRY(IViewObjectEx)
        COM_INTERFACE_ENTRY(IViewObject2)
        COM_INTERFACE_ENTRY(IViewObject)
        COM_INTERFACE_ENTRY(IOleInPlaceObjectWindowless)
        COM_INTERFACE_ENTRY(IOleInPlaceObject)
        COM_INTERFACE_ENTRY2(IOleWindow, IOleInPlaceObjectWindowless)
        COM_INTERFACE_ENTRY(IConnectionPointContainer)
        COM_INTERFACE_ENTRY(IPersistStreamInit)
        COM_INTERFACE_ENTRY2(IPersist, IPersistStreamInit)
        COM_INTERFACE_ENTRY(ISpecifyPropertyPages)
        COM_INTERFACE_ENTRY(IQuickActivate)
        COM_INTERFACE_ENTRY(IDataObject)
        COM_INTERFACE_ENTRY(IProvideClassInfo)
        COM_INTERFACE_ENTRY(IProvideClassInfo2)
    END_COM_MAP()

    BEGIN_CONNECTION_POINT_MAP(CVolvoxGridCtrl)
        CONNECTION_POINT_ENTRY(DIID__DVolvoxGridEvents)
    END_CONNECTION_POINT_MAP()

    BEGIN_PROP_MAP(CVolvoxGridCtrl)
        // Ambient properties persisted automatically
    END_PROP_MAP()

    // ═══════════════════════════════════════════════════════
    // Windows Message Map
    // ═══════════════════════════════════════════════════════

    BEGIN_MSG_MAP(CVolvoxGridCtrl)
        MESSAGE_HANDLER(WM_PAINT, OnPaint)
        MESSAGE_HANDLER(WM_SIZE, OnSize)
        MESSAGE_HANDLER(WM_LBUTTONDOWN, OnLButtonDown)
        MESSAGE_HANDLER(WM_LBUTTONUP, OnLButtonUp)
        MESSAGE_HANDLER(WM_LBUTTONDBLCLK, OnLButtonDblClk)
        MESSAGE_HANDLER(WM_RBUTTONDOWN, OnRButtonDown)
        MESSAGE_HANDLER(WM_MOUSEMOVE, OnMouseMove)
        MESSAGE_HANDLER(WM_MOUSEWHEEL, OnMouseWheel)
        MESSAGE_HANDLER(WM_KEYDOWN, OnKeyDown)
        MESSAGE_HANDLER(WM_KEYUP, OnKeyUp)
        MESSAGE_HANDLER(WM_CHAR, OnChar)
        MESSAGE_HANDLER(WM_ERASEBKGND, OnEraseBkgnd)
        MESSAGE_HANDLER(WM_SETFOCUS, OnSetFocus)
        MESSAGE_HANDLER(WM_KILLFOCUS, OnKillFocus)
        MESSAGE_HANDLER(WM_TIMER, OnTimer)
        CHAIN_MSG_MAP(CComControl<CVolvoxGridCtrl>)
    END_MSG_MAP()

    // ═══════════════════════════════════════════════════════
    // Lifecycle
    // ═══════════════════════════════════════════════════════

    HRESULT FinalConstruct();
    void    FinalRelease();

    HRESULT OnDraw(ATL_DRAWINFO& di);

    // ═══════════════════════════════════════════════════════
    // IVolvoxGrid Property Implementations
    // ═══════════════════════════════════════════════════════

    // Grid Dimensions
    STDMETHOD(get_Rows)(long* pVal);
    STDMETHOD(put_Rows)(long newVal);
    STDMETHOD(get_Cols)(long* pVal);
    STDMETHOD(put_Cols)(long newVal);
    STDMETHOD(get_FixedRows)(long* pVal);
    STDMETHOD(put_FixedRows)(long newVal);
    STDMETHOD(get_FixedCols)(long* pVal);
    STDMETHOD(put_FixedCols)(long newVal);

    // Cursor
    STDMETHOD(get_Row)(long* pVal);
    STDMETHOD(put_Row)(long newVal);
    STDMETHOD(get_Col)(long* pVal);
    STDMETHOD(put_Col)(long newVal);
    STDMETHOD(get_RowSel)(long* pVal);
    STDMETHOD(put_RowSel)(long newVal);
    STDMETHOD(get_ColSel)(long* pVal);
    STDMETHOD(put_ColSel)(long newVal);

    // Selection & Appearance
    STDMETHOD(get_SelectionMode)(FlexSelectionMode* pVal);
    STDMETHOD(put_SelectionMode)(FlexSelectionMode newVal);
    STDMETHOD(get_HighLight)(FlexHighLight* pVal);
    STDMETHOD(put_HighLight)(FlexHighLight newVal);
    STDMETHOD(get_FocusRect)(FlexFocusRect* pVal);
    STDMETHOD(put_FocusRect)(FlexFocusRect newVal);

    // Colors
    STDMETHOD(get_BackColor)(OLE_COLOR* pVal);
    STDMETHOD(put_BackColor)(OLE_COLOR newVal);
    STDMETHOD(get_ForeColor)(OLE_COLOR* pVal);
    STDMETHOD(put_ForeColor)(OLE_COLOR newVal);
    STDMETHOD(get_GridColor)(OLE_COLOR* pVal);
    STDMETHOD(put_GridColor)(OLE_COLOR newVal);
    STDMETHOD(get_BackColorFixed)(OLE_COLOR* pVal);
    STDMETHOD(put_BackColorFixed)(OLE_COLOR newVal);
    STDMETHOD(get_ForeColorFixed)(OLE_COLOR* pVal);
    STDMETHOD(put_ForeColorFixed)(OLE_COLOR newVal);
    STDMETHOD(get_BackColorSel)(OLE_COLOR* pVal);
    STDMETHOD(put_BackColorSel)(OLE_COLOR newVal);
    STDMETHOD(get_ForeColorSel)(OLE_COLOR* pVal);
    STDMETHOD(put_ForeColorSel)(OLE_COLOR newVal);

    // Grid Lines
    STDMETHOD(get_GridLines)(VolvoxGridLines* pVal);
    STDMETHOD(put_GridLines)(VolvoxGridLines newVal);

    // Editing
    STDMETHOD(get_Editable)(FlexEditableMode* pVal);
    STDMETHOD(put_Editable)(FlexEditableMode newVal);

    // Cell Text
    STDMETHOD(get_Text)(BSTR* pVal);
    STDMETHOD(put_Text)(BSTR newVal);

    // Merge & Word Wrap
    STDMETHOD(get_MergeCells)(FlexMergeCells* pVal);
    STDMETHOD(put_MergeCells)(FlexMergeCells newVal);
    STDMETHOD(get_WordWrap)(VARIANT_BOOL* pVal);
    STDMETHOD(put_WordWrap)(VARIANT_BOOL newVal);

    // Frozen
    STDMETHOD(get_FrozenRows)(long* pVal);
    STDMETHOD(put_FrozenRows)(long newVal);
    STDMETHOD(get_FrozenCols)(long* pVal);
    STDMETHOD(put_FrozenCols)(long newVal);

    // Allow User Resizing
    STDMETHOD(get_AllowUserResizing)(FlexAllowUserResizing* pVal);
    STDMETHOD(put_AllowUserResizing)(FlexAllowUserResizing newVal);

    // Clipboard
    STDMETHOD(get_Clip)(BSTR* pVal);
    STDMETHOD(put_Clip)(BSTR newVal);

    // Redraw
    STDMETHOD(get_Redraw)(VARIANT_BOOL* pVal);
    STDMETHOD(put_Redraw)(VARIANT_BOOL newVal);

    // ═══════════════════════════════════════════════════════
    // IVolvoxGrid Method Implementations
    // ═══════════════════════════════════════════════════════

    STDMETHOD(SetTextMatrix)(long row, long col, BSTR text);
    STDMETHOD(GetTextMatrix)(long row, long col, BSTR* pText);
    STDMETHOD(Sort)(FlexSortOrder order);
    STDMETHOD(AutoSize)(long colFrom, long colTo);
    STDMETHOD(Subtotal)(FlexAggregateType aggType, long groupOnCol,
                        long aggregateCol, BSTR caption);
    STDMETHOD(Clear)(FlexClearScope scope);
    STDMETHOD(SaveGrid)(BSTR path, FlexSaveFormat fmt);
    STDMETHOD(LoadGrid)(BSTR path, FlexSaveFormat fmt);
    STDMETHOD(AddItem)(BSTR item, long index);
    STDMETHOD(RemoveItem)(long index);
    STDMETHOD(Select)(long row1, long col1, long row2, long col2);
    STDMETHOD(Refresh)();

    // Indexed properties (ColWidth, RowHeight, ColAlignment)
    STDMETHOD(get_ColWidth)(long col, long* pVal);
    STDMETHOD(put_ColWidth)(long col, long newVal);
    STDMETHOD(get_RowHeight)(long row, long* pVal);
    STDMETHOD(put_RowHeight)(long row, long newVal);
    STDMETHOD(get_ColAlignment)(long col, FlexAlign* pVal);
    STDMETHOD(put_ColAlignment)(long col, FlexAlign newVal);
    STDMETHOD(SetColFormat)(long col, BSTR format);
    STDMETHOD(SetColSort)(long col, FlexSortOrder order);

    // Data Binding
    STDMETHOD(putref_DataSource)(IDispatch* pDataSource);

    // Mouse Info
    STDMETHOD(get_MouseRow)(long* pVal);
    STDMETHOD(get_MouseCol)(long* pVal);

    // ═══════════════════════════════════════════════════════
    // Event Firing Helpers
    // ═══════════════════════════════════════════════════════

    void Fire_BeforeRowColChange(long oldRow, long oldCol,
                                 long newRow, long newCol,
                                 VARIANT_BOOL* cancel);
    void Fire_AfterRowColChange();
    void Fire_BeforeEdit(long row, long col, VARIANT_BOOL* cancel);
    void Fire_AfterEdit(long row, long col);
    void Fire_BeforeSort(long col, VARIANT_BOOL* cancel);
    void Fire_AfterSort();
    void Fire_Click();
    void Fire_DblClick();
    void Fire_KeyDown(long keyCode, long shift);
    void Fire_KeyPress(long keyAscii);
    void Fire_KeyUp(long keyCode, long shift);
    void Fire_MouseDown(long button, long shift, float x, float y);
    void Fire_MouseUp(long button, long shift, float x, float y);
    void Fire_MouseMove(long button, long shift, float x, float y);
    void Fire_CellChanged(long row, long col);
    void Fire_Scroll();

private:
    // ═══════════════════════════════════════════════════════
    // Message Handlers
    // ═══════════════════════════════════════════════════════

    LRESULT OnPaint(UINT uMsg, WPARAM wParam, LPARAM lParam, BOOL& bHandled);
    LRESULT OnSize(UINT uMsg, WPARAM wParam, LPARAM lParam, BOOL& bHandled);
    LRESULT OnLButtonDown(UINT uMsg, WPARAM wParam, LPARAM lParam, BOOL& bHandled);
    LRESULT OnLButtonUp(UINT uMsg, WPARAM wParam, LPARAM lParam, BOOL& bHandled);
    LRESULT OnLButtonDblClk(UINT uMsg, WPARAM wParam, LPARAM lParam, BOOL& bHandled);
    LRESULT OnRButtonDown(UINT uMsg, WPARAM wParam, LPARAM lParam, BOOL& bHandled);
    LRESULT OnMouseMove(UINT uMsg, WPARAM wParam, LPARAM lParam, BOOL& bHandled);
    LRESULT OnMouseWheel(UINT uMsg, WPARAM wParam, LPARAM lParam, BOOL& bHandled);
    LRESULT OnKeyDown(UINT uMsg, WPARAM wParam, LPARAM lParam, BOOL& bHandled);
    LRESULT OnKeyUp(UINT uMsg, WPARAM wParam, LPARAM lParam, BOOL& bHandled);
    LRESULT OnChar(UINT uMsg, WPARAM wParam, LPARAM lParam, BOOL& bHandled);
    LRESULT OnEraseBkgnd(UINT uMsg, WPARAM wParam, LPARAM lParam, BOOL& bHandled);
    LRESULT OnSetFocus(UINT uMsg, WPARAM wParam, LPARAM lParam, BOOL& bHandled);
    LRESULT OnKillFocus(UINT uMsg, WPARAM wParam, LPARAM lParam, BOOL& bHandled);
    LRESULT OnTimer(UINT uMsg, WPARAM wParam, LPARAM lParam, BOOL& bHandled);

    // ═══════════════════════════════════════════════════════
    // Rendering Helpers
    // ═══════════════════════════════════════════════════════

    void SendPointerEvent(volvoxgrid::legacy::PointerEvent::Type type,
                          float x, float y, int modifier, int button,
                          bool dblClick = false);
    void SendKeyEvent(volvoxgrid::legacy::KeyEvent::Type type,
                      int keyCode, int modifier,
                      const std::string& character = "");
    void SendScrollEvent(float dx, float dy);
    void ProcessRenderOutput(const volvoxgrid::legacy::RenderOutput& output);
    void RequestFrame();
    void StartEventThread();
    void StopEventThread();

    // ═══════════════════════════════════════════════════════
    // Synurang Plugin State
    // ═══════════════════════════════════════════════════════

    synurang::PluginHost                               m_pluginHost;
    std::unique_ptr<synurang::PluginStream>            m_renderStream;
    std::unique_ptr<synurang::PluginStream>            m_eventStream;
    int64_t                                            m_gridId = 0;

    // Pixel buffer (BGRA, bottom-up for GDI)
    std::vector<uint8_t>                               m_pixelBuffer;
    int                                                m_width  = 0;
    int                                                m_height = 0;
    BITMAPINFO                                         m_bmi    = {};

    // Event polling thread
    std::thread                                        m_eventThread;
    std::atomic<bool>                                  m_eventThreadRunning{false};

    // Cached grid style for color properties
    volvoxgrid::legacy::GridStyle                            m_cachedStyle;
    bool                                               m_styleDirty = true;
    long                                               m_fixedRows = 1;

    // ADO data source binding (see ADOAdapter.cpp)
    CComPtr<IDispatch>                                 m_dataSource;

    // Helper: invoke a unary RPC on the plugin
    std::vector<uint8_t> InvokePlugin(const std::string& method,
                                      const std::vector<uint8_t>& data);

    // Helper: BSTR <-> std::string
    static std::string BstrToUtf8(BSTR bstr);
    static CComBSTR    Utf8ToBstr(const std::string& s);

    // Helper: get the grid handle message
    volvoxgrid::legacy::GridHandle MakeHandle() const;

    // Helper: refresh cached style from engine
    void RefreshCachedStyle();
};

#endif // FLEXGRID_CTRL_H
