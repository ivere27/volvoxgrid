' Test 96: BeforeScrollTip updates ScrollTipText during interactive scrolling.
Dim gBeforeScrollTip
gBeforeScrollTip = 0

Sub fg_BeforeScrollTip(Row)
    gBeforeScrollTip = gBeforeScrollTip + 1
    fg.ScrollTipText = "Top row " & CStr(Row)
End Sub

fg.Redraw = False
fg.FontSize = 10
fg.Cols = 3
fg.Rows = 40
fg.FixedRows = 1
fg.FixedCols = 0
fg.ScrollTips = True

fg.TextMatrix(0, 0) = "ID"
fg.TextMatrix(0, 1) = "Name"
fg.TextMatrix(0, 2) = "Note"

Dim r10
For r10 = 1 To 39
    fg.TextMatrix(r10, 0) = CStr(r10)
    fg.TextMatrix(r10, 1) = "Item " & CStr(r10)
    fg.TextMatrix(r10, 2) = "Scroll tip"
Next

fg.TopRow = 1
fg.Row = 1
fg.Col = 1
fg.Redraw = True
