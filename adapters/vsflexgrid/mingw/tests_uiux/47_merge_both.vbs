' Test 47: Merge both rows and columns simultaneously
' Combined MergeRow + MergeCol on same grid for cross-shaped merges.
fg.FontSize = 10
fg.Cols = 5
fg.Rows = 10
fg.FixedRows = 1
fg.FixedCols = 0
fg.MergeCells = 1  ' flexMergeFree

' Enable column merge on col 0 and col 1
fg.MergeCol(0) = True
fg.MergeCol(1) = True

' Enable row merge on rows 1-9
For i = 1 To 9
    fg.MergeRow(i) = True
Next

fg.TextMatrix(0, 0) = "Region"
fg.TextMatrix(0, 1) = "Type"
fg.TextMatrix(0, 2) = "Q1"
fg.TextMatrix(0, 3) = "Q2"
fg.TextMatrix(0, 4) = "Q3"

' Vertical merge: same region spans rows
fg.TextMatrix(1, 0) = "North"
fg.TextMatrix(2, 0) = "North"
fg.TextMatrix(3, 0) = "North"
fg.TextMatrix(4, 0) = "South"
fg.TextMatrix(5, 0) = "South"
fg.TextMatrix(6, 0) = "East"
fg.TextMatrix(7, 0) = "East"
fg.TextMatrix(8, 0) = "East"
fg.TextMatrix(9, 0) = "East"

' Vertical merge: same type within region
fg.TextMatrix(1, 1) = "Retail"
fg.TextMatrix(2, 1) = "Retail"
fg.TextMatrix(3, 1) = "Wholesale"
fg.TextMatrix(4, 1) = "Retail"
fg.TextMatrix(5, 1) = "Wholesale"
fg.TextMatrix(6, 1) = "Online"
fg.TextMatrix(7, 1) = "Online"
fg.TextMatrix(8, 1) = "Retail"
fg.TextMatrix(9, 1) = "Retail"

' Horizontal merge: same values across Q columns
fg.TextMatrix(1, 2) = "500"
fg.TextMatrix(1, 3) = "500"
fg.TextMatrix(1, 4) = "600"

fg.TextMatrix(2, 2) = "300"
fg.TextMatrix(2, 3) = "400"
fg.TextMatrix(2, 4) = "400"

fg.TextMatrix(3, 2) = "200"
fg.TextMatrix(3, 3) = "200"
fg.TextMatrix(3, 4) = "200"

fg.TextMatrix(4, 2) = "700"
fg.TextMatrix(4, 3) = "800"
fg.TextMatrix(4, 4) = "800"

fg.TextMatrix(5, 2) = "150"
fg.TextMatrix(5, 3) = "150"
fg.TextMatrix(5, 4) = "150"

fg.TextMatrix(6, 2) = "900"
fg.TextMatrix(6, 3) = "900"
fg.TextMatrix(6, 4) = "900"

fg.TextMatrix(7, 2) = "100"
fg.TextMatrix(7, 3) = "200"
fg.TextMatrix(7, 4) = "300"

fg.TextMatrix(8, 2) = "450"
fg.TextMatrix(8, 3) = "450"
fg.TextMatrix(8, 4) = "500"

fg.TextMatrix(9, 2) = "350"
fg.TextMatrix(9, 3) = "350"
fg.TextMatrix(9, 4) = "350"
