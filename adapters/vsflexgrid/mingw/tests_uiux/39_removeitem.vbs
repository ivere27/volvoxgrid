' Test 39: RemoveItem — delete rows dynamically
' Populate 10 rows via AddItem, then remove rows 3, 5, 7.
fg.FontSize = 10
fg.Cols = 3
fg.Rows = 1
fg.FixedRows = 1

fg.TextMatrix(0, 0) = "Name"
fg.TextMatrix(0, 1) = "Value"
fg.TextMatrix(0, 2) = "Notes"

fg.AddItem "Row1" & vbTab & "100" & vbTab & "Keep"
fg.AddItem "Row2" & vbTab & "200" & vbTab & "Keep"
fg.AddItem "Row3" & vbTab & "300" & vbTab & "Delete"
fg.AddItem "Row4" & vbTab & "400" & vbTab & "Keep"
fg.AddItem "Row5" & vbTab & "500" & vbTab & "Delete"
fg.AddItem "Row6" & vbTab & "600" & vbTab & "Keep"
fg.AddItem "Row7" & vbTab & "700" & vbTab & "Delete"
fg.AddItem "Row8" & vbTab & "800" & vbTab & "Keep"
fg.AddItem "Row9" & vbTab & "900" & vbTab & "Keep"
fg.AddItem "Row10" & vbTab & "1000" & vbTab & "Keep"

' Remove in reverse order to keep indices stable
fg.RemoveItem 7
fg.RemoveItem 5
fg.RemoveItem 3
