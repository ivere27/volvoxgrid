Dim rs
fg.FontSize = 10
Set rs = CreateSqlRecordset(Array("A"), Array(adInteger), Array(0), Array(Array(3), Array(1), Array(2)))
If rs Is Nothing Then
    SetupBoundFallback "SQL Sort", SqlStatus("Recordset unavailable")
Else
    Set fg.DataSource = rs
    fg.Col = 0
    fg.Sort = 1
End If
