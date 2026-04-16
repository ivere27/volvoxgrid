' Test 86: Before/AfterSelChange with cancel on the second selection change.
Dim gBeforeSC, gAfterSC
gBeforeSC = 0
gAfterSC = 0

Sub fg_BeforeSelChange(OldRow, OldCol, NewRow, NewCol, Cancel)
    gBeforeSC = gBeforeSC + 1
    If gBeforeSC = 2 Then Cancel = True
End Sub

Sub fg_AfterSelChange(OldRow, OldCol, NewRow, NewCol)
    gAfterSC = gAfterSC + 1
End Sub

fg.Redraw = False
fg.FontSize = 10
fg.Cols = 4
fg.Rows = 6
fg.FixedRows = 1
fg.FixedCols = 0
fg.AllowSelection = True

fg.TextMatrix(0, 0) = "ID"
fg.TextMatrix(0, 1) = "A"
fg.TextMatrix(0, 2) = "B"
fg.TextMatrix(0, 3) = "C"

Dim r2
For r2 = 1 To 5
    fg.TextMatrix(r2, 0) = CStr(r2)
    fg.TextMatrix(r2, 1) = "L" & CStr(r2)
    fg.TextMatrix(r2, 2) = "M" & CStr(r2)
    fg.TextMatrix(r2, 3) = "N" & CStr(r2)
Next

fg.Row = 1
fg.Col = 1
fg.Redraw = True
