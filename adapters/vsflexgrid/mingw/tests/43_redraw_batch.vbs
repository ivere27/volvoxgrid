' Test 43: Redraw batch mode
' Disable redraw, perform heavy updates, re-enable.
' Mimics the standard ERP initialization pattern.
fg.FontSize = 10
fg.Redraw = False

fg.Cols = 6
fg.Rows = 16
fg.FixedRows = 1
fg.FixedCols = 1
fg.ExtendLastCol = True

fg.TextMatrix(0, 0) = "#"
fg.TextMatrix(0, 1) = "Date"
fg.TextMatrix(0, 2) = "Account"
fg.TextMatrix(0, 3) = "Debit"
fg.TextMatrix(0, 4) = "Credit"
fg.TextMatrix(0, 5) = "Memo"

fg.FixedAlignment(0) = 4
fg.FixedAlignment(1) = 4
fg.FixedAlignment(2) = 4
fg.FixedAlignment(3) = 4
fg.FixedAlignment(4) = 4
fg.FixedAlignment(5) = 4

fg.ColWidth(0) = 600
fg.ColWidth(1) = 1600
fg.ColWidth(2) = 2000
fg.ColWidth(3) = 1800
fg.ColWidth(4) = 1800

fg.ColAlignment(3) = 7  ' right
fg.ColAlignment(4) = 7  ' right

For i = 1 To 15
    fg.TextMatrix(i, 0) = CStr(i)
    fg.TextMatrix(i, 1) = "2025-01-" & Right("0" & CStr(i), 2)
    fg.TextMatrix(i, 2) = "Account-" & CStr(100 + (i Mod 5))
    fg.TextMatrix(i, 3) = CStr(i * 1234)
    fg.TextMatrix(i, 4) = CStr(i * 987)
    fg.TextMatrix(i, 5) = "Entry " & CStr(i)
Next

fg.ColHidden(0) = False

fg.Redraw = True
