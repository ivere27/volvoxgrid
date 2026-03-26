Dim rs
fg.FontSize = 10
Set rs = CreateSqlRecordset(Array("NullInt", "NullStr"), Array(adInteger, adVarChar), Array(0, 16), Array(Array(Null, Null)))
If rs Is Nothing Then
    SetupBoundFallback "SQL Nulls", SqlStatus("Recordset unavailable")
Else
    Set fg.DataSource = rs
End If
