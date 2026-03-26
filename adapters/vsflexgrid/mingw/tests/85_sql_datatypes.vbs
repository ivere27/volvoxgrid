Dim rs
fg.FontSize = 10
Set rs = CreateSqlRecordset(Array("IntVal", "FloatVal", "StrVal", "BitVal", "MoneyVal", "DateVal"), Array(adInteger, adDouble, adVarChar, adBoolean, adCurrency, adDate), Array(0, 0, 32, 0, 0, 0), Array(Array(1, 1.23, "Hello", True, 12.34, DateSerial(2026, 1, 1) + TimeSerial(12, 0, 0))))
If rs Is Nothing Then
    SetupBoundFallback "SQL Types", SqlStatus("Recordset unavailable")
Else
    Set fg.DataSource = rs
    fg.AutoSize 0, fg.Cols - 1
End If
