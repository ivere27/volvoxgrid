' Test 73: Bind through DataMember on a custom ADO source object.

Class AdoMembers
    Public Orders
    Public Summary
End Class

On Error Resume Next

fg.Redraw = False
fg.FontSize = 10

Dim rsOrders, rsSummary, src, memberName, sourceField
Set rsOrders = CreateObject("ADODB.Recordset")
If Err.Number = 0 Then
    rsOrders.CursorLocation = 3
    rsOrders.Fields.Append "ORDER_NO", 200, 12
    rsOrders.Fields.Append "ITEM_NAME", 200, 24
    rsOrders.Open

    rsOrders.AddNew
    rsOrders("ORDER_NO") = "O-01"
    rsOrders("ITEM_NAME") = "Rotor"
    rsOrders.Update

    rsOrders.AddNew
    rsOrders("ORDER_NO") = "O-02"
    rsOrders("ITEM_NAME") = "Seal"
    rsOrders.Update

    Set rsSummary = CreateObject("ADODB.Recordset")
    rsSummary.CursorLocation = 3
    rsSummary.Fields.Append "STATUS", 200, 12
    rsSummary.Fields.Append "COUNT", 3
    rsSummary.Open
    rsSummary.AddNew
    rsSummary("STATUS") = "READY"
    rsSummary("COUNT") = 2
    rsSummary.Update

    Set src = New AdoMembers
    Set src.Orders = rsOrders
    Set src.Summary = rsSummary

    fg.DataMember = "Summary"
    Set fg.DataSource = src
    fg.DataRefresh

    memberName = fg.DataMember
    sourceField = fg.DataSource.Summary.Fields(0).Name

    fg.FixedRows = 1
    fg.FixedCols = 0
    fg.TopRow = 1
    fg.ColWidth(0) = 1400
    fg.ColWidth(1) = 1800

    fg.TextMatrix(0, 0) = memberName
    fg.TextMatrix(0, 1) = sourceField
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
    fg.TextMatrix(0, 1) = "DataMember"
    fg.TextMatrix(1, 0) = "Fallback"
    fg.TextMatrix(1, 1) = "Unavailable"
End If

On Error GoTo 0
fg.Redraw = True
