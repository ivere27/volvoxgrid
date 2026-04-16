' Test 105: .ID and legacy style compatibility properties
fg.Redraw = False
fg.FontSize = 10

fg.Rows = 4
fg.Cols = 2
fg.FixedRows = 1
fg.FixedCols = 0

fg.ID = "ERP-GRID-105"
fg.Appearance = 1
fg.SheetBorder = RGB(64, 96, 160)
fg.GridLineWidth = 2
fg.FontBold = True
fg.FontItalic = True
fg.FontUnderline = True
fg.FontStrikethru = True
fg.FontWidth = 75
fg.MousePointer = 2

fg.TextMatrix(0, 0) = "Property"
fg.TextMatrix(0, 1) = "Value"

fg.TextMatrix(1, 0) = "ID"
fg.TextMatrix(1, 1) = fg.ID

fg.TextMatrix(2, 0) = "FontFlags"
fg.TextMatrix(2, 1) = CStr(fg.FontBold) & "/" & CStr(fg.FontItalic) & "/" & CStr(fg.FontUnderline) & "/" & CStr(fg.FontStrikethru)

fg.TextMatrix(3, 0) = "Visual"
fg.TextMatrix(3, 1) = CStr(fg.Appearance) & "/" & CStr(fg.GridLineWidth) & "/" & CStr(fg.FontWidth) & "/" & CStr(fg.MousePointer)

fg.ColWidth(0) = 1400
fg.ColWidth(1) = 3200
fg.BackColorFixed = RGB(230, 236, 245)
fg.Row = 1
fg.Col = 1

fg.Redraw = True
