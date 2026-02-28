' Test 51: Many hidden columns — ERP data storage pattern
' 12 columns total, 5 hidden (internal IDs), 7 visible.
' Mimics ERP pattern of storing FK/lookup IDs in hidden cols.
fg.FontSize = 10
fg.Redraw = False

fg.Cols = 12
fg.Rows = 8
fg.FixedRows = 1
fg.FixedCols = 1

fg.TextMatrix(0, 0) = "#"
fg.TextMatrix(0, 1) = "ORG_ID"
fg.TextMatrix(0, 2) = "Date"
fg.TextMatrix(0, 3) = "CUST_ID"
fg.TextMatrix(0, 4) = "Customer"
fg.TextMatrix(0, 5) = "ITEM_ID"
fg.TextMatrix(0, 6) = "Item"
fg.TextMatrix(0, 7) = "Qty"
fg.TextMatrix(0, 8) = "Amount"
fg.TextMatrix(0, 9) = "RATE_ID"
fg.TextMatrix(0, 10) = "STATUS_CD"
fg.TextMatrix(0, 11) = "Memo"

' Hide internal ID columns
fg.ColHidden(1) = True   ' ORG_ID
fg.ColHidden(3) = True   ' CUST_ID
fg.ColHidden(5) = True   ' ITEM_ID
fg.ColHidden(9) = True   ' RATE_ID
fg.ColHidden(10) = True  ' STATUS_CD

fg.ColWidth(0) = 500
fg.ColWidth(2) = 1600
fg.ColWidth(4) = 2000
fg.ColWidth(6) = 2000
fg.ColWidth(7) = 1000
fg.ColWidth(8) = 1600
fg.ColWidth(11) = 2400

fg.ColAlignment(7) = 7
fg.ColAlignment(8) = 7
fg.ExtendLastCol = True

For i = 1 To 7
    fg.TextMatrix(i, 0) = CStr(i)
    fg.TextMatrix(i, 1) = "ORG001"
    fg.TextMatrix(i, 2) = "2025-03-" & Right("0" & CStr(i + 10), 2)
    fg.TextMatrix(i, 3) = "C" & CStr(100 + i)
    fg.TextMatrix(i, 4) = "Customer " & Chr(64 + i)
    fg.TextMatrix(i, 5) = "ITM" & CStr(200 + i)
    fg.TextMatrix(i, 6) = "Product " & Chr(64 + i)
    fg.TextMatrix(i, 7) = CStr(i * 5)
    fg.TextMatrix(i, 8) = CStr(i * 5 * 1250)
    fg.TextMatrix(i, 9) = "R0" & CStr(i Mod 3)
    fg.TextMatrix(i, 10) = "A"
    fg.TextMatrix(i, 11) = ""
Next

fg.Redraw = True
