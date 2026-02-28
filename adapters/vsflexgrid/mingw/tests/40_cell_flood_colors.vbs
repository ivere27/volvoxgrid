' Test 40: CellFlood with multiple colors and percentages
' Each row uses a different flood color and fill level.
fg.FontSize = 10
fg.Cols = 4
fg.Rows = 9
fg.FixedRows = 1
fg.FixedCols = 0
fg.FocusRect = 0
fg.HighLight = 0

fg.ColWidth(0) = 1200
fg.ColWidth(1) = 2400
fg.ColWidth(2) = 2400
fg.ColWidth(3) = 1200

fg.TextMatrix(0, 0) = "KPI"
fg.TextMatrix(0, 1) = "Bar 1"
fg.TextMatrix(0, 2) = "Bar 2"
fg.TextMatrix(0, 3) = "Score"

fg.TextMatrix(1, 0) = "Sales"
fg.TextMatrix(1, 1) = "95%"
fg.TextMatrix(1, 2) = "80%"
fg.TextMatrix(1, 3) = "A"
SetCellFlood 1, 1, RGB(0,128,0), 95
SetCellFlood 1, 2, RGB(0,128,0), 80

fg.TextMatrix(2, 0) = "Profit"
fg.TextMatrix(2, 1) = "72%"
fg.TextMatrix(2, 2) = "60%"
fg.TextMatrix(2, 3) = "B"
SetCellFlood 2, 1, RGB(0,120,215), 72
SetCellFlood 2, 2, RGB(0,120,215), 60

fg.TextMatrix(3, 0) = "Growth"
fg.TextMatrix(3, 1) = "50%"
fg.TextMatrix(3, 2) = "45%"
fg.TextMatrix(3, 3) = "C"
SetCellFlood 3, 1, RGB(255,165,0), 50
SetCellFlood 3, 2, RGB(255,165,0), 45

fg.TextMatrix(4, 0) = "Cost"
fg.TextMatrix(4, 1) = "30%"
fg.TextMatrix(4, 2) = "25%"
fg.TextMatrix(4, 3) = "D"
SetCellFlood 4, 1, RGB(200,0,0), 30
SetCellFlood 4, 2, RGB(200,0,0), 25

fg.TextMatrix(5, 0) = "Risk"
fg.TextMatrix(5, 1) = "100%"
fg.TextMatrix(5, 2) = "5%"
fg.TextMatrix(5, 3) = "F"
SetCellFlood 5, 1, RGB(128,0,128), 100
SetCellFlood 5, 2, RGB(128,0,128), 5

fg.TextMatrix(6, 0) = "Quality"
fg.TextMatrix(6, 1) = "88%"
fg.TextMatrix(6, 2) = "88%"
fg.TextMatrix(6, 3) = "A"
SetCellFlood 6, 1, RGB(0,100,180), 88
SetCellFlood 6, 2, RGB(180,100,0), 88

fg.TextMatrix(7, 0) = "Speed"
fg.TextMatrix(7, 1) = "15%"
fg.TextMatrix(7, 2) = "0%"
fg.TextMatrix(7, 3) = "F"
SetCellFlood 7, 1, RGB(128,128,128), 15
SetCellFlood 7, 2, RGB(128,128,128), 0

fg.TextMatrix(8, 0) = "Morale"
fg.TextMatrix(8, 1) = "65%"
fg.TextMatrix(8, 2) = "40%"
fg.TextMatrix(8, 3) = "C"
SetCellFlood 8, 1, RGB(60,180,75), 65
SetCellFlood 8, 2, RGB(230,25,75), 40
