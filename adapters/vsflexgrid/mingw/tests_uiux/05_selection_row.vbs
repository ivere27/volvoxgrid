' Test 05: Row selection
' Select entire row 3 with always-on highlight.
fg.FontSize = 10
Call PopulateStandard()
fg.SelectionMode = 1  ' flexSelectionByRow
fg.HighLight = 2      ' flexHighlightAlways
fg.Row = 3
