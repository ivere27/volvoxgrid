' Test 32: Scrolled position
' Grid scrolled to TopRow=25, LeftCol=4 with fixed row/col.
fg.FontSize = 10
fg.Cols = 10
fg.Rows = 51
fg.FixedRows = 1
fg.FixedCols = 1

For r = 1 To 50
    fg.TextMatrix(r, 0) = "R" & r
    For c = 1 To 9
        fg.TextMatrix(r, c) = CStr(r * c)
    Next
Next

fg.TopRow = 25
fg.LeftCol = 4
