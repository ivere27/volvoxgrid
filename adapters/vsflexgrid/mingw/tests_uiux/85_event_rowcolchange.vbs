' Test 85: Before/AfterRowColChange with cancel on the second move.
Dim gBeforeRC, gAfterRC
gBeforeRC = 0
gAfterRC = 0

Sub fg_BeforeRowColChange(OldRow, OldCol, NewRow, NewCol, Cancel)
    gBeforeRC = gBeforeRC + 1
    If gBeforeRC = 2 Then Cancel = True
End Sub

Sub fg_AfterRowColChange(OldRow, OldCol, NewRow, NewCol)
    gAfterRC = gAfterRC + 1
End Sub

fg.Redraw = False
fg.FontSize = 10
fg.Cols = 3
fg.Rows = 6
fg.FixedRows = 1
fg.FixedCols = 0

fg.TextMatrix(0, 0) = "ID"
fg.TextMatrix(0, 1) = "Name"
fg.TextMatrix(0, 2) = "State"

Dim r
For r = 1 To 5
    fg.TextMatrix(r, 0) = CStr(r)
    fg.TextMatrix(r, 1) = "Row " & CStr(r)
    fg.TextMatrix(r, 2) = "Ready"
Next

fg.Row = 1
fg.Col = 1
fg.Redraw = True
