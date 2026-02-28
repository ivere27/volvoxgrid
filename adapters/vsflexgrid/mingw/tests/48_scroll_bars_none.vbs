' Test 48: ScrollBars = 0 (none)
' Disable all scroll bars on a grid with more data than fits.
fg.FontSize = 10
Call PopulateStandard()
fg.ScrollBars = 0  ' flexScrollBarNone
