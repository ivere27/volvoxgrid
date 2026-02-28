' Test 35: Multiple fixed rows and columns
' 2 fixed header rows + 2 fixed left columns (Region, Product).
fg.FontSize = 10
fg.Cols = 6
fg.Rows = 12
fg.FixedRows = 2
fg.FixedCols = 2

fg.TextMatrix(0, 2) = "Q1"
fg.TextMatrix(0, 3) = "Q2"
fg.TextMatrix(0, 4) = "Q3"
fg.TextMatrix(0, 5) = "Q4"
fg.TextMatrix(1, 0) = "Region"
fg.TextMatrix(1, 1) = "Product"
fg.TextMatrix(1, 2) = "Sales"
fg.TextMatrix(1, 3) = "Sales"
fg.TextMatrix(1, 4) = "Sales"
fg.TextMatrix(1, 5) = "Sales"

fg.TextMatrix(2, 0) = "North"  : fg.TextMatrix(2, 1) = "Widget A" : fg.TextMatrix(2, 2) = "1200" : fg.TextMatrix(2, 3) = "1300" : fg.TextMatrix(2, 4) = "1100" : fg.TextMatrix(2, 5) = "1400"
fg.TextMatrix(3, 0) = "North"  : fg.TextMatrix(3, 1) = "Widget B" : fg.TextMatrix(3, 2) = "800"  : fg.TextMatrix(3, 3) = "900"  : fg.TextMatrix(3, 4) = "850"  : fg.TextMatrix(3, 5) = "950"
fg.TextMatrix(4, 0) = "South"  : fg.TextMatrix(4, 1) = "Gadget X" : fg.TextMatrix(4, 2) = "2100" : fg.TextMatrix(4, 3) = "2200" : fg.TextMatrix(4, 4) = "2000" : fg.TextMatrix(4, 5) = "2300"
fg.TextMatrix(5, 0) = "South"  : fg.TextMatrix(5, 1) = "Gadget Y" : fg.TextMatrix(5, 2) = "500"  : fg.TextMatrix(5, 3) = "600"  : fg.TextMatrix(5, 4) = "550"  : fg.TextMatrix(5, 5) = "650"
fg.TextMatrix(6, 0) = "East"   : fg.TextMatrix(6, 1) = "Tool Z"   : fg.TextMatrix(6, 2) = "3400" : fg.TextMatrix(6, 3) = "3500" : fg.TextMatrix(6, 4) = "3300" : fg.TextMatrix(6, 5) = "3600"
fg.TextMatrix(7, 0) = "East"   : fg.TextMatrix(7, 1) = "Widget A" : fg.TextMatrix(7, 2) = "1500" : fg.TextMatrix(7, 3) = "1600" : fg.TextMatrix(7, 4) = "1400" : fg.TextMatrix(7, 5) = "1700"
fg.TextMatrix(8, 0) = "West"   : fg.TextMatrix(8, 1) = "Widget B" : fg.TextMatrix(8, 2) = "700"  : fg.TextMatrix(8, 3) = "750"  : fg.TextMatrix(8, 4) = "680"  : fg.TextMatrix(8, 5) = "800"
fg.TextMatrix(9, 0) = "West"   : fg.TextMatrix(9, 1) = "Gadget X" : fg.TextMatrix(9, 2) = "1900" : fg.TextMatrix(9, 3) = "2000" : fg.TextMatrix(9, 4) = "1850" : fg.TextMatrix(9, 5) = "2100"
fg.TextMatrix(10, 0) = "North" : fg.TextMatrix(10, 1) = "Tool Z"  : fg.TextMatrix(10, 2) = "2800" : fg.TextMatrix(10, 3) = "2900" : fg.TextMatrix(10, 4) = "2700" : fg.TextMatrix(10, 5) = "3000"
fg.TextMatrix(11, 0) = "South" : fg.TextMatrix(11, 1) = "Gadget Y" : fg.TextMatrix(11, 2) = "600" : fg.TextMatrix(11, 3) = "650" : fg.TextMatrix(11, 4) = "580" : fg.TextMatrix(11, 5) = "700"
