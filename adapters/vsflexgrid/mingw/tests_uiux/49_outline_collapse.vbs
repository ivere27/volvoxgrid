' Test 49: Outline collapse — fold subtotal groups
' Create subtotals then collapse specific groups via IsCollapsed.
fg.FontSize = 10
Call PopulateStandard()
fg.Col = 1
fg.ColSel = 1
fg.Sort = 1  ' flexSortGenericAscending

fg.Subtotal 5, 1, 2, "Total", &HC0FFC0, &H000000, 1
fg.OutlineBar = 1
fg.OutlineCol = 0

' Collapse the first two groups
fg.IsCollapsed(2) = 2
fg.IsCollapsed(7) = 2
