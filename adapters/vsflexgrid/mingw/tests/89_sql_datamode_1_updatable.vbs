Dim rs
fg.FontSize = 10
Set rs = CreateSqlRecordset(Array("id", "val"), Array(adInteger, adVarChar), Array(0, 50), Array(Array(1, "A"), Array(2, "B")))
If rs Is Nothing Then
    SetupBoundFallback "SQL Updatable", SqlStatus("Recordset unavailable")
Else
    fg.DataMode = 1
    Set fg.DataSource = rs
    fg.Editable = 2
End If
