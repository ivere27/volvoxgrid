' Test 42: Clear and repopulate
' Fill grid, clear it, then repopulate with different data.
fg.FontSize = 10
fg.Cols = 4
fg.Rows = 8
fg.FixedRows = 1
fg.FixedCols = 0

' First fill (this data gets cleared)
fg.TextMatrix(0, 0) = "Old A"
fg.TextMatrix(0, 1) = "Old B"
fg.TextMatrix(0, 2) = "Old C"
fg.TextMatrix(0, 3) = "Old D"
For i = 1 To 7
    fg.TextMatrix(i, 0) = "OldData"
    fg.TextMatrix(i, 1) = CStr(i * 111)
    fg.TextMatrix(i, 2) = "Remove"
    fg.TextMatrix(i, 3) = "X"
Next

' Clear all
fg.Clear 0, 0

' Repopulate with new structure
fg.Rows = 6
fg.Cols = 3
fg.TextMatrix(0, 0) = "Code"
fg.TextMatrix(0, 1) = "Description"
fg.TextMatrix(0, 2) = "Amount"

fg.TextMatrix(1, 0) = "A001"
fg.TextMatrix(1, 1) = "Fresh item alpha"
fg.TextMatrix(1, 2) = "1500"

fg.TextMatrix(2, 0) = "B002"
fg.TextMatrix(2, 1) = "Fresh item beta"
fg.TextMatrix(2, 2) = "2300"

fg.TextMatrix(3, 0) = "C003"
fg.TextMatrix(3, 1) = "Fresh item gamma"
fg.TextMatrix(3, 2) = "870"

fg.TextMatrix(4, 0) = "D004"
fg.TextMatrix(4, 1) = "Fresh item delta"
fg.TextMatrix(4, 2) = "4100"

fg.TextMatrix(5, 0) = "E005"
fg.TextMatrix(5, 1) = "Fresh item epsilon"
fg.TextMatrix(5, 2) = "560"
