' Test 54: Three-level subtotal hierarchy
' Mimics ERP module-A: sub → mid → grand total.
' Sort by product then region, subtotal at 3 levels.
fg.FontSize = 10
Call PopulateStandard()

' Sort by Region (col 4) then Product (col 0) for grouping
fg.Col = 4
fg.ColSel = 4
fg.Sort = 1
fg.Col = 0
fg.ColSel = 0
fg.Sort = 1

' Level 1: subtotal by Product (innermost)
fg.Subtotal 5, 0, 2, "Prod Total", &HFFE0D0, &H000000, 1

' Level 2: subtotal by Region (outer group)
fg.Subtotal 5, 4, 2, "Region Total", &HD0FFD0, &H000000, 1

' Level 3: grand total
fg.Subtotal 5, -1, 2, "Grand Total", &HD0D0FF, &H000000, 1

fg.OutlineBar = 3  ' flexOutlineBarComplete
fg.OutlineCol = 0
fg.TreeColor = &H008000&
