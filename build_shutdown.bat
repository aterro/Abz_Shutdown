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
if exist "%SystemDrive%\msys64\usr\bin\bash.exe" call :try_bash "%SystemDrive%\msys64\usr\bin\bash.exe" "MSYS2" && exit /b 0
if exist "%ProgramFiles%\MSYS2\usr\bin\bash.exe" call :try_bash "%ProgramFiles%\MSYS2\usr\bin\bash.exe" "MSYS2 (Program Files)" && exit /b 0
if defined PATH_BASH call :try_bash "%PATH_BASH%" "bash.exe from PATH" && exit /b 0

where wsl.exe >nul 2>nul && call :try_wsl && exit /b 0

echo [ERROR] Could not find a usable Windows Bash or WSL environment.
echo Install Git for Windows, MSYS2, or WSL with GNU-EFI and GNU binutils, then rerun this script.
exit /b %LAST_EXIT_CODE%

:try_bash
echo [INFO] Trying %~2...
pushd "%SCRIPT_DIR%"
"%~1" "./build_shutdown.sh" %BUILD_ARGS%
set "LAST_EXIT_CODE=%ERRORLEVEL%"
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
