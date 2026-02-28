' Test 44: MergeRow — horizontal cell merging
' Repeated values in same row merge horizontally across columns.
fg.FontSize = 10
fg.Cols = 5
fg.Rows = 9
fg.FixedRows = 1
fg.FixedCols = 0
fg.MergeCells = 1  ' flexMergeFree

' Enable merge on all rows
For i = 0 To 8
    fg.MergeRow(i) = True
Next

fg.TextMatrix(0, 0) = "Region"
fg.TextMatrix(0, 1) = "Q1"
fg.TextMatrix(0, 2) = "Q2"
fg.TextMatrix(0, 3) = "Q3"
fg.TextMatrix(0, 4) = "Q4"

' Row 1: all same => merge across entire row
fg.TextMatrix(1, 0) = "North"
fg.TextMatrix(1, 1) = "1200"
fg.TextMatrix(1, 2) = "1200"
fg.TextMatrix(1, 3) = "1200"
fg.TextMatrix(1, 4) = "1200"

' Row 2: Q1-Q2 same, Q3-Q4 same
fg.TextMatrix(2, 0) = "South"
fg.TextMatrix(2, 1) = "800"
fg.TextMatrix(2, 2) = "800"
fg.TextMatrix(2, 3) = "950"
fg.TextMatrix(2, 4) = "950"

' Row 3: no duplicates
fg.TextMatrix(3, 0) = "East"
fg.TextMatrix(3, 1) = "300"
fg.TextMatrix(3, 2) = "450"
fg.TextMatrix(3, 3) = "600"
fg.TextMatrix(3, 4) = "750"

' Row 4: first three same
fg.TextMatrix(4, 0) = "West"
fg.TextMatrix(4, 1) = "500"
fg.TextMatrix(4, 2) = "500"
fg.TextMatrix(4, 3) = "500"
fg.TextMatrix(4, 4) = "700"

' Row 5: last three same
fg.TextMatrix(5, 0) = "Central"
fg.TextMatrix(5, 1) = "400"
fg.TextMatrix(5, 2) = "600"
fg.TextMatrix(5, 3) = "600"
fg.TextMatrix(5, 4) = "600"

' Row 6: alternating
fg.TextMatrix(6, 0) = "NW"
fg.TextMatrix(6, 1) = "100"
fg.TextMatrix(6, 2) = "200"
fg.TextMatrix(6, 3) = "100"
fg.TextMatrix(6, 4) = "200"

' Row 7: pair merge
fg.TextMatrix(7, 0) = "SE"
fg.TextMatrix(7, 1) = "350"
fg.TextMatrix(7, 2) = "350"
fg.TextMatrix(7, 3) = "700"
fg.TextMatrix(7, 4) = "700"

' Row 8: all unique
fg.TextMatrix(8, 0) = "SW"
fg.TextMatrix(8, 1) = "111"
fg.TextMatrix(8, 2) = "222"
fg.TextMatrix(8, 3) = "333"
fg.TextMatrix(8, 4) = "444"
