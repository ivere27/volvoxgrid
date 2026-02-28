' Test 20: Ellipsis
' Narrow columns with long text — shows "..." truncation.
fg.FontSize = 10
fg.Cols = 3
fg.Rows = 6
fg.FixedRows = 1
fg.Ellipsis = 1  ' flexEllipsisEnd

fg.ColWidth(0) = 900   ' ~60px
fg.ColWidth(1) = 1200  ' ~80px
fg.ColWidth(2) = 600   ' ~40px

fg.TextMatrix(0, 0) = "Name"
fg.TextMatrix(0, 1) = "Description"
fg.TextMatrix(0, 2) = "ID"
fg.TextMatrix(1, 0) = "A very long product name that overflows"
fg.TextMatrix(1, 1) = "This description is extremely long and should be truncated"
fg.TextMatrix(1, 2) = "ID-12345678"
fg.TextMatrix(2, 0) = "Widget B"
fg.TextMatrix(2, 1) = "Short"
fg.TextMatrix(2, 2) = "ID-2"
fg.TextMatrix(3, 0) = "Another extremely long product name for testing"
fg.TextMatrix(3, 1) = "Medium length description text here"
fg.TextMatrix(3, 2) = "ID-9876543210"
fg.TextMatrix(4, 0) = "Gadget"
fg.TextMatrix(4, 1) = "Very very very long description that should definitely show ellipsis at the end"
fg.TextMatrix(4, 2) = "ID-42"
fg.TextMatrix(5, 0) = "OK"
fg.TextMatrix(5, 1) = "OK"
fg.TextMatrix(5, 2) = "OK"
