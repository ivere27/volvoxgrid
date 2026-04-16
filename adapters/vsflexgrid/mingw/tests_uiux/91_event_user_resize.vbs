' Test 91: Before/AfterUserResize probe using deterministic width changes.
Dim gBeforeResize, gAfterResize
gBeforeResize = 0
gAfterResize = 0

Sub fg_BeforeUserResize(Row, Col, Cancel)
    gBeforeResize = gBeforeResize + 1
    If gBeforeResize = 2 Then Cancel = True
End Sub

Sub fg_AfterUserResize(Row, Col)
    gAfterResize = gAfterResize + 1
End Sub

fg.Redraw = False
fg.FontSize = 10
fg.Cols = 4
fg.Rows = 5
fg.FixedRows = 1
fg.FixedCols = 0

fg.TextMatrix(0, 0) = "ID"
fg.TextMatrix(0, 1) = "Wide"
fg.TextMatrix(0, 2) = "Resize"
fg.TextMatrix(0, 3) = "Note"

Dim r9
For r9 = 1 To 4
    fg.TextMatrix(r9, 0) = CStr(r9)
    fg.TextMatrix(r9, 1) = "Alpha " & CStr(r9)
    fg.TextMatrix(r9, 2) = "Beta " & CStr(r9)
    fg.TextMatrix(r9, 3) = "Gamma " & CStr(r9)
Next

fg.ColWidth(1) = 1200
fg.ColWidth(2) = 1200
fg.Redraw = True
