' SalesGrid.vba -- Excel VBA demo for the Volvox VolvoxGrid ActiveX control
'
' Usage:
'   1. Register VolvoxGrid.dll:   regsvr32 VolvoxGrid.dll
'   2. In Excel VBA, add a reference to "Volvox VolvoxGrid 0.1 Type Library"
'   3. Paste this module into a VBA Module and run CreateSalesGrid
'
' The VolvoxGrid control can be used either as:
'   - An embedded control on a UserForm (add via Insert > Additional Controls)
'   - A standalone COM object created with CreateObject/New (shown below)

Option Explicit

' ---------------------------------------------------------------------------
' CreateSalesGrid -- builds a 100-row sales data grid
' ---------------------------------------------------------------------------
Sub CreateSalesGrid()
    Dim fg As VolvoxGrid
    Set fg = CreateObject("Volvox.VolvoxGrid")

    ' Configure dimensions
    fg.Rows = 101        ' 1 header + 100 data rows
    fg.Cols = 5
    fg.FixedRows = 1
    fg.FixedCols = 0

    ' Suppress redraw while populating
    fg.Redraw = False

    ' Column headers
    fg.SetTextMatrix 0, 0, "Product"
    fg.SetTextMatrix 0, 1, "Category"
    fg.SetTextMatrix 0, 2, "Sales"
    fg.SetTextMatrix 0, 3, "Quarter"
    fg.SetTextMatrix 0, 4, "Region"

    ' Sample data arrays
    Dim products As Variant
    products = Array("Widget A", "Widget B", "Gadget X", "Gadget Y", "Tool Z")
    Dim categories As Variant
    categories = Array("Electronics", "Electronics", "Hardware", "Hardware", "Tools")

    Randomize

    Dim i As Long
    For i = 1 To 100
        fg.SetTextMatrix i, 0, products((i - 1) Mod 5)
        fg.SetTextMatrix i, 1, categories((i - 1) Mod 5)
        fg.SetTextMatrix i, 2, CStr(Int(Rnd * 10000))
        fg.SetTextMatrix i, 3, "Q" & CStr((i Mod 4) + 1)
        fg.SetTextMatrix i, 4, Choose((i Mod 4) + 1, "North", "South", "East", "West")
    Next i

    ' Column widths (in twips)
    fg.ColWidth(0) = 2000
    fg.ColWidth(1) = 2000
    fg.ColWidth(2) = 1500
    fg.ColWidth(3) = 1000
    fg.ColWidth(4) = 1500

    ' Appearance settings
    fg.SelectionMode = flexSelectionByRow
    fg.HighLight = flexHighlightAlways
    fg.FocusRect = flexFocusLight
    fg.AllowUserResizing = flexResizeColumns

    ' Re-enable redraw
    fg.Redraw = True

    ' Sort by Product (ascending, generic)
    fg.Sort flexSortGenericAscending

    MsgBox "Sales grid created with " & (fg.Rows - 1) & " data rows.", vbInformation

    Set fg = Nothing
End Sub

' ---------------------------------------------------------------------------
' CreateGridWithSubtotals -- demonstrates subtotaling capability
' ---------------------------------------------------------------------------
Sub CreateGridWithSubtotals()
    Dim fg As VolvoxGrid
    Set fg = CreateObject("Volvox.VolvoxGrid")

    fg.Rows = 21
    fg.Cols = 3
    fg.FixedRows = 1
    fg.FixedCols = 0

    fg.Redraw = False

    ' Headers
    fg.SetTextMatrix 0, 0, "Department"
    fg.SetTextMatrix 0, 1, "Employee"
    fg.SetTextMatrix 0, 2, "Salary"

    ' Data
    Dim depts As Variant
    depts = Array("Engineering", "Engineering", "Engineering", "Engineering", "Engineering", _
                  "Sales", "Sales", "Sales", "Sales", "Sales", _
                  "Marketing", "Marketing", "Marketing", "Marketing", "Marketing", _
                  "HR", "HR", "HR", "HR", "HR")
    Dim names As Variant
    names = Array("Alice", "Bob", "Carol", "Dave", "Eve", _
                  "Frank", "Grace", "Heidi", "Ivan", "Judy", _
                  "Karl", "Laura", "Mike", "Nancy", "Oscar", _
                  "Pat", "Quinn", "Rosa", "Sam", "Tina")
    Dim salaries As Variant
    salaries = Array(95000, 88000, 92000, 87000, 91000, _
                     75000, 72000, 78000, 71000, 76000, _
                     82000, 79000, 85000, 81000, 83000, _
                     68000, 65000, 70000, 67000, 69000)

    Dim i As Long
    For i = 1 To 20
        fg.SetTextMatrix i, 0, depts(i - 1)
        fg.SetTextMatrix i, 1, names(i - 1)
        fg.SetTextMatrix i, 2, CStr(salaries(i - 1))
    Next i

    ' Sort by department first
    fg.Sort flexSortGenericAscending

    ' Add subtotals: sum salary, grouped by department column (0)
    fg.Subtotal flexAggSum, 0, 2, "Total {0}"

    ' Column widths
    fg.ColWidth(0) = 2500
    fg.ColWidth(1) = 2000
    fg.ColWidth(2) = 1800

    fg.SelectionMode = flexSelectionByRow
    fg.Redraw = True

    MsgBox "Subtotaled grid created.", vbInformation

    Set fg = Nothing
End Sub

' ---------------------------------------------------------------------------
' BindToADORecordset -- demonstrates ADO data binding
' ---------------------------------------------------------------------------
Sub BindToADORecordset()
    ' Requires a reference to "Microsoft ActiveX Data Objects"
    Dim cn As Object  ' ADODB.Connection
    Dim rs As Object  ' ADODB.Recordset

    Set cn = CreateObject("ADODB.Connection")
    cn.Open "Provider=Microsoft.ACE.OLEDB.12.0;Data Source=C:\Data\Sales.accdb;"

    Set rs = CreateObject("ADODB.Recordset")
    rs.Open "SELECT Product, Category, Sales, Quarter, Region FROM SalesData", cn

    Dim fg As VolvoxGrid
    Set fg = CreateObject("Volvox.VolvoxGrid")

    ' Bind the recordset -- automatically populates headers and data
    Set fg.DataSource = rs

    ' Auto-size columns to fit content
    fg.AutoSize 0, fg.Cols - 1

    rs.Close
    cn.Close
    Set rs = Nothing
    Set cn = Nothing
    Set fg = Nothing
End Sub

' ---------------------------------------------------------------------------
' SaveAndLoadGrid -- demonstrates persistence
' ---------------------------------------------------------------------------
Sub SaveAndLoadGrid()
    Dim fg As VolvoxGrid
    Set fg = CreateObject("Volvox.VolvoxGrid")

    fg.Rows = 5
    fg.Cols = 3
    fg.FixedRows = 1

    fg.SetTextMatrix 0, 0, "Name"
    fg.SetTextMatrix 0, 1, "Value"
    fg.SetTextMatrix 0, 2, "Notes"
    fg.SetTextMatrix 1, 0, "Alpha"
    fg.SetTextMatrix 1, 1, "100"
    fg.SetTextMatrix 1, 2, "First item"
    fg.SetTextMatrix 2, 0, "Beta"
    fg.SetTextMatrix 2, 1, "200"
    fg.SetTextMatrix 2, 2, "Second item"

    ' Save to binary file
    fg.SaveGrid "C:\Temp\grid_data.fgd", flexSaveBinary

    ' Clear and reload
    fg.Clear flexClearEverything
    fg.LoadGrid "C:\Temp\grid_data.fgd", flexSaveBinary

    MsgBox "Grid saved and reloaded. Cell(1,0) = " & fg.GetTextMatrix(1, 0), vbInformation

    Set fg = Nothing
End Sub
