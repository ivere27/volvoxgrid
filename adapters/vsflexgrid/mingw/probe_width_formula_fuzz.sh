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
BACKUP_FILE="/tmp/vfg_probe_74_width_backup.vbs"
PROBE_OUT="/tmp/vfg_width_probe_one.txt"
MEASURE_IN="/tmp/vfg_width_measure_in.txt"
MEASURE_OUT="/tmp/vfg_width_measure_out.txt"
ROWS_OUT="/tmp/vfg_width_rows.tsv"
FIT_OUT="/tmp/vfg_width_fit.tsv"
RAW_OUT="../../../target/ocx/legacy_width_fuzz_results.txt"
SUMMARY_OUT="../../../target/ocx/legacy_width_fuzz_summary.txt"
MEASURE_EXE="../../../target/ocx/gdi_measure_text_i686.exe"

curl -sS "file://$TEST_FILE" -o "$BACKUP_FILE"
restore_test() {
    curl -sS "file://$BACKUP_FILE" -o "$TEST_FILE"
}
trap restore_test EXIT

mkdir -p "../../../target/ocx"
: > "$RAW_OUT"
: > "$SUMMARY_OUT"
: > "$MEASURE_IN"
: > "$MEASURE_OUT"
: > "$ROWS_OUT"
: > "$FIT_OUT"

if [ ! -f "$MEASURE_EXE" ]; then
    BUILD_JOBS=1 bash build_ocx.sh >/tmp/vfg_width_build.log 2>&1
fi
if [ ! -f "$MEASURE_EXE" ]; then
    echo "Missing helper: $MEASURE_EXE" >&2
    exit 1
fi

families=( "W" "I" "M" "AB" "X9" )
lengths=( 1 4 8 12 16 )
sources=(
    "ado_selector|ado|0"
    "ado_direct|ado|1"
    "sql_selector|sql|0"
    "sql_direct|sql|1"
)

append_line() {
    printf "%s\n" "$1" >> "$TEST_FILE"
}

repeat_pattern() {
    local pattern="$1"
    local need="$2"
    local out=""
    while [ "${#out}" -lt "$need" ]; do
        out="${out}${pattern}"
    done
    printf "%s" "${out:0:$need}"
}

field_from_line() {
    local line="$1"
    local want="$2"
    local part key value
    local old_ifs="$IFS"
    IFS=";"
    for part in $line; do
        key="${part%%=*}"
        value="${part#*=}"
        if [ "$key" = "$want" ]; then
            printf "%s" "$value"
            IFS="$old_ifs"
            return 0
        fi
    done
    IFS="$old_ifs"
    return 1
}

twips_to_px() {
    local twips="$1"
    local dpi="${2:-96}"
    printf "%d" $(( (twips * dpi + 720) / 1440 ))
}

append_measure() {
    local id="$1"
    local font_name="$2"
    local font_size="$3"
    local font_bold="$4"
    local font_italic="$5"
    local text="$6"
    if [ -z "$text" ]; then
        return
    fi
    printf "%s\t%s\t%s\t%s\t%s\t%s\n" \
        "$id" "$font_name" "$font_size" "$font_bold" "$font_italic" "$text" >> "$MEASURE_IN"
}

emit_probe_vbs() {
    local case_no="$1"
    local source_name="$2"
    local source_kind="$3"
    local force_direct="$4"
    local header_text="$5"
    local data_text="$6"
    local short_text="$7"

    : > "$TEST_FILE"
    append_line "On Error Resume Next"
    append_line ""
    append_line "Function SafeText(v)"
    append_line "    If IsNull(v) Then"
    append_line "        SafeText = \"\""
    append_line "    Else"
    append_line "        SafeText = CStr(v)"
    append_line "    End If"
    append_line "    If Err.Number <> 0 Then"
    append_line "        Err.Clear"
    append_line "        SafeText = \"\""
    append_line "    End If"
    append_line "End Function"
    append_line ""
    append_line "Function LongestColValue(colIndex)"
    append_line "    Dim r, best, cur"
    append_line "    best = \"\""
    append_line "    For r = fg.FixedRows To fg.Rows - 1"
    append_line "        Err.Clear"
    append_line "        cur = CStr(fg.TextMatrix(r, colIndex))"
    append_line "        If Err.Number <> 0 Then"
    append_line "            Err.Clear"
    append_line "            cur = \"\""
    append_line "        End If"
    append_line "        If Len(cur) > Len(best) Then best = cur"
    append_line "    Next"
    append_line "    LongestColValue = best"
    append_line "End Function"
    append_line ""
    append_line "Sub DumpState(ts, phase)"
    append_line "    Dim vRows, vCols, vFixedCols"
    append_line "    Dim vCW0, vCW1, vCW2, vH0, vH1, vH2, vD0, vD1, vD2"
    append_line "    Err.Clear: vRows = CStr(fg.Rows): If Err.Number <> 0 Then vRows = \"<ERR>\": Err.Clear"
    append_line "    Err.Clear: vCols = CStr(fg.Cols): If Err.Number <> 0 Then vCols = \"<ERR>\": Err.Clear"
    append_line "    Err.Clear: vFixedCols = CStr(fg.FixedCols): If Err.Number <> 0 Then vFixedCols = \"<ERR>\": Err.Clear"
    append_line "    vCW0 = \"<NA>\": vCW1 = \"<NA>\": vCW2 = \"<NA>\""
    append_line "    vH0 = \"\": vH1 = \"\": vH2 = \"\""
    append_line "    vD0 = \"\": vD1 = \"\": vD2 = \"\""
    append_line "    If fg.Cols > 0 Then"
    append_line "        Err.Clear: vCW0 = CStr(fg.ColWidth(0)): If Err.Number <> 0 Then vCW0 = \"<ERR>\": Err.Clear"
    append_line "        Err.Clear: vH0 = SafeText(fg.TextMatrix(0, 0)): If Err.Number <> 0 Then vH0 = \"\": Err.Clear"
    append_line "        vD0 = LongestColValue(0)"
    append_line "    End If"
    append_line "    If fg.Cols > 1 Then"
    append_line "        Err.Clear: vCW1 = CStr(fg.ColWidth(1)): If Err.Number <> 0 Then vCW1 = \"<ERR>\": Err.Clear"
    append_line "        Err.Clear: vH1 = SafeText(fg.TextMatrix(0, 1)): If Err.Number <> 0 Then vH1 = \"\": Err.Clear"
    append_line "        vD1 = LongestColValue(1)"
    append_line "    End If"
    append_line "    If fg.Cols > 2 Then"
    append_line "        Err.Clear: vCW2 = CStr(fg.ColWidth(2)): If Err.Number <> 0 Then vCW2 = \"<ERR>\": Err.Clear"
    append_line "        Err.Clear: vH2 = SafeText(fg.TextMatrix(0, 2)): If Err.Number <> 0 Then vH2 = \"\": Err.Clear"
    append_line "        vD2 = LongestColValue(2)"
    append_line "    End If"
    append_line "    ts.WriteLine \"RESULT;phase=\" & phase & \";case=${case_no};source=${source_name};type=\" & TypeName(fg) & \";Rows=\" & vRows & \";Cols=\" & vCols & \";FixedCols=\" & vFixedCols & \";CW0=\" & vCW0 & \";CW1=\" & vCW1 & \";CW2=\" & vCW2 & \";H0=\" & vH0 & \";H1=\" & vH1 & \";H2=\" & vH2 & \";D0=\" & vD0 & \";D1=\" & vD1 & \";D2=\" & vD2"
    append_line "End Sub"
    append_line ""
    append_line "Dim fso, ts, rs"
    append_line "Set fso = CreateObject(\"Scripting.FileSystemObject\")"
    append_line "Set ts = fso.OpenTextFile(\"Z:\tmp\vfg_width_probe_one.txt\", 8, True)"
    append_line "ts.WriteLine \"BEGIN;type=\" & TypeName(fg)"
    append_line ""
    if [ "$source_kind" = "ado" ]; then
        append_line "Set rs = CreateObject(\"ADODB.Recordset\")"
        append_line "rs.CursorLocation = 3"
        append_line "rs.CursorType = 3"
        append_line "rs.LockType = 3"
        append_line "rs.Fields.Append \"${header_text}\", 200, 64"
        append_line "rs.Fields.Append \"C\", 200, 64"
        append_line "rs.Open"
        append_line "rs.AddNew: rs(\"${header_text}\") = \"1\": rs(\"C\") = \"${short_text}\": rs.Update"
        append_line "rs.AddNew: rs(\"${header_text}\") = \"2\": rs(\"C\") = \"${data_text}\": rs.Update"
    else
        append_line "Set rs = OpenSqlQueryRecordset(\"SELECT CAST(\" & Chr(39) & \"1\" & Chr(39) & \" AS varchar(64)) AS [${header_text}], CAST(\" & Chr(39) & \"${short_text}\" & Chr(39) & \" AS varchar(64)) AS [C] UNION ALL SELECT \" & Chr(39) & \"2\" & Chr(39) & \", \" & Chr(39) & \"${data_text}\" & Chr(39))"
    fi
    append_line "fg.Redraw = False"
    append_line "fg.FontName = \"Tahoma\""
    append_line "fg.FontSize = 10"
    if [ "$force_direct" -eq 1 ]; then
        append_line "fg.FixedCols = 0"
    fi
    append_line "Set fg.DataSource = rs"
    append_line "Call DumpState(ts, \"POST\")"
    append_line "ts.Close"
    append_line "fg.Redraw = True"
    append_line "On Error GoTo 0"
}

process_result_line() {
    local case_no="$1"
    local source_name="$2"
    local profile_name="$3"
    local ctrl_type="$4"
    local line="$5"
    local cols fixedcols font_name font_size font_bold font_italic
    local col cw header data hid did

    cols="$(field_from_line "$line" "Cols")"
    fixedcols="$(field_from_line "$line" "FixedCols")"
    font_name="Tahoma"
    font_size="9.75"
    font_bold="0"
    font_italic="0"

    printf "CASE;%03d;%s;%s;%s\n" "$case_no" "$source_name" "$profile_name" "$line" >> "$RAW_OUT"

    for col in 0 1 2; do
        cw="$(field_from_line "$line" "CW${col}")"
        header="$(field_from_line "$line" "H${col}")"
        data="$(field_from_line "$line" "D${col}")"
        if [ -z "$cw" ] || [ "$cw" = "<NA>" ] || [ "$cw" = "<ERR>" ]; then
            continue
        fi
        hid="-"
        did="-"
        if [ -n "$header" ]; then
            hid="m_${case_no}_${source_name}_${profile_name}_${ctrl_type}_c${col}_h"
            append_measure "$hid" "$font_name" "$font_size" "$font_bold" "$font_italic" "$header"
        fi
        if [ -n "$data" ]; then
            did="m_${case_no}_${source_name}_${profile_name}_${ctrl_type}_c${col}_d"
            append_measure "$did" "$font_name" "$font_size" "$font_bold" "$font_italic" "$data"
        fi
        printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
            "$case_no" "$source_name" "$profile_name" "$ctrl_type" "$col" "$fixedcols" "$cw" "$font_name" "$font_size" "$font_bold" "$font_italic" "$header" "$data" "$hid|$did" >> "$ROWS_OUT"
    done
}

case_no=0
for source in "${sources[@]}"; do
    IFS="|" read -r source_name source_kind force_direct <<< "$source"
    for family in "${families[@]}"; do
        for length in "${lengths[@]}"; do
            case_no=$((case_no + 1))
            profile_name="${family}_${length}"
            header_text="$(repeat_pattern "$family" "$length")"
            data_text="$(repeat_pattern "$family" "$length")"
            short_text="x"
            curl -sS file:///etc/hosts -o "$PROBE_OUT"
            emit_probe_vbs "$case_no" "$source_name" "$source_kind" "$force_direct" "$header_text" "$data_text" "$short_text"
            ./run_compare_ui.sh --tests 74 --jobs 1 >/tmp/vfg_width_case.log 2>&1
            perl -0pi -e "s/\r\n/\n/g" "$PROBE_OUT"
            current_type=""
            lg_post=""
            vv_post=""
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
                esac
            done < "$PROBE_OUT"
            if [ -n "$lg_post" ]; then
                process_result_line "$case_no" "$source_name" "$profile_name" "IVSFlexGrid" "$lg_post"
            fi
            if [ -n "$vv_post" ]; then
                process_result_line "$case_no" "$source_name" "$profile_name" "VolvoxGrid" "$vv_post"
            fi
        done
    done
done

WIN_MEASURE_IN="$(winepath -w "$MEASURE_IN" | tr -d "\r")"
WIN_MEASURE_OUT="$(winepath -w "$MEASURE_OUT" | tr -d "\r")"
wine "$MEASURE_EXE" --in "$WIN_MEASURE_IN" --out "$WIN_MEASURE_OUT" >/tmp/vfg_width_measure.log 2>&1
perl -0pi -e "s/\r\n/\n/g" "$MEASURE_OUT"

declare -A measure_px
declare -A measure_text_h
declare -A measure_ave
declare -A measure_max
declare -A measure_tm_h
declare -A measure_ext
declare -A measure_dpi_x
declare -A measure_ok
declare -A flex_pad_freq
declare -A vv_pad_freq

while IFS=$'\t' read -r id px text_h ave max tm_h ext dpi_x dpi_y ok; do
    [ -n "$id" ] || continue
    measure_px["$id"]="$px"
    measure_text_h["$id"]="$text_h"
    measure_ave["$id"]="$ave"
    measure_max["$id"]="$max"
    measure_tm_h["$id"]="$tm_h"
    measure_ext["$id"]="$ext"
    measure_dpi_x["$id"]="$dpi_x"
    measure_ok["$id"]="$ok"
done < "$MEASURE_OUT"

flex_rows=0
flex_selector_cols=0
flex_data_cols=0
flex_padding_sum=0
flex_padding_min=9999
flex_padding_max=-9999
flex_selector_width_sum=0
vv_rows=0
vv_selector_cols=0
vv_data_cols=0
vv_padding_sum=0
vv_padding_min=9999
vv_padding_max=-9999
vv_selector_width_sum=0

while IFS=$'\t' read -r case_no source_name profile_name ctrl_type col fixedcols cw font_name font_size font_bold font_italic header data measure_ids; do
    [ -n "$case_no" ] || continue
    IFS="|" read -r hid did <<< "$measure_ids"
    header_px=0
    data_px=0
    dpi_x=96
    ave=0
    max=0
    tm_h=0
    ext=0
    if [ "$hid" != "-" ] && [ -n "${measure_px[$hid]:-}" ]; then
        header_px="${measure_px[$hid]}"
        dpi_x="${measure_dpi_x[$hid]:-96}"
        ave="${measure_ave[$hid]:-0}"
        max="${measure_max[$hid]:-0}"
        tm_h="${measure_tm_h[$hid]:-0}"
        ext="${measure_ext[$hid]:-0}"
    fi
    if [ "$did" != "-" ] && [ -n "${measure_px[$did]:-}" ]; then
        data_px="${measure_px[$did]}"
        dpi_x="${measure_dpi_x[$did]:-$dpi_x}"
        if [ "$header_px" -eq 0 ]; then
            ave="${measure_ave[$did]:-0}"
            max="${measure_max[$did]:-0}"
            tm_h="${measure_tm_h[$did]:-0}"
            ext="${measure_ext[$did]:-0}"
        fi
    fi
    basis_px=$(( header_px > data_px ? header_px : data_px ))
    cw_px="$(twips_to_px "$cw" "$dpi_x")"
    padding_px=$(( cw_px - basis_px ))
    kind="selector"
    if [ -n "$header" ] || [ -n "$data" ]; then
        if [ "$header_px" -ge "$data_px" ]; then
            kind="header"
        else
            kind="data"
        fi
    fi
    printf "ROW;case=%03d;source=%s;profile=%s;type=%s;col=%s;kind=%s;fixedcols=%s;cw_twips=%s;cw_px=%s;header=%s;header_px=%s;data=%s;data_px=%s;basis_px=%s;padding_px=%s;tm_ave=%s;tm_max=%s;tm_h=%s;tm_ext=%s\n" \
        "$case_no" "$source_name" "$profile_name" "$ctrl_type" "$col" "$kind" "$fixedcols" "$cw" "$cw_px" "$header" "$header_px" "$data" "$data_px" "$basis_px" "$padding_px" "$ave" "$max" "$tm_h" "$ext" >> "$RAW_OUT"
    printf "%s\t%s\t%s\t%s\n" "$ctrl_type" "$kind" "$basis_px" "$cw_px" >> "$FIT_OUT"
    if [ "$ctrl_type" = "IVSFlexGrid" ]; then
        flex_rows=$((flex_rows + 1))
        if [ "$kind" = "selector" ]; then
            flex_selector_cols=$((flex_selector_cols + 1))
            flex_selector_width_sum=$((flex_selector_width_sum + cw_px))
        else
            flex_data_cols=$((flex_data_cols + 1))
            flex_padding_sum=$((flex_padding_sum + padding_px))
            if [ "$padding_px" -lt "$flex_padding_min" ]; then flex_padding_min="$padding_px"; fi
            if [ "$padding_px" -gt "$flex_padding_max" ]; then flex_padding_max="$padding_px"; fi
            flex_pad_freq["$padding_px"]=$(( ${flex_pad_freq["$padding_px"]:-0} + 1 ))
        fi
    else
        vv_rows=$((vv_rows + 1))
        if [ "$kind" = "selector" ]; then
            vv_selector_cols=$((vv_selector_cols + 1))
            vv_selector_width_sum=$((vv_selector_width_sum + cw_px))
        else
            vv_data_cols=$((vv_data_cols + 1))
            vv_padding_sum=$((vv_padding_sum + padding_px))
            if [ "$padding_px" -lt "$vv_padding_min" ]; then vv_padding_min="$padding_px"; fi
            if [ "$padding_px" -gt "$vv_padding_max" ]; then vv_padding_max="$padding_px"; fi
            vv_pad_freq["$padding_px"]=$(( ${vv_pad_freq["$padding_px"]:-0} + 1 ))
        fi
    fi
done < "$ROWS_OUT"

fit_formula() {
    local ctrl="$1"
    local best_pad=0
    local best_min=0
    local best_exact=-1
    local best_abs=-1
    local best_count=0
    local pad minw exact abs count pred diff
    for pad in $(seq 0 20); do
        for minw in $(seq 0 40); do
            exact=0
            abs=0
            count=0
            while IFS=$'\t' read -r row_ctrl kind basis_px cw_px; do
                [ "$row_ctrl" = "$ctrl" ] || continue
                [ "$kind" = "selector" ] && continue
                pred=$((basis_px + pad))
                if [ "$pred" -lt "$minw" ]; then
                    pred="$minw"
                fi
                diff=$((cw_px - pred))
                if [ "$diff" -lt 0 ]; then
                    abs=$((abs - diff))
                else
                    abs=$((abs + diff))
                fi
                if [ "$diff" -eq 0 ]; then
                    exact=$((exact + 1))
                fi
                count=$((count + 1))
            done < "$FIT_OUT"
            if [ "$exact" -gt "$best_exact" ] || { [ "$exact" -eq "$best_exact" ] && { [ "$best_abs" -lt 0 ] || [ "$abs" -lt "$best_abs" ]; }; }; then
                best_pad="$pad"
                best_min="$minw"
                best_exact="$exact"
                best_abs="$abs"
                best_count="$count"
            fi
        done
    done
    printf "%s\t%s\t%s\t%s\t%s\n" "$best_pad" "$best_min" "$best_exact" "$best_abs" "$best_count"
}

flex_fit="$(fit_formula "IVSFlexGrid")"
vv_fit="$(fit_formula "VolvoxGrid")"
IFS=$'\t' read -r flex_best_pad flex_best_min flex_best_exact flex_best_abs flex_best_count <<< "$flex_fit"
IFS=$'\t' read -r vv_best_pad vv_best_min vv_best_exact vv_best_abs vv_best_count <<< "$vv_fit"

flex_mode_pad=""
flex_mode_count=-1
for key in "${!flex_pad_freq[@]}"; do
    if [ "${flex_pad_freq[$key]}" -gt "$flex_mode_count" ]; then
        flex_mode_pad="$key"
        flex_mode_count="${flex_pad_freq[$key]}"
    fi
done
vv_mode_pad=""
vv_mode_count=-1
for key in "${!vv_pad_freq[@]}"; do
    if [ "${vv_pad_freq[$key]}" -gt "$vv_mode_count" ]; then
        vv_mode_pad="$key"
        vv_mode_count="${vv_pad_freq[$key]}"
    fi
done

if [ "$flex_data_cols" -gt 0 ]; then
    flex_padding_avg=$(( flex_padding_sum / flex_data_cols ))
else
    flex_padding_avg=0
fi
if [ "$vv_data_cols" -gt 0 ]; then
    vv_padding_avg=$(( vv_padding_sum / vv_data_cols ))
else
    vv_padding_avg=0
fi
if [ "$flex_selector_cols" -gt 0 ]; then
    flex_selector_avg=$(( flex_selector_width_sum / flex_selector_cols ))
else
    flex_selector_avg=0
fi
if [ "$vv_selector_cols" -gt 0 ]; then
    vv_selector_avg=$(( vv_selector_width_sum / vv_selector_cols ))
else
    vv_selector_avg=0
fi

{
    printf "cases=%d\n" "$case_no"
    printf "profiles=%d\n" $(( ${#families[@]} * ${#lengths[@]} ))
    printf "sources=%d\n" "${#sources[@]}"
    printf "flex_rows=%d\n" "$flex_rows"
    printf "flex_selector_cols=%d\n" "$flex_selector_cols"
    printf "flex_data_cols=%d\n" "$flex_data_cols"
    printf "flex_selector_width_px_avg=%d\n" "$flex_selector_avg"
    printf "flex_padding_px_avg=%d\n" "$flex_padding_avg"
    printf "flex_padding_px_min=%d\n" "$flex_padding_min"
    printf "flex_padding_px_max=%d\n" "$flex_padding_max"
    printf "flex_padding_px_mode=%s\n" "$flex_mode_pad"
    printf "flex_formula_best=width_px=max(text_px+%s,%s)\n" "$flex_best_pad" "$flex_best_min"
    printf "flex_formula_exact=%s/%s\n" "$flex_best_exact" "$flex_best_count"
    printf "flex_formula_abs_error_sum=%s\n" "$flex_best_abs"
    printf "vv_rows=%d\n" "$vv_rows"
    printf "vv_selector_cols=%d\n" "$vv_selector_cols"
    printf "vv_data_cols=%d\n" "$vv_data_cols"
    printf "vv_selector_width_px_avg=%d\n" "$vv_selector_avg"
    printf "vv_padding_px_avg=%d\n" "$vv_padding_avg"
    printf "vv_padding_px_min=%d\n" "$vv_padding_min"
    printf "vv_padding_px_max=%d\n" "$vv_padding_max"
    printf "vv_padding_px_mode=%s\n" "$vv_mode_pad"
    printf "vv_formula_best=width_px=max(text_px+%s,%s)\n" "$vv_best_pad" "$vv_best_min"
    printf "vv_formula_exact=%s/%s\n" "$vv_best_exact" "$vv_best_count"
    printf "vv_formula_abs_error_sum=%s\n" "$vv_best_abs"
    printf "note=selector columns are blank leading columns when pre bind FixedCols was not forced to 0\n"
} > "$SUMMARY_OUT"

printf "Raw: %s\n" "$RAW_OUT"
printf "Summary: %s\n" "$SUMMARY_OUT"
