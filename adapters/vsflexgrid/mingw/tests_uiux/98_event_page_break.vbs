' Test 98: BeforePageBreak during PrintGrid.
Dim gBeforePageBreak
gBeforePageBreak = 0

Sub fg_BeforePageBreak(Row, BreakOK)
    gBeforePageBreak = gBeforePageBreak + 1
    If gBeforePageBreak = 1 Then BreakOK = False
End Sub

fg.Redraw = False
fg.FontSize = 10
fg.Cols = 3
fg.Rows = 120
fg.FixedRows = 1
fg.FixedCols = 0

fg.TextMatrix(0, 0) = "ID"
fg.TextMatrix(0, 1) = "Name"
fg.TextMatrix(0, 2) = "Group"

Dim r12
For r12 = 1 To 119
    fg.TextMatrix(r12, 0) = CStr(r12)
    fg.TextMatrix(r12, 1) = "Printable " & CStr(r12)
    fg.TextMatrix(r12, 2) = "G" & CStr((r12 Mod 4) + 1)
Next

fg.Redraw = True
