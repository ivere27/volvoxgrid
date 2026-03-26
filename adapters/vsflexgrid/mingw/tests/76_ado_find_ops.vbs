' Test 76: Observe grid state after Recordset.Find changes the current record.

On Error Resume Next

Function SafeField(rs, fieldName)
    SafeField = "<ERR>"
    If rs Is Nothing Then Exit Function
    If (rs.BOF And rs.EOF) Then
        SafeField = "<EMPTY>"
        Exit Function
    End If
    If rs.BOF Or rs.EOF Then
        SafeField = "<EOF>"
        Exit Function
    End If
    If IsNull(rs.Fields(fieldName).Value) Then
        SafeField = "<NULL>"
    Else
        SafeField = CStr(rs.Fields(fieldName).Value)
    End If
    If Err.Number <> 0 Then
        Err.Clear
        SafeField = "<ERR>"
    End If
End Function

Function SafeCount(rs)
    SafeCount = "ERR"
    If rs Is Nothing Then Exit Function
    SafeCount = CStr(rs.RecordCount)
    If Err.Number <> 0 Then
        Err.Clear
        SafeCount = "ERR"
    End If
End Function

Sub SetupGrid()
    fg.Redraw = False
    fg.FontSize = 10
    fg.FixedRows = 1
    fg.FixedCols = 0
    fg.TopRow = 1
    fg.ColWidth(0) = 1800
    fg.ColWidth(1) = 2200
End Sub

Sub SetupFallback(title)
    Err.Clear
    fg.Cols = 2
    fg.Rows = 2
    fg.FixedRows = 1
    fg.FixedCols = 0
    fg.TextMatrix(0, 0) = "ADODB"
    fg.TextMatrix(0, 1) = title
    fg.TextMatrix(1, 0) = "Fallback"
    fg.TextMatrix(1, 1) = "Unavailable"
End Sub

fg.Redraw = False
fg.FontSize = 10

Dim rs
Set rs = CreateObject("ADODB.Recordset")
If Err.Number = 0 Then
    rs.CursorLocation = 3
    rs.CursorType = 3
    rs.LockType = 3
    rs.Fields.Append "ITEM_CODE", 200, 12
    rs.Fields.Append "ITEM_NAME", 200, 24
    rs.Open

    rs.AddNew: rs("ITEM_CODE") = "F-01": rs("ITEM_NAME") = "Rotor": rs.Update
    rs.AddNew: rs("ITEM_CODE") = "F-02": rs("ITEM_NAME") = "Seal": rs.Update
    rs.AddNew: rs("ITEM_CODE") = "F-03": rs("ITEM_NAME") = "Bracket": rs.Update

    fg.VirtualData = False
    fg.DataMode = 1
    Set fg.DataSource = rs
    Call SetupGrid()

    rs.MoveFirst
    rs.Find "ITEM_NAME = 'Seal'"

    fg.TextMatrix(0, 0) = "FGROW=" & CStr(fg.Row)
    fg.TextMatrix(0, 1) = "CURR=" & SafeField(rs, "ITEM_CODE")
Else
    Call SetupFallback("FindSync")
End If

On Error GoTo 0
fg.Redraw = True
