Dim rs
fg.FontSize = 10
Set rs = CreateSqlRecordset(Array("A", "B"), Array(adInteger, adInteger), Array(0, 0), Array(Array(1, 2), Array(3, 4)))
If rs Is Nothing Then
    SetupBoundFallback "SQL DM1", SqlStatus("Recordset unavailable")
Else
    fg.DataMode = 1
    Set fg.DataSource = rs
End If
