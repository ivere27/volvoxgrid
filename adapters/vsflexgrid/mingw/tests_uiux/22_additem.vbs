' Test 22: AddItem method
' Dynamically add rows with tab-separated fields.
fg.FontSize = 10
fg.Cols = 3
fg.Rows = 1
fg.FixedRows = 1

fg.TextMatrix(0, 0) = "Name"
fg.TextMatrix(0, 1) = "Value"
fg.TextMatrix(0, 2) = "Notes"

fg.AddItem "Alpha"   & vbTab & "100" & vbTab & "First"
fg.AddItem "Beta"    & vbTab & "200" & vbTab & "Second"
fg.AddItem "Gamma"   & vbTab & "300" & vbTab & "Third"
fg.AddItem "Delta"   & vbTab & "400" & vbTab & "Fourth"
fg.AddItem "Epsilon" & vbTab & "500" & vbTab & "Fifth"
