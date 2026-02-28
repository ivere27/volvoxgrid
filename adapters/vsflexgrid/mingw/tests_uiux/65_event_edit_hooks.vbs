' Test 65: UI event hook pattern for edit and row/col move
' Intended for run_compare_ux.sh with matching .ux actions.

Dim gBeforeEdit, gAfterEdit, gBeforeRC, gAfterRC
gBeforeEdit = 0
gAfterEdit = 0
gBeforeRC = 0
gAfterRC = 0

Sub UpdateStats()
    fg.TextMatrix(0, 0) = "BE=" & CStr(gBeforeEdit)
    fg.TextMatrix(0, 1) = "AE=" & CStr(gAfterEdit)
    fg.TextMatrix(0, 2) = "BRC=" & CStr(gBeforeRC)
    fg.TextMatrix(0, 3) = "ARC=" & CStr(gAfterRC)
End Sub

Sub fg_BeforeEdit(Row, Col, Cancel)
    gBeforeEdit = gBeforeEdit + 1
    UpdateStats
End Sub

Sub fg_AfterEdit(Row, Col)
    gAfterEdit = gAfterEdit + 1
    UpdateStats
End Sub

Sub fg_BeforeRowColChange(OldRow, OldCol, NewRow, NewCol, Cancel)
    gBeforeRC = gBeforeRC + 1
    UpdateStats
End Sub

Sub fg_AfterRowColChange(OldRow, OldCol, NewRow, NewCol)
    gAfterRC = gAfterRC + 1
    UpdateStats
End Sub

fg.Redraw = False
fg.FontSize = 10

fg.Cols = 4
fg.Rows = 9
fg.FixedRows = 1
fg.FixedCols = 0
fg.Editable = True

Dim r
For r = 1 To 8
    fg.TextMatrix(r, 0) = "R" & CStr(r)
    fg.TextMatrix(r, 1) = "Alpha " & CStr(r)
    fg.TextMatrix(r, 2) = CStr(r * 10)
    fg.TextMatrix(r, 3) = "Ready"
Next

fg.ColWidth(0) = 900
fg.ColWidth(1) = 1700
fg.ColWidth(2) = 900
fg.ColWidth(3) = 1300

fg.Row = 2
fg.Col = 1
fg.TopRow = 1
UpdateStats

fg.Redraw = True
