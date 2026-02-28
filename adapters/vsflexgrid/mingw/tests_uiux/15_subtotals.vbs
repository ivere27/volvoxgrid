' Test 15: Subtotals
' Sort by Category, then add average subtotals on Sales column.
fg.FontSize = 10
Call PopulateStandard()
fg.Col = 1
fg.ColSel = 1
fg.Sort = 1   ' sort by col 1 (Category)

fg.Subtotal 5, 1, 2, "Total", RGB(192, 192, 255), vbBlack, True
'   aggregate = 5 (average)
'   group_on  = 1 (Category column)
'   agg_col   = 2 (Sales column)
'   caption   = "Total"
'   back_color, fore_color
'   add_outline = True

fg.OutlineBar = 1  ' flexOutlineBarSimple
fg.OutlineCol = 0
