' Test 13: Frozen rows and columns
' 2 frozen rows, 1 frozen column. Scrolled to show the effect.
fg.FontSize = 10
Call PopulateStandard()
fg.FrozenRows = 2
fg.FrozenCols = 1
fg.TopRow = 8
fg.LeftCol = 2
