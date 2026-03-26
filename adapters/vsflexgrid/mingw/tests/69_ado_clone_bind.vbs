' Test 69: Bind to a cloned ADODB.Recordset.

On Error Resume Next

fg.Redraw = False
fg.FontSize = 10

Dim rs, rsClone, firstField
Set rs = CreateObject("ADODB.Recordset")
If Err.Number = 0 Then
    rs.CursorLocation = 3
    rs.Fields.Append "ITEM_CODE", 200, 12
    rs.Fields.Append "ITEM_NAME", 200, 24
    rs.Open

    rs.AddNew
    rs("ITEM_CODE") = "C-1001"
    rs("ITEM_NAME") = "Rotor"
    rs.Update

    rs.AddNew
    rs("ITEM_CODE") = "C-1002"
    rs("ITEM_NAME") = "Stator"
    rs.Update

    Set rsClone = rs.Clone
    rs.MoveLast

    Set fg.DataSource = rsClone
    firstField = fg.DataSource.Fields(0).Name

    fg.FixedRows = 1
    fg.FixedCols = 0
    fg.TopRow = 1
    fg.ColWidth(0) = 1500
    fg.ColWidth(1) = 2000

    fg.TextMatrix(0, 0) = firstField
    fg.TextMatrix(0, 1) = "CLONE"
    If fg.Rows > fg.FixedRows Then
        fg.TextMatrix(1, 1) = "ROWS=" & CStr(fg.Rows - fg.FixedRows)
    End If
Else
    Err.Clear
    fg.Cols = 2
    fg.Rows = 2
    fg.FixedRows = 1
    fg.FixedCols = 0
    fg.TextMatrix(0, 0) = "ADODB"
    fg.TextMatrix(0, 1) = "Clone"
    fg.TextMatrix(1, 0) = "Fallback"
    fg.TextMatrix(1, 1) = "Unavailable"
End If

On Error GoTo 0
fg.Redraw = True
