' Test 56: Frozen rows/cols combined with cell merging
' Merge in the frozen zone + merge in scrollable zone.
fg.FontSize = 10
fg.Redraw = False

fg.Cols = 6
fg.Rows = 12
fg.FixedRows = 1
fg.FixedCols = 1
fg.FrozenRows = 1
fg.FrozenCols = 1

fg.MergeCells = 2
fg.MergeCol(1) = True  ' merge on frozen col

fg.TextMatrix(0, 0) = "#"
fg.TextMatrix(0, 1) = "Dept"
fg.TextMatrix(0, 2) = "Name"
fg.TextMatrix(0, 3) = "Q1"
fg.TextMatrix(0, 4) = "Q2"
fg.TextMatrix(0, 5) = "Q3"

fg.TextMatrix(1, 0) = "1"
fg.TextMatrix(1, 1) = "Engineering"
fg.TextMatrix(1, 2) = "Alice"
fg.TextMatrix(1, 3) = "500"
fg.TextMatrix(1, 4) = "600"
fg.TextMatrix(1, 5) = "700"

fg.TextMatrix(2, 0) = "2"
fg.TextMatrix(2, 1) = "Engineering"
fg.TextMatrix(2, 2) = "Bob"
fg.TextMatrix(2, 3) = "400"
fg.TextMatrix(2, 4) = "450"
fg.TextMatrix(2, 5) = "500"

fg.TextMatrix(3, 0) = "3"
fg.TextMatrix(3, 1) = "Engineering"
fg.TextMatrix(3, 2) = "Carol"
fg.TextMatrix(3, 3) = "350"
fg.TextMatrix(3, 4) = "380"
fg.TextMatrix(3, 5) = "420"

fg.TextMatrix(4, 0) = "4"
fg.TextMatrix(4, 1) = "Sales"
fg.TextMatrix(4, 2) = "Dave"
fg.TextMatrix(4, 3) = "800"
fg.TextMatrix(4, 4) = "900"
fg.TextMatrix(4, 5) = "850"

fg.TextMatrix(5, 0) = "5"
fg.TextMatrix(5, 1) = "Sales"
fg.TextMatrix(5, 2) = "Eve"
fg.TextMatrix(5, 3) = "750"
fg.TextMatrix(5, 4) = "780"
fg.TextMatrix(5, 5) = "810"

fg.TextMatrix(6, 0) = "6"
fg.TextMatrix(6, 1) = "Marketing"
fg.TextMatrix(6, 2) = "Frank"
fg.TextMatrix(6, 3) = "300"
fg.TextMatrix(6, 4) = "320"
fg.TextMatrix(6, 5) = "350"

fg.TextMatrix(7, 0) = "7"
fg.TextMatrix(7, 1) = "Marketing"
fg.TextMatrix(7, 2) = "Grace"
fg.TextMatrix(7, 3) = "280"
fg.TextMatrix(7, 4) = "310"
fg.TextMatrix(7, 5) = "330"

fg.TextMatrix(8, 0) = "8"
fg.TextMatrix(8, 1) = "Marketing"
fg.TextMatrix(8, 2) = "Heidi"
fg.TextMatrix(8, 3) = "260"
fg.TextMatrix(8, 4) = "290"
fg.TextMatrix(8, 5) = "310"

fg.TextMatrix(9, 0) = "9"
fg.TextMatrix(9, 1) = "Marketing"
fg.TextMatrix(9, 2) = "Ivan"
fg.TextMatrix(9, 3) = "240"
fg.TextMatrix(9, 4) = "270"
fg.TextMatrix(9, 5) = "300"

fg.TextMatrix(10, 0) = "10"
fg.TextMatrix(10, 1) = "Support"
fg.TextMatrix(10, 2) = "Judy"
fg.TextMatrix(10, 3) = "200"
fg.TextMatrix(10, 4) = "220"
fg.TextMatrix(10, 5) = "250"

fg.TextMatrix(11, 0) = "11"
fg.TextMatrix(11, 1) = "Support"
fg.TextMatrix(11, 2) = "Karl"
fg.TextMatrix(11, 3) = "190"
fg.TextMatrix(11, 4) = "210"
fg.TextMatrix(11, 5) = "230"

fg.TopRow = 5
fg.Redraw = True
