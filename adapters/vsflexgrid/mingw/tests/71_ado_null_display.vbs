' Test 71: Null and empty ADO values should display as blanks.

On Error Resume Next

fg.Redraw = False
fg.FontSize = 10

Dim rs, lenA, lenB, lenC, lenD
Set rs = CreateObject("ADODB.Recordset")
If Err.Number = 0 Then
    rs.CursorLocation = 3
    rs.Fields.Append "ITEM_CODE", 200, 12
    rs.Fields.Append "ITEM_NAME", 200, 24
    rs.Fields.Append "NOTE", 200, 16
    rs.Open

    rs.AddNew
    rs("ITEM_CODE") = "N-1001"
    rs("ITEM_NAME") = Null
    rs("NOTE") = ""
    rs.Update

    rs.AddNew
    rs("ITEM_CODE") = "N-1002"
    rs("ITEM_NAME") = ""
    rs("NOTE") = Null
    rs.Update

    Set fg.DataSource = rs
    fg.FixedRows = 1
    fg.FixedCols = 0
    fg.TopRow = 1

    lenA = Len(fg.TextMatrix(1, 1))
    lenB = Len(fg.TextMatrix(1, 2))
    lenC = Len(fg.TextMatrix(2, 1))
    lenD = Len(fg.TextMatrix(2, 2))

    fg.TextMatrix(0, 0) = "NULLS"
    fg.TextMatrix(0, 1) = "A=" & CStr(lenA) & "/" & CStr(lenB)
    fg.TextMatrix(0, 2) = "B=" & CStr(lenC) & "/" & CStr(lenD)
Else
    Err.Clear
    fg.Cols = 3
    fg.Rows = 2
    fg.FixedRows = 1
    fg.FixedCols = 0
    fg.TextMatrix(0, 0) = "ADODB"
    fg.TextMatrix(0, 1) = "Null"
    fg.TextMatrix(0, 2) = "Display"
    fg.TextMatrix(1, 0) = "Fallback"
    fg.TextMatrix(1, 1) = "Unavailable"
End If

On Error GoTo 0
fg.Redraw = True
