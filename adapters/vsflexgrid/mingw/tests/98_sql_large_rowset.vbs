Dim cn, rs, tableName, i
fg.FontSize = 10
Set cn = OpenSqlConnection()
If cn Is Nothing Then
    SetupBoundFallback "SQL Rows", SqlStatus("Recordset unavailable")
Else
    tableName = NextSqlTableName()
    cn.Execute "CREATE TABLE " & tableName & " (__vfg_pk int IDENTITY(1,1) NOT NULL PRIMARY KEY, [n] int)"
    If Err.Number <> 0 Then
        SetSqlLastError "SQL create table failed"
        SetupBoundFallback "SQL Rows", SqlStatus("Recordset unavailable")
    Else
        For i = 1 To 100
            cn.Execute "INSERT INTO " & tableName & " ([n]) VALUES (" & CStr(i) & ")"
            If Err.Number <> 0 Then Exit For
        Next
        If Err.Number <> 0 Then
            SetSqlLastError "SQL insert failed"
            SetupBoundFallback "SQL Rows", SqlStatus("Recordset unavailable")
        Else
            Set rs = OpenSqlTableRecordset("SELECT [n] FROM " & tableName & " ORDER BY __vfg_pk")
            If rs Is Nothing Then
                SetupBoundFallback "SQL Rows", SqlStatus("Recordset unavailable")
            Else
                Set fg.DataSource = rs
            End If
        End If
    End If
End If
