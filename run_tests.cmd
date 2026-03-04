@ECHO OFF
REM Run GdUnit4 tests from the project root.
REM For Windows. Requires Godot 4.x. Set GODOT_BIN if Godot is not in PATH.

cd /d "%~dp0"

if not defined GODOT_BIN goto find_godot
if not exist "%GODOT_BIN%" (
  echo GODOT_BIN is set to '%GODOT_BIN%' but that path does not exist.
  set GODOT_BIN=
  goto find_godot
)
goto run_tests

:find_godot
where godot.exe >nul 2>&1
if %errorlevel% equ 0 (
  for /f "usebackq tokens=*" %%i in (`where godot.exe 2^>nul`) do (
    set GODOT_BIN=%%i
    goto run_tests
  )
)
if exist "%LOCALAPPDATA%\Godot\Godot_v4.6-stable_win64.exe" (
  set GODOT_BIN=%LOCALAPPDATA%\Godot\Godot_v4.6-stable_win64.exe
  goto run_tests
)
if exist "%LOCALAPPDATA%\Godot\Godot_v4.5-stable_win64.exe" (
  set GODOT_BIN=%LOCALAPPDATA%\Godot\Godot_v4.5-stable_win64.exe
  goto run_tests
)
for /f "delims=" %%d in ('dir /b /ad "%LOCALAPPDATA%\Godot\Godot*" 2^>nul') do (
  for %%e in ("%LOCALAPPDATA%\Godot\%%d\Godot*.exe") do (
    set GODOT_BIN=%%~fe
    goto run_tests
  )
)
if exist "C:\Program Files\Godot\Godot.exe" (
  set GODOT_BIN=C:\Program Files\Godot\Godot.exe
  goto run_tests
)
echo Godot not found. Set GODOT_BIN to your Godot 4 executable, e.g.:
echo   set GODOT_BIN=C:\Path\To\Godot.exe
echo   run_tests.cmd
exit /b 1

:run_tests
call addons\gdUnit4\runtest.cmd -a tests %*
set TEST_EXIT=%errorlevel%
python scripts\print_coverage.py 2>nul
if %errorlevel% neq 0 python3 scripts\print_coverage.py 2>nul
exit /b %TEST_EXIT%
