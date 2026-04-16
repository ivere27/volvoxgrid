' Test 89: Before/AfterCollapse with cancel on the second collapse.
Dim gBeforeCollapse, gAfterCollapse
gBeforeCollapse = 0
gAfterCollapse = 0

Sub fg_BeforeCollapse(Row, State, Cancel)
    gBeforeCollapse = gBeforeCollapse + 1
    If gBeforeCollapse = 2 Then Cancel = True
End Sub

Sub fg_AfterCollapse(Row, State)
    gAfterCollapse = gAfterCollapse + 1
End Sub

fg.FontSize = 10
Call PopulateStandard()
fg.Col = 1
fg.ColSel = 1
fg.Sort = 1
fg.Subtotal 5, 1, 2, "Total", &HC0FFC0, &H000000, 1
fg.OutlineBar = 1
fg.OutlineCol = 0
fg.Row = 2
fg.Col = 1
