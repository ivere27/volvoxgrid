' Test 87: Before/AfterEdit with cancel on the second edit attempt.
Dim gBeforeEdit, gAfterEdit
gBeforeEdit = 0
gAfterEdit = 0

Sub fg_BeforeEdit(Row, Col, Cancel)
    gBeforeEdit = gBeforeEdit + 1
    If gBeforeEdit = 2 Then Cancel = True
End Sub

Sub fg_AfterEdit(Row, Col)
    gAfterEdit = gAfterEdit + 1
End Sub

fg.Redraw = False
fg.FontSize = 10
fg.Cols = 3
fg.Rows = 6
fg.FixedRows = 1
fg.FixedCols = 0
fg.Editable = True

fg.TextMatrix(0, 0) = "ID"
fg.TextMatrix(0, 1) = "Value"
fg.TextMatrix(0, 2) = "State"

Dim r3
For r3 = 1 To 5
    fg.TextMatrix(r3, 0) = CStr(r3)
    fg.TextMatrix(r3, 1) = "Item " & CStr(r3)
    fg.TextMatrix(r3, 2) = "Open"
Next

fg.Row = 2
fg.Col = 1
fg.Redraw = True
