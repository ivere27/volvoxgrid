' Test 01: Default baseline
' Standard 5-column grid with 20 data rows, no styling.
fg.FontSize = 10
fg.Cols = 5
fg.Rows = 21
fg.FixedRows = 1
fg.FixedCols = 0

fg.TextMatrix(0, 0) = "Product"
fg.TextMatrix(0, 1) = "Category"
fg.TextMatrix(0, 2) = "Sales"
fg.TextMatrix(0, 3) = "Quarter"
fg.TextMatrix(0, 4) = "Region"

For i = 1 To 20
    fg.TextMatrix(i, 0) = products((i - 1) Mod 5)
    fg.TextMatrix(i, 1) = categories((i - 1) Mod 5)
    fg.TextMatrix(i, 2) = CStr(sales(i - 1))
    fg.TextMatrix(i, 3) = "Q" & ((i - 1) Mod 4) + 1
    fg.TextMatrix(i, 4) = regions((i - 1) Mod 4)
Next
