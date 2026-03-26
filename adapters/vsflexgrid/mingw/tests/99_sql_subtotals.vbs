Dim rs
fg.FontSize = 10
Set rs = CreateSqlRecordset(Array("G", "V"), Array(adVarChar, adInteger), Array(16, 0), Array(Array("Group1", 10), Array("Group1", 20), Array("Group2", 30)))
If rs Is Nothing Then
    SetupBoundFallback "SQL Total", SqlStatus("Recordset unavailable")
Else
    Set fg.DataSource = rs
    fg.Subtotal 2, 0, 1
End If
