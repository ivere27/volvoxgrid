' Test 63: ColFormat and ColEditMask numeric patterns
' Mirrors ERP format/edit-mask setup from grid.vbs helpers.
fg.Redraw = False
fg.FontSize = 10

fg.Cols = 5
fg.Rows = 11
fg.FixedRows = 1
fg.FixedCols = 1

fg.TextMatrix(0, 0) = "#"
fg.TextMatrix(0, 1) = "Qty"
fg.TextMatrix(0, 2) = "UnitPrice"
fg.TextMatrix(0, 3) = "Amount"
fg.TextMatrix(0, 4) = "Rate"

fg.ColWidth(0) = 600
fg.ColWidth(1) = 1100
fg.ColWidth(2) = 1400
fg.ColWidth(3) = 1500
fg.ColWidth(4) = 1200

fg.ColAlignment(1) = 7
fg.ColAlignment(2) = 7
fg.ColAlignment(3) = 7
fg.ColAlignment(4) = 7

On Error Resume Next
fg.ColFormat(1) = "#,##0"
fg.ColFormat(2) = "#,##0.00"
fg.ColFormat(3) = "#,##0.00"
fg.ColFormat(4) = "0.000"

fg.ColEditMask(1) = "###,###,##0"
fg.ColEditMask(2) = "###,###,##0.00"
fg.ColEditMask(3) = "###,###,##0.00"
fg.ColEditMask(4) = "0.000"
On Error Goto 0

Dim i, q, p
For i = 1 To 10
    q = (i * 3) + 7
    p = 123.45 + (i * 11.1)
    fg.TextMatrix(i, 0) = CStr(i)
    fg.TextMatrix(i, 1) = CStr(q)
    fg.TextMatrix(i, 2) = CStr(p)
    fg.TextMatrix(i, 3) = CStr(q * p)
    fg.TextMatrix(i, 4) = CStr((i * 37) / 1000)
Next

fg.TopRow = 1
fg.Redraw = True
