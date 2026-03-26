' Test 02: Colors
' Custom colors for background, text, grid, fixed area, selection.
fg.FontSize = 10
Call PopulateStandard()
fg.BackColor = RGB(224, 224, 255)
fg.ForeColor = vbNavy
fg.GridColor = RGB(128, 128, 128)
fg.BackColorFixed = RGB(64, 64, 192)
fg.ForeColorFixed = vbWhite
fg.BackColorSel = RGB(255, 128, 0)
fg.ForeColorSel = RGB(255, 255, 255)
