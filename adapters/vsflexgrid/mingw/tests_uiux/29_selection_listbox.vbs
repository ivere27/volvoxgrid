' Test 29: Listbox selection mode
' Rows can be toggled individually like a listbox.
fg.FontSize = 10
Call PopulateStandard()
fg.SelectionMode = 3  ' flexSelectionListbox
fg.HighLight = 2      ' flexHighlightAlways
fg.Row = 2
fg.Row = 5
fg.Row = 8
