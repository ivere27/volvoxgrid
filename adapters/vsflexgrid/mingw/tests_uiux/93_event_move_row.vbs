' Test 93: Before/AfterMoveRow with position override on the second move.
Dim gBeforeMoveRow, gAfterMoveRow
gBeforeMoveRow = 0
gAfterMoveRow = 0

Sub fg_BeforeMoveRow(Row, Position)
    gBeforeMoveRow = gBeforeMoveRow + 1
    If gBeforeMoveRow = 2 Then Position = 1
End Sub

Sub fg_AfterMoveRow(Row, OldPosition)
    gAfterMoveRow = gAfterMoveRow + 1
End Sub

fg.Redraw = False
fg.FontSize = 10
fg.Cols = 3
fg.Rows = 7
fg.FixedRows = 1
fg.FixedCols = 0

fg.TextMatrix(0, 0) = "ID"
fg.TextMatrix(0, 1) = "Name"
fg.TextMatrix(0, 2) = "State"

Dim r7
For r7 = 1 To 6
    fg.TextMatrix(r7, 0) = CStr(r7)
    fg.TextMatrix(r7, 1) = "Row " & CStr(r7)
    fg.TextMatrix(r7, 2) = "Move"
Next

fg.Redraw = True
