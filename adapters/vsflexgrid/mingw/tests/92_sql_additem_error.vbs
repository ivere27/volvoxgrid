Dim rs
fg.FontSize = 10
Set rs = CreateSqlRecordset(Array("A"), Array(adInteger), Array(0), Array(Array(1)))
If rs Is Nothing Then
    SetupBoundFallback "SQL AddItem", SqlStatus("Recordset unavailable")
Else
    fg.DataMode = 1
    Set fg.DataSource = rs
    fg.TextMatrix(0, 0) = "CT=" & CStr(rs.CursorType) & ",LT=" & CStr(rs.LockType)
    fg.TextMatrix(0, 1) = "ST=" & TypeName(rs.Source) & ",AC=" & TypeName(rs.ActiveConnection)
    fg.TextMatrix(1, 0) = "Bound SQL"
End If
