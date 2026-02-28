' Test 45: Sort descending
' Sort by Sales column in descending order (flexSortGenericDescending=2).
fg.FontSize = 10
Call PopulateStandard()
fg.Col = 2
fg.ColSel = 2
fg.Sort = 2   ' flexSortGenericDescending
