' Test 92: Before/AfterMoveColumn with position override on the second move.
Dim gBeforeMoveCol, gAfterMoveCol
gBeforeMoveCol = 0
gAfterMoveCol = 0

Sub fg_BeforeMoveColumn(Col, Position)
    gBeforeMoveCol = gBeforeMoveCol + 1
    If gBeforeMoveCol = 2 Then Position = 0
End Sub

Sub fg_AfterMoveColumn(Col, OldPosition)
    gAfterMoveCol = gAfterMoveCol + 1
End Sub

fg.Redraw = False
fg.FontSize = 10
fg.Cols = 4
fg.Rows = 5
fg.FixedRows = 1
fg.FixedCols = 0
fg.ExplorerBar = 7

fg.TextMatrix(0, 0) = "C0"
fg.TextMatrix(0, 1) = "C1"
fg.TextMatrix(0, 2) = "C2"
fg.TextMatrix(0, 3) = "C3"

Dim r6
For r6 = 1 To 4
    fg.TextMatrix(r6, 0) = "A" & CStr(r6)
    fg.TextMatrix(r6, 1) = "B" & CStr(r6)
    fg.TextMatrix(r6, 2) = "C" & CStr(r6)
    fg.TextMatrix(r6, 3) = "D" & CStr(r6)
Next

fg.Redraw = True
