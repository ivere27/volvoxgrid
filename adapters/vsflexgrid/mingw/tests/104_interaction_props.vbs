' Test 104: ExplorerBar / TabBehavior / AllowUserFreezing compatibility
fg.Redraw = False
fg.FontSize = 10

fg.Cols = 3
fg.Rows = 5
fg.FixedRows = 1
fg.FixedCols = 0

fg.ExplorerBar = 7          ' flexExSortShowAndMove
fg.TabBehavior = 1          ' flexTabCells
fg.AllowUserFreezing = 3    ' flexFreezeBoth

fg.TextMatrix(0, 0) = "Property"
fg.TextMatrix(0, 1) = "Value"
fg.TextMatrix(0, 2) = "SortKey"

fg.TextMatrix(1, 0) = "TabBehavior"
fg.TextMatrix(1, 1) = CStr(fg.TabBehavior)
fg.TextMatrix(1, 2) = "B"

fg.TextMatrix(2, 0) = "ExplorerBar"
fg.TextMatrix(2, 1) = CStr(fg.ExplorerBar)
fg.TextMatrix(2, 2) = "A"

fg.TextMatrix(3, 0) = "AllowUserFreezing"
fg.TextMatrix(3, 1) = CStr(fg.AllowUserFreezing)
fg.TextMatrix(3, 2) = "C"

fg.TextMatrix(4, 0) = "Summary"
fg.TextMatrix(4, 1) = CStr(fg.TabBehavior) & "/" & CStr(fg.ExplorerBar) & "/" & CStr(fg.AllowUserFreezing)
fg.TextMatrix(4, 2) = "D"

fg.ColWidth(0) = 2200
fg.ColWidth(1) = 1200
fg.ColWidth(2) = 1000
fg.BackColorFixed = RGB(214, 228, 245)
fg.ColAlignment(1) = 7

' Sorting with ExplorerBar enabled should show the sort arrow on SortKey.
fg.Col = 2
fg.ColSel = 2
fg.Sort = 1

fg.Redraw = True
