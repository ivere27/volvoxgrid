' Test 27: Outline bar styles
' Complete outline bar with green tree color after subtotaling.
fg.FontSize = 10
Call PopulateStandard()
fg.Col = 1
fg.ColSel = 1
fg.Sort = 1   ' sort by Category

fg.Subtotal 5, 1, 2, "Total", RGB(208, 208, 255), vbBlack, True

fg.OutlineBar = 3          ' flexOutlineBarComplete
fg.OutlineCol = 0
fg.TreeColor = vbGreen     ' green (VB constant)
