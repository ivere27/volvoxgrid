' Test 16: Checkboxes
' Legacy manual:
'   FlexDTBoolean = 11
'   FlexChecked = 1
'   FlexUnchecked = 2
fg.FontSize = 10
fg.Cols = 3
fg.Rows = 8
fg.FixedRows = 1

fg.TextMatrix(0, 0) = "Task"
fg.TextMatrix(0, 1) = "Priority"
fg.TextMatrix(0, 2) = "Done"

fg.ColDataType(2) = 11

fg.TextMatrix(1, 0) = "Design"
fg.TextMatrix(1, 1) = "High"
fg.Row = 1: fg.Col = 2: fg.CellChecked = 1

fg.TextMatrix(2, 0) = "Implement"
fg.TextMatrix(2, 1) = "High"
fg.Row = 2: fg.Col = 2: fg.CellChecked = 1

fg.TextMatrix(3, 0) = "Test"
fg.TextMatrix(3, 1) = "Medium"
fg.Row = 3: fg.Col = 2: fg.CellChecked = 2

fg.TextMatrix(4, 0) = "Review"
fg.TextMatrix(4, 1) = "Medium"
fg.Row = 4: fg.Col = 2: fg.CellChecked = 2

fg.TextMatrix(5, 0) = "Deploy"
fg.TextMatrix(5, 1) = "Low"
fg.Row = 5: fg.Col = 2: fg.CellChecked = 1

fg.TextMatrix(6, 0) = "Monitor"
fg.TextMatrix(6, 1) = "Low"
fg.Row = 6: fg.Col = 2: fg.CellChecked = 2

fg.TextMatrix(7, 0) = "Document"
fg.TextMatrix(7, 1) = "Low"
fg.Row = 7: fg.Col = 2: fg.CellChecked = 2
