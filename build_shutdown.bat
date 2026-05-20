@echo off
setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "LAST_EXIT_CODE=1"
set "PATH_BASH="
set "BUILD_ARGS=%*"

for %%I in (bash.exe) do set "PATH_BASH=%%~$PATH:I"

rem Define candidate paths in order of preference (MinGW/UCRT with tools in PATH first)
setlocal enabledelayedexpansion
set "BASH_CANDIDATES=0"
rem MSYS2 MinGW64 has tools in /mingw64/bin - these are fastest
set "BASH_CANDIDATE[0]=%SystemDrive%\msys64\mingw64\bin\bash.exe|MSYS2 MinGW64"
rem Git Bash (bin variant) usually has better tool support
set "BASH_CANDIDATE[1]=%ProgramFiles%\Git\bin\bash.exe|Git Bash (bin)"
rem MSYS2 MinGW32 
set "BASH_CANDIDATE[2]=%SystemDrive%\msys64\mingw32\bin\bash.exe|MSYS2 MinGW32"
rem Fallback to standard MSYS2 paths
set "BASH_CANDIDATE[3]=%SystemDrive%\msys64\usr\bin\bash.exe|MSYS2 (msys64)"
set "BASH_CANDIDATE[4]=%ProgramFiles%\MSYS2\usr\bin\bash.exe|MSYS2 (Program Files)"
set "BASH_CANDIDATE[5]=%ProgramFiles%\Git\usr\bin\bash.exe|Git Bash (usr\bin)"
set "BASH_CANDIDATE[6]=C:\msys64\mingw64\bin\bash.exe|MSYS2 MinGW64 (C:\msys64)"

rem Try each candidate in order
for /l %%i in (0,1,6) do (
    for /f "tokens=1,2 delims=|" %%A in ("!BASH_CANDIDATE[%%i]!") do (
        if exist "%%A" (
            call :quick_test "%%A" && call :try_bash "%%A" "%%B" && exit /b 0
        )
    )
)

rem Try bash from PATH (with quick test)
if defined PATH_BASH (
    call :quick_test "%PATH_BASH%" && call :try_bash "%PATH_BASH%" "bash.exe from PATH" && exit /b 0
)

rem Fall back to WSL
where wsl.exe >nul 2>nul && call :try_wsl && exit /b 0

echo [ERROR] Could not find a usable Windows Bash or WSL environment.
echo Install Git for Windows, MSYS2, or WSL with GNU-EFI and GNU binutils, then rerun this script.
exit /b %LAST_EXIT_CODE%

:quick_test
rem Quick test: check if bash environment has required tools without running full build
setlocal
set "BASH_PATH=%~1"
"%BASH_PATH%" -lc "command -v gcc >/dev/null 2>&1 && command -v ld >/dev/null 2>&1 && command -v objcopy >/dev/null 2>&1" >nul 2>&1
endlocal & exit /b %ERRORLEVEL%

:try_bash
setlocal
set "BASH_PATH=%~1"
set "DESC=%~2"

rem Quick sanity check: can bash execute?
"%BASH_PATH%" --version >nul 2>&1
if errorlevel 1 (
    endlocal
    exit /b 1
)

echo [INFO] Using %DESC%...
pushd "%SCRIPT_DIR%"

rem If PATH-style path (starts with /), call bash from PATH so Windows doesn't try to interpret it as a file path.
if "%BASH_PATH:~0,1%"=="/" goto :use_bash_from_path
goto :use_bash_file

:use_bash_from_path
bash -lc "set -o pipefail; export PATH=/mingw64/bin:/usr/bin:/bin:\$PATH; cd \"$(cygpath -u '%SCRIPT_DIR%')\"; tr -d '\r' < ./build_shutdown.sh | bash -s -- %BUILD_ARGS%"
set "LAST_EXIT_CODE=%ERRORLEVEL%"
goto :after_try_bash

:use_bash_file
"%BASH_PATH%" -lc "set -o pipefail; export PATH=/mingw64/bin:/ucrt64/bin:/usr/bin:/bin:\$PATH; cd \"$(cygpath -u '%SCRIPT_DIR%')\"; tr -d '\r' < ./build_shutdown.sh | bash -s -- %BUILD_ARGS%"
set "LAST_EXIT_CODE=%ERRORLEVEL%"

:after_try_bash
popd
endlocal & set "LAST_EXIT_CODE=%LAST_EXIT_CODE%"
if "%LAST_EXIT_CODE%"=="0" exit /b 0
exit /b 1

:try_wsl
for /f "delims=" %%I in ('wsl.exe -e wslpath -a "%SCRIPT_DIR%" 2^>nul') do set "WSL_SCRIPT_DIR=%%I"
if not defined WSL_SCRIPT_DIR (
    echo [WARN] WSL is installed, but the repository path could not be translated. Skipping WSL fallback...
    exit /b 1
)

echo [INFO] Trying WSL...
wsl.exe -e bash -lc "set -o pipefail; export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin; cd '%WSL_SCRIPT_DIR%'; tr -d '\r' < ./build_shutdown.sh | bash -s -- %BUILD_ARGS%"
set "LAST_EXIT_CODE=%ERRORLEVEL%"
if "%LAST_EXIT_CODE%"=="0" exit /b 0
echo [WARN] WSL failed with exit code %LAST_EXIT_CODE%.
exit /b 1
