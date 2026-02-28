' Test 18: Hidden rows and columns
' Hide rows 3, 7 and column 1 (Category).
fg.FontSize = 10
Call PopulateStandard()
fg.RowHidden(3) = True
fg.RowHidden(7) = True
fg.ColHidden(1) = True
