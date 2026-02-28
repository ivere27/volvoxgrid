' Test 36: Unicode text — CJK, Cyrillic, accented Latin, symbols
' Verifies correct rendering of non-ASCII text in various scripts.
fg.FontName = "Noto Sans CJK SC"
fg.FontSize = 10
fg.Cols = 3
fg.Rows = 10
fg.ColWidth(0) = 2400
fg.ColWidth(1) = 3600
fg.ColWidth(2) = 3000

fg.TextMatrix(0, 0) = "Script"
fg.TextMatrix(0, 1) = "Text"
fg.TextMatrix(0, 2) = "Notes"

fg.TextMatrix(1, 0) = "Latin"
fg.TextMatrix(1, 1) = "café résumé"
fg.TextMatrix(1, 2) = "Accented"

fg.TextMatrix(2, 0) = "CJK"
fg.TextMatrix(2, 1) = "世界你好"
fg.TextMatrix(2, 2) = "Chinese"

fg.TextMatrix(3, 0) = "Japanese"
fg.TextMatrix(3, 1) = "こんにちは"
fg.TextMatrix(3, 2) = "Hiragana"

fg.TextMatrix(4, 0) = "Korean"
fg.TextMatrix(4, 1) = "안녕하세요"
fg.TextMatrix(4, 2) = "Hangul"

fg.TextMatrix(5, 0) = "Cyrillic"
fg.TextMatrix(5, 1) = "Привет"
fg.TextMatrix(5, 2) = "Russian"

fg.TextMatrix(6, 0) = "Greek"
fg.TextMatrix(6, 1) = "Γειά σου"
fg.TextMatrix(6, 2) = "Greeting"

fg.TextMatrix(7, 0) = "Symbols"
fg.TextMatrix(7, 1) = "☃ ♥ ♪ ★ ©"
fg.TextMatrix(7, 2) = "Misc"

fg.TextMatrix(8, 0) = "Currency"
fg.TextMatrix(8, 1) = "£ ¥ € ₹"
fg.TextMatrix(8, 2) = "Money"

fg.TextMatrix(9, 0) = "Mixed"
fg.TextMatrix(9, 1) = "ABC世界Πα★"
fg.TextMatrix(9, 2) = "All scripts"
