' Test 07: Focus rect heavy
' Heavy focus rectangle on cell (5, 1).
fg.FontSize = 10
Call PopulateStandard()
fg.FocusRect = 2      ' flexFocusHeavy
fg.HighLight = 2      ' flexHighlightAlways
fg.Row = 5
fg.Col = 1
