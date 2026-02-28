' Test 55: AllowBigSelection — select entire column
' Click column header selects whole column.
fg.FontSize = 10
Call PopulateStandard()
fg.AllowBigSelection = True
fg.HighLight = 2  ' flexHighlightAlways

' Select entire column 2 by setting range
fg.Select 1, 2, 20, 2
