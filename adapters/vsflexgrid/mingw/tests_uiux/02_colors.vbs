' Test 02: Colors
' Custom colors for background, text, grid, fixed area, selection.
' Demonstrates mixed color formats: hex, VB constants, RGB() function.
fg.FontSize = 10
Call PopulateStandard()
fg.BackColor = RGB(224, 224, 255)    ' light blue background (RGB function)
fg.ForeColor = vbNavy                ' navy text (VB constant)
fg.GridColor = &H808080              ' gray grid lines (hex OLE_COLOR)
fg.BackColorFixed = RGB(64, 64, 192) ' blue fixed headers (RGB function)
fg.ForeColorFixed = vbWhite          ' white fixed text (VB constant)
fg.BackColorSel = &H0080FF           ' orange selection (hex OLE_COLOR)
fg.ForeColorSel = RGB(255, 255, 255) ' white selection text (RGB function)
