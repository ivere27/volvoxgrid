' Test 97: AfterUserFreeze after dragging the frozen column separator.
Dim gAfterUserFreeze
gAfterUserFreeze = 0

Sub fg_AfterUserFreeze()
    gAfterUserFreeze = gAfterUserFreeze + 1
End Sub

fg.Redraw = False
fg.FontSize = 10
fg.Cols = 6
fg.Rows = 8
fg.FixedRows = 1
fg.FixedCols = 1
fg.AllowUserFreezing = 1
fg.FrozenCols = 1

fg.TextMatrix(0, 0) = "Key"
fg.TextMatrix(0, 1) = "A"
fg.TextMatrix(0, 2) = "B"
fg.TextMatrix(0, 3) = "C"
fg.TextMatrix(0, 4) = "D"
fg.TextMatrix(0, 5) = "E"

Dim r11, c11
For r11 = 1 To 7
    fg.TextMatrix(r11, 0) = "R" & CStr(r11)
    For c11 = 1 To 5
        fg.TextMatrix(r11, c11) = "C" & CStr(c11) & "-" & CStr(r11)
    Next
Next

fg.Row = 1
fg.Col = 1
fg.Redraw = True
