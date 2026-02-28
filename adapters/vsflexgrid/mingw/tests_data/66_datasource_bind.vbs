' Test 66: DataSource binding + edit-length pattern
' Mirrors DataSource/sfSetEditMaxLength usage with a disconnected ADODB.Recordset.

On Error Resume Next

Function sfSetEditMaxLength(oSheet, lCol)
    Dim oField
    sfSetEditMaxLength = 0

    oSheet.EditMaxLength = 0
    If Not oSheet.DataSource Is Nothing Then
        Set oField = oSheet.DataSource.Fields(lCol)
        If Err.Number = 0 Then
            Select Case oField.Type
                Case 200
                    oSheet.EditMaxLength = oField.DefinedSize
                Case 131
                    oSheet.EditMaxLength = oField.Precision + oField.NumericScale + 1
            End Select
            sfSetEditMaxLength = oSheet.EditMaxLength
        Else
            Err.Clear
        End If
    End If
End Function

fg.Redraw = False
fg.FontSize = 10

Dim rs, lenCode, lenName, lenSpec
Set rs = CreateObject("ADODB.Recordset")
If Err.Number = 0 Then
    rs.Fields.Append "ITEM_CODE", 200, 12
    rs.Fields.Append "ITEM_NAME", 200, 24
    rs.Fields.Append "ITEM_SPEC", 200, 40
    rs.Open

    rs.AddNew
    rs("ITEM_CODE") = "A-1001"
    rs("ITEM_NAME") = "Gasket"
    rs("ITEM_SPEC") = "NBR-70, 48mm"
    rs.Update

    rs.AddNew
    rs("ITEM_CODE") = "A-1002"
    rs("ITEM_NAME") = "Seal Ring"
    rs("ITEM_SPEC") = "PTFE, 32mm"
    rs.Update

    Set fg.DataSource = rs
    fg.FixedRows = 1
    fg.FixedCols = 0
    fg.Editable = True
    fg.TopRow = 1

    fg.ColWidth(0) = 1500
    fg.ColWidth(1) = 2100
    fg.ColWidth(2) = 2400

    lenCode = sfSetEditMaxLength(fg, 0)
    lenName = sfSetEditMaxLength(fg, 1)
    lenSpec = sfSetEditMaxLength(fg, 2)

    fg.TextMatrix(0, 0) = "ITEM_CODE(" & CStr(lenCode) & ")"
    fg.TextMatrix(0, 1) = "ITEM_NAME(" & CStr(lenName) & ")"
    fg.TextMatrix(0, 2) = "ITEM_SPEC(" & CStr(lenSpec) & ")"
Else
    Err.Clear
    fg.Cols = 3
    fg.Rows = 4
    fg.FixedRows = 1
    fg.FixedCols = 0

    fg.TextMatrix(0, 0) = "ITEM_CODE"
    fg.TextMatrix(0, 1) = "ITEM_NAME"
    fg.TextMatrix(0, 2) = "ITEM_SPEC"

    fg.TextMatrix(1, 0) = "ADODB"
    fg.TextMatrix(1, 1) = "Unavailable"
    fg.TextMatrix(1, 2) = "Fallback mode"
End If

On Error GoTo 0
fg.Redraw = True
