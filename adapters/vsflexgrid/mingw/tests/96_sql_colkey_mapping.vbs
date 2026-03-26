Dim rs, keyIndex
fg.FontSize = 10
Set rs = CreateSqlRecordset(Array("MySpecialKey"), Array(adVarChar), Array(32), Array(Array("Hello")))
If rs Is Nothing Then
    SetupBoundFallback "SQL ColKey", SqlStatus("Recordset unavailable")
Else
    Set fg.DataSource = rs
    On Error Resume Next
    keyIndex = fg.ColIndex("MySpecialKey")
    If Err.Number <> 0 Then
        fg.TextMatrix(0, 0) = "ColIndex Err=" & CStr(Err.Number)
        Err.Clear
    Else
        fg.TextMatrix(1, keyIndex) = "Modified by Key"
        If Err.Number <> 0 Then
            fg.TextMatrix(0, 0) = "SetKey Err=" & CStr(Err.Number)
            Err.Clear
        End If
    End If
    On Error GoTo 0
End If
