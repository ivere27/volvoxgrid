' Test 50: Wide ERP report — 16 columns with frozen columns
' Mimics ERP monthly summary (module-B): many narrow number cols,
' frozen first 3 columns, scrolled right to show freeze effect.
fg.FontSize = 9
fg.Redraw = False

fg.Cols = 16
fg.Rows = 11
fg.FixedRows = 1
fg.FixedCols = 1

fg.TextMatrix(0, 0) = "#"
fg.TextMatrix(0, 1) = "Code"
fg.TextMatrix(0, 2) = "Name"
fg.TextMatrix(0, 3) = "Jan"
fg.TextMatrix(0, 4) = "Feb"
fg.TextMatrix(0, 5) = "Mar"
fg.TextMatrix(0, 6) = "Apr"
fg.TextMatrix(0, 7) = "May"
fg.TextMatrix(0, 8) = "Jun"
fg.TextMatrix(0, 9) = "Jul"
fg.TextMatrix(0, 10) = "Aug"
fg.TextMatrix(0, 11) = "Sep"
fg.TextMatrix(0, 12) = "Oct"
fg.TextMatrix(0, 13) = "Nov"
fg.TextMatrix(0, 14) = "Dec"
fg.TextMatrix(0, 15) = "Total"

For c = 0 To 15
    fg.FixedAlignment(c) = 4
Next

fg.ColWidth(0) = 500
fg.ColWidth(1) = 1200
fg.ColWidth(2) = 2000
For c = 3 To 15
    fg.ColWidth(c) = 1100
    fg.ColAlignment(c) = 7  ' right
Next

fg.FrozenCols = 2  ' freeze Code+Name alongside fixed col

For i = 1 To 10
    fg.TextMatrix(i, 0) = CStr(i)
    fg.TextMatrix(i, 1) = "C-" & Right("00" & CStr(i), 3)
    fg.TextMatrix(i, 2) = "Customer " & Chr(64 + i)
    Dim total : total = 0
    For m = 3 To 14
        Dim v : v = (i * 100) + (m * 37) Mod 500
        fg.TextMatrix(i, m) = CStr(v)
        total = total + v
    Next
    fg.TextMatrix(i, 15) = CStr(total)
Next

fg.TopRow = 1
fg.LeftCol = 8  ' scroll right to show frozen effect

fg.Redraw = True
