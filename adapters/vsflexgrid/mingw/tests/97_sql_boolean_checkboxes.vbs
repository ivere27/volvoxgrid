Dim rs
fg.FontSize = 10
Set rs = CreateSqlRecordset(Array("CheckedBox", "UncheckedBox"), Array(adBoolean, adBoolean), Array(0, 0), Array(Array(True, False)))
If rs Is Nothing Then
    SetupBoundFallback "SQL Boolean", SqlStatus("Recordset unavailable")
Else
    Set fg.DataSource = rs
    fg.ColWidth(0) = 1500
    fg.ColWidth(1) = 1500
End If
