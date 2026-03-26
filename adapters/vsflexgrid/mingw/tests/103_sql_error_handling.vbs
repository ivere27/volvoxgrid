Dim rs, v
fg.FontSize = 10
Set rs = CreateSqlRecordset(Array("GoodValue"), Array(adInteger), Array(0), Array(Array(1)))
If rs Is Nothing Then
    SetupBoundFallback "SQL Error", SqlStatus("Recordset unavailable")
Else
    On Error Resume Next
    v = rs.Fields("MissingField").Value
    If Err.Number <> 0 Then
        SetSqlLastError "SQL query failed"
        SetupBoundFallback "SQL Error", SqlStatus("Expected query failure")
        Err.Clear
    Else
        SetupBoundFallback "SQL Error", "Unexpected success"
    End If
    On Error GoTo 0
End If
