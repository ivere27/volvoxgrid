' Test 34: Focus rect inset style
' Inset focus rectangle on cell (4, 2).
fg.FontSize = 10
Call PopulateStandard()
fg.FocusRect = 3      ' flexFocusInset
fg.HighLight = 2      ' flexHighlightAlways
fg.Row = 4
fg.Col = 2
