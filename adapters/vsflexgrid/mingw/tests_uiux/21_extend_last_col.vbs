' Test 21: Extend last column
' Last column stretches to fill remaining viewport width.
fg.FontSize = 10
Call PopulateStandard()
fg.ExtendLastCol = True
fg.ColWidth(0) = 1200  ' ~80px
fg.ColWidth(1) = 1200  ' ~80px
fg.ColWidth(2) = 900   ' ~60px
fg.ColWidth(3) = 900   ' ~60px
