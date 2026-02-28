' Test 17: Cell flood
' Uses CellFloodPercent on the active cell (Row/Col).
fg.FontSize = 10
fg.Cols = 3
fg.Rows = 8
fg.FixedRows = 1

fg.TextMatrix(0, 0) = "Item"
fg.TextMatrix(0, 1) = "Progress"
fg.TextMatrix(0, 2) = "Status"

fg.TextMatrix(1, 0) = "Task A"
fg.TextMatrix(1, 1) = "100%"
fg.TextMatrix(1, 2) = "Good"
fg.Row = 1: fg.Col = 1: fg.CellFloodColor = RGB(0, 120, 215): fg.CellFloodPercent = 100

fg.TextMatrix(2, 0) = "Task B"
fg.TextMatrix(2, 1) = "85%"
fg.TextMatrix(2, 2) = "Good"
fg.Row = 2: fg.Col = 1: fg.CellFloodColor = RGB(0, 120, 215): fg.CellFloodPercent = 85

fg.TextMatrix(3, 0) = "Task C"
fg.TextMatrix(3, 1) = "70%"
fg.TextMatrix(3, 2) = "Good"
fg.Row = 3: fg.Col = 1: fg.CellFloodColor = RGB(0, 120, 215): fg.CellFloodPercent = 70

fg.TextMatrix(4, 0) = "Task D"
fg.TextMatrix(4, 1) = "50%"
fg.TextMatrix(4, 2) = "OK"
fg.Row = 4: fg.Col = 1: fg.CellFloodColor = RGB(0, 120, 215): fg.CellFloodPercent = 50

fg.TextMatrix(5, 0) = "Task E"
fg.TextMatrix(5, 1) = "35%"
fg.TextMatrix(5, 2) = "Low"
fg.Row = 5: fg.Col = 1: fg.CellFloodColor = RGB(0, 120, 215): fg.CellFloodPercent = 35

fg.TextMatrix(6, 0) = "Task F"
fg.TextMatrix(6, 1) = "20%"
fg.TextMatrix(6, 2) = "Low"
fg.Row = 6: fg.Col = 1: fg.CellFloodColor = RGB(0, 120, 215): fg.CellFloodPercent = 20

fg.TextMatrix(7, 0) = "Task G"
fg.TextMatrix(7, 1) = "5%"
fg.TextMatrix(7, 2) = "Low"
fg.Row = 7: fg.Col = 1: fg.CellFloodColor = RGB(0, 120, 215): fg.CellFloodPercent = 5
