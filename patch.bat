@echo off
REM ===========================================================================
REM tatepatch ? opencode patching script (Windows)
REM
REM Applies server-side persistence patch and appends "(Tate Patched)"
REM to the version string.
REM
REM Usage:
REM   patch.bat               Apply patch
REM   patch.bat unapply       Restore official binary
REM   patch.bat status        Check patch status
REM   patch.bat help          Show help
REM ===========================================================================
setlocal enabledelayedexpansion

set "TATEPATCH_DIR=%~dp0"
set "PATCHES_DIR=%TATEPATCH_DIR%patches"
set "WORK_DIR=%TATEPATCH_DIR%_work"
set "SOURCE_DIR=%WORK_DIR%\source"
set "TATEPATCH_VERSION=v1.15.13 (Tate Patched 2)"
set "OPENCODE_TAG=v1.15.13"
set "BACKUP_FILE=%TATEPATCH_DIR%opencode-official-backup.exe"
 
REM Find opencode binary
where opencode >nul 2>&1
if %errorlevel% equ 0 (
    for /f "tokens=*" %%i in ('where opencode') do set "OPENCODE_BIN=%%i"
) else (
    set "OPENCODE_BIN="
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
"%OPENCODE_BIN%" --version 2>nul | findstr "(Tate Patched)" >nul
if %errorlevel% equ 0 (exit /b 0) else (exit /b 1)

REM ---------------------------------------------------------------------------
:unapply
echo.
echo ^=^=^> Unapplying patch ? restoring official binary
if not exist "%BACKUP_FILE%" (
    echo FAILED: No backup found at %BACKUP_FILE%
    exit /b 1
)
copy /y "%BACKUP_FILE%" "%OPENCODE_BIN%" >nul
echo Restored backup binary.
for /f "tokens=*" %%v in ('"%OPENCODE_BIN%" --version 2^>nul') do echo Version: %%v
goto :eof

REM ---------------------------------------------------------------------------
:do_patch
echo.
echo ^=^=^> Detecting opencode installation
if "%OPENCODE_BIN%"=="" (
    echo FAILED: opencode not found in PATH.
    exit /b 1
)

call :is_patched
if !errorlevel! equ 0 (
    for /f "tokens=*" %%v in ('"%OPENCODE_BIN%" --version 2^>nul') do echo Already patched: %%v
    echo Run "%~0 unapply" first to revert.
    exit /b 0
)

call :get_version
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
git clone --depth 1 --branch "%OPENCODE_TAG%" https://github.com/anomalyco/opencode.git "%SOURCE_DIR%"
if %errorlevel% neq 0 (
    echo FAILED: Clone failed. Check that v%VER% tag exists on GitHub.
    exit /b 1
)

pushd "%SOURCE_DIR%"

REM Apply patches
echo.
echo ^=^=^> Applying patches
for %%p in (
    version.patch
    webapp-storage-proxy.patch
    auth-pool.patch
    ctrl-enter-send.patch
    remove-help-button.patch
    remove-share.patch
    remove-upsell.patch
) do (
    if exist "%PATCHES_DIR%\%%p" (
        echo Applying %%p ...
        git apply "%PATCHES_DIR%\%%p"
        if !errorlevel! neq 0 (
            echo FAILED: Patch %%p could not be applied. Source has changed.
            popd
            exit /b 1
        )
    )
)

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
set "OPENCODE_VERSION=%TATEPATCH_VERSION%"
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
set "OPENCODE_VERSION=%TATEPATCH_VERSION%"
bun run "%SOURCE_DIR%\packages\opencode\script\build.ts" --single

REM Find built binary (.exe or extensionless, exclude directory names)
dir /s /b /a-d "%SOURCE_DIR%\packages\opencode\dist\*.exe" > "%TATEPATCH_DIR%\_binary_list.txt" 2>nul
set /p BINARY_PATH=<"%TATEPATCH_DIR%\_binary_list.txt"
if "%BINARY_PATH%"=="" (
    REM Maybe bun output without .exe ? search for any file named opencode
    dir /s /b /a-d "%SOURCE_DIR%\packages\opencode\dist\opencode" > "%TATEPATCH_DIR%\_binary_list.txt" 2>nul
    set /p BINARY_PATH=<"%TATEPATCH_DIR%\_binary_list.txt"
)
if "%BINARY_PATH%"=="" (
    echo FAILED: Built binary not found in dist/
    popd
    exit /b 1
)

REM Verify version
echo.
echo ^=^=^> Installing patched binary
echo Backing up original to %BACKUP_FILE%
copy /y "%OPENCODE_BIN%" "%BACKUP_FILE%" >nul
echo Installing patched binary
copy /y "%BINARY_PATH%" "%OPENCODE_BIN%" >nul

echo.
echo ^=^=^= Installation complete! ^=^=^=
for /f "tokens=*" %%v in ('"%OPENCODE_BIN%" --version 2^>nul') do echo Version: %%v
echo.
echo "(Tate Patched)" appears in version output on success.
echo Restore original: %~0 unapply

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
if /i "%1"=="help" goto :help
echo Unknown command: %1
echo Usage: %~0 [apply^|unapply^|status^|help]
exit /b 1

:apply
call :do_patch
exit /b 0

:unapply
call :unapply
exit /b 0

:status
if "%OPENCODE_BIN%"=="" (
    echo Status: opencode not installed
) else (
    call :is_patched
    if !errorlevel! equ 0 (
        for /f "tokens=*" %%v in ('"%OPENCODE_BIN%" --version 2^>nul') do echo Status: PATCHED (%%v)
    ) else (
        for /f "tokens=*" %%v in ('"%OPENCODE_BIN%" --version 2^>nul') do echo Status: OFFICIAL (%%v)
    )
)
exit /b 0

:help
echo Usage: %~0 [command]
echo.
echo Commands:
echo   apply           Apply tatepatch (default)
echo   unapply         Restore official binary
echo   status          Show patch status
echo   help            Show this help
exit /b 0
