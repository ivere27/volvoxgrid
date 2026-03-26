#!/bin/bash
set -euo pipefail

VERIFY_ONLY=0
VERIFY_SQL=0

while [ "$#" -gt 0 ]; do
    case "$1" in
        --verify)
            VERIFY_ONLY=1
            shift
            ;;
        --sql)
            VERIFY_SQL=1
            shift
            ;;
        --help|-h)
            break
            ;;
        --)
            shift
            break
            ;;
        -*)
            echo "ERROR: unknown option: $1"
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

SELF_NAME="$(basename "$0")"
WINEPREFIX="${WINEPREFIX:-$HOME/.wine}"
MDAC28_EXE="${MDAC28_EXE:-${1:-}}"
MDAC28SDK_DIR="${MDAC28SDK_DIR:-}"
MDAC_STABLE_DIR="$WINEPREFIX/drive_c/windows/system32/mdac28"

# Well-known download URL for MDAC 2.8 SP1.
MDAC28_DOWNLOAD_URL="${MDAC28_DOWNLOAD_URL:-https://web.archive.org/web/20051124032200id_/http://download.microsoft.com/download/4/a/a/4aafff19-9d21-4d35-ae81-02c48dcbbbff/MDAC_TYP.EXE}"

if [ -z "$MDAC28SDK_DIR" ] && [ -d "/tmp/mdac28sdk" ]; then
    MDAC28SDK_DIR="/tmp/mdac28sdk"
fi

usage() {
    cat <<EOF
Usage: $SELF_NAME [--verify] [--sql] [path/to/MDAC_TYP.EXE]

Prepares WINEPREFIX for VSFlexGrid ADO comparisons including MSSQL drivers.

Environment:
  WINEPREFIX           Target Wine prefix. Default: $HOME/.wine
  MDAC28_EXE           Optional path to MDAC_TYP.EXE
  MDAC28SDK_DIR        Optional path to extracted mdac28sdk files
  MDAC28_DOWNLOAD_URL  Override download URL for MDAC_TYP.EXE

Notes:
  - The MDAC runtime installer is optional if native msado15.dll and oledb32.dll
    are already present in the prefix.
  - If sqloledb.dll is missing, the script downloads MDAC_TYP.EXE automatically
    (set MDAC28_EXE to skip download).
  - The SDK typelibs are needed to register MSDATASRC and SIMPDATA into a stable
    path under the prefix instead of a temporary directory.
  - Use --verify to check the current prefix without changing it.
  - Use --verify --sql to fail if MSSQL client DLLs are missing.
EOF
}

have_native_mdac() {
    [ -f "$WINEPREFIX/drive_c/Program Files (x86)/Common Files/System/ADO/msado15.dll" ] || \
    [ -f "$WINEPREFIX/drive_c/Program Files/Common Files/System/ADO/msado15.dll" ]
}

have_native_oledb() {
    [ -f "$WINEPREFIX/drive_c/Program Files (x86)/Common Files/System/OLE DB/oledb32.dll" ] || \
    [ -f "$WINEPREFIX/drive_c/Program Files/Common Files/System/OLE DB/oledb32.dll" ]
}

find_sdk_tlb() {
    local pattern="$1"
    [ -n "$MDAC28SDK_DIR" ] || return 1
    find "$MDAC28SDK_DIR" -type f -iname "*${pattern}*" | sort | head -n 1
}

ensure_prefix_booted() {
    mkdir -p "$WINEPREFIX"
    WINEDEBUG=-all wineboot -u >/dev/null 2>&1 || true
}

install_mdac_runtime() {
    if have_native_mdac && have_native_oledb; then
        echo "Native MDAC runtime already present in $WINEPREFIX"
        return 0
    fi

    if [ -z "$MDAC28_EXE" ]; then
        echo "ERROR: native MDAC runtime is missing from $WINEPREFIX"
        echo "Provide MDAC_TYP.EXE as the first argument or MDAC28_EXE."
        return 1
    fi

    if [ ! -f "$MDAC28_EXE" ]; then
        echo "ERROR: MDAC installer not found: $MDAC28_EXE"
        return 1
    fi

    echo "Launching MDAC installer in $WINEPREFIX"
    echo "Installer: $MDAC28_EXE"
    WINEDEBUG=-all wine start /wait /unix "$MDAC28_EXE"

    if ! have_native_mdac || ! have_native_oledb; then
        echo "ERROR: MDAC runtime is still missing after installer exit."
        echo "If the installer showed a UI, complete it and rerun $SELF_NAME."
        return 1
    fi

    echo "Native MDAC runtime is installed in $WINEPREFIX"
}

is_wine_builtin() {
    local dll="$1"
    [ -f "$dll" ] || return 1
    # Wine builtin DLLs have "Wine builtin DLL" at offset 0x40 in the PE header.
    # Use grep on the binary to avoid bash null-byte warnings from dd.
    grep -q 'Wine builtin DLL' "$dll" 2>/dev/null
}

# locate_mdac_cab — find or download the MDAC installer to provide access to its cab files.
# Sets CAB_DIR to a directory containing the cab files on success; returns 1 on failure.
# The caller is responsible for deleting CAB_DIR after use.
locate_mdac_cab() {
    CAB_DIR=""
    local tmpdir

    # 1. Try from MDAC28_EXE.
    if [ -n "$MDAC28_EXE" ] && [ -f "$MDAC28_EXE" ]; then
        tmpdir="$(mktemp -d /tmp/mdac28-extract.XXXXXX)"
        cabextract -d "$tmpdir" -F '*.cab' "$MDAC28_EXE" >/dev/null 2>&1 || true
        if [ -f "$tmpdir/mdacxpak.cab" ]; then
            CAB_DIR="$tmpdir"
            return 0
        fi
        rm -rf "$tmpdir"
    fi

    # 2. Check cached download.
    local cached="/tmp/mdac28_download/MDAC_TYP.EXE"
    if [ -f "$cached" ]; then
        tmpdir="$(mktemp -d /tmp/mdac28-extract.XXXXXX)"
        cabextract -d "$tmpdir" -F '*.cab' "$cached" >/dev/null 2>&1 || true
        if [ -f "$tmpdir/mdacxpak.cab" ]; then
            CAB_DIR="$tmpdir"
            return 0
        fi
        rm -rf "$tmpdir"
    fi

    # 3. Download MDAC_TYP.EXE.
    if command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1; then
        echo "Downloading MDAC_TYP.EXE..."
        mkdir -p /tmp/mdac28_download
        local dl="/tmp/mdac28_download/MDAC_TYP.EXE"
        if command -v curl >/dev/null 2>&1; then
            curl -fSL -o "$dl" "$MDAC28_DOWNLOAD_URL" 2>&1 || true
        else
            wget -q -O "$dl" "$MDAC28_DOWNLOAD_URL" 2>&1 || true
        fi
        if [ -f "$dl" ] && [ -s "$dl" ]; then
            tmpdir="$(mktemp -d /tmp/mdac28-extract.XXXXXX)"
            cabextract -d "$tmpdir" -F '*.cab' "$dl" >/dev/null 2>&1 || true
            if [ -f "$tmpdir/mdacxpak.cab" ]; then
                CAB_DIR="$tmpdir"
                return 0
            fi
            rm -rf "$tmpdir"
        fi
    fi

    return 1
}

fix_wine_builtins() {
    local ado_dir oledb_dir msadc_dir syswow64

    ado_dir="$WINEPREFIX/drive_c/Program Files (x86)/Common Files/System/ADO"
    oledb_dir="$WINEPREFIX/drive_c/Program Files (x86)/Common Files/System/OLE DB"
    msadc_dir="$WINEPREFIX/drive_c/Program Files (x86)/Common Files/System/MSADC"
    syswow64="$WINEPREFIX/drive_c/windows/syswow64"

    if ! is_wine_builtin "$ado_dir/msado15.dll"; then
        echo "ADO DLLs appear to be genuine native — no replacement needed"
        return 0
    fi

    if ! locate_mdac_cab; then
        echo "WARNING: cannot locate mdacxpak.cab — skipping builtin replacement"
        return 0
    fi

    echo "Replacing Wine builtin DLLs with genuine native from cab..."
    local dlldir
    dlldir="$(mktemp -d /tmp/mdac28-dlls.XXXXXX)"
    cabextract -d "$dlldir" -F '*.dll' "$CAB_DIR/mdacxpak.cab" >/dev/null 2>&1

    # Copy layout mirrors the [ADO], [MSADC], [OLEDB], [SYSTEMDIR] sections of
    # mdacxpak.inf.  All DLLs also go to syswow64 for 32-bit COM resolution.
    local dll

    # ADO directory
    mkdir -p "$ado_dir"
    for dll in msader15.dll msado15.dll msador15.dll msadrh15.dll msadomd.dll msadox.dll msjro.dll; do
        [ -f "$dlldir/$dll" ] && cp "$dlldir/$dll" "$ado_dir/$dll"
    done

    # MSADC directory
    mkdir -p "$msadc_dir"
    for dll in msadce.dll msadcer.dll msadcf.dll msadcfr.dll msadco.dll msadcor.dll msadcs.dll msadds.dll msaddsr.dll msdaprst.dll msdaprsr.dll msdarem.dll msdaremr.dll msdfmap.dll; do
        [ -f "$dlldir/$dll" ] && cp "$dlldir/$dll" "$msadc_dir/$dll"
    done

    # OLE DB directory
    mkdir -p "$oledb_dir"
    for dll in oledb32.dll oledb32r.dll msdaps.dll msxactps.dll msdadc.dll msdaenum.dll msdaer.dll msdaurl.dll msdatt.dll msdasql.dll msdasqlr.dll msdasc.dll msdaosp.dll msdatl3.dll msdaora.dll msdaorar.dll; do
        [ -f "$dlldir/$dll" ] && cp "$dlldir/$dll" "$oledb_dir/$dll"
    done

    # System DLLs
    for dll in msdart.dll msdatl3.dll mscpxl32.dll msorcl32.dll msorc32r.dll; do
        [ -f "$dlldir/$dll" ] && [ -d "$syswow64" ] && cp "$dlldir/$dll" "$syswow64/$dll"
    done

    # Mirror everything to syswow64 for 32-bit COM lookup
    if [ -d "$syswow64" ]; then
        for dll in "$dlldir"/*.dll; do
            [ -f "$dll" ] && cp "$dll" "$syswow64/$(basename "$dll")"
        done
    fi

    rm -rf "$dlldir" "$CAB_DIR"
    echo "Replaced Wine builtin ADO/OLE DB DLLs with genuine native"
}

install_mssql_dlls() {
    local oledb_dir="$WINEPREFIX/drive_c/Program Files (x86)/Common Files/System/OLE DB"
    [ -d "$oledb_dir" ] || oledb_dir="$WINEPREFIX/drive_c/Program Files/Common Files/System/OLE DB"
    local sys32="$WINEPREFIX/drive_c/windows/system32"
    local syswow64="$WINEPREFIX/drive_c/windows/syswow64"
    local need_extract=0

    # Check what's missing.
    if [ ! -f "$oledb_dir/sqloledb.dll" ]; then
        need_extract=1
    fi
    for dll in odbc32.dll odbccp32.dll mtxdm.dll dbmsrpcn.dll dbnmpntw.dll dbnetlib.dll dbmsgnet.dll sqlunirl.dll; do
        if [ -f "$sys32/$dll" ] && is_wine_builtin "$sys32/$dll"; then
            need_extract=1
        fi
        if [ ! -f "$sys32/$dll" ]; then
            need_extract=1
        fi
    done

    if [ "$need_extract" = "0" ]; then
        echo "MSSQL driver DLLs already present"
        return 0
    fi

    echo "Installing MSSQL driver DLLs..."

    if ! locate_mdac_cab; then
        echo "ERROR: cannot locate MDAC cab — MSSQL driver DLLs cannot be installed"
        echo "  Provide MDAC_TYP.EXE or set MDAC28_DOWNLOAD_URL."
        return 1
    fi

    local dlldir
    dlldir="$(mktemp -d /tmp/mdac28-mssql.XXXXXX)"
    for cab in mdacxpak.cab sqloldb.cab sqlodbc.cab sqlnet.cab mtxfiles.cab; do
        if [ -f "$CAB_DIR/$cab" ]; then
            cabextract -d "$dlldir" -F '*.dll' "$CAB_DIR/$cab" >/dev/null 2>&1 || true
            cabextract -d "$dlldir" -F '*.rll' "$CAB_DIR/$cab" >/dev/null 2>&1 || true
            cabextract -d "$dlldir" -F '*.exe' "$CAB_DIR/$cab" >/dev/null 2>&1 || true
            cabextract -d "$dlldir" -F '*.chm' "$CAB_DIR/$cab" >/dev/null 2>&1 || true
        fi
    done

    # SQLOLEDB provider -> OLE DB directory.
    mkdir -p "$oledb_dir"
    for dll in sqloledb.dll sqlsrv32.dll; do
        [ -f "$dlldir/$dll" ] || continue
        cp "$dlldir/$dll" "$oledb_dir/$dll"
        [ -d "$syswow64" ] && cp "$dlldir/$dll" "$syswow64/$dll"
        WINEDEBUG=-all wine regsvr32 /s "$oledb_dir/$dll" >/dev/null 2>&1 || true
        echo "  Installed and registered $dll"
    done

    # ODBC core + MSSQL ODBC driver + DTC proxy.
    for dll in odbc32.dll odbccp32.dll odbcint.dll mtxdm.dll sqlsrv32.dll msdtcprx.dll; do
        [ -f "$dlldir/$dll" ] || continue
        cp "$dlldir/$dll" "$sys32/$dll"
        [ -d "$syswow64" ] && cp "$dlldir/$dll" "$syswow64/$dll"
        echo "  Installed $dll"
    done

    # SQL client net libs used by SQLOLEDB to reach SQL Server.
    for dll in dbmsrpcn.dll dbnmpntw.dll dbnetlib.dll dbmsgnet.dll sqlunirl.dll cliconfg.dll cliconfg.exe cliconfg.rll cliconf.chm; do
        [ -f "$dlldir/$dll" ] || continue
        cp "$dlldir/$dll" "$sys32/$dll"
        [ -d "$syswow64" ] && cp "$dlldir/$dll" "$syswow64/$dll"
        echo "  Installed $dll"
    done

    # Mirror the SQL net client defaults from sqlnet.inf.
    WINEDEBUG=-all wine reg add "HKLM\Software\Microsoft\MSSQLServer\Client\SuperSocketNetLib\VIA" /v "Vendor" /t REG_SZ /d "" /f >/dev/null 2>&1 || true
    WINEDEBUG=-all wine reg add "HKLM\Software\Microsoft\MSSQLServer\Client\SuperSocketNetLib\VIA" /v "DefaultServerPort" /t REG_SZ /d "0:1433" /f >/dev/null 2>&1 || true
    WINEDEBUG=-all wine reg add "HKLM\Software\Microsoft\MSSQLServer\Client\SuperSocketNetLib\VIA" /v "DefaultClientNIC" /t REG_SZ /d "0" /f >/dev/null 2>&1 || true
    WINEDEBUG=-all wine reg add "HKLM\Software\Microsoft\MSSQLServer\Client\SuperSocketNetLib\VIA" /v "RecognizedVendors" /t REG_SZ /d "Giganet, ServerNet II" /f >/dev/null 2>&1 || true

    rm -rf "$dlldir" "$CAB_DIR"
    echo "MSSQL driver DLLs installed"
}

# register_mdac_com_classes — call DllRegisterServer on each MDAC DLL from a
# 32-bit process so that COM class entries land in Wow6432Node where the 32-bit
# grid_compare_test.exe can find them.  `wine regsvr32` invoked from the shell
# runs 64-bit and writes to the wrong hive, so we compile a tiny 32-bit helper
# with i686-w64-mingw32-gcc (already a prerequisite of the compare pipeline).
# The list matches the INF [RegFiles] section of mdacxpak.inf.
register_mdac_com_classes() {
    if ! command -v i686-w64-mingw32-gcc >/dev/null 2>&1; then
        echo "WARNING: i686-w64-mingw32-gcc not found — skipping 32-bit COM registration"
        return 0
    fi

    local helper_c helper_exe
    helper_c="$(mktemp /tmp/mdac28-reg.XXXXXX.c)"
    helper_exe="${helper_c%.c}.exe"

    cat > "$helper_c" << 'HELPER_C'
#include <windows.h>
#include <stdio.h>
typedef HRESULT (WINAPI *RegFunc)(void);
static void reg(const wchar_t *p) {
    HMODULE h = LoadLibraryW(p);
    if (!h) return;
    RegFunc f = (RegFunc)GetProcAddress(h, "DllRegisterServer");
    if (f) f();
    /* keep DLLs loaded — later registrations may need earlier ones */
}
int main(void) {
    CoInitialize(NULL);
    /* ADO */
    reg(L"C:\\Program Files (x86)\\Common Files\\System\\ADO\\msado15.dll");
    reg(L"C:\\Program Files (x86)\\Common Files\\System\\ADO\\msador15.dll");
    reg(L"C:\\Program Files (x86)\\Common Files\\System\\ADO\\msadrh15.dll");
    reg(L"C:\\Program Files (x86)\\Common Files\\System\\ADO\\msadomd.dll");
    reg(L"C:\\Program Files (x86)\\Common Files\\System\\ADO\\msadox.dll");
    reg(L"C:\\Program Files (x86)\\Common Files\\System\\ADO\\msjro.dll");
    /* MSADC */
    reg(L"C:\\Program Files (x86)\\Common Files\\System\\MSADC\\msadce.dll");
    reg(L"C:\\Program Files (x86)\\Common Files\\System\\MSADC\\msadcf.dll");
    reg(L"C:\\Program Files (x86)\\Common Files\\System\\MSADC\\msadco.dll");
    reg(L"C:\\Program Files (x86)\\Common Files\\System\\MSADC\\msadds.dll");
    reg(L"C:\\Program Files (x86)\\Common Files\\System\\MSADC\\msdaprst.dll");
    reg(L"C:\\Program Files (x86)\\Common Files\\System\\MSADC\\msdarem.dll");
    reg(L"C:\\Program Files (x86)\\Common Files\\System\\MSADC\\msdfmap.dll");
    /* OLE DB */
    reg(L"C:\\Program Files (x86)\\Common Files\\System\\OLE DB\\oledb32.dll");
    reg(L"C:\\Program Files (x86)\\Common Files\\System\\OLE DB\\msxactps.dll");
    reg(L"C:\\Program Files (x86)\\Common Files\\System\\OLE DB\\msdaenum.dll");
    reg(L"C:\\Program Files (x86)\\Common Files\\System\\OLE DB\\msdaurl.dll");
    reg(L"C:\\Program Files (x86)\\Common Files\\System\\OLE DB\\msdatt.dll");
    reg(L"C:\\Program Files (x86)\\Common Files\\System\\OLE DB\\msdasql.dll");
    reg(L"C:\\Program Files (x86)\\Common Files\\System\\OLE DB\\msdaosp.dll");
    reg(L"C:\\Program Files (x86)\\Common Files\\System\\OLE DB\\msdaora.dll");
    reg(L"C:\\Program Files (x86)\\Common Files\\System\\OLE DB\\msdaps.dll");
    reg(L"C:\\Program Files (x86)\\Common Files\\System\\OLE DB\\sqloledb.dll");
    CoUninitialize();
    return 0;
}
HELPER_C

    i686-w64-mingw32-gcc -O2 -o "$helper_exe" "$helper_c" \
        -lole32 -loleaut32 -luuid -static-libgcc 2>/dev/null
    if [ ! -f "$helper_exe" ]; then
        echo "WARNING: failed to compile 32-bit registration helper"
        rm -f "$helper_c"
        return 0
    fi

    echo "Registering MDAC COM classes from 32-bit helper..."
    WINEDEBUG=-all wine "$helper_exe" >/dev/null 2>&1 || true
    rm -f "$helper_c" "$helper_exe"
    echo "MDAC COM classes registered"
}

register_dll_overrides() {
    echo "Registering Wine DLL overrides (native priority)..."
    local override_dlls="msado15 msadce msadco msdart msdaps msdatl3 oledb32 msdadc msdaenum msdaer msdasql sqloledb odbc32 odbccp32 mtxdm sqlsrv32 dbnetlib dbnmpntw dbmsrpcn dbmsgnet sqlunirl"
    local dll
    for dll in $override_dlls; do
        WINEDEBUG=-all wine reg add "HKCU\Software\Wine\DllOverrides" /v "$dll" /t REG_SZ /d "native" /f >/dev/null 2>&1
    done
    echo "DLL overrides registered"
}

register_sdk_typelibs() {
    local msdatsrc_src simpdata_src

    msdatsrc_src="$(find_sdk_tlb "msdatsrc.tlb")"
    simpdata_src="$(find_sdk_tlb "simpdata.tlb")"

    if [ -z "$msdatsrc_src" ] || [ -z "$simpdata_src" ]; then
        echo "WARNING: MDAC28SDK_DIR does not contain both msdatsrc.tlb and simpdata.tlb"
        echo "  MDAC28SDK_DIR=${MDAC28SDK_DIR:-<unset>}"
        return 0
    fi

    # Install to system32 (64-bit) and syswow64 (32-bit WoW64 redirect).
    mkdir -p "$MDAC_STABLE_DIR"
    cp "$msdatsrc_src" "$MDAC_STABLE_DIR/msdatsrc.tlb"
    cp "$simpdata_src" "$MDAC_STABLE_DIR/simpdata.tlb"

    local syswow64_mdac="$WINEPREFIX/drive_c/windows/syswow64/mdac28"
    if [ -d "$WINEPREFIX/drive_c/windows/syswow64" ]; then
        mkdir -p "$syswow64_mdac"
        cp "$msdatsrc_src" "$syswow64_mdac/msdatsrc.tlb"
        cp "$simpdata_src" "$syswow64_mdac/simpdata.tlb"
    fi

    # Use wine reg for reliable path handling (winepath -w can produce broken paths).
    local MSDATSRC_KEY="HKLM\\Software\\Classes\\TypeLib\\{7C0FFAB0-CD84-11D0-949A-00A0C91110ED}"
    local SIMPDATA_KEY="HKLM\\Software\\Classes\\TypeLib\\{E0E270C2-C0BE-11D0-8FE4-00A0C90A6341}"
    local TLB_DIR="C:\\windows\\system32\\mdac28"

    WINEDEBUG=-all wine reg add "${MSDATSRC_KEY}\\1.0" /ve /t REG_SZ /d "Microsoft Data Source Interfaces" /f >/dev/null 2>&1
    WINEDEBUG=-all wine reg add "${MSDATSRC_KEY}\\1.0\\0\\win32" /ve /t REG_SZ /d "${TLB_DIR}\\msdatsrc.tlb" /f >/dev/null 2>&1
    WINEDEBUG=-all wine reg add "${MSDATSRC_KEY}\\1.0\\FLAGS" /ve /t REG_SZ /d "8" /f >/dev/null 2>&1
    WINEDEBUG=-all wine reg add "${MSDATSRC_KEY}\\1.0\\HELPDIR" /ve /t REG_SZ /d "${TLB_DIR}" /f >/dev/null 2>&1

    WINEDEBUG=-all wine reg add "${SIMPDATA_KEY}\\1.5" /ve /t REG_SZ /d "Microsoft OLE DB Simple Provider 1.5 Library" /f >/dev/null 2>&1
    WINEDEBUG=-all wine reg add "${SIMPDATA_KEY}\\1.5\\409\\win32" /ve /t REG_SZ /d "${TLB_DIR}\\simpdata.tlb" /f >/dev/null 2>&1
    WINEDEBUG=-all wine reg add "${SIMPDATA_KEY}\\1.5\\FLAGS" /ve /t REG_SZ /d "8" /f >/dev/null 2>&1
    WINEDEBUG=-all wine reg add "${SIMPDATA_KEY}\\1.5\\HELPDIR" /ve /t REG_SZ /d "${TLB_DIR}" /f >/dev/null 2>&1

    echo "Registered MSDATASRC and SIMPDATA typelibs into $MDAC_STABLE_DIR"
}

verify_setup() {
    local strict_sql="${1:-0}"
    if ! have_native_mdac || ! have_native_oledb; then
        echo "ERROR: native MDAC runtime is not fully present in $WINEPREFIX"
        return 1
    fi

    # Check that key DLLs are genuine native (not Wine builtins).
    local ado_dll="$WINEPREFIX/drive_c/Program Files (x86)/Common Files/System/ADO/msado15.dll"
    if [ -f "$ado_dll" ] && is_wine_builtin "$ado_dll"; then
        echo "WARNING: msado15.dll is still a Wine builtin — run $SELF_NAME with MDAC28_EXE"
    fi

    # Check typelib registration.
    local tlb_ok=0
    local reg_val
    reg_val="$(WINEDEBUG=-all wine reg query "HKLM\\Software\\Classes\\TypeLib\\{7C0FFAB0-CD84-11D0-949A-00A0C91110ED}\\1.0\\0\\win32" /ve 2>/dev/null)"
    if echo "$reg_val" | grep -qi "msdatsrc.tlb"; then
        tlb_ok=1
    fi

    if [ "$tlb_ok" = "1" ]; then
        echo "MDAC typelibs are registered"
    else
        echo "WARNING: MDAC typelibs are not yet registered"
        echo "  Set MDAC28SDK_DIR to extracted mdac28sdk files and rerun $SELF_NAME."
    fi

    # Check syswow64 copy for 32-bit processes.
    if [ -d "$WINEPREFIX/drive_c/windows/syswow64" ]; then
        if [ ! -f "$WINEPREFIX/drive_c/windows/syswow64/mdac28/msdatsrc.tlb" ]; then
            echo "WARNING: msdatsrc.tlb not in syswow64/mdac28 — 32-bit processes may fail"
        fi
    fi

    # Verify MSSQL driver DLLs.
    local oledb_dir_chk="$WINEPREFIX/drive_c/Program Files (x86)/Common Files/System/OLE DB"
    [ ! -d "$oledb_dir_chk" ] && oledb_dir_chk="$WINEPREFIX/drive_c/Program Files/Common Files/System/OLE DB"
    local sys32_chk="$WINEPREFIX/drive_c/windows/system32"
    local mssql_ok=1

    if [ ! -f "$oledb_dir_chk/sqloledb.dll" ]; then
        echo "WARNING: sqloledb.dll not found in OLE DB directory — SQLOLEDB provider missing"
        mssql_ok=0
    fi
    for dll in odbc32.dll odbccp32.dll mtxdm.dll dbmsrpcn.dll dbnmpntw.dll dbnetlib.dll dbmsgnet.dll sqlunirl.dll; do
        if [ ! -f "$sys32_chk/$dll" ]; then
            echo "WARNING: $dll is missing from system32"
            mssql_ok=0
        fi
    done

    if [ "$mssql_ok" = "1" ]; then
        echo "MSSQL driver DLLs are present (sqloledb, odbc32, odbccp32, mtxdm, dbnetlib)"
    else
        echo "WARNING: some MSSQL driver DLLs are missing — run $SELF_NAME with MDAC28_EXE"
        if [ "$strict_sql" = "1" ]; then
            echo "ERROR: live SQL compare prerequisites are not ready"
            return 1
        fi
    fi

    return 0
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    usage
    exit 0
fi

command -v wine >/dev/null 2>&1 || { echo "ERROR: wine not found"; exit 1; }

if [ "$VERIFY_ONLY" = "1" ]; then
    if [ ! -d "$WINEPREFIX" ]; then
        echo "ERROR: Wine prefix not found: $WINEPREFIX"
        exit 1
    fi
    verify_setup "$VERIFY_SQL"
    exit $?
fi

command -v cabextract >/dev/null 2>&1 || { echo "ERROR: cabextract not found (apt install cabextract)"; exit 1; }
ensure_prefix_booted
install_mdac_runtime
fix_wine_builtins
install_mssql_dlls
register_mdac_com_classes
register_dll_overrides
register_sdk_typelibs
verify_setup
