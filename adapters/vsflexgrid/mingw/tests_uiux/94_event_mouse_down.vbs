' Test 94: BeforeMouseDown with cancel on the first click.
Dim gBeforeMouseDown
gBeforeMouseDown = 0

Sub fg_BeforeMouseDown(Button, Shift, X, Y, Cancel)
    gBeforeMouseDown = gBeforeMouseDown + 1
    If gBeforeMouseDown = 1 Then Cancel = True
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

Dim r8
For r8 = 1 To 5
    fg.TextMatrix(r8, 0) = CStr(r8)
    fg.TextMatrix(r8, 1) = "Row " & CStr(r8)
    fg.TextMatrix(r8, 2) = "Click"
Next

fg.Row = 1
fg.Col = 1
fg.Redraw = True
