#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static WCHAR *utf8_to_wide(const char *src) {
    int needed;
    WCHAR *out;
    if (!src) src = "";
    needed = MultiByteToWideChar(CP_UTF8, 0, src, -1, NULL, 0);
    if (needed <= 0) return NULL;
    out = (WCHAR *)malloc((size_t)needed * sizeof(WCHAR));
    if (!out) return NULL;
    if (MultiByteToWideChar(CP_UTF8, 0, src, -1, out, needed) <= 0) {
        free(out);
        return NULL;
    }
    return out;
}

static int measure_text(
    const char *font_name_utf8,
    double point_size,
    int bold,
    int italic,
    const char *text_utf8,
    int *px_out,
    int *text_h_out,
    int *ave_out,
    int *max_out,
    int *tm_h_out,
    int *ext_out,
    int *dpi_x_out,
    int *dpi_y_out)
{
    HDC hdc = NULL;
    HFONT font = NULL;
    HFONT old_font = NULL;
    TEXTMETRICW tm;
    SIZE size;
    LOGFONTW lf;
    WCHAR *font_name = NULL;
    WCHAR *text = NULL;
    int dpi_x = 96;
    int dpi_y = 96;
    int point100;
    int ok = 0;

    if (px_out) *px_out = 0;
    if (text_h_out) *text_h_out = 0;
    if (ave_out) *ave_out = 0;
    if (max_out) *max_out = 0;
    if (tm_h_out) *tm_h_out = 0;
    if (ext_out) *ext_out = 0;
    if (dpi_x_out) *dpi_x_out = dpi_x;
    if (dpi_y_out) *dpi_y_out = dpi_y;

    hdc = GetDC(NULL);
    if (!hdc) return 0;
    dpi_x = GetDeviceCaps(hdc, LOGPIXELSX);
    dpi_y = GetDeviceCaps(hdc, LOGPIXELSY);
    if (dpi_x <= 0) dpi_x = 96;
    if (dpi_y <= 0) dpi_y = 96;
    if (dpi_x_out) *dpi_x_out = dpi_x;
    if (dpi_y_out) *dpi_y_out = dpi_y;

    ZeroMemory(&lf, sizeof(lf));
    point100 = (int)(point_size * 100.0 + 0.5);
    if (point100 <= 0) point100 = 1000;
    lf.lfHeight = -MulDiv(point100, dpi_y, 72 * 100);
    lf.lfWeight = bold ? FW_BOLD : FW_NORMAL;
    lf.lfItalic = italic ? TRUE : FALSE;
    lf.lfCharSet = DEFAULT_CHARSET;
    lf.lfQuality = CLEARTYPE_QUALITY;

    if (font_name_utf8 && font_name_utf8[0]) {
        font_name = utf8_to_wide(font_name_utf8);
        if (font_name) {
            lstrcpynW(lf.lfFaceName, font_name, LF_FACESIZE);
        }
    }

    font = CreateFontIndirectW(&lf);
    if (!font) goto cleanup;
    old_font = (HFONT)SelectObject(hdc, font);

    text = utf8_to_wide(text_utf8 ? text_utf8 : "");
    if (!text) goto cleanup;

    ZeroMemory(&size, sizeof(size));
    if (text[0]) {
        if (!GetTextExtentPoint32W(hdc, text, lstrlenW(text), &size)) goto cleanup;
    }

    ZeroMemory(&tm, sizeof(tm));
    if (!GetTextMetricsW(hdc, &tm)) goto cleanup;

    if (px_out) *px_out = size.cx;
    if (text_h_out) *text_h_out = size.cy;
    if (ave_out) *ave_out = tm.tmAveCharWidth;
    if (max_out) *max_out = tm.tmMaxCharWidth;
    if (tm_h_out) *tm_h_out = tm.tmHeight;
    if (ext_out) *ext_out = tm.tmExternalLeading;
    ok = 1;

cleanup:
    if (old_font) SelectObject(hdc, old_font);
    if (font) DeleteObject(font);
    if (hdc) ReleaseDC(NULL, hdc);
    if (font_name) free(font_name);
    if (text) free(text);
    return ok;
}

static void chomp(char *s) {
    size_t n;
    if (!s) return;
    n = strlen(s);
    while (n > 0 && ((unsigned char)s[n - 1] == 10 || (unsigned char)s[n - 1] == 13)) {
        s[n - 1] = 0;
        --n;
    }
}

static void usage(const char *argv0) {
    fprintf(stderr, "Usage: %s --in INPUT --out OUTPUT\n", argv0);
}

int main(int argc, char **argv) {
    const char *in_path = NULL;
    const char *out_path = NULL;
    FILE *fin = NULL;
    FILE *fout = NULL;
    char line[8192];
    int i;

    for (i = 1; i < argc; ++i) {
        if (strcmp(argv[i], "--in") == 0 && i + 1 < argc) {
            in_path = argv[++i];
        } else if (strcmp(argv[i], "--out") == 0 && i + 1 < argc) {
            out_path = argv[++i];
        } else {
            usage(argv[0]);
            return 2;
        }
    }

    if (!in_path || !out_path) {
        usage(argv[0]);
        return 2;
    }

    fin = fopen(in_path, "rb");
    if (!fin) {
        fprintf(stderr, "Failed to open input: %s\n", in_path);
        return 1;
    }
    fout = fopen(out_path, "wb");
    if (!fout) {
        fprintf(stderr, "Failed to open output: %s\n", out_path);
        fclose(fin);
        return 1;
    }

    while (fgets(line, sizeof(line), fin)) {
        char *id;
        char *font_name;
        char *font_size_s;
        char *bold_s;
        char *italic_s;
        char *text;
        char *ctx;
        int px = 0;
        int text_h = 0;
        int ave = 0;
        int max = 0;
        int tm_h = 0;
        int ext = 0;
        int dpi_x = 96;
        int dpi_y = 96;
        int bold;
        int italic;
        int ok;
        double font_size;

        chomp(line);
        if (!line[0]) continue;

        id = strtok_s(line, "\t", &ctx);
        font_name = strtok_s(NULL, "\t", &ctx);
        font_size_s = strtok_s(NULL, "\t", &ctx);
        bold_s = strtok_s(NULL, "\t", &ctx);
        italic_s = strtok_s(NULL, "\t", &ctx);
        text = strtok_s(NULL, "", &ctx);
        if (!id || !font_name || !font_size_s || !bold_s || !italic_s || !text) {
            continue;
        }

        font_size = strtod(font_size_s, NULL);
        bold = atoi(bold_s);
        italic = atoi(italic_s);
        ok = measure_text(font_name, font_size, bold, italic, text,
            &px, &text_h, &ave, &max, &tm_h, &ext, &dpi_x, &dpi_y);
        fprintf(fout, "%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\n",
            id, ok ? px : -1, text_h, ave, max, tm_h, ext, dpi_x, dpi_y, ok);
    }

    fclose(fin);
    fclose(fout);
    return 0;
}
