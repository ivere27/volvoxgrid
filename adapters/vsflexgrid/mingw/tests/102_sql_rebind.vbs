Dim rs1, rs2
fg.FontSize = 10
Set rs1 = CreateSqlRecordset(Array("A"), Array(adVarChar), Array(16), Array(Array("First")))
Set rs2 = CreateSqlRecordset(Array("B", "C"), Array(adVarChar, adVarChar), Array(16, 16), Array(Array("Second", "Extra")))
If rs1 Is Nothing Or rs2 Is Nothing Then
    SetupBoundFallback "SQL Rebind", SqlStatus("Recordset unavailable")
Else
    Set fg.DataSource = rs1
    Set fg.DataSource = rs2
End If
