' Test 46: ERP-style ledger layout
' Mimics ERP pattern: FixedCols=1, many columns, hidden ID cols,
' right-aligned numbers, FixedAlignment center, ExtendLastCol,
' Redraw batch, alternate row colors.
fg.FontSize = 10
fg.Redraw = False

fg.Cols = 10
fg.Rows = 13
fg.FixedRows = 1
fg.FixedCols = 1
fg.ExtendLastCol = True
fg.BackColorAlternate = &HF0F0F0

fg.TextMatrix(0, 0) = "#"
fg.TextMatrix(0, 1) = "ID"
fg.TextMatrix(0, 2) = "Date"
fg.TextMatrix(0, 3) = "Customer"
fg.TextMatrix(0, 4) = "Item"
fg.TextMatrix(0, 5) = "Qty"
fg.TextMatrix(0, 6) = "Unit Price"
fg.TextMatrix(0, 7) = "Amount"
fg.TextMatrix(0, 8) = "Tax"
fg.TextMatrix(0, 9) = "Remark"

' Center all fixed header alignment
fg.FixedAlignment(0) = 4
fg.FixedAlignment(1) = 4
fg.FixedAlignment(2) = 4
fg.FixedAlignment(3) = 4
fg.FixedAlignment(4) = 4
fg.FixedAlignment(5) = 4
fg.FixedAlignment(6) = 4
fg.FixedAlignment(7) = 4
fg.FixedAlignment(8) = 4
fg.FixedAlignment(9) = 4

' Hide the internal ID column
fg.ColHidden(1) = True

' Set column widths (twips)
fg.ColWidth(0) = 500
fg.ColWidth(1) = 1200
fg.ColWidth(2) = 1600
fg.ColWidth(3) = 2000
fg.ColWidth(4) = 2000
fg.ColWidth(5) = 1000
fg.ColWidth(6) = 1400
fg.ColWidth(7) = 1600
fg.ColWidth(8) = 1200

' Right-align numeric columns
fg.ColAlignment(5) = 7
fg.ColAlignment(6) = 7
fg.ColAlignment(7) = 7
fg.ColAlignment(8) = 7

' Populate data rows
For i = 1 To 12
    fg.TextMatrix(i, 0) = CStr(i)
    fg.TextMatrix(i, 1) = "INV-" & CStr(10000 + i)
    fg.TextMatrix(i, 2) = "2025-02-" & Right("0" & CStr(i), 2)
    fg.TextMatrix(i, 3) = "Customer " & Chr(64 + ((i - 1) Mod 8) + 1)
    fg.TextMatrix(i, 4) = "Item-" & CStr(200 + (i Mod 6))
    fg.TextMatrix(i, 5) = CStr(i * 3)
    fg.TextMatrix(i, 6) = CStr(500 + (i * 73) Mod 400)
    fg.TextMatrix(i, 7) = CStr((i * 3) * (500 + (i * 73) Mod 400))
    fg.TextMatrix(i, 8) = CStr(Int(((i * 3) * (500 + (i * 73) Mod 400)) * 0.1))
    fg.TextMatrix(i, 9) = ""
Next

fg.Redraw = True
