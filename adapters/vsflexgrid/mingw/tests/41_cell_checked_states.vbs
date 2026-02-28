' Test 41: CellChecked — all checkbox states across multiple columns
' Tests checked, unchecked, and grayed states in different columns.
fg.FontSize = 10
fg.Cols = 5
fg.Rows = 8
fg.FixedRows = 1
fg.FixedCols = 0
fg.FocusRect = 0
fg.HighLight = 0

fg.TextMatrix(0, 0) = "Item"
fg.TextMatrix(0, 1) = "Active"
fg.TextMatrix(0, 2) = "Verified"
fg.TextMatrix(0, 3) = "Shipped"
fg.TextMatrix(0, 4) = "Notes"

fg.TextMatrix(1, 0) = "Order A"
SetCellChecked 1, 1, 1   ' checked
SetCellChecked 1, 2, 1   ' checked
SetCellChecked 1, 3, 1   ' checked
fg.TextMatrix(1, 4) = "All done"

fg.TextMatrix(2, 0) = "Order B"
SetCellChecked 2, 1, 1   ' checked
SetCellChecked 2, 2, 1   ' checked
SetCellChecked 2, 3, 2   ' unchecked
fg.TextMatrix(2, 4) = "Pending ship"

fg.TextMatrix(3, 0) = "Order C"
SetCellChecked 3, 1, 1   ' checked
SetCellChecked 3, 2, 2   ' unchecked
SetCellChecked 3, 3, 2   ' unchecked
fg.TextMatrix(3, 4) = "Needs verify"

fg.TextMatrix(4, 0) = "Order D"
SetCellChecked 4, 1, 2   ' unchecked
SetCellChecked 4, 2, 2   ' unchecked
SetCellChecked 4, 3, 2   ' unchecked
fg.TextMatrix(4, 4) = "New order"

fg.TextMatrix(5, 0) = "Order E"
SetCellChecked 5, 1, 1
SetCellChecked 5, 2, 2
SetCellChecked 5, 3, 1
fg.TextMatrix(5, 4) = "Partial"

fg.TextMatrix(6, 0) = "Order F"
SetCellChecked 6, 1, 2
SetCellChecked 6, 2, 1
SetCellChecked 6, 3, 2
fg.TextMatrix(6, 4) = "Mixed"

fg.TextMatrix(7, 0) = "Order G"
SetCellChecked 7, 1, 1
SetCellChecked 7, 2, 1
SetCellChecked 7, 3, 2
fg.TextMatrix(7, 4) = "Almost"
