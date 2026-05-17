@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "LAST_EXIT_CODE=1"
set "PATH_BASH="
set "BUILD_ARGS=%*"

for %%I in (bash.exe) do set "PATH_BASH=%%~$PATH:I"

if exist "%ProgramFiles%\Git\usr\bin\bash.exe" call :try_bash "%ProgramFiles%\Git\usr\bin\bash.exe" "Git Bash (usr\bin)" && exit /b 0
if exist "%ProgramFiles%\Git\bin\bash.exe" call :try_bash "%ProgramFiles%\Git\bin\bash.exe" "Git Bash (bin)" && exit /b 0
if exist "%SystemDrive%\msys64\usr\bin\bash.exe" call :try_bash "%SystemDrive%\msys64\usr\bin\bash.exe" "MSYS2 (msys64)" && exit /b 0
if exist "%SystemDrive%\msys32\usr\bin\bash.exe" call :try_bash "%SystemDrive%\msys32\usr\bin\bash.exe" "MSYS2 (msys32)" && exit /b 0
if exist "C:\msys64\usr\bin\bash.exe" call :try_bash "C:\msys64\usr\bin\bash.exe" "MSYS2 (C:\msys64)" && exit /b 0
if exist "C:\msys32\usr\bin\bash.exe" call :try_bash "C:\msys32\usr\bin\bash.exe" "MSYS2 (C:\msys32)" && exit /b 0
if exist "%ProgramFiles%\MSYS2\usr\bin\bash.exe" call :try_bash "%ProgramFiles%\MSYS2\usr\bin\bash.exe" "MSYS2 (Program Files)" && exit /b 0
if exist "%SystemDrive%\msys64\mingw64\bin\bash.exe" call :try_bash "%SystemDrive%\msys64\mingw64\bin\bash.exe" "MSYS2 Mingw64 bash" && exit /b 0
if exist "%SystemDrive%\msys32\mingw32\bin\bash.exe" call :try_bash "%SystemDrive%\msys32\mingw32\bin\bash.exe" "MSYS2 Mingw32 bash" && exit /b 0
if defined PATH_BASH call :try_bash "%PATH_BASH%" "bash.exe from PATH" && exit /b 0

where wsl.exe >nul 2>nul && call :try_wsl && exit /b 0

echo [ERROR] Could not find a usable Windows Bash or WSL environment.
echo Install Git for Windows, MSYS2, or WSL with GNU-EFI and GNU binutils, then rerun this script.
exit /b %LAST_EXIT_CODE%
:try_bash
echo [INFO] Trying %~2...
pushd "%SCRIPT_DIR%"
set "BASH_PATH=%~1"
rem Detect MSYS root (msys32/msys64) from the bash path and set TOOLCHAIN_PREFIX to the mingw bin if found
set "MSYS_ROOT="
set "MINGW_SUB="
echo %BASH_PATH% | findstr /I "msys32" >nul && (set "MSYS_ROOT=%SystemDrive%\msys32" & set "MINGW_SUB=mingw32")
echo %BASH_PATH% | findstr /I "msys64" >nul && (set "MSYS_ROOT=%SystemDrive%\msys64" & set "MINGW_SUB=mingw64")
echo %BASH_PATH% | findstr /I "C:\\msys32" >nul && (set "MSYS_ROOT=C:\msys32" & set "MINGW_SUB=mingw32")
echo %BASH_PATH% | findstr /I "C:\\msys64" >nul && (set "MSYS_ROOT=C:\msys64" & set "MINGW_SUB=mingw64")
rem If a msys root was found, set TOOLCHAIN_PREFIX inside the invoked bash so build script can prefer the mingw toolchain
if "%BASH_PATH:~0,1%"=="/" goto :use_bash_from_path

if not "%MSYS_ROOT%"=="" (
    set "TOOLCHAIN_PREFIX_WIN=%MSYS_ROOT%\%MINGW_SUB%"
) else (
    set "TOOLCHAIN_PREFIX_WIN="
)

:use_bash_from_path
if not "%TOOLCHAIN_PREFIX_WIN%"=="" (
    bash -lc "set -o pipefail; export TOOLCHAIN_PREFIX=\"$(cygpath -u '%TOOLCHAIN_PREFIX_WIN%')\"; export PATH=/usr/bin:/bin:\$PATH; cd \"$(cygpath -u '%SCRIPT_DIR%')\"; tr -d '\r' < ./build_shutdown.sh | bash -s -- %BUILD_ARGS%"
) else (
    bash -lc "set -o pipefail; export PATH=/usr/bin:/bin:\$PATH; cd \"$(cygpath -u '%SCRIPT_DIR%')\"; tr -d '\r' < ./build_shutdown.sh | bash -s -- %BUILD_ARGS%"
)
set "LAST_EXIT_CODE=%ERRORLEVEL%"
goto :after_try_bash

:use_bash_file
if not "%TOOLCHAIN_PREFIX_WIN%"=="" (
    "%~1" -lc "set -o pipefail; export TOOLCHAIN_PREFIX=\"$(cygpath -u '%TOOLCHAIN_PREFIX_WIN%')\"; export PATH=/usr/bin:/bin:\$PATH; cd \"$(cygpath -u '%SCRIPT_DIR%')\"; tr -d '\r' < ./build_shutdown.sh | bash -s -- %BUILD_ARGS%"
) else (
    "%~1" -lc "set -o pipefail; export PATH=/usr/bin:/bin:\$PATH; cd \"$(cygpath -u '%SCRIPT_DIR%')\"; tr -d '\r' < ./build_shutdown.sh | bash -s -- %BUILD_ARGS%"
)
set "LAST_EXIT_CODE=%ERRORLEVEL%"

:after_try_bash
popd
if "%LAST_EXIT_CODE%"=="0" exit /b 0
echo [WARN] %~2 failed with exit code %LAST_EXIT_CODE%. Trying the next environment...
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
