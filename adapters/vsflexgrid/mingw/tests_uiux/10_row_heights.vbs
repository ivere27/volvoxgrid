' Test 10: Variable row heights (twips)
' Each row gets a different height: 300-780 twips (~20-52px).
fg.FontSize = 10
Call PopulateStandard()
For i = 1 To 20
    fg.RowHeight(i) = 300 + (i Mod 5) * 120
Next
