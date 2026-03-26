Dim rs
fg.FontSize = 10
Set rs = CreateSqlRecordset(Array("A"), Array(adVarChar), Array(32), Array(Array("Should Remain")))
If rs Is Nothing Then
    SetupBoundFallback "SQL Unbind", SqlStatus("Recordset unavailable")
Else
    Set fg.DataSource = rs
    Set fg.DataSource = Nothing
End If
