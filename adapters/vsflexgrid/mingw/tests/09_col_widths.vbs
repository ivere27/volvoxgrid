' Test 09: Column widths (twips)
' Custom widths: 1 inch = 1440 twips, ~15 twips/pixel at 96 DPI.
fg.FontSize = 10
Call PopulateStandard()
fg.ColWidth(0) = 3000  ' ~200px
fg.ColWidth(1) = 1800  ' ~120px
fg.ColWidth(2) = 1200  ' ~80px
fg.ColWidth(3) = 900   ' ~60px
fg.ColWidth(4) = 2100  ' ~140px
