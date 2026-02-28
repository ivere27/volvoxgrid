' Test 60: Column ComboList patterns
' Mirrors ERP usage of ColComboList and combo-style columns.
fg.Redraw = False
fg.FontSize = 10

fg.Cols = 4
fg.Rows = 10
fg.FixedRows = 1
fg.FixedCols = 0

fg.TextMatrix(0, 0) = "DocNo"
fg.TextMatrix(0, 1) = "Region"
fg.TextMatrix(0, 2) = "PayType"
fg.TextMatrix(0, 3) = "Finder"

fg.ColComboList(1) = "North|South|East|West"
fg.ColComboList(2) = "Cash|Card|Transfer|Voucher"
fg.ColComboList(3) = "..."

Dim regionVals, payVals
regionVals = Array("North", "South", "East", "West")
payVals = Array("Cash", "Card", "Transfer", "Voucher")

Dim i
For i = 1 To 9
    fg.TextMatrix(i, 0) = "DOC-" & Right("00" & CStr(i), 3)
    fg.TextMatrix(i, 1) = regionVals((i - 1) Mod 4)
    fg.TextMatrix(i, 2) = payVals((i - 1) Mod 4)
    fg.TextMatrix(i, 3) = "..."
Next

fg.ColWidth(0) = 1200
fg.ColWidth(1) = 1600
fg.ColWidth(2) = 1600
fg.ColWidth(3) = 900

fg.Editable = True
fg.Row = 2
fg.Col = 1
fg.TopRow = 1

fg.Redraw = True
