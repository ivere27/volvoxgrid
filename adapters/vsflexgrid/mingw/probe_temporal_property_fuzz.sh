#!/bin/bash
set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
if [[ "$SCRIPT_PATH" != /* ]]; then
    SCRIPT_PATH="$(pwd)/$SCRIPT_PATH"
fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
SCRIPT_PATH="$SCRIPT_DIR/$(basename "$SCRIPT_PATH")"
cd "$SCRIPT_DIR"

TEST_FILE="$SCRIPT_DIR/tests/74_ado_move_cursor_ops.vbs"
BACKUP_FILE="/tmp/vfg_probe_temporal_74_backup.vbs"
PROBE_OUT="/tmp/vfg_temporal_probe_one.txt"
RAW_OUT="../../../target/ocx/legacy_temporal_fuzz_results.txt"
TRANSITIONS_OUT="../../../target/ocx/legacy_temporal_fuzz_transitions.txt"
SUMMARY_OUT="../../../target/ocx/legacy_temporal_fuzz_summary.txt"
CASES_OUT="../../../target/ocx/legacy_temporal_fuzz_cases.tsv"
RUN_LOG="/tmp/vfg_temporal_probe_run.log"
CASE_LIMIT=0

while [ "$#" -gt 0 ]; do
    case "$1" in
        --cases)
            CASE_LIMIT="$2"
            shift 2
            ;;
        --cases=*)
            CASE_LIMIT="${1#--cases=}"
            shift
            ;;
        *)
            echo "Unknown arg: $1" >&2
            exit 1
            ;;
    esac
done

if ! [[ "$CASE_LIMIT" =~ ^[0-9]+$ ]]; then
    echo "--cases must be numeric" >&2
    exit 1
fi

restore_test() {
    if [ -f "$BACKUP_FILE" ]; then
        cp "$BACKUP_FILE" "$TEST_FILE"
    fi
}
trap restore_test EXIT
cp "$TEST_FILE" "$BACKUP_FILE"

mkdir -p "../../../target/ocx"
: > "$RAW_OUT"
: > "$TRANSITIONS_OUT"
: > "$SUMMARY_OUT"
: > "$CASES_OUT"

declare -a SOURCES=(
    "1|ado_static2|2"
    "2|ado_batch3|3"
    "3|ado_clone2|2"
    "4|ado_datamember_summary|2"
    "5|sql_query2|2"
    "6|sql_table3|3"
)

declare -a PROFILES=(
    "1|default_mode0"
    "2|pre_fixedcols0"
    "3|pre_shape_direct"
    "4|pre_widths"
    "5|pre_headers_widths"
    "6|pre_datamode1_fc0"
    "7|pre_datamode2_fc0"
    "8|pre_shape_selector"
    "9|pre_full_direct"
)

declare -a POSITIONS=(
    "1|first"
    "2|last"
)

case_count=0
for source in "${SOURCES[@]}"; do
    IFS='|' read -r source_id source_name field_count <<< "$source"
    for profile in "${PROFILES[@]}"; do
        IFS='|' read -r profile_id profile_name <<< "$profile"
        for pos in "${POSITIONS[@]}"; do
            IFS='|' read -r pos_id pos_name <<< "$pos"
            case_count=$((case_count + 1))
            if [ "$CASE_LIMIT" -gt 0 ] && [ "$case_count" -gt "$CASE_LIMIT" ]; then
                break 3
            fi
            printf "%03d\t%s\t%s\t%s\t%s\n" \
                "$case_count" "$source_name" "$field_count" "$profile_name" "$pos_name" >> "$CASES_OUT"
        done
    done
done

cat > "$TEST_FILE" <<'VBS'
On Error Resume Next

Class AdoMembers
    Public Orders
    Public Summary
End Class

Function ControlTag(root)
    If InStr(1, TypeName(root), "VSFlex", 1) > 0 Then
        ControlTag = "LG"
    Else
        ControlTag = "VV"
    End If
End Function

Function ControlProgId(root)
    If ControlTag(root) = "LG" Then
        ControlProgId = "VSFlexGrid8.VSFlexGridADO"
    Else
        ControlProgId = "VolvoxGrid.VolvoxGridCtrl"
    End If
End Function

Function CleanText(value)
    Dim s
    If IsObject(value) Then
        CleanText = "<OBJ>"
        Exit Function
    End If
    If IsNull(value) Then
        s = "<NULL>"
    Else
        s = CStr(value)
    End If
    If Err.Number <> 0 Then
        Err.Clear
        CleanText = "<ERR>"
        Exit Function
    End If
    s = Replace(s, vbCr, " ")
    s = Replace(s, vbLf, " ")
    s = Replace(s, ";", ",")
    s = Replace(s, "|", "/")
    CleanText = s
End Function

Function SerializeColWidths(g)
    Dim cols, i, out
    out = ""
    cols = -1
    Err.Clear
    cols = g.Cols
    If Err.Number <> 0 Then
        Err.Clear
        SerializeColWidths = "<ERR>"
        Exit Function
    End If
    For i = 0 To cols - 1
        If i > 0 Then out = out & ","
        Err.Clear
        out = out & CleanText(g.ColWidth(i))
        If Err.Number <> 0 Then
            Err.Clear
            out = out & "<ERR>"
        End If
    Next
    SerializeColWidths = out
End Function

Function SerializeRowHeights(g)
    Dim rows, i, out
    out = ""
    rows = -1
    Err.Clear
    rows = g.Rows
    If Err.Number <> 0 Then
        Err.Clear
        SerializeRowHeights = "<ERR>"
        Exit Function
    End If
    For i = 0 To rows - 1
        If i > 0 Then out = out & ","
        Err.Clear
        out = out & CleanText(g.RowHeight(i))
        If Err.Number <> 0 Then
            Err.Clear
            out = out & "<ERR>"
        End If
    Next
    SerializeRowHeights = out
End Function

Function SerializeRow(g, rowIndex)
    Dim rows, cols, i, out
    out = ""
    rows = -1
    cols = -1
    Err.Clear
    rows = g.Rows
    If Err.Number <> 0 Then
        Err.Clear
        SerializeRow = "<ERR>"
        Exit Function
    End If
    If rowIndex < 0 Or rowIndex >= rows Then
        SerializeRow = "<NA>"
        Exit Function
    End If
    Err.Clear
    cols = g.Cols
    If Err.Number <> 0 Then
        Err.Clear
        SerializeRow = "<ERR>"
        Exit Function
    End If
    For i = 0 To cols - 1
        If i > 0 Then out = out & "|"
        Err.Clear
        out = out & CleanText(g.TextMatrix(rowIndex, i))
        If Err.Number <> 0 Then
            Err.Clear
            out = out & "<ERR>"
        End If
    Next
    SerializeRow = out
End Function

Function SafeRecordCount(rs)
    If rs Is Nothing Then
        SafeRecordCount = "<NA>"
        Exit Function
    End If
    Err.Clear
    SafeRecordCount = CleanText(rs.RecordCount)
    If Err.Number <> 0 Then
        Err.Clear
        SafeRecordCount = "<ERR>"
    End If
End Function

Function SafeAbsolutePosition(rs)
    If rs Is Nothing Then
        SafeAbsolutePosition = "<NA>"
        Exit Function
    End If
    Err.Clear
    SafeAbsolutePosition = CleanText(rs.AbsolutePosition)
    If Err.Number <> 0 Then
        Err.Clear
        SafeAbsolutePosition = "<ERR>"
    End If
End Function

Sub RecordAction(ts, tag, caseId, sourceKind, preProfile, bindPos, stepName, opName)
    Dim desc
    desc = ""
    If Err.Number <> 0 Then desc = CleanText(Err.Description)
    ts.WriteLine "ACTION;CTRL=" & tag & ";CASE=" & CStr(caseId) & ";SRC=" & CStr(sourceKind) & ";PRE=" & CStr(preProfile) & ";POS=" & CStr(bindPos) & ";STEP=" & stepName & ";OP=" & opName & ";ERR=" & CStr(Err.Number) & ";DESC=" & desc
    Err.Clear
End Sub

Sub DumpState(ts, tag, caseId, sourceKind, fieldCount, preProfile, bindPos, stepName, g, rs)
    Dim nRows, nCols
    Dim sRows, sCols, sFixedRows, sFixedCols, sFrozenRows, sFrozenCols
    Dim sRow, sCol, sRowSel, sColSel, sTopRow, sLeftCol, sEditable, sDataMode
    Dim sVirtualData, sAutoResize, sCW, sRH, sH0, sR1, sRL, sRC, sRSPos

    nRows = -1
    nCols = -1

    Err.Clear: nRows = g.Rows: If Err.Number <> 0 Then nRows = -1: Err.Clear
    Err.Clear: nCols = g.Cols: If Err.Number <> 0 Then nCols = -1: Err.Clear

    sRows = CleanText(nRows)
    sCols = CleanText(nCols)
    Err.Clear: sFixedRows = CleanText(g.FixedRows): If Err.Number <> 0 Then sFixedRows = "<ERR>": Err.Clear
    Err.Clear: sFixedCols = CleanText(g.FixedCols): If Err.Number <> 0 Then sFixedCols = "<ERR>": Err.Clear
    Err.Clear: sFrozenRows = CleanText(g.FrozenRows): If Err.Number <> 0 Then sFrozenRows = "<ERR>": Err.Clear
    Err.Clear: sFrozenCols = CleanText(g.FrozenCols): If Err.Number <> 0 Then sFrozenCols = "<ERR>": Err.Clear
    Err.Clear: sRow = CleanText(g.Row): If Err.Number <> 0 Then sRow = "<ERR>": Err.Clear
    Err.Clear: sCol = CleanText(g.Col): If Err.Number <> 0 Then sCol = "<ERR>": Err.Clear
    Err.Clear: sRowSel = CleanText(g.RowSel): If Err.Number <> 0 Then sRowSel = "<ERR>": Err.Clear
    Err.Clear: sColSel = CleanText(g.ColSel): If Err.Number <> 0 Then sColSel = "<ERR>": Err.Clear
    Err.Clear: sTopRow = CleanText(g.TopRow): If Err.Number <> 0 Then sTopRow = "<ERR>": Err.Clear
    Err.Clear: sLeftCol = CleanText(g.LeftCol): If Err.Number <> 0 Then sLeftCol = "<ERR>": Err.Clear
    Err.Clear: sEditable = CleanText(g.Editable): If Err.Number <> 0 Then sEditable = "<ERR>": Err.Clear
    Err.Clear: sDataMode = CleanText(g.DataMode): If Err.Number <> 0 Then sDataMode = "<ERR>": Err.Clear
    Err.Clear: sVirtualData = CleanText(g.VirtualData): If Err.Number <> 0 Then sVirtualData = "<ERR>": Err.Clear
    Err.Clear: sAutoResize = CleanText(g.AutoResize): If Err.Number <> 0 Then sAutoResize = "<ERR>": Err.Clear

    sCW = SerializeColWidths(g)
    sRH = SerializeRowHeights(g)
    sH0 = SerializeRow(g, 0)
    sR1 = SerializeRow(g, 1)
    If nRows > 1 Then
        sRL = SerializeRow(g, nRows - 1)
    Else
        sRL = "<NA>"
    End If
    sRC = SafeRecordCount(rs)
    sRSPos = SafeAbsolutePosition(rs)

    ts.WriteLine "STATE;CTRL=" & tag & ";CASE=" & CStr(caseId) & ";SRC=" & CStr(sourceKind) & ";FIELDS=" & CStr(fieldCount) & ";PRE=" & CStr(preProfile) & ";POS=" & CStr(bindPos) & ";STEP=" & stepName & ";Rows=" & sRows & ";Cols=" & sCols & ";FixedRows=" & sFixedRows & ";FixedCols=" & sFixedCols & ";FrozenRows=" & sFrozenRows & ";FrozenCols=" & sFrozenCols & ";Row=" & sRow & ";Col=" & sCol & ";RowSel=" & sRowSel & ";ColSel=" & sColSel & ";TopRow=" & sTopRow & ";LeftCol=" & sLeftCol & ";Editable=" & sEditable & ";DataMode=" & sDataMode & ";VirtualData=" & sVirtualData & ";AutoResize=" & sAutoResize & ";CW=" & sCW & ";RH=" & sRH & ";H0=" & sH0 & ";R1=" & sR1 & ";RL=" & sRL & ";RSCount=" & sRC & ";RSPos=" & sRSPos
End Sub

Sub InitSource(sourceKind, bindPos, ByRef bindSource, ByRef bindRs, ByRef memberName, ByRef fieldCount)
    Dim rs, rsBase, rsClone, rsOrders, rsSummary, src
    fieldCount = 0
    memberName = ""
    Set bindSource = Nothing
    Set bindRs = Nothing

    Select Case sourceKind
        Case 1
            fieldCount = 2
            Set rs = CreateBoundRecordset(Array("ITEM_CODE", "ITEM_NAME"), Array(adVarChar, adVarChar), Array(12, 24))
            AppendRecord rs, Array("A-01", "Rotor")
            AppendRecord rs, Array("A-02", "Seal")
            AppendRecord rs, Array("A-03", "Bracket")
            Set bindSource = rs
            Set bindRs = rs
        Case 2
            fieldCount = 3
            Set rs = CreateObject("ADODB.Recordset")
            rs.CursorLocation = 3
            rs.CursorType = 3
            rs.LockType = 4
            rs.Fields.Append "ITEM_CODE", 200, 12
            rs.Fields.Append "ITEM_NAME", 200, 24
            rs.Fields.Append "QTY", 3
            rs.Open
            AppendRecord rs, Array("B-01", "Rotor", 10)
            AppendRecord rs, Array("B-02", "Seal", 20)
            AppendRecord rs, Array("B-03", "Plate", 30)
            Set bindSource = rs
            Set bindRs = rs
        Case 3
            fieldCount = 2
            Set rsBase = CreateBoundRecordset(Array("ITEM_CODE", "ITEM_NAME"), Array(adVarChar, adVarChar), Array(12, 24))
            AppendRecord rsBase, Array("C-01", "Rotor")
            AppendRecord rsBase, Array("C-02", "Seal")
            AppendRecord rsBase, Array("C-03", "Plate")
            Set rsClone = rsBase.Clone
            Set bindSource = rsClone
            Set bindRs = rsClone
        Case 4
            fieldCount = 2
            Set rsOrders = CreateBoundRecordset(Array("ORDER_NO", "ITEM_NAME"), Array(adVarChar, adVarChar), Array(12, 24))
            AppendRecord rsOrders, Array("O-01", "Rotor")
            AppendRecord rsOrders, Array("O-02", "Seal")
            Set rsSummary = CreateBoundRecordset(Array("STATUS", "COUNT"), Array(adVarChar, adInteger), Array(12, 0))
            AppendRecord rsSummary, Array("READY", 2)
            AppendRecord rsSummary, Array("DONE", 5)
            Set src = New AdoMembers
            Set src.Orders = rsOrders
            Set src.Summary = rsSummary
            memberName = "Summary"
            Set bindSource = src
            Set bindRs = rsSummary
        Case 5
            fieldCount = 2
            Set rs = OpenSqlQueryRecordset("SELECT CAST(1 AS int) AS ID, CAST('ALPHA' AS varchar(16)) AS NAME UNION ALL SELECT 2, 'BETA' UNION ALL SELECT 3, 'GAMMA'")
            Set bindSource = rs
            Set bindRs = rs
        Case 6
            fieldCount = 3
            Set rs = CreateSqlRecordset(Array("ID", "NAME", "QTY"), Array(adInteger, adVarChar, adInteger), Array(0, 24, 0), Array(Array(1, "Alpha", 10), Array(2, "Beta", 20), Array(3, "Gamma", 30)))
            Set bindSource = rs
            Set bindRs = rs
    End Select

    If Not (bindRs Is Nothing) Then
        If bindPos = 2 Then
            Err.Clear
            bindRs.MoveLast
            If Err.Number <> 0 Then Err.Clear
        Else
            Err.Clear
            bindRs.MoveFirst
            If Err.Number <> 0 Then Err.Clear
        End If
    End If
End Sub

Sub ApplyPreProfile(g, preProfile, fieldCount)
    g.Redraw = False
    g.FontSize = 10
    Select Case preProfile
        Case 1
        Case 2
            g.FixedCols = 0
        Case 3
            g.Cols = fieldCount
            g.Rows = 2
            g.FixedRows = 1
            g.FixedCols = 0
        Case 4
            g.ColWidth(0) = 1800
            If g.Cols > 1 Then g.ColWidth(1) = 2205
            If g.Cols > 2 Then g.ColWidth(2) = 2595
        Case 5
            g.ColWidth(0) = 1800
            If g.Cols > 1 Then g.ColWidth(1) = 2205
            If g.Cols > 2 Then g.ColWidth(2) = 2595
            g.TextMatrix(0, 0) = "C0"
            If g.Cols > 1 Then g.TextMatrix(0, 1) = "C1"
            If g.Cols > 2 Then g.TextMatrix(0, 2) = "C2"
        Case 6
            g.DataMode = 1
            g.FixedCols = 0
        Case 7
            g.DataMode = 2
            g.FixedCols = 0
        Case 8
            g.Cols = fieldCount + 1
            g.Rows = 2
            g.FixedRows = 1
            g.FixedCols = 1
            g.ColWidth(0) = 1200
            If g.Cols > 1 Then g.ColWidth(1) = 1800
            If g.Cols > 2 Then g.ColWidth(2) = 2205
        Case 9
            g.Cols = fieldCount
            g.Rows = 3
            g.FixedRows = 1
            g.FixedCols = 0
            g.ColWidth(0) = 1800
            If g.Cols > 1 Then g.ColWidth(1) = 2205
            If g.Cols > 2 Then g.ColWidth(2) = 2595
            g.Row = 1
            g.Col = 0
            g.RowSel = 1
            g.ColSel = 0
            g.TopRow = 1
            g.LeftCol = 0
    End Select
End Sub

Sub ApplyPostWidthWrites(g)
    Err.Clear
    If g.Cols > 0 Then g.ColWidth(0) = 1500
    If g.Cols > 1 Then g.ColWidth(1) = 2100
    If g.Cols > 2 Then g.ColWidth(2) = 2400
End Sub

Sub ApplyPostCursorWrites(g)
    Err.Clear
    If g.Rows > 1 Then g.Row = 1
    g.Col = 0
    If g.Rows > 1 Then g.RowSel = 1
    g.ColSel = 0
    g.TopRow = 1
    g.LeftCol = 0
End Sub

Sub RunCase(ts, rootFg, caseId, sourceKind, preProfile, bindPos)
    Dim tag, g, bindSource, bindRs, memberName, fieldCount
    tag = ControlTag(rootFg)
    Set g = rootFg
    fieldCount = 0
    memberName = ""
    Set bindSource = Nothing
    Set bindRs = Nothing

    Call DumpState(ts, tag, caseId, sourceKind, fieldCount, preProfile, bindPos, "INIT", g, bindRs)

    Call InitSource(sourceKind, bindPos, bindSource, bindRs, memberName, fieldCount)
    Call RecordAction(ts, tag, caseId, sourceKind, preProfile, bindPos, "INIT_SOURCE", "InitSource")
    Call DumpState(ts, tag, caseId, sourceKind, fieldCount, preProfile, bindPos, "RS_READY", g, bindRs)

    Call ApplyPreProfile(g, preProfile, fieldCount)
    Call RecordAction(ts, tag, caseId, sourceKind, preProfile, bindPos, "PRE", "ApplyPreProfile")
    Call DumpState(ts, tag, caseId, sourceKind, fieldCount, preProfile, bindPos, "PRE", g, bindRs)

    If Len(memberName) > 0 Then
        Err.Clear
        g.DataMember = memberName
        Call RecordAction(ts, tag, caseId, sourceKind, preProfile, bindPos, "SET_DATAMEMBER", "DataMember")
        Call DumpState(ts, tag, caseId, sourceKind, fieldCount, preProfile, bindPos, "SET_DATAMEMBER", g, bindRs)
    End If

    Err.Clear
    Set g.DataSource = bindSource
    Call RecordAction(ts, tag, caseId, sourceKind, preProfile, bindPos, "BIND", "DataSource")
    Call DumpState(ts, tag, caseId, sourceKind, fieldCount, preProfile, bindPos, "BIND", g, bindRs)

    Err.Clear
    g.FixedRows = 1
    Call RecordAction(ts, tag, caseId, sourceKind, preProfile, bindPos, "POST_FR1", "FixedRows=1")
    Call DumpState(ts, tag, caseId, sourceKind, fieldCount, preProfile, bindPos, "POST_FR1", g, bindRs)

    Err.Clear
    g.FixedCols = 0
    Call RecordAction(ts, tag, caseId, sourceKind, preProfile, bindPos, "POST_FC0", "FixedCols=0")
    Call DumpState(ts, tag, caseId, sourceKind, fieldCount, preProfile, bindPos, "POST_FC0", g, bindRs)

    Err.Clear
    g.Editable = 2
    Call RecordAction(ts, tag, caseId, sourceKind, preProfile, bindPos, "POST_EDIT", "Editable=2")
    Call DumpState(ts, tag, caseId, sourceKind, fieldCount, preProfile, bindPos, "POST_EDIT", g, bindRs)

    Call ApplyPostWidthWrites(g)
    Call RecordAction(ts, tag, caseId, sourceKind, preProfile, bindPos, "POST_WIDTHS", "ColWidth writes")
    Call DumpState(ts, tag, caseId, sourceKind, fieldCount, preProfile, bindPos, "POST_WIDTHS", g, bindRs)

    Call ApplyPostCursorWrites(g)
    Call RecordAction(ts, tag, caseId, sourceKind, preProfile, bindPos, "POST_CURSOR", "Cursor/Selection/Scroll writes")
    Call DumpState(ts, tag, caseId, sourceKind, fieldCount, preProfile, bindPos, "POST_CURSOR", g, bindRs)

    If Not (bindRs Is Nothing) Then
        Err.Clear
        bindRs.MoveLast
        Call RecordAction(ts, tag, caseId, sourceKind, preProfile, bindPos, "POST_RS_LAST", "Recordset.MoveLast")
        Call DumpState(ts, tag, caseId, sourceKind, fieldCount, preProfile, bindPos, "POST_RS_LAST", g, bindRs)
    End If

    Err.Clear
    g.DataRefresh
    Call RecordAction(ts, tag, caseId, sourceKind, preProfile, bindPos, "POST_REFRESH", "DataRefresh")
    Call DumpState(ts, tag, caseId, sourceKind, fieldCount, preProfile, bindPos, "POST_REFRESH", g, bindRs)

    Set g = Nothing
    Set bindRs = Nothing
    Set bindSource = Nothing
End Sub

VBS

rm -f "$SCRIPT_DIR/tests/75_temp_case_"*.vbs

case_id=0
for source in "${SOURCES[@]}"; do
    IFS='|' read -r source_id source_name field_count <<< "$source"
    for profile in "${PROFILES[@]}"; do
        IFS='|' read -r profile_id profile_name <<< "$profile"
        for pos in "${POSITIONS[@]}"; do
            IFS='|' read -r pos_id pos_name <<< "$pos"
            case_id=$((case_id + 1))
            if [ "$CASE_LIMIT" -gt 0 ] && [ "$case_id" -gt "$CASE_LIMIT" ]; then
                break 3
            fi

            CASE_SCRIPT="$(printf "$SCRIPT_DIR/tests/75_temp_case_%03d.vbs" "$case_id")"
            cp "$TEST_FILE" "$CASE_SCRIPT"
            cat >> "$CASE_SCRIPT" <<RUNTIME_VBS
Dim fso, ts
Set fso = CreateObject("Scripting.FileSystemObject")
Set ts = fso.OpenTextFile("Z:\tmp\vfg_temporal_probe_one.txt", 8, True)
ts.WriteLine "BEGIN;ROOT=" & TypeName(fg) & ";CTRL=" & ControlTag(fg)
Call RunCase(ts, fg, $case_id, $source_id, $profile_id, $pos_id)
ts.Close
On Error GoTo 0
RUNTIME_VBS
        done
    done
done

rm -f "$PROBE_OUT"
./run_compare_ui.sh --tests 75 --jobs 8 --no-html --no-diff > "$RUN_LOG" 2>&1 || true
rm -f "$SCRIPT_DIR/tests/75_temp_case_"*.vbs

if [ ! -f "$PROBE_OUT" ]; then
    echo "Probe output missing: $PROBE_OUT" >&2
    echo "Run log: $RUN_LOG" >&2
    exit 1
fi

perl -0pi -e 's/\r\n/\n/g' "$PROBE_OUT"
cp "$PROBE_OUT" "$RAW_OUT"

awk -F';' '
function getv_line(line, name,    n,i,key,val) {
    n = split(line, parts, ";")
    for (i = 1; i <= n; i++) {
        split(parts[i], kv, "=")
        key = kv[1]
        val = substr(parts[i], length(key) + 2)
        if (key == name) return val
    }
    return ""
}
BEGIN {
    split("Rows Cols FixedRows FixedCols FrozenRows FrozenCols Row Col RowSel ColSel TopRow LeftCol Editable DataMode VirtualData AutoResize CW RH H0 R1 RL RSCount RSPos", props, " ")
}
/^STATE;/ {
    ctrl = getv_line($0, "CTRL")
    case_id = getv_line($0, "CASE")
    step = getv_line($0, "STEP")
    key = ctrl SUBSEP case_id
    if (key in prev_step) {
        for (i = 1; i <= length(props); i++) {
            p = props[i]
            oldv = prev[key SUBSEP p]
            newv = getv_line($0, p)
            if (oldv != newv) {
                printf "TRANS;CTRL=%s;CASE=%s;FROM=%s;TO=%s;PROP=%s;OLD=%s;NEW=%s\n", ctrl, case_id, prev_step[key], step, p, oldv, newv
            }
        }
    }
    for (i = 1; i <= length(props); i++) {
        p = props[i]
        prev[key SUBSEP p] = getv_line($0, p)
    }
    prev_step[key] = step
}
' "$RAW_OUT" > "$TRANSITIONS_OUT"

awk -F';' '
function getv(line, name,    i,n,part,key,val) {
    n = split(line, parts, ";")
    for (i = 1; i <= n; i++) {
        split(parts[i], kv, "=")
        key = kv[1]
        val = substr(parts[i], length(key) + 2)
        if (key == name) return val
    }
    return ""
}
BEGIN {
    split("Rows Cols FixedRows FixedCols FrozenRows FrozenCols Row Col RowSel ColSel TopRow LeftCol Editable DataMode VirtualData AutoResize CW RH H0 R1 RL RSCount RSPos", props, " ")
}
FNR == NR {
    if ($0 ~ /^STATE;/) {
        ctrl = getv($0, "CTRL")
        case_id = getv($0, "CASE")
        step = getv($0, "STEP")
        steps[step] = 1
        seen_case[ctrl SUBSEP case_id] = 1
        source_kind = getv($0, "SRC")
        field_count = getv($0, "FIELDS") + 0
        casesrc[case_id] = source_kind
        casefields[case_id] = field_count
        if (ctrl == "LG" && step == "BIND") {
            bind_cases++
            cols = getv($0, "Cols") + 0
            fixedcols = getv($0, "FixedCols") + 0
            col = getv($0, "Col") + 0
            if (cols == field_count + 1 && fixedcols == 1 && col == 1) bind_selector++
            else if (cols == field_count && fixedcols == 0 && col == 0) bind_direct++
            else bind_other++
        }
        if (ctrl == "LG" && step == "POST_FC0") {
            fc0_fixed[getv($0, "FixedCols")]++
            fc0_col[getv($0, "Col")]++
            fc0_colsel[getv($0, "ColSel")]++
        }
        if (ctrl == "LG" && step == "POST_REFRESH") {
            refresh_state[case_id SUBSEP "FixedCols"] = getv($0, "FixedCols")
            refresh_state[case_id SUBSEP "Col"] = getv($0, "Col")
            refresh_state[case_id SUBSEP "ColSel"] = getv($0, "ColSel")
            refresh_state[case_id SUBSEP "TopRow"] = getv($0, "TopRow")
            refresh_state[case_id SUBSEP "LeftCol"] = getv($0, "LeftCol")
            refresh_state[case_id SUBSEP "CW"] = getv($0, "CW")
            refresh_state[case_id SUBSEP "RH"] = getv($0, "RH")
        }
        if (ctrl == "LG" && step == "POST_CURSOR") {
            cursor_state[case_id SUBSEP "FixedCols"] = getv($0, "FixedCols")
            cursor_state[case_id SUBSEP "Col"] = getv($0, "Col")
            cursor_state[case_id SUBSEP "ColSel"] = getv($0, "ColSel")
            cursor_state[case_id SUBSEP "TopRow"] = getv($0, "TopRow")
            cursor_state[case_id SUBSEP "LeftCol"] = getv($0, "LeftCol")
            cursor_state[case_id SUBSEP "CW"] = getv($0, "CW")
            cursor_state[case_id SUBSEP "RH"] = getv($0, "RH")
        }
        for (i in props) {
            p = props[i]
            state[ctrl SUBSEP case_id SUBSEP step SUBSEP p] = getv($0, p)
        }
    } else if ($0 ~ /^ACTION;/) {
        ctrl = getv($0, "CTRL")
        step = getv($0, "STEP")
        op = getv($0, "OP")
        err = getv($0, "ERR")
        action_count++
        if (ctrl == "LG" && err != "0") {
            lg_action_err[step SUBSEP op]++
        }
    }
    next
}
$0 ~ /^TRANS;/ {
    ctrl = getv($0, "CTRL")
    from = getv($0, "FROM")
    to = getv($0, "TO")
    prop = getv($0, "PROP")
    trans_count++
    if (ctrl == "LG") {
        lg_change[to SUBSEP prop]++
    }
}
END {
    for (k in seen_case) total_control_cases++
    for (k in state) total_states = total_states + 0
    lg_cases = 0
    vv_cases = 0
    for (k in seen_case) {
        split(k, a, SUBSEP)
        if (a[1] == "LG") lg_cases++
        else if (a[1] == "VV") vv_cases++
    }
    print "cases_total=" lg_cases
    print "controls_seen=LG:" lg_cases ",VV:" vv_cases
    print "bind_cases=" bind_cases
    print "lg_bind_selector=" bind_selector
    print "lg_bind_direct=" bind_direct
    print "lg_bind_other=" bind_other
    print ""
    print "lg_post_fc0_fixedcols_counts:"
    for (k in fc0_fixed) print "  " k "=" fc0_fixed[k]
    print "lg_post_fc0_col_counts:"
    for (k in fc0_col) print "  " k "=" fc0_col[k]
    print "lg_post_fc0_colsel_counts:"
    for (k in fc0_colsel) print "  " k "=" fc0_colsel[k]
    print ""
    print "lg_refresh_rewrites_from_post_cursor:"
    split("FixedCols Col ColSel TopRow LeftCol CW RH", keyprops, " ")
    for (i in keyprops) {
        p = keyprops[i]
        c = 0
        for (case_id in casesrc) {
            if (cursor_state[case_id SUBSEP p] != "" && refresh_state[case_id SUBSEP p] != "" && cursor_state[case_id SUBSEP p] != refresh_state[case_id SUBSEP p]) c++
        }
        print "  " p "=" c
    }
    print ""
    print "lg_transition_frequency_by_step:"
    for (k in lg_change) {
        split(k, a, SUBSEP)
        print "  " a[1] "." a[2] "=" lg_change[k]
    }
    print ""
    print "lg_action_errors:"
    had_err = 0
    for (k in lg_action_err) {
        split(k, a, SUBSEP)
        print "  " a[1] "." a[2] "=" lg_action_err[k]
        had_err = 1
    }
    if (!had_err) print "  none"
    print ""
    print "lg_vs_vv_mismatch_frequency_by_step:"
    mismatch_count = 0
    split("Rows Cols FixedRows FixedCols FrozenRows FrozenCols Row Col RowSel ColSel TopRow LeftCol Editable DataMode CW RH H0 R1 RL RSPos", cmpProps, " ")
    for (case_id in casesrc) {
        for (step in steps) {
            for (i in cmpProps) {
                p = cmpProps[i]
                lgv = state["LG" SUBSEP case_id SUBSEP step SUBSEP p]
                vvv = state["VV" SUBSEP case_id SUBSEP step SUBSEP p]
                if (lgv != "" && vvv != "" && lgv != vvv) {
                    mismatch[step SUBSEP p]++
                    mismatch_count++
                }
            }
        }
    }
    for (k in mismatch) {
        split(k, a, SUBSEP)
        print "  " a[1] "." a[2] "=" mismatch[k]
    }
    if (mismatch_count == 0) print "  none"
}
' "$RAW_OUT" "$TRANSITIONS_OUT" > "$SUMMARY_OUT"

printf '\nlg_state_counts_by_step:\n' >> "$SUMMARY_OUT"
awk -F';' '
function getv(name,    i,a,b) {
    for (i = 1; i <= NF; i++) {
        split($i, a, "=")
        b = substr($i, length(a[1]) + 2)
        if (a[1] == name) return b
    }
    return ""
}
/^STATE;CTRL=LG/ {
    step = getv("STEP")
    c[step]++
}
END {
    for (k in c) print "  " k "=" c[k]
}
' "$RAW_OUT" | sort >> "$SUMMARY_OUT"

printf '\nlg_cases_missing_bind_after_datamember:\n' >> "$SUMMARY_OUT"
awk -F';' '
function getv(name,    i,a,b) {
    for (i = 1; i <= NF; i++) {
        split($i, a, "=")
        b = substr($i, length(a[1]) + 2)
        if (a[1] == name) return b
    }
    return ""
}
/^STATE;CTRL=LG/ {
    case_id = getv("CASE")
    step = getv("STEP")
    src[case_id] = getv("SRC")
    pre[case_id] = getv("PRE")
    pos[case_id] = getv("POS")
    seen[case_id SUBSEP step] = 1
}
END {
    missing = 0
    for (case_id in src) {
        if (seen[case_id SUBSEP "SET_DATAMEMBER"] && !seen[case_id SUBSEP "BIND"]) {
            print "  CASE=" case_id ";SRC=" src[case_id] ";PRE=" pre[case_id] ";POS=" pos[case_id]
            missing++
        }
    }
    if (missing == 0) print "  none"
}
' "$RAW_OUT" | sort -n >> "$SUMMARY_OUT"

printf '\nlg_cases_missing_post_bind_after_bind:\n' >> "$SUMMARY_OUT"
awk -F';' '
function getv(name,    i,a,b) {
    for (i = 1; i <= NF; i++) {
        split($i, a, "=")
        b = substr($i, length(a[1]) + 2)
        if (a[1] == name) return b
    }
    return ""
}
/^STATE;CTRL=LG/ {
    case_id = getv("CASE")
    step = getv("STEP")
    src[case_id] = getv("SRC")
    pre[case_id] = getv("PRE")
    pos[case_id] = getv("POS")
    seen[case_id SUBSEP step] = 1
}
END {
    missing = 0
    for (case_id in src) {
        if (seen[case_id SUBSEP "BIND"] && !seen[case_id SUBSEP "POST_FR1"]) {
            print "  CASE=" case_id ";SRC=" src[case_id] ";PRE=" pre[case_id] ";POS=" pos[case_id]
            missing++
        }
    }
    if (missing == 0) print "  none"
}
' "$RAW_OUT" | sort -n >> "$SUMMARY_OUT"

cat "$SUMMARY_OUT"
