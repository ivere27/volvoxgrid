' Test 23: Range selection
' Select a rectangular range using the Select method.
fg.FontSize = 10
Call PopulateStandard()
fg.HighLight = 2  ' flexHighlightAlways
fg.Select 3, 1, 7, 3  ' rows 3-7, cols 1-3
