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
BACKUP_FILE="/tmp/vfg_probe_74_backup.vbs"
PROBE_OUT="/tmp/vfg_probe_one.txt"
RAW_OUT="../../../target/ocx/legacy_bind_fuzz_results.txt"
SUMMARY_OUT="../../../target/ocx/legacy_bind_fuzz_summary.txt"

curl -sS "file://$TEST_FILE" -o "$BACKUP_FILE"
restore_test() {
    curl -sS "file://$BACKUP_FILE" -o "$TEST_FILE"
}
trap restore_test EXIT

mkdir -p "../../../target/ocx"
: > "$RAW_OUT"
: > "$SUMMARY_OUT"

profiles=(
    "00|none|0|0|0|0|0|0|0|0"
    "01|fixedcols_only|0|0|0|1|0|0|0|0"
    "02|fixedrows_only|0|0|1|0|0|0|0|0"
    "03|toprow_only|0|0|0|0|0|0|0|1"
    "04|cursor_only|0|0|0|0|0|0|1|0"
    "05|widths_only|0|0|0|0|1|0|0|0"
    "06|text_only|0|0|0|0|0|1|0|0"
    "07|fixedcols_widths|0|0|0|1|1|0|0|0"
    "08|fixedcols_text|0|0|0|1|0|1|0|0"
    "09|widths_text|0|0|0|0|1|1|0|0"
    "10|cols_only|1|0|0|0|0|0|0|0"
    "11|rows_only|0|1|0|0|0|0|0|0"
    "12|cols_rows|1|1|0|0|0|0|0|0"
    "13|cols_rows_fixedcols|1|1|0|1|0|0|0|0"
    "14|cols_rows_widths|1|1|0|0|1|0|0|0"
    "15|cols_rows_text|1|1|0|0|0|1|0|0"
    "16|cols_fixedcols|1|0|0|1|0|0|0|0"
    "17|rows_fixedcols|0|1|0|1|0|0|0|0"
    "18|cols_widths|1|0|0|0|1|0|0|0"
    "19|rows_widths|0|1|0|0|1|0|0|0"
    "20|cols_rows_cursor|1|1|0|0|0|0|1|0"
    "21|cols_rows_toprow|1|1|0|0|0|0|0|1"
    "22|cols_rows_fixedrows|1|1|1|0|0|0|0|0"
    "23|full_precfg|1|1|1|1|1|1|1|1"
    "24|full_precfg_no_fixedcols|1|1|1|0|1|1|1|1"
)

sources=(
    "ado2_static|2|ITEM_CODE|1"
    "ado3_batch|3|ITEM_CODE|2"
    "sql2_query|2|ID|1"
    "sql3_table|3|ID|1"
)

append_line() {
    printf "%s\n" "$1" >> "$TEST_FILE"
}

emit_probe_vbs() {
    local case_id="$1"
    local profile_name="$2"
    local set_cols="$3"
    local set_rows="$4"
    local set_fixedrows="$5"
    local set_fixedcols="$6"
    local set_widths="$7"
    local set_text="$8"
    local set_cursor="$9"
    local set_toprow="${10}"
    local source_kind="${11}"
    local field_count="${12}"
    local first_header="${13}"
    local data_mode="${14}"

    local pre_cols="$field_count"
    local pre_rows=$((2 + (case_id % 2)))

    : > "$TEST_FILE"

    append_line "On Error Resume Next"
    append_line ""
    append_line "Sub DumpState(ts, phase, rs)"
    append_line "    Dim vRows, vCols, vFixedRows, vFixedCols, vRow, vCol, vTopRow, vDataMode"
    append_line "    Dim vCW0, vCW1, vCW2, vH0, vH1, vH2, vRsCount, vRsPos"
    append_line "    Err.Clear: vRows = CStr(fg.Rows): If Err.Number <> 0 Then vRows = \"<ERR>\": Err.Clear"
    append_line "    Err.Clear: vCols = CStr(fg.Cols): If Err.Number <> 0 Then vCols = \"<ERR>\": Err.Clear"
    append_line "    Err.Clear: vFixedRows = CStr(fg.FixedRows): If Err.Number <> 0 Then vFixedRows = \"<ERR>\": Err.Clear"
    append_line "    Err.Clear: vFixedCols = CStr(fg.FixedCols): If Err.Number <> 0 Then vFixedCols = \"<ERR>\": Err.Clear"
    append_line "    Err.Clear: vRow = CStr(fg.Row): If Err.Number <> 0 Then vRow = \"<ERR>\": Err.Clear"
    append_line "    Err.Clear: vCol = CStr(fg.Col): If Err.Number <> 0 Then vCol = \"<ERR>\": Err.Clear"
    append_line "    Err.Clear: vTopRow = CStr(fg.TopRow): If Err.Number <> 0 Then vTopRow = \"<ERR>\": Err.Clear"
    append_line "    Err.Clear: vDataMode = CStr(fg.DataMode): If Err.Number <> 0 Then vDataMode = \"<ERR>\": Err.Clear"
    append_line "    vCW0 = \"<NA>\": vCW1 = \"<NA>\": vCW2 = \"<NA>\""
    append_line "    vH0 = \"<NA>\": vH1 = \"<NA>\": vH2 = \"<NA>\""
    append_line "    If fg.Cols > 0 Then"
    append_line "        Err.Clear: vCW0 = CStr(fg.ColWidth(0)): If Err.Number <> 0 Then vCW0 = \"<ERR>\": Err.Clear"
    append_line "        Err.Clear: vH0 = CStr(fg.TextMatrix(0, 0)): If Err.Number <> 0 Then vH0 = \"<ERR>\": Err.Clear"
    append_line "    End If"
    append_line "    If fg.Cols > 1 Then"
    append_line "        Err.Clear: vCW1 = CStr(fg.ColWidth(1)): If Err.Number <> 0 Then vCW1 = \"<ERR>\": Err.Clear"
    append_line "        Err.Clear: vH1 = CStr(fg.TextMatrix(0, 1)): If Err.Number <> 0 Then vH1 = \"<ERR>\": Err.Clear"
    append_line "    End If"
    append_line "    If fg.Cols > 2 Then"
    append_line "        Err.Clear: vCW2 = CStr(fg.ColWidth(2)): If Err.Number <> 0 Then vCW2 = \"<ERR>\": Err.Clear"
    append_line "        Err.Clear: vH2 = CStr(fg.TextMatrix(0, 2)): If Err.Number <> 0 Then vH2 = \"<ERR>\": Err.Clear"
    append_line "    End If"
    append_line "    Err.Clear: vRsCount = CStr(rs.RecordCount): If Err.Number <> 0 Then vRsCount = \"<ERR>\": Err.Clear"
    append_line "    Err.Clear: vRsPos = CStr(rs.AbsolutePosition): If Err.Number <> 0 Then vRsPos = \"<ERR>\": Err.Clear"
    append_line "    ts.WriteLine \"RESULT;phase=\" & phase & \";type=\" & TypeName(fg) & \";Rows=\" & vRows & \";Cols=\" & vCols & \";FixedRows=\" & vFixedRows & \";FixedCols=\" & vFixedCols & \";Row=\" & vRow & \";Col=\" & vCol & \";TopRow=\" & vTopRow & \";DataMode=\" & vDataMode & \";CW0=\" & vCW0 & \";CW1=\" & vCW1 & \";CW2=\" & vCW2 & \";H0=\" & vH0 & \";H1=\" & vH1 & \";H2=\" & vH2 & \";RSCount=\" & vRsCount & \";RSPos=\" & vRsPos"
    append_line "End Sub"
    append_line ""
    append_line "Dim fso, ts, rs"
    append_line "Set fso = CreateObject(\"Scripting.FileSystemObject\")"
    append_line "Set ts = fso.OpenTextFile(\"Z:\tmp\vfg_probe_one.txt\", 8, True)"
    append_line "ts.WriteLine \"BEGIN;type=\" & TypeName(fg)"
    append_line ""
    case "$source_kind" in
        ado2_static)
            append_line "Set rs = CreateObject(\"ADODB.Recordset\")"
            append_line "rs.CursorLocation = 3"
            append_line "rs.CursorType = 3"
            append_line "rs.LockType = 3"
            append_line "rs.Fields.Append \"ITEM_CODE\", 200, 12"
            append_line "rs.Fields.Append \"ITEM_NAME\", 200, 24"
            append_line "rs.Open"
            append_line "rs.AddNew: rs(\"ITEM_CODE\") = \"A-01\": rs(\"ITEM_NAME\") = \"Rotor\": rs.Update"
            append_line "rs.AddNew: rs(\"ITEM_CODE\") = \"A-02\": rs(\"ITEM_NAME\") = \"Seal\": rs.Update"
            ;;
        ado3_batch)
            append_line "Set rs = CreateObject(\"ADODB.Recordset\")"
            append_line "rs.CursorLocation = 3"
            append_line "rs.CursorType = 3"
            append_line "rs.LockType = 4"
            append_line "rs.Fields.Append \"ITEM_CODE\", 200, 12"
            append_line "rs.Fields.Append \"ITEM_NAME\", 200, 24"
            append_line "rs.Fields.Append \"QTY\", 3"
            append_line "rs.Open"
            append_line "rs.AddNew: rs(\"ITEM_CODE\") = \"B-01\": rs(\"ITEM_NAME\") = \"Rotor\": rs(\"QTY\") = 10: rs.Update"
            append_line "rs.AddNew: rs(\"ITEM_CODE\") = \"B-02\": rs(\"ITEM_NAME\") = \"Seal\": rs(\"QTY\") = 20: rs.Update"
            ;;
        sql2_query)
            append_line "Set rs = OpenSqlQueryRecordset(\"SELECT CAST(1 AS int) AS ID, CAST(11 AS int) AS VAL UNION ALL SELECT 2, 22\")"
            ;;
        sql3_table)
            append_line "Set rs = CreateSqlRecordset(Array(\"ID\", \"NAME\", \"QTY\"), Array(adInteger, adVarChar, adInteger), Array(0, 16, 0), Array(Array(1, \"Alpha\", 10), Array(2, \"Beta\", 20)))"
            ;;
    esac

    append_line ""
    append_line "fg.Redraw = False"
    append_line "fg.FontSize = 10"

    if [ "$set_cols" -eq 1 ]; then
        append_line "fg.Cols = $pre_cols"
    fi
    if [ "$set_rows" -eq 1 ]; then
        append_line "fg.Rows = $pre_rows"
    fi
    if [ "$set_fixedrows" -eq 1 ]; then
        append_line "fg.FixedRows = 1"
    fi
    if [ "$set_fixedcols" -eq 1 ]; then
        append_line "fg.FixedCols = 0"
    fi
    if [ "$set_cursor" -eq 1 ]; then
        append_line "fg.Row = 1"
        append_line "fg.Col = 1"
    fi
    if [ "$set_toprow" -eq 1 ]; then
        append_line "fg.TopRow = 1"
    fi
    if [ "$set_widths" -eq 1 ]; then
        append_line "fg.ColWidth(0) = 1800"
        append_line "If fg.Cols > 1 Then fg.ColWidth(1) = 2200"
        append_line "If fg.Cols > 2 Then fg.ColWidth(2) = 2600"
    fi
    if [ "$set_text" -eq 1 ]; then
        append_line "fg.TextMatrix(0, 0) = \"C0\""
        append_line "If fg.Cols > 1 Then fg.TextMatrix(0, 1) = \"C1\""
        append_line "If fg.Cols > 2 Then fg.TextMatrix(0, 2) = \"C2\""
    fi

    append_line "fg.DataMode = $data_mode"
    append_line "Call DumpState(ts, \"PRE\", rs)"
    append_line "Set fg.DataSource = rs"
    append_line "Call DumpState(ts, \"POST\", rs)"
    append_line "fg.FixedCols = 0"
    append_line "Call DumpState(ts, \"FC0\", rs)"
    append_line "rs.MoveLast"
    append_line "Call DumpState(ts, \"MOVE_LAST\", rs)"
    append_line "ts.Close"
    append_line "fg.Redraw = True"
    append_line "On Error GoTo 0"
}

selector_state_from_line() {
    local line="$1"
    local field_count="$2"
    local first_header="$3"
    local cols="" fixedcols="" col="" h0=""
    local part key val
    local old_ifs="$IFS"
    IFS=";"
    for part in $line; do
        key="${part%%=*}"
        val="${part#*=}"
        case "$key" in
            Cols) cols="$val" ;;
            FixedCols) fixedcols="$val" ;;
            Col) col="$val" ;;
            H0) h0="$val" ;;
        esac
    done
    IFS="$old_ifs"

    if [ "$cols" = "$((field_count + 1))" ] && [ "$fixedcols" = "1" ] && [ "$col" = "1" ] && [ -z "$h0" ]; then
        printf "selector"
        return
    fi
    if [ "$cols" = "$field_count" ] && [ "$fixedcols" = "0" ] && [ "$col" = "0" ] && [ "$h0" = "$first_header" ]; then
        printf "direct"
        return
    fi
    printf "other"
}

expected_state_for_case() {
    local set_fixedcols="$1"
    if [ "$set_fixedcols" -eq 1 ]; then
        printf "direct"
    else
        printf "selector"
    fi
}

case_no=0
flex_expected_match=0
flex_expected_miss=0
flex_selector=0
flex_direct=0
flex_other=0
vv_match_flex=0
vv_miss_flex=0

for source in "${sources[@]}"; do
    IFS="|" read -r source_kind field_count first_header data_mode <<< "$source"
    for profile in "${profiles[@]}"; do
        IFS="|" read -r profile_id profile_name set_cols set_rows set_fixedrows set_fixedcols set_widths set_text set_cursor set_toprow <<< "$profile"
        case_no=$((case_no + 1))
        curl -sS file:///etc/hosts -o "$PROBE_OUT"
        emit_probe_vbs "$case_no" "$profile_name" "$set_cols" "$set_rows" "$set_fixedrows" "$set_fixedcols" "$set_widths" "$set_text" "$set_cursor" "$set_toprow" "$source_kind" "$field_count" "$first_header" "$data_mode"
        ./run_compare_ui.sh --tests 74 --jobs 1 >/tmp/vfg_bind_probe_case.log 2>&1

        current_type=""
        lg_post=""
        vv_post=""
        lg_fc0=""
        vv_fc0=""

        perl -0pi -e "s/\r\n/\n/g" "/tmp/vfg_probe_one.txt"
        while IFS= read -r line; do
            [ -n "$line" ] || continue
            case "$line" in
                BEGIN\;type=*)
                    current_type="${line#BEGIN;type=}"
                    ;;
                RESULT\;phase=POST*)
                    if [ "$current_type" = "IVSFlexGrid" ]; then
                        lg_post="$line"
                    else
                        vv_post="$line"
                    fi
                    ;;
                RESULT\;phase=FC0*)
                    if [ "$current_type" = "IVSFlexGrid" ]; then
                        lg_fc0="$line"
                    else
                        vv_fc0="$line"
                    fi
                    ;;
            esac
        done < "$PROBE_OUT"

        lg_state="$(selector_state_from_line "$lg_post" "$field_count" "$first_header")"
        vv_state="$(selector_state_from_line "$vv_post" "$field_count" "$first_header")"
        if [ "$set_fixedcols" -eq 1 ]; then
            expected_state="direct"
        else
            expected_state="selector"
        fi

        case "$lg_state" in
            selector) flex_selector=$((flex_selector + 1)) ;;
            direct) flex_direct=$((flex_direct + 1)) ;;
            *) flex_other=$((flex_other + 1)) ;;
        esac

        if [ "$lg_state" = "$expected_state" ]; then
            flex_expected_match=$((flex_expected_match + 1))
        else
            flex_expected_miss=$((flex_expected_miss + 1))
        fi

        if [ "$vv_state" = "$lg_state" ]; then
            vv_match_flex=$((vv_match_flex + 1))
        else
            vv_miss_flex=$((vv_miss_flex + 1))
        fi

        printf "CASE;%03d;source=%s;profile=%s;set_cols=%s;set_rows=%s;expected=%s;lg=%s;vv=%s\n" \
            "$case_no" "$source_kind" "$profile_name" "$set_cols" "$set_rows" "$expected_state" "$lg_state" "$vv_state" >> "$RAW_OUT"
        printf "CASE;%03d;LG_POST;%s\n" "$case_no" "$lg_post" >> "$RAW_OUT"
        printf "CASE;%03d;LG_FC0;%s\n" "$case_no" "$lg_fc0" >> "$RAW_OUT"
        printf "CASE;%03d;VV_POST;%s\n" "$case_no" "$vv_post" >> "$RAW_OUT"
        printf "CASE;%03d;VV_FC0;%s\n" "$case_no" "$vv_fc0" >> "$RAW_OUT"
    done
done

{
    printf "cases=%d\n" "$case_no"
    printf "flex_selector=%d\n" "$flex_selector"
    printf "flex_direct=%d\n" "$flex_direct"
    printf "flex_other=%d\n" "$flex_other"
    printf "flex_expected_match=%d\n" "$flex_expected_match"
    printf "flex_expected_miss=%d\n" "$flex_expected_miss"
    printf "vv_match_flex=%d\n" "$vv_match_flex"
    printf "vv_miss_flex=%d\n" "$vv_miss_flex"
    printf "rule_checked=expected direct only when pre bind FixedCols was explicitly set to 0; otherwise selector\n"
} > "$SUMMARY_OUT"

printf "Raw: %s\n" "$RAW_OUT"
printf "Summary: %s\n" "$SUMMARY_OUT"
