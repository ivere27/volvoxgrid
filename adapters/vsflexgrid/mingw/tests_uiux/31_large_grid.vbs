' Test 31: Large grid stress test
' 100 rows x 10 columns with fixed row and column headers.
fg.FontSize = 10
fg.Cols = 10
fg.Rows = 101
fg.FixedRows = 1
fg.FixedCols = 1

For c = 0 To 9
    fg.TextMatrix(0, c) = "Col " & c
Next
For r = 1 To 100
    fg.TextMatrix(r, 0) = CStr(r)
    For c = 1 To 9
        fg.TextMatrix(r, c) = CStr(r * 10 + c)
    Next
Next
