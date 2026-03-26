Dim rs, autoErr
fg.FontSize = 10
autoErr = 0
On Error Resume Next
fg.AutoResize = True
If Err.Number <> 0 Then
    autoErr = Err.Number
    Err.Clear
End If
On Error GoTo 0
Set rs = CreateSqlRecordset(Array("LongCol"), Array(adVarChar), Array(96), Array(Array("A very very long string indeed that should stretch")))
If rs Is Nothing Then
    SetupBoundFallback "SQL AutoSize", SqlStatus("Recordset unavailable")
Else
    Set fg.DataSource = rs
    If autoErr <> 0 Then
        fg.TextMatrix(0, 0) = "AutoResize Err=" & CStr(autoErr)
    End If
End If
