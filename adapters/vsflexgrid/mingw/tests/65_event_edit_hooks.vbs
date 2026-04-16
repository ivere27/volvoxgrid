' Test 65: UI event hook pattern for edit and row/col move
' Intended for run_compare_ux.sh with matching .ux actions.

Dim gBeforeEdit, gStartEdit, gAfterEdit, gBeforeRC, gAfterRC, gCellButton
gBeforeEdit = 0
gStartEdit = 0
gAfterEdit = 0
gBeforeRC = 0
gAfterRC = 0
gCellButton = 0

Sub UpdateStats()
    fg.TextMatrix(0, 0) = "BE=" & CStr(gBeforeEdit)
    fg.TextMatrix(0, 1) = "SE=" & CStr(gStartEdit)
    fg.TextMatrix(0, 2) = "AE=" & CStr(gAfterEdit)
    fg.TextMatrix(0, 3) = "BRC=" & CStr(gBeforeRC)
    fg.TextMatrix(0, 4) = "ARC=" & CStr(gAfterRC)
    fg.TextMatrix(0, 5) = "CBC=" & CStr(gCellButton)
End Sub

Sub fg_BeforeEdit(Row, Col, Cancel)
    gBeforeEdit = gBeforeEdit + 1
    UpdateStats
End Sub

Sub fg_AfterEdit(Row, Col)
    gAfterEdit = gAfterEdit + 1
    UpdateStats
End Sub

Sub fg_StartEdit(Row, Col, Cancel)
    gStartEdit = gStartEdit + 1
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

Sub fg_CellButtonClick(Row, Col)
    gCellButton = gCellButton + 1
    UpdateStats
End Sub

fg.Redraw = False
fg.FontSize = 10

fg.Cols = 6
fg.Rows = 9
fg.FixedRows = 1
fg.FixedCols = 0
fg.Editable = True
fg.ColComboList(5) = "..."

Dim r
For r = 1 To 8
    fg.TextMatrix(r, 0) = "R" & CStr(r)
    fg.TextMatrix(r, 1) = "Alpha " & CStr(r)
    fg.TextMatrix(r, 2) = CStr(r * 10)
    fg.TextMatrix(r, 3) = "Ready"
    fg.TextMatrix(r, 4) = "More " & CStr(r)
    fg.TextMatrix(r, 5) = "..."
Next

fg.ColWidth(0) = 900
fg.ColWidth(1) = 1700
fg.ColWidth(2) = 900
fg.ColWidth(3) = 1300
fg.ColWidth(4) = 1100
fg.ColWidth(5) = 900

fg.Row = 2
fg.Col = 1
fg.TopRow = 1
UpdateStats

fg.Redraw = True
