@echo off
REM ===========================================================================
REM tatepatch - opencode patching script (Windows)
REM
REM Applies server-side persistence patch and appends a tatepatch label to the
REM version string.
REM
REM The version numbers live only in the VERSION file. This script derives the
REM git tag, the build define, the display string and the patched-detection
REM string from it. Run "patch.bat version" to see the derived values.
REM
REM Usage:
REM   patch.bat               Apply patch
REM   patch.bat unapply       Restore official binary
REM   patch.bat status        Check patch status
REM   patch.bat version       Show version settings
REM   patch.bat help          Show help
REM ===========================================================================
setlocal enabledelayedexpansion

set "TATEPATCH_DIR=%~dp0"
set "PATCHES_DIR=%TATEPATCH_DIR%patches"
set "VERSION_FILE=%TATEPATCH_DIR%VERSION"
set "WORK_DIR=%TATEPATCH_DIR%_work"
set "SOURCE_DIR=%WORK_DIR%\source"
set "BACKUP_FILE=%TATEPATCH_DIR%opencode-official-backup.exe"
set "SCRIPT_ABS=%~f0"

REM ---------------------------------------------------------------------------
REM Version settings. VERSION is the single source of truth; everything below is
REM derived from it. Do not hardcode a version number here.
REM ---------------------------------------------------------------------------
set "TATEPATCH_BASE_VERSION="
set "TATEPATCH_PATCH_LEVEL="
for /f "usebackq tokens=1,* delims==" %%A in (`findstr /B "TATEPATCH_BASE_VERSION=" "%VERSION_FILE%"`) do set "TATEPATCH_BASE_VERSION=%%B"
for /f "usebackq tokens=1,* delims==" %%A in (`findstr /B "TATEPATCH_PATCH_LEVEL=" "%VERSION_FILE%"`) do set "TATEPATCH_PATCH_LEVEL=%%B"
if not defined TATEPATCH_BASE_VERSION (
    echo FAILED: TATEPATCH_BASE_VERSION is not set in %VERSION_FILE%
    exit /b 1
)
if not defined TATEPATCH_PATCH_LEVEL (
    echo FAILED: TATEPATCH_PATCH_LEVEL is not set in %VERSION_FILE%
    exit /b 1
)

set "TATEPATCH_LABEL=(Tate Patched !TATEPATCH_PATCH_LEVEL!)"
set "TATEPATCH_VERSION=v!TATEPATCH_BASE_VERSION! !TATEPATCH_LABEL!"
REM OPENCODE_VERSION define = UI/display version (no leading "v": UI adds it
REM itself). Outbound User-Agents are clean semver via InstallationClientVersion.
set "TATEPATCH_OPENCODE_VERSION=!TATEPATCH_BASE_VERSION! !TATEPATCH_LABEL!"
set "OPENCODE_TAG=v!TATEPATCH_BASE_VERSION!"

REM Find opencode binary (first PATH match, like patch.sh)
set "OPENCODE_BIN="
where opencode >nul 2>&1
if %errorlevel% equ 0 (
    for /f "tokens=*" %%i in ('where opencode') do if not defined OPENCODE_BIN set "OPENCODE_BIN=%%i"
)

goto :main

REM ---------------------------------------------------------------------------
:get_version
for /f "tokens=*" %%v in ('"%OPENCODE_BIN%" --version 2^>nul') do (
    set "RAW=%%v"
)
REM Extract semver (digit.digit.digit)
for /f "tokens=1 delims= " %%a in ("%RAW%") do set "VER=%%a"
for /f "tokens=1 delims=-" %%a in ("%VER%") do set "VER=%%a"
goto :eof

REM ---------------------------------------------------------------------------
:is_patched
"%OPENCODE_BIN%" --version 2>nul | findstr /C:"!TATEPATCH_LABEL!" >nul
if %errorlevel% equ 0 (exit /b 0) else (exit /b 1)

REM ---------------------------------------------------------------------------
:print_version
echo VERSION file:    %VERSION_FILE%
echo   base version:  !TATEPATCH_BASE_VERSION!
echo   patch level:   !TATEPATCH_PATCH_LEVEL!
echo   label:         !TATEPATCH_LABEL!
echo   git tag:       !OPENCODE_TAG!
echo   display:       !TATEPATCH_VERSION!
echo   build define:  !TATEPATCH_OPENCODE_VERSION!
goto :eof

REM ---------------------------------------------------------------------------
:unapply
echo.
echo ^=^=^> Unapplying patch - restoring official binary
if not exist "!BACKUP_FILE!" (
    echo FAILED: No backup found at !BACKUP_FILE!
    exit /b 1
)
copy /y "!BACKUP_FILE!" "!OPENCODE_BIN!" >nul
echo Restored backup binary.
for /f "tokens=*" %%v in ('"!OPENCODE_BIN!" --version 2^>nul') do echo Version: %%v
goto :eof

REM ---------------------------------------------------------------------------
:do_patch
echo.
echo ^=^=^> Detecting opencode installation
if not defined OPENCODE_BIN (
    echo FAILED: opencode not found in PATH.
    exit /b 1
)

call :is_patched
if !errorlevel! equ 0 (
    for /f "tokens=*" %%v in ('"!OPENCODE_BIN!" --version 2^>nul') do echo Already patched: %%v
    echo Run "%~0 unapply" first to revert.
    exit /b 0
)

call :get_version
if not defined VER (
    echo FAILED: Cannot determine installed opencode version
    exit /b 1
)
echo Installed: v%VER% at %OPENCODE_BIN%

REM Check prerequisites
where git >nul 2>&1 || (echo FAILED: git not found. Install Git for Windows. & exit /b 1)
where bun >nul 2>&1 || (echo FAILED: bun not found. Install bun. & exit /b 1)

REM Prepare source
echo.
echo ^=^=^> Preparing source code (v%VER%)
if exist "%SOURCE_DIR%" rmdir /s /q "%SOURCE_DIR%"
mkdir "%SOURCE_DIR%"

echo Cloning opencode source at tag %OPENCODE_TAG% ...
git clone --depth 1 --branch "%OPENCODE_TAG%" --config core.autocrlf=false --config core.eol=lf https://github.com/anomalyco/opencode.git "%SOURCE_DIR%"
if %errorlevel% neq 0 (
    echo FAILED: Clone failed. Check that v%VER% tag exists on GitHub.
    exit /b 1
)

pushd "%SOURCE_DIR%"

REM Normalize patch files to LF: a Windows checkout of this repository may
REM carry CRLF in patches\*.patch. git apply tolerates CR on normal lines but
REM NOT on the "\ No newline at end of file" marker, which makes the single
REM no-trailing-newline hunk (folder-environment.svg) fail with
REM "patch does not apply". Apply from CR-stripped copies in the work dir.
set "APPLY_DIR=%WORK_DIR%\patches"
if exist "%APPLY_DIR%" rmdir /s /q "%APPLY_DIR%"
mkdir "%APPLY_DIR%"
powershell -NoProfile -Command "Get-ChildItem -Path '%PATCHES_DIR%' -Filter '*.patch' | ForEach-Object { $t = [IO.File]::ReadAllText($_.FullName).Replace(\"`r`n\", \"`n\"); [IO.File]::WriteAllText((Join-Path '%APPLY_DIR%' $_.Name), $t) }"
if %errorlevel% neq 0 (
    echo FAILED: Could not normalize patch files to LF.
    popd
    exit /b 1
)

REM Apply patches, in the order listed in the single PATCH_ORDER definition.
echo.
echo ^=^=^> Applying patches
for %%p in (
    webapp-storage-proxy.patch
    auth-pool.patch
    ctrl-enter-send.patch
    remove-help-button.patch
    remove-share.patch
    remove-upsell.patch
    trash.patch
    anti-key-stick.patch
    shell-background.patch
    wait-commit.patch
    version.patch
    key-suffix.patch
) do (
    if exist "!APPLY_DIR!\%%p" (
        echo Applying %%p ...
        git apply --whitespace=nowarn "!APPLY_DIR!\%%p" 2>"!WORK_DIR!\apply_err.log"
        if !errorlevel! neq 0 (
            echo FAILED: Patch %%p could not be applied. Source has changed.
            type "!WORK_DIR!\apply_err.log"
            popd
            exit /b 1
        )
    )
)

REM Stamp the VERSION values into the source
echo.
echo ^=^=^> Stamping version
set "STAMP_TARGET=%SOURCE_DIR%\packages\core\src\installation\version.ts"
if not exist "!STAMP_TARGET!" (
    echo FAILED: version.ts not found at !STAMP_TARGET!
    popd
    exit /b 1
)
powershell -NoProfile -Command ^
    "$p='%STAMP_TARGET%';$t=[IO.File]::ReadAllText($p);" ^
    "$t=$t.Replace('@@TATEPATCH_BASE_VERSION@@','!TATEPATCH_BASE_VERSION!').Replace('@@TATEPATCH_PATCH_LEVEL@@','!TATEPATCH_PATCH_LEVEL!');" ^
    "[IO.File]::WriteAllText($p,$t,(New-Object Text.UTF8Encoding $false))"
if %errorlevel% neq 0 (
    echo FAILED: version stamping failed.
    popd
    exit /b 1
)
echo   Base: !TATEPATCH_BASE_VERSION!  level: !TATEPATCH_PATCH_LEVEL!
findstr /S /C:"@@TATEPATCH_" "%SOURCE_DIR%\*.ts" "%SOURCE_DIR%\*.tsx" >nul 2>&1
if %errorlevel% equ 0 (
    echo FAILED: Unsubstituted @@TATEPATCH_* placeholders remain in !SOURCE_DIR!
    popd
    exit /b 1
)
echo   Version string: !TATEPATCH_VERSION!

REM ---------------------------------------------------------------------------
REM Relax upstream's bun version gate. Upstream pins the packageManager bun
REM version and the build scripts refuse to run on anything else (same fix as
REM patch.sh: replace the script entry point with a stub that reads
REM OPENCODE_VERSION, and let the scripts run via OPENCODE_SKIP_BUN_CHECK).
REM ---------------------------------------------------------------------------
set "OPENCODE_SKIP_BUN_CHECK=1"
set "SCRIPT_ENTRY=%SOURCE_DIR%\packages\script\src\index.ts"
if exist "%SCRIPT_ENTRY%" echo export const Script = { get version(){ return process.env.OPENCODE_VERSION ^|^| "%TATEPATCH_OPENCODE_VERSION%" }, get channel(){ return process.env.OPENCODE_CHANNEL ^|^| "prod" } } as any>"%SCRIPT_ENTRY%"

REM Install dependencies
echo.
echo ^=^=^> Installing dependencies
bun install --ignore-scripts
if %errorlevel% neq 0 (
    echo FAILED: bun install failed.
    popd
    exit /b 1
)

REM Build web app
echo.
echo ^=^=^> Building web app
set "OPENCODE_CHANNEL=prod"
set "OPENCODE_VERSION=%TATEPATCH_OPENCODE_VERSION%"
pushd "%SOURCE_DIR%\packages\app"
bun run build
if %errorlevel% neq 0 (
    echo FAILED: Web app build failed.
    popd
    popd
    exit /b 1
)
popd

REM Build binary
echo.
echo ^=^=^> Building opencode binary (this may take a while...)
set "OPENCODE_VERSION=%TATEPATCH_OPENCODE_VERSION%"
bun run "%SOURCE_DIR%\packages\opencode\script\build.ts" --single

REM Find built binary (.exe or extensionless, exclude directory names)
dir /s /b /a-d "!SOURCE_DIR!\packages\opencode\dist\*.exe" > "!TATEPATCH_DIR!\_binary_list.txt" 2>nul
set /p BINARY_PATH=<"!TATEPATCH_DIR!\_binary_list.txt"
if not defined BINARY_PATH (
    REM Maybe bun output without .exe; search for any file named opencode
    dir /s /b /a-d "!SOURCE_DIR!\packages\opencode\dist\opencode" > "!TATEPATCH_DIR!\_binary_list.txt" 2>nul
    set /p BINARY_PATH=<"!TATEPATCH_DIR!\_binary_list.txt"
)
if not defined BINARY_PATH (
    echo FAILED: Built binary not found in dist/
    popd
    exit /b 1
)
del /q "!TATEPATCH_DIR!\_binary_list.txt" 2>nul

REM Verify the built binary actually runs and reports the patched version
echo.
echo Checking built binary version...
set "BUILT_VERSION="
for /f "tokens=*" %%v in ('"!BINARY_PATH!" --version 2^>nul') do set "BUILT_VERSION=%%v"
echo Built: !BUILT_VERSION!

REM Install
echo.
echo ^=^=^> Installing patched binary
echo Backing up original to !BACKUP_FILE!
copy /y "!OPENCODE_BIN!" "!BACKUP_FILE!" >nul
if !errorlevel! neq 0 (
    echo FAILED: Could not back up !OPENCODE_BIN! to !BACKUP_FILE!
    echo        The target is probably locked. Close opencode and retry.
    popd
    exit /b 1
)

REM Port 4096 safety: if an opencode server is listening, do NOT replace the
REM running binary; save the patched build next to the repo instead (same
REM behavior as patch.sh).
set "PORT4096_IN_USE="
netstat -ano -p tcp 2>nul | findstr /C:":4096 " | findstr /C:"LISTENING" >nul 2>&1
if not errorlevel 1 set "PORT4096_IN_USE=1"

if defined PORT4096_IN_USE (
    echo Port 4096 in use - not overwriting the running binary
    if not exist "!WORK_DIR!" mkdir "!WORK_DIR!"
    copy /y "!BINARY_PATH!" "!WORK_DIR!\opencode.patched" >nul
    if !errorlevel! neq 0 (
        echo FAILED: Could not save patched binary to !WORK_DIR!\opencode.patched
        popd
        exit /b 1
    )
    echo Patched binary saved to: !WORK_DIR!\opencode.patched
    echo.
    echo ^=^=^= Installation complete! ^(saved separately^) ^=^=^=
    echo Port 4096 is in use; the installed binary was not replaced to avoid
    echo touching a running instance.
    echo To test: "!WORK_DIR!\opencode.patched" --version
    echo.
    echo Restore original: "!SCRIPT_ABS!" unapply
) else (
    echo Installing patched binary
    copy /y "!BINARY_PATH!" "!OPENCODE_BIN!" >nul
    if !errorlevel! neq 0 (
        echo FAILED: Could not install patched binary to !OPENCODE_BIN!
        echo        The target is probably locked. Close opencode and retry.
        echo        Original was backed up to !BACKUP_FILE!
        popd
        exit /b 1
    )
    echo.
    echo ^=^=^= Installation complete! ^=^=^=
    for /f "tokens=*" %%v in ('"!OPENCODE_BIN!" --version 2^>nul') do echo Version: %%v
    echo.
    echo "!TATEPATCH_LABEL!" appears in version output on success.
    echo.
    echo Restore original: "!SCRIPT_ABS!" unapply
)

popd
goto :eof

REM ---------------------------------------------------------------------------
:main
if "%1"=="" goto :apply
if /i "%1"=="apply" goto :apply
if /i "%1"=="unapply" goto :unapply
if /i "%1"=="uninstall" goto :unapply
if /i "%1"=="revert" goto :unapply
if /i "%1"=="status" goto :status
if /i "%1"=="version" goto :version
if /i "%1"=="help" goto :help
echo Unknown command: %1
echo Usage: %~0 [apply^|unapply^|status^|version^|help]
exit /b 1

:apply
call :do_patch
exit /b 0

:status
if not defined OPENCODE_BIN (
    echo Status: opencode not installed
) else (
    call :is_patched
    if !errorlevel! equ 0 (
        for /f "tokens=*" %%v in ('"!OPENCODE_BIN!" --version 2^>nul') do echo Status: PATCHED ^(%%v^)
    ) else (
        for /f "tokens=*" %%v in ('"!OPENCODE_BIN!" --version 2^>nul') do echo Status: OFFICIAL ^(%%v^)
    )
)
exit /b 0

:version
call :print_version
exit /b 0

:help
echo Usage: %~0 [command]
echo.
echo Commands:
echo   apply           Apply tatepatch (default)
echo   unapply         Restore official binary
echo   status          Show patch status
echo   version         Show the version settings from %VERSION_FILE%
echo   help            Show this help
exit /b 0
