' Test 88: Before/AfterSort with order override on the second sort.
Dim gBeforeSort, gAfterSort
gBeforeSort = 0
gAfterSort = 0

Sub fg_BeforeSort(Col, Order)
    gBeforeSort = gBeforeSort + 1
    If gBeforeSort = 2 Then Order = 2
End Sub

Sub fg_AfterSort(Col, Order)
    gAfterSort = gAfterSort + 1
End Sub

fg.Redraw = False
fg.FontSize = 10
fg.Cols = 2
fg.Rows = 4
fg.FixedRows = 1
fg.FixedCols = 0

fg.TextMatrix(0, 0) = "ID"
fg.TextMatrix(0, 1) = "Code"

fg.TextMatrix(1, 0) = "1"
fg.TextMatrix(1, 1) = "B"
fg.TextMatrix(2, 0) = "2"
fg.TextMatrix(2, 1) = "A"
fg.TextMatrix(3, 0) = "3"
fg.TextMatrix(3, 1) = "C"

fg.Col = 1
fg.ColSel = 1
fg.Redraw = True
