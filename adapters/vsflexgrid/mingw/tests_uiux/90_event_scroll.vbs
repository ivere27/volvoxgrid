' Test 90: Before/AfterScroll with cancel on the second scroll change.
Dim gBeforeScroll, gAfterScroll
gBeforeScroll = 0
gAfterScroll = 0

Sub fg_BeforeScroll(OldTopRow, OldLeftCol, NewTopRow, NewLeftCol, Cancel)
    gBeforeScroll = gBeforeScroll + 1
    If gBeforeScroll = 2 Then Cancel = True
End Sub

Sub fg_AfterScroll(OldTopRow, OldLeftCol, NewTopRow, NewLeftCol)
    gAfterScroll = gAfterScroll + 1
End Sub

fg.Redraw = False
fg.FontSize = 10
fg.Cols = 3
fg.Rows = 24
fg.FixedRows = 1
fg.FixedCols = 0

fg.TextMatrix(0, 0) = "ID"
fg.TextMatrix(0, 1) = "Name"
fg.TextMatrix(0, 2) = "Note"

Dim r4
For r4 = 1 To 23
    fg.TextMatrix(r4, 0) = CStr(r4)
    fg.TextMatrix(r4, 1) = "Item " & CStr(r4)
    fg.TextMatrix(r4, 2) = "Scroll"
Next

fg.TopRow = 1
fg.Row = 1
fg.Col = 1
fg.Redraw = True
