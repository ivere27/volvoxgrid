' Test 58: ERP-style row copy using Cell(range) get/put
fg.Redraw = 0

fg.Rows = 9
fg.Cols = 6
fg.FixedRows = 1
fg.FixedCols = 1
fg.FocusRect = 0
fg.HighLight = 0

fg.TextMatrix(0, 0) = "#"
fg.TextMatrix(0, 1) = "Item"
fg.TextMatrix(0, 2) = "Lot"
fg.TextMatrix(0, 3) = "Quarter"
fg.TextMatrix(0, 4) = "Qty"
fg.TextMatrix(0, 5) = "Remark"

Dim i
For i = 1 To 8
    fg.TextMatrix(i, 0) = CStr(i)
    fg.TextMatrix(i, 1) = "ITEM-" & CStr(i)
    fg.TextMatrix(i, 2) = "LOT-" & CStr(100 + i)
    fg.TextMatrix(i, 3) = "Q" & CStr(((i - 1) Mod 4) + 1)
    fg.TextMatrix(i, 4) = CStr(i * 10)
    fg.TextMatrix(i, 5) = "ROW-" & CStr(i)
Next

' Source row values
fg.TextMatrix(3, 1) = "COPY-ME"
fg.TextMatrix(3, 2) = "LOT-777"
fg.TextMatrix(3, 3) = "Q9"
fg.TextMatrix(3, 4) = "999"
fg.TextMatrix(3, 5) = "SRC"

' Target row values that should be replaced (except fixed col 0)
fg.TextMatrix(7, 1) = "OLD-A"
fg.TextMatrix(7, 2) = "OLD-B"
fg.TextMatrix(7, 3) = "OLD-C"
fg.TextMatrix(7, 4) = "OLD-D"
fg.TextMatrix(7, 5) = "OLD-E"

Dim copyBuf
fg.Row = 3
copyBuf = fg.Cell(0, fg.Row, fg.FixedCols, fg.Row, fg.Cols - 1)

fg.Row = 7
fg.Cell(0, fg.Row, fg.FixedCols, fg.Row, fg.Cols - 1) = copyBuf

fg.Redraw = 1
