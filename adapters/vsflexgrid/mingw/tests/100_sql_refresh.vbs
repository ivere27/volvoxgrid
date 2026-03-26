Dim cn, rs, tableName
fg.FontSize = 10
Set cn = OpenSqlConnection()
If cn Is Nothing Then
    SetupBoundFallback "SQL Refresh", SqlStatus("Connection unavailable")
Else
    tableName = NextSqlTableName()
    On Error Resume Next
    cn.Execute "CREATE TABLE " & tableName & " (__vfg_pk int IDENTITY(1,1) NOT NULL PRIMARY KEY, [val] int)"
    If Err.Number <> 0 Then
        SetupBoundFallback "SQL Refresh", "Create Err=" & CStr(Err.Number)
        Err.Clear
    Else
        cn.Execute "INSERT INTO " & tableName & " ([val]) VALUES (1)"
        Set rs = OpenSqlTableRecordset("SELECT [val] FROM " & tableName & " ORDER BY __vfg_pk")
        If rs Is Nothing Then
            SetupBoundFallback "SQL Refresh", SqlStatus("Recordset unavailable")
        Else
            Set fg.DataSource = rs
            cn.Execute "UPDATE " & tableName & " SET [val] = 2"
            fg.DataRefresh
        End If
    End If
    On Error GoTo 0
End If
