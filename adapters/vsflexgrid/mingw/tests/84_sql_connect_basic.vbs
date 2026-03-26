Dim rs
fg.FontSize = 10
Set rs = OpenSqlQueryRecordset("SELECT CAST(@@VERSION AS varchar(255)) AS VersionInfo")
If rs Is Nothing Then
    SetupBoundFallback "SQL Connect", SqlStatus("Query unavailable")
Else
    Set fg.DataSource = rs
    fg.AutoSize 0, fg.Cols - 1
End If
