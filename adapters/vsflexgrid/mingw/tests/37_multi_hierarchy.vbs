' Test 37: Multi-level hierarchy (tree)
' Build nested product/category subtotal hierarchy with complete outline bar.
fg.FontSize = 10
Call PopulateStandard()

' Legacy-compatible sort by Product (column 0)
fg.Col = 0
fg.ColSel = 0
fg.Sort = 1   ' flexSortGenericAscending

fg.SubtotalPosition = 1  ' legacy above

' Level 1 (inner): product subtotals (legacy-compatible caption behavior)
fg.Subtotal 5, 0, 2, "Total", RGB(208, 224, 240), vbBlack, True

' Level 2 (outer): category subtotals
fg.Subtotal 5, 1, 2, "Total", RGB(216, 255, 216), vbBlack, True

fg.OutlineBar = 3         ' flexOutlineBarComplete
fg.OutlineCol = 0
fg.TreeColor = RGB(0, 128, 0)
