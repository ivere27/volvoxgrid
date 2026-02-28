' Test 59: ERP row-state marks with hidden delete row
' Mimics ERP save marks: I(insert), U(update), D(delete), blank(saved).
fg.Redraw = False
fg.FontSize = 10

fg.Cols = 5
fg.Rows = 1
fg.FixedRows = 1
fg.FixedCols = 0

fg.TextMatrix(0, 0) = "State"
fg.TextMatrix(0, 1) = "Code"
fg.TextMatrix(0, 2) = "Name"
fg.TextMatrix(0, 3) = "Qty"
fg.TextMatrix(0, 4) = "Remark"

fg.AddItem "I" & vbTab & "A-001" & vbTab & "Rose"   & vbTab & "12" & vbTab & "Inserted"
fg.AddItem "U" & vbTab & "A-002" & vbTab & "Tulip"  & vbTab & "35" & vbTab & "Updated"
fg.AddItem "D" & vbTab & "A-003" & vbTab & "Lily"   & vbTab & "20" & vbTab & "Deleted(hidden)"
fg.AddItem ""  & vbTab & "A-004" & vbTab & "Orchid" & vbTab & "44" & vbTab & "Saved"

fg.RowData(1) = "SAVE"
fg.RowData(2) = "SAVE"
fg.RowData(3) = "SAVE"
fg.RowData(4) = "SAVE"

fg.RowHidden(3) = True

fg.ColWidth(0) = 700
fg.ColWidth(1) = 1300
fg.ColWidth(2) = 1800
fg.ColWidth(3) = 1000
fg.ColWidth(4) = 2300
fg.ColAlignment(3) = 7

' Highlight mark column and move viewport to first data row.
fg.Cell(6, fg.FixedRows, 0, fg.Rows - 1, 0) = RGB(235, 245, 255)
fg.TopRow = 1
fg.Row = 2
fg.Col = 2

fg.Redraw = True
