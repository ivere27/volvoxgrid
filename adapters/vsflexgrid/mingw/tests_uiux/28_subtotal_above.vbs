' Test 28: SubtotalPosition mapping
' ActiveX ADO maps 0 to below and 1 to above.
fg.FontSize = 10
Call PopulateStandard()
fg.SubtotalPosition = 1  ' legacy above

fg.Col = 1
fg.ColSel = 1
fg.Sort = 1   ' sort by Category
fg.Subtotal 5, 1, 2, "Total", RGB(192, 255, 192), vbBlack, True

fg.OutlineBar = 1  ' flexOutlineBarSimple
fg.OutlineCol = 0
