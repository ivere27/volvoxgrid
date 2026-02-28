' Test 38: AutoSize columns to fit content
' Columns auto-sized after populating variable-length data.
fg.FontSize = 10
fg.Cols = 4
fg.Rows = 8
fg.FixedRows = 1
fg.FixedCols = 0

fg.TextMatrix(0, 0) = "ID"
fg.TextMatrix(0, 1) = "Name"
fg.TextMatrix(0, 2) = "Description"
fg.TextMatrix(0, 3) = "Qty"

fg.TextMatrix(1, 0) = "1"
fg.TextMatrix(1, 1) = "A"
fg.TextMatrix(1, 2) = "Short"
fg.TextMatrix(1, 3) = "5"

fg.TextMatrix(2, 0) = "2"
fg.TextMatrix(2, 1) = "Beta Component"
fg.TextMatrix(2, 2) = "A moderately long description"
fg.TextMatrix(2, 3) = "123"

fg.TextMatrix(3, 0) = "3"
fg.TextMatrix(3, 1) = "Gamma Industrial System"
fg.TextMatrix(3, 2) = "Very long product description that needs space"
fg.TextMatrix(3, 3) = "42"

fg.TextMatrix(4, 0) = "100"
fg.TextMatrix(4, 1) = "D"
fg.TextMatrix(4, 2) = "X"
fg.TextMatrix(4, 3) = "9999"

fg.TextMatrix(5, 0) = "5"
fg.TextMatrix(5, 1) = "Epsilon Widget Pro"
fg.TextMatrix(5, 2) = "Medium length"
fg.TextMatrix(5, 3) = "7"

fg.TextMatrix(6, 0) = "6"
fg.TextMatrix(6, 1) = "F"
fg.TextMatrix(6, 2) = "Another description line"
fg.TextMatrix(6, 3) = "88"

fg.TextMatrix(7, 0) = "7"
fg.TextMatrix(7, 1) = "G"
fg.TextMatrix(7, 2) = "OK"
fg.TextMatrix(7, 3) = "1"

fg.AutoSize 0, 3, 0, 0
