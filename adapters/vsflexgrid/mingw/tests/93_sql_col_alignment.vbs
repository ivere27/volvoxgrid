Dim rs
fg.FontSize = 10
Set rs = CreateSqlRecordset(Array("IntVal", "StrVal", "BitVal"), Array(adInteger, adVarChar, adBoolean), Array(0, 16, 0), Array(Array(1, "Str", True)))
If rs Is Nothing Then
    SetupBoundFallback "SQL Align", SqlStatus("Recordset unavailable")
Else
    Set fg.DataSource = rs
End If
