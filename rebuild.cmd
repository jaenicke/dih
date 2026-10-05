@echo off
setlocal

:: ============================================================================
:: DIH Example - Build Only (no registration)
:: Builds delinst.exe, then uses it to build packages without modifying the IDE
:: ============================================================================

set BDSVER=37.0
set DELINST=%~dp0delinst.exe
set DIHCONFIG=dihexample.xml
set USEBDS=

:: Build delinst.exe first (also detects if cmd compiler is available)
call "%~dp0dih\builddih.cmd" %BDSVER%
if %ERRORLEVEL% NEQ 0 goto :error

:: builddih.cmd creates .dih_usebds marker if bds.exe was used
if exist "%~dp0.dih_usebds" set USEBDS=-usebds

echo.
echo ============================================
echo  DIH Example - Build Only (BDS %BDSVER%)
echo ============================================
echo.

"%DELINST%" %BDSVER% -config "%DIHCONFIG%" -platforms Win32 -configs Release -entries dihexample -action build -verbose log %USEBDS%

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Build completed with errors. See dihexample.log for details.
    goto :error
)

echo.
echo Build completed successfully.
goto :end

:error
echo.
pause
exit /b 1

:end
pause
exit /b 0
