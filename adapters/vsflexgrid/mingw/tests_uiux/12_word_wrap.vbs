' Test 12: Word wrap
' Long text wraps within cells. Row heights set to 900 twips (~60px).
fg.FontSize = 10
fg.Cols = 3
fg.Rows = 6
fg.FixedRows = 1
fg.WordWrap = True

For i = 1 To 5
    fg.RowHeight(i) = 900  ' ~60px
Next

fg.TextMatrix(0, 0) = "Item"
fg.TextMatrix(0, 1) = "Description"
fg.TextMatrix(0, 2) = "Status"

fg.TextMatrix(1, 0) = "Widget A"
fg.TextMatrix(1, 1) = "This is a long description that should " & _
    "wrap to multiple lines within the cell."
fg.TextMatrix(1, 2) = "Active"

fg.TextMatrix(2, 0) = "Gadget X"
fg.TextMatrix(2, 1) = "Another description with enough text " & _
    "to test word wrapping behavior."
fg.TextMatrix(2, 2) = "Pending"

fg.TextMatrix(3, 0) = "Tool Z"
fg.TextMatrix(3, 1) = "Short text"
fg.TextMatrix(3, 2) = "Done"

fg.TextMatrix(4, 0) = "Part B"
fg.TextMatrix(4, 1) = "Medium length text that might wrap on narrow columns but not wide ones"
fg.TextMatrix(4, 2) = "Review"

fg.TextMatrix(5, 0) = "Unit C"
fg.TextMatrix(5, 1) = "Testing word wrap with multiple sentences. This cell has even more text to verify the wrapping continues properly."
fg.TextMatrix(5, 2) = "Active"
