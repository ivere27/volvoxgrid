' Test 62: Fixed-row bold and essential-column coloring
' Mirrors sfSetFixedRowText + sfSetColBgColor style from ERP.
fg.Redraw = False
fg.FontSize = 10

fg.Cols = 6
fg.Rows = 12
fg.FixedRows = 2
fg.FixedCols = 1

fg.TextMatrix(0, 0) = "#"
fg.TextMatrix(0, 1) = "Code"
fg.TextMatrix(0, 2) = "Name*"
fg.TextMatrix(0, 3) = "Qty*"
fg.TextMatrix(0, 4) = "Price"
fg.TextMatrix(0, 5) = "Remark"

fg.TextMatrix(1, 0) = ""
fg.TextMatrix(1, 1) = ""
fg.TextMatrix(1, 2) = "Required"
fg.TextMatrix(1, 3) = "Required"
fg.TextMatrix(1, 4) = "Optional"
fg.TextMatrix(1, 5) = "Optional"

Dim i
For i = 2 To 11
    fg.TextMatrix(i, 0) = CStr(i - 1)
    fg.TextMatrix(i, 1) = "C-" & Right("00" & CStr(i - 1), 3)
    fg.TextMatrix(i, 2) = "Plant " & Chr(64 + ((i - 2) Mod 8) + 1)
    fg.TextMatrix(i, 3) = CStr((i - 1) * 5)
    fg.TextMatrix(i, 4) = CStr(800 + ((i - 1) * 37) Mod 300)
    fg.TextMatrix(i, 5) = "ok"
Next

fg.ColWidth(0) = 600
fg.ColWidth(1) = 1200
fg.ColWidth(2) = 1900
fg.ColWidth(3) = 1000
fg.ColWidth(4) = 1200
fg.ColWidth(5) = 1600
fg.ColAlignment(3) = 7
fg.ColAlignment(4) = 7

' Fixed header rows bold (Cell attribute 13 = FontBold)
fg.Cell(13, 0, 0, fg.FixedRows - 1, fg.Cols - 1) = True

' Essential columns background (Cell attribute 6 = BackColor)
fg.Cell(6, fg.FixedRows, 2, fg.Rows - 1, 2) = RGB(255, 250, 220)
fg.Cell(6, fg.FixedRows, 3, fg.Rows - 1, 3) = RGB(240, 255, 240)

fg.BackColorFixed = RGB(214, 228, 245)
fg.FrozenCols = 1
fg.TopRow = 2

fg.Redraw = True
