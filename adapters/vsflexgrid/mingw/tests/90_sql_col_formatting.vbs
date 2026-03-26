Dim rs
fg.FontSize = 10
Set rs = CreateSqlRecordset(Array("MoneyVal", "DateVal"), Array(adCurrency, adDate), Array(0, 0), Array(Array(123456.78, DateSerial(2026, 12, 31) + TimeSerial(23, 59, 59))))
If rs Is Nothing Then
    SetupBoundFallback "SQL Format", SqlStatus("Recordset unavailable")
Else
    Set fg.DataSource = rs
    On Error Resume Next
    fg.ColFormat(0) = "#,##0.0"
    If Err.Number <> 0 Then
        fg.TextMatrix(0, 0) = "Fmt0 Err=" & CStr(Err.Number)
        Err.Clear
    End If
    fg.ColFormat(1) = "yyyy-mmm-dd"
    If Err.Number <> 0 Then
        fg.TextMatrix(0, 1) = "Fmt1 Err=" & CStr(Err.Number)
        Err.Clear
    End If
    On Error GoTo 0
End If
