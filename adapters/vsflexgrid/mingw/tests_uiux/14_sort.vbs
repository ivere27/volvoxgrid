' Test 14: Sort
' Sort ascending by column 2 (Sales).
fg.FontSize = 10
Call PopulateStandard()
fg.Col = 2
fg.ColSel = 2
fg.Sort = 1    ' flexSortGenericAscending
