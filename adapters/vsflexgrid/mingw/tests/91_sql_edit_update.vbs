Dim rs, editErr
fg.FontSize = 10
Set rs = CreateSqlRecordset(Array("id", "val"), Array(adInteger, adVarChar), Array(0, 50), Array(Array(1, "A")))
If rs Is Nothing Then
    SetupBoundFallback "SQL Edit", SqlStatus("Recordset unavailable")
Else
    editErr = 0
    fg.DataMode = 3
    Set fg.DataSource = rs
    On Error Resume Next
    fg.Editable = 2
    If Err.Number <> 0 Then
        editErr = Err.Number
        Err.Clear
    End If
    fg.TextMatrix(1, 1) = "Edited"
    If Err.Number <> 0 And editErr = 0 Then
        editErr = Err.Number
        Err.Clear
    End If
    On Error GoTo 0
    If editErr <> 0 Then
        fg.TextMatrix(0, 1) = "Edit Err=" & CStr(editErr)
    End If
End If
