' Test 11: Merge cells
' Repeated values in column 0 are merged vertically.
fg.FontSize = 10
fg.Cols = 4
fg.Rows = 11
fg.FixedRows = 1
fg.MergeCells = 2     ' flexMergeFree
fg.MergeCol(0) = True ' enable merge on col 0

fg.TextMatrix(0, 0) = "Department"
fg.TextMatrix(0, 1) = "Name"
fg.TextMatrix(0, 2) = "Role"
fg.TextMatrix(0, 3) = "ID"

' Repeated department values trigger merge:
'   Engineering (rows 1-3), Sales (rows 4-5), Marketing (rows 6-9), Support (row 10)
fg.TextMatrix(1, 0) = "Engineering" : fg.TextMatrix(1, 1) = "Alice"   : fg.TextMatrix(1, 2) = "Dev"     : fg.TextMatrix(1, 3) = "101"
fg.TextMatrix(2, 0) = "Engineering" : fg.TextMatrix(2, 1) = "Bob"     : fg.TextMatrix(2, 2) = "QA"      : fg.TextMatrix(2, 3) = "102"
fg.TextMatrix(3, 0) = "Engineering" : fg.TextMatrix(3, 1) = "Carol"   : fg.TextMatrix(3, 2) = "Lead"    : fg.TextMatrix(3, 3) = "103"
fg.TextMatrix(4, 0) = "Sales"       : fg.TextMatrix(4, 1) = "Dave"    : fg.TextMatrix(4, 2) = "Rep"     : fg.TextMatrix(4, 3) = "201"
fg.TextMatrix(5, 0) = "Sales"       : fg.TextMatrix(5, 1) = "Eve"     : fg.TextMatrix(5, 2) = "Manager" : fg.TextMatrix(5, 3) = "202"
fg.TextMatrix(6, 0) = "Marketing"   : fg.TextMatrix(6, 1) = "Frank"   : fg.TextMatrix(6, 2) = "Design"  : fg.TextMatrix(6, 3) = "301"
fg.TextMatrix(7, 0) = "Marketing"   : fg.TextMatrix(7, 1) = "Grace"   : fg.TextMatrix(7, 2) = "Copy"    : fg.TextMatrix(7, 3) = "302"
fg.TextMatrix(8, 0) = "Marketing"   : fg.TextMatrix(8, 1) = "Heidi"   : fg.TextMatrix(8, 2) = "SEO"     : fg.TextMatrix(8, 3) = "303"
fg.TextMatrix(9, 0) = "Marketing"   : fg.TextMatrix(9, 1) = "Ivan"    : fg.TextMatrix(9, 2) = "Social"  : fg.TextMatrix(9, 3) = "304"
fg.TextMatrix(10, 0) = "Support"    : fg.TextMatrix(10, 1) = "Judy"   : fg.TextMatrix(10, 2) = "Tier 1"  : fg.TextMatrix(10, 3) = "401"
