' Test 06: Column selection
' Select entire column 2 (Sales).
fg.FontSize = 10
Call PopulateStandard()
fg.SelectionMode = 2  ' flexSelectionByColumn
fg.Col = 2
