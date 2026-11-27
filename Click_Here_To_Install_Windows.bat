@echo off
setlocal EnableExtensions
title JurisAtlas - Denmark Legal MCP Setup

set "REPO_NAME=dk-legal-mcp"
set "ZIP_URL=https://github.com/jurisatlas/dk-legal-mcp/archive/refs/heads/main.zip"
set "SCRIPT_DIR=%~dp0"
set "LOCAL_PS1=%SCRIPT_DIR%gui_installer.ps1"
set "LOCAL_MAIN=%SCRIPT_DIR%mcp_server_main.py"
set "IN_ZIP_PREVIEW=0"
if /I not "%SCRIPT_DIR:.zip\=%X"=="%SCRIPT_DIR%X" set "IN_ZIP_PREVIEW=1"

if "%IN_ZIP_PREVIEW%"=="0" if exist "%LOCAL_PS1%" if exist "%LOCAL_MAIN%" goto :run_local
goto :bootstrap

:run_local
echo Launching JurisAtlas visual setup window for Denmark...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%LOCAL_PS1%"
set "EXIT_CODE=%ERRORLEVEL%"
goto :done

:bootstrap
echo.
echo ============================================================================
echo   JurisAtlas Self-Bootstrapping Setup (Denmark)
echo ============================================================================
echo   Downloading latest dk-legal-mcp files from GitHub in the background...
echo.

set "BOOT_ROOT=%LOCALAPPDATA%\JurisAtlas\_bootstrap\%REPO_NAME%"
set "BOOT_ZIP=%BOOT_ROOT%\repo.zip"
set "BOOT_EXTRACT=%BOOT_ROOT%\extracted"

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference = 'Stop'; " ^
  "[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12; " ^
  "$zip = $env:BOOT_ZIP; $ext = $env:BOOT_EXTRACT; " ^
  "if (Test-Path -LiteralPath $ext) { Remove-Item -LiteralPath $ext -Recurse -Force }; " ^
  "New-Item -ItemType Directory -Path $ext -Force | Out-Null; " ^
  "Invoke-WebRequest -Uri $env:ZIP_URL -OutFile $zip -UseBasicParsing; " ^
  "Expand-Archive -LiteralPath $zip -DestinationPath $ext -Force; " ^
  "Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue"
set "DL_EXIT=%ERRORLEVEL%"

if not "%DL_EXIT%"=="0" (
    echo.
    echo ============================================================================
    echo   Could not download dk-legal-mcp from GitHub (Exit Code: %DL_EXIT%).
    echo ============================================================================
    echo   Please check your internet connection or try the unified installer:
    echo   https://jurisatlas.github.io
    echo.
    pause
    exit /b %DL_EXIT%
)

set "BOOT_PS1="
for /d %%D in ("%BOOT_EXTRACT%\*") do (
    if exist "%%~fD\gui_installer.ps1" set "BOOT_PS1=%%~fD\gui_installer.ps1"
)
if "%BOOT_PS1%"=="" if exist "%BOOT_EXTRACT%\gui_installer.ps1" set "BOOT_PS1=%BOOT_EXTRACT%\gui_installer.ps1"

if "%BOOT_PS1%"=="" (
    echo.
    echo Error: Downloaded archive did not contain gui_installer.ps1.
    pause
    exit /b 1
)

echo Launching JurisAtlas visual setup window for Denmark...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%BOOT_PS1%"
set "EXIT_CODE=%ERRORLEVEL%"

:done
if not "%EXIT_CODE%"=="0" (
    echo.
    echo ============================================================================
    echo   JurisAtlas Installer exited with error code %EXIT_CODE%.
    echo ============================================================================
    echo.
    echo   If your organization blocks PowerShell scripts (ExecutionPolicy / GPO),
    echo   please use the JurisAtlas unified installer or Claude .mcpb bundle:
    echo   https://jurisatlas.github.io
    echo.
    pause
    exit /b %EXIT_CODE%
)

endlocal
