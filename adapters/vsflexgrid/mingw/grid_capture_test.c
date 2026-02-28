/* grid_capture_test.c — Minimal test for VolvoxGrid.ocx
 *
 * Creates a VolvoxGrid COM instance directly (no ATL hosting),
 * populates it via IDispatch, then uses IViewObject::Draw to
 * render a screenshot to BMP.
 *
 * Build with MinGW:
 *   i686-w64-mingw32-gcc -o grid_capture_test.exe grid_capture_test.c \
 *       -lole32 -loleaut32 -luuid
 *
 * Usage:
 *   1. Register the OCX:  regsvr32 VolvoxGrid_i686.ocx
 *   2. Run:               grid_capture_test.exe
 */

#define COBJMACROS
#define CINTERFACE
#include <windows.h>
#include <ole2.h>
#include <oleauto.h>
#include <olectl.h>
#include <stdio.h>
#include <stdlib.h>

/* VolvoxGrid CLSID — define storage directly */
static const GUID CLSID_VolvoxGrid =
    { 0xa7e3b4d1, 0x5c2f, 0x4e8a,
      { 0xb9, 0xd6, 0x1f, 0x3c, 0x7e, 0x2a, 0x4b, 0x5d } };

static HRESULT put_int(IDispatch *pDisp, LPCOLESTR name, int val) {
    DISPID dispid;
    LPOLESTR names[1] = { (LPOLESTR)name };
    HRESULT hr = pDisp->lpVtbl->GetIDsOfNames(pDisp, &IID_NULL, names, 1, 0, &dispid);
    if (FAILED(hr)) { printf("GetIDsOfNames(%ls) failed: 0x%08lx\n", name, hr); return hr; }
    VARIANT v; VariantInit(&v); v.vt = VT_I4; v.lVal = val;
    DISPID putid = DISPID_PROPERTYPUT;
    DISPPARAMS dp = { &v, &putid, 1, 1 };
    hr = pDisp->lpVtbl->Invoke(pDisp, dispid, &IID_NULL, 0, DISPATCH_PROPERTYPUT, &dp, NULL, NULL, NULL);
    if (FAILED(hr)) printf("put_int(%ls, %d) Invoke failed: 0x%08lx\n", name, val, hr);
    return hr;
}

static HRESULT put_text_matrix(IDispatch *pDisp, int row, int col, LPCWSTR text) {
    DISPID dispid;
    LPOLESTR name = L"TextMatrix";
    HRESULT hr = pDisp->lpVtbl->GetIDsOfNames(pDisp, &IID_NULL, &name, 1, 0, &dispid);
    if (FAILED(hr)) { printf("GetIDsOfNames(TextMatrix) failed: 0x%08lx\n", hr); return hr; }
    VARIANT args[3];
    VariantInit(&args[0]); args[0].vt = VT_BSTR; args[0].bstrVal = SysAllocString(text);
    VariantInit(&args[1]); args[1].vt = VT_I4;   args[1].lVal = col;
    VariantInit(&args[2]); args[2].vt = VT_I4;   args[2].lVal = row;
    DISPID putid = DISPID_PROPERTYPUT;
    DISPPARAMS dp = { args, &putid, 3, 1 };
    hr = pDisp->lpVtbl->Invoke(pDisp, dispid, &IID_NULL, 0, DISPATCH_PROPERTYPUT, &dp, NULL, NULL, NULL);
    SysFreeString(args[0].bstrVal);
    if (FAILED(hr)) printf("put_text_matrix(%d,%d,%ls) Invoke failed: 0x%08lx\n", row, col, text, hr);
    return hr;
}

static void save_bmp(HDC hdcMem, HBITMAP hbm, int w, int h, const char *filename) {
    int stride = ((w * 3 + 3) & ~3);
    int dataSize = stride * h;
    BITMAPINFOHEADER bi = {0};
    bi.biSize = sizeof(bi);
    bi.biWidth = w;
    bi.biHeight = h;
    bi.biPlanes = 1;
    bi.biBitCount = 24;
    bi.biCompression = BI_RGB;
    bi.biSizeImage = dataSize;
    BYTE *pixels = (BYTE*)malloc(dataSize);
    GetDIBits(hdcMem, hbm, 0, h, pixels, (BITMAPINFO*)&bi, DIB_RGB_COLORS);
    BITMAPFILEHEADER bf = {0};
    bf.bfType = 0x4D42;
    bf.bfOffBits = sizeof(bf) + sizeof(bi);
    bf.bfSize = bf.bfOffBits + dataSize;
    FILE *f = fopen(filename, "wb");
    if (f) {
        fwrite(&bf, sizeof(bf), 1, f);
        fwrite(&bi, sizeof(bi), 1, f);
        fwrite(pixels, dataSize, 1, f);
        fclose(f);
        printf("Screenshot saved: %s (%dx%d)\n", filename, w, h);
    } else {
        printf("Failed to open %s\n", filename);
    }
    free(pixels);
}

int main(void) {
    printf("=== VolvoxGrid.ocx Screenshot Test ===\n\n");

    printf("Initializing COM...\n");
    HRESULT hr = CoInitializeEx(NULL, COINIT_APARTMENTTHREADED);
    if (FAILED(hr)) {
        printf("CoInitializeEx failed: 0x%08lx\n", hr);
        return 1;
    }

    /* Create VolvoxGrid COM instance */
    printf("Creating VolvoxGrid instance...\n");
    IDispatch *pGrid = NULL;
    hr = CoCreateInstance(&CLSID_VolvoxGrid, NULL, CLSCTX_INPROC_SERVER,
                          &IID_IDispatch, (void **)&pGrid);
    if (FAILED(hr)) {
        printf("CoCreateInstance failed: 0x%08lx\n", hr);
        printf("Make sure the OCX is registered: regsvr32 VolvoxGrid_i686.ocx\n");
        CoUninitialize();
        return 1;
    }
    printf("Got IDispatch.\n");

    /* Populate the grid */
    printf("Populating grid...\n");
    put_int(pGrid, L"Cols", 4);
    put_int(pGrid, L"Rows", 6);
    put_int(pGrid, L"FixedRows", 1);
    put_int(pGrid, L"FixedCols", 0);
    put_text_matrix(pGrid, 0, 0, L"ID");
    put_text_matrix(pGrid, 0, 1, L"Name");
    put_text_matrix(pGrid, 0, 2, L"Value");
    put_text_matrix(pGrid, 0, 3, L"Status");
    put_text_matrix(pGrid, 1, 0, L"1");
    put_text_matrix(pGrid, 1, 1, L"Item A");
    put_text_matrix(pGrid, 1, 2, L"100");
    put_text_matrix(pGrid, 1, 3, L"OK");
    put_text_matrix(pGrid, 2, 0, L"2");
    put_text_matrix(pGrid, 2, 1, L"Item B");
    put_text_matrix(pGrid, 2, 2, L"200");
    put_text_matrix(pGrid, 2, 3, L"Pending");
    put_text_matrix(pGrid, 3, 0, L"3");
    put_text_matrix(pGrid, 3, 1, L"Item C");
    put_text_matrix(pGrid, 3, 2, L"300");
    put_text_matrix(pGrid, 3, 3, L"OK");
    put_text_matrix(pGrid, 4, 0, L"4");
    put_text_matrix(pGrid, 4, 1, L"Item D");
    put_text_matrix(pGrid, 4, 2, L"400");
    put_text_matrix(pGrid, 4, 3, L"Error");
    put_text_matrix(pGrid, 5, 0, L"5");
    put_text_matrix(pGrid, 5, 1, L"Item E");
    put_text_matrix(pGrid, 5, 2, L"500");
    put_text_matrix(pGrid, 5, 3, L"OK");
    printf("Grid populated.\n");

    /* Get IViewObject for rendering */
    IViewObject *pView = NULL;
    hr = pGrid->lpVtbl->QueryInterface(pGrid, &IID_IViewObject, (void **)&pView);
    if (SUCCEEDED(hr) && pView) {
        printf("Got IViewObject — rendering via Draw()...\n");
        int w = 800, h = 400;
        HDC hdcScreen = GetDC(NULL);
        HDC hdcMem = CreateCompatibleDC(hdcScreen);
        HBITMAP hbm = CreateCompatibleBitmap(hdcScreen, w, h);
        HBITMAP hOld = (HBITMAP)SelectObject(hdcMem, hbm);

        RECT rc = {0, 0, w, h};
        FillRect(hdcMem, &rc, (HBRUSH)GetStockObject(WHITE_BRUSH));

        RECTL rcl = {0, 0, w, h};
        hr = pView->lpVtbl->Draw(pView, DVASPECT_CONTENT, -1, NULL, NULL,
                                  NULL, hdcMem, &rcl, NULL, NULL, 0);
        printf("IViewObject::Draw returned: 0x%08lx\n", hr);

        save_bmp(hdcMem, hbm, w, h, "volvoxgrid_screenshot.bmp");

        SelectObject(hdcMem, hOld);
        DeleteObject(hbm);
        DeleteDC(hdcMem);
        ReleaseDC(NULL, hdcScreen);

        pView->lpVtbl->Release(pView);
    } else {
        printf("QueryInterface(IViewObject) failed: 0x%08lx\n", hr);
        printf("Trying OleDraw fallback...\n");
        IUnknown *pUnk = NULL;
        hr = pGrid->lpVtbl->QueryInterface(pGrid, &IID_IUnknown, (void **)&pUnk);
        if (SUCCEEDED(hr) && pUnk) {
            int w = 800, h = 400;
            HDC hdcScreen = GetDC(NULL);
            HDC hdcMem = CreateCompatibleDC(hdcScreen);
            HBITMAP hbm = CreateCompatibleBitmap(hdcScreen, w, h);
            HBITMAP hOld = (HBITMAP)SelectObject(hdcMem, hbm);
            RECT rc2 = {0, 0, w, h};
            hr = OleDraw(pUnk, DVASPECT_CONTENT, hdcMem, &rc2);
            printf("OleDraw returned: 0x%08lx\n", hr);
            save_bmp(hdcMem, hbm, w, h, "volvoxgrid_screenshot.bmp");
            SelectObject(hdcMem, hOld);
            DeleteObject(hbm);
            DeleteDC(hdcMem);
            ReleaseDC(NULL, hdcScreen);
            pUnk->lpVtbl->Release(pUnk);
        }
    }

    pGrid->lpVtbl->Release(pGrid);
    CoUninitialize();
    printf("\nDone.\n");
    return 0;
}
